SET search_path TO society_manager, public;

CREATE OR REPLACE FUNCTION fn_provision_new_society_admin(p_society_code varchar,p_login_base varchar)
RETURNS TABLE(login_name varchar,generated_password varchar,society_name varchar)
LANGUAGE plpgsql AS $$
DECLARE
 v_society_id bigint;
 v_society_name varchar;
 v_login varchar:=lower(regexp_replace(trim(p_login_base),'[^a-z0-9._-]','','g'));
 v_password varchar:=substr(encode(gen_random_bytes(12),'base64'),1,16);
 v_suffix integer:=1;
 v_user_id bigint;
BEGIN
 SELECT s.society_id,s.society_name INTO v_society_id,v_society_name
 FROM m_society s WHERE upper(s.society_code)=upper(trim(p_society_code)) AND s.is_active;
 IF v_society_id IS NULL THEN RAISE EXCEPTION 'Society not found'; END IF;
 IF length(v_login)<4 THEN RAISE EXCEPTION 'Login base is too short'; END IF;

 WHILE EXISTS(SELECT 1 FROM m_user u WHERE lower(u.login_name)=v_login) LOOP
   v_suffix:=v_suffix+1;
   v_login:=left(lower(regexp_replace(trim(p_login_base),'[^a-z0-9._-]','','g')),90-length(v_suffix::text))||v_suffix::text;
 END LOOP;

 INSERT INTO m_user(society_id,login_name,display_name,password_hash,role_code,is_active)
 VALUES(v_society_id,v_login,'Society Admin',crypt(v_password,gen_salt('bf',12)),'SOCIETY_ADMIN',true)
 RETURNING user_id INTO v_user_id;

 INSERT INTO m_user_role(user_id,role_id)
 SELECT v_user_id,role_id FROM m_role WHERE role_code='SOCIETY_ADMIN'
 ON CONFLICT DO NOTHING;

 INSERT INTO m_user_society(user_id,society_id,is_default)
 VALUES(v_user_id,v_society_id,true)
 ON CONFLICT(user_id,society_id) DO UPDATE SET is_default=true;

 PERFORM fn_log_audit(v_society_id,v_user_id,'m_user',v_user_id,'CREATE',NULL,
   jsonb_build_object('source','admin_provisioning','role','SOCIETY_ADMIN'));

 RETURN QUERY SELECT v_login,v_password,v_society_name;
END;
$$;