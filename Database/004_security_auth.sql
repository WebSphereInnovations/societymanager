SET search_path TO society_manager, public;

CREATE TABLE IF NOT EXISTS m_role(
 role_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 role_code varchar(60) NOT NULL UNIQUE,
 role_name varchar(120) NOT NULL,
 description text,
 is_system boolean NOT NULL DEFAULT false,
 is_active boolean NOT NULL DEFAULT true,
 created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS m_permission(
 permission_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 module_code varchar(80) NOT NULL,
 action_code varchar(50) NOT NULL,
 permission_name varchar(160) NOT NULL,
 is_active boolean NOT NULL DEFAULT true,
 UNIQUE(module_code,action_code)
);

CREATE TABLE IF NOT EXISTS m_role_permission(
 role_id bigint NOT NULL REFERENCES m_role(role_id) ON DELETE CASCADE,
 permission_id bigint NOT NULL REFERENCES m_permission(permission_id) ON DELETE CASCADE,
 PRIMARY KEY(role_id,permission_id)
);

CREATE TABLE IF NOT EXISTS m_user_role( user_id bigint NOT NULL REFERENCES m_user(user_id) ON DELETE CASCADE,
 role_id bigint NOT NULL REFERENCES m_role(role_id) ON DELETE CASCADE,
 PRIMARY KEY(user_id,role_id)
);

CREATE TABLE IF NOT EXISTS m_user_society(
 user_id bigint NOT NULL REFERENCES m_user(user_id) ON DELETE CASCADE,
 society_id bigint NOT NULL REFERENCES m_society(society_id) ON DELETE CASCADE,
 is_default boolean NOT NULL DEFAULT false,
 PRIMARY KEY(user_id,society_id)
);

CREATE TABLE IF NOT EXISTS t_user_session(
 session_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 user_id bigint NOT NULL REFERENCES m_user(user_id) ON DELETE CASCADE,
 token_hash text NOT NULL UNIQUE,
 society_id bigint REFERENCES m_society(society_id),
 created_at timestamptz NOT NULL DEFAULT now(),
 expires_at timestamptz NOT NULL,
 revoked_at timestamptz
);

CREATE INDEX IF NOT EXISTS ix_m_user_society_user ON m_user_society(user_id);
CREATE INDEX IF NOT EXISTS ix_m_user_role_user ON m_user_role(user_id);
CREATE INDEX IF NOT EXISTS ix_m_role_permission_role ON m_role_permission(role_id);
CREATE INDEX IF NOT EXISTS ix_t_user_session_token ON t_user_session(token_hash);

INSERT INTO m_role(role_code,role_name,description,is_system)VALUES
('SUPER_ADMIN','Super Admin','Global platform administrator',true),
('SOCIETY_ADMIN','Society Admin','Society-level administrator',true),
('BILLING_ADMIN','Billing Admin','Billing and collection administrator',true),
('COLLECTOR','Collector','Collection and receipt operator',true),
('SECURITY','Security','Visitor and security operator',true),
('RESIDENT','Resident','Resident self-service role',true)
ON CONFLICT(role_code) DO NOTHING;

INSERT INTO m_permission(module_code,action_code,permission_name)
VALUES
('DASHBOARD','VIEW','View dashboard'),
('SOCIETY','VIEW','View societies'),
('SOCIETY','ADD','Create society'),
('SOCIETY','EDIT','Edit society'),
('SOCIETY','DELETE','Deactivate society'),
('USERS','VIEW','View users'),
('USERS','ADD','Create user'),
('USERS','EDIT','Edit user'),
('USERS','DELETE','Deactivate user'),
('ROLES','VIEW','View roles'),
('ROLES','ADD','Create role'),
('ROLES','EDIT','Edit role'),
('ROLES','DELETE','Deactivate role'),
('ROLES','ASSIGN','Assign permissions'),
('CONFIGURATION','VIEW','View configuration'),
('CONFIGURATION','EDIT','Edit configuration'),
('FLATS','VIEW','View flats'),('FLATS','ADD','Add flat'),
('FLATS','EDIT','Edit flat'),
('FLATS','DELETE','Deactivate flat'),
('RESIDENTS','VIEW','View residents'),
('RESIDENTS','ADD','Add resident'),
('RESIDENTS','EDIT','Edit resident'),
('RESIDENTS','DELETE','Deactivate resident'),
('BILLING','VIEW','View billing'),
('BILLING','ADD','Create bill'),
('BILLING','EDIT','Edit bill'),
('BILLING','DELETE','Delete bill'),
('BILLING','APPROVE','Approve bill'),
('BILLING','POST','Post bill'),
('BILLING','CANCEL','Cancel bill'),
('BILLING','PRINT','Print bill'),
('BILLING','EXPORT','Export bills'),
('COLLECTION','VIEW','View collection'),
('COLLECTION','ADD','Receive payment'),
('COLLECTION','EDIT','Edit payment'),
('COLLECTION','CANCEL','Cancel payment'),
('COLLECTION','REFUND','Refund payment'),
('COLLECTION','PRINT','Print receipt'),
('COLLECTION','EXPORT','Export collection'),
('PARKING','VIEW','View parking'),
('PARKING','ADD','Add parking'),
('PARKING','EDIT','Edit parking'),
('PARKING','DELETE','Delete parking'),
('COMPLAINTS','VIEW','View complaints'),('COMPLAINTS','ADD','Create complaint'),
('COMPLAINTS','EDIT','Update complaint'),
('COMPLAINTS','ASSIGN','Assign complaint'),
('VISITORS','VIEW','View visitors'),
('VISITORS','ADD','Add visitor'),
('VISITORS','EDIT','Update visitor'),
('REPORTS','VIEW','View reports'),
('REPORTS','EXPORT','Export reports'),
('MIGRATION','VIEW','View migration'),
('MIGRATION','IMPORT','Import migration'),
('MIGRATION','APPROVE','Approve migration'),
('AUDIT','VIEW','View audit log')
ON CONFLICT(module_code,action_code) DO NOTHING;

INSERT INTO m_role_permission(role_id,permission_id)
SELECT r.role_id,p.permission_id FROM m_role r CROSS JOIN m_permission p
WHERE r.role_code='SUPER_ADMIN' ON CONFLICT DO NOTHING;

INSERT INTO m_role_permission(role_id,permission_id)
SELECT r.role_id,p.permission_id FROM m_role r JOIN m_permission p ON
 (r.role_code='SOCIETY_ADMIN' AND p.module_code IN
 ('DASHBOARD','SOCIETY','USERS','ROLES','CONFIGURATION','FLATS','RESIDENTS','BILLING','COLLECTION','PARKING','COMPLAINTS','VISITORS','REPORTS','MIGRATION','AUDIT'))
 OR (r.role_code='BILLING_ADMIN' AND p.module_code IN ('DASHBOARD','BILLING','COLLECTION','FLATS','RESIDENTS','REPORTS'))
 OR (r.role_code='COLLECTOR' AND p.module_code IN ('DASHBOARD','COLLECTION','RESIDENTS','FLATS'))
 OR (r.role_code='SECURITY' AND p.module_code IN ('DASHBOARD','VISITORS'))
 OR (r.role_code='RESIDENT' AND p.module_code IN ('DASHBOARD','COMPLAINTS','VISITORS','PARKING'))
ON CONFLICT DO NOTHING;
CREATE OR REPLACE FUNCTION fn_create_super_admin(p_login varchar,p_display_name varchar,p_password varchar)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_user_id bigint;
BEGIN
 INSERT INTO m_user(society_id,login_name,display_name,password_hash,role_code,is_active)
 VALUES(NULL,p_login,p_display_name,crypt(p_password,gen_salt('bf',12)),'SUPER_ADMIN',true)
 ON CONFLICT(login_name) DO UPDATE
 SET display_name=excluded.display_name,password_hash=excluded.password_hash,
     role_code='SUPER_ADMIN',is_active=true
 RETURNING user_id INTO v_user_id;
 INSERT INTO m_user_role(user_id,role_id)
 SELECT v_user_id,role_id FROM m_role WHERE role_code='SUPER_ADMIN'
 ON CONFLICT DO NOTHING;
 RETURN v_user_id;
END; $$;

CREATE OR REPLACE FUNCTION fn_authenticate_user(p_login varchar,p_password varchar)
RETURNS TABLE(user_id bigint,login_name varchar,display_name varchar,role_code varchar,preferred_language varchar)
LANGUAGE sql AS $$
SELECT u.user_id,u.login_name,u.display_name,
 COALESCE((SELECT r.role_code FROM m_user_role ur JOIN m_role r ON r.role_id=ur.role_id
 WHERE ur.user_id=u.user_id AND r.is_active ORDER BY r.is_system DESC,r.role_id LIMIT 1),u.role_code),
 u.preferred_language
FROM m_user u WHERE lower(u.login_name)=lower(p_login) AND u.is_active
 AND u.password_hash IS NOT NULL AND u.password_hash=crypt(p_password,u.password_hash);
$$;

CREATE OR REPLACE FUNCTION fn_user_societies(p_user_id bigint)RETURNS TABLE(society_id bigint,society_code varchar,society_name varchar,is_default boolean)
LANGUAGE sql AS $$
SELECT s.society_id,s.society_code,s.society_name,us.is_default
FROM m_user_society us JOIN m_society s ON s.society_id=us.society_id
WHERE us.user_id=p_user_id AND s.is_active ORDER BY us.is_default DESC,s.society_name;
$$;

CREATE OR REPLACE FUNCTION fn_user_permissions(p_user_id bigint)
RETURNS TABLE(module_code varchar,action_code varchar)
LANGUAGE sql AS $$
SELECT DISTINCT p.module_code,p.action_code
FROM m_user_role ur JOIN m_role r ON r.role_id=ur.role_id AND r.is_active
JOIN m_role_permission rp ON rp.role_id=r.role_id
JOIN m_permission p ON p.permission_id=rp.permission_id AND p.is_active
WHERE ur.user_id=p_user_id ORDER BY p.module_code,p.action_code;
$$;

CREATE OR REPLACE FUNCTION fn_create_session(p_user_id bigint,p_token_hash text,p_society_id bigint,p_expires_at timestamptz)
RETURNS uuid LANGUAGE sql AS $$
INSERT INTO t_user_session(user_id,token_hash,society_id,expires_at)
VALUES(p_user_id,p_token_hash,p_society_id,p_expires_at) RETURNING session_id;
$$;

CREATE OR REPLACE FUNCTION fn_session_context(p_token_hash text)
RETURNS TABLE(session_id uuid,user_id bigint,society_id bigint,login_name varchar,display_name varchar,role_code varchar)
LANGUAGE sql AS $$
SELECT s.session_id,s.user_id,s.society_id,u.login_name,u.display_name,
 COALESCE((SELECT r.role_code FROM m_user_role ur JOIN m_role r ON r.role_id=ur.role_id WHERE ur.user_id=u.user_id AND r.is_active ORDER BY r.is_system DESC,r.role_id LIMIT 1),u.role_code)
FROM t_user_session s JOIN m_user u ON u.user_id=s.user_id
WHERE s.token_hash=p_token_hash AND s.revoked_at IS NULL AND s.expires_at>now() AND u.is_active;
$$;

CREATE OR REPLACE FUNCTION fn_revoke_session(p_token_hash text)
RETURNS void LANGUAGE sql AS $$
UPDATE t_user_session SET revoked_at=now() WHERE token_hash=p_token_hash;
$$;CREATE OR REPLACE FUNCTION fn_set_session_society(p_token_hash text,p_society_id bigint)
RETURNS boolean LANGUAGE plpgsql AS $$
DECLARE v_user_id bigint;
BEGIN
 SELECT user_id INTO v_user_id FROM t_user_session
 WHERE token_hash=p_token_hash AND revoked_at IS NULL AND expires_at>now();
 IF v_user_id IS NULL THEN RETURN false; END IF;
 IF NOT EXISTS(SELECT 1 FROM m_user_society WHERE user_id=v_user_id AND society_id=p_society_id) THEN
   RETURN false;
 END IF;
 UPDATE t_user_session SET society_id=p_society_id WHERE token_hash=p_token_hash;
 RETURN true;
END; $$;
