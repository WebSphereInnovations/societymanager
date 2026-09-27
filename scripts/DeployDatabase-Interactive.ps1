$ErrorActionPreference='Stop'
$ProjectRoot='C:\Users\Delta\Society360'
$Psql='C:\Program Files\PostgreSQL\18\bin\psql.exe'
Write-Host 'READY_DB_PASSWORD'
$Password=[Console]::ReadLine()
Write-Host 'READY_ADMIN_PASSWORD'
$AdminPassword=[Console]::ReadLine()
$pgpass=Join-Path $env:TEMP ('society360-'+[guid]::NewGuid().ToString('N')+'.conf')
try {
  '192.168.1.11:5432:society_manager:society_manager:'+$Password | Set-Content $pgpass -Encoding ascii -NoNewline
  $env:PGPASSFILE=$pgpass
  foreach($f in @('001_society360_foundation.sql','002_core_functions.sql','003_multilingual.sql','005_complete_demo.sql','004_security_auth.sql')){
    Write-Host ('RUN '+$f)
    & $Psql -h 192.168.1.11 -p 5432 -U society_manager -d society_manager -v ON_ERROR_STOP=1 -f (Join-Path $ProjectRoot ('Database\'+$f))
    if($LASTEXITCODE -ne 0){throw ('Failed '+$f)}
  }
  Write-Host 'RUN SUPER ADMIN'
  $env:PGPASSWORD=$Password
  & $Psql -h 192.168.1.11 -p 5432 -U society_manager -d society_manager -v ON_ERROR_STOP=1 -c ("select society_manager.fn_create_super_admin('Rahul','Rahul','" + $AdminPassword.Replace("'","''") + "');")
  if($LASTEXITCODE -ne 0){throw 'Failed Super Admin'}
  $conn='Host=192.168.1.11;Port=5432;Database=society_manager;Username=society_manager;Password='+$Password+';Search Path=society_manager;'
  [Environment]::SetEnvironmentVariable('SOCIETY360_DB_CONNECTION',$conn,'User')
  Write-Host 'DATABASE_DEPLOYMENT_SUCCESS'
} finally {
  Remove-Item Env:PGPASSFILE -ErrorAction SilentlyContinue
  Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
  if(Test-Path $pgpass){Remove-Item $pgpass -Force}
  $Password=$null;$AdminPassword=$null
}