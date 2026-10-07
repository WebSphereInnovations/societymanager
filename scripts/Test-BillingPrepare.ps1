$ErrorActionPreference='Stop'
$cs=[Environment]::GetEnvironmentVariable('SOCIETY360_DB_CONNECTION','User');$m=[regex]::Match($cs,'(?i)(?:^|;)Password=([^;]*)');$env:PGPASSWORD=$m.Groups[1].Value
try {
 & 'C:\Program Files\PostgreSQL\18\bin\psql.exe' -h 127.0.0.1 -p 5432 -U society_manager -d society_manager -v ON_ERROR_STOP=1 -c "select society_manager.sp_billing_prepare(1,1) as billing_run_id;"
 & 'C:\Program Files\PostgreSQL\18\bin\psql.exe' -h 127.0.0.1 -p 5432 -U society_manager -d society_manager -v ON_ERROR_STOP=1 -c "select customer_name,customer_number,flat_no,billing_month,maintenance_amount,sinking_fund_amount,parking_amount,other_charge_amount,arrear_amount,interest_arrear_amount,total_amount,payment_amount,balance_amount from society_manager.fn_billing_preview(1,(select max(billing_run_id) from society_manager.t_billing_run where society_id=1));"
} finally {Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue}