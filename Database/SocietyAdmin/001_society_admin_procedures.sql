[Reading 123 lines from start (total: 123 lines, 0 remaining)]

SET search_path TO society_manager, public;

CREATE OR REPLACE FUNCTION fn_society_admin_dashboard(p_society_id bigint,p_month date)
RETURNS TABLE(total_flats bigint,occupied_flats bigint,billed numeric,collected numeric,outstanding numeric,open_complaints bigint,inside_visitors bigint,parking_slots bigint) LANGUAGE sql AS $$
SELECT
 (SELECT count(*) FROM m_flat WHERE society_id=p_society_id AND is_active),
 (SELECT count(*) FROM m_flat WHERE society_id=p_society_id AND is_active AND occupancy_status='Occupied'),
 COALESCE((SELECT sum(total_amount) FROM t_bill WHERE society_id=p_society_id AND bill_month=date_trunc('month',p_month)::date),0),
 COALESCE((SELECT sum(amount) FROM t_payment WHERE society_id=p_society_id AND payment_date::date>=date_trunc('month',p_month)::date AND payment_date::date<(date_trunc('month',p_month)+interval '1 month')::date),0),
 COALESCE((SELECT sum(total_amount-paid_amount) FROM t_bill WHERE society_id=p_society_id AND total_amount>paid_amount),0),
 (SELECT count(*) FROM t_complaint WHERE society_id=p_society_id AND status NOT IN ('Closed','Resolved')),
 (SELECT count(*) FROM t_visitor_entry WHERE society_id=p_society_id AND status='Inside'),
 (SELECT count(*) FROM m_parking_slot WHERE society_id=p_society_id AND is_active);
$$;

CREATE OR REPLACE FUNCTION fn_society_admin_customer_search(p_society_id bigint,p_search varchar,p_limit integer DEFAULT 50)
RETURNS TABLE(customer_id bigint,customer_code varchar,full_name varchar,phone varchar,email varchar,flat_no varchar,wing varchar) LANGUAGE sql AS $$
SELECT c.customer_id,c.customer_code,c.full_name,c.phone,c.email,f.flat_no,COALESCE(w.wing_name,w.wing_code,'')
FROM m_customer c LEFT JOIN m_customer_flat cf ON cf.customer_id=c.customer_id AND cf.is_primary
LEFT JOIN m_flat f ON f.flat_id=cf.flat_id LEFT JOIN m_wing w ON w.wing_id=f.wing_id
WHERE c.society_id=p_society_id AND c.is_active
AND (length(trim(COALESCE(p_search,'')))=0 OR c.full_name ILIKE trim(p_search)||'%' OR c.full_name ILIKE '%'||trim(p_search)||'%' OR c.phone ILIKE '%'||trim(p_search)||'%' OR c.customer_code ILIKE '%'||trim(p_search)||'%')
ORDER BY c.full_name LIMIT greatest(1,least(COALESCE(p_limit,50),200));
$$;

CREATE OR REPLACE FUNCTION fn_society_admin_flat_search(p_society_id bigint,p_search varchar,p_limit integer DEFAULT 50)
RETURNS TABLE(flat_id bigint,flat_no varchar,wing varchar,building varchar,unit_type varchar,area_sqft numeric,occupancy_status varchar,owner_name varchar,owner_phone varchar) LANGUAGE sql AS $$
SELECT f.flat_id,f.flat_no,COALESCE(w.wing_name,w.wing_code,''),COALESCE(b.building_name,b.building_code,''),f.unit_type,f.area_sqft,f.occupancy_status,COALESCE(c.full_name,''),COALESCE(c.phone,'')
FROM m_flat f LEFT JOIN m_wing w ON w.wing_id=f.wing_id LEFT JOIN m_building b ON b.building_id=f.building_id
LEFT JOIN m_customer_flat cf ON cf.flat_id=f.flat_id AND cf.is_primary LEFT JOIN m_customer c ON c.customer_id=cf.customer_id
WHERE f.society_id=p_society_id AND f.is_active
AND (length(trim(COALESCE(p_search,'')))=0 OR f.flat_no ILIKE '%'||trim(p_search)||'%' OR COALESCE(w.wing_code,'') ILIKE '%'||trim(p_search)||'%' OR COALESCE(w.wing_name,'') ILIKE '%'||trim(p_search)||'%')
ORDER BY f.flat_no LIMIT greatest(1,least(COALESCE(p_limit,50),200));
$$;

CREATE OR REPLACE FUNCTION fn_society_admin_customer_360(p_society_id bigint,p_customer_id bigint)
RETURNS TABLE(customer_id bigint,customer_code varchar,full_name varchar,phone varchar,email varchar,customer_type varchar,flat_id bigint,flat_no varchar,wing varchar,area_sqft numeric,occupancy_status varchar,bill_count bigint,billed_amount numeric,paid_amount numeric,outstanding numeric,complaint_count bigint,last_payment_date date) LANGUAGE sql AS $$
SELECT c.customer_id,c.customer_code,c.full_name,c.phone,c.email,c.customer_type,f.flat_id,f.flat_no,COALESCE(w.wing_name,w.wing_code,''),f.area_sqft,f.occupancy_status,
(SELECT count(*) FROM t_bill b WHERE b.society_id=p_society_id AND b.flat_id=f.flat_id),
COALESCE((SELECT sum(b.total_amount) FROM t_bill b WHERE b.society_id=p_society_id AND b.flat_id=f.flat_id),0),
COALESCE((SELECT sum(p.amount) FROM t_payment p WHERE p.society_id=p_society_id AND p.customer_id=c.customer_id),0),
COALESCE((SELECT sum(b.total_amount-b.paid_amount) FROM t_bill b WHERE b.society_id=p_society_id AND b.flat_id=f.flat_id AND b.total_amount>b.paid_amount),0),
(SELECT count(*) FROM t_complaint x WHERE x.society_id=p_society_id AND x.customer_id=c.customer_id),
(SELECT max(p.payment_date)::date FROM t_payment p WHERE p.society_id=p_society_id AND p.customer_id=c.customer_id)
FROM m_customer c LEFT JOIN m_customer_flat cf ON cf.customer_id=c.customer_id AND cf.is_primary LEFT JOIN m_flat f ON f.flat_id=cf.flat_id LEFT JOIN m_wing w ON w.wing_id=f.wing_id
WHERE c.society_id=p_society_id AND c.customer_id=p_customer_id;
$$;CREATE OR REPLACE FUNCTION fn_society_admin_bill_list(p_society_id bigint,p_search varchar DEFAULT '',p_month date DEFAULT NULL)
RETURNS TABLE(bill_id bigint,bill_no varchar,bill_month date,flat_no varchar,customer_name varchar,total_amount numeric,paid_amount numeric,balance numeric,due_date date,status varchar) LANGUAGE sql AS $$
SELECT b.bill_id,b.bill_no,b.bill_month,f.flat_no,COALESCE(c.full_name,''),b.total_amount,b.paid_amount,b.total_amount-b.paid_amount,b.due_date,b.status
FROM t_bill b JOIN m_flat f ON f.flat_id=b.flat_id LEFT JOIN m_customer_flat cf ON cf.flat_id=f.flat_id AND cf.is_primary LEFT JOIN m_customer c ON c.customer_id=cf.customer_id
WHERE b.society_id=p_society_id AND (p_month IS NULL OR b.bill_month=date_trunc('month',p_month)::date)
AND (length(trim(COALESCE(p_search,'')))=0 OR b.bill_no ILIKE '%'||trim(p_search)||'%' OR f.flat_no ILIKE '%'||trim(p_search)||'%' OR COALESCE(c.full_name,'') ILIKE '%'||trim(p_search)||'%')
ORDER BY b.bill_month DESC,b.bill_id DESC LIMIT 500;
$$;

CREATE OR REPLACE FUNCTION fn_society_admin_collection(p_society_id bigint,p_from date,p_to date)
RETURNS TABLE(payment_id bigint,payment_no varchar,payment_date date,flat_no varchar,customer_name varchar,amount numeric,payment_mode varchar,reference_no varchar) LANGUAGE sql AS $$
SELECT p.payment_id,p.payment_no,p.payment_date::date,f.flat_no,COALESCE(c.full_name,''),p.amount,p.payment_mode,p.reference_no
FROM t_payment p LEFT JOIN m_flat f ON f.flat_id=p.flat_id LEFT JOIN m_customer c ON c.customer_id=p.customer_id
WHERE p.society_id=p_society_id AND p.payment_date::date BETWEEN p_from AND p_to
ORDER BY p.payment_date DESC,p.payment_id DESC LIMIT 500;
$$;

CREATE OR REPLACE FUNCTION fn_society_admin_complaints(p_society_id bigint,p_search varchar DEFAULT '')
RETURNS TABLE(complaint_id bigint,complaint_no varchar,flat_no varchar,customer_name varchar,category varchar,title varchar,priority varchar,status varchar,created_at timestamptz) LANGUAGE sql AS $$
SELECT x.complaint_id,x.complaint_no,f.flat_no,COALESCE(c.full_name,''),x.category,x.title,x.priority,x.status,x.created_at
FROM t_complaint x LEFT JOIN m_flat f ON f.flat_id=x.flat_id LEFT JOIN m_customer c ON c.customer_id=x.customer_id
WHERE x.society_id=p_society_id AND (length(trim(COALESCE(p_search,'')))=0 OR x.complaint_no ILIKE '%'||trim(p_search)||'%' OR COALESCE(f.flat_no,'') ILIKE '%'||trim(p_search)||'%' OR x.title ILIKE '%'||trim(p_search)||'%')
ORDER BY x.created_at DESC LIMIT 500;
$$;

CREATE OR REPLACE FUNCTION fn_society_admin_visitors(p_society_id bigint,p_search varchar DEFAULT '')
RETURNS TABLE(visitor_id bigint,visitor_name varchar,phone varchar,flat_no varchar,visitor_type varchar,purpose varchar,status varchar,entry_time timestamptz,exit_time timestamptz) LANGUAGE sql AS $$
SELECT v.visitor_entry_id,v.visitor_name,v.phone,f.flat_no,v.visitor_type,v.purpose,v.status,v.entry_at,v.exit_at
FROM t_visitor_entry v LEFT JOIN m_flat f ON f.flat_id=v.flat_id
WHERE v.society_id=p_society_id AND (length(trim(COALESCE(p_search,'')))=0 OR v.visitor_name ILIKE '%'||trim(p_search)||'%' OR COALESCE(f.flat_no,'') ILIKE '%'||trim(p_search)||'%' OR v.phone ILIKE '%'||trim(p_search)||'%')
ORDER BY v.entry_at DESC LIMIT 500;
$$;

CREATE OR REPLACE FUNCTION fn_society_admin_parking(p_society_id bigint,p_search varchar DEFAULT '')
RETURNS TABLE(slot_id bigint,slot_no varchar,slot_type varchar,charge numeric,assigned_flat varchar,customer_name varchar,status varchar) LANGUAGE sql AS $$
SELECT s.parking_slot_id AS slot_id,s.slot_no,s.slot_type,s.charge,COALESCE(f.flat_no,''),COALESCE(c.full_name,''),CASE WHEN a.assignment_id IS NULL THEN 'Available' ELSE 'Assigned' END
FROM m_parking_slot s LEFT JOIN t_parking_assignment a ON a.parking_slot_id=s.parking_slot_id AND a.is_active LEFT JOIN m_flat f ON f.flat_id=a.flat_id LEFT JOIN m_customer c ON c.customer_id=a.customer_id
WHERE s.society_id=p_society_id AND s.is_active AND (length(trim(COALESCE(p_search,'')))=0 OR s.slot_no ILIKE '%'||trim(p_search)||'%' OR COALESCE(f.flat_no,'') ILIKE '%'||trim(p_search)||'%')
ORDER BY s.slot_no LIMIT 500;
$$;CREATE OR REPLACE FUNCTION fn_change_user_password(p_user_id bigint,p_current_password varchar,p_new_password varchar)
RETURNS boolean LANGUAGE plpgsql AS $$
BEGIN
 IF length(COALESCE(p_new_password,''))<10 THEN RETURN false; END IF;
 UPDATE m_user SET password_hash=crypt(p_new_password,gen_salt('bf',12))
 WHERE user_id=p_user_id AND is_active AND password_hash=crypt(p_current_password,password_hash);
 RETURN FOUND;
END; $$;

CREATE OR REPLACE FUNCTION fn_change_user_login(p_user_id bigint,p_current_password varchar,p_new_login varchar)
RETURNS boolean LANGUAGE plpgsql AS $$
BEGIN
 IF length(trim(COALESCE(p_new_login,'')))<3 THEN RETURN false; END IF;
 UPDATE m_user SET login_name=trim(p_new_login)
 WHERE user_id=p_user_id AND is_active AND password_hash=crypt(p_current_password,password_hash);
 RETURN FOUND;
EXCEPTION WHEN unique_violation THEN RETURN false;
END; $$;

CREATE OR REPLACE FUNCTION fn_provision_demo_society_admin(p_society_code varchar,p_login varchar,p_password varchar,p_display_name varchar)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_society bigint; v_user bigint;
BEGIN
 SELECT society_id INTO v_society FROM m_society WHERE society_code=p_society_code AND is_active;
 IF v_society IS NULL THEN RAISE EXCEPTION 'Society not found'; END IF;
 SELECT user_id INTO v_user FROM m_user WHERE login_name=p_login;
 IF v_user IS NULL THEN
  INSERT INTO m_user(society_id,login_name,display_name,email,password_hash,role_code,preferred_language)
  VALUES(v_society,p_login,p_display_name,p_login||'@demo.local',crypt(p_password,gen_salt('bf',12)),'SOCIETY_ADMIN','en')
  RETURNING user_id INTO v_user;
 ELSE
  UPDATE m_user SET society_id=v_society,display_name=p_display_name,password_hash=crypt(p_password,gen_salt('bf',12)),role_code='SOCIETY_ADMIN',is_active=true WHERE user_id=v_user;
 END IF;
 INSERT INTO m_user_role(user_id,role_id) SELECT v_user,role_id FROM m_role WHERE role_code='SOCIETY_ADMIN' ON CONFLICT DO NOTHING;
 INSERT INTO m_user_society(user_id,society_id,is_default) VALUES(v_user,v_society,true)
 ON CONFLICT(user_id,society_id) DO UPDATE SET is_default=true;
 RETURN v_user;
END; $$;

[executed on device: Sandman (3c28f028-a467-4934-be2f-752a8db6b6a8)]