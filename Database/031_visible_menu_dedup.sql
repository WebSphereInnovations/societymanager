-- Consolidate duplicate visible security/audit menu entries.
UPDATE society_manager.m_module
SET visible=false,is_active=false
WHERE module_code IN ('SEC_GATE','SEC_VISITOR','SEC_VEHICLE','SUPER_AUDIT','AUDIT');