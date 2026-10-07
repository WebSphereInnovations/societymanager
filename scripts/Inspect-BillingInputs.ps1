$ErrorActionPreference='Stop'
$cs=[Environment]::GetEnvironmentVariable('SOCIETY360_DB_CONNECTION','User');$m=[regex]::Match($cs,'(?i)(?:^|;)Password=([^;]*)');$env:PGPASSWORD=$m.Groups[1].Value
try {
 & 'C:\Program Files\PostgreSQL\18\bin\psql.exe' -h 127.0.0.1 -p 5432 -U society_manager -d society_manager -v ON_ERROR_STOP=1 -c "select * from society_manager.fn_society_charge_rules(1);"
 & 'C:\Program Files\PostgreSQL\18\bin\psql.exe' -h 127.0.0.1 -p 5432 -U society_manager -d society_manager -v ON_ERROR_STOP=1 -c "select c.consumer_id,c.customer_id,c.full_name,f.flat_no,f.unit_type,f.area_sqft from society_manager.m_customer c join society_manager.m_customer_flat cf on cf.society_id=c.society_id and cf.customer_id=c.customer_id and cf.is_primary join society_manager.m_flat f on f.society_id=c.society_id and f.flat_id=cf.flat_id where c.society_id=1 and c.is_active order by c.customer_id limit 10;"
} finally {Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue}