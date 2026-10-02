SET search_path TO society_manager, public;

UPDATE m_module
SET is_active=false
WHERE module_code IN (
'METER_MANAGEMENT','MTR_MASTER','MTR_ASSIGN','MTR_REPLACEMENT','MTR_TEST','MTR_HISTORY',
'WATER_DISTRIBUTION','WATER_CONSUMPTION','WATER_TANK','WATER_SCHEDULE','WATER_ZONE',
'RECOVERY_MANAGEMENT','RECOVERY_DUE','RECOVERY_DISCON','RECOVERY_RECON','RECOVERY_TRACKER',
'CONNECTION_MANAGEMENT','CONN_APPLICATION','CONN_SERVICE','CONN_TRANSFER','CONN_DISCON_RECON','CONN_HISTORY',
'DEVICE_AUTH','DEV_REGISTER','DEV_ASSIGN','DEV_AUTH','DEV_STATUS','MIS_METER','DASH_RTS'
);

UPDATE m_module
SET is_active=false
WHERE module_code IN (
'ADM_CONTRACTOR','ADM_EMPLOYEE','ADM_ROLE_MASTER','ADM_CUSTOMER_COUNTS',
'ADM_SMS_CONFIG','ADM_MASTER_DATA','ADM_COLLECTION_CONFIG','ADM_SEND_SMS'
);

CREATE OR REPLACE FUNCTION fn_user_permissions(p_user_id bigint)
RETURNS TABLE(module_code varchar,action_code varchar)
LANGUAGE sql AS $$
SELECT DISTINCT p.module_code,p.action_code
FROM m_permission p
JOIN m_module m ON m.module_code=p.module_code AND m.is_active
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
JOIN m_module m ON m.module_code=p.module_code AND m.is_active
WHERE u.user_id=p_user_id
  AND NOT u.user_permission_configured
  AND (u.valid_from IS NULL OR u.valid_from<=current_date)
  AND (u.valid_to IS NULL OR u.valid_to>=current_date)
ORDER BY 1,2;
$$;