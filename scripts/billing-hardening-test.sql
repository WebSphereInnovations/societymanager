BEGIN;
UPDATE society_manager.m_billing_config SET dpc_applicable=true,dpc_apply_on='ARREAR_AND_INTEREST',dpc_rate=2 WHERE billing_config_id=1;
INSERT INTO society_manager.m_billing_arrear(society_id,consumer_id,customer_id,flat_id,bill_month,raw_arrear,calculated_arrear,raw_interest,calculated_interest,modify_by,modify_remark)
VALUES(1,11,11,(select flat_id from society_manager.m_customer_flat where society_id=1 and customer_id=11 and is_primary limit 1),'202607',1000,1000,20,20,1,'Hardening DPC test')
ON CONFLICT(society_id,consumer_id,bill_month) DO UPDATE SET raw_arrear=1000,calculated_arrear=1000,raw_interest=20,calculated_interest=20;
SELECT society_manager.sp_billing_prepare(1,1) AS run_id;
SELECT customer_name,other_charge_amount,arrear_amount,interest_arrear_amount,total_amount,last_payment_amount,last_payment_date
FROM society_manager.fn_billing_preview(1,(SELECT max(billing_run_id) FROM society_manager.t_billing_run WHERE society_id=1))
WHERE consumer_id=11;
ROLLBACK;