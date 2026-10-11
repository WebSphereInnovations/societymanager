using Npgsql;
using Society360.Data;
using Society360.Security;

namespace Society360.Modules.CustomerAccount;

public static class CustomerAccountEndpoints
{
    public static void MapCustomerAccountEndpoints(this WebApplication app)
    {
        app.MapGet("/api/customer-account/search", Search);
        app.MapGet("/api/customer-account/reference/{recordType}/{recordId:long}", ResolveReference);
        app.MapGet("/api/customer-account/me", GetMine);
        app.MapGet("/api/customer-account/{consumerId:long}", GetAccount);
        app.MapGet("/api/customer-account/{consumerId:long}/section/{section}", GetSection);
        app.MapGet("/api/customer-account/{consumerId:long}/bill/{billId:long}", GetBill);
        app.MapGet("/api/customer-account/{consumerId:long}/receipt/{paymentId:long}", GetReceipt);
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

    static async Task<IResult> ResolveReference(string recordType, long recordId, AuthService auth, HttpContext http, CancellationToken ct)
    {
        var s = await AuthGuard.Get(http, auth, ct);
        if (s is null) return Results.Unauthorized();
        if (s.SocietyId is null || recordId <= 0) return Results.BadRequest(new { message = "Invalid customer reference." });
        if (!await CanSearchAsync(s, auth, ct)) return Results.Forbid();

        // Whitelisted record-to-consumer joins preserve the exact row relationship and society boundary.
        var sql = recordType.ToLowerInvariant() switch
        {
            "consumer" => """
                select c.consumer_id from society_manager.m_customer c
                where c.society_id=@society and c.consumer_id=@id and c.is_active
                """,
            "customer" => """
                select c.consumer_id from society_manager.m_customer c
                where c.society_id=@society and c.customer_id=@id and c.is_active and c.consumer_id is not null
                """,
            "flat" => """
                select c.consumer_id from society_manager.m_flat f
                join society_manager.m_customer_flat cf on cf.society_id=f.society_id and cf.flat_id=f.flat_id and cf.is_primary
                join society_manager.m_customer c on c.society_id=cf.society_id and c.customer_id=cf.customer_id
                where f.society_id=@society and f.flat_id=@id and f.is_active and c.is_active and c.consumer_id is not null
                order by cf.start_date desc nulls last limit 1
                """,
            "bill" => """
                select coalesce(cd.consumer_id,cf.consumer_id)
                from society_manager.t_bill b
                left join society_manager.m_customer cd on cd.society_id=b.society_id and cd.consumer_id=b.consumer_id
                left join society_manager.m_customer_flat xcf on xcf.society_id=b.society_id and xcf.flat_id=b.flat_id and xcf.is_primary
                left join society_manager.m_customer cf on cf.society_id=xcf.society_id and cf.customer_id=xcf.customer_id
                where b.society_id=@society and b.bill_id=@id limit 1
                """,
            "payment" => """
                select c.consumer_id from society_manager.t_payment p
                join society_manager.m_customer c on c.society_id=p.society_id and c.customer_id=p.customer_id
                where p.society_id=@society and p.payment_id=@id and c.consumer_id is not null
                """,
            "parking" => """
                select c.consumer_id
                from society_manager.m_parking_slot s
                join society_manager.t_parking_assignment a on a.society_id=s.society_id and a.parking_slot_id=s.parking_slot_id and a.is_active
                join society_manager.m_customer c on c.society_id=a.society_id and c.customer_id=a.customer_id
                where s.society_id=@society and s.parking_slot_id=@id and s.is_active and c.is_active and c.consumer_id is not null
                order by a.start_date desc nulls last,a.assignment_id desc limit 1
                """,
            "visitor" => """
                select c.consumer_id from society_manager.t_visitor_entry v
                join society_manager.m_customer_flat cf on cf.society_id=v.society_id and cf.flat_id=v.flat_id and cf.is_primary
                join society_manager.m_customer c on c.society_id=cf.society_id and c.customer_id=cf.customer_id
                where v.society_id=@society and v.visitor_entry_id=@id and c.consumer_id is not null
                order by cf.start_date desc nulls last limit 1
                """,
            "complaint" => """
                select c.consumer_id from society_manager.t_complaint x
                join society_manager.m_customer c on c.society_id=x.society_id and c.customer_id=x.customer_id
                where x.society_id=@society and x.complaint_id=@id and c.consumer_id is not null
                """,
            _ => null
        };
        if (sql is null) return Results.BadRequest(new { message = "Unsupported customer reference type." });

        await using var cn = new NpgsqlConnection(Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION"));
        await cn.OpenAsync(ct);
        await using var cmd = new NpgsqlCommand(sql, cn);
        cmd.Parameters.AddWithValue("society", s.SocietyId.Value);
        cmd.Parameters.AddWithValue("id", recordId);
        var value = await cmd.ExecuteScalarAsync(ct);
        if (value is null || value is DBNull) return Results.NotFound(new { message = "No linked customer account was found for this record." });
        var consumerId = Convert.ToInt64(value);
        if (!await CanOpenAsync(s, auth, consumerId, ct)) return Results.Forbid();
        return Results.Ok(new { consumerId });
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

    static async Task<IResult> GetBill(long consumerId, long billId, AuthService auth, HttpContext http, CancellationToken ct)
    {
        var s = await AuthGuard.Get(http, auth, ct);
        if (s is null) return Results.Unauthorized();
        if (s.SocietyId is null || !await CanOpenAsync(s, auth, consumerId, ct)) return Results.Forbid();
        await using var cn = new NpgsqlConnection(Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION"));
        await cn.OpenAsync(ct);
        await using var cmd = new NpgsqlCommand("select society_manager.sp_customer_bill_view(@society,@consumer,@bill)", cn);
        cmd.Parameters.AddWithValue("society", s.SocietyId.Value);
        cmd.Parameters.AddWithValue("consumer", consumerId);
        cmd.Parameters.AddWithValue("bill", billId);
        var value = await cmd.ExecuteScalarAsync(ct);
        if (value is null || value is DBNull) return Results.NotFound(new { message = "Bill not found for the selected consumer." });
        return Results.Text(value.ToString()!, "application/json");
    }

    static async Task<IResult> GetReceipt(long consumerId, long paymentId, AuthService auth, HttpContext http, CancellationToken ct)
    {
        var s = await AuthGuard.Get(http, auth, ct);
        if (s is null) return Results.Unauthorized();
        if (s.SocietyId is null || !await CanOpenAsync(s, auth, consumerId, ct)) return Results.Forbid();
        await using var cn = new NpgsqlConnection(Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION"));
        await cn.OpenAsync(ct);
        await using var cmd = new NpgsqlCommand("select society_manager.sp_customer_receipt_view(@society,@consumer,@payment)", cn);
        cmd.Parameters.AddWithValue("society", s.SocietyId.Value);
        cmd.Parameters.AddWithValue("consumer", consumerId);
        cmd.Parameters.AddWithValue("payment", paymentId);
        var value = await cmd.ExecuteScalarAsync(ct);
        if (value is null || value is DBNull) return Results.NotFound(new { message = "Receipt not found for the selected consumer." });
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
