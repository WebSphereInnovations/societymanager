-- Society360 requested-module hardening and audit consistency
DO $$
DECLARE r record;
BEGIN
 FOR r IN
  SELECT table_schema,table_name
  FROM information_schema.tables
  WHERE table_schema='society_manager' AND table_type='BASE TABLE'
 LOOP
  IF NOT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema=r.table_schema AND table_name=r.table_name AND column_name='modify_by') THEN
   EXECUTE format('ALTER TABLE %I.%I ADD COLUMN modify_by bigint REFERENCES society_manager.m_user(user_id)',r.table_schema,r.table_name);
  END IF;
  IF NOT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema=r.table_schema AND table_name=r.table_name AND column_name='modify_date') THEN
   EXECUTE format('ALTER TABLE %I.%I ADD COLUMN modify_date timestamptz NOT NULL DEFAULT now()',r.table_schema,r.table_name);
  END IF;
  IF NOT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema=r.table_schema AND table_name=r.table_name AND column_name='modify_remark') THEN
   EXECUTE format('ALTER TABLE %I.%I ADD COLUMN modify_remark text DEFAULT ''''',r.table_schema,r.table_name);
  END IF;
 END LOOP;
END $$;

CREATE INDEX IF NOT EXISTS ix_m_customer_society_name ON m_customer(society_id,lower(full_name));
CREATE INDEX IF NOT EXISTS ix_m_customer_society_phone ON m_customer(society_id,phone);
CREATE INDEX IF NOT EXISTS ix_m_flat_society_flat_no ON m_flat(society_id,lower(flat_no));

DROP FUNCTION IF EXISTS fn_customer_search_requested(bigint,varchar);
CREATE FUNCTION fn_customer_search_requested(p_society_id bigint,p_search varchar)
RETURNS TABLE(customer_id bigint,customer_code varchar,full_name varchar,phone varchar,email varchar,flat_count bigint,flat_numbers text,current_dues numeric,next_due_date date,due_status varchar)
LANGUAGE sql AS $$
WITH x AS (
 SELECT c.customer_id,c.customer_code,c.full_name,c.phone,c.email,count(DISTINCT cf.flat_id) flat_count,
 string_agg(DISTINCT f.flat_no,', ' ORDER BY f.flat_no) flat_numbers,
 COALESCE((SELECT sum(GREATEST(b.total_amount-b.paid_amount,0)) FROM t_bill b WHERE b.society_id=p_society_id AND b.flat_id IN(SELECT flat_id FROM m_customer_flat WHERE customer_id=c.customer_id AND society_id=p_society_id) AND b.status NOT IN('Paid','Cancelled')),0)
 + COALESCE((SELECT sum(sc.amount) FROM t_service_charge sc WHERE sc.society_id=p_society_id AND sc.customer_id=c.customer_id AND sc.status IN('Pending','Success')),0) current_dues,
 (SELECT min(b.due_date) FROM t_bill b WHERE b.society_id=p_society_id AND b.flat_id IN(SELECT flat_id FROM m_customer_flat WHERE customer_id=c.customer_id AND society_id=p_society_id) AND b.status NOT IN('Paid','Cancelled')) next_due_date
 FROM m_customer c
 LEFT JOIN m_customer_flat cf ON cf.customer_id=c.customer_id AND cf.society_id=p_society_id
 LEFT JOIN m_flat f ON f.flat_id=cf.flat_id AND f.society_id=p_society_id
 WHERE c.society_id=p_society_id AND c.is_active
 AND (coalesce(p_search,'')='' OR c.full_name ILIKE '%'||p_search||'%' OR c.phone ILIKE '%'||p_search||'%' OR c.customer_code ILIKE '%'||p_search||'%' OR f.flat_no ILIKE '%'||p_search||'%')
 GROUP BY c.customer_id,c.customer_code,c.full_name,c.phone,c.email
)
SELECT x.*,CASE WHEN x.next_due_date IS NULL THEN 'NO_DUE' WHEN current_date<x.next_due_date THEN 'BEFORE_DUE' WHEN current_date=x.next_due_date THEN 'DUE_TODAY' ELSE 'OVERDUE' END
FROM x ORDER BY x.full_name;
$$;
CREATE OR REPLACE FUNCTION fn_consumer_account_full(p_society_id bigint,p_customer_id bigint)
RETURNS jsonb LANGUAGE sql AS $$
SELECT jsonb_build_object(
 'customer',to_jsonb(c),
 'flats',COALESCE((SELECT jsonb_agg(jsonb_build_object('flat_id',f.flat_id,'flat_no',f.flat_no,'wing',w.wing_name,'building',b.building_name,'area_sqft',f.area_sqft,'unit_type',f.unit_type,'relation',cf.relation_type)) FROM m_customer_flat cf JOIN m_flat f ON f.flat_id=cf.flat_id AND f.society_id=p_society_id LEFT JOIN m_wing w ON w.wing_id=f.wing_id AND w.society_id=p_society_id LEFT JOIN m_building b ON b.building_id=f.building_id AND b.society_id=p_society_id WHERE cf.society_id=p_society_id AND cf.customer_id=p_customer_id),'[]'::jsonb),
 'parking',COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM (SELECT pa.parking_slot_id,ps.slot_no,ps.slot_type,ps.charge,pa.start_date,pa.end_date FROM t_parking_assignment pa JOIN m_parking_slot ps ON ps.parking_slot_id=pa.parking_slot_id AND ps.society_id=p_society_id WHERE pa.society_id=p_society_id AND pa.customer_id=p_customer_id AND pa.is_active)x),'[]'::jsonb),
 'vehicles',COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM (SELECT vehicle_id,registration_no,vehicle_type,parking_slot_id FROM m_vehicle WHERE society_id=p_society_id AND customer_id=p_customer_id AND is_active)x),'[]'::jsonb),
 'dues',COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM (SELECT bill_id,bill_no,bill_month,bill_date,due_date,subtotal,tax_amount,rebate_amount,dpc_amount,total_amount,paid_amount,status,CASE WHEN current_date<due_date THEN 'BEFORE_DUE' WHEN current_date=due_date THEN 'DUE_TODAY' ELSE 'OVERDUE' END due_status FROM t_bill WHERE society_id=p_society_id AND flat_id IN(SELECT flat_id FROM m_customer_flat WHERE customer_id=p_customer_id AND society_id=p_society_id) ORDER BY bill_date DESC LIMIT 100)x),'[]'::jsonb),
 'payments',COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM (SELECT payment_id,payment_no,payment_date,amount,payment_mode,reference_no,status,remarks FROM t_payment WHERE society_id=p_society_id AND customer_id=p_customer_id ORDER BY payment_date DESC LIMIT 100)x),'[]'::jsonb),
 'adjustments',COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM (SELECT adjustment_id,flat_id,bill_id,adjustment_type,amount,reason,approved_by,created_at FROM t_adjustment WHERE society_id=p_society_id AND flat_id IN(SELECT flat_id FROM m_customer_flat WHERE customer_id=p_customer_id AND society_id=p_society_id) ORDER BY created_at DESC LIMIT 100)x),'[]'::jsonb),
 'complaints',COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM (SELECT complaint_id,complaint_no,category,title,description,priority,status,created_at,resolved_at FROM t_complaint WHERE society_id=p_society_id AND customer_id=p_customer_id ORDER BY created_at DESC LIMIT 100)x),'[]'::jsonb),
 'service_history',COALESCE((
   SELECT jsonb_agg(to_jsonb(x) ORDER BY x.changed_at DESC) FROM (
    SELECT service_attribute_history_id history_id,attribute_name,old_value,new_value,changed_at,changed_by,remarks,'ATTRIBUTE_UPDATE' history_type
    FROM t_customer_service_attribute_history WHERE society_id=p_society_id AND customer_id=p_customer_id
    UNION ALL
    SELECT sc.service_charge_id,st.charge_name,NULL,NULL,sc.charge_date,sc.created_by,sc.remarks,'SERVICE_PAYMENT'
    FROM t_service_charge sc JOIN m_service_charge_type st ON st.service_charge_type_id=sc.service_charge_type_id AND st.society_id=p_society_id
    WHERE sc.society_id=p_society_id AND sc.customer_id=p_customer_id
    UNION ALL
    SELECT dc.dishonored_cheque_id,'Dishonour Cheque Charges',NULL,dc.due_amount::text,dc.dishonored_date,dc.created_by,dc.remarks,'DISHONOURED_CHEQUE'
    FROM t_dishonored_cheque dc WHERE dc.society_id=p_society_id AND dc.customer_id=p_customer_id
   ) x
 ),'[]'::jsonb),
 'documents',COALESCE((SELECT jsonb_agg(jsonb_build_object('document_id',d.document_id,'document_type',dt.document_name,'file_name',d.file_name,'uploaded_at',d.uploaded_at,'uploaded_by',d.uploaded_by,'flat_id',d.flat_id)) FROM t_customer_document d JOIN m_document_type dt ON dt.document_type_id=d.document_type_id AND dt.society_id=p_society_id WHERE d.society_id=p_society_id AND d.customer_id=p_customer_id AND d.is_active AND d.visible),'[]'::jsonb),
 'notifications',COALESCE((SELECT jsonb_agg(to_jsonb(n)) FROM (SELECT notification_id,notification_type,title,message,reference_entity,reference_id,is_read,created_at FROM t_notification WHERE society_id=p_society_id AND (recipient_user_id IS NULL OR recipient_user_id IN(SELECT user_id FROM m_user WHERE society_id=p_society_id AND user_id=(SELECT user_id FROM m_customer WHERE customer_id=p_customer_id AND society_id=p_society_id))) ORDER BY created_at DESC LIMIT 50)n),'[]'::jsonb),
 'current_dues',(
   COALESCE((SELECT sum(GREATEST(b.total_amount-b.paid_amount,0)) FROM t_bill b WHERE b.society_id=p_society_id AND b.flat_id IN(SELECT flat_id FROM m_customer_flat WHERE customer_id=p_customer_id AND society_id=p_society_id) AND b.status NOT IN('Paid','Cancelled')),0)
   + COALESCE((SELECT sum(sc.amount) FROM t_service_charge sc WHERE sc.society_id=p_society_id AND sc.customer_id=p_customer_id AND sc.status IN('Pending','Success')),0)
 ),
 'due_status',CASE WHEN (SELECT min(b.due_date) FROM t_bill b WHERE b.society_id=p_society_id AND b.flat_id IN(SELECT flat_id FROM m_customer_flat WHERE customer_id=p_customer_id AND society_id=p_society_id) AND b.status NOT IN('Paid','Cancelled')) IS NULL THEN 'NO_DUE'
 ELSE CASE WHEN current_date<(SELECT min(b.due_date) FROM t_bill b WHERE b.society_id=p_society_id AND b.flat_id IN(SELECT flat_id FROM m_customer_flat WHERE customer_id=p_customer_id AND society_id=p_society_id) AND b.status NOT IN('Paid','Cancelled')) THEN 'BEFORE_DUE' WHEN current_date=(SELECT min(b.due_date) FROM t_bill b WHERE b.society_id=p_society_id AND b.flat_id IN(SELECT flat_id FROM m_customer_flat WHERE customer_id=p_customer_id AND society_id=p_society_id) AND b.status NOT IN('Paid','Cancelled')) THEN 'DUE_TODAY' ELSE 'OVERDUE' END END
) FROM m_customer c WHERE c.society_id=p_society_id AND c.customer_id=p_customer_id AND c.is_active;
$$;

CREATE OR REPLACE FUNCTION sp_record_dishonored_cheque(p_society_id bigint,p_payment_id bigint,p_reason_id bigint,p_bank_charge numeric,p_user_id bigint,p_remarks text)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_id bigint; v_customer bigint; v_flat bigint; v_amt numeric; v_due numeric;
BEGIN
 SELECT customer_id,flat_id,amount INTO v_customer,v_flat,v_amt FROM t_payment WHERE payment_id=p_payment_id AND society_id=p_society_id AND payment_mode='CHEQUE' AND status<>'Dishonored';
 IF NOT FOUND THEN RAISE EXCEPTION 'Cheque payment not found in selected society'; END IF;
 IF EXISTS(SELECT 1 FROM t_dishonored_cheque WHERE society_id=p_society_id AND payment_id=p_payment_id) THEN RAISE EXCEPTION 'Cheque is already marked as dishonored'; END IF;
 IF NOT EXISTS(SELECT 1 FROM m_cheque_dishonor_reason WHERE society_id=p_society_id AND dishonor_reason_id=p_reason_id AND is_active AND visible) THEN RAISE EXCEPTION 'Invalid dishonor reason for selected society'; END IF;
 v_due:=v_amt+coalesce(p_bank_charge,0);
 INSERT INTO t_dishonored_cheque(society_id,payment_id,customer_id,flat_id,dishonor_reason_id,bank_charge,due_amount,created_by,remarks)
 VALUES(p_society_id,p_payment_id,v_customer,v_flat,p_reason_id,coalesce(p_bank_charge,0),v_due,p_user_id,p_remarks) RETURNING dishonored_cheque_id INTO v_id;
 UPDATE t_payment SET status='Dishonored',modify_by=p_user_id,modify_date=now(),modify_remark=coalesce(p_remarks,'') WHERE payment_id=p_payment_id AND society_id=p_society_id;
 INSERT INTO t_service_charge(society_id,customer_id,flat_id,service_charge_type_id,amount,reference_no,remarks,status,created_by,modify_by,modify_date,modify_remark)
 SELECT p_society_id,v_customer,v_flat,service_charge_type_id,v_due,'CHEQUE-'||p_payment_id,'Dishonored Cheque Charges','Pending',p_user_id,p_user_id,now(),coalesce(p_remarks,'')
 FROM m_service_charge_type WHERE society_id=p_society_id AND charge_code='DISHONORED_CHEQUE' AND visible AND is_active;
 INSERT INTO t_notification(society_id,recipient_user_id,customer_id,notification_type,title,message,reference_entity,reference_id,channel,status)
 SELECT p_society_id,u.user_id,v_customer,'CHEQUE_DISHONORED','Dishonored Cheque','Cheque payment was dishonored and the unpaid amount was added to dues.','DISHONORED_CHEQUE',v_id,'APP','Pending'
 FROM m_user u WHERE u.society_id=p_society_id AND u.role_code='SOCIETY_ADMIN' AND u.is_active;
 RETURN v_id;
END; $$;
CREATE OR REPLACE FUNCTION fn_cheque_dishonor_reasons(p_society_id bigint)
RETURNS TABLE(dishonor_reason_id bigint,reason_code varchar,reason_name varchar)
LANGUAGE sql AS $$
SELECT dishonor_reason_id,reason_code,reason_name FROM m_cheque_dishonor_reason
WHERE society_id=p_society_id AND is_active AND visible ORDER BY reason_name;
$$;

CREATE OR REPLACE FUNCTION fn_bank_details(p_society_id bigint)
RETURNS TABLE(bank_detail_id bigint,bank_name varchar,account_name varchar,account_number varchar,ifsc_code varchar,branch_name varchar,account_type varchar,upi_id varchar,is_active boolean)
LANGUAGE sql AS $$
SELECT bank_detail_id,bank_name,account_name,account_number,ifsc_code,branch_name,account_type,upi_id,is_active
FROM m_bank_detail WHERE society_id=p_society_id ORDER BY bank_name,bank_detail_id;
$$;

CREATE OR REPLACE FUNCTION fn_customer_service_history_requested(p_society_id bigint,p_customer_id bigint)
RETURNS TABLE(history_id bigint,attribute_name varchar,old_value text,new_value text,changed_at timestamptz,changed_by bigint,remarks text)
LANGUAGE sql AS $$
SELECT history_id,attribute_name,old_value,new_value,changed_at,changed_by,remarks
FROM (
 SELECT service_attribute_history_id history_id,attribute_name,old_value,new_value,changed_at,changed_by,remarks
 FROM t_customer_service_attribute_history WHERE society_id=p_society_id AND customer_id=p_customer_id
 UNION ALL
 SELECT sc.service_charge_id,st.charge_name,NULL,NULL,sc.charge_date,sc.created_by,sc.remarks
 FROM t_service_charge sc JOIN m_service_charge_type st ON st.service_charge_type_id=sc.service_charge_type_id AND st.society_id=p_society_id
 WHERE sc.society_id=p_society_id AND sc.customer_id=p_customer_id
 UNION ALL
 SELECT dc.dishonored_cheque_id,'Dishonour Cheque Charges',NULL,dc.due_amount::text,dc.dishonored_date,dc.created_by,dc.remarks
 FROM t_dishonored_cheque dc WHERE dc.society_id=p_society_id AND dc.customer_id=p_customer_id
) x ORDER BY changed_at DESC;
$$;

DROP FUNCTION IF EXISTS fn_collection_consumer_search(bigint,varchar);
CREATE FUNCTION fn_collection_consumer_search(p_society_id bigint,p_search varchar)
RETURNS TABLE(customer_id bigint,customer_code varchar,full_name varchar,phone varchar,email varchar,flat_id bigint,flat_no varchar,wing_name varchar,current_dues numeric,due_date date,last_bill_date date,last_bill_amount numeric,due_status varchar)
LANGUAGE sql AS $$
WITH q AS (
 SELECT c.customer_id,c.customer_code,c.full_name,c.phone,c.email,f.flat_id,f.flat_no,w.wing_name,
 COALESCE((SELECT sum(GREATEST(b.total_amount-b.paid_amount,0)) FROM t_bill b WHERE b.society_id=p_society_id AND b.flat_id=f.flat_id AND b.status NOT IN('Paid','Cancelled')),0)
 + COALESCE((SELECT sum(sc.amount) FROM t_service_charge sc WHERE sc.society_id=p_society_id AND sc.customer_id=c.customer_id AND sc.flat_id=f.flat_id AND sc.status IN('Pending','Success')),0) current_dues,
 (SELECT min(b.due_date) FROM t_bill b WHERE b.society_id=p_society_id AND b.flat_id=f.flat_id AND b.status NOT IN('Paid','Cancelled')) due_date,
 (SELECT max(b.bill_date) FROM t_bill b WHERE b.society_id=p_society_id AND b.flat_id=f.flat_id) last_bill_date,
 (SELECT max(b.total_amount) FROM t_bill b WHERE b.society_id=p_society_id AND b.flat_id=f.flat_id) last_bill_amount
 FROM m_customer c JOIN m_customer_flat cf ON cf.customer_id=c.customer_id AND cf.society_id=p_society_id
 JOIN m_flat f ON f.flat_id=cf.flat_id AND f.society_id=p_society_id LEFT JOIN m_wing w ON w.wing_id=f.wing_id AND w.society_id=p_society_id
 WHERE c.society_id=p_society_id AND c.is_active
 AND (coalesce(p_search,'')='' OR c.full_name ILIKE '%'||p_search||'%' OR c.phone ILIKE '%'||p_search||'%' OR c.customer_code ILIKE '%'||p_search||'%' OR f.flat_no ILIKE '%'||p_search||'%')
)
SELECT q.*,CASE WHEN q.due_date IS NULL THEN 'NO_DUE' WHEN current_date<q.due_date THEN 'BEFORE_DUE' WHEN current_date=q.due_date THEN 'DUE_TODAY' ELSE 'OVERDUE' END FROM q ORDER BY full_name,flat_no;
$$;
CREATE OR REPLACE FUNCTION fn_document_content(p_society_id bigint,p_document_id bigint)
RETURNS TABLE(file_name varchar,content_type varchar,file_data bytea)
LANGUAGE sql AS $$
SELECT d.file_name,d.content_type,d.file_data
FROM t_customer_document d
JOIN m_document_type dt ON dt.document_type_id=d.document_type_id AND dt.society_id=p_society_id AND dt.is_active AND dt.visible
WHERE d.society_id=p_society_id AND d.document_id=p_document_id AND d.is_active AND d.visible;
$$;

DROP FUNCTION IF EXISTS fn_customer_documents(bigint,bigint);
CREATE FUNCTION fn_customer_documents(p_society_id bigint,p_customer_id bigint)
RETURNS TABLE(document_id bigint,document_type varchar,file_name varchar,content_type varchar,file_size bigint,uploaded_at timestamptz,uploaded_by bigint,flat_no varchar)
LANGUAGE sql AS $$
SELECT d.document_id,dt.document_name,d.file_name,d.content_type,d.file_size,d.uploaded_at,d.uploaded_by,f.flat_no
FROM t_customer_document d JOIN m_document_type dt ON dt.document_type_id=d.document_type_id AND dt.society_id=p_society_id
LEFT JOIN m_flat f ON f.flat_id=d.flat_id AND f.society_id=p_society_id
WHERE d.society_id=p_society_id AND d.customer_id=p_customer_id AND d.is_active AND d.visible ORDER BY d.uploaded_at DESC;
$$;

CREATE OR REPLACE FUNCTION fn_notifications(p_society_id bigint,p_user_id bigint)
RETURNS TABLE(notification_id bigint,notification_type varchar,title varchar,message text,reference_entity varchar,reference_id bigint,is_read boolean,created_at timestamptz)
LANGUAGE sql AS $$
SELECT notification_id,notification_type,title,message,reference_entity,reference_id,is_read,created_at
FROM t_notification
WHERE society_id=p_society_id AND (recipient_user_id=p_user_id OR (recipient_user_id IS NULL AND user_id=p_user_id))
ORDER BY created_at DESC;
$$;
CREATE OR REPLACE FUNCTION sp_accept_payment(p_society_id bigint,p_customer_id bigint,p_flat_id bigint,p_amount numeric,p_payment_mode varchar,p_reference varchar,p_remarks text,p_user_id bigint)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_payment bigint; v_no varchar; v_receipt varchar; v_receipt_id bigint; v_payment_date timestamptz:=now();
BEGIN
 IF NOT EXISTS(SELECT 1 FROM m_customer WHERE customer_id=p_customer_id AND society_id=p_society_id AND is_active) THEN RAISE EXCEPTION 'Customer not found in selected society'; END IF;
 IF NOT EXISTS(SELECT 1 FROM m_customer_flat WHERE customer_id=p_customer_id AND flat_id=p_flat_id AND society_id=p_society_id) THEN RAISE EXCEPTION 'Customer is not linked to selected flat'; END IF;
 IF NOT EXISTS(SELECT 1 FROM m_flat WHERE flat_id=p_flat_id AND society_id=p_society_id AND is_active) THEN RAISE EXCEPTION 'Flat not found in selected society'; END IF;
 IF p_amount<=0 THEN RAISE EXCEPTION 'Payment amount must be greater than zero'; END IF;
 IF NOT EXISTS(SELECT 1 FROM m_collection_payment_mode WHERE society_id=p_society_id AND payment_mode_code=p_payment_mode AND visible AND is_active) THEN RAISE EXCEPTION 'Payment mode is not available'; END IF;
 v_no='PAY-'||to_char(clock_timestamp(),'YYYYMMDDHH24MISSMS');
 INSERT INTO t_payment(society_id,customer_id,flat_id,payment_no,amount,payment_mode,reference_no,remarks,status,modify_by,modify_date,modify_remark)
 VALUES(p_society_id,p_customer_id,p_flat_id,v_no,p_amount,p_payment_mode,p_reference,p_remarks,'Success',p_user_id,now(),coalesce(p_remarks,'')) RETURNING payment_id,payment_date INTO v_payment,v_payment_date;
 v_receipt='RCT-'||to_char(clock_timestamp(),'YYYYMMDDHH24MISSMS');
 INSERT INTO t_receipt(society_id,payment_id,receipt_no,amount,modify_by,modify_date,modify_remark) VALUES(p_society_id,v_payment,v_receipt,p_amount,p_user_id,now(),coalesce(p_remarks,'')) RETURNING receipt_id INTO v_receipt_id;
 UPDATE t_bill b SET paid_amount=LEAST(b.total_amount,b.paid_amount+p_amount),status=CASE WHEN b.paid_amount+p_amount>=b.total_amount THEN 'Paid' ELSE 'Partial' END,modify_by=p_user_id,modify_date=now(),modify_remark=coalesce(p_remarks,'')
 WHERE b.society_id=p_society_id AND b.flat_id=p_flat_id AND b.status NOT IN('Paid','Cancelled') AND b.total_amount>b.paid_amount
 AND b.bill_id=(SELECT bill_id FROM t_bill WHERE society_id=p_society_id AND flat_id=p_flat_id AND status NOT IN('Paid','Cancelled') AND total_amount>paid_amount ORDER BY due_date,bill_date LIMIT 1);
 RETURN v_payment;
END; $$;

CREATE OR REPLACE FUNCTION sp_save_service_charge(p_society_id bigint,p_customer_id bigint,p_flat_id bigint,p_type_id bigint,p_amount numeric,p_reference varchar,p_remarks text,p_user bigint)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_id bigint;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM m_customer WHERE customer_id=p_customer_id AND society_id=p_society_id AND is_active) THEN RAISE EXCEPTION 'Customer not found in selected society'; END IF;
 IF p_flat_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM m_customer_flat WHERE customer_id=p_customer_id AND flat_id=p_flat_id AND society_id=p_society_id) THEN RAISE EXCEPTION 'Customer is not linked to selected flat'; END IF;
 IF NOT EXISTS(SELECT 1 FROM m_service_charge_type WHERE service_charge_type_id=p_type_id AND society_id=p_society_id AND is_active AND visible) THEN RAISE EXCEPTION 'Service charge type not found'; END IF;
 IF p_amount<=0 THEN RAISE EXCEPTION 'Service payment amount must be greater than zero'; END IF;
 INSERT INTO t_service_charge(society_id,customer_id,flat_id,service_charge_type_id,amount,reference_no,remarks,created_by,modify_by,modify_date,modify_remark)
 VALUES(p_society_id,p_customer_id,p_flat_id,p_type_id,p_amount,p_reference,p_remarks,p_user,p_user,now(),coalesce(p_remarks,'')) RETURNING service_charge_id INTO v_id;
 RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION sp_delete_customer_document(p_society_id bigint,p_document_id bigint,p_user_id bigint,p_remark text)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_id bigint;
BEGIN
 UPDATE t_customer_document SET is_active=false,visible=false,modify_by=p_user_id,modify_date=now(),modify_remark=coalesce(p_remark,'')
 WHERE society_id=p_society_id AND document_id=p_document_id AND is_active RETURNING document_id INTO v_id;
 IF v_id IS NULL THEN RAISE EXCEPTION 'Document not found in selected society'; END IF;
 RETURN v_id;
END; $$;
