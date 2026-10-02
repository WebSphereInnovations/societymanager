[Reading 126 lines from start (total: 126 lines, 0 remaining)]

SET search_path TO society_manager, public;

ALTER TABLE m_module ADD COLUMN IF NOT EXISTS visible boolean NOT NULL DEFAULT true;
ALTER TABLE m_permission ADD COLUMN IF NOT EXISTS visible boolean NOT NULL DEFAULT true;

UPDATE m_module SET visible=true WHERE is_active;
UPDATE m_module SET visible=false WHERE NOT is_active;
UPDATE m_permission SET visible=true;

DROP FUNCTION IF EXISTS fn_user_module_menu(bigint);
CREATE FUNCTION fn_user_module_menu(p_user_id bigint)
RETURNS TABLE(module_code varchar,module_name varchar,parent_module_code varchar,display_order integer,visible boolean)
LANGUAGE sql AS $$
SELECT DISTINCT m.module_code,m.module_name,m.parent_module_code,m.display_order,m.visible
FROM m_module m
WHERE m.is_active AND m.visible
AND (
 EXISTS(SELECT 1 FROM fn_user_permissions(p_user_id) p WHERE p.module_code=m.module_code AND p.action_code='VIEW')
 OR EXISTS(
   SELECT 1 FROM m_module child
   WHERE child.parent_module_code=m.module_code AND child.is_active AND child.visible
   AND EXISTS(SELECT 1 FROM fn_user_permissions(p_user_id) p WHERE p.module_code=child.module_code AND p.action_code='VIEW')
 )
)
ORDER BY m.display_order,m.module_code;
$$;

CREATE OR REPLACE FUNCTION fn_admin_role_list(p_society_id bigint)
RETURNS TABLE(role_id bigint,role_code varchar,role_name varchar,description text,is_system boolean,is_active boolean,user_count bigint)
LANGUAGE sql AS $$
SELECT r.role_id,r.role_code,r.role_name,r.description,r.is_system,r.is_active,
       count(DISTINCT ur.user_id) FILTER (WHERE u.society_id=p_society_id)
FROM m_role r
LEFT JOIN m_user_role ur ON ur.role_id=r.role_id
LEFT JOIN m_user u ON u.user_id=ur.user_id
WHERE r.is_active OR r.role_code IN ('SUPER_ADMIN','SOCIETY_ADMIN')
GROUP BY r.role_id,r.role_code,r.role_name,r.description,r.is_system,r.is_active
ORDER BY r.is_system DESC,r.role_name;
$$;

CREATE OR REPLACE FUNCTION fn_admin_role_rights(p_role_id bigint)
RETURNS TABLE(module_code varchar,module_name varchar,parent_module_code varchar,display_order integer,action_code varchar,permission_id bigint,permission_name varchar,granted boolean,visible boolean)
LANGUAGE sql AS $$
SELECT m.module_code,m.module_name,m.parent_module_code,m.display_order,p.action_code,p.permission_id,p.permission_name,
       EXISTS(SELECT 1 FROM m_role_permission rp WHERE rp.role_id=p_role_id AND rp.permission_id=p.permission_id) granted,
       m.visible AND p.visible
FROM m_module m
JOIN m_permission p ON p.module_code=m.module_code AND p.is_active AND p.visible
WHERE m.is_active AND m.visible
ORDER BY m.display_order,m.module_code,p.action_code;
$$;

CREATE OR REPLACE PROCEDURE sp_admin_save_role(
 IN p_role_id bigint,IN p_role_code varchar,IN p_role_name varchar,IN p_description text,
 IN p_rights jsonb,IN p_modified_by bigint,IN p_remark text DEFAULT '',INOUT p_saved_role_id bigint DEFAULT NULL)
LANGUAGE plpgsql AS $$
DECLARE v_code varchar:=upper(trim(p_role_code));
BEGIN
 IF length(v_code)<2 OR length(trim(p_role_name))<2 THEN RAISE EXCEPTION 'Role code and role name are required'; END IF;
 IF COALESCE(p_role_id,0)=0 THEN
   IF EXISTS(SELECT 1 FROM m_role WHERE upper(role_code)=v_code) THEN RAISE EXCEPTION 'Role code already exists'; END IF;
   INSERT INTO m_role(role_code,role_name,description,is_system,is_active,created_by,modified_by,modified_at,modify_remark)
   VALUES(v_code,trim(p_role_name),NULLIF(trim(p_description),''),false,true,p_modified_by,p_modified_by,now(),COALESCE(p_remark,''))
   RETURNING role_id INTO p_saved_role_id;
 ELSE
   IF EXISTS(SELECT 1 FROM m_role WHERE role_id=p_role_id AND is_system) THEN RAISE EXCEPTION 'System role is protected and cannot be changed here'; END IF;
   UPDATE m_role SET role_name=trim(p_role_name),description=NULLIF(trim(p_description),''),
     modified_by=p_modified_by,modified_at=now(),modify_remark=COALESCE(p_remark,'')
   WHERE role_id=p_role_id;
   IF NOT FOUND THEN RAISE EXCEPTION 'Role not found'; END IF;
   p_saved_role_id:=p_role_id;
 END IF;
 DELETE FROM m_role_permission WHERE role_id=p_saved_role_id;
 INSERT INTO m_role_permission(role_id,permission_id,created_by,modified_by,modified_at,modify_remark)
 SELECT p_saved_role_id,p.permission_id,p_modified_by,p_modified_by,now(),COALESCE(p_remark,'')
 FROM jsonb_to_recordset(COALESCE(p_rights,'[]'::jsonb)) x(module_code varchar,action_code varchar,granted boolean)
 JOIN m_permission p ON p.module_code=x.module_code AND p.action_code=x.action_code AND p.is_active AND p.visible
 WHERE COALESCE(x.granted,true);
END $$;

CREATE OR REPLACE FUNCTION fn_admin_menu_list()
RETURNS TABLE(module_id bigint,module_code varchar,module_name varchar,parent_module_code varchar,display_order integer,visible boolean,is_active boolean,child_count bigint,permission_count bigint)
LANGUAGE sql AS $$
SELECT m.module_id,m.module_code,m.module_name,m.parent_module_code,m.display_order,m.visible,m.is_active,
       (SELECT count(*) FROM m_module c WHERE c.parent_module_code=m.module_code),
       (SELECT count(*) FROM m_permission p WHERE p.module_code=m.module_code AND p.is_active)
FROM m_module m
ORDER BY m.parent_module_code NULLS FIRST,m.display_order,m.module_code;
$$;

CREATE OR REPLACE PROCEDURE sp_admin_save_menu(
 IN p_module_id bigint,IN p_module_code varchar,IN p_module_name varchar,IN p_parent_module_code varchar,
 IN p_display_order integer,IN p_visible boolean,IN p_modified_by bigint,IN p_remark text DEFAULT '',INOUT p_saved_module_id bigint DEFAULT NULL)
LANGUAGE plpgsql AS $$
DECLARE v_code varchar:=upper(trim(p_module_code));
BEGIN
 IF length(v_code)<2 OR length(trim(p_module_name))<2 THEN RAISE EXCEPTION 'Menu code and menu name are required'; END IF;
 IF p_parent_module_code IS NOT NULL AND trim(p_parent_module_code)<>'' AND NOT EXISTS(
   SELECT 1 FROM m_module WHERE module_code=upper(trim(p_parent_module_code)) AND is_active
 ) THEN RAISE EXCEPTION 'Selected parent menu does not exist'; END IF;
 IF COALESCE(p_module_id,0)=0 THEN
   IF EXISTS(SELECT 1 FROM m_module WHERE upper(module_code)=v_code) THEN RAISE EXCEPTION 'Menu code already exists'; END IF;
   INSERT INTO m_module(module_code,module_name,parent_module_code,display_order,is_active,visible,created_by,modified_by,modified_at,modify_remark)
   VALUES(v_code,trim(p_module_name),NULLIF(upper(trim(p_parent_module_code)),''),COALESCE(p_display_order,100),true,COALESCE(p_visible,true),p_modified_by,p_modified_by,now(),COALESCE(p_remark,''))
   RETURNING module_id INTO p_saved_module_id;
 ELSE
   UPDATE m_module SET module_name=trim(p_module_name),parent_module_code=NULLIF(upper(trim(p_parent_module_code)),''),display_order=COALESCE(p_display_order,100),
     visible=COALESCE(p_visible,true),modified_by=p_modified_by,modified_at=now(),modify_remark=COALESCE(p_remark,'')
   WHERE module_id=p_module_id;
   IF NOT FOUND THEN RAISE EXCEPTION 'Menu not found'; END IF;
   p_saved_module_id:=p_module_id;
 END IF;
 INSERT INTO m_permission(module_code,action_code,permission_name,is_active,visible,created_by,modified_by,modified_at,modify_remark)
 SELECT v_code,a,initcap(lower(a))||' '||trim(p_module_name),true,true,p_modified_by,p_modified_by,now(),COALESCE(p_remark,'')
 FROM (VALUES('VIEW'),('ADD'),('EDIT'),('DELETE'),('APPROVE'),('POST'),('CANCEL'),('PRINT'),('EXPORT'),('ASSIGN'),('IMPORT'),('REFUND')) z(a)
 ON CONFLICT(module_code,action_code) DO UPDATE SET permission_name=excluded.permission_name,is_active=true,visible=excluded.visible,modified_by=p_modified_by,modified_at=now(),modify_remark=COALESCE(p_remark,'');
END $$;

CREATE OR REPLACE PROCEDURE sp_admin_set_menu_visibility(
 IN p_module_id bigint,IN p_visible boolean,IN p_modified_by bigint,IN p_remark text DEFAULT '')
LANGUAGE plpgsql AS $$
BEGIN
 UPDATE m_module SET visible=p_visible,modified_by=p_modified_by,modified_at=now(),modify_remark=COALESCE(p_remark,'')
 WHERE module_id=p_module_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Menu not found'; END IF;
END $$;

[executed on device: Sandman (3c28f028-a467-4934-be2f-752a8db6b6a8)]