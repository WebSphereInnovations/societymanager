SET search_path TO society_manager, public;

CREATE TABLE IF NOT EXISTS m_subscription_plan(
 subscription_plan_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 plan_code varchar(40) UNIQUE NOT NULL, plan_name varchar(120) NOT NULL,
 duration_days integer NOT NULL DEFAULT 365, price numeric(18,2) NOT NULL DEFAULT 0,
 max_flats integer, max_users integer, features jsonb NOT NULL DEFAULT '{}'::jsonb,
 is_active boolean NOT NULL DEFAULT true
);
CREATE TABLE IF NOT EXISTS m_society_subscription(
 subscription_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 society_id bigint NOT NULL REFERENCES m_society(society_id), subscription_plan_id bigint NOT NULL REFERENCES m_subscription_plan(subscription_plan_id),
 start_date date NOT NULL, end_date date NOT NULL, amount numeric(18,2) NOT NULL DEFAULT 0,
 payment_status varchar(30) NOT NULL DEFAULT 'Pending', payment_reference varchar(120), is_active boolean NOT NULL DEFAULT true,
 UNIQUE(society_id,subscription_plan_id,start_date)
);
CREATE TABLE IF NOT EXISTS t_subscription_payment(
 subscription_payment_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 society_id bigint NOT NULL REFERENCES m_society(society_id), subscription_id bigint NOT NULL REFERENCES m_society_subscription(subscription_id),
 payment_date timestamptz NOT NULL DEFAULT now(), amount numeric(18,2) NOT NULL, payment_mode varchar(30) NOT NULL,
 reference_no varchar(120), status varchar(30) NOT NULL DEFAULT 'Success', created_by bigint REFERENCES m_user(user_id)
);
CREATE INDEX IF NOT EXISTS ix_m_society_subscription_end ON m_society_subscription(society_id,end_date,is_active);

INSERT INTO m_subscription_plan(plan_code,plan_name,duration_days,price,max_flats,max_users,features) VALUES
('STARTER','Starter',365,9999,100,10,'{"billing":true,"collection":true,"complaints":true,"parking":true}'::jsonb),
('PRO','Professional',365,24999,500,50,'{"billing":true,"collection":true,"complaints":true,"parking":true,"visitor":true,"reports":true,"migration":true}'::jsonb),
('ENTERPRISE','Enterprise',365,49999,2000,200,'{"all":true,"api":true,"advanced_reports":true}'::jsonb)
ON CONFLICT(plan_code) DO NOTHING;

INSERT INTO m_module(module_code,module_name,parent_module_code,display_order) VALUES
('SUPER_DASHBOARD','Dashboard',NULL,10),('SUPER_SOCIETIES','Societies','SOCIETY',20),('SUPER_SUBSCRIPTIONS','Subscriptions & Plans','SOCIETY',21),('SUPER_PLATFORM_BILLING','Platform Billing','SOCIETY',22),
('SUPER_USERS','Users','USERS',30),('SUPER_ROLES','Roles & Rights','ROLES',40),('SUPER_MODULES','Modules & Submodules','ROLES',41),('SUPER_SECURITY','Security & Sessions','ROLES',42),('SUPER_SETTINGS','System Settings','CONFIGURATION',50),('SUPER_AUDIT','Audit Log','AUDIT',170),
('SA_DASHBOARD','Dashboard','DASHBOARD',10),('SA_SOCIETY_PROFILE','Society Profile','SOCIETY',20),('SA_BUILDINGS','Buildings','FLATS',60),('SA_WINGS','Wings','FLATS',61),('SA_FLATS','Flats','FLATS',62),('SA_RESIDENTS','Residents / Owners','RESIDENTS',70),('SA_FAMILY','Family / Occupants','RESIDENTS',71),
('SA_BILLING_DASH','Billing Dashboard','BILLING',80),('SA_BILL_GENERATION','Bill Generation','BILLING',81),('SA_BILL_REGISTER','Bill Register','BILLING',82),('SA_BILL_ADJUSTMENT','Billing Adjustment','BILLING',83),('SA_REBATE','Rebate / Early Payment','BILLING',84),('SA_DPC','DPC / Interest','BILLING',85),('SA_CHARGE_CONFIG','Charge & Rate Configuration','CONFIGURATION',86),('SA_RATE_PLANS','Rate Plans & Effective Dates','CONFIGURATION',87),('SA_TAX_CONFIG','Tax / GST Configuration','CONFIGURATION',88),
('SA_COLLECTION','Collection','COLLECTION',90),('SA_PAYMENT_ENTRY','Payment Entry','COLLECTION',91),('SA_RECEIPTS','Receipts','COLLECTION',92),('SA_REVERSAL','Collection Reversal','COLLECTION',93),
('SA_PARKING','Parking Slots','PARKING',100),('SA_VEHICLES','Vehicles','PARKING',101),('SA_PARKING_ASSIGN','Parking Assignment','PARKING',102),
('SA_COMPLAINTS','Complaints','COMPLAINTS',110),('SA_VISITORS','Visitor Entry','VISITORS',120),('SA_SECURITY','Security / Gate','VISITORS',121),('SA_DOCUMENTS','Documents','DOCUMENTS',130),('SA_NOTICES','Notices','NOTICES',140),('SA_COMMUNICATION','SMS / Email / Notifications','NOTICES',141),('SA_REPORTS','Reports','REPORTS',150),('SA_MIGRATION','Back Office Migration','MIGRATION',160),('SA_AUDIT','Audit Trail','AUDIT',170),
('CASH_DASHBOARD','Dashboard','DASHBOARD',10),('CASH_CUSTOMER','Customer Search','COLLECTION',90),('CASH_ACCEPT_PAYMENT','Accept Payment','COLLECTION',91),('CASH_RECEIPTS','Receipt Reprint','COLLECTION',92),('CASH_ALLOCATION','Payment Allocation','COLLECTION',93),('CASH_REVERSAL','Payment Reversal','COLLECTION',94),('CASH_ADJUSTMENT','Adjustment','BILLING',83),('CASH_BILL_LOOKUP','Bill Lookup','BILLING',82),
('CUST_DASHBOARD','My Dashboard','DASHBOARD',10),('CUST_PROFILE','My Profile','RESIDENTS',70),('CUST_FLAT','My Flat / Unit','RESIDENTS',71),('CUST_FAMILY','Family Members','RESIDENTS',72),('CUST_PARKING','My Parking','PARKING',100),('CUST_VEHICLES','My Vehicles','PARKING',101),('CUST_BILLS','My Bills','BILLING',80),('CUST_PAYMENTS','My Payments','COLLECTION',90),('CUST_RECEIPTS','My Receipts','COLLECTION',91),('CUST_ADJUSTMENTS','My Adjustments','BILLING',83),('CUST_COMPLAINTS','My Complaints','COMPLAINTS',110),('CUST_DOCUMENTS','My Documents','DOCUMENTS',130),('CUST_NOTICES','Society Notices','NOTICES',140),('CUST_NOTIFICATIONS','Notifications','NOTICES',141)
ON CONFLICT(module_code) DO NOTHING;

CREATE OR REPLACE FUNCTION fn_super_admin_dashboard()
RETURNS TABLE(total_societies bigint,active_societies bigint,total_flats bigint,total_customers bigint,total_billed numeric,total_collected numeric,active_subscriptions bigint,expiring_30_days bigint)
LANGUAGE sql AS $$
SELECT (SELECT count(*) FROM m_society),(SELECT count(*) FROM m_society WHERE is_active),(SELECT count(*) FROM m_flat),(SELECT count(*) FROM m_customer),
COALESCE((SELECT sum(total_amount) FROM t_bill WHERE bill_month=date_trunc('month',current_date)::date),0),
COALESCE((SELECT sum(amount) FROM t_payment WHERE payment_date>=date_trunc('month',current_date) AND status='Success'),0),
(SELECT count(*) FROM m_society_subscription WHERE is_active AND end_date>=current_date),
(SELECT count(*) FROM m_society_subscription WHERE is_active AND end_date BETWEEN current_date AND current_date+30);
$$;

CREATE OR REPLACE FUNCTION fn_super_admin_societies()
RETURNS TABLE(society_id bigint,society_code varchar,society_name varchar,is_active boolean,total_flats bigint,total_customers bigint,plan_name varchar,subscription_end date,days_remaining integer)
LANGUAGE sql AS $$
SELECT s.society_id,s.society_code,s.society_name,s.is_active,
(SELECT count(*) FROM m_flat f WHERE f.society_id=s.society_id),(SELECT count(*) FROM m_customer c WHERE c.society_id=s.society_id),
sp.plan_name,ss.end_date,(ss.end_date-current_date)::integer
FROM m_society s
LEFT JOIN LATERAL (SELECT * FROM m_society_subscription x WHERE x.society_id=s.society_id AND x.is_active ORDER BY x.end_date DESC LIMIT 1) ss ON true
LEFT JOIN m_subscription_plan sp ON sp.subscription_plan_id=ss.subscription_plan_id ORDER BY s.society_name;
$$;

CREATE OR REPLACE FUNCTION fn_super_admin_subscriptions()
RETURNS TABLE(subscription_id bigint,society_id bigint,society_name varchar,plan_name varchar,start_date date,end_date date,amount numeric,payment_status varchar,days_remaining integer)
LANGUAGE sql AS $$
SELECT ss.subscription_id,ss.society_id,s.society_name,sp.plan_name,ss.start_date,ss.end_date,ss.amount,ss.payment_status,(ss.end_date-current_date)::integer
FROM m_society_subscription ss JOIN m_society s ON s.society_id=ss.society_id JOIN m_subscription_plan sp ON sp.subscription_plan_id=ss.subscription_plan_id ORDER BY ss.end_date;
$$;

CREATE OR REPLACE FUNCTION fn_super_admin_set_subscription(p_society_id bigint,p_plan_code varchar,p_start date,p_days integer,p_amount numeric,p_user_id bigint)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_plan bigint; v_id bigint;
BEGIN
 SELECT subscription_plan_id INTO v_plan FROM m_subscription_plan WHERE plan_code=p_plan_code AND is_active;
 IF v_plan IS NULL THEN RAISE EXCEPTION 'Subscription plan not found'; END IF;
 UPDATE m_society_subscription SET is_active=false WHERE society_id=p_society_id AND is_active;
 INSERT INTO m_society_subscription(society_id,subscription_plan_id,start_date,end_date,amount,payment_status,is_active)
 VALUES(p_society_id,v_plan,p_start,p_start+greatest(p_days,1)-1,p_amount,'Pending',true) RETURNING subscription_id INTO v_id;
 PERFORM fn_log_audit(p_society_id,p_user_id,'m_society_subscription',v_id,'CREATE',NULL,jsonb_build_object('plan',p_plan_code,'days',p_days,'amount',p_amount));
 RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION fn_society_charge_rules(p_society_id bigint)
RETURNS TABLE(charge_rule_id bigint,charge_code varchar,charge_name varchar,calculation_method varchar,rate numeric,effective_from date,effective_to date,scope_type varchar,scope_value varchar)
LANGUAGE sql AS $$
SELECT cr.charge_rule_id,ct.charge_code,ct.charge_name,cr.calculation_method,cr.rate,cr.effective_from,cr.effective_to,cr.scope_type,cr.scope_value
FROM m_charge_rule cr JOIN m_charge_type ct ON ct.charge_type_id=cr.charge_type_id WHERE cr.society_id=p_society_id ORDER BY cr.effective_from DESC,ct.charge_name;
$$;

CREATE OR REPLACE FUNCTION fn_society_save_charge_rule(p_society_id bigint,p_charge_code varchar,p_plan_name varchar,p_method varchar,p_rate numeric,p_effective_from date,p_effective_to date,p_scope_type varchar,p_scope_value varchar,p_user_id bigint)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_plan bigint; v_type bigint; v_id bigint;
BEGIN
 INSERT INTO m_rate_plan(society_id,plan_name,effective_from,effective_to) VALUES(p_society_id,p_plan_name,p_effective_from,p_effective_to)
 ON CONFLICT(society_id,plan_name,effective_from) DO UPDATE SET effective_to=excluded.effective_to RETURNING rate_plan_id INTO v_plan;
 SELECT charge_type_id INTO v_type FROM m_charge_type WHERE society_id=p_society_id AND charge_code=p_charge_code AND is_active;
 IF v_type IS NULL THEN RAISE EXCEPTION 'Charge type not found'; END IF;
 INSERT INTO m_charge_rule(society_id,rate_plan_id,charge_type_id,scope_type,scope_value,calculation_method,rate,effective_from,effective_to)
 VALUES(p_society_id,v_plan,v_type,p_scope_type,p_scope_value,p_method,p_rate,p_effective_from,p_effective_to) RETURNING charge_rule_id INTO v_id;
 PERFORM fn_log_audit(p_society_id,p_user_id,'m_charge_rule',v_id,'CREATE',NULL,jsonb_build_object('charge',p_charge_code,'method',p_method,'rate',p_rate,'effective_from',p_effective_from,'effective_to',p_effective_to));
 RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION fn_society_interest_rules(p_society_id bigint)
RETURNS TABLE(interest_rule_id bigint,rule_name varchar,calculation_type varchar,rate numeric,frequency varchar,simple_or_compound varchar,grace_days integer,cap_amount numeric,effective_from date,effective_to date)
LANGUAGE sql AS $$ SELECT interest_rule_id,rule_name,calculation_type,rate,frequency,simple_or_compound,grace_days,cap_amount,effective_from,effective_to FROM m_interest_rule WHERE society_id=p_society_id AND is_active ORDER BY effective_from DESC; $$;

CREATE OR REPLACE FUNCTION fn_society_save_interest_rule(p_society_id bigint,p_rule_name varchar,p_type varchar,p_rate numeric,p_frequency varchar,p_simple_compound varchar,p_grace_days integer,p_cap numeric,p_effective_from date,p_effective_to date,p_user_id bigint)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_id bigint;
BEGIN
 INSERT INTO m_interest_rule(society_id,rule_name,calculation_type,rate,frequency,simple_or_compound,grace_days,cap_amount,effective_from,effective_to)
 VALUES(p_society_id,p_rule_name,p_type,p_rate,p_frequency,p_simple_compound,p_grace_days,p_cap,p_effective_from,p_effective_to) RETURNING interest_rule_id INTO v_id;
 PERFORM fn_log_audit(p_society_id,p_user_id,'m_interest_rule',v_id,'CREATE',NULL,jsonb_build_object('rate',p_rate,'effective_from',p_effective_from)); RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION fn_cashier_customer_search(p_society_id bigint,p_search varchar)
RETURNS TABLE(customer_id bigint,customer_code varchar,full_name varchar,phone varchar,flat_no varchar,wing varchar,area_sqft numeric,outstanding numeric)
LANGUAGE sql AS $$
SELECT c.customer_id,c.customer_code,c.full_name,c.phone,f.flat_no,coalesce(w.wing_name,w.wing_code,''),f.area_sqft,
coalesce((SELECT sum(b.total_amount-b.paid_amount) FROM t_bill b WHERE b.society_id=p_society_id AND b.flat_id=f.flat_id AND b.total_amount>b.paid_amount),0)
FROM m_customer c JOIN m_customer_flat cf ON cf.customer_id=c.customer_id AND cf.is_primary JOIN m_flat f ON f.flat_id=cf.flat_id LEFT JOIN m_wing w ON w.wing_id=f.wing_id
WHERE c.society_id=p_society_id AND c.is_active AND (trim(coalesce(p_search,''))='' OR c.full_name ILIKE trim(p_search)||'%' OR c.full_name ILIKE '%'||trim(p_search)||'%' OR f.flat_no ILIKE '%'||trim(p_search)||'%' OR c.phone ILIKE '%'||trim(p_search)||'%') ORDER BY c.full_name LIMIT 100;
$$;

CREATE OR REPLACE FUNCTION fn_cashier_customer_360(p_society_id bigint,p_customer_id bigint)
RETURNS TABLE(customer_id bigint,customer_code varchar,full_name varchar,phone varchar,email varchar,flat_no varchar,wing varchar,building varchar,area_sqft numeric,occupancy_status varchar,total_billed numeric,total_paid numeric,outstanding numeric,parking_count bigint,vehicle_count bigint,complaint_count bigint,adjustment_count bigint)
LANGUAGE sql AS $$
SELECT c.customer_id,c.customer_code,c.full_name,c.phone,c.email,f.flat_no,coalesce(w.wing_name,w.wing_code,''),coalesce(b.building_name,b.building_code,''),f.area_sqft,f.occupancy_status,
coalesce((SELECT sum(x.total_amount) FROM t_bill x WHERE x.society_id=p_society_id AND x.flat_id=f.flat_id),0),coalesce((SELECT sum(x.amount) FROM t_payment x WHERE x.society_id=p_society_id AND x.customer_id=c.customer_id AND x.status='Success'),0),coalesce((SELECT sum(x.total_amount-x.paid_amount) FROM t_bill x WHERE x.society_id=p_society_id AND x.flat_id=f.flat_id AND x.total_amount>x.paid_amount),0),
(SELECT count(*) FROM t_parking_assignment pa WHERE pa.society_id=p_society_id AND pa.customer_id=c.customer_id AND pa.is_active),(SELECT count(*) FROM m_vehicle v WHERE v.society_id=p_society_id AND v.customer_id=c.customer_id AND v.is_active),(SELECT count(*) FROM t_complaint x WHERE x.society_id=p_society_id AND x.customer_id=c.customer_id),(SELECT count(*) FROM t_adjustment a WHERE a.society_id=p_society_id AND a.flat_id=f.flat_id)
FROM m_customer c JOIN m_customer_flat cf ON cf.customer_id=c.customer_id AND cf.is_primary JOIN m_flat f ON f.flat_id=cf.flat_id LEFT JOIN m_wing w ON w.wing_id=f.wing_id LEFT JOIN m_building b ON b.building_id=f.building_id
WHERE c.society_id=p_society_id AND c.customer_id=p_customer_id;
$$;

CREATE OR REPLACE FUNCTION fn_cashier_accept_payment(p_society_id bigint,p_customer_id bigint,p_flat_id bigint,p_amount numeric,p_mode varchar,p_reference varchar,p_remarks varchar,p_user_id bigint)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_id bigint; v_no varchar; v_remaining numeric:=p_amount; r record; v_alloc numeric;
BEGIN
 IF p_amount<=0 THEN RAISE EXCEPTION 'Payment amount must be greater than zero'; END IF;
 IF NOT EXISTS(SELECT 1 FROM m_customer_flat WHERE society_id=p_society_id AND customer_id=p_customer_id AND flat_id=p_flat_id AND is_primary) THEN RAISE EXCEPTION 'Customer and flat do not belong together'; END IF;
 SELECT 'PAY-'||to_char(current_date,'YYYYMMDD')||'-'||lpad((count(*)+1)::text,5,'0') INTO v_no FROM t_payment WHERE society_id=p_society_id AND payment_date::date=current_date;
 INSERT INTO t_payment(society_id,customer_id,flat_id,payment_no,amount,payment_mode,reference_no,remarks) VALUES(p_society_id,p_customer_id,p_flat_id,v_no,p_amount,p_mode,p_reference,p_remarks) RETURNING payment_id INTO v_id;
 FOR r IN SELECT bill_id,total_amount-paid_amount balance FROM t_bill WHERE society_id=p_society_id AND flat_id=p_flat_id AND total_amount>paid_amount ORDER BY bill_month,bill_id LOOP
  EXIT WHEN v_remaining<=0; v_alloc=least(v_remaining,r.balance);
  INSERT INTO t_payment_allocation(society_id,payment_id,bill_id,allocated_amount) VALUES(p_society_id,v_id,r.bill_id,v_alloc);
  UPDATE t_bill SET paid_amount=paid_amount+v_alloc,status=CASE WHEN paid_amount+v_alloc>=total_amount THEN 'Paid' ELSE 'Partially Paid' END WHERE bill_id=r.bill_id;
  v_remaining=v_remaining-v_alloc;
 END LOOP;
 INSERT INTO t_receipt(society_id,payment_id,receipt_no,amount) VALUES(p_society_id,v_id,'RCT-'||v_no,p_amount);
 PERFORM fn_log_audit(p_society_id,p_user_id,'t_payment',v_id,'CREATE',NULL,jsonb_build_object('amount',p_amount,'mode',p_mode));
 RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION fn_customer_360(p_user_id bigint)
RETURNS TABLE(customer_id bigint,customer_code varchar,full_name varchar,phone varchar,email varchar,flat_id bigint,flat_no varchar,wing varchar,building varchar,area_sqft numeric,occupancy_status varchar,parking_count bigint,vehicle_count bigint,total_billed numeric,total_paid numeric,outstanding numeric,complaint_count bigint,adjustment_count bigint,document_count bigint,notice_count bigint)
LANGUAGE sql AS $$
SELECT c.customer_id,c.customer_code,c.full_name,c.phone,c.email,f.flat_id,f.flat_no,coalesce(w.wing_name,w.wing_code,''),coalesce(b.building_name,b.building_code,''),f.area_sqft,f.occupancy_status,
(SELECT count(*) FROM t_parking_assignment pa WHERE pa.customer_id=c.customer_id AND pa.is_active),(SELECT count(*) FROM m_vehicle v WHERE v.customer_id=c.customer_id AND v.is_active),
coalesce((SELECT sum(x.total_amount) FROM t_bill x WHERE x.flat_id=f.flat_id),0),coalesce((SELECT sum(x.amount) FROM t_payment x WHERE x.customer_id=c.customer_id AND x.status='Success'),0),coalesce((SELECT sum(x.total_amount-x.paid_amount) FROM t_bill x WHERE x.flat_id=f.flat_id AND x.total_amount>x.paid_amount),0),
(SELECT count(*) FROM t_complaint x WHERE x.customer_id=c.customer_id),(SELECT count(*) FROM t_adjustment a WHERE a.flat_id=f.flat_id),(SELECT count(*) FROM t_document d WHERE d.customer_id=c.customer_id),(SELECT count(*) FROM t_notice n WHERE n.society_id=c.society_id AND n.status='Published')
FROM m_user u JOIN m_customer c ON c.customer_id=u.customer_id JOIN m_customer_flat cf ON cf.customer_id=c.customer_id AND cf.is_primary JOIN m_flat f ON f.flat_id=cf.flat_id LEFT JOIN m_wing w ON w.wing_id=f.wing_id LEFT JOIN m_building b ON b.building_id=f.building_id
WHERE u.user_id=p_user_id AND u.role_code='RESIDENT' AND u.is_active AND c.is_active;
$$;

CREATE OR REPLACE FUNCTION fn_customer_parking(p_user_id bigint)
RETURNS TABLE(slot_no varchar,slot_type varchar,charge numeric,flat_no varchar,assignment_start date,assignment_end date,vehicle_no varchar,vehicle_type varchar)
LANGUAGE sql AS $$
SELECT s.slot_no,s.slot_type,s.charge,f.flat_no,pa.start_date,pa.end_date,v.registration_no,v.vehicle_type FROM m_user u JOIN m_customer c ON c.customer_id=u.customer_id JOIN t_parking_assignment pa ON pa.customer_id=c.customer_id AND pa.is_active JOIN m_parking_slot s ON s.parking_slot_id=pa.parking_slot_id LEFT JOIN m_flat f ON f.flat_id=pa.flat_id LEFT JOIN m_vehicle v ON v.parking_slot_id=s.parking_slot_id AND v.customer_id=c.customer_id AND v.is_active WHERE u.user_id=p_user_id AND u.role_code='RESIDENT';
$$;

CREATE OR REPLACE FUNCTION fn_customer_payments(p_user_id bigint)
RETURNS TABLE(payment_id bigint,payment_no varchar,payment_date date,amount numeric,payment_mode varchar,reference_no varchar,status varchar,receipt_no varchar)
LANGUAGE sql AS $$
SELECT p.payment_id,p.payment_no,p.payment_date::date,p.amount,p.payment_mode,p.reference_no,p.status,r.receipt_no FROM m_user u JOIN t_payment p ON p.customer_id=u.customer_id LEFT JOIN t_receipt r ON r.payment_id=p.payment_id WHERE u.user_id=p_user_id AND u.role_code='RESIDENT' ORDER BY p.payment_date DESC;
$$;

CREATE OR REPLACE FUNCTION fn_customer_adjustments(p_user_id bigint)
RETURNS TABLE(adjustment_id bigint,bill_no varchar,adjustment_type varchar,amount numeric,reason text,created_at date)
LANGUAGE sql AS $$
SELECT a.adjustment_id,b.bill_no,a.adjustment_type,a.amount,a.reason,a.created_at::date FROM m_user u JOIN m_customer_flat cf ON cf.customer_id=u.customer_id AND cf.is_primary JOIN t_adjustment a ON a.flat_id=cf.flat_id LEFT JOIN t_bill b ON b.bill_id=a.bill_id WHERE u.user_id=p_user_id AND u.role_code='RESIDENT' ORDER BY a.created_at DESC;
$$;

CREATE OR REPLACE FUNCTION fn_customer_documents(p_user_id bigint)
RETURNS TABLE(document_id bigint,document_type varchar,file_name varchar,created_at date)
LANGUAGE sql AS $$
SELECT d.document_id,d.document_type,d.file_name,d.created_at::date FROM m_user u JOIN t_document d ON d.customer_id=u.customer_id WHERE u.user_id=p_user_id AND u.role_code='RESIDENT' ORDER BY d.created_at DESC;
$$;

CREATE OR REPLACE FUNCTION fn_customer_notices(p_user_id bigint)
RETURNS TABLE(notice_id bigint,notice_no varchar,title varchar,content text,publish_from timestamptz,publish_to timestamptz)
LANGUAGE sql AS $$
SELECT n.notice_id,n.notice_no,n.title,n.content,n.publish_from,n.publish_to FROM m_user u JOIN t_notice n ON n.society_id=u.society_id WHERE u.user_id=p_user_id AND u.role_code='RESIDENT' AND n.status='Published' ORDER BY n.publish_from DESC;
$$;