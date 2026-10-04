SET search_path TO society_manager, public;

-- Customer Account has one visible source of truth under Customer Relationship Management.
UPDATE m_module
SET module_name='Customer Relationship Management', visible=true, is_active=true
WHERE module_code='CRM';

-- Retire the older CRM/customer-account menu implementations. Keep records for historical references/FKs.
UPDATE m_module
SET visible=false, is_active=false
WHERE module_code IN (
  'CRM_CUSTOMER_SEARCH','CRM_CUSTOMER_360','CRM_INTERACTION','CRM_COMPLAINT','CRM_SERVICE_REQUEST'
);

-- The only active Customer Account entry is the dedicated Consumer 360 implementation.
UPDATE m_module
SET module_name='Customer Account', parent_module_code='CRM', display_order=82, visible=true, is_active=true
WHERE module_code='CRM_CUSTOMER_ACCOUNT';

-- Keep Customer Interaction only if it is an existing visible workflow; it is not a second Customer Account.
UPDATE m_module
SET module_name='Customer Interaction', parent_module_code='CRM', display_order=83, visible=true, is_active=true
WHERE module_code='CRM_CUSTOMER_INTERACTION';

-- Retire permissions belonging only to the removed CRM implementations.
UPDATE m_permission
SET visible=false, is_active=false
WHERE module_code IN (
  'CRM_CUSTOMER_SEARCH','CRM_CUSTOMER_360','CRM_INTERACTION','CRM_COMPLAINT','CRM_SERVICE_REQUEST'
);

-- The dedicated Customer Account permission is the single authorization key for Consumer 360.
INSERT INTO m_permission(module_code,action_code,permission_name,is_active,visible)
SELECT 'CRM_CUSTOMER_ACCOUNT',a.code,'Customer Account - '||a.code,true,true
FROM (VALUES('VIEW'),('ADD'),('EDIT'),('DELETE'),('APPROVE'),('POST'),('PRINT'),('EXPORT')) a(code)
ON CONFLICT(module_code,action_code)
DO UPDATE SET is_active=true,visible=true,permission_name=excluded.permission_name;

-- Society Admin/Super Admin can open the Customer Account; Cashier may open it for collection work.
INSERT INTO m_role_permission(role_id,permission_id)
SELECT r.role_id,p.permission_id
FROM m_role r
JOIN m_permission p ON p.module_code='CRM_CUSTOMER_ACCOUNT' AND p.action_code='VIEW' AND p.is_active
WHERE r.role_code IN ('SOCIETY_ADMIN','SUPER_ADMIN','CASHIER')
ON CONFLICT DO NOTHING;

-- Retire duplicate role grants for the removed Customer 360/search permissions.
DELETE FROM m_role_permission rp
USING m_permission p
WHERE rp.permission_id=p.permission_id
  AND p.module_code IN ('CRM_CUSTOMER_SEARCH','CRM_CUSTOMER_360','CRM_INTERACTION','CRM_COMPLAINT','CRM_SERVICE_REQUEST');

-- Remove obsolete duplicate menu permissions from the catalog where safe.
UPDATE m_module
SET visible=false, is_active=false
WHERE module_code IN ('CRM_CUSTOMER_SEARCH','CRM_CUSTOMER_360');

-- Remove obsolete backend/database entry points that belonged only to the retired duplicate account implementations.
DROP FUNCTION IF EXISTS fn_society360_consumer_search(bigint, varchar);
DROP FUNCTION IF EXISTS fn_society360_consumer_account(bigint, bigint);
DROP FUNCTION IF EXISTS fn_society_admin_customer_account(bigint, bigint);
DROP FUNCTION IF EXISTS fn_society_admin_account_statement(bigint, bigint);
DROP FUNCTION IF EXISTS fn_consumer_account(bigint, bigint);
