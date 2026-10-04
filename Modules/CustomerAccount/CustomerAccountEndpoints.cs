using Npgsql;
using Society360.Data;
using Society360.Security;

namespace Society360.Modules.CustomerAccount;

public static class CustomerAccountEndpoints
{
    public static void MapCustomerAccountEndpoints(this WebApplication app)
    {
        app.MapGet("/api/customer-account/search", Search);
        app.MapGet("/api/customer-account/me", GetMine);
        app.MapGet("/api/customer-account/{consumerId:long}", GetAccount);
        app.MapGet("/api/customer-account/{consumerId:long}/section/{section}", GetSection);
    }

    static async Task<IResult> Search(string? q, int? limit, AuthService auth, HttpContext http, CancellationToken ct)
    {
        var s = await AuthGuard.Get(http, auth, ct);
        if (s is null) return Results.Unauthorized();
        if (s.SocietyId is null) return Results.BadRequest(new { message = "Select a society first." });
        if (!await CanSearchAsync(s, auth, ct)) return Results.Forbid();

        var term = (q ?? string.Empty).Trim();
        if (term.Length == 0) return Results.Ok(Array.Empty<object>());
        var take = Math.Clamp(limit ?? 20, 1, 30);

        await using var cn = new NpgsqlConnection(Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION"));
        await cn.OpenAsync(ct);
        await using var cmd = new NpgsqlCommand("select * from society_manager.sp_customer_account_search(@society,@search) limit @limit", cn);
        cmd.Parameters.AddWithValue("society", s.SocietyId.Value);
        cmd.Parameters.AddWithValue("search", term);
        cmd.Parameters.AddWithValue("limit", take);
        return Results.Ok(await ReadRows(cmd, ct));
    }

    static async Task<IResult> GetMine(AuthService auth, HttpContext http, CancellationToken ct)
    {
        var s = await AuthGuard.Get(http, auth, ct);
        if (s is null) return Results.Unauthorized();
        if (s.SocietyId is null) return Results.Forbid();

        await using var cn = new NpgsqlConnection(Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION"));
        await cn.OpenAsync(ct);
        await using var cmd = new NpgsqlCommand("""
            select consumer_id from society_manager.m_user
            where user_id=@user and society_id=@society and is_active
            """, cn);
        cmd.Parameters.AddWithValue("user", s.UserId);
        cmd.Parameters.AddWithValue("society", s.SocietyId.Value);
        var value = await cmd.ExecuteScalarAsync(ct);
        if (value is null || value is DBNull) return Results.NotFound(new { message = "No consumer account is linked to this login." });
        return await GetAccountById(s, auth, (long)value, ct);
    }

    static async Task<IResult> GetAccount(long consumerId, AuthService auth, HttpContext http, CancellationToken ct)
    {
        var s = await AuthGuard.Get(http, auth, ct);
        if (s is null) return Results.Unauthorized();
        if (s.SocietyId is null) return Results.Forbid();
        return await GetAccountById(s, auth, consumerId, ct);
    }

    static async Task<IResult> GetAccountById(SessionContext s, AuthService auth, long consumerId, CancellationToken ct)
    {
        if (!await CanOpenAsync(s, auth, consumerId, ct)) return Results.Forbid();

        await using var cn = new NpgsqlConnection(Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION"));
        await cn.OpenAsync(ct);

        await using var profileCmd = new NpgsqlCommand("select * from society_manager.sp_customer_account_get(@society,@consumer)", cn);
        profileCmd.Parameters.AddWithValue("society", s.SocietyId!.Value);
        profileCmd.Parameters.AddWithValue("consumer", consumerId);
        var profile = await ReadRows(profileCmd, ct);
        if (profile.Count == 0) return Results.NotFound(new { message = "Consumer account not found in the selected society." });

        await using var summaryCmd = new NpgsqlCommand("select * from society_manager.sp_customer_account_summary(@society,@consumer)", cn);
        summaryCmd.Parameters.AddWithValue("society", s.SocietyId.Value);
        summaryCmd.Parameters.AddWithValue("consumer", consumerId);
        var summary = await ReadRows(summaryCmd, ct);

        return Results.Ok(new { consumerId, profile, summary = summary.FirstOrDefault() });
    }

    static async Task<IResult> GetSection(long consumerId, string section, string? search, int? page, int? pageSize,
        AuthService auth, HttpContext http, CancellationToken ct)
    {
        var s = await AuthGuard.Get(http, auth, ct);
        if (s is null) return Results.Unauthorized();
        if (s.SocietyId is null) return Results.Forbid();
        if (!await CanOpenAsync(s, auth, consumerId, ct)) return Results.Forbid();

        var allowed = new[] { "billing", "payments", "dues", "service", "complaints", "interactions", "adjustments", "documents", "timeline" };
        if (!allowed.Contains(section, StringComparer.OrdinalIgnoreCase))
            return Results.BadRequest(new { message = "Unsupported account section." });

        var size = Math.Clamp(pageSize ?? 25, 1, 100);
        var currentPage = Math.Max(page ?? 1, 1);
        var offset = (currentPage - 1) * size;

        await using var cn = new NpgsqlConnection(Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION"));
        await cn.OpenAsync(ct);
        await using var cmd = new NpgsqlCommand("select society_manager.sp_customer_account_section(@society,@consumer,@section,@search,@limit,@offset)", cn);
        cmd.Parameters.AddWithValue("society", s.SocietyId.Value);
        cmd.Parameters.AddWithValue("consumer", consumerId);
        cmd.Parameters.AddWithValue("section", section.ToLowerInvariant());
        cmd.Parameters.AddWithValue("search", (search ?? string.Empty).Trim());
        cmd.Parameters.AddWithValue("limit", size);
        cmd.Parameters.AddWithValue("offset", offset);
        var value = await cmd.ExecuteScalarAsync(ct);
        if (value is null || value is DBNull) return Results.NotFound(new { message = "Consumer account not found." });
        return Results.Text(value.ToString()!, "application/json");
    }

    static async Task<bool> CanSearchAsync(SessionContext s, AuthService auth, CancellationToken ct)
    {
        if (s.RoleCode is "SUPER_ADMIN" or "SOCIETY_ADMIN")
            return await auth.HasPermissionAsync(s.UserId, "CRM_CUSTOMER_ACCOUNT", "VIEW", ct);
        if (s.RoleCode == "CASHIER")
            return await auth.HasPermissionAsync(s.UserId, "COLLECTION_MANAGEMENT", "VIEW", ct)
                || await auth.HasPermissionAsync(s.UserId, "CRM_CUSTOMER_ACCOUNT", "VIEW", ct);
        return false;
    }

    static async Task<bool> CanOpenAsync(SessionContext s, AuthService auth, long consumerId, CancellationToken ct)
    {
        if (s.RoleCode == "RESIDENT")
        {
            await using var cn = new NpgsqlConnection(Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION"));
            await cn.OpenAsync(ct);
            await using var cmd = new NpgsqlCommand("""
                select exists(
                    select 1 from society_manager.m_user
                    where user_id=@user and society_id=@society and consumer_id=@consumer and is_active
                )
                """, cn);
            cmd.Parameters.AddWithValue("user", s.UserId);
            cmd.Parameters.AddWithValue("society", s.SocietyId!.Value);
            cmd.Parameters.AddWithValue("consumer", consumerId);
            return Convert.ToBoolean(await cmd.ExecuteScalarAsync(ct));
        }

        if (s.RoleCode == "CASHIER")
            return await auth.HasPermissionAsync(s.UserId, "COLLECTION_MANAGEMENT", "VIEW", ct)
                || await auth.HasPermissionAsync(s.UserId, "CRM_CUSTOMER_ACCOUNT", "VIEW", ct);

        return await auth.HasPermissionAsync(s.UserId, "CRM_CUSTOMER_ACCOUNT", "VIEW", ct);
    }

    static async Task<List<Dictionary<string, object?>>> ReadRows(NpgsqlCommand cmd, CancellationToken ct)
    {
        var rows = new List<Dictionary<string, object?>>();
        await using var reader = await cmd.ExecuteReaderAsync(ct);
        while (await reader.ReadAsync(ct))
        {
            var row = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
            for (var i = 0; i < reader.FieldCount; i++)
            {
                var value = reader.IsDBNull(i) ? null : reader.GetValue(i);
                row[reader.GetName(i)] = value is DateOnly d ? d.ToString("yyyy-MM-dd")
                    : value is DateTime dt ? dt.ToString("yyyy-MM-ddTHH:mm:ss")
                    : value is DateTimeOffset dto ? dto.ToString("yyyy-MM-ddTHH:mm:sszzz")
                    : value;
            }
            rows.Add(row);
        }
        return rows;
    }
}
