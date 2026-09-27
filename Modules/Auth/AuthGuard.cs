using System.Security.Claims;
using Society360.Data;

namespace Society360.Security;

public static class AuthGuard
{
    public static async Task<SessionContext?> Get(HttpContext http, AuthService auth, CancellationToken ct)
    {
        var token = http.User.FindFirstValue("society360_session_token");
        if (http.User.Identity?.IsAuthenticated == true && !string.IsNullOrWhiteSpace(token))
        {
            var session = await auth.GetSessionAsync(token, ct);
            Console.WriteLine($"[AUTH] AUTH_COOKIE path={http.Request.Path} session_valid={session is not null} role={session?.RoleCode ?? "-"} society={session?.SocietyId?.ToString() ?? "-"}");
            return session;
        }

        if (http.Request.Cookies.TryGetValue("society360_session", out var legacyToken) && !string.IsNullOrWhiteSpace(legacyToken))
        {
            var session = await auth.GetSessionAsync(legacyToken, ct);
            Console.WriteLine($"[AUTH] LEGACY_COOKIE path={http.Request.Path} session_valid={session is not null} role={session?.RoleCode ?? "-"} society={session?.SocietyId?.ToString() ?? "-"}");
            return session;
        }

        Console.WriteLine($"[AUTH] NOT_AUTHENTICATED path={http.Request.Path} scheme={http.Request.Scheme} host={http.Request.Host}");
        return null;
    }

    public static void SetCookie(HttpResponse response, string token)
    {
        var request = response.HttpContext.Request;
        var forwardedProto = request.Headers["X-Forwarded-Proto"].ToString();
        var cloudflareVisitor = request.Headers["CF-Visitor"].ToString();
        var isHttps = request.IsHttps
            || forwardedProto.Contains("https", StringComparison.OrdinalIgnoreCase)
            || cloudflareVisitor.Contains("https", StringComparison.OrdinalIgnoreCase);

        response.Cookies.Append("society360_session",token,new CookieOptions
        {
            HttpOnly=true,
            Secure=isHttps,
            SameSite=SameSiteMode.Lax,
            Expires=DateTimeOffset.UtcNow.AddHours(8),
            MaxAge=TimeSpan.FromHours(8),
            Path="/"
        });
    }

    public static void ClearCookie(HttpResponse response)
    {
        response.Cookies.Delete("society360_session",new CookieOptions { Path="/" });
    }
}