using Microsoft.AspNetCore.DataProtection;

namespace Society360.Security;

public sealed class ConnectionStringProtector
{
    private readonly IDataProtector _protector;

    public ConnectionStringProtector(IDataProtectionProvider provider)
    {
        _protector = provider.CreateProtector("Society360.ConnectionString.v1");
    }

    public string Protect(string value) => _protector.Protect(value);
    public string Unprotect(string value) => _protector.Unprotect(value);
}