$ErrorActionPreference='Stop'
$env:SOCIETY360_DB_CONNECTION=[Environment]::GetEnvironmentVariable('SOCIETY360_DB_CONNECTION','User')
Set-Location 'C:\Users\Delta\Society360'
& 'C:\Users\Delta\.dotnet\dotnet.exe' run --no-launch-profile --no-build -- --apply-module-catalog
