SET search_path TO society_manager, public;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

ALTER TABLE m_society ADD COLUMN IF NOT EXISTS default_language varchar(10) NOT NULL DEFAULT 'en';
ALTER TABLE m_user ADD COLUMN IF NOT EXISTS preferred_language varchar(10) NOT NULL DEFAULT 'en';

CREATE TABLE IF NOT EXISTS m_module(
 module_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,module_code varchar(80) UNIQUE NOT NULL,module_name varchar(150) NOT NULL,
 parent_module_code varchar(80),display_order int NOT NULL DEFAULT 0,is_active boolean NOT NULL DEFAULT true);
CREATE TABLE IF NOT EXISTS m_system_setting(
 setting_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,society_id bigint REFERENCES m_society(society_id),
 setting_group varchar(80) NOT NULL,setting_key varchar(120) NOT NULL,setting_value text,
 data_type varchar(30) NOT NULL DEFAULT 'text',is_secret boolean NOT NULL DEFAULT false,is_active boolean NOT NULL DEFAULT true,
 UNIQUE(society_id,setting_group,setting_key));
CREATE TABLE IF NOT EXISTS m_charge_tax_rule(
 tax_rule_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,society_id bigint NOT NULL REFERENCES m_society(society_id),
 tax_name varchar(100) NOT NULL,tax_rate numeric(8,4) NOT NULL DEFAULT 0,effective_from date NOT NULL,effective_to date,is_active boolean NOT NULL DEFAULT true);
CREATE TABLE IF NOT EXISTS m_rebate_rule(
 rebate_rule_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,society_id bigint NOT NULL REFERENCES m_society(society_id),
 rule_name varchar(120) NOT NULL,calculation_type varchar(30) NOT NULL,rate numeric(18,4) NOT NULL DEFAULT 0,
 max_amount numeric(18,2),days_before_due int NOT NULL DEFAULT 0,effective_from date NOT NULL,effective_to date,is_active boolean NOT NULL DEFAULT true);
CREATE TABLE IF NOT EXISTS m_waiver_rule(
 waiver_rule_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,society_id bigint NOT NULL REFERENCES m_society(society_id),
 rule_name varchar(120) NOT NULL,approval_required boolean NOT NULL DEFAULT true,max_amount numeric(18,2),is_active boolean NOT NULL DEFAULT true);
CREATE TABLE IF NOT EXISTS m_payment_mode(
 payment_mode_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,society_id bigint NOT NULL REFERENCES m_society(society_id),
 mode_code varchar(30) NOT NULL,mode_name varchar(80) NOT NULL,is_active boolean NOT NULL DEFAULT true,UNIQUE(society_id,mode_code));
CREATE TABLE IF NOT EXISTS t_payment_allocation(
 allocation_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,society_id bigint NOT NULL REFERENCES m_society(society_id),
 payment_id bigint NOT NULL REFERENCES t_payment(payment_id) ON DELETE CASCADE,bill_id bigint NOT NULL REFERENCES t_bill(bill_id),
 allocated_amount numeric(18,2) NOT NULL CHECK(allocated_amount>0),UNIQUE(payment_id,bill_id));
CREATE TABLE IF NOT EXISTS t_notice(
 notice_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,society_id bigint NOT NULL REFERENCES m_society(society_id),
 notice_no varchar(60) NOT NULL,title varchar(200) NOT NULL,content text NOT NULL,publish_from timestamptz,publish_to timestamptz,
 status varchar(30) NOT NULL DEFAULT 'Draft',created_by bigint REFERENCES m_user(user_id),created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(society_id,notice_no));
CREATE TABLE IF NOT EXISTS t_notification(
 notification_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,society_id bigint NOT NULL REFERENCES m_society(society_id),
 user_id bigint REFERENCES m_user(user_id),customer_id bigint REFERENCES m_customer(customer_id),
 channel varchar(20) NOT NULL,message text NOT NULL,status varchar(30) NOT NULL DEFAULT 'Pending',sent_at timestamptz,created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS t_document(
 document_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,society_id bigint NOT NULL REFERENCES m_society(society_id),
 flat_id bigint REFERENCES m_flat(flat_id),customer_id bigint REFERENCES m_customer(customer_id),
 document_type varchar(80) NOT NULL,file_name varchar(255) NOT NULL,storage_path text NOT NULL,uploaded_by bigint REFERENCES m_user(user_id),
 created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS t_parking_assignment(
 assignment_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,society_id bigint NOT NULL REFERENCES m_society(society_id),
 parking_slot_id bigint NOT NULL REFERENCES m_parking_slot(parking_slot_id),flat_id bigint REFERENCES m_flat(flat_id),
 customer_id bigint REFERENCES m_customer(customer_id),start_date date NOT NULL,end_date date,is_active boolean NOT NULL DEFAULT true);
CREATE TABLE IF NOT EXISTS t_bill_status_history(
 history_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,society_id bigint NOT NULL REFERENCES m_society(society_id),
 bill_id bigint NOT NULL REFERENCES t_bill(bill_id) ON DELETE CASCADE,old_status varchar(30),new_status varchar(30) NOT NULL,
 changed_by bigint REFERENCES m_user(user_id),changed_at timestamptz NOT NULL DEFAULT now(),remarks text);
CREATE TABLE IF NOT EXISTS t_collection_reversal(
 reversal_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,society_id bigint NOT NULL REFERENCES m_society(society_id),
 payment_id bigint NOT NULL REFERENCES t_payment(payment_id),amount numeric(18,2) NOT NULL,reason text NOT NULL,
 reversed_by bigint REFERENCES m_user(user_id),reversed_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS t_migration_row(
 migration_row_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,migration_batch_id bigint NOT NULL REFERENCES t_migration_batch(migration_batch_id) ON DELETE CASCADE,
 row_number int NOT NULL,external_key varchar(150),status varchar(30) NOT NULL DEFAULT 'Pending',raw_data jsonb NOT NULL DEFAULT '{}'::jsonb,
 target_id bigint,error_message text);
CREATE INDEX IF NOT EXISTS ix_m_system_setting_society ON m_system_setting(society_id);
CREATE INDEX IF NOT EXISTS ix_t_payment_allocation_bill ON t_payment_allocation(society_id,bill_id);
CREATE INDEX IF NOT EXISTS ix_t_notice_society_status ON t_notice(society_id,status);
CREATE INDEX IF NOT EXISTS ix_t_notification_society_status ON t_notification(society_id,status);
CREATE INDEX IF NOT EXISTS ix_t_bill_status_history_bill ON t_bill_status_history(society_id,bill_id,changed_at);
CREATE INDEX IF NOT EXISTS ix_t_document_society ON t_document(society_id);

INSERT INTO m_module(module_code,module_name,parent_module_code,display_order) VALUES
('DASHBOARD','Dashboard',null,10),('SOCIETY','Society Management',null,20),('USERS','Users',null,30),('ROLES','Roles & Rights',null,40),('CONFIGURATION','Configuration',null,50),('FLATS','Buildings / Wings / Flats',null,60),('RESIDENTS','Residents',null,70),
('BILLING','Billing',null,80),('COLLECTION','Collection & Receipts',null,90),('PARKING','Parking & Vehicles',null,100),
('COMPLAINTS','Complaints',null,110),('VISITORS','Visitors & Security',null,120),('DOCUMENTS','Documents',null,130),
('NOTICES','Notices & Communication',null,140),('REPORTS','Reports',null,150),('MIGRATION','Migration',null,160),('AUDIT','Audit',null,170)
ON CONFLICT(module_code) DO NOTHING;

CREATE OR REPLACE FUNCTION fn_set_society_context(p_society_id bigint) RETURNS void
LANGUAGE plpgsql AS $$ BEGIN PERFORM set_config('society_manager.current_society_id',p_society_id::text,true); END; $$;

CREATE OR REPLACE FUNCTION fn_generate_bill(p_society_id bigint,p_bill_month date,p_user_id bigint)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_count bigint;
BEGIN
 WITH eligible AS (
   SELECT f.flat_id FROM m_flat f WHERE f.society_id=p_society_id AND f.is_active
 ), created AS (
   INSERT INTO t_bill(society_id,flat_id,bill_no,bill_month,bill_date,due_date,subtotal,total_amount,status)
   SELECT p_society_id,e.flat_id,
          'BILL-'||to_char(p_bill_month,'YYYYMM')||'-'||lpad(row_number() over(order by e.flat_id)::text,4,'0'),
          date_trunc('month',p_bill_month)::date,current_date,
          (date_trunc('month',p_bill_month)::date + interval '14 days')::date,1500,1500,'Generated'
   FROM eligible e
   WHERE NOT EXISTS(SELECT 1 FROM t_bill b WHERE b.society_id=p_society_id AND b.flat_id=e.flat_id AND b.bill_month=date_trunc('month',p_bill_month)::date)
   RETURNING bill_id
 ) SELECT count(*) INTO v_count FROM created;
 RETURN v_count;
END; $$;

CREATE OR REPLACE FUNCTION fn_bill_balance(p_bill_id bigint) RETURNS numeric LANGUAGE sql AS $$
SELECT total_amount-paid_amount FROM t_bill WHERE bill_id=p_bill_id;
$$;

CREATE OR REPLACE FUNCTION fn_record_payment(p_society_id bigint,p_flat_id bigint,p_amount numeric,p_mode varchar,p_user_id bigint)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_payment_id bigint; v_no varchar; v_remaining numeric:=p_amount; r record;BEGIN
 SELECT 'PAY-'||to_char(current_date,'YYYYMMDD')||'-'||lpad((count(*)+1)::text,5,'0') INTO v_no FROM t_payment WHERE society_id=p_society_id AND payment_date::date=current_date;
 INSERT INTO t_payment(society_id,flat_id,payment_no,amount,payment_mode,remarks) VALUES(p_society_id,p_flat_id,v_no,p_amount,p_mode,'Demo payment') RETURNING payment_id INTO v_payment_id;
 FOR r IN SELECT bill_id,total_amount-paid_amount balance FROM t_bill WHERE society_id=p_society_id AND flat_id=p_flat_id AND total_amount>paid_amount ORDER BY bill_month,bill_id
 LOOP
   EXIT WHEN v_remaining<=0;
   INSERT INTO t_payment_allocation(society_id,payment_id,bill_id,allocated_amount)
   VALUES(p_society_id,v_payment_id,r.bill_id,least(v_remaining,r.balance));
   UPDATE t_bill SET paid_amount=paid_amount+least(v_remaining,r.balance),
     status=CASE WHEN paid_amount+least(v_remaining,r.balance)>=total_amount THEN 'Paid' ELSE 'Partially Paid' END
   WHERE bill_id=r.bill_id;
   v_remaining:=v_remaining-least(v_remaining,r.balance);
 END LOOP;
 INSERT INTO t_receipt(society_id,payment_id,receipt_no,amount) VALUES(p_society_id,v_payment_id,'RCT-'||v_no,p_amount);
 RETURN v_payment_id;
END; $$;

INSERT INTO m_society(society_code,society_name,email,phone,address,default_language)
VALUES
('LAKEVIEW','Lakeview Residency','admin@lakeview.demo','9876500001','Demo Road, Nagpur','en'),
('GREENPARK','Green Park Heights','admin@greenpark.demo','9876500002','Central Avenue, Pune','mr')
ON CONFLICT(society_code) DO NOTHING;

INSERT INTO m_society_branding(society_id,short_name)
SELECT society_id,society_code FROM m_society WHERE society_code IN ('LAKEVIEW','GREENPARK')
ON CONFLICT(society_id) DO NOTHING;

INSERT INTO m_building(society_id,building_code,building_name,floor_count)
SELECT s.society_id,x.code,x.name,x.floors FROM m_society s CROSS JOIN (VALUES('A','Tower A',8),('B','Tower B',8)) x(code,name,floors)
WHERE s.society_code='LAKEVIEW' ON CONFLICT(society_id,building_code) DO NOTHING;
INSERT INTO m_building(society_id,building_code,building_name,floor_count)
SELECT s.society_id,x.code,x.name,x.floors FROM m_society s CROSS JOIN (VALUES('A','Block A',6),('B','Block B',6)) x(code,name,floors)
WHERE s.society_code='GREENPARK' ON CONFLICT(society_id,building_code) DO NOTHING;

INSERT INTO m_wing(society_id,building_id,wing_code,wing_name)SELECT b.society_id,b.building_id,b.building_code||'-W','Wing '||b.building_code FROM m_building b
ON CONFLICT(society_id,wing_code) DO NOTHING;

INSERT INTO m_flat(society_id,building_id,wing_id,flat_no,floor_no,unit_type,area_sqft,occupancy_status)
SELECT b.society_id,b.building_id,w.wing_id,b.building_code||'-'||lpad(f::text,2,'0'),f/10,'2BHK',1050+(f*10),'Occupied'
FROM m_building b JOIN m_wing w ON w.building_id=b.building_id
CROSS JOIN generate_series(1,10) f
ON CONFLICT(society_id,flat_no) DO NOTHING;

INSERT INTO m_customer(society_id,customer_code,full_name,customer_type,phone,email)
SELECT s.society_id,'C'||lpad(row_number() over(partition by s.society_id order by f.flat_id)::text,4,'0'),
       CASE WHEN s.society_code='LAKEVIEW' THEN 'Rahul Sharma ' ELSE 'Amit Patil ' END||row_number() over(partition by s.society_id order by f.flat_id),
       'Owner','98'||lpad((row_number() over(partition by s.society_id order by f.flat_id)+650000)::text,8,'0'),'owner'||f.flat_id||'@demo.local'
FROM m_society s JOIN m_flat f ON f.society_id=s.society_id
WHERE f.is_active
ON CONFLICT(society_id,customer_code) DO NOTHING;

WITH ranked_flats AS (
 SELECT f.*,row_number() over(partition by f.society_id order by f.flat_id) rn FROM m_flat f
), ranked_customers AS (
 SELECT c.*,row_number() over(partition by c.society_id order by c.customer_id) rn FROM m_customer c
)
INSERT INTO m_customer_flat(society_id,customer_id,flat_id,relation_type,is_primary,start_date)
SELECT f.society_id,c.customer_id,f.flat_id,'Owner',true,current_date-interval '2 years'
FROM ranked_flats f JOIN ranked_customers c ON c.society_id=f.society_id AND c.rn=f.rn
ON CONFLICT(customer_id,flat_id,relation_type) DO NOTHING;

INSERT INTO m_charge_type(society_id,charge_code,charge_name,calculation_method,recurring,taxable,mandatory)
SELECT society_id,x.code,x.name,x.method,true,false,true FROM m_society CROSS JOIN
(VALUES('MAINT','Monthly Maintenance','Fixed'),('SINK','Sinking Fund','Fixed'),('WATER','Water Charges','Fixed'),('PARK','Parking','Fixed'),('REPAIR','Repair Fund','Fixed')) x(code,name,method)
ON CONFLICT(society_id,charge_code) DO NOTHING;
INSERT INTO m_rate_plan(society_id,plan_name,effective_from) SELECT society_id,'Standard 2026','2026-04-01' FROM m_society ON CONFLICT DO NOTHING;
INSERT INTO m_charge_rule(society_id,rate_plan_id,charge_type_id,calculation_method,rate,effective_from)
SELECT c.society_id,r.rate_plan_id,c.charge_type_id,'Fixed',       CASE c.charge_code WHEN 'MAINT' THEN 1500 WHEN 'SINK' THEN 300 WHEN 'WATER' THEN 250 WHEN 'PARK' THEN 500 ELSE 150 END,
       '2026-04-01'
FROM m_charge_type c JOIN m_rate_plan r ON r.society_id=c.society_id AND r.plan_name='Standard 2026'
ON CONFLICT DO NOTHING;
INSERT INTO m_interest_rule(society_id,rule_name,calculation_type,rate,frequency,simple_or_compound,grace_days,effective_from)
SELECT society_id,'Standard DPC','Percentage',2,'Monthly','Simple',10,'2026-04-01' FROM m_society
WHERE NOT EXISTS(SELECT 1 FROM m_interest_rule i WHERE i.society_id=m_society.society_id AND i.rule_name='Standard DPC');
INSERT INTO m_rebate_rule(society_id,rule_name,calculation_type,rate,days_before_due,effective_from)
SELECT society_id,'Early Payment Rebate','Percentage',2,5,'2026-04-01' FROM m_society
WHERE NOT EXISTS(SELECT 1 FROM m_rebate_rule r WHERE r.society_id=m_society.society_id AND r.rule_name='Early Payment Rebate');
INSERT INTO m_payment_mode(society_id,mode_code,mode_name)
SELECT society_id,x.code,x.name FROM m_society CROSS JOIN (VALUES('CASH','Cash'),('UPI','UPI'),('BANK','Bank Transfer'),('CHEQUE','Cheque')) x(code,name)
ON CONFLICT DO NOTHING;
INSERT INTO m_parking_slot(society_id,slot_no,slot_type,charge)
SELECT s.society_id,s.society_code||'-P'||g,'Car',500 FROM m_society s CROSS JOIN generate_series(1,10) g
ON CONFLICT(society_id,slot_no) DO NOTHING;

INSERT INTO t_bill(society_id,flat_id,bill_no,bill_month,bill_date,due_date,subtotal,total_amount,status)
SELECT f.society_id,f.flat_id,'DEMO-'||s.society_code||'-'||to_char(date_trunc('month',current_date-interval '1 month'),'YYYYMM')||'-'||f.flat_no,
date_trunc('month',current_date-interval '1 month')::date,current_date-interval '1 month',
date_trunc('month',current_date-interval '1 month')::date+interval '14 days',2200,2200,'Posted'
FROM m_flat f JOIN m_society s ON s.society_id=f.society_id
WHERE NOT EXISTS(SELECT 1 FROM t_bill b WHERE b.society_id=f.society_id AND b.flat_id=f.flat_id AND b.bill_month=date_trunc('month',current_date-interval '1 month')::date);

INSERT INTO t_bill_line_item(society_id,bill_id,description,quantity,rate,amount)
SELECT b.society_id,b.bill_id,'Monthly Maintenance',1,1500,1500 FROM t_bill b
WHERE b.bill_no LIKE 'DEMO-%' AND NOT EXISTS(SELECT 1 FROM t_bill_line_item l WHERE l.bill_id=b.bill_id);
INSERT INTO t_bill_line_item(society_id,bill_id,description,quantity,rate,amount)
SELECT b.society_id,b.bill_id,'Sinking Fund',1,300,300 FROM t_bill b WHERE b.bill_no LIKE 'DEMO-%';
INSERT INTO t_bill_line_item(society_id,bill_id,description,quantity,rate,amount)
SELECT b.society_id,b.bill_id,'Water Charges',1,250,250 FROM t_bill b WHERE b.bill_no LIKE 'DEMO-%';
INSERT INTO t_bill_line_item(society_id,bill_id,description,quantity,rate,amount)
SELECT b.society_id,b.bill_id,'Repair Fund',1,150,150 FROM t_bill b WHERE b.bill_no LIKE 'DEMO-%';

WITH ranked AS (
 SELECT f.flat_id,f.society_id,row_number() over(partition by f.society_id order by f.flat_id) rn
 FROM m_flat f
), ranked_customers AS (
 SELECT c.customer_id,c.society_id,row_number() over(partition by c.society_id order by c.customer_id) rn
 FROM m_customer c
)
INSERT INTO t_payment(society_id,customer_id,flat_id,payment_no,payment_date,amount,payment_mode,reference_no,remarks)
SELECT r.society_id,c.customer_id,r.flat_id,'DEMO-PAY-'||r.flat_id,current_date-(r.rn::int),
       CASE WHEN r.rn%3=0 THEN 1000 ELSE 2200 END,'UPI','DEMO'||r.flat_id,'Demo collection'
FROM ranked r JOIN ranked_customers c ON c.society_id=r.society_id AND c.rn=r.rn
WHERE r.rn<=10
AND NOT EXISTS(SELECT 1 FROM t_payment p WHERE p.payment_no='DEMO-PAY-'||r.flat_id);

INSERT INTO t_receipt(society_id,payment_id,receipt_no,amount)
SELECT p.society_id,p.payment_id,'DEMO-RCT-'||p.payment_id,p.amount FROM t_payment p
WHERE p.payment_no LIKE 'DEMO-PAY-%' AND NOT EXISTS(SELECT 1 FROM t_receipt r WHERE r.payment_id=p.payment_id);

INSERT INTO t_complaint(society_id,flat_id,customer_id,complaint_no,category,title,description,priority,status)
SELECT f.society_id,f.flat_id,c.customer_id,'CMP-DEMO-'||f.flat_id,'Maintenance','Water leakage','Demo complaint for testing workflow','High',
CASE WHEN f.flat_id%2=0 THEN 'In Progress' ELSE 'Open' END
FROM m_flat f JOIN m_customer c ON c.society_id=f.society_id LIMIT 10;

INSERT INTO t_visitor_entry(society_id,flat_id,visitor_name,phone,visitor_type,purpose,status)
SELECT f.society_id,f.flat_id,'Demo Visitor '||f.flat_no,'900000'||right('0000'||f.flat_id::text,4),'Guest','Personal visit',
CASE WHEN f.flat_id%2=0 THEN 'Exited' ELSE 'Inside' END FROM m_flat f LIMIT 10;

INSERT INTO t_notice(society_id,notice_no,title,content,publish_from,status,created_by)
SELECT society_id,'NOTICE-DEMO-01','Monthly Maintenance Notice','This is a demo notice for Society360 testing.',now(),'Published',
(SELECT user_id FROM m_user WHERE login_name='Rahul' LIMIT 1) FROM m_society
WHERE NOT EXISTS(SELECT 1 FROM t_notice n WHERE n.society_id=m_society.society_id AND n.notice_no='NOTICE-DEMO-01');

CREATE OR REPLACE FUNCTION fn_society_data_counts(p_society_id bigint)
RETURNS TABLE(table_name text,row_count bigint) LANGUAGE plpgsql AS $$
BEGIN
 RETURN QUERY
 SELECT 'm_flat',count(*) FROM m_flat WHERE society_id=p_society_id
 UNION ALL SELECT 'm_customer',count(*) FROM m_customer WHERE society_id=p_society_id
 UNION ALL SELECT 't_bill',count(*) FROM t_bill WHERE society_id=p_society_id
 UNION ALL SELECT 't_payment',count(*) FROM t_payment WHERE society_id=p_society_id
 UNION ALL SELECT 't_complaint',count(*) FROM t_complaint WHERE society_id=p_society_id
 UNION ALL SELECT 't_visitor_entry',count(*) FROM t_visitor_entry WHERE society_id=p_society_id;
END; $$;