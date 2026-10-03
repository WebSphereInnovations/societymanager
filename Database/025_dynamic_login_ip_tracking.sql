SET search_path TO society_manager, public;

ALTER TABLE m_user ADD COLUMN IF NOT EXISTS last_login_ip inet;

CREATE OR REPLACE PROCEDURE sp_record_login_success(
 IN p_user_id bigint,IN p_society_id bigint,IN p_login varchar,IN p_ip varchar,IN p_user_agent varchar,IN p_session_id uuid)
LANGUAGE plpgsql AS $$
DECLARE v_count bigint:=0;
BEGIN
 IF p_user_id IS NULL OR NOT EXISTS(SELECT 1 FROM m_user WHERE user_id=p_user_id) THEN
   RAISE EXCEPTION 'User not found';
 END IF;
 CALL sp_record_login(p_user_id,p_login,NULLIF(trim(p_ip),'')::inet,p_user_agent,'SUCCESS',NULL,p_session_id::text,v_count);
 UPDATE m_user
 SET last_login_ip=NULLIF(trim(p_ip),'')::inet,
     last_login_at=now(),
     modified_by=p_user_id,
     modified_at=now(),
     modify_remark=''
 WHERE user_id=p_user_id;
END $$;

DROP FUNCTION IF EXISTS fn_login_security_overview(bigint);

CREATE FUNCTION fn_login_security_overview(p_society_id bigint)
RETURNS TABLE(
 user_id bigint,login_name varchar,display_name varchar,last_login_ip inet,last_login_at timestamptz,
 login_count bigint,last_user_agent varchar,last_login_status varchar,is_active boolean)
LANGUAGE sql AS $$
SELECT u.user_id,u.login_name,u.display_name,
       COALESCE(a.last_login_ip,u.last_login_ip),
       COALESCE(a.last_login_at,u.last_login_at),
       COALESCE(a.login_count,0),
       a.last_user_agent,a.last_login_status,u.is_active
FROM m_user u
LEFT JOIN t_user_login_audit a ON a.user_id=u.user_id
WHERE u.society_id=p_society_id
  AND u.role_code NOT IN ('SUPER_ADMIN','RESIDENT')
ORDER BY COALESCE(a.last_login_at,u.last_login_at) DESC NULLS LAST,u.display_name,u.user_id;
$$;

CREATE OR REPLACE PROCEDURE sp_user_login_audit(
 IN p_user_id bigint,
 INOUT p_cursor refcursor DEFAULT 'login_audit_cursor')
LANGUAGE plpgsql AS $$
BEGIN
 OPEN p_cursor FOR
 SELECT a.user_id,u.login_name,u.display_name,
        COALESCE(a.last_login_ip,u.last_login_ip) AS last_login_ip,
        COALESCE(a.last_login_at,u.last_login_at) AS last_login_at,
        a.login_count,a.last_user_agent,a.last_login_status
 FROM t_user_login_audit a
 JOIN m_user u ON u.user_id=a.user_id
 WHERE a.user_id=p_user_id;
END $$;
