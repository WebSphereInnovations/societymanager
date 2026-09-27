$cs=[Environment]::GetEnvironmentVariable('SOCIETY360_DB_CONNECTION','User')
$match=[regex]::Match($cs,'(?i)(?:^|;)Password=([^;]*)')
if(-not $match.Success){throw 'Password not found in configured connection string'}
$env:PGPASSWORD=$match.Groups[1].Value
try {
 & 'C:\Program Files\PostgreSQL\18\bin\psql.exe' -h 192.168.1.11 -p 5432 -U society_manager -d society_manager -v ON_ERROR_STOP=1 -c "select (select count(*) from society_manager.m_society) as societies,(select count(*) from society_manager.m_flat) as flats,(select count(*) from society_manager.m_customer) as customers,(select count(*) from society_manager.t_bill) as bills,(select count(*) from society_manager.t_payment) as payments,(select count(*) from society_manager.m_role) as roles,(select count(*) from society_manager.m_permission) as permissions;"
 & 'C:\Program Files\PostgreSQL\18\bin\psql.exe' -h 192.168.1.11 -p 5432 -U society_manager -d society_manager -v ON_ERROR_STOP=1 -c "select society_code,society_name from society_manager.m_society order by society_id;"
} finally {Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue}