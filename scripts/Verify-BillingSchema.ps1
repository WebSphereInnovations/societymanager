$ErrorActionPreference='Stop'
$cs=[Environment]::GetEnvironmentVariable('SOCIETY360_DB_CONNECTION','User');$m=[regex]::Match($cs,'(?i)(?:^|;)Password=([^;]*)');$env:PGPASSWORD=$m.Groups[1].Value
try {
 & 'C:\Program Files\PostgreSQL\18\bin\psql.exe' -h 127.0.0.1 -p 5432 -U society_manager -d society_manager -v ON_ERROR_STOP=1 -c "select society_id,society_code,society_name from society_manager.m_society order by society_id;"
 & 'C:\Program Files\PostgreSQL\18\bin\psql.exe' -h 127.0.0.1 -p 5432 -U society_manager -d society_manager -v ON_ERROR_STOP=1 -c "select * from society_manager.fn_billing_frequencies();"
 & 'C:\Program Files\PostgreSQL\18\bin\psql.exe' -h 127.0.0.1 -p 5432 -U society_manager -d society_manager -v ON_ERROR_STOP=1 -c "select * from society_manager.fn_billing_get_configuration(1);"
 & 'C:\Program Files\PostgreSQL\18\bin\psql.exe' -h 127.0.0.1 -p 5432 -U society_manager -d society_manager -v ON_ERROR_STOP=1 -c "select society_manager.fn_billing_get_next_month(1) as next_month;"
 & 'C:\Program Files\PostgreSQL\18\bin\psql.exe' -h 127.0.0.1 -p 5432 -U society_manager -d society_manager -v ON_ERROR_STOP=1 -c "select count(*) as missing_rates from society_manager.fn_billing_required_rates_missing(1);"
 & 'C:\Program Files\PostgreSQL\18\bin\psql.exe' -h 127.0.0.1 -p 5432 -U society_manager -d society_manager -v ON_ERROR_STOP=1 -c "select table_name from information_schema.tables where table_schema='society_manager' and table_name like '%billing%' order by table_name;"
} finally {Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue}