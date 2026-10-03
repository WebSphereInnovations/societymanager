-- Requested submenu workflow hardening
CREATE TABLE IF NOT EXISTS society_manager.m_complaint_status(
 complaint_status_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 society_id bigint NOT NULL REFERENCES society_manager.m_society(society_id),
 status_code varchar(40) NOT NULL,
 status_name varchar(100) NOT NULL,
 status_order integer NOT NULL DEFAULT 0,
 visible boolean NOT NULL DEFAULT true,
 is_active boolean NOT NULL DEFAULT true,
 modify_by bigint REFERENCES society_manager.m_user(user_id),
 modify_date timestamptz NOT NULL DEFAULT now(),
 modify_remark text DEFAULT '',
 UNIQUE(society_id,status_code)
);
INSERT INTO society_manager.m_complaint_status(society_id,status_code,status_name,status_order,visible,is_active)
SELECT s.society_id,x.code,x.name,x.ord,true,true
FROM society_manager.m_society s
CROSS JOIN (VALUES('NEW','New',1),('ASSIGNED','Assigned',2),('IN_PROCESS','In Process',3),('RESOLVED','Resolved',4),('CLOSED','Closed',5)) x(code,name,ord)
ON CONFLICT(society_id,status_code) DO UPDATE SET status_name=excluded.status_name,status_order=excluded.status_order,visible=true,is_active=true;
CREATE OR REPLACE FUNCTION society_manager.fn_complaint_statuses(p_society_id bigint)
RETURNS TABLE(complaint_status_id bigint,status_code varchar,status_name varchar,status_order integer)
LANGUAGE sql AS $$
SELECT complaint_status_id,status_code,status_name,status_order FROM society_manager.m_complaint_status
WHERE society_id=p_society_id AND visible AND is_active ORDER BY status_order;
$$;
ALTER TABLE society_manager.t_payment ADD COLUMN IF NOT EXISTS cheque_no varchar(80);
ALTER TABLE society_manager.t_payment ADD COLUMN IF NOT EXISTS cheque_date date;
ALTER TABLE society_manager.t_payment ADD COLUMN IF NOT EXISTS cheque_bank varchar(160);
CREATE UNIQUE INDEX IF NOT EXISTS ux_t_payment_society_cheque_no ON society_manager.t_payment(society_id,cheque_no) WHERE cheque_no IS NOT NULL;
ALTER TABLE society_manager.t_service_charge ADD COLUMN IF NOT EXISTS payment_mode varchar(30);
ALTER TABLE society_manager.t_it_ticket ADD COLUMN IF NOT EXISTS attachment_name varchar(255);
ALTER TABLE society_manager.t_it_ticket ADD COLUMN IF NOT EXISTS attachment_content_type varchar(120);
ALTER TABLE society_manager.t_it_ticket ADD COLUMN IF NOT EXISTS attachment_data bytea;
ALTER TABLE society_manager.t_it_ticket ADD COLUMN IF NOT EXISTS modify_by bigint REFERENCES society_manager.m_user(user_id);
ALTER TABLE society_manager.t_it_ticket ADD COLUMN IF NOT EXISTS modify_date timestamptz NOT NULL DEFAULT now();
ALTER TABLE society_manager.t_it_ticket ADD COLUMN IF NOT EXISTS modify_remark text DEFAULT '';

DROP FUNCTION IF EXISTS society_manager.sp_accept_payment(bigint,bigint,bigint,numeric,varchar,varchar,text,timestamptz,bigint);
DROP FUNCTION IF EXISTS society_manager.sp_accept_payment(bigint,bigint,bigint,numeric,varchar,varchar,text,timestamptz,varchar,date,varchar,bigint);
CREATE OR REPLACE FUNCTION society_manager.sp_accept_payment(p_society_id bigint,p_customer_id bigint,p_flat_id bigint,p_amount numeric,p_payment_mode varchar,p_reference varchar,p_remarks text,p_payment_date timestamptz,p_cheque_no varchar,p_cheque_date date,p_cheque_bank varchar,p_user_id bigint)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_payment bigint; v_no varchar; v_receipt varchar; v_due numeric; v_bill_id bigint; v_alloc numeric;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM society_manager.m_customer WHERE customer_id=p_customer_id AND society_id=p_society_id AND is_active) THEN RAISE EXCEPTION 'Customer not found in selected society'; END IF;
 IF NOT EXISTS(SELECT 1 FROM society_manager.m_customer_flat WHERE customer_id=p_customer_id AND flat_id=p_flat_id AND society_id=p_society_id) THEN RAISE EXCEPTION 'Customer is not linked to selected flat'; END IF;
 IF NOT EXISTS(SELECT 1 FROM society_manager.m_flat WHERE flat_id=p_flat_id AND society_id=p_society_id AND is_active) THEN RAISE EXCEPTION 'Flat not found in selected society'; END IF;
 IF p_amount<=0 THEN RAISE EXCEPTION 'Payment amount must be greater than zero'; END IF;
 IF NOT EXISTS(SELECT 1 FROM society_manager.m_collection_payment_mode WHERE society_id=p_society_id AND payment_mode_code=p_payment_mode AND visible AND is_active) THEN RAISE EXCEPTION 'Payment mode is not available'; END IF;
 IF upper(p_payment_mode)='CHEQUE' AND NULLIF(trim(p_cheque_no),'') IS NULL THEN RAISE EXCEPTION 'Cheque number is required for cheque payment'; END IF;
 IF upper(p_payment_mode)='CHEQUE' AND p_cheque_date IS NULL THEN RAISE EXCEPTION 'Cheque date is required for cheque payment'; END IF;
 SELECT COALESCE(sum(GREATEST(b.total_amount-b.paid_amount,0)),0) INTO v_due FROM society_manager.t_bill b WHERE b.society_id=p_society_id AND b.flat_id=p_flat_id AND b.status NOT IN('Paid','Cancelled');
 IF p_amount>v_due AND v_due>0 THEN RAISE EXCEPTION 'Payment amount cannot exceed current outstanding dues'; END IF;
 IF v_due=0 THEN RAISE EXCEPTION 'No outstanding dues available for payment'; END IF;
 v_no='PAY-'||to_char(clock_timestamp(),'YYYYMMDDHH24MISSMS');
 INSERT INTO society_manager.t_payment(society_id,customer_id,flat_id,payment_no,payment_date,amount,payment_mode,reference_no,remarks,status,modify_by,modify_date,modify_remark,cheque_no,cheque_date,cheque_bank)
 VALUES(p_society_id,p_customer_id,p_flat_id,v_no,coalesce(p_payment_date,now()),p_amount,p_payment_mode,p_reference,p_remarks,'Success',p_user_id,now(),coalesce(p_remarks,''),NULLIF(p_cheque_no,''),p_cheque_date,NULLIF(p_cheque_bank,'')) RETURNING payment_id INTO v_payment;
 v_receipt='RCT-'||to_char(clock_timestamp(),'YYYYMMDDHH24MISSMS');
 INSERT INTO society_manager.t_receipt(society_id,payment_id,receipt_no,receipt_date,amount,modify_by,modify_date,modify_remark)
 VALUES(p_society_id,v_payment,v_receipt,coalesce(p_payment_date,now()),p_amount,p_user_id,now(),coalesce(p_remarks,'')) RETURNING receipt_id INTO v_receipt;
 FOR v_bill_id IN SELECT b.bill_id FROM society_manager.t_bill b WHERE b.society_id=p_society_id AND b.flat_id=p_flat_id AND b.status NOT IN('Paid','Cancelled') AND b.total_amount>b.paid_amount ORDER BY b.due_date,b.bill_date LOOP
   EXIT WHEN p_amount<=0;
   SELECT LEAST(p_amount,GREATEST(total_amount-paid_amount,0)) INTO v_alloc FROM society_manager.t_bill WHERE bill_id=v_bill_id;
   UPDATE society_manager.t_bill SET paid_amount=paid_amount+v_alloc,status=CASE WHEN paid_amount+v_alloc>=total_amount THEN 'Paid' ELSE 'Partial' END,modify_by=p_user_id,modify_date=now(),modify_remark=coalesce(p_remarks,'') WHERE bill_id=v_bill_id AND society_id=p_society_id;
   INSERT INTO society_manager.t_payment_allocation(society_id,payment_id,bill_id,allocated_amount) VALUES(p_society_id,v_payment,v_bill_id,v_alloc);
   p_amount:=p_amount-v_alloc;
 END LOOP;
 RETURN v_payment;
END; $$;

DROP FUNCTION IF EXISTS society_manager.sp_save_service_charge(bigint,bigint,bigint,bigint,numeric,varchar,text,timestamptz,bigint);
CREATE OR REPLACE FUNCTION society_manager.sp_save_service_charge(p_society_id bigint,p_customer_id bigint,p_flat_id bigint,p_type_id bigint,p_amount numeric,p_reference varchar,p_remarks text,p_charge_date timestamptz,p_payment_mode varchar,p_user bigint)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_id bigint;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM society_manager.m_customer WHERE customer_id=p_customer_id AND society_id=p_society_id AND is_active) THEN RAISE EXCEPTION 'Customer not found in selected society'; END IF;
 IF p_flat_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM society_manager.m_customer_flat WHERE customer_id=p_customer_id AND flat_id=p_flat_id AND society_id=p_society_id) THEN RAISE EXCEPTION 'Customer is not linked to selected flat'; END IF;
 IF NOT EXISTS(SELECT 1 FROM society_manager.m_service_charge_type WHERE service_charge_type_id=p_type_id AND society_id=p_society_id AND is_active AND visible) THEN RAISE EXCEPTION 'Service charge type not found'; END IF;
 IF p_amount<=0 THEN RAISE EXCEPTION 'Service payment amount must be greater than zero'; END IF;
 IF NOT EXISTS(SELECT 1 FROM society_manager.m_collection_payment_mode WHERE society_id=p_society_id AND payment_mode_code=p_payment_mode AND visible AND is_active) THEN RAISE EXCEPTION 'Payment mode is not available'; END IF;
 INSERT INTO society_manager.t_service_charge(society_id,customer_id,flat_id,service_charge_type_id,amount,charge_date,reference_no,remarks,status,created_by,modify_by,modify_date,modify_remark,payment_mode)
 VALUES(p_society_id,p_customer_id,p_flat_id,p_type_id,p_amount,coalesce(p_charge_date,now()),p_reference,p_remarks,'Success',p_user,p_user,now(),coalesce(p_remarks,''),p_payment_mode) RETURNING service_charge_id INTO v_id;
 RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION society_manager.sp_raise_complaint(p_society_id bigint,p_customer_id bigint,p_flat_id bigint,p_category varchar,p_title varchar,p_description text,p_user_id bigint)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_id bigint; v_no varchar;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM society_manager.m_customer WHERE customer_id=p_customer_id AND society_id=p_society_id AND is_active) THEN RAISE EXCEPTION 'Customer not found in selected society'; END IF;
 IF p_flat_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM society_manager.m_customer_flat WHERE customer_id=p_customer_id AND flat_id=p_flat_id AND society_id=p_society_id) THEN RAISE EXCEPTION 'Flat is not linked to selected customer'; END IF;
 IF NOT EXISTS(SELECT 1 FROM society_manager.m_complaint_category WHERE society_id=p_society_id AND category_code=p_category AND is_active AND visible) THEN RAISE EXCEPTION 'Complaint category is not available'; END IF;
 v_no='CMP-'||to_char(clock_timestamp(),'YYYYMMDDHH24MISSMS');
 INSERT INTO society_manager.t_complaint(society_id,flat_id,customer_id,complaint_no,category,title,description,status,created_at,created_by,modify_by,modify_date,modify_remark)
 VALUES(p_society_id,p_flat_id,p_customer_id,v_no,p_category,p_title,p_description,'NEW',now(),p_user_id,p_user_id,now(),'Complaint registered') RETURNING complaint_id INTO v_id;
 INSERT INTO society_manager.t_notification(society_id,recipient_user_id,customer_id,notification_type,title,message,reference_entity,reference_id,channel,status)
 SELECT p_society_id,u.user_id,p_customer_id,'COMPLAINT','New Consumer Complaint',v_no||' - '||p_title,'COMPLAINT',v_id,'APP','Pending'
 FROM society_manager.m_user u WHERE u.society_id=p_society_id AND u.role_code='SOCIETY_ADMIN' AND u.is_active;
 RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION society_manager.fn_complaints_requested(p_society_id bigint)
RETURNS TABLE(complaint_id bigint,complaint_no varchar,customer_id bigint,customer_name varchar,flat_no varchar,category varchar,title varchar,description text,priority varchar,status varchar,created_at timestamptz,resolved_at timestamptz)
LANGUAGE sql AS $$
SELECT c.complaint_id,c.complaint_no,c.customer_id,cu.full_name,f.flat_no,c.category,c.title,c.description,c.priority,c.status,c.created_at,c.resolved_at
FROM society_manager.t_complaint c
JOIN society_manager.m_customer cu ON cu.customer_id=c.customer_id AND cu.society_id=p_society_id
LEFT JOIN society_manager.m_flat f ON f.flat_id=c.flat_id AND f.society_id=p_society_id
WHERE c.society_id=p_society_id ORDER BY c.created_at DESC;
$$;

CREATE OR REPLACE FUNCTION society_manager.sp_update_complaint_status(p_society_id bigint,p_complaint_id bigint,p_status varchar,p_user_id bigint)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_id bigint; v_customer bigint; v_title varchar; v_no varchar;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM society_manager.m_complaint_status WHERE society_id=p_society_id AND status_code=p_status AND is_active AND visible) THEN RAISE EXCEPTION 'Complaint status is not available'; END IF;
 SELECT complaint_id,customer_id,title,complaint_no INTO v_id,v_customer,v_title,v_no FROM society_manager.t_complaint WHERE complaint_id=p_complaint_id AND society_id=p_society_id FOR UPDATE;
 IF v_id IS NULL THEN RAISE EXCEPTION 'Complaint not found in selected society'; END IF;
 UPDATE society_manager.t_complaint SET status=p_status,resolved_at=CASE WHEN p_status IN('RESOLVED','CLOSED') THEN now() ELSE resolved_at END,modify_by=p_user_id,modify_date=now(),modify_remark='Complaint status updated' WHERE complaint_id=v_id AND society_id=p_society_id;
 INSERT INTO society_manager.t_notification(society_id,recipient_user_id,customer_id,notification_type,title,message,reference_entity,reference_id,channel,status)
 SELECT p_society_id,u.user_id,v_customer,'COMPLAINT_STATUS','Complaint Status Updated',v_no||' status changed to '||p_status,'COMPLAINT',v_id,'APP','Pending'
 FROM society_manager.m_user u WHERE u.society_id=p_society_id AND u.role_code='SOCIETY_ADMIN' AND u.is_active;
 RETURN v_id;
END; $$;
