CREATE SCHEMA IF NOT EXISTS society_manager;
SET search_path TO society_manager, public;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS m_society(
 society_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,society_code varchar(40) UNIQUE NOT NULL,
 society_name varchar(180) NOT NULL,email varchar(180),phone varchar(30),address text,
 timezone varchar(60) NOT NULL DEFAULT 'Asia/Kolkata',currency_code char(3) NOT NULL DEFAULT 'INR',
 is_active boolean NOT NULL DEFAULT true,created_at timestamptz NOT NULL DEFAULT now(),updated_at timestamptz NOT NULL DEFAULT now());

CREATE TABLE IF NOT EXISTS m_society_branding(
 branding_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,society_id bigint UNIQUE NOT NULL REFERENCES m_society(society_id),
 logo_url text,logo_mode varchar(20) NOT NULL DEFAULT 'generated',short_name varchar(30),
 primary_color varchar(20) NOT NULL DEFAULT '#7057E8',secondary_color varchar(20) NOT NULL DEFAULT '#172554',
 accent_color varchar(20) NOT NULL DEFAULT '#2DD4BF',icon_style varchar(30) NOT NULL DEFAULT 'monogram');

CREATE TABLE IF NOT EXISTS m_user(
 user_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,society_id bigint REFERENCES m_society(society_id),
 login_name varchar(100) UNIQUE NOT NULL,display_name varchar(150) NOT NULL,email varchar(180),phone varchar(30),
 password_hash text,role_code varchar(40) NOT NULL,is_active boolean NOT NULL DEFAULT true,
 last_login_at timestamptz,created_at timestamptz NOT NULL DEFAULT now());

CREATE TABLE IF NOT EXISTS m_building(
 building_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,society_id bigint NOT NULL REFERENCES m_society(society_id),
 building_code varchar(30) NOT NULL,building_name varchar(100) NOT NULL,floor_count int NOT NULL DEFAULT 1,
 is_active boolean NOT NULL DEFAULT true,UNIQUE(society_id,building_code));

CREATE TABLE IF NOT EXISTS m_wing(
 wing_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,society_id bigint NOT NULL REFERENCES m_society(society_id),
 building_id bigint REFERENCES m_building(building_id),wing_code varchar(30) NOT NULL,wing_name varchar(100) NOT NULL,
 is_active boolean NOT NULL DEFAULT true,UNIQUE(society_id,wing_code));

CREATE TABLE IF NOT EXISTS m_flat(
 flat_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,society_id bigint NOT NULL REFERENCES m_society(society_id),
 building_id bigint REFERENCES m_building(building_id),wing_id bigint REFERENCES m_wing(wing_id),
 flat_no varchar(30) NOT NULL,floor_no int,unit_type varchar(50),area_sqft numeric(12,2),
 occupancy_status varchar(30) NOT NULL DEFAULT 'Vacant',is_active boolean NOT NULL DEFAULT true,UNIQUE(society_id,flat_no));

CREATE TABLE IF NOT EXISTS m_customer(
 customer_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,society_id bigint NOT NULL REFERENCES m_society(society_id),
 customer_code varchar(50),full_name varchar(180) NOT NULL,customer_type varchar(30) NOT NULL DEFAULT 'Owner',
 phone varchar(30),email varchar(180),is_active boolean NOT NULL DEFAULT true,
 created_at timestamptz NOT NULL DEFAULT now(),UNIQUE(society_id,customer_code));

CREATE TABLE IF NOT EXISTS m_customer_flat(
 customer_flat_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,society_id bigint NOT NULL REFERENCES m_society(society_id),
 customer_id bigint NOT NULL REFERENCES m_customer(customer_id),flat_id bigint NOT NULL REFERENCES m_flat(flat_id),
 relation_type varchar(30) NOT NULL DEFAULT 'Owner',is_primary boolean NOT NULL DEFAULT false,
 start_date date,end_date date,UNIQUE(customer_id,flat_id,relation_type));

CREATE TABLE IF NOT EXISTS m_charge_type(
 charge_type_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,society_id bigint NOT NULL REFERENCES m_society(society_id),
 charge_code varchar(50) NOT NULL,charge_name varchar(120) NOT NULL,calculation_method varchar(40) NOT NULL,
 recurring boolean NOT NULL DEFAULT true,taxable boolean NOT NULL DEFAULT false,mandatory boolean NOT NULL DEFAULT true,
 is_active boolean NOT NULL DEFAULT true,UNIQUE(society_id,charge_code));

CREATE TABLE IF NOT EXISTS m_rate_plan(
 rate_plan_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,society_id bigint NOT NULL REFERENCES m_society(society_id),
 plan_name varchar(120) NOT NULL,effective_from date NOT NULL,effective_to date,is_active boolean NOT NULL DEFAULT true,
 UNIQUE(society_id,plan_name,effective_from));

CREATE TABLE IF NOT EXISTS m_charge_rule(
 charge_rule_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,society_id bigint NOT NULL REFERENCES m_society(society_id),
 rate_plan_id bigint NOT NULL REFERENCES m_rate_plan(rate_plan_id),charge_type_id bigint NOT NULL REFERENCES m_charge_type(charge_type_id),
 scope_type varchar(40) NOT NULL DEFAULT 'Society',scope_value varchar(100),calculation_method varchar(40) NOT NULL,
 rate numeric(18,4) NOT NULL DEFAULT 0,minimum_amount numeric(18,2),maximum_amount numeric(18,2),
 effective_from date NOT NULL,effective_to date,metadata jsonb NOT NULL DEFAULT '{}'::jsonb);

CREATE TABLE IF NOT EXISTS m_interest_rule(
 interest_rule_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,society_id bigint NOT NULL REFERENCES m_society(society_id),
 rule_name varchar(120) NOT NULL,calculation_type varchar(30) NOT NULL,rate numeric(18,6) NOT NULL DEFAULT 0,
 frequency varchar(20) NOT NULL DEFAULT 'Monthly',simple_or_compound varchar(20) NOT NULL DEFAULT 'Simple',
 grace_days int NOT NULL DEFAULT 0,cap_amount numeric(18,2),effective_from date NOT NULL,effective_to date,
 is_active boolean NOT NULL DEFAULT true);

CREATE TABLE IF NOT EXISTS m_parking_slot(
 parking_slot_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,society_id bigint NOT NULL REFERENCES m_society(society_id),
 slot_no varchar(40) NOT NULL,slot_type varchar(30) NOT NULL DEFAULT 'Car',charge numeric(18,2) NOT NULL DEFAULT 0,
 is_active boolean NOT NULL DEFAULT true,UNIQUE(society_id,slot_no));

CREATE TABLE IF NOT EXISTS m_vehicle(
 vehicle_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,society_id bigint NOT NULL REFERENCES m_society(society_id),
 customer_id bigint REFERENCES m_customer(customer_id),flat_id bigint REFERENCES m_flat(flat_id),
 registration_no varchar(30) NOT NULL,vehicle_type varchar(30) NOT NULL,parking_slot_id bigint REFERENCES m_parking_slot(parking_slot_id),
 is_active boolean NOT NULL DEFAULT true,UNIQUE(society_id,registration_no));

CREATE TABLE IF NOT EXISTS t_bill(
 bill_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,society_id bigint NOT NULL REFERENCES m_society(society_id),
 flat_id bigint NOT NULL REFERENCES m_flat(flat_id),bill_no varchar(60) NOT NULL,bill_month date NOT NULL,
 bill_date date NOT NULL DEFAULT current_date,due_date date NOT NULL,subtotal numeric(18,2) NOT NULL DEFAULT 0,
 tax_amount numeric(18,2) NOT NULL DEFAULT 0,rebate_amount numeric(18,2) NOT NULL DEFAULT 0,dpc_amount numeric(18,2) NOT NULL DEFAULT 0,
 total_amount numeric(18,2) NOT NULL DEFAULT 0,paid_amount numeric(18,2) NOT NULL DEFAULT 0,status varchar(30) NOT NULL DEFAULT 'Pending',
 created_at timestamptz NOT NULL DEFAULT now(),UNIQUE(society_id,bill_no));

CREATE TABLE IF NOT EXISTS t_bill_line_item(
 bill_line_item_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,society_id bigint NOT NULL REFERENCES m_society(society_id),
 bill_id bigint NOT NULL REFERENCES t_bill(bill_id) ON DELETE CASCADE,charge_type_id bigint REFERENCES m_charge_type(charge_type_id),
 description varchar(200) NOT NULL,quantity numeric(18,4) NOT NULL DEFAULT 1,rate numeric(18,4) NOT NULL DEFAULT 0,
 amount numeric(18,2) NOT NULL DEFAULT 0,historical_rule jsonb NOT NULL DEFAULT '{}'::jsonb);

CREATE TABLE IF NOT EXISTS t_payment(
 payment_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,society_id bigint NOT NULL REFERENCES m_society(society_id),
 customer_id bigint REFERENCES m_customer(customer_id),flat_id bigint REFERENCES m_flat(flat_id),
 payment_no varchar(60) NOT NULL,payment_date timestamptz NOT NULL DEFAULT now(),amount numeric(18,2) NOT NULL,
 payment_mode varchar(30) NOT NULL,reference_no varchar(120),status varchar(30) NOT NULL DEFAULT 'Success',
 remarks text,UNIQUE(society_id,payment_no));

CREATE TABLE IF NOT EXISTS t_receipt(
 receipt_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,society_id bigint NOT NULL REFERENCES m_society(society_id),
 payment_id bigint NOT NULL REFERENCES t_payment(payment_id),receipt_no varchar(60) NOT NULL,
 receipt_date timestamptz NOT NULL DEFAULT now(),amount numeric(18,2) NOT NULL,UNIQUE(society_id,receipt_no));

CREATE TABLE IF NOT EXISTS t_adjustment(
 adjustment_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,society_id bigint NOT NULL REFERENCES m_society(society_id),
 flat_id bigint REFERENCES m_flat(flat_id),bill_id bigint REFERENCES t_bill(bill_id),adjustment_type varchar(30) NOT NULL,
 amount numeric(18,2) NOT NULL,reason text,approved_by bigint REFERENCES m_user(user_id),created_at timestamptz NOT NULL DEFAULT now());

CREATE TABLE IF NOT EXISTS t_complaint(
 complaint_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,society_id bigint NOT NULL REFERENCES m_society(society_id),
 flat_id bigint REFERENCES m_flat(flat_id),customer_id bigint REFERENCES m_customer(customer_id),
 complaint_no varchar(60) NOT NULL,category varchar(80) NOT NULL,title varchar(180) NOT NULL,description text,
 priority varchar(20) NOT NULL DEFAULT 'Normal',status varchar(30) NOT NULL DEFAULT 'Open',
 assigned_to bigint REFERENCES m_user(user_id),created_at timestamptz NOT NULL DEFAULT now(),resolved_at timestamptz,
 UNIQUE(society_id,complaint_no));

CREATE TABLE IF NOT EXISTS t_visitor_entry(
 visitor_entry_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,society_id bigint NOT NULL REFERENCES m_society(society_id),
 flat_id bigint REFERENCES m_flat(flat_id),visitor_name varchar(150) NOT NULL,phone varchar(30),visitor_type varchar(40),
 vehicle_no varchar(30),purpose varchar(150),entry_at timestamptz NOT NULL DEFAULT now(),exit_at timestamptz,status varchar(30) NOT NULL DEFAULT 'Inside');

CREATE TABLE IF NOT EXISTS t_migration_batch(
 migration_batch_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,society_id bigint NOT NULL REFERENCES m_society(society_id),
 batch_no varchar(60) NOT NULL,source_file_name varchar(255),status varchar(30) NOT NULL DEFAULT 'Uploaded',
 total_rows int NOT NULL DEFAULT 0,valid_rows int NOT NULL DEFAULT 0,error_rows int NOT NULL DEFAULT 0,
 created_by bigint REFERENCES m_user(user_id),created_at timestamptz NOT NULL DEFAULT now(),UNIQUE(society_id,batch_no));

CREATE TABLE IF NOT EXISTS t_migration_error(
 migration_error_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,migration_batch_id bigint NOT NULL REFERENCES t_migration_batch(migration_batch_id) ON DELETE CASCADE,
 row_number int NOT NULL,field_name varchar(100),error_message text NOT NULL,raw_data jsonb NOT NULL DEFAULT '{}'::jsonb);

CREATE TABLE IF NOT EXISTS t_audit_log(
 audit_log_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,society_id bigint REFERENCES m_society(society_id),
 user_id bigint REFERENCES m_user(user_id),entity_name varchar(100) NOT NULL,entity_id bigint,action varchar(30) NOT NULL,
 old_data jsonb,new_data jsonb,created_at timestamptz NOT NULL DEFAULT now());

CREATE INDEX IF NOT EXISTS ix_m_flat_society ON m_flat(society_id);
CREATE INDEX IF NOT EXISTS ix_m_customer_society ON m_customer(society_id);
CREATE INDEX IF NOT EXISTS ix_m_charge_rule_effective ON m_charge_rule(society_id,effective_from,effective_to);
CREATE INDEX IF NOT EXISTS ix_m_interest_rule_effective ON m_interest_rule(society_id,effective_from,effective_to);
CREATE INDEX IF NOT EXISTS ix_t_bill_society_month ON t_bill(society_id,bill_month);
CREATE INDEX IF NOT EXISTS ix_t_bill_flat_status ON t_bill(society_id,flat_id,status);
CREATE INDEX IF NOT EXISTS ix_t_payment_society_date ON t_payment(society_id,payment_date);
CREATE INDEX IF NOT EXISTS ix_t_complaint_status ON t_complaint(society_id,status);

CREATE OR REPLACE FUNCTION fn_dashboard_summary(p_society_id bigint,p_month date)
RETURNS TABLE(billed numeric,collected numeric,outstanding numeric,occupied_flats bigint,total_flats bigint,open_complaints bigint)
LANGUAGE sql AS $$
SELECT
COALESCE((SELECT sum(total_amount) FROM t_bill WHERE society_id=p_society_id AND bill_month=date_trunc('month',p_month)::date),0),
COALESCE((SELECT sum(amount) FROM t_payment WHERE society_id=p_society_id AND payment_date>=date_trunc('month',p_month) AND payment_date<date_trunc('month',p_month)+interval '1 month' AND status='Success'),0),
COALESCE((SELECT sum(total_amount-paid_amount) FROM t_bill WHERE society_id=p_society_id AND bill_month=date_trunc('month',p_month)::date AND total_amount>paid_amount),0),
COALESCE((SELECT count(*) FROM m_flat WHERE society_id=p_society_id AND occupancy_status='Occupied' AND is_active),0),
COALESCE((SELECT count(*) FROM m_flat WHERE society_id=p_society_id AND is_active),0),
COALESCE((SELECT count(*) FROM t_complaint WHERE society_id=p_society_id AND status NOT IN ('Resolved','Closed')),0);
$$;