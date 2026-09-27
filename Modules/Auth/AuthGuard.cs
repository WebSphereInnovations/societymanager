using Society360.Data;

namespace Society360.Security;

public static class AuthGuard
{
    public static async Task<SessionContext?> Get(HttpContext http, AuthService auth, CancellationToken ct)
    {
        if (!http.Request.Cookies.TryGetValue("society360_session", out var token))
            return null;
        return await auth.GetSessionAsync(token, ct);
    }

    public static void SetCookie(HttpResponse response, string token)
    {
        response.Cookies.Append("society360_session",token,new CookieOptions
        {
            HttpOnly=true,Secure=response.HttpContext.Request.IsHttps,SameSite=SameSiteMode.Strict,
            Expires=DateTimeOffset.UtcNow.AddHours(8),Path="/"
        });
    }

    public static void ClearCookie(HttpResponse response)
    {
        response.Cookies.Delete("society360_session",new CookieOptions { Path="/" });
    }
}