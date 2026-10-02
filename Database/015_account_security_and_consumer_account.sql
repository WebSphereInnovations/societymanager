SET search_path TO society_manager, public;

ALTER TABLE m_user ADD COLUMN IF NOT EXISTS account_type_code varchar(60);
ALTER TABLE m_user ADD COLUMN IF NOT EXISTS user_permission_configured boolean NOT NULL DEFAULT false;
ALTER TABLE m_user ADD COLUMN IF NOT EXISTS valid_from date NOT NULL DEFAULT current_date;
ALTER TABLE m_user ADD COLUMN IF NOT EXISTS valid_to date;

CREATE TABLE IF NOT EXISTS m_user_permission(
 user_id bigint NOT NULL REFERENCES m_user(user_id) ON DELETE CASCADE,
 permission_id bigint NOT NULL REFERENCES m_permission(permission_id) ON DELETE CASCADE,
 granted boolean NOT NULL DEFAULT true,
 modified_by bigint REFERENCES m_user(user_id),
 modified_at timestamptz NOT NULL DEFAULT now(),
 modify_remark varchar(500) NOT NULL DEFAULT '',
 PRIMARY KEY(user_id,permission_id)
);
CREATE INDEX IF NOT EXISTS ix_m_user_permission_user ON m_user_permission(user_id);

INSERT INTO m_role(role_code,role_name,description,is_system) VALUES
('CASHIER','Cashier','Cash collection and receipt operator',true),
('GUARD','Guard','Gate and visitor security operator',true),
('EMPLOYEE','Society Employee','General society employee',true),
('MAINTENANCE','Maintenance','Maintenance and service operator',true),
('ACCOUNTANT','Accountant','Society accounts operator',true)
ON CONFLICT(role_code) DO NOTHING;

INSERT INTO m_permission(module_code,action_code,permission_name)
SELECT m.module_code,'VIEW','View '||m.module_name
FROM m_module m
WHERE m.is_active
ON CONFLICT(module_code,action_code) DO NOTHING;

INSERT INTO m_permission(module_code,action_code,permission_name)
SELECT m.module_code,a.action_code,initcap(lower(a.action_code))||' '||m.module_name
FROM m_module m
CROSS JOIN (VALUES('VIEW'),('ADD'),('EDIT'),('DELETE'),('APPROVE'),('POST'),('CANCEL'),('PRINT'),('EXPORT'),('ASSIGN'),('IMPORT'),('REFUND')) a(action_code)
WHERE m.is_active
ON CONFLICT(module_code,action_code) DO NOTHING;

INSERT INTO m_role_permission(role_id,permission_id)
SELECT r.role_id,p.permission_id
FROM m_role r JOIN m_permission p ON p.module_code='ADMINISTRATOR' AND p.action_code IN ('VIEW','ADD','EDIT')
WHERE r.role_code IN ('SUPER_ADMIN','SOCIETY_ADMIN')
ON CONFLICT DO NOTHING;

INSERT INTO m_role_permission(role_id,permission_id)
SELECT r.role_id,p.permission_id
FROM m_role r JOIN m_permission p ON p.module_code IN (SELECT module_code FROM m_module WHERE is_active)
WHERE r.role_code IN ('SUPER_ADMIN','SOCIETY_ADMIN')
ON CONFLICT DO NOTHING;

CREATE OR REPLACE FUNCTION fn_user_permissions(p_user_id bigint)
RETURNS TABLE(module_code varchar,action_code varchar)
LANGUAGE sql AS $$
SELECT DISTINCT p.module_code,p.action_code
FROM m_permission p
JOIN m_user_permission up ON up.permission_id=p.permission_id AND up.user_id=p_user_id AND up.granted
JOIN m_user u ON u.user_id=p_user_id AND u.is_active
WHERE p.is_active
  AND (u.valid_from IS NULL OR u.valid_from<=current_date)
  AND (u.valid_to IS NULL OR u.valid_to>=current_date)
UNION
SELECT DISTINCT p.module_code,p.action_code
FROM m_user u
JOIN m_user_role ur ON ur.user_id=u.user_id
JOIN m_role r ON r.role_id=ur.role_id AND r.is_active
JOIN m_role_permission rp ON rp.role_id=r.role_id
JOIN m_permission p ON p.permission_id=rp.permission_id AND p.is_active
WHERE u.user_id=p_user_id
  AND NOT u.user_permission_configured
  AND (u.valid_from IS NULL OR u.valid_from<=current_date)
  AND (u.valid_to IS NULL OR u.valid_to>=current_date)
ORDER BY 1,2;
$$;

CREATE OR REPLACE FUNCTION fn_user_has_permission(p_user_id bigint,p_module_code varchar,p_action_code varchar DEFAULT 'VIEW')
RETURNS boolean
LANGUAGE sql AS $$
SELECT EXISTS(
 SELECT 1 FROM fn_user_permissions(p_user_id) x
 WHERE x.module_code=p_module_code AND x.action_code=p_action_code
);
$$;

CREATE OR REPLACE FUNCTION fn_user_module_menu(p_user_id bigint)
RETURNS TABLE(module_code varchar,module_name varchar,parent_module_code varchar,display_order integer)
LANGUAGE sql AS $$
SELECT DISTINCT m.module_code,m.module_name,m.parent_module_code,m.display_order
FROM m_module m
WHERE m.is_active
AND (
 EXISTS(SELECT 1 FROM fn_user_permissions(p_user_id) p WHERE p.module_code=m.module_code AND p.action_code='VIEW')
 OR EXISTS(
   SELECT 1 FROM m_module child
   WHERE child.parent_module_code=m.module_code AND child.is_active
   AND EXISTS(SELECT 1 FROM fn_user_permissions(p_user_id) p WHERE p.module_code=child.module_code AND p.action_code='VIEW')
 )
)
ORDER BY m.display_order,m.module_code;
$$;

CREATE OR REPLACE FUNCTION fn_admin_account_types()
RETURNS TABLE(role_code varchar,role_name varchar,description text)
LANGUAGE sql AS $$
SELECT role_code,role_name,description FROM m_role
WHERE is_active AND role_code NOT IN ('SUPER_ADMIN','RESIDENT')
ORDER BY is_system DESC,role_name;
$$;

CREATE OR REPLACE FUNCTION fn_admin_account_list(p_society_id bigint,p_search varchar DEFAULT '')
RETURNS TABLE(
 user_id bigint,login_name varchar,display_name varchar,email varchar,phone varchar,
 account_type_code varchar,account_type_name varchar,is_active boolean,valid_from date,valid_to date,
 last_login_at timestamptz,login_count bigint
) LANGUAGE sql AS $$
SELECT u.user_id,u.login_name,u.display_name,u.email,u.phone,
 COALESCE(u.account_type_code,u.role_code),
 COALESCE(r.role_name,u.role_code),
 u.is_active,u.valid_from,u.valid_to,u.last_login_at,
 COALESCE(a.login_count,0)
FROM m_user u
LEFT JOIN m_role r ON r.role_code=COALESCE(u.account_type_code,u.role_code)
LEFT JOIN t_user_login_audit a ON a.user_id=u.user_id
WHERE u.society_id=p_society_id
  AND u.role_code NOT IN ('SUPER_ADMIN','RESIDENT')
  AND (
   length(trim(COALESCE(p_search,'')))=0 OR
   u.login_name ILIKE '%'||trim(p_search)||'%' OR
   u.display_name ILIKE '%'||trim(p_search)||'%' OR
   u.phone ILIKE '%'||trim(p_search)||'%' OR
   COALESCE(u.account_type_code,u.role_code) ILIKE '%'||trim(p_search)||'%'
  )
ORDER BY u.display_name,u.user_id;
$$;

CREATE OR REPLACE FUNCTION fn_admin_module_rights()
RETURNS TABLE(module_code varchar,module_name varchar,parent_module_code varchar,display_order integer,action_code varchar,permission_name varchar,granted boolean)
LANGUAGE sql AS $$
SELECT m.module_code,m.module_name,m.parent_module_code,m.display_order,p.action_code,p.permission_name,false
FROM m_module m
JOIN m_permission p ON p.module_code=m.module_code AND p.is_active
WHERE m.is_active
ORDER BY m.display_order,m.module_code,p.action_code;
$$;

CREATE OR REPLACE FUNCTION fn_admin_account_rights(p_user_id bigint,p_society_id bigint)
RETURNS TABLE(module_code varchar,module_name varchar,parent_module_code varchar,display_order integer,action_code varchar,permission_name varchar,granted boolean)
LANGUAGE sql AS $$
SELECT m.module_code,m.module_name,m.parent_module_code,m.display_order,p.action_code,p.permission_name,
       EXISTS(
         SELECT 1 FROM m_user_permission up
         WHERE up.user_id=p_user_id AND up.permission_id=p.permission_id AND up.granted
       ) granted
FROM m_module m
JOIN m_permission p ON p.module_code=m.module_code AND p.is_active
JOIN m_user u ON u.user_id=p_user_id AND u.society_id=p_society_id
WHERE m.is_active
ORDER BY m.display_order,m.module_code,p.action_code;
$$;

CREATE OR REPLACE PROCEDURE sp_admin_save_account(
 IN p_society_id bigint,IN p_user_id bigint,IN p_login_name varchar,IN p_display_name varchar,
 IN p_email varchar,IN p_phone varchar,IN p_account_type varchar,IN p_password varchar,
 IN p_valid_from date,IN p_valid_to date,IN p_rights jsonb,IN p_modified_by bigint,IN p_remark varchar DEFAULT '',
 INOUT p_saved_user_id bigint DEFAULT NULL
)
LANGUAGE plpgsql AS $$
DECLARE v_role_id bigint; v_role_code varchar:=upper(trim(p_account_type));
BEGIN
 IF p_society_id IS NULL OR NOT EXISTS(SELECT 1 FROM m_society WHERE society_id=p_society_id AND is_active) THEN RAISE EXCEPTION 'Society not found'; END IF;
 IF length(trim(COALESCE(p_login_name,'')))<4 THEN RAISE EXCEPTION 'Login name must contain at least 4 characters'; END IF;
 IF length(trim(COALESCE(p_display_name,'')))<2 THEN RAISE EXCEPTION 'Display name is required'; END IF;
 IF p_valid_to IS NOT NULL AND p_valid_to<p_valid_from THEN RAISE EXCEPTION 'Valid To cannot be before Valid From'; END IF;
 SELECT role_id INTO v_role_id FROM m_role WHERE role_code=v_role_code AND is_active;
 IF v_role_id IS NULL THEN RAISE EXCEPTION 'Account type not found'; END IF;

 IF COALESCE(p_user_id,0)=0 THEN
   IF length(COALESCE(p_password,''))<10 THEN RAISE EXCEPTION 'Password must contain at least 10 characters'; END IF;
   IF EXISTS(SELECT 1 FROM m_user WHERE lower(login_name)=lower(trim(p_login_name))) THEN RAISE EXCEPTION 'Login name already exists'; END IF;
   INSERT INTO m_user(society_id,login_name,display_name,email,phone,password_hash,role_code,account_type_code,is_active,valid_from,valid_to,modified_by,modified_at,modify_remark)
   VALUES(p_society_id,lower(trim(p_login_name)),trim(p_display_name),NULLIF(trim(p_email),''),NULLIF(trim(p_phone),''),
          crypt(p_password,gen_salt('bf',12)),v_role_code,v_role_code,true,COALESCE(p_valid_from,current_date),p_valid_to,p_modified_by,now(),COALESCE(p_remark,''))
   RETURNING user_id INTO p_saved_user_id;
   INSERT INTO m_user_society(user_id,society_id,is_default) VALUES(p_saved_user_id,p_society_id,true) ON CONFLICT(user_id,society_id) DO UPDATE SET is_default=true;
   INSERT INTO m_user_role(user_id,role_id) VALUES(p_saved_user_id,v_role_id) ON CONFLICT DO NOTHING;
 ELSE
   IF NOT EXISTS(SELECT 1 FROM m_user WHERE user_id=p_user_id AND society_id=p_society_id) THEN RAISE EXCEPTION 'Account does not belong to selected society'; END IF;
   IF EXISTS(SELECT 1 FROM m_user WHERE lower(login_name)=lower(trim(p_login_name)) AND user_id<>p_user_id) THEN RAISE EXCEPTION 'Login name already exists'; END IF;
   UPDATE m_user SET login_name=lower(trim(p_login_name)),display_name=trim(p_display_name),email=NULLIF(trim(p_email),''),
     phone=NULLIF(trim(p_phone),''),role_code=v_role_code,account_type_code=v_role_code,
     valid_from=COALESCE(p_valid_from,current_date),valid_to=p_valid_to,modified_by=p_modified_by,modified_at=now(),modify_remark=COALESCE(p_remark,'')
   WHERE user_id=p_user_id;
   IF length(COALESCE(p_password,''))>0 THEN
     IF length(p_password)<10 THEN RAISE EXCEPTION 'Password must contain at least 10 characters'; END IF;
     UPDATE m_user SET password_hash=crypt(p_password,gen_salt('bf',12)) WHERE user_id=p_user_id;
   END IF;
   DELETE FROM m_user_role WHERE user_id=p_user_id;
   INSERT INTO m_user_role(user_id,role_id) VALUES(p_user_id,v_role_id);
   p_saved_user_id:=p_user_id;
 END IF;

 UPDATE m_user SET user_permission_configured=true,modified_by=p_modified_by,modified_at=now(),modify_remark=COALESCE(p_remark,'') WHERE user_id=p_saved_user_id;
 DELETE FROM m_user_permission WHERE user_id=p_saved_user_id;
 INSERT INTO m_user_permission(user_id,permission_id,granted,modified_by,modified_at,modify_remark)
 SELECT p_saved_user_id,p.permission_id,true,p_modified_by,now(),COALESCE(p_remark,'')
 FROM jsonb_to_recordset(COALESCE(p_rights,'[]'::jsonb))
      AS x(module_code varchar,action_code varchar,granted boolean)
 JOIN m_permission p ON p.module_code=x.module_code AND p.action_code=x.action_code AND p.is_active
 WHERE COALESCE(x.granted,true);
END $$;

CREATE OR REPLACE PROCEDURE sp_admin_set_account_status(
 IN p_society_id bigint,IN p_user_id bigint,IN p_is_active boolean,IN p_modified_by bigint,IN p_remark varchar DEFAULT '')
LANGUAGE plpgsql AS $$
BEGIN
 UPDATE m_user SET is_active=p_is_active,modified_by=p_modified_by,modified_at=now(),modify_remark=COALESCE(p_remark,'')
 WHERE user_id=p_user_id AND society_id=p_society_id AND role_code NOT IN ('SUPER_ADMIN','RESIDENT');
 IF NOT FOUND THEN RAISE EXCEPTION 'Account not found in selected society'; END IF;
END $$;

CREATE OR REPLACE PROCEDURE sp_admin_extend_account(
 IN p_society_id bigint,IN p_user_id bigint,IN p_valid_to date,IN p_modified_by bigint,IN p_remark varchar DEFAULT '')
LANGUAGE plpgsql AS $$
BEGIN
 UPDATE m_user SET valid_to=p_valid_to,modified_by=p_modified_by,modified_at=now(),modify_remark=COALESCE(p_remark,'')
 WHERE user_id=p_user_id AND society_id=p_society_id AND role_code NOT IN ('SUPER_ADMIN','RESIDENT');
 IF NOT FOUND THEN RAISE EXCEPTION 'Account not found in selected society'; END IF;
END $$;

CREATE OR REPLACE FUNCTION fn_authenticate_user(p_login varchar,p_password varchar)
RETURNS TABLE(user_id bigint,login_name varchar,display_name varchar,role_code varchar,preferred_language varchar)
LANGUAGE sql AS $$
SELECT u.user_id,u.login_name,u.display_name,
 COALESCE((SELECT r.role_code FROM m_user_role ur JOIN m_role r ON r.role_id=ur.role_id
 WHERE ur.user_id=u.user_id AND r.is_active ORDER BY r.is_system DESC,r.role_id LIMIT 1),u.role_code),
 u.preferred_language
FROM m_user u
WHERE lower(u.login_name)=lower(p_login) AND u.is_active
  AND (u.valid_from IS NULL OR u.valid_from<=current_date)
  AND (u.valid_to IS NULL OR u.valid_to>=current_date)
  AND u.password_hash IS NOT NULL AND u.password_hash=crypt(p_password,u.password_hash);
$$;

CREATE OR REPLACE FUNCTION fn_session_context(p_token_hash text)
RETURNS TABLE(session_id uuid,user_id bigint,society_id bigint,login_name varchar,display_name varchar,role_code varchar)
LANGUAGE sql AS $$
SELECT s.session_id,s.user_id,s.society_id,u.login_name,u.display_name,
 COALESCE((SELECT r.role_code FROM m_user_role ur JOIN m_role r ON r.role_id=ur.role_id WHERE ur.user_id=u.user_id AND r.is_active ORDER BY r.is_system DESC,r.role_id LIMIT 1),u.role_code)
FROM t_user_session s JOIN m_user u ON u.user_id=s.user_id
WHERE s.token_hash=p_token_hash AND s.revoked_at IS NULL AND s.expires_at>now() AND u.is_active
  AND (u.valid_from IS NULL OR u.valid_from<=current_date)
  AND (u.valid_to IS NULL OR u.valid_to>=current_date);
$$;

CREATE OR REPLACE FUNCTION fn_login_route(p_user_id bigint)
RETURNS TABLE(role_code varchar,route_path varchar,society_id bigint,customer_id bigint)
LANGUAGE sql AS $$
SELECT COALESCE((SELECT r.role_code FROM m_user_role ur JOIN m_role r ON r.role_id=ur.role_id AND r.is_active WHERE ur.user_id=u.user_id ORDER BY r.is_system DESC,r.role_id LIMIT 1),u.role_code),
       CASE WHEN u.role_code='SUPER_ADMIN' THEN '/' WHEN u.role_code='RESIDENT' THEN '/modules/customer/index.html' ELSE '/modules/society-admin/index.html' END,
       u.society_id,u.customer_id
FROM m_user u
WHERE u.user_id=p_user_id AND u.is_active
  AND (u.valid_from IS NULL OR u.valid_from<=current_date)
  AND (u.valid_to IS NULL OR u.valid_to>=current_date);
$$;

CREATE OR REPLACE FUNCTION fn_consumer_account(p_society_id bigint,p_customer_id bigint)
RETURNS TABLE(
 customer_id bigint,customer_code varchar,full_name varchar,customer_type varchar,phone varchar,email varchar,
 flat_id bigint,flat_no varchar,wing varchar,building varchar,area_sqft numeric,occupancy_status varchar,
 relation_type varchar,last_bill_date date,last_bill_amount numeric,arrear numeric,last_payment_date date
) LANGUAGE sql AS $$
SELECT c.customer_id,c.customer_code,c.full_name,c.customer_type,c.phone,c.email,
 f.flat_id,f.flat_no,COALESCE(w.wing_name,w.wing_code,''),COALESCE(b.building_name,b.building_code,''),
 f.area_sqft,f.occupancy_status,cf.relation_type,
 (SELECT max(x.bill_month) FROM t_bill x WHERE x.society_id=p_society_id AND x.flat_id=f.flat_id),
 (SELECT x.total_amount FROM t_bill x WHERE x.society_id=p_society_id AND x.flat_id=f.flat_id ORDER BY x.bill_month DESC,x.bill_id DESC LIMIT 1),
 COALESCE((SELECT sum(x.total_amount-x.paid_amount) FROM t_bill x WHERE x.society_id=p_society_id AND x.flat_id=f.flat_id AND x.total_amount>x.paid_amount),0),
 (SELECT max(x.payment_date)::date FROM t_payment x WHERE x.society_id=p_society_id AND x.customer_id=c.customer_id)
FROM m_customer c
LEFT JOIN m_customer_flat cf ON cf.customer_id=c.customer_id AND cf.society_id=p_society_id
LEFT JOIN m_flat f ON f.flat_id=cf.flat_id AND f.society_id=p_society_id AND f.is_active
LEFT JOIN m_wing w ON w.wing_id=f.wing_id AND w.society_id=p_society_id
LEFT JOIN m_building b ON b.building_id=f.building_id AND b.society_id=p_society_id
WHERE c.society_id=p_society_id AND c.customer_id=p_customer_id AND c.is_active
ORDER BY f.flat_no;
$$;

DROP FUNCTION IF EXISTS fn_society_admin_customer_search(bigint,varchar,integer);
CREATE FUNCTION fn_society_admin_customer_search(p_society_id bigint,p_search varchar,p_limit integer DEFAULT 50)
RETURNS TABLE(customer_id bigint,customer_code varchar,full_name varchar,phone varchar,email varchar,flat_no varchar,wing varchar) LANGUAGE sql AS $$
SELECT c.customer_id,c.customer_code,c.full_name,c.phone,c.email,f.flat_no,COALESCE(w.wing_name,w.wing_code,'')
FROM m_customer c
LEFT JOIN m_customer_flat cf ON cf.customer_id=c.customer_id AND cf.society_id=p_society_id AND cf.is_primary
LEFT JOIN m_flat f ON f.flat_id=cf.flat_id AND f.society_id=p_society_id
LEFT JOIN m_wing w ON w.wing_id=f.wing_id AND w.society_id=p_society_id
WHERE c.society_id=p_society_id AND c.is_active
AND (length(trim(COALESCE(p_search,'')))=0 OR c.full_name ILIKE '%'||trim(p_search)||'%' OR c.phone ILIKE '%'||trim(p_search)||'%' OR c.customer_code ILIKE '%'||trim(p_search)||'%' OR COALESCE(f.flat_no,'') ILIKE '%'||trim(p_search)||'%' OR COALESCE(w.wing_code,'') ILIKE '%'||trim(p_search)||'%')
ORDER BY c.full_name LIMIT greatest(1,least(COALESCE(p_limit,50),200));
$$;

CREATE OR REPLACE FUNCTION fn_consumer_account_service_history(p_society_id bigint,p_customer_id bigint)
RETURNS TABLE(service_history_id bigint,event_type varchar,event_sub_type varchar,event_title varchar,event_description text,reference_no varchar,performed_by_name varchar,performed_at timestamptz)
LANGUAGE sql AS $$
SELECT h.service_history_id,h.event_type,h.event_sub_type,h.event_title,h.event_description,h.reference_no,u.display_name,h.performed_at
FROM t_service_history h
LEFT JOIN m_user u ON u.user_id=h.performed_by
WHERE h.society_id=p_society_id AND h.customer_id=p_customer_id
ORDER BY h.performed_at DESC;
$$;
