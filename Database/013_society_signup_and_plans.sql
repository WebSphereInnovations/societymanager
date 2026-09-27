SET search_path TO society_manager, public;

CREATE OR REPLACE FUNCTION fn_subscription_plans()
RETURNS TABLE(plan_code varchar,plan_name varchar,duration_days integer,price numeric,max_flats integer,max_users integer,features jsonb)
LANGUAGE sql AS $$
SELECT sp.plan_code,sp.plan_name,sp.duration_days,sp.price,sp.max_flats,sp.max_users,sp.features
FROM m_subscription_plan sp
WHERE sp.is_active
ORDER BY price;
$$;

CREATE OR REPLACE FUNCTION fn_create_society_signup(
 p_society_name varchar,p_email varchar,p_phone varchar,p_address text,
 p_admin_name varchar,p_login_name varchar,p_password varchar,p_plan_code varchar
)
RETURNS TABLE(society_id bigint,user_id bigint,society_code varchar,plan_code varchar,plan_name varchar,amount numeric,end_date date)
LANGUAGE plpgsql AS $$
DECLARE
 v_society_id bigint;
 v_user_id bigint;
 v_code varchar;
 v_base varchar;
 v_plan m_subscription_plan%ROWTYPE;
 v_suffix integer:=1;
BEGIN
 IF length(trim(coalesce(p_society_name,'')))<3 THEN RAISE EXCEPTION 'Society name is required'; END IF;
 IF length(trim(coalesce(p_admin_name,'')))<2 THEN RAISE EXCEPTION 'Administrator name is required'; END IF;
 IF length(trim(coalesce(p_login_name,'')))<4 THEN RAISE EXCEPTION 'Login name must contain at least 4 characters'; END IF;
 IF length(coalesce(p_password,''))<10 THEN RAISE EXCEPTION 'Password must contain at least 10 characters'; END IF;
 IF EXISTS(SELECT 1 FROM m_user WHERE lower(login_name)=lower(trim(p_login_name))) THEN RAISE EXCEPTION 'Login name already exists'; END IF;

 SELECT * INTO v_plan FROM m_subscription_plan sp WHERE upper(sp.plan_code)=upper(trim(p_plan_code)) AND sp.is_active;
 IF NOT FOUND THEN RAISE EXCEPTION 'Subscription plan not found'; END IF;

 v_base:=left(regexp_replace(upper(trim(p_society_name)),'[^A-Z0-9]+','','g'),30);
 IF v_base='' THEN v_base:='SOCIETY'; END IF;
 v_code:=v_base;
 WHILE EXISTS(SELECT 1 FROM m_society s WHERE s.society_code=v_code) LOOP
   v_suffix:=v_suffix+1;
   v_code:=left(v_base,30-length(v_suffix::text)-1)||'-'||v_suffix::text;
 END LOOP;

 INSERT INTO m_society(society_code,society_name,email,phone,address)
 VALUES(v_code,trim(p_society_name),nullif(trim(p_email),''),nullif(trim(p_phone),''),nullif(trim(p_address),''))
 RETURNING m_society.society_id INTO v_society_id;

 INSERT INTO m_society_branding(society_id,short_name,logo_mode)
 VALUES(v_society_id,left(trim(p_society_name),30),'generated');

 INSERT INTO m_user(society_id,login_name,display_name,email,phone,password_hash,role_code,is_active)
 VALUES(v_society_id,lower(trim(p_login_name)),trim(p_admin_name),nullif(trim(p_email),''),nullif(trim(p_phone),''),
        crypt(p_password,gen_salt('bf',12)),'SOCIETY_ADMIN',true)
 RETURNING m_user.user_id INTO v_user_id;

 INSERT INTO m_user_role(user_id,role_id)
 SELECT v_user_id,role_id FROM m_role WHERE role_code='SOCIETY_ADMIN'
 ON CONFLICT DO NOTHING;
 INSERT INTO m_user_society(user_id,society_id,is_default)
 VALUES(v_user_id,v_society_id,true)
 ON CONFLICT ON CONSTRAINT m_user_society_pkey DO UPDATE SET is_default=true;

 UPDATE m_society_subscription ss SET is_active=false WHERE ss.society_id=v_society_id;
 INSERT INTO m_society_subscription(society_id,subscription_plan_id,start_date,end_date,amount,payment_status,is_active)
 VALUES(v_society_id,v_plan.subscription_plan_id,current_date,current_date+v_plan.duration_days-1,v_plan.price,'Pending',true);

 INSERT INTO m_charge_type(society_id,charge_code,charge_name,calculation_method,recurring,taxable,mandatory)
 SELECT v_society_id,x.code,x.name,x.method,true,false,true
 FROM (VALUES
   ('MAINT','Monthly Maintenance','Fixed'),
   ('SINK','Sinking Fund','Fixed'),
   ('WATER','Water Charges','Fixed'),
   ('PARK','Parking','Fixed'),
   ('REPAIR','Repair Fund','Fixed')
 ) x(code,name,method)
 ON CONFLICT DO NOTHING;

 INSERT INTO m_rate_plan(society_id,plan_name,effective_from)
 VALUES(v_society_id,'Standard Plan',current_date)
 ON CONFLICT DO NOTHING;

 INSERT INTO m_payment_mode(society_id,mode_code,mode_name)
 SELECT v_society_id,x.code,x.name
 FROM (VALUES('CASH','Cash'),('UPI','UPI'),('BANK','Bank Transfer'),('CHEQUE','Cheque')) x(code,name)
 ON CONFLICT DO NOTHING;

 PERFORM fn_log_audit(v_society_id,v_user_id,'m_society',v_society_id,'CREATE',NULL,
   jsonb_build_object('source','public_signup','plan',v_plan.plan_code));

 RETURN QUERY SELECT v_society_id,v_user_id,v_code,v_plan.plan_code,v_plan.plan_name,v_plan.price,
   current_date+v_plan.duration_days-1;
END;
$$;