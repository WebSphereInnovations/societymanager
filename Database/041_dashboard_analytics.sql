SET search_path TO society_manager, public;

-- Dashboard read model only: no data writes or demo seeding.
-- The society_id is always supplied by the authenticated server-side session.
CREATE OR REPLACE FUNCTION society_manager.fn_dashboard_analytics(
    p_society_id bigint,
    p_from date,
    p_to date,
    p_building_id bigint DEFAULT NULL,
    p_unit_type varchar DEFAULT NULL,
    p_customer_type varchar DEFAULT NULL,
    p_payment_mode varchar DEFAULT NULL,
    p_bill_status varchar DEFAULT NULL
) RETURNS jsonb
LANGUAGE sql
STABLE
AS $$
WITH
date_scope AS (
    SELECT COALESCE(p_from, date_trunc('month', current_date)::date) AS from_date,
           COALESCE(p_to, current_date) AS to_date
),
flat_scope AS (
    SELECT f.*
    FROM m_flat f
    WHERE f.society_id = p_society_id
      AND f.is_active
      AND (p_building_id IS NULL OR f.building_id = p_building_id)
      AND (NULLIF(trim(p_unit_type), '') IS NULL OR f.unit_type = p_unit_type)
),
customer_scope AS (
    SELECT c.*
    FROM m_customer c
    WHERE c.society_id = p_society_id
      AND (NULLIF(trim(p_customer_type), '') IS NULL OR c.customer_type = p_customer_type)
      AND (
          (p_building_id IS NULL AND NULLIF(trim(p_unit_type), '') IS NULL)
          OR EXISTS (
              SELECT 1
              FROM m_customer_flat cf
              JOIN flat_scope f ON f.flat_id = cf.flat_id
              WHERE cf.society_id = c.society_id
                AND cf.customer_id = c.customer_id
                AND (cf.end_date IS NULL OR cf.end_date >= current_date)
          )
      )
),
bill_scope AS (
    SELECT b.*,
           GREATEST(COALESCE(b.total_amount,0) - COALESCE(b.paid_amount,0),0)::numeric(18,2) AS balance_amount
    FROM t_bill b
    JOIN flat_scope f ON f.flat_id = b.flat_id
    CROSS JOIN date_scope d
    WHERE b.society_id = p_society_id
      AND b.bill_date >= d.from_date
      AND b.bill_date < d.to_date + 1
      AND upper(COALESCE(b.status,'')) NOT IN ('DRAFT','CANCELLED','CANCELED','VOID','DELETED')
      AND (NULLIF(trim(p_bill_status), '') IS NULL OR b.status = p_bill_status)
),
all_open_bills AS (
    SELECT b.*
    FROM t_bill b
    JOIN flat_scope f ON f.flat_id = b.flat_id
    WHERE b.society_id = p_society_id
      AND upper(COALESCE(b.status,'')) NOT IN ('DRAFT','CANCELLED','CANCELED','VOID','DELETED','PAID','SETTLED')
      AND GREATEST(COALESCE(b.total_amount,0)-COALESCE(b.paid_amount,0),0) > 0
      AND (NULLIF(trim(p_bill_status), '') IS NULL OR b.status = p_bill_status)
      AND (NULLIF(trim(p_customer_type), '') IS NULL OR EXISTS (
        SELECT 1 FROM m_customer_flat cf JOIN m_customer mc ON mc.customer_id=cf.customer_id
        WHERE cf.flat_id=b.flat_id AND mc.society_id=p_society_id AND mc.customer_type=p_customer_type
          AND (cf.end_date IS NULL OR cf.end_date>=current_date)))
),
payment_scope AS (
    SELECT p.*
    FROM t_payment p
    JOIN flat_scope f ON f.flat_id = p.flat_id
    CROSS JOIN date_scope d
    WHERE p.society_id = p_society_id
      AND p.payment_date >= d.from_date::timestamp
      AND p.payment_date < (d.to_date + 1)::timestamp
      AND upper(COALESCE(p.status,'')) IN ('SUCCESS','PAID','COMPLETED','SETTLED')
      AND (NULLIF(trim(p_payment_mode), '') IS NULL OR p.payment_mode = p_payment_mode)
),
trend_months AS (
    SELECT gs::date AS month_start
    FROM date_scope d
    CROSS JOIN LATERAL generate_series(
        date_trunc('month', d.from_date)::timestamp,
        date_trunc('month', d.to_date)::timestamp,
        interval '1 month'
    ) gs
    WHERE gs <= date_trunc('month', d.to_date)::timestamp
    ORDER BY gs
),
summary AS (
    SELECT
      (SELECT count(*) FROM customer_scope) AS total_customers,
      (SELECT count(*) FROM customer_scope WHERE is_active) AS active_customers,
      (SELECT count(*) FROM customer_scope WHERE NOT is_active) AS inactive_customers,
      (SELECT count(*) FROM customer_scope c CROSS JOIN date_scope d WHERE c.created_at >= d.from_date::timestamp AND c.created_at < (d.to_date + 1)::timestamp) AS new_customers,
      (SELECT count(*) FROM m_building b WHERE b.society_id=p_society_id AND b.is_active
        AND ((p_building_id IS NULL AND NULLIF(trim(p_unit_type),'') IS NULL AND NULLIF(trim(p_customer_type),'') IS NULL)
          OR EXISTS (SELECT 1 FROM flat_scope f WHERE f.building_id=b.building_id))) AS total_buildings,
      (SELECT count(*) FROM m_wing w WHERE w.society_id=p_society_id AND w.is_active
        AND ((p_building_id IS NULL AND NULLIF(trim(p_unit_type),'') IS NULL AND NULLIF(trim(p_customer_type),'') IS NULL)
          OR EXISTS (SELECT 1 FROM flat_scope f WHERE f.wing_id=w.wing_id))) AS total_wings,
      (SELECT count(*) FROM flat_scope) AS total_flats,
      (SELECT count(*) FROM flat_scope WHERE lower(occupancy_status)='occupied') AS occupied_flats,
      (SELECT count(*) FROM flat_scope WHERE lower(occupancy_status)='vacant') AS vacant_flats,
      (SELECT count(*) FROM flat_scope WHERE lower(occupancy_status) NOT IN ('occupied','vacant')) AS other_flats,
      (SELECT count(*) FROM m_parking_slot ps WHERE ps.society_id=p_society_id AND ps.is_active
        AND ((p_building_id IS NULL AND NULLIF(trim(p_unit_type),'') IS NULL AND NULLIF(trim(p_customer_type),'') IS NULL)
          OR EXISTS (SELECT 1 FROM t_parking_assignment pa JOIN flat_scope f ON f.flat_id=pa.flat_id
            WHERE pa.society_id=p_society_id AND pa.parking_slot_id=ps.parking_slot_id AND pa.is_active
              AND pa.start_date<=current_date AND (pa.end_date IS NULL OR pa.end_date>=current_date)
              AND (NULLIF(trim(p_customer_type),'') IS NULL OR EXISTS (SELECT 1 FROM m_customer mc WHERE mc.customer_id=pa.customer_id AND mc.customer_type=p_customer_type))))) AS parking_slots,
      (SELECT count(*) FROM bill_scope) AS bills_count,
      (SELECT COALESCE(sum(total_amount),0) FROM bill_scope) AS billed_amount,
      (SELECT COALESCE(sum(amount),0) FROM payment_scope) AS collected_amount,
      (SELECT COALESCE(sum(balance_amount),0) FROM bill_scope) AS period_outstanding,
      (SELECT COALESCE(sum(GREATEST(COALESCE(total_amount,0)-COALESCE(paid_amount,0),0)),0) FROM all_open_bills) AS current_outstanding,
      (SELECT count(*) FROM all_open_bills WHERE due_date < current_date) AS overdue_bills,
      (SELECT COALESCE(sum(GREATEST(COALESCE(total_amount,0)-COALESCE(paid_amount,0),0)),0) FROM all_open_bills WHERE due_date < current_date) AS overdue_amount,
      (SELECT count(*) FROM t_complaint c WHERE c.society_id=p_society_id AND c.status NOT IN ('Closed','Resolved')
        AND ((p_building_id IS NULL AND NULLIF(trim(p_unit_type), '') IS NULL) OR EXISTS (SELECT 1 FROM flat_scope f WHERE f.flat_id=c.flat_id))
        AND (NULLIF(trim(p_customer_type),'') IS NULL OR EXISTS (SELECT 1 FROM m_customer mc WHERE mc.customer_id=c.customer_id AND mc.customer_type=p_customer_type))) AS open_complaints,
      (SELECT count(*) FROM t_visitor_entry v WHERE v.society_id=p_society_id AND v.status='Inside'
        AND ((p_building_id IS NULL AND NULLIF(trim(p_unit_type), '') IS NULL) OR EXISTS (SELECT 1 FROM flat_scope f WHERE f.flat_id=v.flat_id))
        AND (NULLIF(trim(p_customer_type),'') IS NULL OR EXISTS (SELECT 1 FROM m_customer_flat cf JOIN m_customer mc ON mc.customer_id=cf.customer_id WHERE cf.flat_id=v.flat_id AND mc.customer_type=p_customer_type AND (cf.end_date IS NULL OR cf.end_date>=current_date)))) AS inside_visitors,
      (SELECT count(*) FROM t_migration_batch mb CROSS JOIN date_scope d WHERE mb.society_id=p_society_id AND mb.created_at >= d.from_date::timestamp AND mb.created_at < (d.to_date+1)::timestamp) AS migration_batches,
      (SELECT count(*) FROM t_parking_assignment pa JOIN flat_scope f ON f.flat_id=pa.flat_id WHERE pa.society_id=p_society_id AND pa.is_active AND pa.start_date<=current_date AND (pa.end_date IS NULL OR pa.end_date>=current_date)
        AND (NULLIF(trim(p_customer_type),'') IS NULL OR EXISTS (SELECT 1 FROM m_customer mc WHERE mc.customer_id=pa.customer_id AND mc.customer_type=p_customer_type))) AS assigned_parking_slots,
      (SELECT count(*) FROM t_customer_document cd CROSS JOIN date_scope d WHERE cd.society_id=p_society_id AND cd.is_active AND cd.uploaded_at >= d.from_date::timestamp AND cd.uploaded_at < (d.to_date+1)::timestamp AND ((p_building_id IS NULL AND NULLIF(trim(p_unit_type), '') IS NULL) OR EXISTS (SELECT 1 FROM flat_scope f WHERE f.flat_id=cd.flat_id))
        AND (NULLIF(trim(p_customer_type),'') IS NULL OR EXISTS (SELECT 1 FROM m_customer_flat cf JOIN m_customer mc ON mc.customer_id=cf.customer_id WHERE cf.flat_id=cd.flat_id AND mc.customer_type=p_customer_type AND (cf.end_date IS NULL OR cf.end_date>=current_date)))) AS customer_documents,
      (SELECT count(*) FROM t_document td CROSS JOIN date_scope d WHERE td.society_id=p_society_id AND td.created_at >= d.from_date::timestamp AND td.created_at < (d.to_date+1)::timestamp AND ((p_building_id IS NULL AND NULLIF(trim(p_unit_type), '') IS NULL) OR EXISTS (SELECT 1 FROM flat_scope f WHERE f.flat_id=td.flat_id))
        AND (NULLIF(trim(p_customer_type),'') IS NULL OR EXISTS (SELECT 1 FROM m_customer_flat cf JOIN m_customer mc ON mc.customer_id=cf.customer_id WHERE cf.flat_id=td.flat_id AND mc.customer_type=p_customer_type AND (cf.end_date IS NULL OR cf.end_date>=current_date)))) AS society_documents,
      (SELECT count(*) FROM t_notice n WHERE n.society_id=p_society_id AND n.status='Published' AND (n.publish_from IS NULL OR n.publish_from<=now()) AND (n.publish_to IS NULL OR n.publish_to>=now())) AS published_notices,
      (SELECT count(*) FROM t_notification nt WHERE nt.society_id=p_society_id AND nt.status='Pending') AS pending_notifications,
      (SELECT count(*) FROM t_it_ticket it WHERE it.society_id=p_society_id AND it.resolved_at IS NULL) AS open_tickets,
      (SELECT count(*) FROM t_security_incident si WHERE si.society_id=p_society_id AND si.status NOT IN ('Closed','Resolved') AND ((p_building_id IS NULL AND NULLIF(trim(p_unit_type), '') IS NULL) OR EXISTS (SELECT 1 FROM flat_scope f WHERE f.flat_id=si.flat_id))
        AND (NULLIF(trim(p_customer_type),'') IS NULL OR EXISTS (SELECT 1 FROM m_customer_flat cf JOIN m_customer mc ON mc.customer_id=cf.customer_id WHERE cf.flat_id=si.flat_id AND mc.customer_type=p_customer_type AND (cf.end_date IS NULL OR cf.end_date>=current_date)))) AS open_security_incidents,
      (SELECT count(*) FROM t_service_charge sc CROSS JOIN date_scope d WHERE sc.society_id=p_society_id AND sc.status NOT IN ('Paid','Cancelled','Void') AND sc.charge_date >= d.from_date::timestamp AND sc.charge_date < (d.to_date+1)::timestamp AND ((p_building_id IS NULL AND NULLIF(trim(p_unit_type), '') IS NULL) OR EXISTS (SELECT 1 FROM flat_scope f WHERE f.flat_id=sc.flat_id))
        AND (NULLIF(trim(p_customer_type),'') IS NULL OR EXISTS (SELECT 1 FROM m_customer_flat cf JOIN m_customer mc ON mc.customer_id=cf.customer_id WHERE cf.flat_id=sc.flat_id AND mc.customer_type=p_customer_type AND (cf.end_date IS NULL OR cf.end_date>=current_date)))) AS pending_service_charges,
      (SELECT count(*) FROM t_dishonored_cheque dc CROSS JOIN date_scope d WHERE dc.society_id=p_society_id AND dc.status NOT IN ('Resolved','Recovered','Cancelled') AND dc.dishonored_date >= d.from_date::timestamp AND dc.dishonored_date < (d.to_date+1)::timestamp AND ((p_building_id IS NULL AND NULLIF(trim(p_unit_type), '') IS NULL) OR EXISTS (SELECT 1 FROM flat_scope f WHERE f.flat_id=dc.flat_id))
        AND (NULLIF(trim(p_customer_type),'') IS NULL OR EXISTS (SELECT 1 FROM m_customer_flat cf JOIN m_customer mc ON mc.customer_id=cf.customer_id WHERE cf.flat_id=dc.flat_id AND mc.customer_type=p_customer_type AND (cf.end_date IS NULL OR cf.end_date>=current_date)))) AS dishonored_cheques,
      (SELECT count(*) FROM m_security_guard sg WHERE sg.society_id=p_society_id AND sg.is_active) AS active_guards
),
trends AS (
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'month', to_char(tm.month_start,'YYYY-MM'),
        'label', to_char(tm.month_start,'Mon YY'),
        'billed', COALESCE(b.billed,0),
        'collected', COALESCE(p.collected,0)
    ) ORDER BY tm.month_start),'[]'::jsonb) AS data
    FROM trend_months tm
    LEFT JOIN LATERAL (
        SELECT sum(bs.total_amount) AS billed
        FROM t_bill bs
        JOIN flat_scope f ON f.flat_id=bs.flat_id
        WHERE bs.society_id=p_society_id
          AND bs.bill_date >= GREATEST(tm.month_start, (SELECT from_date FROM date_scope))
          AND bs.bill_date < LEAST((tm.month_start + interval '1 month')::date, (SELECT to_date + 1 FROM date_scope))
          AND upper(COALESCE(bs.status,'')) NOT IN ('DRAFT','CANCELLED','CANCELED','VOID','DELETED')
          AND (NULLIF(trim(p_bill_status), '') IS NULL OR bs.status=p_bill_status)
    ) b ON true
    LEFT JOIN LATERAL (
        SELECT sum(ps.amount) AS collected
        FROM t_payment ps
        JOIN flat_scope f ON f.flat_id=ps.flat_id
        WHERE ps.society_id=p_society_id
          AND ps.payment_date >= GREATEST(tm.month_start, (SELECT from_date FROM date_scope))::timestamp
          AND ps.payment_date < LEAST((tm.month_start + interval '1 month')::date, (SELECT to_date + 1 FROM date_scope))::timestamp
          AND upper(COALESCE(ps.status,'')) IN ('SUCCESS','PAID','COMPLETED','SETTLED')
          AND (NULLIF(trim(p_payment_mode), '') IS NULL OR ps.payment_mode=p_payment_mode)
    ) p ON true
),
occupancy AS (
    SELECT COALESCE(jsonb_agg(jsonb_build_object('label',status,'count',cnt,'percentage',pct) ORDER BY status),'[]'::jsonb) AS data
    FROM (
      SELECT occupancy_status AS status, count(*) AS cnt,
             round(count(*)*100.0/NULLIF((SELECT count(*) FROM flat_scope),0),1) AS pct
      FROM flat_scope GROUP BY occupancy_status
    ) x
),
customer_types AS (
    SELECT COALESCE(jsonb_agg(jsonb_build_object('label',customer_type,'count',cnt,'percentage',pct) ORDER BY customer_type),'[]'::jsonb) AS data
    FROM (
      SELECT customer_type,count(*) AS cnt,
             round(count(*)*100.0/NULLIF((SELECT count(*) FROM customer_scope),0),1) AS pct
      FROM customer_scope GROUP BY customer_type
    ) x
),
payment_modes AS (
    SELECT COALESCE(jsonb_agg(jsonb_build_object('label',payment_mode,'amount',amount,'count',cnt) ORDER BY amount DESC),'[]'::jsonb) AS data
    FROM (
      SELECT payment_mode, sum(amount) AS amount, count(*) AS cnt
      FROM payment_scope GROUP BY payment_mode
    ) x
),
bill_statuses AS (
    SELECT COALESCE(jsonb_agg(jsonb_build_object('label',status,'count',cnt,'amount',amount) ORDER BY cnt DESC),'[]'::jsonb) AS data
    FROM (
      SELECT status,count(*) AS cnt,sum(total_amount) AS amount
      FROM bill_scope GROUP BY status
    ) x
),
unit_types AS (
    SELECT COALESCE(jsonb_agg(jsonb_build_object('label',COALESCE(NULLIF(unit_type,''),'Unspecified'),'count',cnt) ORDER BY cnt DESC),'[]'::jsonb) AS data
    FROM (
      SELECT unit_type,count(*) AS cnt FROM flat_scope GROUP BY unit_type
    ) x
),
complaint_statuses AS (
    SELECT COALESCE(jsonb_agg(jsonb_build_object('label',status,'count',cnt) ORDER BY cnt DESC),'[]'::jsonb) AS data
    FROM (
      SELECT c.status,count(*) AS cnt
      FROM t_complaint c CROSS JOIN date_scope d
      WHERE c.society_id=p_society_id AND c.created_at >= d.from_date::timestamp AND c.created_at < (d.to_date+1)::timestamp
        AND ((p_building_id IS NULL AND NULLIF(trim(p_unit_type), '') IS NULL) OR EXISTS (SELECT 1 FROM flat_scope f WHERE f.flat_id=c.flat_id))
      GROUP BY c.status
    ) x
),
filter_options AS (
    SELECT jsonb_build_object(
      'buildings', COALESCE((SELECT jsonb_agg(jsonb_build_object('id',building_id,'label',building_name) ORDER BY building_name) FROM m_building WHERE society_id=p_society_id AND is_active),'[]'::jsonb),
      'unitTypes', COALESCE((SELECT jsonb_agg(jsonb_build_object('value',unit_type,'label',unit_type) ORDER BY unit_type) FROM (SELECT DISTINCT unit_type FROM m_flat WHERE society_id=p_society_id AND is_active AND NULLIF(unit_type,'') IS NOT NULL) q),'[]'::jsonb),
      'customerTypes', COALESCE((SELECT jsonb_agg(jsonb_build_object('value',customer_type,'label',customer_type) ORDER BY customer_type) FROM (SELECT DISTINCT customer_type FROM m_customer WHERE society_id=p_society_id) q),'[]'::jsonb),
      'paymentModes', COALESCE((SELECT jsonb_agg(jsonb_build_object('value',payment_mode,'label',payment_mode) ORDER BY payment_mode) FROM (SELECT DISTINCT payment_mode FROM t_payment WHERE society_id=p_society_id) q),'[]'::jsonb),
      'billStatuses', COALESCE((SELECT jsonb_agg(jsonb_build_object('value',status,'label',status) ORDER BY status) FROM (SELECT DISTINCT status FROM t_bill WHERE society_id=p_society_id AND upper(COALESCE(status,'')) NOT IN ('DRAFT','CANCELLED','CANCELED','VOID','DELETED')) q),'[]'::jsonb)
    ) AS data
)
SELECT jsonb_build_object(
  'period', (SELECT jsonb_build_object('from',from_date,'to',to_date) FROM date_scope),
  'summary', jsonb_build_object(
    'totalCustomers', total_customers, 'activeCustomers', active_customers,
    'inactiveCustomers', inactive_customers, 'newCustomers', new_customers,
    'totalBuildings', total_buildings, 'totalWings', total_wings,
    'totalFlats', total_flats, 'occupiedFlats', occupied_flats,
    'vacantFlats', vacant_flats, 'otherFlats', other_flats,
    'occupancyRate', round(occupied_flats*100.0/NULLIF(total_flats,0),1),
    'parkingSlots', parking_slots, 'billsCount', bills_count,
    'billedAmount', billed_amount, 'collectedAmount', collected_amount,
    'periodOutstanding', period_outstanding, 'currentOutstanding', current_outstanding,
    'overdueBills', overdue_bills, 'overdueAmount', overdue_amount,
    'openComplaints', open_complaints, 'insideVisitors', inside_visitors,
    'migrationBatches', migration_batches, 'assignedParkingSlots', assigned_parking_slots,
    'customerDocuments', customer_documents, 'societyDocuments', society_documents,
    'publishedNotices', published_notices, 'pendingNotifications', pending_notifications,
    'openTickets', open_tickets, 'openSecurityIncidents', open_security_incidents,
    'pendingServiceCharges', pending_service_charges, 'dishonoredCheques', dishonored_cheques,
    'activeGuards', active_guards,
    'collectionRate', round(collected_amount*100.0/NULLIF(billed_amount,0),1)
  ),
  'trends', (SELECT data FROM trends),
  'occupancy', (SELECT data FROM occupancy),
  'customerTypes', (SELECT data FROM customer_types),
  'paymentModes', (SELECT data FROM payment_modes),
  'billStatuses', (SELECT data FROM bill_statuses),
  'unitTypes', (SELECT data FROM unit_types),
  'complaintStatuses', (SELECT data FROM complaint_statuses),
  'filters', (SELECT data FROM filter_options),
  'lastUpdated', now()
)
FROM summary;
$$;

CREATE INDEX IF NOT EXISTS ix_m_customer_society_created_at ON m_customer(society_id, created_at);
CREATE INDEX IF NOT EXISTS ix_t_complaint_society_created_at ON t_complaint(society_id, created_at);
CREATE INDEX IF NOT EXISTS ix_t_visitor_society_entry_at ON t_visitor_entry(society_id, entry_at);
