SET search_path TO society_manager, public;
ALTER TABLE m_user ADD COLUMN IF NOT EXISTS customer_id bigint REFERENCES m_customer(customer_id);
ALTER TABLE m_user ADD COLUMN IF NOT EXISTS preferred_language varchar(10) NOT NULL DEFAULT 'en';

CREATE OR REPLACE FUNCTION fn_login_route(p_user_id bigint)
RETURNS TABLE(role_code varchar,route_path varchar,society_id bigint,customer_id bigint) LANGUAGE sql AS $$
SELECT COALESCE((SELECT r.role_code FROM m_user_role ur JOIN m_role r ON r.role_id=ur.role_id
 WHERE ur.user_id=u.user_id AND r.is_active ORDER BY r.is_system DESC,r.role_id LIMIT 1),u.role_code),
 CASE COALESCE((SELECT r.role_code FROM m_user_role ur JOIN m_role r ON r.role_id=ur.role_id
 WHERE ur.user_id=u.user_id AND r.is_active ORDER BY r.is_system DESC,r.role_id LIMIT 1),u.role_code)
 WHEN 'SUPER_ADMIN' THEN '/' WHEN 'SOCIETY_ADMIN' THEN '/modules/society-admin/index.html'
 WHEN 'BILLING_ADMIN' THEN '/modules/cashier/index.html' WHEN 'COLLECTOR' THEN '/modules/cashier/index.html'
 WHEN 'RESIDENT' THEN '/modules/customer/index.html' ELSE '/login' END,
 u.society_id,u.customer_id FROM m_user u WHERE u.user_id=p_user_id;
$$;

CREATE OR REPLACE FUNCTION fn_customer_portal(p_user_id bigint)
RETURNS TABLE(customer_id bigint,customer_code varchar,full_name varchar,phone varchar,email varchar,flat_no varchar,wing varchar,building varchar,relation_type varchar) LANGUAGE sql AS $$
SELECT c.customer_id,c.customer_code,c.full_name,c.phone,c.email,f.flat_no,w.wing_name,b.building_name,cf.relation_type
FROM m_user u JOIN m_customer c ON c.customer_id=u.customer_id AND c.society_id=u.society_id
JOIN m_customer_flat cf ON cf.customer_id=c.customer_id AND cf.society_id=c.society_id AND cf.is_primary
JOIN m_flat f ON f.flat_id=cf.flat_id AND f.society_id=c.society_id LEFT JOIN m_wing w ON w.wing_id=f.wing_id LEFT JOIN m_building b ON b.building_id=f.building_id
WHERE u.user_id=p_user_id AND u.role_code='RESIDENT' AND u.is_active;
$$;

CREATE OR REPLACE FUNCTION fn_customer_portal_bills(p_user_id bigint)
RETURNS TABLE(bill_id bigint,bill_no varchar,bill_month date,total_amount numeric,paid_amount numeric,balance numeric,due_date date,status varchar) LANGUAGE sql AS $$
SELECT b.bill_id,b.bill_no,b.bill_month,b.total_amount,b.paid_amount,b.total_amount-b.paid_amount,b.due_date,b.status
FROM m_user u JOIN m_customer_flat cf ON cf.customer_id=u.customer_id AND cf.society_id=u.society_id AND cf.is_primary JOIN t_bill b ON b.flat_id=cf.flat_id AND b.society_id=u.society_id
WHERE u.user_id=p_user_id AND u.role_code='RESIDENT' ORDER BY b.bill_month DESC,b.bill_id DESC;
$$;

CREATE OR REPLACE FUNCTION fn_customer_portal_complaints(p_user_id bigint)
RETURNS TABLE(complaint_id bigint,complaint_no varchar,category varchar,title varchar,description text,priority varchar,status varchar,created_at timestamptz) LANGUAGE sql AS $$
SELECT c.complaint_id,c.complaint_no,c.category,c.title,c.description,c.priority,c.status,c.created_at FROM m_user u JOIN t_complaint c ON c.customer_id=u.customer_id AND c.society_id=u.society_id
WHERE u.user_id=p_user_id AND u.role_code='RESIDENT' ORDER BY c.created_at DESC;
$$;

CREATE OR REPLACE FUNCTION fn_customer_portal_create_complaint(p_user_id bigint,p_category varchar,p_title varchar,p_description text,p_priority varchar DEFAULT 'Normal')
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_id bigint;v_society bigint;v_customer bigint;
BEGIN SELECT society_id,customer_id INTO v_society,v_customer FROM m_user WHERE user_id=p_user_id AND role_code='RESIDENT' AND is_active;
IF v_society IS NULL OR v_customer IS NULL THEN RAISE EXCEPTION 'Customer account is not valid'; END IF;
INSERT INTO t_complaint(society_id,customer_id,complaint_no,category,title,description,priority,status) VALUES(v_society,v_customer,'CMP-'||to_char(clock_timestamp(),'YYYYMMDDHH24MISSMS'),p_category,p_title,p_description,p_priority,'Open') RETURNING complaint_id INTO v_id; RETURN v_id; END; $$;

DROP FUNCTION IF EXISTS fn_provision_demo_accounts();
CREATE OR REPLACE FUNCTION fn_provision_demo_accounts()
RETURNS void LANGUAGE plpgsql AS $$
DECLARE v_soc bigint;v_customer bigint;v_user bigint;
BEGIN
SELECT society_id INTO v_soc FROM m_society WHERE society_code='LAKEVIEW';
PERFORM fn_create_super_admin('rahul','Rahul Super Admin','SuperAdmin@12345');
INSERT INTO m_user(society_id,login_name,display_name,password_hash,role_code,is_active) VALUES(v_soc,'lakeadmin','Lakeview Society Admin',crypt('Society@12345',gen_salt('bf',12)),'SOCIETY_ADMIN',true)
ON CONFLICT(login_name) DO UPDATE SET password_hash=excluded.password_hash,is_active=true,role_code='SOCIETY_ADMIN' RETURNING user_id INTO v_user;
INSERT INTO m_user_role SELECT v_user,role_id FROM m_role WHERE role_code='SOCIETY_ADMIN' ON CONFLICT DO NOTHING;
INSERT INTO m_user_society VALUES(v_user,v_soc,true) ON CONFLICT(user_id,society_id) DO UPDATE SET is_default=true;
INSERT INTO m_user(society_id,login_name,display_name,password_hash,role_code,is_active) VALUES(v_soc,'lakecashier','Lakeview Cashier',crypt('Cashier@12345',gen_salt('bf',12)),'COLLECTOR',true)
ON CONFLICT(login_name) DO UPDATE SET password_hash=excluded.password_hash,is_active=true,role_code='COLLECTOR' RETURNING user_id INTO v_user;
INSERT INTO m_user_role SELECT v_user,role_id FROM m_role WHERE role_code='COLLECTOR' ON CONFLICT DO NOTHING;
INSERT INTO m_user_society VALUES(v_user,v_soc,true) ON CONFLICT(user_id,society_id) DO UPDATE SET is_default=true;
SELECT c.customer_id INTO v_customer FROM m_customer c JOIN m_customer_flat cf ON cf.customer_id=c.customer_id AND cf.is_primary WHERE c.society_id=v_soc ORDER BY c.customer_id LIMIT 1;
INSERT INTO m_user(society_id,customer_id,login_name,display_name,password_hash,role_code,is_active) VALUES(v_soc,v_customer,'lakeowner','Rahul Sharma 1',crypt('Owner@12345',gen_salt('bf',12)),'RESIDENT',true)
ON CONFLICT(login_name) DO UPDATE SET password_hash=excluded.password_hash,is_active=true,role_code='RESIDENT',customer_id=excluded.customer_id,society_id=excluded.society_id RETURNING user_id INTO v_user;
INSERT INTO m_user_role SELECT v_user,role_id FROM m_role WHERE role_code='RESIDENT' ON CONFLICT DO NOTHING;
INSERT INTO m_user_society VALUES(v_user,v_soc,true) ON CONFLICT(user_id,society_id) DO UPDATE SET is_default=true;
RETURN;
END; $$;