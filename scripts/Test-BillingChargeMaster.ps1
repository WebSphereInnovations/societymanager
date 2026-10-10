$ErrorActionPreference='Stop'
$cs=[Environment]::GetEnvironmentVariable('SOCIETY360_DB_CONNECTION','User')
$m=[regex]::Match($cs,'(?i)(?:^|;)Password=([^;]*)')
$env:PGPASSWORD=$m.Groups[1].Value
try {
 & 'C:\Program Files\PostgreSQL\18\bin\psql.exe' -h 127.0.0.1 -p 5432 -U society_manager -d society_manager -v ON_ERROR_STOP=1 -f 'C:\Users\Delta\Society360\scripts\billing-charge-master-test.sql'
 if($LASTEXITCODE -ne 0){throw 'Charge master binding test failed.'}
} finally {Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue}
