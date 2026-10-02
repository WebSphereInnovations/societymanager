SET search_path TO society_manager, public;

CREATE TABLE IF NOT EXISTS t_user_login_audit(
 user_id bigint PRIMARY KEY REFERENCES m_user(user_id) ON DELETE CASCADE,
 last_login_ip inet,last_login_at timestamptz,login_count bigint NOT NULL DEFAULT 0,
 last_user_agent varchar(500),last_login_status varchar(20) NOT NULL DEFAULT 'Never',
 modified_by bigint REFERENCES m_user(user_id),modified_at timestamptz NOT NULL DEFAULT now(),modify_remark varchar(500) NOT NULL DEFAULT ''
);
CREATE TABLE IF NOT EXISTS t_user_login_history(
 login_history_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,user_id bigint REFERENCES m_user(user_id),
 login_name varchar(100),login_at timestamptz NOT NULL DEFAULT now(),login_ip inet,user_agent varchar(500),
 status varchar(20) NOT NULL,failure_reason varchar(200),trace_id varchar(100),created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS t_service_history(
 service_history_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,society_id bigint REFERENCES m_society(society_id),
 customer_id bigint REFERENCES m_customer(customer_id),flat_id bigint REFERENCES m_flat(flat_id),
 event_type varchar(80) NOT NULL,event_sub_type varchar(80),entity_name varchar(100),entity_id bigint,reference_no varchar(120),
 event_title varchar(200) NOT NULL,event_description text,event_data jsonb NOT NULL DEFAULT '{}'::jsonb,
 performed_by bigint REFERENCES m_user(user_id),performed_at timestamptz NOT NULL DEFAULT now(),
 source_channel varchar(30) NOT NULL DEFAULT 'WEB',modify_remark varchar(500) NOT NULL DEFAULT ''
);
CREATE INDEX IF NOT EXISTS ix_service_history_customer ON t_service_history(customer_id,performed_at DESC);
CREATE INDEX IF NOT EXISTS ix_service_history_flat ON t_service_history(flat_id,performed_at DESC);
DO $$
DECLARE r record;
BEGIN
 FOR r IN SELECT table_name FROM information_schema.tables WHERE table_schema='society_manager' AND table_type='BASE TABLE'
   AND table_name NOT IN ('t_audit_log','t_user_login_history')
 LOOP
  EXECUTE format('ALTER TABLE society_manager.%I ADD COLUMN IF NOT EXISTS modified_by bigint REFERENCES society_manager.m_user(user_id)',r.table_name);
  EXECUTE format('ALTER TABLE society_manager.%I ADD COLUMN IF NOT EXISTS modified_at timestamptz NOT NULL DEFAULT now()',r.table_name);
  EXECUTE format('ALTER TABLE society_manager.%I ADD COLUMN IF NOT EXISTS modify_remark varchar(500) NOT NULL DEFAULT ''''',r.table_name);
 END LOOP;
END $$;

CREATE OR REPLACE FUNCTION fn_standard_modify_audit() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_user bigint; v_remark varchar(500);
BEGIN
 v_user:=NULLIF(current_setting('society_manager.current_user_id',true),'')::bigint;
 v_remark:=COALESCE(current_setting('society_manager.modify_remark',true),'');
 NEW.modified_by:=COALESCE(v_user,NEW.modified_by); NEW.modified_at:=now(); NEW.modify_remark:=v_remark; RETURN NEW;
END $$;

DO $$
DECLARE r record;
BEGIN
 FOR r IN SELECT table_name FROM information_schema.columns WHERE table_schema='society_manager' AND column_name='modified_by'
   AND table_name NOT IN ('t_audit_log','t_user_login_history')
 LOOP
  EXECUTE format('DROP TRIGGER IF EXISTS trg_standard_modify_audit ON society_manager.%I',r.table_name);
  EXECUTE format('CREATE TRIGGER trg_standard_modify_audit BEFORE INSERT OR UPDATE ON society_manager.%I FOR EACH ROW EXECUTE FUNCTION society_manager.fn_standard_modify_audit()',r.table_name);
 END LOOP;
END $$;

CREATE OR REPLACE PROCEDURE sp_set_audit_context(p_user_id bigint,p_remark varchar DEFAULT '')
LANGUAGE plpgsql AS $$ BEGIN
 PERFORM set_config('society_manager.current_user_id',COALESCE(p_user_id::text,''),true);
 PERFORM set_config('society_manager.modify_remark',COALESCE(p_remark,''),true);
END $$;

CREATE OR REPLACE PROCEDURE sp_record_login(
 IN p_user_id bigint,IN p_login_name varchar,IN p_ip inet,IN p_user_agent varchar,
 IN p_status varchar,IN p_failure_reason varchar DEFAULT NULL,IN p_trace_id varchar DEFAULT NULL,INOUT p_login_count bigint DEFAULT 0)
LANGUAGE plpgsql AS $$
BEGIN
 IF p_status='SUCCESS' THEN
  INSERT INTO t_user_login_audit(user_id,last_login_ip,last_login_at,login_count,last_user_agent,last_login_status,modified_by,modified_at)
  VALUES(p_user_id,p_ip,now(),1,p_user_agent,'SUCCESS',p_user_id,now())
  ON CONFLICT(user_id) DO UPDATE SET last_login_ip=EXCLUDED.last_login_ip,last_login_at=EXCLUDED.last_login_at,
   login_count=t_user_login_audit.login_count+1,last_user_agent=EXCLUDED.last_user_agent,last_login_status='SUCCESS',
   modified_by=p_user_id,modified_at=now(),modify_remark='';
  SELECT login_count INTO p_login_count FROM t_user_login_audit WHERE user_id=p_user_id;
  UPDATE m_user SET last_login_at=now(),modified_by=p_user_id,modified_at=now(),modify_remark='' WHERE user_id=p_user_id;
 END IF;
 INSERT INTO t_user_login_history(user_id,login_name,login_ip,user_agent,status,failure_reason,trace_id)
 VALUES(p_user_id,p_login_name,p_ip,p_user_agent,p_status,p_failure_reason,p_trace_id);
END $$;

CREATE OR REPLACE PROCEDURE sp_log_service_history(
 IN p_society_id bigint,IN p_customer_id bigint,IN p_flat_id bigint,IN p_event_type varchar,IN p_event_sub_type varchar,
 IN p_entity_name varchar,IN p_entity_id bigint,IN p_reference_no varchar,IN p_event_title varchar,IN p_event_description text,
 IN p_event_data jsonb,IN p_performed_by bigint,IN p_source_channel varchar DEFAULT 'WEB',IN p_modify_remark varchar DEFAULT '')
LANGUAGE sql AS $$
INSERT INTO t_service_history(society_id,customer_id,flat_id,event_type,event_sub_type,entity_name,entity_id,reference_no,event_title,event_description,event_data,performed_by,source_channel,modify_remark)
VALUES(p_society_id,p_customer_id,p_flat_id,p_event_type,p_event_sub_type,p_entity_name,p_entity_id,p_reference_no,p_event_title,p_event_description,COALESCE(p_event_data,'{}'::jsonb),p_performed_by,COALESCE(p_source_channel,'WEB'),COALESCE(p_modify_remark,''))
$$;

CREATE OR REPLACE PROCEDURE sp_create_society(
 IN p_society_code varchar,IN p_society_name varchar,IN p_admin_name varchar,IN p_login_name varchar,IN p_password varchar,
 IN p_email varchar,IN p_phone varchar,IN p_address text,IN p_plan_code varchar,
 INOUT p_society_id bigint DEFAULT NULL,INOUT p_user_id bigint DEFAULT NULL,INOUT p_subscription_id bigint DEFAULT NULL)
LANGUAGE plpgsql AS $$
DECLARE v_plan_id bigint;v_days int;v_price numeric;
BEGIN
 IF length(trim(COALESCE(p_society_name,'')))<3 THEN RAISE EXCEPTION 'Society name is required'; END IF;
 IF length(trim(COALESCE(p_login_name,'')))<4 THEN RAISE EXCEPTION 'Admin login name is required'; END IF;
 IF length(COALESCE(p_password,''))<10 THEN RAISE EXCEPTION 'Password must contain at least 10 characters'; END IF;
 IF EXISTS(SELECT 1 FROM m_user WHERE lower(login_name)=lower(trim(p_login_name))) THEN RAISE EXCEPTION 'Admin login name already exists'; END IF;
 SELECT subscription_plan_id,duration_days,price INTO v_plan_id,v_days,v_price FROM m_subscription_plan WHERE plan_code=p_plan_code AND is_active;
 IF v_plan_id IS NULL THEN RAISE EXCEPTION 'Subscription plan not found'; END IF;
 INSERT INTO m_society(society_code,society_name,email,phone,address) VALUES(upper(trim(p_society_code)),trim(p_society_name),NULLIF(trim(p_email),''),NULLIF(trim(p_phone),''),NULLIF(trim(p_address),'')) RETURNING society_id INTO p_society_id;
 INSERT INTO m_society_branding(society_id,short_name) VALUES(p_society_id,left(trim(p_society_name),30));
 INSERT INTO m_user(society_id,login_name,display_name,email,phone,password_hash,role_code,is_active)
 VALUES(p_society_id,lower(trim(p_login_name)),trim(p_admin_name),NULLIF(trim(p_email),''),NULLIF(trim(p_phone),''),crypt(p_password,gen_salt('bf',12)),'SOCIETY_ADMIN',true) RETURNING user_id INTO p_user_id;
 INSERT INTO m_user_society(user_id,society_id,is_default) VALUES(p_user_id,p_society_id,true) ON CONFLICT DO NOTHING;
 INSERT INTO m_user_role(user_id,role_id) SELECT p_user_id,role_id FROM m_role WHERE role_code='SOCIETY_ADMIN' ON CONFLICT DO NOTHING;
 INSERT INTO m_society_subscription(society_id,subscription_plan_id,start_date,end_date,amount,payment_status,is_active,modified_by,modified_at)
 VALUES(p_society_id,v_plan_id,current_date,current_date+greatest(v_days,1)-1,v_price,'Pending',true,p_user_id,now()) RETURNING subscription_id INTO p_subscription_id;
END $$;

CREATE OR REPLACE PROCEDURE sp_save_charge_rule(
 IN p_society_id bigint,IN p_charge_code varchar,IN p_plan_name varchar,IN p_method varchar,IN p_rate numeric,
 IN p_effective_from date,IN p_effective_to date,IN p_scope_type varchar,IN p_scope_value varchar,IN p_user_id bigint,
 IN p_remark varchar DEFAULT '',INOUT p_charge_rule_id bigint DEFAULT NULL)
LANGUAGE plpgsql AS $$
DECLARE v_plan bigint;v_type bigint;
BEGIN
 INSERT INTO m_rate_plan(society_id,plan_name,effective_from,effective_to,modified_by,modified_at,modify_remark)
 VALUES(p_society_id,p_plan_name,p_effective_from,p_effective_to,p_user_id,now(),p_remark)
 ON CONFLICT(society_id,plan_name,effective_from) DO UPDATE SET effective_to=EXCLUDED.effective_to,modified_by=p_user_id,modified_at=now(),modify_remark=p_remark
 RETURNING rate_plan_id INTO v_plan;
 SELECT charge_type_id INTO v_type FROM m_charge_type WHERE society_id=p_society_id AND charge_code=p_charge_code AND is_active;
 IF v_type IS NULL THEN RAISE EXCEPTION 'Charge type not found'; END IF;
 INSERT INTO m_charge_rule(society_id,rate_plan_id,charge_type_id,scope_type,scope_value,calculation_method,rate,effective_from,effective_to,modified_by,modified_at,modify_remark)
 VALUES(p_society_id,v_plan,v_type,p_scope_type,p_scope_value,p_method,p_rate,p_effective_from,p_effective_to,p_user_id,now(),p_remark) RETURNING charge_rule_id INTO p_charge_rule_id;
END $$;

CREATE OR REPLACE PROCEDURE sp_save_interest_rule(
 IN p_society_id bigint,IN p_rule_name varchar,IN p_type varchar,IN p_rate numeric,IN p_frequency varchar,IN p_simple_compound varchar,
 IN p_grace_days int,IN p_cap numeric,IN p_effective_from date,IN p_effective_to date,IN p_user_id bigint,IN p_remark varchar DEFAULT '',
 INOUT p_interest_rule_id bigint DEFAULT NULL)
LANGUAGE plpgsql AS $$
BEGIN
 INSERT INTO m_interest_rule(society_id,rule_name,calculation_type,rate,frequency,simple_or_compound,grace_days,cap_amount,effective_from,effective_to,is_active,modified_by,modified_at,modify_remark)
 VALUES(p_society_id,p_rule_name,p_type,p_rate,p_frequency,p_simple_compound,p_grace_days,p_cap,p_effective_from,p_effective_to,true,p_user_id,now(),p_remark)
 RETURNING interest_rule_id INTO p_interest_rule_id;
END $$;

CREATE OR REPLACE PROCEDURE sp_record_payment(
 IN p_society_id bigint,IN p_customer_id bigint,IN p_flat_id bigint,IN p_amount numeric,IN p_mode varchar,IN p_reference varchar,IN p_remarks varchar,
 IN p_user_id bigint,IN p_modify_remark varchar DEFAULT '',INOUT p_payment_id bigint DEFAULT NULL)
LANGUAGE plpgsql AS $$
DECLARE v_no varchar;v_remaining numeric:=p_amount;r record;v_alloc numeric;
BEGIN
 IF p_amount<=0 THEN RAISE EXCEPTION 'Payment amount must be greater than zero'; END IF;
 IF NOT EXISTS(SELECT 1 FROM m_customer_flat WHERE society_id=p_society_id AND customer_id=p_customer_id AND flat_id=p_flat_id AND is_primary) THEN RAISE EXCEPTION 'Customer and flat do not belong together'; END IF;
 SELECT 'PAY-'||to_char(current_date,'YYYYMMDD')||'-'||lpad((count(*)+1)::text,5,'0') INTO v_no FROM t_payment WHERE society_id=p_society_id AND payment_date::date=current_date;
 INSERT INTO t_payment(society_id,customer_id,flat_id,payment_no,amount,payment_mode,reference_no,status,remarks,modified_by,modified_at,modify_remark)
 VALUES(p_society_id,p_customer_id,p_flat_id,v_no,p_amount,p_mode,p_reference,'Success',p_remarks,p_user_id,now(),p_modify_remark) RETURNING payment_id INTO p_payment_id;
 FOR r IN SELECT bill_id,total_amount-paid_amount balance FROM t_bill WHERE society_id=p_society_id AND flat_id=p_flat_id AND total_amount>paid_amount ORDER BY bill_month,bill_id LOOP
  EXIT WHEN v_remaining<=0;v_alloc:=least(v_remaining,r.balance);
  INSERT INTO t_payment_allocation(society_id,payment_id,bill_id,allocated_amount,modified_by,modified_at,modify_remark) VALUES(p_society_id,p_payment_id,r.bill_id,v_alloc,p_user_id,now(),p_modify_remark);
  UPDATE t_bill SET paid_amount=paid_amount+v_alloc,status=CASE WHEN paid_amount+v_alloc>=total_amount THEN 'Paid' ELSE 'Partially Paid' END,modified_by=p_user_id,modified_at=now(),modify_remark=p_modify_remark WHERE bill_id=r.bill_id;
  v_remaining:=v_remaining-v_alloc;
 END LOOP;
 INSERT INTO t_receipt(society_id,payment_id,receipt_no,amount,modified_by,modified_at,modify_remark) VALUES(p_society_id,p_payment_id,'RCT-'||v_no,p_amount,p_user_id,now(),p_modify_remark);
 CALL sp_log_service_history(p_society_id,p_customer_id,p_flat_id,'COLLECTION','PAYMENT','t_payment',p_payment_id,v_no,'Payment received','Collection payment recorded',jsonb_build_object('amount',p_amount,'mode',p_mode),p_user_id,'WEB',p_modify_remark);
END $$;

CREATE OR REPLACE PROCEDURE sp_service_history(IN p_customer_id bigint,IN p_flat_id bigint,INOUT p_cursor refcursor DEFAULT 'service_history_cursor')
LANGUAGE plpgsql AS $$
BEGIN OPEN p_cursor FOR SELECT h.service_history_id,h.event_type,h.event_sub_type,h.event_title,h.event_description,h.reference_no,h.event_data,h.performed_by,u.display_name,h.performed_at
FROM t_service_history h LEFT JOIN m_user u ON u.user_id=h.performed_by WHERE (p_customer_id IS NULL OR h.customer_id=p_customer_id) AND (p_flat_id IS NULL OR h.flat_id=p_flat_id) ORDER BY h.performed_at DESC; END $$;

CREATE OR REPLACE PROCEDURE sp_user_login_audit(IN p_user_id bigint,INOUT p_cursor refcursor DEFAULT 'login_audit_cursor')
LANGUAGE plpgsql AS $$
BEGIN OPEN p_cursor FOR SELECT a.user_id,u.login_name,u.display_name,a.last_login_ip,a.last_login_at,a.login_count,a.last_user_agent,a.last_login_status FROM t_user_login_audit a JOIN m_user u ON u.user_id=a.user_id WHERE a.user_id=p_user_id; END $$;

CREATE OR REPLACE PROCEDURE sp_subscription_plans(INOUT p_cursor refcursor DEFAULT 'subscription_plans_cursor')
LANGUAGE plpgsql AS $$
BEGIN OPEN p_cursor FOR SELECT plan_code,plan_name,duration_days,price,max_flats,max_users,features FROM m_subscription_plan WHERE is_active ORDER BY price; END $$;

CREATE OR REPLACE PROCEDURE sp_create_society_signup(
 IN p_society_name varchar,IN p_email varchar,IN p_phone varchar,IN p_address text,IN p_admin_name varchar,IN p_login_name varchar,IN p_password varchar,IN p_plan_code varchar,
 INOUT p_society_id bigint DEFAULT NULL,INOUT p_user_id bigint DEFAULT NULL,INOUT p_society_code varchar DEFAULT NULL,INOUT p_plan_code_out varchar DEFAULT NULL,
 INOUT p_plan_name varchar DEFAULT NULL,INOUT p_amount numeric DEFAULT NULL,INOUT p_end_date date DEFAULT NULL)
LANGUAGE plpgsql AS $$
BEGIN
 SELECT society_id,user_id,society_code,plan_code,plan_name,amount,end_date
 INTO p_society_id,p_user_id,p_society_code,p_plan_code_out,p_plan_name,p_amount,p_end_date
 FROM fn_create_society_signup(p_society_name,p_email,p_phone,p_address,p_admin_name,p_login_name,p_password,p_plan_code);
END $$;

CREATE OR REPLACE PROCEDURE sp_create_society_admin(
 IN p_society_id bigint,IN p_login_name varchar,IN p_display_name varchar,IN p_password varchar,IN p_email varchar DEFAULT NULL,IN p_phone varchar DEFAULT NULL,
 INOUT p_user_id bigint DEFAULT NULL)
LANGUAGE plpgsql AS $$
DECLARE v_role bigint;
BEGIN
 IF p_society_id IS NULL OR NOT EXISTS(SELECT 1 FROM m_society WHERE society_id=p_society_id AND is_active) THEN RAISE EXCEPTION 'Society not found'; END IF;
 IF length(trim(COALESCE(p_login_name,'')))<4 THEN RAISE EXCEPTION 'Login name must contain at least 4 characters'; END IF;
 IF length(COALESCE(p_password,''))<10 THEN RAISE EXCEPTION 'Password must contain at least 10 characters'; END IF;
 IF EXISTS(SELECT 1 FROM m_user WHERE lower(login_name)=lower(trim(p_login_name))) THEN RAISE EXCEPTION 'Login name already exists'; END IF;
 SELECT role_id INTO v_role FROM m_role WHERE role_code='SOCIETY_ADMIN' AND is_active;
 IF v_role IS NULL THEN RAISE EXCEPTION 'SOCIETY_ADMIN role not found'; END IF;
 INSERT INTO m_user(society_id,login_name,display_name,email,phone,password_hash,role_code,is_active)
 VALUES(p_society_id,lower(trim(p_login_name)),trim(p_display_name),NULLIF(trim(p_email),''),NULLIF(trim(p_phone),''),crypt(p_password,gen_salt('bf',12)),'SOCIETY_ADMIN',true)
 RETURNING user_id INTO p_user_id;
 INSERT INTO m_user_role(user_id,role_id) VALUES(p_user_id,v_role) ON CONFLICT DO NOTHING;
 INSERT INTO m_user_society(user_id,society_id,is_default) VALUES(p_user_id,p_society_id,true) ON CONFLICT DO NOTHING;
END $$;

CREATE OR REPLACE PROCEDURE sp_remove_reading_modules()
LANGUAGE plpgsql AS $$
BEGIN
 DELETE FROM m_module WHERE module_code IN ('READ_ENTRY','READ_UPLOAD','READ_VALIDATE','READ_AUTH','READ_EXCEPTION','ADM_METER_CONFIG','BILL_READING_VALIDATE','BILL_READING_AUTH','READING_MANAGEMENT');
END $$;
CALL sp_remove_reading_modules();

CREATE OR REPLACE PROCEDURE sp_record_login_success(
 IN p_user_id bigint,IN p_society_id bigint,IN p_login varchar,IN p_ip varchar,IN p_user_agent varchar,IN p_session_id uuid)
LANGUAGE plpgsql AS $$
DECLARE v_count bigint:=0;
BEGIN
 CALL sp_record_login(p_user_id,p_login,NULLIF(p_ip,'')::inet,p_user_agent,'SUCCESS',NULL,p_session_id::text,v_count);
END $$;

CREATE OR REPLACE PROCEDURE sp_record_login_failure(
 IN p_user_id bigint,IN p_society_id bigint,IN p_login varchar,IN p_ip varchar,IN p_user_agent varchar,IN p_reason varchar)
LANGUAGE plpgsql AS $$
DECLARE v_count bigint:=0;
BEGIN
 CALL sp_record_login(p_user_id,p_login,NULLIF(p_ip,'')::inet,p_user_agent,'FAILURE',p_reason,NULL,v_count);
END $$;

CREATE OR REPLACE PROCEDURE sp_record_subscription_payment(
 IN p_society_id bigint,IN p_subscription_id bigint,IN p_amount numeric,IN p_payment_mode varchar,IN p_reference_no varchar,IN p_user_id bigint,
 INOUT p_payment_id bigint DEFAULT NULL,INOUT p_subscription_id_out bigint DEFAULT NULL,INOUT p_payment_status varchar DEFAULT NULL)
LANGUAGE plpgsql AS $$
BEGIN
 SELECT payment_id,subscription_id,payment_status INTO p_payment_id,p_subscription_id_out,p_payment_status
 FROM fn_record_subscription_payment(p_society_id,p_subscription_id,p_amount,p_payment_mode,p_reference_no,p_user_id);
END $$;
