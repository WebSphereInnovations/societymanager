$ErrorActionPreference='Stop'
$cs=[Environment]::GetEnvironmentVariable('SOCIETY360_DB_CONNECTION','User');$m=[regex]::Match($cs,'(?i)(?:^|;)Password=([^;]*)');$env:PGPASSWORD=$m.Groups[1].Value
try {
 & 'C:\Program Files\PostgreSQL\18\bin\psql.exe' -h 127.0.0.1 -p 5432 -U society_manager -d society_manager -v ON_ERROR_STOP=1 -c "select * from society_manager.fn_billing_required_rates_missing(1);"
 & 'C:\Program Files\PostgreSQL\18\bin\psql.exe' -h 127.0.0.1 -p 5432 -U society_manager -d society_manager -v ON_ERROR_STOP=1 -c "select property_type_name,charge_code,rate_type,rate,effective_from from society_manager.fn_billing_rates(1) order by property_type_name,charge_code;"
} finally {Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue}