BEGIN;
SELECT society_manager.sp_billing_save_rate(
  1,0,
  (SELECT billing_property_type_id FROM society_manager.m_billing_property_type WHERE society_id=1 ORDER BY billing_property_type_id LIMIT 1),
  (SELECT charge_type_id FROM society_manager.m_charge_type WHERE society_id=1 AND charge_code='MAINT' AND is_active LIMIT 1),
  'PER_FLAT',123.45,current_date,NULL,NULL,'charge master test'
);
SELECT charge_type_id,charge_code,charge_name,rate
FROM society_manager.m_billing_rate
WHERE society_id=1 AND rate=123.45;
ROLLBACK;
