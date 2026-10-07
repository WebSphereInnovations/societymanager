$ErrorActionPreference='Stop'
$cs=[Environment]::GetEnvironmentVariable('SOCIETY360_DB_CONNECTION','User');$m=[regex]::Match($cs,'(?i)(?:^|;)Password=([^;]*)');$env:PGPASSWORD=$m.Groups[1].Value
try {
 $sql=@"
BEGIN;
INSERT INTO society_manager.m_billing_arrear(society_id,consumer_id,customer_id,flat_id,bill_month,raw_arrear,calculated_arrear,raw_interest,calculated_interest,modify_by,modify_remark)
VALUES
(1,11,11,(select flat_id from society_manager.m_customer_flat where society_id=1 and customer_id=11 and is_primary limit 1),'202601',1000,1000,20,20,1,'Billing allocation test'),
(1,11,11,(select flat_id from society_manager.m_customer_flat where society_id=1 and customer_id=11 and is_primary limit 1),'202602',800,800,15,15,1,'Billing allocation test')
ON CONFLICT(society_id,consumer_id,bill_month) DO UPDATE SET raw_arrear=excluded.raw_arrear,calculated_arrear=excluded.calculated_arrear,raw_interest=excluded.raw_interest,calculated_interest=excluded.calculated_interest;
INSERT INTO society_manager.t_payment(society_id,customer_id,flat_id,payment_no,payment_date,amount,payment_mode,status,created_by,consumer_id,modify_remark)
VALUES(1,11,(select flat_id from society_manager.m_customer_flat where society_id=1 and customer_id=11 and is_primary limit 1),'BILLING-TEST-20261007-C11',now(),1010,'TEST','Success',1,11,'Billing allocation test');
SELECT society_manager.sp_billing_prepare(1,1) as run_id;
SELECT billing_month,interest_adjusted,arrear_adjusted,adjustment_total,allocation_order FROM society_manager.t_billing_payment_adjustment WHERE billing_run_id=1 AND consumer_id=11 ORDER BY allocation_order,billing_month;
SELECT raw_arrear,calculated_arrear,raw_interest,calculated_interest FROM society_manager.m_billing_arrear WHERE society_id=1 AND consumer_id=11 ORDER BY bill_month;
SELECT arrear_amount,interest_arrear_amount,payment_amount,balance_amount FROM society_manager.t_billing_run_detail WHERE billing_run_id=1 AND consumer_id=11;
ROLLBACK;
"@;
 & 'C:\Program Files\PostgreSQL\18\bin\psql.exe' -h 127.0.0.1 -p 5432 -U society_manager -d society_manager -v ON_ERROR_STOP=1 -c $sql
} finally {Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue}