-- Rollback for 051_skyfy_nexus_theme_entitlements.sql.
-- Use only when SKYFY theme preferences/entitlements are no longer in use.
SET search_path TO society_manager, public;

DELETE FROM society_manager.m_role_permission rp
USING society_manager.m_permission p
WHERE p.permission_id=rp.permission_id
  AND p.module_code='THEME_PREFERENCES';

DELETE FROM society_manager.m_user_permission up
USING society_manager.m_permission p
WHERE p.permission_id=up.permission_id
  AND p.module_code='THEME_PREFERENCES';

DELETE FROM society_manager.m_permission
WHERE module_code='THEME_PREFERENCES';

DELETE FROM society_manager.m_module
WHERE module_code='THEME_PREFERENCES';

-- Dropping the tables first removes their dependent triggers.
DROP TABLE IF EXISTS society_manager.t_user_theme_preference;
DROP TABLE IF EXISTS society_manager.t_society_theme_entitlement;
DROP TABLE IF EXISTS society_manager.m_theme_configuration;
DROP TABLE IF EXISTS society_manager.m_theme;

DROP FUNCTION IF EXISTS society_manager.fn_skyfy_theme_is_entitled(bigint, varchar);
DROP FUNCTION IF EXISTS society_manager.fn_skyfy_theme_validate_entitlement();
DROP FUNCTION IF EXISTS society_manager.fn_skyfy_theme_audit();
DROP FUNCTION IF EXISTS society_manager.fn_skyfy_theme_stamp();
