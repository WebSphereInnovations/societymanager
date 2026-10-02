$conn=(Get-ItemProperty -Path 'HKCU:\Environment' -Name 'SOCIETY360_DB_CONNECTION' -ErrorAction Stop).SOCIETY360_DB_CONNECTION
if([string]::IsNullOrWhiteSpace($conn)){throw 'SOCIETY360_DB_CONNECTION is not configured.'}
$env:SOCIETY360_DB_CONNECTION=$conn
Set-Location 'C:\Users\Delta\Society360'
& 'C:\Users\Delta\.dotnet\dotnet.exe' run --no-launch-profile --urls 'http://0.0.0.0:5180'
