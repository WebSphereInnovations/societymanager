$ErrorActionPreference='Stop'
$cs=[Environment]::GetEnvironmentVariable('SOCIETY360_DB_CONNECTION','User')
$m=[regex]::Match($cs,'(?i)(?:^|;)Password=([^;]*)')
$env:PGPASSWORD=$m.Groups[1].Value
try {
 & 'C:\Program Files\PostgreSQL\18\bin\psql.exe' -h 127.0.0.1 -p 5432 -U society_manager -d society_manager -v ON_ERROR_STOP=1 -f 'C:\Users\Delta\Society360\Database\037_billing_hardening.sql'
 if($LASTEXITCODE -ne 0){throw "Billing hardening deployment failed."}
 Write-Output 'BILLING_HARDENING_APPLIED'
} finally {Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue}
