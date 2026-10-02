SET search_path TO society_manager, public;

ALTER TABLE m_module ADD COLUMN IF NOT EXISTS visible boolean NOT NULL DEFAULT true;

CREATE TABLE IF NOT EXISTS m_collection_payment_mode(
 payment_mode_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 society_id bigint NOT NULL REFERENCES m_society(society_id),
 payment_mode_code varchar(40) NOT NULL,
 payment_mode_name varchar(100) NOT NULL,
 requires_reference boolean NOT NULL DEFAULT false,
 is_active boolean NOT NULL DEFAULT true,
 visible boolean NOT NULL DEFAULT true,
 modify_by bigint REFERENCES m_user(user_id), modify_date timestamptz NOT NULL DEFAULT now(), modify_remark text DEFAULT '',
 UNIQUE(society_id,payment_mode_code)
);

CREATE TABLE IF NOT EXISTS m_service_charge_type(
 service_charge_type_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 society_id bigint NOT NULL REFERENCES m_society(society_id),
 charge_code varchar(50) NOT NULL, charge_name varchar(150) NOT NULL,
 calculation_method varchar(40) NOT NULL DEFAULT 'Fixed', default_amount numeric(18,2) NOT NULL DEFAULT 0,
 is_active boolean NOT NULL DEFAULT true, visible boolean NOT NULL DEFAULT true,
 modify_by bigint REFERENCES m_user(user_id), modify_date timestamptz NOT NULL DEFAULT now(), modify_remark text DEFAULT '',
 UNIQUE(society_id,charge_code)
);

CREATE TABLE IF NOT EXISTS m_bank_detail(
 bank_detail_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 society_id bigint NOT NULL REFERENCES m_society(society_id),
 bank_name varchar(150) NOT NULL, account_name varchar(150), account_number varchar(80),
 ifsc_code varchar(30), branch_name varchar(150), account_type varchar(30),
 upi_id varchar(150), is_active boolean NOT NULL DEFAULT true, visible boolean NOT NULL DEFAULT true,
 modify_by bigint REFERENCES m_user(user_id), modify_date timestamptz NOT NULL DEFAULT now(), modify_remark text DEFAULT ''
);

CREATE TABLE IF NOT EXISTS m_cheque_dishonor_reason(
 dishonor_reason_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 society_id bigint NOT NULL REFERENCES m_society(society_id),
 reason_code varchar(50) NOT NULL, reason_name varchar(150) NOT NULL,
 is_active boolean NOT NULL DEFAULT true, visible boolean NOT NULL DEFAULT true,
 modify_by bigint REFERENCES m_user(user_id), modify_date timestamptz NOT NULL DEFAULT now(), modify_remark text DEFAULT '',
 UNIQUE(society_id,reason_code)
);

CREATE TABLE IF NOT EXISTS m_document_type(
 document_type_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 society_id bigint NOT NULL REFERENCES m_society(society_id),
 document_code varchar(50) NOT NULL, document_name varchar(150) NOT NULL,
 allowed_extensions varchar(200) NOT NULL DEFAULT 'pdf,jpg,jpeg,png',
 is_active boolean NOT NULL DEFAULT true, visible boolean NOT NULL DEFAULT true,
 modify_by bigint REFERENCES m_user(user_id), modify_date timestamptz NOT NULL DEFAULT now(), modify_remark text DEFAULT '',
 UNIQUE(society_id,document_code)
);

CREATE TABLE IF NOT EXISTS m_ticket_status(
 ticket_status_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 status_code varchar(40) NOT NULL UNIQUE, status_name varchar(100) NOT NULL,
 status_order integer NOT NULL DEFAULT 10, display_color varchar(20) NOT NULL DEFAULT '#64748B',
 is_active boolean NOT NULL DEFAULT true, visible boolean NOT NULL DEFAULT true
);

CREATE TABLE IF NOT EXISTS m_complaint_category(
 complaint_category_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 society_id bigint NOT NULL REFERENCES m_society(society_id),
 category_code varchar(50) NOT NULL, category_name varchar(150) NOT NULL,
 is_active boolean NOT NULL DEFAULT true, visible boolean NOT NULL DEFAULT true,
 modify_by bigint REFERENCES m_user(user_id), modify_date timestamptz NOT NULL DEFAULT now(), modify_remark text DEFAULT '',
 UNIQUE(society_id,category_code)
);

CREATE TABLE IF NOT EXISTS t_service_charge(
 service_charge_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 society_id bigint NOT NULL REFERENCES m_society(society_id),
 customer_id bigint NOT NULL REFERENCES m_customer(customer_id),
 flat_id bigint REFERENCES m_flat(flat_id),
 service_charge_type_id bigint NOT NULL REFERENCES m_service_charge_type(service_charge_type_id),
 amount numeric(18,2) NOT NULL, charge_date timestamptz NOT NULL DEFAULT now(),
 status varchar(30) NOT NULL DEFAULT 'Pending', reference_no varchar(100), remarks text,
 created_by bigint REFERENCES m_user(user_id)
);

CREATE TABLE IF NOT EXISTS t_dishonored_cheque(
 dishonored_cheque_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 society_id bigint NOT NULL REFERENCES m_society(society_id),
 payment_id bigint NOT NULL REFERENCES t_payment(payment_id),
 customer_id bigint REFERENCES m_customer(customer_id), flat_id bigint REFERENCES m_flat(flat_id),
 cheque_no varchar(80), cheque_date date, dishonor_reason_id bigint REFERENCES m_cheque_dishonor_reason(dishonor_reason_id),
 dishonored_date timestamptz NOT NULL DEFAULT now(), bank_charge numeric(18,2) NOT NULL DEFAULT 0,
 due_amount numeric(18,2) NOT NULL DEFAULT 0, status varchar(30) NOT NULL DEFAULT 'Dishonored',
 created_by bigint REFERENCES m_user(user_id), remarks text
);

CREATE TABLE IF NOT EXISTS t_customer_document(
 document_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 society_id bigint NOT NULL REFERENCES m_society(society_id),
 customer_id bigint NOT NULL REFERENCES m_customer(customer_id),
 flat_id bigint REFERENCES m_flat(flat_id), document_type_id bigint NOT NULL REFERENCES m_document_type(document_type_id),
 file_name varchar(255) NOT NULL, content_type varchar(120) NOT NULL, file_size bigint NOT NULL DEFAULT 0,
 file_data bytea NOT NULL, uploaded_at timestamptz NOT NULL DEFAULT now(), uploaded_by bigint REFERENCES m_user(user_id),
 is_active boolean NOT NULL DEFAULT true, visible boolean NOT NULL DEFAULT true, modify_remark text DEFAULT ''
);

CREATE TABLE IF NOT EXISTS t_customer_service_attribute_history(
 service_attribute_history_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 society_id bigint NOT NULL REFERENCES m_society(society_id),
 customer_id bigint NOT NULL REFERENCES m_customer(customer_id),
 attribute_code varchar(60) NOT NULL, attribute_name varchar(120) NOT NULL,
 old_value text, new_value text, changed_at timestamptz NOT NULL DEFAULT now(),
 changed_by bigint REFERENCES m_user(user_id), remarks text
);

CREATE TABLE IF NOT EXISTS t_it_ticket(
 ticket_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 society_id bigint NOT NULL REFERENCES m_society(society_id),
 ticket_no varchar(60) NOT NULL, title varchar(200) NOT NULL, description text,
 ticket_status_id bigint NOT NULL REFERENCES m_ticket_status(ticket_status_id),
 priority varchar(30) NOT NULL DEFAULT 'Normal', assigned_to bigint REFERENCES m_user(user_id),
 created_by bigint REFERENCES m_user(user_id), created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(), resolved_at timestamptz, UNIQUE(society_id,ticket_no)
);

ALTER TABLE t_notification ADD COLUMN IF NOT EXISTS recipient_user_id bigint REFERENCES m_user(user_id);
ALTER TABLE t_notification ALTER COLUMN channel SET DEFAULT 'APP';
ALTER TABLE t_notification ALTER COLUMN status SET DEFAULT 'Pending';
ALTER TABLE t_notification ADD COLUMN IF NOT EXISTS notification_type varchar(60) NOT NULL DEFAULT 'GENERAL';
ALTER TABLE t_notification ADD COLUMN IF NOT EXISTS title varchar(200) NOT NULL DEFAULT 'Notification';
ALTER TABLE t_notification ADD COLUMN IF NOT EXISTS reference_entity varchar(80);
ALTER TABLE t_notification ADD COLUMN IF NOT EXISTS reference_id bigint;
ALTER TABLE t_notification ADD COLUMN IF NOT EXISTS is_read boolean NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS ix_t_service_charge_customer ON t_service_charge(society_id,customer_id,charge_date);
CREATE INDEX IF NOT EXISTS ix_t_dishonored_cheque_customer ON t_dishonored_cheque(society_id,customer_id);
CREATE INDEX IF NOT EXISTS ix_t_customer_document_customer ON t_customer_document(society_id,customer_id);
CREATE INDEX IF NOT EXISTS ix_t_service_attr_customer ON t_customer_service_attribute_history(society_id,customer_id,changed_at);
CREATE INDEX IF NOT EXISTS ix_t_it_ticket_society ON t_it_ticket(society_id,ticket_status_id,created_at);
CREATE INDEX IF NOT EXISTS ix_t_notification_user ON t_notification(society_id,recipient_user_id,is_read,created_at);

INSERT INTO m_ticket_status(status_code,status_name,status_order,display_color) VALUES
('GENERATED','Generated',10,'#2563EB'),('WORK_IN_PROGRESS','Work In Process',20,'#F59E0B'),('WAITING','Waiting',30,'#8B5CF6'),('RESOLVED','Resolved',40,'#16A34A'),('CLOSED','Closed',50,'#64748B')
ON CONFLICT(status_code) DO UPDATE SET status_name=excluded.status_name,status_order=excluded.status_order,display_color=excluded.display_color;

INSERT INTO m_collection_payment_mode(society_id,payment_mode_code,payment_mode_name,requires_reference)
SELECT society_id,v.code,v.name,v.ref FROM m_society CROSS JOIN (VALUES
('CASH','Cash',false),('CHEQUE','Cheque',true),('DD','Demand Draft',true),('BANK_TRANSFER','Bank Transfer',true),('OTHER','Other',true)
) v(code,name,ref)
ON CONFLICT(society_id,payment_mode_code) DO NOTHING;

INSERT INTO m_service_charge_type(society_id,charge_code,charge_name,calculation_method)
SELECT society_id,v.code,v.name,v.method FROM m_society CROSS JOIN (VALUES
('DISHONORED_CHEQUE','Dishonored Cheque Charges','Fixed'),('LATE_FEE','Late Fee','Fixed'),('PARKING','Parking Service','Fixed'),('REPAIR','Repair / Maintenance','Fixed'),('OTHER','Other Service','Fixed')
) v(code,name,method)
ON CONFLICT(society_id,charge_code) DO NOTHING;

INSERT INTO m_document_type(society_id,document_code,document_name,allowed_extensions)
SELECT society_id,v.code,v.name,v.ext FROM m_society CROSS JOIN (VALUES
('PARKING_RECEIPT','Parking Receipt','pdf,jpg,jpeg,png'),('RENT_AGREEMENT','Flat Rent Agreement','pdf,jpg,jpeg,png'),('SALE_AGREEMENT','Sale Agreement','pdf,jpg,jpeg,png'),('ID_PROOF','Identity Proof','pdf,jpg,jpeg,png'),('ADDRESS_PROOF','Address Proof','pdf,jpg,jpeg,png'),('OTHER','Other','pdf,jpg,jpeg,png')
) v(code,name,ext)
ON CONFLICT(society_id,document_code) DO NOTHING;

INSERT INTO m_cheque_dishonor_reason(society_id,reason_code,reason_name)
SELECT society_id,v.code,v.name FROM m_society CROSS JOIN (VALUES
('INSUFFICIENT_FUNDS','Insufficient Funds'),('SIGNATURE_MISMATCH','Signature Mismatch'),('ACCOUNT_CLOSED','Account Closed'),('PAYMENT_STOPPED','Payment Stopped'),('STALE_CHEQUE','Stale Cheque'),('OTHER','Other')
) v(code,name)
ON CONFLICT(society_id,reason_code) DO NOTHING;

INSERT INTO m_complaint_category(society_id,category_code,category_name)
SELECT society_id,v.code,v.name FROM m_society CROSS JOIN (VALUES
('MAINTENANCE','Maintenance'),('BILLING','Billing'),('COLLECTION','Collection'),('PARKING','Parking'),('SECURITY','Security'),('CLEANLINESS','Cleanliness'),('OTHER','Other')
) v(code,name)
ON CONFLICT(society_id,category_code) DO NOTHING;

CREATE OR REPLACE FUNCTION fn_society_management(p_society_id bigint,p_search varchar)
RETURNS TABLE(entity_type varchar,entity_id bigint,code varchar,name varchar,parent_name varchar,details jsonb,is_active boolean)
LANGUAGE sql AS $$
SELECT 'WING',w.wing_id,w.wing_code,w.wing_name,b.building_name,jsonb_build_object('building_id',w.building_id),w.is_active FROM m_wing w LEFT JOIN m_building b ON b.building_id=w.building_id WHERE w.society_id=p_society_id AND (coalesce(p_search,'')='' OR w.wing_code ILIKE '%'||p_search||'%' OR w.wing_name ILIKE '%'||p_search||'%')
UNION ALL SELECT 'FLAT',f.flat_id,f.flat_no,f.flat_no,w.wing_name,jsonb_build_object('area_sqft',f.area_sqft,'floor_no',f.floor_no,'unit_type',f.unit_type,'occupancy_status',f.occupancy_status),f.is_active FROM m_flat f LEFT JOIN m_wing w ON w.wing_id=f.wing_id WHERE f.society_id=p_society_id AND (coalesce(p_search,'')='' OR f.flat_no ILIKE '%'||p_search||'%')
UNION ALL SELECT 'PARKING',p.parking_slot_id,p.slot_no,p.slot_no,NULL,jsonb_build_object('slot_type',p.slot_type,'charge',p.charge),p.is_active FROM m_parking_slot p WHERE p.society_id=p_society_id AND (coalesce(p_search,'')='' OR p.slot_no ILIKE '%'||p_search||'%')
UNION ALL SELECT 'CUSTOMER',c.customer_id,c.customer_code,c.full_name,NULL,jsonb_build_object('phone',c.phone,'email',c.email,'customer_type',c.customer_type),c.is_active FROM m_customer c WHERE c.society_id=p_society_id AND (coalesce(p_search,'')='' OR c.full_name ILIKE '%'||p_search||'%' OR c.phone ILIKE '%'||p_search||'%' OR c.customer_code ILIKE '%'||p_search||'%')
;
$$;

CREATE OR REPLACE FUNCTION fn_collection_consumer_search(p_society_id bigint,p_search varchar)
RETURNS TABLE(customer_id bigint,customer_code varchar,full_name varchar,phone varchar,email varchar,flat_id bigint,flat_no varchar,wing_name varchar,current_dues numeric,due_date date,last_bill_date date,last_bill_amount numeric)
LANGUAGE sql AS $$
SELECT c.customer_id,c.customer_code,c.full_name,c.phone,c.email,f.flat_id,f.flat_no,w.wing_name,
COALESCE(SUM(GREATEST(b.total_amount-b.paid_amount,0)),0),MIN(b.due_date),MAX(b.bill_date),MAX(b.total_amount)
FROM m_customer c JOIN m_customer_flat cf ON cf.customer_id=c.customer_id AND cf.society_id=p_society_id
JOIN m_flat f ON f.flat_id=cf.flat_id LEFT JOIN m_wing w ON w.wing_id=f.wing_id
LEFT JOIN t_bill b ON b.society_id=p_society_id AND b.flat_id=f.flat_id AND b.status NOT IN ('Paid','Cancelled')
WHERE c.society_id=p_society_id AND (coalesce(p_search,'')='' OR c.full_name ILIKE '%'||p_search||'%' OR c.phone ILIKE '%'||p_search||'%' OR f.flat_no ILIKE '%'||p_search||'%')
GROUP BY c.customer_id,c.customer_code,c.full_name,c.phone,c.email,f.flat_id,f.flat_no,w.wing_name;
$$;

CREATE OR REPLACE FUNCTION fn_consumer_account_full(p_society_id bigint,p_customer_id bigint)
RETURNS jsonb LANGUAGE sql AS $$
SELECT jsonb_build_object(
 'customer',to_jsonb(c),
 'flats',COALESCE((SELECT jsonb_agg(jsonb_build_object('flat_id',f.flat_id,'flat_no',f.flat_no,'wing',w.wing_name,'building',b.building_name,'area_sqft',f.area_sqft,'unit_type',f.unit_type,'relation',cf.relation_type)) FROM m_customer_flat cf JOIN m_flat f ON f.flat_id=cf.flat_id LEFT JOIN m_wing w ON w.wing_id=f.wing_id LEFT JOIN m_building b ON b.building_id=f.building_id WHERE cf.society_id=p_society_id AND cf.customer_id=p_customer_id),'[]'::jsonb),
 'dues',COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM (SELECT bill_id,bill_no,bill_month,bill_date,due_date,total_amount,paid_amount,status FROM t_bill WHERE society_id=p_society_id AND flat_id IN (SELECT flat_id FROM m_customer_flat WHERE customer_id=p_customer_id AND society_id=p_society_id) ORDER BY bill_date DESC LIMIT 100)x),'[]'::jsonb),
 'payments',COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM (SELECT payment_id,payment_no,payment_date,amount,payment_mode,reference_no,status FROM t_payment WHERE society_id=p_society_id AND customer_id=p_customer_id ORDER BY payment_date DESC LIMIT 100)x),'[]'::jsonb),
 'complaints',COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM (SELECT complaint_id,complaint_no,category,title,description,priority,status,created_at,resolved_at FROM t_complaint WHERE society_id=p_society_id AND customer_id=p_customer_id ORDER BY created_at DESC LIMIT 100)x),'[]'::jsonb),
 'service_history',COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM (SELECT service_attribute_history_id,attribute_name,old_value,new_value,changed_at,remarks FROM t_customer_service_attribute_history WHERE society_id=p_society_id AND customer_id=p_customer_id ORDER BY changed_at DESC LIMIT 200)x),'[]'::jsonb)
) FROM m_customer c WHERE c.society_id=p_society_id AND c.customer_id=p_customer_id;
$$;

CREATE OR REPLACE FUNCTION fn_mis_consumer_master(p_society_id bigint,p_wing_id bigint,p_search varchar)
RETURNS TABLE(customer_id bigint,customer_code varchar,full_name varchar,phone varchar,email varchar,flat_no varchar,wing_name varchar,area_sqft numeric,customer_type varchar)
LANGUAGE sql AS $$
SELECT c.customer_id,c.customer_code,c.full_name,c.phone,c.email,f.flat_no,w.wing_name,f.area_sqft,c.customer_type
FROM m_customer c JOIN m_customer_flat cf ON cf.customer_id=c.customer_id AND cf.society_id=p_society_id JOIN m_flat f ON f.flat_id=cf.flat_id
LEFT JOIN m_wing w ON w.wing_id=f.wing_id WHERE c.society_id=p_society_id AND (p_wing_id IS NULL OR f.wing_id=p_wing_id)
AND (coalesce(p_search,'')='' OR c.full_name ILIKE '%'||p_search||'%' OR c.phone ILIKE '%'||p_search||'%' OR f.flat_no ILIKE '%'||p_search||'%') ORDER BY w.wing_name,f.flat_no,c.full_name;
$$;

CREATE OR REPLACE FUNCTION fn_mis_billing(p_society_id bigint,p_month date)
RETURNS TABLE(bill_no varchar,flat_no varchar,customer_name varchar,bill_month date,current_charges numeric,arrear numeric,dpc numeric,total_amount numeric,paid_amount numeric,status varchar)
LANGUAGE sql AS $$
SELECT b.bill_no,f.flat_no,c.full_name,b.bill_month,b.subtotal,
GREATEST(b.total_amount-b.subtotal-b.dpc_amount-b.tax_amount,0),b.dpc_amount,b.total_amount,b.paid_amount,b.status
FROM t_bill b JOIN m_flat f ON f.flat_id=b.flat_id LEFT JOIN m_customer_flat cf ON cf.flat_id=f.flat_id AND cf.society_id=p_society_id AND cf.is_primary=true LEFT JOIN m_customer c ON c.customer_id=cf.customer_id
WHERE b.society_id=p_society_id AND b.bill_month=date_trunc('month',p_month)::date ORDER BY f.flat_no;
$$;

CREATE OR REPLACE FUNCTION fn_mis_collection(p_society_id bigint,p_month date,p_status varchar)
RETURNS TABLE(payment_no varchar,payment_date timestamptz,flat_no varchar,customer_name varchar,amount numeric,payment_mode varchar,status varchar,reference_no varchar)
LANGUAGE sql AS $$
SELECT p.payment_no,p.payment_date,f.flat_no,c.full_name,p.amount,p.payment_mode,p.status,p.reference_no FROM t_payment p LEFT JOIN m_flat f ON f.flat_id=p.flat_id LEFT JOIN m_customer c ON c.customer_id=p.customer_id
WHERE p.society_id=p_society_id AND p.payment_date>=date_trunc('month',p_month) AND p.payment_date<date_trunc('month',p_month)+interval '1 month' AND (coalesce(p_status,'')='' OR p.status=p_status) ORDER BY p.payment_date DESC;
$$;

CREATE OR REPLACE FUNCTION fn_mis_complaints(p_society_id bigint,p_status varchar)
RETURNS TABLE(complaint_no varchar,created_at timestamptz,flat_no varchar,customer_name varchar,category varchar,title varchar,priority varchar,status varchar)
LANGUAGE sql AS $$
SELECT t.complaint_no,t.created_at,f.flat_no,c.full_name,t.category,t.title,t.priority,t.status FROM t_complaint t LEFT JOIN m_flat f ON f.flat_id=t.flat_id LEFT JOIN m_customer c ON c.customer_id=t.customer_id
WHERE t.society_id=p_society_id AND (coalesce(p_status,'')='' OR t.status=p_status) ORDER BY t.created_at DESC;
$$;

CREATE OR REPLACE FUNCTION sp_accept_payment(p_society_id bigint,p_customer_id bigint,p_flat_id bigint,p_amount numeric,p_payment_mode varchar,p_reference varchar,p_remarks text,p_user_id bigint)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_payment bigint; v_no varchar; v_receipt varchar; v_receipt_id bigint;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM m_customer WHERE customer_id=p_customer_id AND society_id=p_society_id AND is_active) THEN RAISE EXCEPTION 'Customer not found in selected society'; END IF;
 IF NOT EXISTS(SELECT 1 FROM m_flat WHERE flat_id=p_flat_id AND society_id=p_society_id AND is_active) THEN RAISE EXCEPTION 'Flat not found in selected society'; END IF;
 IF p_amount<=0 THEN RAISE EXCEPTION 'Payment amount must be greater than zero'; END IF;
 IF NOT EXISTS(SELECT 1 FROM m_collection_payment_mode WHERE society_id=p_society_id AND payment_mode_code=p_payment_mode AND visible AND is_active) THEN RAISE EXCEPTION 'Payment mode is not available'; END IF;
 v_no='PAY-'||to_char(now(),'YYYYMMDDHH24MISSMS');
 INSERT INTO t_payment(society_id,customer_id,flat_id,payment_no,amount,payment_mode,reference_no,remarks,status) VALUES(p_society_id,p_customer_id,p_flat_id,v_no,p_amount,p_payment_mode,p_reference,p_remarks,'Success') RETURNING payment_id INTO v_payment;
 v_receipt='RCT-'||to_char(now(),'YYYYMMDDHH24MISSMS');
 INSERT INTO t_receipt(society_id,payment_id,receipt_no,amount) VALUES(p_society_id,v_payment,v_receipt,p_amount) RETURNING receipt_id INTO v_receipt_id;
 UPDATE t_bill b SET paid_amount=LEAST(b.total_amount,b.paid_amount+x.amount),status=CASE WHEN b.paid_amount+x.amount>=b.total_amount THEN 'Paid' ELSE 'Partial' END
 FROM (SELECT p_amount amount) x WHERE b.society_id=p_society_id AND b.flat_id=p_flat_id AND b.status NOT IN ('Paid','Cancelled') AND b.total_amount>b.paid_amount
 AND b.bill_id=(SELECT bill_id FROM t_bill WHERE society_id=p_society_id AND flat_id=p_flat_id AND status NOT IN ('Paid','Cancelled') AND total_amount>paid_amount ORDER BY due_date,bill_date LIMIT 1);
 RETURN v_payment;
END; $$;

CREATE OR REPLACE FUNCTION fn_payment_receipt(p_society_id bigint,p_payment_id bigint)
RETURNS TABLE(receipt_no varchar,payment_no varchar,receipt_date timestamptz,amount numeric,payment_mode varchar,reference_no varchar,society_name varchar,society_logo text,customer_name varchar,flat_no varchar,wing_name varchar)
LANGUAGE sql AS $$
SELECT r.receipt_no,p.payment_no,r.receipt_date,r.amount,p.payment_mode,p.reference_no,s.society_name,sb.logo_url,c.full_name,f.flat_no,w.wing_name
FROM t_receipt r JOIN t_payment p ON p.payment_id=r.payment_id JOIN m_society s ON s.society_id=r.society_id
LEFT JOIN m_society_branding sb ON sb.society_id=s.society_id LEFT JOIN m_customer c ON c.customer_id=p.customer_id
LEFT JOIN m_flat f ON f.flat_id=p.flat_id LEFT JOIN m_wing w ON w.wing_id=f.wing_id
WHERE r.society_id=p_society_id AND r.payment_id=p_payment_id;
$$;

CREATE OR REPLACE FUNCTION fn_subscription_history(p_society_id bigint)
RETURNS TABLE(subscription_id bigint,plan_name varchar,start_date date,end_date date,amount numeric,payment_status varchar,payment_reference varchar,days_remaining integer)
LANGUAGE sql AS $$
SELECT ss.subscription_id,sp.plan_name,ss.start_date,ss.end_date,ss.amount,ss.payment_status,ss.payment_reference,(ss.end_date-current_date)::integer
FROM m_society_subscription ss JOIN m_subscription_plan sp ON sp.subscription_plan_id=ss.subscription_plan_id
WHERE ss.society_id=p_society_id ORDER BY ss.start_date DESC;
$$;

CREATE OR REPLACE FUNCTION fn_role_rights_catalog(p_society_id bigint)
RETURNS TABLE(role_id bigint,role_code varchar,role_name varchar,description text,is_system boolean,is_active boolean,user_count bigint)
LANGUAGE sql AS $$
SELECT r.role_id,r.role_code,r.role_name,r.description,r.is_system,r.is_active,COUNT(u.user_id)
FROM m_role r LEFT JOIN m_user u ON u.role_code=r.role_code AND u.society_id=p_society_id
GROUP BY r.role_id,r.role_code,r.role_name,r.description,r.is_system,r.is_active ORDER BY r.role_name;
$$;

CREATE OR REPLACE FUNCTION fn_wing_catalog(p_society_id bigint)
RETURNS TABLE(wing_id bigint,building_id bigint,building_name varchar,wing_code varchar,wing_name varchar,is_active boolean)
LANGUAGE sql AS $$
SELECT w.wing_id,w.building_id,b.building_name,w.wing_code,w.wing_name,w.is_active FROM m_wing w LEFT JOIN m_building b ON b.building_id=w.building_id WHERE w.society_id=p_society_id ORDER BY b.building_name,w.wing_name;
$$;

CREATE OR REPLACE FUNCTION fn_building_catalog(p_society_id bigint)
RETURNS TABLE(building_id bigint,building_code varchar,building_name varchar,floor_count integer,is_active boolean)
LANGUAGE sql AS $$ SELECT building_id,building_code,building_name,floor_count,is_active FROM m_building WHERE society_id=p_society_id ORDER BY building_name; $$;

CREATE OR REPLACE FUNCTION fn_parking_catalog(p_society_id bigint)
RETURNS TABLE(parking_slot_id bigint,slot_no varchar,slot_type varchar,charge numeric,is_active boolean)
LANGUAGE sql AS $$ SELECT parking_slot_id,slot_no,slot_type,charge,is_active FROM m_parking_slot WHERE society_id=p_society_id ORDER BY slot_no; $$;

CREATE OR REPLACE FUNCTION fn_payment_modes(p_society_id bigint)
RETURNS TABLE(payment_mode_code varchar,payment_mode_name varchar,requires_reference boolean)
LANGUAGE sql AS $$ SELECT payment_mode_code,payment_mode_name,requires_reference FROM m_collection_payment_mode WHERE society_id=p_society_id AND is_active AND visible ORDER BY payment_mode_name; $$;

CREATE OR REPLACE FUNCTION fn_service_charge_types(p_society_id bigint)
RETURNS TABLE(service_charge_type_id bigint,charge_code varchar,charge_name varchar,calculation_method varchar,default_amount numeric)
LANGUAGE sql AS $$ SELECT service_charge_type_id,charge_code,charge_name,calculation_method,default_amount FROM m_service_charge_type WHERE society_id=p_society_id AND is_active AND visible ORDER BY charge_name; $$;

CREATE OR REPLACE FUNCTION fn_bank_details(p_society_id bigint)
RETURNS TABLE(bank_detail_id bigint,bank_name varchar,account_name varchar,account_number varchar,ifsc_code varchar,branch_name varchar,account_type varchar,upi_id varchar,is_active boolean)
LANGUAGE sql AS $$ SELECT bank_detail_id,bank_name,account_name,account_number,ifsc_code,branch_name,account_type,upi_id,is_active FROM m_bank_detail WHERE society_id=p_society_id ORDER BY bank_name; $$;

CREATE OR REPLACE FUNCTION fn_document_types(p_society_id bigint)
RETURNS TABLE(document_type_id bigint,document_code varchar,document_name varchar,allowed_extensions varchar)
LANGUAGE sql AS $$ SELECT document_type_id,document_code,document_name,allowed_extensions FROM m_document_type WHERE society_id=p_society_id AND is_active AND visible ORDER BY document_name; $$;

CREATE OR REPLACE FUNCTION fn_ticket_statuses()
RETURNS TABLE(ticket_status_id bigint,status_code varchar,status_name varchar,display_color varchar)
LANGUAGE sql AS $$ SELECT ticket_status_id,status_code,status_name,display_color FROM m_ticket_status WHERE is_active AND visible ORDER BY status_order; $$;

CREATE OR REPLACE FUNCTION fn_complaint_categories(p_society_id bigint)
RETURNS TABLE(category_code varchar,category_name varchar)
LANGUAGE sql AS $$ SELECT category_code,category_name FROM m_complaint_category WHERE society_id=p_society_id AND is_active AND visible ORDER BY category_name; $$;

CREATE OR REPLACE FUNCTION fn_notifications(p_society_id bigint,p_user_id bigint)
RETURNS TABLE(notification_id bigint,notification_type varchar,title varchar,message text,reference_entity varchar,reference_id bigint,is_read boolean,created_at timestamptz)
LANGUAGE sql AS $$
SELECT notification_id,notification_type,title,message,reference_entity,reference_id,is_read,created_at FROM t_notification
WHERE society_id=p_society_id AND (recipient_user_id=p_user_id OR recipient_user_id IS NULL) ORDER BY created_at DESC;
$$;

CREATE OR REPLACE FUNCTION sp_save_building(p_society_id bigint,p_building_id bigint,p_code varchar,p_name varchar,p_floor_count integer,p_user_id bigint,p_remark text)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_id bigint;
BEGIN
 IF p_building_id>0 THEN UPDATE m_building SET building_code=p_code,building_name=p_name,floor_count=p_floor_count WHERE building_id=p_building_id AND society_id=p_society_id RETURNING building_id INTO v_id;
 ELSE INSERT INTO m_building(society_id,building_code,building_name,floor_count) VALUES(p_society_id,p_code,p_name,p_floor_count) RETURNING building_id INTO v_id; END IF;
 IF v_id IS NULL THEN RAISE EXCEPTION 'Building not found in selected society'; END IF; RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION sp_save_wing(p_society_id bigint,p_wing_id bigint,p_building_id bigint,p_code varchar,p_name varchar,p_user_id bigint,p_remark text)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_id bigint;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM m_building WHERE building_id=p_building_id AND society_id=p_society_id) THEN RAISE EXCEPTION 'Building not found in selected society'; END IF;
 IF p_wing_id>0 THEN UPDATE m_wing SET building_id=p_building_id,wing_code=p_code,wing_name=p_name WHERE wing_id=p_wing_id AND society_id=p_society_id RETURNING wing_id INTO v_id;
 ELSE INSERT INTO m_wing(society_id,building_id,wing_code,wing_name) VALUES(p_society_id,p_building_id,p_code,p_name) RETURNING wing_id INTO v_id; END IF;
 RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION sp_save_flat(p_society_id bigint,p_flat_id bigint,p_building_id bigint,p_wing_id bigint,p_flat_no varchar,p_floor_no integer,p_unit_type varchar,p_area numeric,p_occupancy varchar,p_user_id bigint,p_remark text)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_id bigint;
BEGIN
 IF p_building_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM m_building WHERE building_id=p_building_id AND society_id=p_society_id) THEN RAISE EXCEPTION 'Building not found'; END IF;
 IF p_wing_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM m_wing WHERE wing_id=p_wing_id AND society_id=p_society_id) THEN RAISE EXCEPTION 'Wing not found'; END IF;
 IF p_flat_id>0 THEN UPDATE m_flat SET building_id=p_building_id,wing_id=p_wing_id,flat_no=p_flat_no,floor_no=p_floor_no,unit_type=p_unit_type,area_sqft=p_area,occupancy_status=p_occupancy WHERE flat_id=p_flat_id AND society_id=p_society_id RETURNING flat_id INTO v_id;
 ELSE INSERT INTO m_flat(society_id,building_id,wing_id,flat_no,floor_no,unit_type,area_sqft,occupancy_status) VALUES(p_society_id,p_building_id,p_wing_id,p_flat_no,p_floor_no,p_unit_type,p_area,p_occupancy) RETURNING flat_id INTO v_id; END IF;
 IF v_id IS NULL THEN RAISE EXCEPTION 'Flat not found in selected society'; END IF; RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION sp_save_parking(p_society_id bigint,p_slot_id bigint,p_slot_no varchar,p_slot_type varchar,p_charge numeric,p_user_id bigint,p_remark text)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_id bigint;
BEGIN
 IF p_slot_id>0 THEN UPDATE m_parking_slot SET slot_no=p_slot_no,slot_type=p_slot_type,charge=p_charge WHERE parking_slot_id=p_slot_id AND society_id=p_society_id RETURNING parking_slot_id INTO v_id;
 ELSE INSERT INTO m_parking_slot(society_id,slot_no,slot_type,charge) VALUES(p_society_id,p_slot_no,p_slot_type,p_charge) RETURNING parking_slot_id INTO v_id; END IF; RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION sp_save_customer(p_society_id bigint,p_customer_id bigint,p_code varchar,p_name varchar,p_type varchar,p_phone varchar,p_email varchar,p_flat_id bigint,p_user bigint,p_remark text)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_id bigint;
BEGIN
 IF p_customer_id>0 THEN UPDATE m_customer SET customer_code=p_code,full_name=p_name,customer_type=p_type,phone=p_phone,email=p_email WHERE customer_id=p_customer_id AND society_id=p_society_id RETURNING customer_id INTO v_id;
 ELSE INSERT INTO m_customer(society_id,customer_code,full_name,customer_type,phone,email) VALUES(p_society_id,p_code,p_name,p_type,p_phone,p_email) RETURNING customer_id INTO v_id; END IF;
 IF v_id IS NULL THEN RAISE EXCEPTION 'Customer not found in selected society'; END IF;
 IF p_flat_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM m_customer_flat WHERE society_id=p_society_id AND customer_id=v_id AND flat_id=p_flat_id) THEN INSERT INTO m_customer_flat(society_id,customer_id,flat_id,relation_type,is_primary,start_date) VALUES(p_society_id,v_id,p_flat_id,'Owner',true,current_date); END IF;
 RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION sp_update_flat_area(p_society_id bigint,p_customer_id bigint,p_flat_id bigint,p_new_area numeric,p_user_id bigint,p_remarks text)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_old text; v_id bigint;
BEGIN
 SELECT area_sqft::text INTO v_old FROM m_flat WHERE flat_id=p_flat_id AND society_id=p_society_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Flat not found in selected society'; END IF;
 UPDATE m_flat SET area_sqft=p_new_area WHERE flat_id=p_flat_id AND society_id=p_society_id;
 INSERT INTO t_customer_service_attribute_history(society_id,customer_id,attribute_code,attribute_name,old_value,new_value,changed_by,remarks) VALUES(p_society_id,p_customer_id,'AREA','Flat Area',v_old,p_new_area::text,p_user_id,p_remarks) RETURNING service_attribute_history_id INTO v_id;
 RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION sp_update_customer_attribute(p_society_id bigint,p_customer_id bigint,p_attribute_code varchar,p_attribute_name varchar,p_new_value text,p_user_id bigint,p_remarks text)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_old text; v_id bigint;
BEGIN
 SELECT CASE p_attribute_code WHEN 'MOBILE' THEN phone WHEN 'EMAIL' THEN email WHEN 'NAME' THEN full_name ELSE NULL END INTO v_old FROM m_customer WHERE customer_id=p_customer_id AND society_id=p_society_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Customer not found in selected society'; END IF;
 IF p_attribute_code='MOBILE' THEN UPDATE m_customer SET phone=p_new_value WHERE customer_id=p_customer_id AND society_id=p_society_id;
 ELSIF p_attribute_code='EMAIL' THEN UPDATE m_customer SET email=p_new_value WHERE customer_id=p_customer_id AND society_id=p_society_id;
 ELSIF p_attribute_code='NAME' THEN UPDATE m_customer SET full_name=p_new_value WHERE customer_id=p_customer_id AND society_id=p_society_id;
 ELSE RAISE EXCEPTION 'Unsupported service attribute'; END IF;
 INSERT INTO t_customer_service_attribute_history(society_id,customer_id,attribute_code,attribute_name,old_value,new_value,changed_by,remarks) VALUES(p_society_id,p_customer_id,p_attribute_code,p_attribute_name,v_old,p_new_value,p_user_id,p_remarks) RETURNING service_attribute_history_id INTO v_id;
 RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION sp_save_ticket(p_society_id bigint,p_ticket_id bigint,p_title varchar,p_description text,p_status_code varchar,p_priority varchar,p_user_id bigint)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_id bigint; v_status bigint;
BEGIN
 SELECT ticket_status_id INTO v_status FROM m_ticket_status WHERE status_code=p_status_code AND visible AND is_active;
 IF v_status IS NULL THEN RAISE EXCEPTION 'Ticket status not found'; END IF;
 IF p_ticket_id>0 THEN UPDATE t_it_ticket SET title=p_title,description=p_description,ticket_status_id=v_status,priority=p_priority,updated_at=now(),resolved_at=CASE WHEN p_status_code='RESOLVED' THEN now() ELSE resolved_at END WHERE ticket_id=p_ticket_id AND society_id=p_society_id RETURNING ticket_id INTO v_id;
 ELSE INSERT INTO t_it_ticket(society_id,ticket_no,title,description,ticket_status_id,priority,created_by) VALUES(p_society_id,'TKT-'||to_char(now(),'YYYYMMDDHH24MISSMS'),p_title,p_description,v_status,p_priority,p_user_id) RETURNING ticket_id INTO v_id; END IF;
 IF v_id IS NULL THEN RAISE EXCEPTION 'Ticket not found in selected society'; END IF;
 IF p_status_code='RESOLVED' THEN INSERT INTO t_notification(society_id,recipient_user_id,notification_type,title,message,reference_entity,reference_id) SELECT society_id,created_by,'TICKET_RESOLVED','IT Ticket Resolved','Ticket '||ticket_no||' has been resolved.','TICKET',ticket_id FROM t_it_ticket WHERE ticket_id=v_id;
 END IF;
 RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION sp_record_dishonored_cheque(p_society_id bigint,p_payment_id bigint,p_reason_id bigint,p_bank_charge numeric,p_user_id bigint,p_remarks text)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_id bigint; v_customer bigint; v_flat bigint; v_amt numeric;
BEGIN
 SELECT customer_id,flat_id,amount INTO v_customer,v_flat,v_amt FROM t_payment WHERE payment_id=p_payment_id AND society_id=p_society_id AND payment_mode='CHEQUE';
 IF NOT FOUND THEN RAISE EXCEPTION 'Cheque payment not found in selected society'; END IF;
 INSERT INTO t_dishonored_cheque(society_id,payment_id,customer_id,flat_id,dishonor_reason_id,bank_charge,due_amount,created_by,remarks) VALUES(p_society_id,p_payment_id,v_customer,v_flat,p_reason_id,coalesce(p_bank_charge,0),v_amt+coalesce(p_bank_charge,0),p_user_id,p_remarks) RETURNING dishonored_cheque_id INTO v_id;
 UPDATE t_payment SET status='Dishonored' WHERE payment_id=p_payment_id AND society_id=p_society_id;
 INSERT INTO t_service_charge(society_id,customer_id,flat_id,service_charge_type_id,amount,reference_no,remarks,created_by)
 SELECT p_society_id,v_customer,v_flat,service_charge_type_id,coalesce(p_bank_charge,0),'CHEQUE-'||p_payment_id,'Dishonored Cheque Charges',p_user_id FROM m_service_charge_type WHERE society_id=p_society_id AND charge_code='DISHONORED_CHEQUE' AND visible AND is_active;
 INSERT INTO t_notification(society_id,recipient_user_id,customer_id,notification_type,title,message,reference_entity,reference_id)
 SELECT p_society_id,u.user_id,'CHEQUE_DISHONORED','Dishonored Cheque','A cheque payment was dishonored and dues were added.','DISHONORED_CHEQUE',v_id FROM m_user u WHERE u.society_id=p_society_id AND u.role_code='SOCIETY_ADMIN' AND u.is_active;
 RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION sp_save_bank_detail(p_society_id bigint,p_bank_id bigint,p_bank_name varchar,p_account_name varchar,p_account_number varchar,p_ifsc varchar,p_branch varchar,p_account_type varchar,p_upi varchar,p_active boolean,p_user bigint,p_remark text)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_id bigint;
BEGIN
 IF p_bank_id>0 THEN UPDATE m_bank_detail SET bank_name=p_bank_name,account_name=p_account_name,account_number=p_account_number,ifsc_code=p_ifsc,branch_name=p_branch,account_type=p_account_type,upi_id=p_upi,is_active=p_active,modify_by=p_user,modify_date=now(),modify_remark=p_remark WHERE bank_detail_id=p_bank_id AND society_id=p_society_id RETURNING bank_detail_id INTO v_id;
 ELSE INSERT INTO m_bank_detail(society_id,bank_name,account_name,account_number,ifsc_code,branch_name,account_type,upi_id,is_active,modify_by,modify_remark) VALUES(p_society_id,p_bank_name,p_account_name,p_account_number,p_ifsc,p_branch,p_account_type,p_upi,p_active,p_user,p_remark) RETURNING bank_detail_id INTO v_id; END IF;
 IF v_id IS NULL THEN RAISE EXCEPTION 'Bank detail not found in selected society'; END IF; RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION sp_save_service_charge(p_society_id bigint,p_customer_id bigint,p_flat_id bigint,p_type_id bigint,p_amount numeric,p_reference varchar,p_remarks text,p_user bigint)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_id bigint;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM m_service_charge_type WHERE service_charge_type_id=p_type_id AND society_id=p_society_id AND is_active AND visible) THEN RAISE EXCEPTION 'Service charge type not found'; END IF;
 INSERT INTO t_service_charge(society_id,customer_id,flat_id,service_charge_type_id,amount,reference_no,remarks,created_by) VALUES(p_society_id,p_customer_id,p_flat_id,p_type_id,p_amount,p_reference,p_remarks,p_user) RETURNING service_charge_id INTO v_id;
 RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION sp_save_document(p_society_id bigint,p_customer_id bigint,p_flat_id bigint,p_type_id bigint,p_file_name varchar,p_content_type varchar,p_file_size bigint,p_file_data bytea,p_user bigint)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_id bigint;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM m_document_type WHERE document_type_id=p_type_id AND society_id=p_society_id AND is_active AND visible) THEN RAISE EXCEPTION 'Document type not found'; END IF;
 INSERT INTO t_customer_document(society_id,customer_id,flat_id,document_type_id,file_name,content_type,file_size,file_data,uploaded_by) VALUES(p_society_id,p_customer_id,p_flat_id,p_type_id,p_file_name,p_content_type,p_file_size,p_file_data,p_user) RETURNING document_id INTO v_id;
 RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION fn_super_tickets()
RETURNS TABLE(ticket_id bigint,society_id bigint,society_name varchar,ticket_no varchar,title varchar,description text,status_code varchar,status_name varchar,status_color varchar,priority varchar,created_at timestamptz,updated_at timestamptz,resolved_at timestamptz)
LANGUAGE sql AS $$ SELECT t.ticket_id,t.society_id,society_name,t.ticket_no,t.title,t.description,st.status_code,st.status_name,st.display_color,t.priority,t.created_at,t.updated_at,t.resolved_at FROM t_it_ticket t JOIN m_society s ON s.society_id=t.society_id JOIN m_ticket_status st ON st.ticket_status_id=t.ticket_status_id ORDER BY t.created_at DESC; $$;

CREATE OR REPLACE FUNCTION sp_super_update_ticket(p_ticket_id bigint,p_status_code varchar,p_user_id bigint)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_status bigint;v_society bigint;v_id bigint;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM m_user WHERE user_id=p_user_id AND role_code='SUPER_ADMIN' AND is_active) THEN RAISE EXCEPTION 'Super Admin permission required'; END IF;
 SELECT ticket_status_id INTO v_status FROM m_ticket_status WHERE status_code=p_status_code AND is_active AND visible;
 SELECT society_id INTO v_society FROM t_it_ticket WHERE ticket_id=p_ticket_id FOR UPDATE;
 IF v_status IS NULL OR v_society IS NULL THEN RAISE EXCEPTION 'Ticket or status not found'; END IF;
 UPDATE t_it_ticket SET ticket_status_id=v_status,updated_at=now(),resolved_at=CASE WHEN p_status_code='RESOLVED' THEN now() ELSE resolved_at END WHERE ticket_id=p_ticket_id RETURNING ticket_id INTO v_id;
 INSERT INTO t_notification(society_id,recipient_user_id,notification_type,title,message,reference_entity,reference_id,channel)
 SELECT v_society,u.user_id,'TICKET_STATUS','IT Ticket Status Updated','IT ticket status changed to '||p_status_code,'TICKET',v_id,'APP' FROM m_user u WHERE u.society_id=v_society AND u.role_code='SOCIETY_ADMIN' AND u.is_active;
 RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION fn_document_content(p_society_id bigint,p_document_id bigint)
RETURNS TABLE(file_name varchar,content_type varchar,file_data bytea)
LANGUAGE sql AS $$ SELECT file_name,content_type,file_data FROM t_customer_document WHERE society_id=p_society_id AND document_id=p_document_id AND is_active; $$;

CREATE OR REPLACE FUNCTION fn_ticket_statuses()
RETURNS TABLE(ticket_status_id bigint,status_code varchar,status_name varchar,display_color varchar)
LANGUAGE sql AS $$ SELECT ticket_status_id,status_code,status_name,display_color FROM m_ticket_status WHERE is_active AND visible ORDER BY status_order; $$;

CREATE OR REPLACE FUNCTION fn_tickets(p_society_id bigint)
RETURNS TABLE(ticket_id bigint,ticket_no varchar,title varchar,description text,status_code varchar,status_name varchar,status_color varchar,priority varchar,created_at timestamptz,updated_at timestamptz,resolved_at timestamptz)
LANGUAGE sql AS $$ SELECT t.ticket_id,t.ticket_no,t.title,t.description,s.status_code,s.status_name,s.display_color,t.priority,t.created_at,t.updated_at,t.resolved_at FROM t_it_ticket t JOIN m_ticket_status s ON s.ticket_status_id=t.ticket_status_id WHERE t.society_id=p_society_id ORDER BY t.created_at DESC; $$;

CREATE OR REPLACE FUNCTION fn_customer_documents(p_society_id bigint,p_customer_id bigint)
RETURNS TABLE(document_id bigint,document_type varchar,file_name varchar,content_type varchar,file_size bigint,uploaded_at timestamptz,flat_no varchar)
LANGUAGE sql AS $$ SELECT d.document_id,dt.document_name,d.file_name,d.content_type,d.file_size,d.uploaded_at,f.flat_no FROM t_customer_document d JOIN m_document_type dt ON dt.document_type_id=d.document_type_id LEFT JOIN m_flat f ON f.flat_id=d.flat_id WHERE d.society_id=p_society_id AND d.customer_id=p_customer_id AND d.is_active ORDER BY d.uploaded_at DESC; $$;

CREATE OR REPLACE FUNCTION fn_customer_service_history_requested(p_society_id bigint,p_customer_id bigint)
RETURNS TABLE(history_id bigint,attribute_name varchar,old_value text,new_value text,changed_at timestamptz,changed_by bigint,remarks text)
LANGUAGE sql AS $$ SELECT service_attribute_history_id,attribute_name,old_value,new_value,changed_at,changed_by,remarks FROM t_customer_service_attribute_history WHERE society_id=p_society_id AND customer_id=p_customer_id ORDER BY changed_at DESC; $$;

CREATE OR REPLACE FUNCTION fn_dishonored_cheques(p_society_id bigint)
RETURNS TABLE(dishonored_cheque_id bigint,payment_id bigint,customer_name varchar,flat_no varchar,cheque_no varchar,cheque_date date,reason varchar,bank_charge numeric,due_amount numeric,dishonored_date timestamptz,status varchar)
LANGUAGE sql AS $$ SELECT d.dishonored_cheque_id,d.payment_id,c.full_name,f.flat_no,d.cheque_no,d.cheque_date,r.reason_name,d.bank_charge,d.due_amount,d.dishonored_date,d.status FROM t_dishonored_cheque d LEFT JOIN m_customer c ON c.customer_id=d.customer_id LEFT JOIN m_flat f ON f.flat_id=d.flat_id LEFT JOIN m_cheque_dishonor_reason r ON r.dishonor_reason_id=d.dishonor_reason_id WHERE d.society_id=p_society_id ORDER BY d.dishonored_date DESC; $$;

CREATE OR REPLACE FUNCTION fn_customer_search_requested(p_society_id bigint,p_search varchar)
RETURNS TABLE(customer_id bigint,customer_code varchar,full_name varchar,phone varchar,email varchar,flat_count bigint,flat_numbers text,current_dues numeric,next_due_date date)
LANGUAGE sql AS $$ SELECT c.customer_id,c.customer_code,c.full_name,c.phone,c.email,count(cf.flat_id),string_agg(f.flat_no,', ' ORDER BY f.flat_no),COALESCE((SELECT sum(GREATEST(b.total_amount-b.paid_amount,0)) FROM t_bill b WHERE b.society_id=p_society_id AND b.flat_id IN(SELECT flat_id FROM m_customer_flat WHERE customer_id=c.customer_id AND society_id=p_society_id) AND b.status NOT IN ('Paid','Cancelled')),0), (SELECT min(b.due_date) FROM t_bill b WHERE b.society_id=p_society_id AND b.flat_id IN(SELECT flat_id FROM m_customer_flat WHERE customer_id=c.customer_id AND society_id=p_society_id) AND b.status NOT IN ('Paid','Cancelled')) FROM m_customer c LEFT JOIN m_customer_flat cf ON cf.customer_id=c.customer_id AND cf.society_id=p_society_id LEFT JOIN m_flat f ON f.flat_id=cf.flat_id WHERE c.society_id=p_society_id AND (coalesce(p_search,'')='' OR c.full_name ILIKE '%'||p_search||'%' OR c.phone ILIKE '%'||p_search||'%' OR f.flat_no ILIKE '%'||p_search||'%') GROUP BY c.customer_id,c.customer_code,c.full_name,c.phone,c.email ORDER BY c.full_name; $$;

UPDATE m_module SET visible=true WHERE is_active;
UPDATE m_permission SET visible=true WHERE is_active;

INSERT INTO m_module(module_code,module_name,parent_module_code,display_order,visible,is_active) VALUES
('ADMIN_SUBSCRIPTION','Subscription & Billing Plan','ADMINISTRATOR',15,true,true),
('SOCIETY_MANAGEMENT','Society Management',NULL,25,true,true),
('SOC_NEW_BUILDING','New Building','SOCIETY_MANAGEMENT',26,true,true),
('SOC_NEW_WING','New Wing','SOCIETY_MANAGEMENT',27,true,true),
('SOC_NEW_FLAT','New Flat','SOCIETY_MANAGEMENT',28,true,true),
('SOC_NEW_PARKING','New Parking','SOCIETY_MANAGEMENT',29,true,true),
('SOC_CUSTOMER_MASTER','Customer / Area Management','SOCIETY_MANAGEMENT',30,true,true),
('COL_ACCEPT_PAYMENT','Accept Payment','COLLECTION_MANAGEMENT',51,true,true),
('COL_SERVICE_PAYMENT','Accept Services Payment','COLLECTION_MANAGEMENT',52,true,true),
('COL_BANK_DETAILS','Add / Edit Bank Details','COLLECTION_MANAGEMENT',53,true,true),
('COL_DISHONORED','Dishonored Cheque','COLLECTION_MANAGEMENT',57,true,true),
('BACKOFFICE_TICKET','Raise Ticket [IT Help Desk]','BACK_OFFICE',21,true,true),
('BACKOFFICE_DOCUMENT','Document Management System','BACK_OFFICE',23,true,true),
('BACKOFFICE_SERVICE','Update Service Attribute','BACK_OFFICE',24,true,true),
('BACKOFFICE_MIGRATION','Master Data Migration','BACK_OFFICE',25,true,true),
('ROLE_RIGHTS','Role & Rights','ADMINISTRATOR',40,true,true),
('MODULE_SUBMODULE','Module & Submodule','ADMINISTRATOR',41,true,true),
('CRM_CUSTOMER_ACCOUNT','Customer Account','CRM',82,true,true),
('CRM_CUSTOMER_INTERACTION','Customer Interaction','CRM',83,true,true),
('MIS_CONSUMER_MASTER','Consumer Master Data','MIS',121,true,true),
('MIS_BILLING_DATA','Billing Data','MIS',122,true,true),
('MIS_COLLECTION_DETAILS','Collection Details','MIS',123,true,true),
('MIS_COMPLAINT_HISTORY','Complaint History','MIS',124,true,true),
('NOTIFICATION_CENTER','Notification','BACK_OFFICE',28,true,true)
ON CONFLICT(module_code) DO UPDATE SET module_name=excluded.module_name,parent_module_code=excluded.parent_module_code,display_order=excluded.display_order,visible=true,is_active=true;

INSERT INTO m_permission(module_code,action_code,permission_name)
SELECT m.module_code,a.code,m.module_name||' - '||a.code FROM m_module m CROSS JOIN (VALUES ('VIEW'),('ADD'),('EDIT'),('DELETE'),('APPROVE'),('POST'),('PRINT'),('EXPORT')) a(code)
WHERE m.visible AND NOT EXISTS(SELECT 1 FROM m_permission p WHERE p.module_code=m.module_code AND p.action_code=a.code);

INSERT INTO m_role_permission(role_id,permission_id)
SELECT r.role_id,p.permission_id FROM m_role r JOIN m_permission p ON p.module_code IN
('APP_DASHBOARD','ADMIN_SUBSCRIPTION','SOCIETY_MANAGEMENT','SOC_NEW_BUILDING','SOC_NEW_WING','SOC_NEW_FLAT','SOC_NEW_PARKING','SOC_CUSTOMER_MASTER','COL_ACCEPT_PAYMENT','COL_SERVICE_PAYMENT','COL_BANK_DETAILS','COL_DISHONORED','BACKOFFICE_TICKET','BACKOFFICE_DOCUMENT','BACKOFFICE_SERVICE','BACKOFFICE_MIGRATION','ROLE_RIGHTS','MODULE_SUBMODULE','CRM_CUSTOMER_ACCOUNT','CRM_CUSTOMER_INTERACTION','MIS_CONSUMER_MASTER','MIS_BILLING_DATA','MIS_COLLECTION_DETAILS','MIS_COMPLAINT_HISTORY','NOTIFICATION_CENTER')
WHERE r.role_code IN ('SOCIETY_ADMIN','SUPER_ADMIN') AND p.is_active ON CONFLICT DO NOTHING;

UPDATE m_module SET visible=false WHERE module_code IN
('DASHBOARD','SOCIETY','USERS','ROLES','CONFIGURATION','FLATS','RESIDENTS','BILLING','COLLECTION','PARKING','COMPLAINTS','VISITORS','DOCUMENTS','NOTICES','REPORTS','MIGRATION');
UPDATE m_module SET visible=false WHERE module_code IN
('ADM_CONTRACTOR','ADM_EMPLOYEE','ADM_CUSTOMER_COUNTS','ADM_SMS_CONFIG','ADM_MASTER_DATA','ADM_COLLECTION_CONFIG','ADM_SEND_SMS');
UPDATE m_module SET visible=false WHERE module_code IN
('BO_HELPDESK','BO_CONSUMER_MIGRATION');
UPDATE m_module SET visible=false WHERE parent_module_code='COLLECTION_MANAGEMENT' AND module_code NOT IN ('COL_ACCEPT_PAYMENT','COL_SERVICE_PAYMENT','COL_BANK_DETAILS','COL_DISHONORED');
UPDATE m_module SET visible=false WHERE parent_module_code='CRM' AND module_code NOT IN ('CRM_CUSTOMER_ACCOUNT','CRM_CUSTOMER_INTERACTION');
UPDATE m_module SET visible=false WHERE parent_module_code='MIS' AND module_code NOT IN ('MIS_CONSUMER_MASTER','MIS_BILLING_DATA','MIS_COLLECTION_DETAILS','MIS_COMPLAINT_HISTORY');

CREATE OR REPLACE FUNCTION sp_raise_complaint(p_society_id bigint,p_customer_id bigint,p_flat_id bigint,p_category varchar,p_title varchar,p_description text,p_user_id bigint)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_id bigint;
BEGIN
 INSERT INTO t_complaint(society_id,flat_id,customer_id,complaint_no,category,title,description,created_at) VALUES(p_society_id,p_flat_id,p_customer_id,'CMP-'||to_char(now(),'YYYYMMDDHH24MISSMS'),p_category,p_title,p_description,now()) RETURNING complaint_id INTO v_id;
 INSERT INTO t_notification(society_id,recipient_user_id,customer_id,notification_type,title,message,reference_entity,reference_id)
 SELECT p_society_id,u.user_id,'COMPLAINT','New Consumer Complaint',p_title,'COMPLAINT',v_id FROM m_user u WHERE u.society_id=p_society_id AND u.role_code='SOCIETY_ADMIN' AND u.is_active;
 RETURN v_id;
END; $$;


-- Final requested navigation hierarchy: only requested menus remain visible.
UPDATE m_module SET visible=false WHERE module_code IN (
'DASHBOARD','SOCIETY','USERS','ROLES','CONFIGURATION','FLATS','RESIDENTS','BILLING','COLLECTION','PARKING','COMPLAINTS','VISITORS','DOCUMENTS','NOTICES','REPORTS','MIGRATION',
'ADM_CONTRACTOR','ADM_EMPLOYEE','ADM_CUSTOMER_COUNTS','ADM_SMS_CONFIG','ADM_MASTER_DATA','ADM_COLLECTION_CONFIG','ADM_SEND_SMS','BO_HELPDESK','BO_CONSUMER_MIGRATION','BO_REPORTS','BO_DOCUMENTS','BO_NOTICES',
'COLLECTION','SA_DASHBOARD','SA_SOCIETY_PROFILE','SA_BUILDINGS','SA_WINGS','SA_FLATS','SA_RESIDENTS','SA_FAMILY','SA_BILLING_DASH','SA_BILL_GENERATION','SA_BILL_REGISTER','SA_BILL_ADJUSTMENT','SA_REBATE','SA_DPC','SA_CHARGE_CONFIG','SA_RATE_PLANS','SA_TAX_CONFIG','SA_COLLECTION','SA_PAYMENT_ENTRY','SA_RECEIPTS','SA_REVERSAL','SA_PARKING','SA_VEHICLES','SA_PARKING_ASSIGN','SA_COMPLAINTS','SA_VISITORS','SA_SECURITY','SA_DOCUMENTS','SA_NOTICES','SA_COMMUNICATION','SA_REPORTS','SA_MIGRATION','SA_AUDIT','CASH_DASHBOARD','CASH_CUSTOMER','CASH_ACCEPT_PAYMENT','CASH_RECEIPTS','CASH_ALLOCATION','CASH_REVERSAL','CASH_ADJUSTMENT','CASH_BILL_LOOKUP'
);
INSERT INTO m_module(module_code,module_name,parent_module_code,display_order,visible,is_active) VALUES
('ADMIN_CREATE_ACCOUNT','Create Account','ADM_ACCOUNTS',11,true,true),
('ADMIN_MANAGE_ACCOUNT','Manage / Edit Account','ADM_ACCOUNTS',12,true,true),
('SOC_CUSTOMER','Customer','SOCIETY_MANAGEMENT',30,true,true),
('SOC_AREA_UPDATE','Area Update','SOCIETY_MANAGEMENT',31,true,true)
ON CONFLICT(module_code) DO UPDATE SET module_name=excluded.module_name,parent_module_code=excluded.parent_module_code,display_order=excluded.display_order,visible=true,is_active=true;
UPDATE m_module SET module_name='Manage Account',parent_module_code='ADMINISTRATOR',display_order=10,visible=true,is_active=true WHERE module_code='ADM_ACCOUNTS';
UPDATE m_module SET visible=false WHERE module_code IN ('SOC_NEW_BUILDING','SOC_NEW_WING','SOC_CUSTOMER_MASTER');
UPDATE m_module SET parent_module_code=NULL,display_order=90,visible=true,is_active=true,module_name='Notification Center' WHERE module_code='NOTIFICATION_CENTER';
UPDATE m_module SET parent_module_code='BACK_OFFICE',module_name='Raise Ticket',display_order=21,visible=true,is_active=true WHERE module_code='BACKOFFICE_TICKET';
UPDATE m_module SET module_name='Document Management System',display_order=23,visible=true,is_active=true WHERE module_code='BACKOFFICE_DOCUMENT';
UPDATE m_module SET module_name='Update Service Attribute',display_order=24,visible=true,is_active=true WHERE module_code='BACKOFFICE_SERVICE';
UPDATE m_module SET module_name='Master Data Migration',display_order=25,visible=true,is_active=true WHERE module_code='BACKOFFICE_MIGRATION';
UPDATE m_module SET visible=true,is_active=true,parent_module_code='ADMINISTRATOR' WHERE module_code IN ('ADMIN_SUBSCRIPTION','ROLE_RIGHTS','MODULE_SUBMODULE');
UPDATE m_module SET visible=true,is_active=true,parent_module_code='SOCIETY_MANAGEMENT' WHERE module_code IN ('SOC_NEW_FLAT','SOC_NEW_PARKING');
UPDATE m_module SET visible=true,is_active=true,parent_module_code='COLLECTION_MANAGEMENT' WHERE module_code IN ('COL_ACCEPT_PAYMENT','COL_SERVICE_PAYMENT','COL_BANK_DETAILS','COL_DISHONORED');
UPDATE m_module SET visible=true,is_active=true,parent_module_code='BACK_OFFICE' WHERE module_code IN ('BACKOFFICE_TICKET','BACKOFFICE_DOCUMENT','BACKOFFICE_SERVICE','BACKOFFICE_MIGRATION');
UPDATE m_module SET visible=true,is_active=true,parent_module_code='CRM' WHERE module_code IN ('CRM_CUSTOMER_ACCOUNT','CRM_CUSTOMER_INTERACTION');
UPDATE m_module SET visible=true,is_active=true,parent_module_code='MIS' WHERE module_code IN ('MIS_CONSUMER_MASTER','MIS_BILLING_DATA','MIS_COLLECTION_DETAILS','MIS_COMPLAINT_HISTORY');

INSERT INTO m_permission(module_code,action_code,permission_name,is_active,visible)
SELECT m.module_code,a.code,m.module_name||' - '||a.code,true,true FROM m_module m CROSS JOIN (VALUES('VIEW'),('ADD'),('EDIT'),('DELETE'),('APPROVE'),('POST'),('PRINT'),('EXPORT'),('ASSIGN'),('IMPORT'),('REFUND')) a(code)
WHERE m.module_code IN ('ADMIN_CREATE_ACCOUNT','ADMIN_MANAGE_ACCOUNT','SOC_CUSTOMER','SOC_AREA_UPDATE') ON CONFLICT(module_code,action_code) DO UPDATE SET is_active=true,visible=true;
INSERT INTO m_role_permission(role_id,permission_id)
SELECT r.role_id,p.permission_id FROM m_role r JOIN m_permission p ON p.module_code IN ('ADMIN_CREATE_ACCOUNT','ADMIN_MANAGE_ACCOUNT','SOC_CUSTOMER','SOC_AREA_UPDATE')
WHERE r.role_code IN ('SOCIETY_ADMIN','SUPER_ADMIN') AND p.is_active ON CONFLICT DO NOTHING;
