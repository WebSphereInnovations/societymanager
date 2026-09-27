$ErrorActionPreference='Stop'
$env:SOCIETY360_DB_CONNECTION=[Environment]::GetEnvironmentVariable('SOCIETY360_DB_CONNECTION','User')
if([string]::IsNullOrWhiteSpace($env:SOCIETY360_DB_CONNECTION)){throw 'SOCIETY360_DB_CONNECTION is not configured.'}
$env:ASPNETCORE_URLS='http://127.0.0.1:5239'
Set-Location 'C:\Users\Delta\Society360'
& 'C:\Users\Delta\.dotnet\dotnet.exe' run --no-launch-profile --no-build -- --apply-operational-schema
exit $LASTEXITCODE
