$ErrorActionPreference='Stop'
$cs=[Environment]::GetEnvironmentVariable('SOCIETY360_DB_CONNECTION','User');$m=[regex]::Match($cs,'(?i)(?:^|;)Password=([^;]*)');$env:PGPASSWORD=$m.Groups[1].Value
try {
 & 'C:\Program Files\PostgreSQL\18\bin\psql.exe' -h 127.0.0.1 -p 5432 -U society_manager -d society_manager -v ON_ERROR_STOP=1 -c "select table_name,column_name,data_type from information_schema.columns where table_schema='society_manager' and table_name in ('m_billing_config','t_billing_config_history','m_billing_property_type','m_billing_rate','m_billing_arrear','t_billing_run','t_billing_run_detail','t_billing_payment_adjustment') order by table_name,ordinal_position;"
} finally {Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue}