SET search_path TO society_manager, public;

CREATE SEQUENCE IF NOT EXISTS seq_society360_consumer_id;

ALTER TABLE m_customer ADD COLUMN IF NOT EXISTS consumer_id bigint;
UPDATE m_customer
SET consumer_id=nextval('seq_society360_consumer_id')
WHERE consumer_id IS NULL;
SELECT setval('seq_society360_consumer_id',
              GREATEST(COALESCE((SELECT max(consumer_id) FROM m_customer),0)+1,1),
              false);
ALTER TABLE m_customer ALTER COLUMN consumer_id SET DEFAULT nextval('seq_society360_consumer_id');
ALTER TABLE m_customer ALTER COLUMN consumer_id SET NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS ux_m_customer_society_consumer
ON m_customer(society_id,consumer_id);

ALTER TABLE m_customer_flat ADD COLUMN IF NOT EXISTS consumer_id bigint;
UPDATE m_customer_flat cf SET consumer_id=c.consumer_id
FROM m_customer c
WHERE cf.customer_id=c.customer_id AND cf.consumer_id IS NULL;
DO $do$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='fk_m_customer_flat_consumer' AND conrelid='m_customer_flat'::regclass) THEN ALTER TABLE m_customer_flat ADD CONSTRAINT fk_m_customer_flat_consumer FOREIGN KEY(society_id,consumer_id) REFERENCES m_customer(society_id,consumer_id); END IF; END $do$;
CREATE INDEX IF NOT EXISTS ix_m_customer_flat_consumer ON m_customer_flat(society_id,consumer_id);

ALTER TABLE m_user ADD COLUMN IF NOT EXISTS consumer_id bigint;
UPDATE m_user u SET consumer_id=c.consumer_id
FROM m_customer c
WHERE u.customer_id=c.customer_id AND u.consumer_id IS NULL;
DO $do$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='fk_m_user_consumer' AND conrelid='m_user'::regclass) THEN ALTER TABLE m_user ADD CONSTRAINT fk_m_user_consumer FOREIGN KEY(society_id,consumer_id) REFERENCES m_customer(society_id,consumer_id); END IF; END $do$;
CREATE INDEX IF NOT EXISTS ix_m_user_consumer ON m_user(society_id,consumer_id);

ALTER TABLE m_vehicle ADD COLUMN IF NOT EXISTS consumer_id bigint;
UPDATE m_vehicle v SET consumer_id=c.consumer_id
FROM m_customer c
WHERE v.customer_id=c.customer_id AND v.consumer_id IS NULL;
DO $do$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='fk_m_vehicle_consumer' AND conrelid='m_vehicle'::regclass) THEN ALTER TABLE m_vehicle ADD CONSTRAINT fk_m_vehicle_consumer FOREIGN KEY(society_id,consumer_id) REFERENCES m_customer(society_id,consumer_id); END IF; END $do$;
CREATE INDEX IF NOT EXISTS ix_m_vehicle_consumer ON m_vehicle(society_id,consumer_id);

ALTER TABLE t_bill ADD COLUMN IF NOT EXISTS consumer_id bigint;
UPDATE t_bill b SET consumer_id=x.consumer_id
FROM (
 SELECT b2.bill_id,c.consumer_id
 FROM t_bill b2
 JOIN m_customer_flat cf ON cf.society_id=b2.society_id AND cf.flat_id=b2.flat_id AND cf.is_primary
 JOIN m_customer c ON c.society_id=cf.society_id AND c.customer_id=cf.customer_id
) x WHERE b.bill_id=x.bill_id AND b.consumer_id IS NULL;
DO $do$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='fk_t_bill_consumer' AND conrelid='t_bill'::regclass) THEN ALTER TABLE t_bill ADD CONSTRAINT fk_t_bill_consumer FOREIGN KEY(society_id,consumer_id) REFERENCES m_customer(society_id,consumer_id); END IF; END $do$;
CREATE INDEX IF NOT EXISTS ix_t_bill_consumer ON t_bill(society_id,consumer_id);

ALTER TABLE t_bill_line_item ADD COLUMN IF NOT EXISTS consumer_id bigint;
UPDATE t_bill_line_item li SET consumer_id=b.consumer_id
FROM t_bill b WHERE li.bill_id=b.bill_id AND li.consumer_id IS NULL;
DO $do$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='fk_t_bill_line_item_consumer' AND conrelid='t_bill_line_item'::regclass) THEN ALTER TABLE t_bill_line_item ADD CONSTRAINT fk_t_bill_line_item_consumer FOREIGN KEY(society_id,consumer_id) REFERENCES m_customer(society_id,consumer_id); END IF; END $do$;
CREATE INDEX IF NOT EXISTS ix_t_bill_line_item_consumer ON t_bill_line_item(society_id,consumer_id);

ALTER TABLE t_payment ADD COLUMN IF NOT EXISTS consumer_id bigint;
UPDATE t_payment p SET consumer_id=c.consumer_id
FROM m_customer c WHERE p.customer_id=c.customer_id AND p.consumer_id IS NULL;
DO $do$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='fk_t_payment_consumer' AND conrelid='t_payment'::regclass) THEN ALTER TABLE t_payment ADD CONSTRAINT fk_t_payment_consumer FOREIGN KEY(society_id,consumer_id) REFERENCES m_customer(society_id,consumer_id); END IF; END $do$;
CREATE INDEX IF NOT EXISTS ix_t_payment_consumer ON t_payment(society_id,consumer_id);

ALTER TABLE t_receipt ADD COLUMN IF NOT EXISTS consumer_id bigint;
UPDATE t_receipt r SET consumer_id=p.consumer_id
FROM t_payment p WHERE r.payment_id=p.payment_id AND r.consumer_id IS NULL;
DO $do$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='fk_t_receipt_consumer' AND conrelid='t_receipt'::regclass) THEN ALTER TABLE t_receipt ADD CONSTRAINT fk_t_receipt_consumer FOREIGN KEY(society_id,consumer_id) REFERENCES m_customer(society_id,consumer_id); END IF; END $do$;
CREATE INDEX IF NOT EXISTS ix_t_receipt_consumer ON t_receipt(society_id,consumer_id);

ALTER TABLE t_adjustment ADD COLUMN IF NOT EXISTS consumer_id bigint;
UPDATE t_adjustment a SET consumer_id=x.consumer_id
FROM (
 SELECT a2.adjustment_id,c.consumer_id
 FROM t_adjustment a2
 JOIN m_customer_flat cf ON cf.society_id=a2.society_id AND cf.flat_id=a2.flat_id AND cf.is_primary
 JOIN m_customer c ON c.society_id=cf.society_id AND c.customer_id=cf.customer_id
) x WHERE a.adjustment_id=x.adjustment_id AND a.consumer_id IS NULL;
DO $do$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='fk_t_adjustment_consumer' AND conrelid='t_adjustment'::regclass) THEN ALTER TABLE t_adjustment ADD CONSTRAINT fk_t_adjustment_consumer FOREIGN KEY(society_id,consumer_id) REFERENCES m_customer(society_id,consumer_id); END IF; END $do$;
CREATE INDEX IF NOT EXISTS ix_t_adjustment_consumer ON t_adjustment(society_id,consumer_id);

ALTER TABLE t_complaint ADD COLUMN IF NOT EXISTS consumer_id bigint;
UPDATE t_complaint x SET consumer_id=c.consumer_id
FROM m_customer c WHERE x.customer_id=c.customer_id AND x.consumer_id IS NULL;
DO $do$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='fk_t_complaint_consumer' AND conrelid='t_complaint'::regclass) THEN ALTER TABLE t_complaint ADD CONSTRAINT fk_t_complaint_consumer FOREIGN KEY(society_id,consumer_id) REFERENCES m_customer(society_id,consumer_id); END IF; END $do$;
CREATE INDEX IF NOT EXISTS ix_t_complaint_consumer ON t_complaint(society_id,consumer_id);

ALTER TABLE t_visitor_entry ADD COLUMN IF NOT EXISTS consumer_id bigint;
UPDATE t_visitor_entry v SET consumer_id=x.consumer_id
FROM (
 SELECT v2.visitor_entry_id,c.consumer_id
 FROM t_visitor_entry v2
 JOIN m_customer_flat cf ON cf.society_id=v2.society_id AND cf.flat_id=v2.flat_id AND cf.is_primary
 JOIN m_customer c ON c.society_id=cf.society_id AND c.customer_id=cf.customer_id
) x WHERE v.visitor_entry_id=x.visitor_entry_id AND v.consumer_id IS NULL;
DO $do$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='fk_t_visitor_entry_consumer' AND conrelid='t_visitor_entry'::regclass) THEN ALTER TABLE t_visitor_entry ADD CONSTRAINT fk_t_visitor_entry_consumer FOREIGN KEY(society_id,consumer_id) REFERENCES m_customer(society_id,consumer_id); END IF; END $do$;
CREATE INDEX IF NOT EXISTS ix_t_visitor_entry_consumer ON t_visitor_entry(society_id,consumer_id);

ALTER TABLE t_service_history ADD COLUMN IF NOT EXISTS consumer_id bigint;
UPDATE t_service_history x SET consumer_id=c.consumer_id
FROM m_customer c WHERE x.customer_id=c.customer_id AND x.consumer_id IS NULL;
DO $do$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='fk_t_service_history_consumer' AND conrelid='t_service_history'::regclass) THEN ALTER TABLE t_service_history ADD CONSTRAINT fk_t_service_history_consumer FOREIGN KEY(society_id,consumer_id) REFERENCES m_customer(society_id,consumer_id); END IF; END $do$;
CREATE INDEX IF NOT EXISTS ix_t_service_history_consumer ON t_service_history(society_id,consumer_id,performed_at DESC);

ALTER TABLE t_parking_assignment ADD COLUMN IF NOT EXISTS consumer_id bigint;
UPDATE t_parking_assignment x SET consumer_id=c.consumer_id
FROM m_customer c WHERE x.customer_id=c.customer_id AND x.consumer_id IS NULL;
DO $do$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='fk_t_parking_assignment_consumer' AND conrelid='t_parking_assignment'::regclass) THEN ALTER TABLE t_parking_assignment ADD CONSTRAINT fk_t_parking_assignment_consumer FOREIGN KEY(society_id,consumer_id) REFERENCES m_customer(society_id,consumer_id); END IF; END $do$;
CREATE INDEX IF NOT EXISTS ix_t_parking_assignment_consumer ON t_parking_assignment(society_id,consumer_id);

ALTER TABLE t_bill_status_history ADD COLUMN IF NOT EXISTS consumer_id bigint;
UPDATE t_bill_status_history x SET consumer_id=b.consumer_id
FROM t_bill b WHERE x.bill_id=b.bill_id AND x.consumer_id IS NULL;
DO $do$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='fk_t_bill_status_history_consumer' AND conrelid='t_bill_status_history'::regclass) THEN ALTER TABLE t_bill_status_history ADD CONSTRAINT fk_t_bill_status_history_consumer FOREIGN KEY(society_id,consumer_id) REFERENCES m_customer(society_id,consumer_id); END IF; END $do$;
CREATE INDEX IF NOT EXISTS ix_t_bill_status_history_consumer ON t_bill_status_history(society_id,consumer_id);

ALTER TABLE t_payment_allocation ADD COLUMN IF NOT EXISTS consumer_id bigint;
UPDATE t_payment_allocation x SET consumer_id=p.consumer_id
FROM t_payment p WHERE x.payment_id=p.payment_id AND x.consumer_id IS NULL;
DO $do$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='fk_t_payment_allocation_consumer' AND conrelid='t_payment_allocation'::regclass) THEN ALTER TABLE t_payment_allocation ADD CONSTRAINT fk_t_payment_allocation_consumer FOREIGN KEY(society_id,consumer_id) REFERENCES m_customer(society_id,consumer_id); END IF; END $do$;
CREATE INDEX IF NOT EXISTS ix_t_payment_allocation_consumer ON t_payment_allocation(society_id,consumer_id);

ALTER TABLE t_collection_reversal ADD COLUMN IF NOT EXISTS consumer_id bigint;
UPDATE t_collection_reversal x SET consumer_id=p.consumer_id
FROM t_payment p WHERE x.payment_id=p.payment_id AND x.consumer_id IS NULL;
DO $do$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='fk_t_collection_reversal_consumer' AND conrelid='t_collection_reversal'::regclass) THEN ALTER TABLE t_collection_reversal ADD CONSTRAINT fk_t_collection_reversal_consumer FOREIGN KEY(society_id,consumer_id) REFERENCES m_customer(society_id,consumer_id); END IF; END $do$;
CREATE INDEX IF NOT EXISTS ix_t_collection_reversal_consumer ON t_collection_reversal(society_id,consumer_id);

CREATE OR REPLACE FUNCTION fn_society360_consumer_search(p_society_id bigint,p_search varchar)
RETURNS TABLE(
 consumer_id bigint,customer_id bigint,customer_code varchar,full_name varchar,customer_type varchar,
 phone varchar,email varchar,flat_count bigint,primary_flat varchar,primary_wing varchar,outstanding numeric
)
LANGUAGE sql STABLE AS $$
WITH q AS (SELECT lower(trim(coalesce(p_search,''))) s)
SELECT c.consumer_id,c.customer_id,c.customer_code,c.full_name,c.customer_type,c.phone,c.email,
       count(DISTINCT cf.flat_id) AS flat_count,
       max(f.flat_no) FILTER (WHERE cf.is_primary) AS primary_flat,
       max(coalesce(w.wing_name,w.wing_code,'')) FILTER (WHERE cf.is_primary) AS primary_wing,
       coalesce((
         SELECT sum(b.total_amount-b.paid_amount)
         FROM t_bill b
         WHERE b.society_id=p_society_id AND b.consumer_id=c.consumer_id
           AND b.total_amount>b.paid_amount
       ),0) AS outstanding
FROM m_customer c
LEFT JOIN m_customer_flat cf ON cf.society_id=c.society_id AND cf.customer_id=c.customer_id
LEFT JOIN m_flat f ON f.society_id=c.society_id AND f.flat_id=cf.flat_id
LEFT JOIN m_wing w ON w.wing_id=f.wing_id
CROSS JOIN q
WHERE c.society_id=p_society_id AND c.is_active
  AND (
    q.s='' OR c.full_name ILIKE q.s||'%' OR c.full_name ILIKE '%'||q.s||'%'
    OR c.phone ILIKE q.s||'%' OR c.customer_code ILIKE q.s||'%'
    OR c.consumer_id::text LIKE q.s||'%'
    OR EXISTS (
      SELECT 1 FROM m_customer_flat cf2 JOIN m_flat f2 ON f2.society_id=cf2.society_id AND f2.flat_id=cf2.flat_id
      WHERE cf2.society_id=c.society_id AND cf2.customer_id=c.customer_id
        AND f2.flat_no ILIKE '%'||q.s||'%'
    )
  )
GROUP BY q.s,c.consumer_id,c.customer_id,c.customer_code,c.full_name,c.customer_type,c.phone,c.email
ORDER BY CASE WHEN q.s='' THEN 2
              WHEN c.full_name ILIKE q.s||'%' OR c.phone ILIKE q.s||'%' OR c.customer_code ILIKE q.s||'%' OR c.consumer_id::text LIKE q.s||'%' THEN 0
              ELSE 1 END,c.full_name
LIMIT 60;
$$;

CREATE OR REPLACE FUNCTION fn_society360_consumer_account(p_society_id bigint,p_consumer_id bigint)
RETURNS jsonb
LANGUAGE sql STABLE AS $$
WITH c AS (
 SELECT * FROM m_customer WHERE society_id=p_society_id AND consumer_id=p_consumer_id AND is_active
),
flats AS (
 SELECT coalesce(jsonb_agg(jsonb_build_object(
   'flatId',f.flat_id,'flatNo',f.flat_no,'wing',coalesce(w.wing_name,w.wing_code,''),
   'building',coalesce(b.building_name,b.building_code,''),'areaSqft',f.area_sqft,
   'occupancyStatus',f.occupancy_status,'relationType',cf.relation_type,'isPrimary',cf.is_primary,
   'startDate',cf.start_date,'endDate',cf.end_date
 ) ORDER BY cf.is_primary DESC,f.flat_no),'[]'::jsonb) data
 FROM m_customer_flat cf JOIN m_flat f ON f.society_id=cf.society_id AND f.flat_id=cf.flat_id
 LEFT JOIN m_wing w ON w.wing_id=f.wing_id LEFT JOIN m_building b ON b.building_id=f.building_id
 WHERE cf.society_id=p_society_id AND cf.consumer_id=p_consumer_id
),
bills AS (
 SELECT coalesce(jsonb_agg(jsonb_build_object(
   'billId',b.bill_id,'billNo',b.bill_no,'billMonth',b.bill_month,'billDate',b.bill_date,'dueDate',b.due_date,
   'totalAmount',b.total_amount,'paidAmount',b.paid_amount,'balance',b.total_amount-b.paid_amount,
   'dpcAmount',b.dpc_amount,'rebateAmount',b.rebate_amount,'status',b.status,'flatNo',f.flat_no
 ) ORDER BY b.bill_date DESC),'[]'::jsonb) data
 FROM t_bill b JOIN m_flat f ON f.society_id=b.society_id AND f.flat_id=b.flat_id
 WHERE b.society_id=p_society_id AND b.consumer_id=p_consumer_id
),
payments AS (
 SELECT coalesce(jsonb_agg(jsonb_build_object(
   'paymentId',p.payment_id,'paymentNo',p.payment_no,'paymentDate',p.payment_date,'amount',p.amount,
   'mode',p.payment_mode,'referenceNo',p.reference_no,'status',p.status,'flatNo',f.flat_no
 ) ORDER BY p.payment_date DESC),'[]'::jsonb) data
 FROM t_payment p LEFT JOIN m_flat f ON f.society_id=p.society_id AND f.flat_id=p.flat_id
 WHERE p.society_id=p_society_id AND p.consumer_id=p_consumer_id
),
complaints AS (
 SELECT coalesce(jsonb_agg(jsonb_build_object(
   'complaintId',x.complaint_id,'complaintNo',x.complaint_no,'category',x.category,'title',x.title,
   'priority',x.priority,'status',x.status,'createdAt',x.created_at,'flatNo',f.flat_no
 ) ORDER BY x.created_at DESC),'[]'::jsonb) data
 FROM t_complaint x LEFT JOIN m_flat f ON f.society_id=x.society_id AND f.flat_id=x.flat_id
 WHERE x.society_id=p_society_id AND x.consumer_id=p_consumer_id
),
parking AS (
 SELECT coalesce(jsonb_agg(jsonb_build_object(
   'assignmentId',pa.assignment_id,'slotNo',ps.slot_no,'slotType',ps.slot_type,'charge',ps.charge,
   'flatNo',f.flat_no,'startDate',pa.start_date,'endDate',pa.end_date,'isActive',pa.is_active
 ) ORDER BY pa.is_active DESC,ps.slot_no),'[]'::jsonb) data
 FROM t_parking_assignment pa JOIN m_parking_slot ps ON ps.society_id=pa.society_id AND ps.parking_slot_id=pa.parking_slot_id
 LEFT JOIN m_flat f ON f.society_id=pa.society_id AND f.flat_id=pa.flat_id
 WHERE pa.society_id=p_society_id AND pa.consumer_id=p_consumer_id
),
history AS (
 SELECT coalesce(jsonb_agg(jsonb_build_object(
   'serviceHistoryId',h.service_history_id,'eventType',h.event_type,'eventSubType',h.event_sub_type,
   'entityName',h.entity_name,'entityId',h.entity_id,'referenceNo',h.reference_no,'eventTitle',h.event_title,
   'description',h.event_description,'performedAt',h.performed_at,'sourceChannel',h.source_channel,
   'modifyRemark',h.modify_remark,'flatNo',f.flat_no,'performedBy',u.display_name
 ) ORDER BY h.performed_at DESC),'[]'::jsonb) data
 FROM t_service_history h LEFT JOIN m_flat f ON f.society_id=h.society_id AND f.flat_id=h.flat_id
 LEFT JOIN m_user u ON u.user_id=h.performed_by
 WHERE h.society_id=p_society_id AND h.consumer_id=p_consumer_id
),
summary AS (
 SELECT
   (SELECT count(*) FROM m_customer_flat WHERE society_id=p_society_id AND consumer_id=p_consumer_id) flat_count,
   coalesce((SELECT sum(total_amount-paid_amount) FROM t_bill WHERE society_id=p_society_id AND consumer_id=p_consumer_id AND total_amount>paid_amount),0) outstanding,
   (SELECT min(due_date) FROM t_bill WHERE society_id=p_society_id AND consumer_id=p_consumer_id AND total_amount>paid_amount) next_due_date,
   coalesce((SELECT sum(amount) FROM t_payment WHERE society_id=p_society_id AND consumer_id=p_consumer_id AND status='Success'),0) paid_total
)
SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM c) THEN NULL ELSE jsonb_build_object(
 'consumer', (SELECT jsonb_build_object('consumerId',consumer_id,'customerId',customer_id,'customerCode',customer_code,'fullName',full_name,'customerType',customer_type,'phone',phone,'email',email) FROM c),
 'summary', (SELECT jsonb_build_object('flatCount',flat_count,'outstanding',outstanding,'nextDueDate',next_due_date,'paidTotal',paid_total) FROM summary),
 'flats',(SELECT data FROM flats),'bills',(SELECT data FROM bills),'payments',(SELECT data FROM payments),
 'complaints',(SELECT data FROM complaints),'parking',(SELECT data FROM parking),'serviceHistory',(SELECT data FROM history)
) END;
$$;

CREATE OR REPLACE FUNCTION fn_society360_consumer_account_by_customer(p_society_id bigint,p_customer_id bigint)
RETURNS jsonb LANGUAGE sql STABLE AS $$
SELECT fn_society360_consumer_account(p_society_id,c.consumer_id)
FROM m_customer c WHERE c.society_id=p_society_id AND c.customer_id=p_customer_id;
$$;



-- Keep the master consumer_id synchronized for all future writes while preserving
-- existing customer_id/flat_id foreign keys for backward compatibility.
CREATE OR REPLACE FUNCTION fn_sync_consumer_from_customer()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.customer_id IS NOT NULL THEN
    SELECT c.consumer_id INTO NEW.consumer_id
    FROM m_customer c
    WHERE c.society_id=NEW.society_id AND c.customer_id=NEW.customer_id;
  END IF;
  RETURN NEW;
END $$;

CREATE OR REPLACE FUNCTION fn_sync_consumer_from_flat()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.flat_id IS NOT NULL THEN
    SELECT c.consumer_id INTO NEW.consumer_id
    FROM m_customer_flat cf
    JOIN m_customer c ON c.society_id=cf.society_id AND c.customer_id=cf.customer_id
    WHERE cf.society_id=NEW.society_id AND cf.flat_id=NEW.flat_id AND cf.is_primary
    ORDER BY cf.customer_flat_id
    LIMIT 1;
  END IF;
  RETURN NEW;
END $$;

CREATE OR REPLACE FUNCTION fn_sync_consumer_from_payment()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.payment_id IS NOT NULL THEN
    SELECT p.consumer_id INTO NEW.consumer_id
    FROM t_payment p
    WHERE p.society_id=NEW.society_id AND p.payment_id=NEW.payment_id;
  END IF;
  RETURN NEW;
END $$;

CREATE OR REPLACE FUNCTION fn_sync_consumer_from_bill()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.bill_id IS NOT NULL THEN
    SELECT b.consumer_id INTO NEW.consumer_id
    FROM t_bill b
    WHERE b.society_id=NEW.society_id AND b.bill_id=NEW.bill_id;
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_m_customer_flat_consumer ON m_customer_flat;
CREATE TRIGGER trg_m_customer_flat_consumer BEFORE INSERT OR UPDATE OF customer_id,society_id
ON m_customer_flat FOR EACH ROW EXECUTE FUNCTION fn_sync_consumer_from_customer();

DROP TRIGGER IF EXISTS trg_m_user_consumer ON m_user;
CREATE TRIGGER trg_m_user_consumer BEFORE INSERT OR UPDATE OF customer_id,society_id
ON m_user FOR EACH ROW EXECUTE FUNCTION fn_sync_consumer_from_customer();

DROP TRIGGER IF EXISTS trg_m_vehicle_consumer ON m_vehicle;
CREATE TRIGGER trg_m_vehicle_consumer BEFORE INSERT OR UPDATE OF customer_id,society_id
ON m_vehicle FOR EACH ROW EXECUTE FUNCTION fn_sync_consumer_from_customer();

DROP TRIGGER IF EXISTS trg_t_payment_consumer ON t_payment;
CREATE TRIGGER trg_t_payment_consumer BEFORE INSERT OR UPDATE OF customer_id,society_id
ON t_payment FOR EACH ROW EXECUTE FUNCTION fn_sync_consumer_from_customer();

DROP TRIGGER IF EXISTS trg_t_complaint_consumer ON t_complaint;
CREATE TRIGGER trg_t_complaint_consumer BEFORE INSERT OR UPDATE OF customer_id,society_id
ON t_complaint FOR EACH ROW EXECUTE FUNCTION fn_sync_consumer_from_customer();

DROP TRIGGER IF EXISTS trg_t_service_history_consumer ON t_service_history;
CREATE TRIGGER trg_t_service_history_consumer BEFORE INSERT OR UPDATE OF customer_id,society_id
ON t_service_history FOR EACH ROW EXECUTE FUNCTION fn_sync_consumer_from_customer();

DROP TRIGGER IF EXISTS trg_t_parking_assignment_consumer ON t_parking_assignment;
CREATE TRIGGER trg_t_parking_assignment_consumer BEFORE INSERT OR UPDATE OF customer_id,society_id
ON t_parking_assignment FOR EACH ROW EXECUTE FUNCTION fn_sync_consumer_from_customer();

DROP TRIGGER IF EXISTS trg_t_bill_consumer ON t_bill;
CREATE TRIGGER trg_t_bill_consumer BEFORE INSERT OR UPDATE OF flat_id,society_id
ON t_bill FOR EACH ROW EXECUTE FUNCTION fn_sync_consumer_from_flat();

DROP TRIGGER IF EXISTS trg_t_adjustment_consumer ON t_adjustment;
CREATE TRIGGER trg_t_adjustment_consumer BEFORE INSERT OR UPDATE OF flat_id,society_id
ON t_adjustment FOR EACH ROW EXECUTE FUNCTION fn_sync_consumer_from_flat();

DROP TRIGGER IF EXISTS trg_t_visitor_entry_consumer ON t_visitor_entry;
CREATE TRIGGER trg_t_visitor_entry_consumer BEFORE INSERT OR UPDATE OF flat_id,society_id
ON t_visitor_entry FOR EACH ROW EXECUTE FUNCTION fn_sync_consumer_from_flat();

DROP TRIGGER IF EXISTS trg_t_bill_line_item_consumer ON t_bill_line_item;
CREATE TRIGGER trg_t_bill_line_item_consumer BEFORE INSERT OR UPDATE OF bill_id,society_id
ON t_bill_line_item FOR EACH ROW EXECUTE FUNCTION fn_sync_consumer_from_bill();

DROP TRIGGER IF EXISTS trg_t_bill_status_history_consumer ON t_bill_status_history;
CREATE TRIGGER trg_t_bill_status_history_consumer BEFORE INSERT OR UPDATE OF bill_id,society_id
ON t_bill_status_history FOR EACH ROW EXECUTE FUNCTION fn_sync_consumer_from_bill();

DROP TRIGGER IF EXISTS trg_t_payment_allocation_consumer ON t_payment_allocation;
CREATE TRIGGER trg_t_payment_allocation_consumer BEFORE INSERT OR UPDATE OF payment_id,society_id
ON t_payment_allocation FOR EACH ROW EXECUTE FUNCTION fn_sync_consumer_from_payment();

DROP TRIGGER IF EXISTS trg_t_collection_reversal_consumer ON t_collection_reversal;
CREATE TRIGGER trg_t_collection_reversal_consumer BEFORE INSERT OR UPDATE OF payment_id,society_id
ON t_collection_reversal FOR EACH ROW EXECUTE FUNCTION fn_sync_consumer_from_payment();
