SET search_path TO society_manager, public;

-- Customer Account / Consumer 360 production schema.
ALTER TABLE m_customer ADD COLUMN IF NOT EXISTS alternate_phone varchar(30);
ALTER TABLE m_customer ADD COLUMN IF NOT EXISTS address_line text;
ALTER TABLE m_customer ADD COLUMN IF NOT EXISTS notes text;
ALTER TABLE t_complaint ADD COLUMN IF NOT EXISTS resolution text;
ALTER TABLE t_complaint ADD COLUMN IF NOT EXISTS remarks text;
ALTER TABLE t_adjustment ADD COLUMN IF NOT EXISTS status varchar(30) NOT NULL DEFAULT 'Approved';

ALTER TABLE t_document ADD COLUMN IF NOT EXISTS consumer_id bigint;
UPDATE t_document d
SET consumer_id=c.consumer_id
FROM m_customer c
WHERE d.society_id=c.society_id
  AND d.customer_id=c.customer_id
  AND d.consumer_id IS NULL;
DO $$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='fk_t_document_consumer' AND conrelid='t_document'::regclass) THEN
  ALTER TABLE t_document ADD CONSTRAINT fk_t_document_consumer
    FOREIGN KEY(society_id,consumer_id) REFERENCES m_customer(society_id,consumer_id);
 END IF;
END $$;
CREATE INDEX IF NOT EXISTS ix_t_document_consumer ON t_document(society_id,consumer_id,created_at DESC);

ALTER TABLE t_notification ADD COLUMN IF NOT EXISTS consumer_id bigint;
UPDATE t_notification n
SET consumer_id=c.consumer_id
FROM m_customer c
WHERE n.society_id=c.society_id AND n.customer_id=c.customer_id AND n.consumer_id IS NULL;
DO $$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='fk_t_notification_consumer' AND conrelid='t_notification'::regclass) THEN
  ALTER TABLE t_notification ADD CONSTRAINT fk_t_notification_consumer
    FOREIGN KEY(society_id,consumer_id) REFERENCES m_customer(society_id,consumer_id);
 END IF;
END $$;
CREATE INDEX IF NOT EXISTS ix_t_notification_consumer ON t_notification(society_id,consumer_id,created_at DESC);

CREATE TABLE IF NOT EXISTS t_customer_interaction(
 interaction_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 society_id bigint NOT NULL REFERENCES m_society(society_id),
 consumer_id bigint NOT NULL,
 interaction_date timestamptz NOT NULL DEFAULT now(),
 interaction_type varchar(40) NOT NULL,
 subject varchar(180),
 description text,
 employee_user_id bigint REFERENCES m_user(user_id),
 outcome text,
 follow_up_date date,
 remarks text,
 created_at timestamptz NOT NULL DEFAULT now(),
 modified_by bigint REFERENCES m_user(user_id),
 modified_at timestamptz NOT NULL DEFAULT now(),
 modify_remark varchar(500) NOT NULL DEFAULT '',
 CONSTRAINT fk_t_customer_interaction_consumer
   FOREIGN KEY(society_id,consumer_id) REFERENCES m_customer(society_id,consumer_id)
);
CREATE INDEX IF NOT EXISTS ix_t_customer_interaction_consumer
 ON t_customer_interaction(society_id,consumer_id,interaction_date DESC);

CREATE OR REPLACE FUNCTION sp_customer_account_search(p_society_id bigint,p_search text)
RETURNS TABLE(
 consumer_id bigint,consumer_code varchar,full_name varchar,flat_no varchar,wing varchar,
 phone varchar,email varchar,account_status varchar,flat_count bigint,outstanding numeric
)
LANGUAGE sql STABLE AS $$
WITH q AS (SELECT lower(trim(coalesce(p_search,''))) AS s)
SELECT c.consumer_id,c.customer_code,c.full_name,
       max(f.flat_no) FILTER (WHERE cf.is_primary) AS flat_no,
       max(coalesce(w.wing_name,w.wing_code,'')) FILTER (WHERE cf.is_primary) AS wing,
       c.phone,c.email,CASE WHEN c.is_active THEN 'Active' ELSE 'Inactive' END,
       count(DISTINCT cf.flat_id),
       coalesce((SELECT sum(greatest(b.total_amount-b.paid_amount,0))
                 FROM t_bill b
                 WHERE b.society_id=p_society_id AND b.consumer_id=c.consumer_id),0)
FROM m_customer c
LEFT JOIN m_customer_flat cf ON cf.society_id=c.society_id AND cf.customer_id=c.customer_id
LEFT JOIN m_flat f ON f.society_id=cf.society_id AND f.flat_id=cf.flat_id
LEFT JOIN m_wing w ON w.society_id=f.society_id AND w.wing_id=f.wing_id
CROSS JOIN q
WHERE c.society_id=p_society_id
  AND (q.s='' OR c.full_name ILIKE '%'||q.s||'%' OR c.phone ILIKE '%'||q.s||'%'
       OR c.email ILIKE '%'||q.s||'%' OR c.customer_code ILIKE q.s||'%'
       OR c.consumer_id::text LIKE q.s||'%'
       OR EXISTS (SELECT 1 FROM m_customer_flat cf2 JOIN m_flat f2 ON f2.society_id=cf2.society_id AND f2.flat_id=cf2.flat_id
                  WHERE cf2.society_id=c.society_id AND cf2.customer_id=c.customer_id
                    AND f2.flat_no ILIKE '%'||q.s||'%'))
GROUP BY c.consumer_id,c.customer_code,c.full_name,c.phone,c.email,c.is_active,q.s
ORDER BY CASE WHEN c.full_name ILIKE q.s||'%' OR c.customer_code ILIKE q.s||'%' OR c.consumer_id::text=q.s THEN 0 ELSE 1 END,c.full_name
LIMIT 30;
$$;

CREATE OR REPLACE FUNCTION sp_customer_account_get(p_society_id bigint,p_consumer_id bigint)
RETURNS TABLE(
 consumer_id bigint,customer_code varchar,full_name varchar,customer_type varchar,phone varchar,
 alternate_phone varchar,email varchar,address_line text,account_status varchar,created_at timestamptz,
 society_name varchar,flat_no varchar,wing varchar,building varchar,area_sqft numeric,
 occupancy_status varchar,relation_type varchar,is_primary boolean
)
LANGUAGE sql STABLE AS $$
SELECT c.consumer_id,c.customer_code,c.full_name,c.customer_type,c.phone,c.alternate_phone,c.email,c.address_line,
       CASE WHEN c.is_active THEN 'Active' ELSE 'Inactive' END,c.created_at,s.society_name,
       f.flat_no,coalesce(w.wing_name,w.wing_code,''),coalesce(b.building_name,''),f.area_sqft,
       f.occupancy_status,cf.relation_type,cf.is_primary
FROM m_customer c
JOIN m_society s ON s.society_id=c.society_id
LEFT JOIN m_customer_flat cf ON cf.society_id=c.society_id AND cf.customer_id=c.customer_id
LEFT JOIN m_flat f ON f.society_id=cf.society_id AND f.flat_id=cf.flat_id
LEFT JOIN m_wing w ON w.society_id=f.society_id AND w.wing_id=f.wing_id
LEFT JOIN m_building b ON b.society_id=f.society_id AND b.building_id=f.building_id
WHERE c.society_id=p_society_id AND c.consumer_id=p_consumer_id
ORDER BY cf.is_primary DESC NULLS LAST,f.flat_no;
$$;

CREATE OR REPLACE FUNCTION sp_customer_account_summary(p_society_id bigint,p_consumer_id bigint)
RETURNS TABLE(
 current_outstanding numeric,current_bill_amount numeric,previous_outstanding numeric,adjustments numeric,
 payments_received numeric,net_outstanding numeric,due_date date,overdue_days integer,overdue_amount numeric,
 last_payment_amount numeric,last_payment_date timestamptz,latest_bill_no varchar,latest_bill_date date,
 latest_bill_amount numeric,open_complaints bigint,open_service_requests bigint
)
LANGUAGE sql STABLE AS $$
WITH bills AS (
 SELECT b.*,greatest(b.total_amount-b.paid_amount,0) AS balance
 FROM t_bill b WHERE b.society_id=p_society_id AND b.consumer_id=p_consumer_id
),
latest AS (SELECT * FROM bills ORDER BY bill_date DESC,bill_id DESC LIMIT 1),
adj AS (
 SELECT coalesce(sum(CASE WHEN lower(adjustment_type) LIKE '%credit%' OR lower(adjustment_type) LIKE '%rebate%'
                           OR lower(adjustment_type) LIKE '%waiv%' OR lower(adjustment_type) LIKE '%discount%'
                          THEN -amount ELSE amount END),0) AS impact
 FROM t_adjustment WHERE society_id=p_society_id AND consumer_id=p_consumer_id
),
pay AS (
 SELECT p.payment_id,p.payment_date,p.amount
 FROM t_payment p WHERE p.society_id=p_society_id AND p.consumer_id=p_consumer_id
   AND lower(coalesce(p.status,'')) NOT IN ('cancelled','reversed','failed')
),
service AS (
 SELECT count(*) FILTER (WHERE lower(coalesce(event_type,'')) LIKE '%service%'
                              AND lower(coalesce(event_title,'')) NOT LIKE '%complaint%') AS open_service
 FROM t_service_history
 WHERE society_id=p_society_id AND consumer_id=p_consumer_id
   AND lower(coalesce(event_type,'')) IN ('service_request','service','request')
   AND lower(coalesce(event_data->>'status','')) IN ('open','in progress','pending')
)
SELECT coalesce((SELECT sum(balance) FROM bills),0),
       coalesce((SELECT total_amount FROM latest),0),
       coalesce((SELECT sum(balance) FROM bills WHERE bill_date < coalesce((SELECT bill_date FROM latest),current_date)),0),
       adj.impact,
       coalesce((SELECT sum(amount) FROM pay),0),
       greatest(coalesce((SELECT sum(balance) FROM bills),0)+adj.impact,0),
       (SELECT min(due_date) FROM bills WHERE balance>0),
       coalesce((SELECT greatest(current_date-min(due_date),0)::integer FROM bills WHERE balance>0 AND due_date<current_date),0),
       coalesce((SELECT sum(balance) FROM bills WHERE balance>0 AND due_date<current_date),0),
       (SELECT amount FROM pay ORDER BY payment_date DESC,payment_id DESC LIMIT 1),
       (SELECT payment_date FROM pay ORDER BY payment_date DESC,payment_id DESC LIMIT 1),
       (SELECT bill_no FROM latest),(SELECT bill_date FROM latest),(SELECT total_amount FROM latest),
       (SELECT count(*) FROM t_complaint WHERE society_id=p_society_id AND consumer_id=p_consumer_id AND lower(status) IN ('open','in progress')),
       coalesce(service.open_service,0)
FROM adj CROSS JOIN service;
$$;

CREATE OR REPLACE FUNCTION sp_customer_billing_history(p_society_id bigint,p_consumer_id bigint)
RETURNS TABLE(
 bill_id bigint,bill_no varchar,bill_date date,billing_period date,bill_type varchar,
 previous_balance numeric,current_bill numeric,adjustments numeric,payments numeric,net_amount numeric,
 due_date date,outstanding numeric,status varchar
)
LANGUAGE sql STABLE AS $$
SELECT b.bill_id,b.bill_no,b.bill_date,b.bill_month,'Regular',
       coalesce(l.previous_balance,0),b.total_amount,
       coalesce(a.amount,0),coalesce(pa.paid, b.paid_amount,0),
       b.total_amount+coalesce(a.amount,0),
       b.due_date,greatest(b.total_amount-b.paid_amount,0),b.status
FROM t_bill b
LEFT JOIN LATERAL (
 SELECT sum(greatest(x.total_amount-x.paid_amount,0)) previous_balance
 FROM t_bill x WHERE x.society_id=b.society_id AND x.consumer_id=b.consumer_id AND x.bill_date<b.bill_date
) l ON true
LEFT JOIN LATERAL (
 SELECT sum(CASE WHEN lower(adjustment_type) LIKE '%credit%' OR lower(adjustment_type) LIKE '%rebate%'
                  OR lower(adjustment_type) LIKE '%waiv%' OR lower(adjustment_type) LIKE '%discount%'
                THEN -amount ELSE amount END) amount
 FROM t_adjustment a WHERE a.society_id=b.society_id AND a.consumer_id=b.consumer_id AND a.bill_id=b.bill_id
) a ON true
LEFT JOIN LATERAL (
 SELECT sum(allocated_amount) paid FROM t_payment_allocation x
 WHERE x.society_id=b.society_id AND x.bill_id=b.bill_id AND x.consumer_id=b.consumer_id
) pa ON true
WHERE b.society_id=p_society_id AND b.consumer_id=p_consumer_id
ORDER BY b.bill_date DESC,b.bill_id DESC;
$$;

CREATE OR REPLACE FUNCTION sp_customer_payment_history(p_society_id bigint,p_consumer_id bigint)
RETURNS TABLE(
 payment_id bigint,receipt_no varchar,payment_no varchar,payment_date timestamptz,payment_mode varchar,
 reference_no varchar,amount numeric,against_bill varchar,collected_by varchar,remarks text,status varchar
)
LANGUAGE sql STABLE AS $$
SELECT p.payment_id,r.receipt_no,p.payment_no,p.payment_date,p.payment_mode,p.reference_no,p.amount,
       string_agg(DISTINCT b.bill_no,', ' ORDER BY b.bill_no),coalesce(u.display_name,''),p.remarks,p.status
FROM t_payment p
LEFT JOIN t_receipt r ON r.society_id=p.society_id AND r.payment_id=p.payment_id
LEFT JOIN t_payment_allocation pa ON pa.society_id=p.society_id AND pa.payment_id=p.payment_id
LEFT JOIN t_bill b ON b.society_id=pa.society_id AND b.bill_id=pa.bill_id
LEFT JOIN m_user u ON u.user_id=p.modified_by
WHERE p.society_id=p_society_id AND p.consumer_id=p_consumer_id
GROUP BY p.payment_id,r.receipt_no,p.payment_no,p.payment_date,p.payment_mode,p.reference_no,p.amount,p.remarks,p.status,u.display_name
ORDER BY p.payment_date DESC,p.payment_id DESC;
$$;

CREATE OR REPLACE FUNCTION sp_customer_service_history(p_society_id bigint,p_consumer_id bigint)
RETURNS TABLE(
 service_history_id bigint,service_no varchar,performed_at timestamptz,service_type varchar,category varchar,
 description text,status varchar,assigned_to varchar,resolution text,closed_date timestamptz,remarks varchar
)
LANGUAGE sql STABLE AS $$
SELECT h.service_history_id,h.reference_no,h.performed_at,h.event_type,h.event_sub_type,h.event_description,
       coalesce(h.event_data->>'status','Recorded'),coalesce(u.display_name,''),
       h.event_data->>'resolution',
       CASE WHEN h.event_data ? 'closedAt' THEN (h.event_data->>'closedAt')::timestamptz ELSE NULL END,
       h.modify_remark
FROM t_service_history h
LEFT JOIN m_user u ON u.user_id=h.performed_by
WHERE h.society_id=p_society_id AND h.consumer_id=p_consumer_id
ORDER BY h.performed_at DESC,h.service_history_id DESC;
$$;

CREATE OR REPLACE FUNCTION sp_customer_complaint_history(p_society_id bigint,p_consumer_id bigint)
RETURNS TABLE(
 complaint_id bigint,complaint_no varchar,complaint_date timestamptz,complaint_type varchar,subject varchar,
 description text,priority varchar,status varchar,assigned_to varchar,resolution text,resolved_date timestamptz,remarks varchar
)
LANGUAGE sql STABLE AS $$
SELECT c.complaint_id,c.complaint_no,c.created_at,c.category,c.title,c.description,c.priority,c.status,
       coalesce(u.display_name,''),c.resolution,c.resolved_at,coalesce(c.remarks,c.modify_remark)
FROM t_complaint c
LEFT JOIN m_user u ON u.user_id=c.assigned_to
WHERE c.society_id=p_society_id AND c.consumer_id=p_consumer_id
ORDER BY c.created_at DESC,c.complaint_id DESC;
$$;

CREATE OR REPLACE FUNCTION sp_customer_interaction_history(p_society_id bigint,p_consumer_id bigint)
RETURNS TABLE(
 interaction_id bigint,interaction_date timestamptz,interaction_type varchar,subject varchar,
 description text,employee_user varchar,outcome text,follow_up_date date,remarks text
)
LANGUAGE sql STABLE AS $$
SELECT i.interaction_id,i.interaction_date,i.interaction_type,i.subject,i.description,
       coalesce(u.display_name,''),i.outcome,i.follow_up_date,i.remarks
FROM t_customer_interaction i
LEFT JOIN m_user u ON u.user_id=i.employee_user_id
WHERE i.society_id=p_society_id AND i.consumer_id=p_consumer_id
ORDER BY i.interaction_date DESC,i.interaction_id DESC;
$$;

CREATE OR REPLACE FUNCTION sp_customer_adjustment_history(p_society_id bigint,p_consumer_id bigint)
RETURNS TABLE(
 adjustment_id bigint,adjustment_date timestamptz,adjustment_type varchar,reference_bill varchar,
 amount numeric,reason text,approved_by varchar,status varchar,remarks varchar
)
LANGUAGE sql STABLE AS $$
SELECT a.adjustment_id,a.created_at,a.adjustment_type,b.bill_no,a.amount,a.reason,
       coalesce(u.display_name,''),a.status,a.modify_remark
FROM t_adjustment a
LEFT JOIN t_bill b ON b.society_id=a.society_id AND b.bill_id=a.bill_id
LEFT JOIN m_user u ON u.user_id=a.approved_by
WHERE a.society_id=p_society_id AND a.consumer_id=p_consumer_id
ORDER BY a.created_at DESC,a.adjustment_id DESC;
$$;

CREATE OR REPLACE FUNCTION sp_customer_documents(p_society_id bigint,p_consumer_id bigint)
RETURNS TABLE(
 document_id bigint,document_name varchar,document_type varchar,uploaded_date timestamptz,
 uploaded_by varchar,status varchar,storage_path text
)
LANGUAGE sql STABLE AS $$
SELECT d.document_id,d.file_name,d.document_type,d.created_at,coalesce(u.display_name,''),'Available',d.storage_path
FROM t_document d
LEFT JOIN m_user u ON u.user_id=d.uploaded_by
WHERE d.society_id=p_society_id AND d.consumer_id=p_consumer_id
ORDER BY d.created_at DESC,d.document_id DESC;
$$;

CREATE OR REPLACE FUNCTION sp_customer_timeline(p_society_id bigint,p_consumer_id bigint)
RETURNS TABLE(
 event_at timestamptz,event_type varchar,event_title varchar,event_description text,reference_no varchar,amount numeric,status varchar
)
LANGUAGE sql STABLE AS $$
SELECT b.bill_date::timestamptz,'Billing','Bill Generated',('Bill '||b.bill_no),b.bill_no,b.total_amount,b.status
FROM t_bill b WHERE b.society_id=p_society_id AND b.consumer_id=p_consumer_id
UNION ALL
SELECT p.payment_date,'Payment','Payment Received',('Receipt '||coalesce(r.receipt_no,p.payment_no)),coalesce(r.receipt_no,p.payment_no),p.amount,p.status
FROM t_payment p LEFT JOIN t_receipt r ON r.society_id=p.society_id AND r.payment_id=p.payment_id
WHERE p.society_id=p_society_id AND p.consumer_id=p_consumer_id
UNION ALL
SELECT c.created_at,'Complaint','Complaint Raised',c.title,c.complaint_no,NULL,c.status
FROM t_complaint c WHERE c.society_id=p_society_id AND c.consumer_id=p_consumer_id
UNION ALL
SELECT c.resolved_at,'Complaint','Complaint Resolved',c.title,c.complaint_no,NULL,'Resolved'
FROM t_complaint c WHERE c.society_id=p_society_id AND c.consumer_id=p_consumer_id AND c.resolved_at IS NOT NULL
UNION ALL
SELECT h.performed_at,h.event_type,h.event_title,h.event_description,h.reference_no,
       NULL,coalesce(h.event_data->>'status','Recorded')
FROM t_service_history h WHERE h.society_id=p_society_id AND h.consumer_id=p_consumer_id
UNION ALL
SELECT a.created_at,'Adjustment','Adjustment Created',a.reason,b.bill_no,a.amount,'Recorded'
FROM t_adjustment a LEFT JOIN t_bill b ON b.society_id=a.society_id AND b.bill_id=a.bill_id
WHERE a.society_id=p_society_id AND a.consumer_id=p_consumer_id
UNION ALL
SELECT d.created_at,'Document','Document Uploaded',d.file_name,NULL,NULL,'Available'
FROM t_document d WHERE d.society_id=p_society_id AND d.consumer_id=p_consumer_id
UNION ALL
SELECT i.interaction_date,'Interaction',coalesce(i.subject,i.interaction_type),i.description,NULL,NULL,'Recorded'
FROM t_customer_interaction i WHERE i.society_id=p_society_id AND i.consumer_id=p_consumer_id
ORDER BY 1 DESC;
$$;

CREATE OR REPLACE FUNCTION sp_customer_account_full(p_society_id bigint,p_consumer_id bigint)
RETURNS jsonb
LANGUAGE sql STABLE AS $$
SELECT CASE WHEN EXISTS(
 SELECT 1 FROM m_customer WHERE society_id=p_society_id AND consumer_id=p_consumer_id
) THEN jsonb_build_object(
 'profile',coalesce((SELECT jsonb_agg(to_jsonb(x)) FROM sp_customer_account_get(p_society_id,p_consumer_id) x),'[]'::jsonb),
 'summary',coalesce((SELECT to_jsonb(x) FROM sp_customer_account_summary(p_society_id,p_consumer_id) x LIMIT 1),'{}'::jsonb),
 'billing',coalesce((SELECT jsonb_agg(to_jsonb(x)) FROM sp_customer_billing_history(p_society_id,p_consumer_id) x),'[]'::jsonb),
 'payments',coalesce((SELECT jsonb_agg(to_jsonb(x)) FROM sp_customer_payment_history(p_society_id,p_consumer_id) x),'[]'::jsonb),
 'serviceHistory',coalesce((SELECT jsonb_agg(to_jsonb(x)) FROM sp_customer_service_history(p_society_id,p_consumer_id) x),'[]'::jsonb),
 'complaints',coalesce((SELECT jsonb_agg(to_jsonb(x)) FROM sp_customer_complaint_history(p_society_id,p_consumer_id) x),'[]'::jsonb),
 'interactions',coalesce((SELECT jsonb_agg(to_jsonb(x)) FROM sp_customer_interaction_history(p_society_id,p_consumer_id) x),'[]'::jsonb),
 'adjustments',coalesce((SELECT jsonb_agg(to_jsonb(x)) FROM sp_customer_adjustment_history(p_society_id,p_consumer_id) x),'[]'::jsonb),
 'documents',coalesce((SELECT jsonb_agg(to_jsonb(x)) FROM sp_customer_documents(p_society_id,p_consumer_id) x),'[]'::jsonb),
 'timeline',coalesce((SELECT jsonb_agg(to_jsonb(x)) FROM sp_customer_timeline(p_society_id,p_consumer_id) x),'[]'::jsonb)
) ELSE NULL END;
$$;

CREATE OR REPLACE FUNCTION sp_customer_dues(p_society_id bigint,p_consumer_id bigint)
RETURNS TABLE(
 bill_id bigint,bill_no varchar,bill_date date,due_date date,total_amount numeric,paid_amount numeric,outstanding numeric,
 overdue_days integer,status varchar
)
LANGUAGE sql STABLE AS $$
SELECT b.bill_id,b.bill_no,b.bill_date,b.due_date,b.total_amount,b.paid_amount,
       greatest(b.total_amount-b.paid_amount,0),
       CASE WHEN b.due_date<current_date THEN current_date-b.due_date ELSE 0 END,
       b.status
FROM t_bill b
WHERE b.society_id=p_society_id AND b.consumer_id=p_consumer_id
  AND b.total_amount>b.paid_amount
ORDER BY b.due_date ASC,b.bill_date ASC,b.bill_id ASC;
$$;

CREATE OR REPLACE FUNCTION sp_customer_account_section(
 p_society_id bigint,p_consumer_id bigint,p_section varchar,p_search text DEFAULT '',p_limit integer DEFAULT 25,p_offset integer DEFAULT 0)
RETURNS jsonb
LANGUAGE plpgsql STABLE AS $$
DECLARE v_rows jsonb; v_total bigint;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM m_customer WHERE society_id=p_society_id AND consumer_id=p_consumer_id) THEN RETURN NULL; END IF;
 p_limit:=LEAST(GREATEST(coalesce(p_limit,25),1),100);
 p_offset:=GREATEST(coalesce(p_offset,0),0);
 CASE lower(p_section)
 WHEN 'billing' THEN
   SELECT count(*) INTO v_total FROM sp_customer_billing_history(p_society_id,p_consumer_id) x WHERE coalesce(x.bill_no,'') ILIKE '%'||coalesce(p_search,'')||'%' OR coalesce(x.status,'') ILIKE '%'||coalesce(p_search,'')||'%';
   SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) INTO v_rows FROM (SELECT * FROM sp_customer_billing_history(p_society_id,p_consumer_id) WHERE coalesce(bill_no,'') ILIKE '%'||coalesce(p_search,'')||'%' OR coalesce(status,'') ILIKE '%'||coalesce(p_search,'')||'%' LIMIT p_limit OFFSET p_offset) x;
 WHEN 'payments' THEN
   SELECT count(*) INTO v_total FROM sp_customer_payment_history(p_society_id,p_consumer_id) x WHERE coalesce(x.payment_no,'') ILIKE '%'||coalesce(p_search,'')||'%' OR coalesce(x.receipt_no,'') ILIKE '%'||coalesce(p_search,'')||'%' OR coalesce(x.reference_no,'') ILIKE '%'||coalesce(p_search,'')||'%';
   SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) INTO v_rows FROM (SELECT * FROM sp_customer_payment_history(p_society_id,p_consumer_id) WHERE coalesce(payment_no,'') ILIKE '%'||coalesce(p_search,'')||'%' OR coalesce(receipt_no,'') ILIKE '%'||coalesce(p_search,'')||'%' OR coalesce(reference_no,'') ILIKE '%'||coalesce(p_search,'')||'%' LIMIT p_limit OFFSET p_offset) x;
 WHEN 'dues' THEN
   SELECT count(*) INTO v_total FROM sp_customer_dues(p_society_id,p_consumer_id) x WHERE coalesce(x.bill_no,'') ILIKE '%'||coalesce(p_search,'')||'%' OR coalesce(x.status,'') ILIKE '%'||coalesce(p_search,'')||'%';
   SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) INTO v_rows FROM (SELECT * FROM sp_customer_dues(p_society_id,p_consumer_id) WHERE coalesce(bill_no,'') ILIKE '%'||coalesce(p_search,'')||'%' OR coalesce(status,'') ILIKE '%'||coalesce(p_search,'')||'%' LIMIT p_limit OFFSET p_offset) x;
 WHEN 'service' THEN
   SELECT count(*) INTO v_total FROM sp_customer_service_history(p_society_id,p_consumer_id) x WHERE coalesce(x.service_no,'') ILIKE '%'||coalesce(p_search,'')||'%' OR coalesce(x.service_type,'') ILIKE '%'||coalesce(p_search,'')||'%' OR coalesce(x.description,'') ILIKE '%'||coalesce(p_search,'')||'%';
   SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) INTO v_rows FROM (SELECT * FROM sp_customer_service_history(p_society_id,p_consumer_id) WHERE coalesce(service_no,'') ILIKE '%'||coalesce(p_search,'')||'%' OR coalesce(service_type,'') ILIKE '%'||coalesce(p_search,'')||'%' OR coalesce(description,'') ILIKE '%'||coalesce(p_search,'')||'%' LIMIT p_limit OFFSET p_offset) x;
 WHEN 'complaints' THEN
   SELECT count(*) INTO v_total FROM sp_customer_complaint_history(p_society_id,p_consumer_id) x WHERE coalesce(x.complaint_no,'') ILIKE '%'||coalesce(p_search,'')||'%' OR coalesce(x.subject,'') ILIKE '%'||coalesce(p_search,'')||'%' OR coalesce(x.status,'') ILIKE '%'||coalesce(p_search,'')||'%';
   SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) INTO v_rows FROM (SELECT * FROM sp_customer_complaint_history(p_society_id,p_consumer_id) WHERE coalesce(complaint_no,'') ILIKE '%'||coalesce(p_search,'')||'%' OR coalesce(subject,'') ILIKE '%'||coalesce(p_search,'')||'%' OR coalesce(status,'') ILIKE '%'||coalesce(p_search,'')||'%' LIMIT p_limit OFFSET p_offset) x;
 WHEN 'interactions' THEN
   SELECT count(*) INTO v_total FROM sp_customer_interaction_history(p_society_id,p_consumer_id) x WHERE coalesce(x.interaction_type,'') ILIKE '%'||coalesce(p_search,'')||'%' OR coalesce(x.subject,'') ILIKE '%'||coalesce(p_search,'')||'%';
   SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) INTO v_rows FROM (SELECT * FROM sp_customer_interaction_history(p_society_id,p_consumer_id) WHERE coalesce(interaction_type,'') ILIKE '%'||coalesce(p_search,'')||'%' OR coalesce(subject,'') ILIKE '%'||coalesce(p_search,'')||'%' LIMIT p_limit OFFSET p_offset) x;
 WHEN 'adjustments' THEN
   SELECT count(*) INTO v_total FROM sp_customer_adjustment_history(p_society_id,p_consumer_id) x WHERE coalesce(x.adjustment_type,'') ILIKE '%'||coalesce(p_search,'')||'%' OR coalesce(x.reference_bill,'') ILIKE '%'||coalesce(p_search,'')||'%';
   SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) INTO v_rows FROM (SELECT * FROM sp_customer_adjustment_history(p_society_id,p_consumer_id) WHERE coalesce(adjustment_type,'') ILIKE '%'||coalesce(p_search,'')||'%' OR coalesce(reference_bill,'') ILIKE '%'||coalesce(p_search,'')||'%' LIMIT p_limit OFFSET p_offset) x;
 WHEN 'documents' THEN
   SELECT count(*) INTO v_total FROM sp_customer_documents(p_society_id,p_consumer_id) x WHERE coalesce(x.document_name,'') ILIKE '%'||coalesce(p_search,'')||'%' OR coalesce(x.document_type,'') ILIKE '%'||coalesce(p_search,'')||'%';
   SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) INTO v_rows FROM (SELECT * FROM sp_customer_documents(p_society_id,p_consumer_id) WHERE coalesce(document_name,'') ILIKE '%'||coalesce(p_search,'')||'%' OR coalesce(document_type,'') ILIKE '%'||coalesce(p_search,'')||'%' LIMIT p_limit OFFSET p_offset) x;
 WHEN 'timeline' THEN
   SELECT count(*) INTO v_total FROM sp_customer_timeline(p_society_id,p_consumer_id) x WHERE coalesce(x.event_title,'') ILIKE '%'||coalesce(p_search,'')||'%' OR coalesce(x.event_type,'') ILIKE '%'||coalesce(p_search,'')||'%';
   SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) INTO v_rows FROM (SELECT * FROM sp_customer_timeline(p_society_id,p_consumer_id) WHERE coalesce(event_title,'') ILIKE '%'||coalesce(p_search,'')||'%' OR coalesce(event_type,'') ILIKE '%'||coalesce(p_search,'')||'%' LIMIT p_limit OFFSET p_offset) x;
 ELSE RAISE EXCEPTION 'Unsupported customer account section: %',p_section;
 END CASE;
 RETURN jsonb_build_object('rows',v_rows,'total',v_total,'page_size',p_limit,'offset',p_offset);
END $$;
