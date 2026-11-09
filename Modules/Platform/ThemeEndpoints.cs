using Npgsql;
using Society360.Data;
using Society360.Security;
using Microsoft.AspNetCore.Antiforgery;

namespace Society360.Modules.Platform;

public sealed record ThemePreferenceRequest(string ThemeCode, string? Remark);
public sealed record ThemeEntitlementRequest(
    long SocietyId,
    string ThemeCode,
    bool IsActive,
    string? GrantSource,
    long? SubscriptionId,
    DateTimeOffset? StartsAt,
    DateTimeOffset? EndsAt,
    string? Remark);

public static class ThemeEndpoints
{
    private const string PermissionModule = "THEME_PREFERENCES";

    public static void MapThemeEndpoints(this WebApplication app)
    {
        app.MapGet("/api/theme/options", async (
            SocietyDb db, AuthService auth, HttpContext http, CancellationToken ct) =>
        {
            var session = await AuthGuard.Get(http, auth, ct);
            if (session is null) return Results.Unauthorized();
            if (!db.IsConfigured) return Results.Problem("Database is not configured.", statusCode: 503);

            var canView = await auth.HasPermissionAsync(session.UserId, PermissionModule, "VIEW", ct);
            var canUpdate = canView && await auth.HasPermissionAsync(session.UserId, PermissionModule, "UPDATE", ct);
            var options = new List<object>();
            var allowedThemeCodes = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            var selectedTheme = "STANDARD";

            await using var cn = db.CreateConnection();
            await cn.OpenAsync(ct);

            await using (var cmd = new NpgsqlCommand("""
                SELECT theme_code, theme_name, is_commercial
                FROM society_manager.m_theme t
                WHERE t.is_active
                  AND (
                    t.theme_code = 'STANDARD'
                    OR (
                      @can_view AND @society_id IS NOT NULL
                      AND society_manager.fn_skyfy_theme_is_entitled(@society_id, t.theme_code)
                    )
                  )
                ORDER BY t.is_default DESC, t.theme_name
                """, cn))
            {
                cmd.Parameters.AddWithValue("can_view", canView);
                cmd.Parameters.Add("society_id", NpgsqlTypes.NpgsqlDbType.Bigint).Value = (object?)session.SocietyId ?? DBNull.Value;
                await using var reader = await cmd.ExecuteReaderAsync(ct);
                while (await reader.ReadAsync(ct))
                {
                    var themeCode = reader.GetString(0);
                    allowedThemeCodes.Add(themeCode);
                    options.Add(new
                    {
                        themeCode,
                        themeName = reader.GetString(1),
                        isCommercial = reader.GetBoolean(2)
                    });
                }
            }

            if (canView && session.SocietyId is long societyId)
            {
                await using var preference = new NpgsqlCommand("""
                    SELECT t.theme_code
                    FROM society_manager.t_user_theme_preference p
                    JOIN society_manager.m_theme t ON t.theme_id = p.theme_id
                    WHERE p.user_id = @user_id AND p.society_id = @society_id
                    """, cn);
                preference.Parameters.AddWithValue("user_id", session.UserId);
                preference.Parameters.AddWithValue("society_id", societyId);
                var saved = await preference.ExecuteScalarAsync(ct) as string;
                if (!string.IsNullOrWhiteSpace(saved) &&
                    allowedThemeCodes.Contains(saved))
                    selectedTheme = saved;
            }

            return Results.Ok(new
            {
                selectedTheme,
                canChange = canUpdate && session.SocietyId is not null,
                themes = options
            });
        });

        app.MapPut("/api/theme/preference", async (
            ThemePreferenceRequest request, SocietyDb db, AuthService auth,
            HttpContext http, IAntiforgery antiforgery, CancellationToken ct) =>
        {
            var session = await AuthGuard.Get(http, auth, ct);
            if (session is null) return Results.Unauthorized();
            if (session.SocietyId is not long societyId) return Results.BadRequest(new { message = "Select a society before changing the theme." });
            if (!await auth.HasPermissionAsync(session.UserId, PermissionModule, "UPDATE", ct)) return Results.Forbid();
            try { await antiforgery.ValidateRequestAsync(http); }
            catch { return Results.BadRequest(new { message = "Security token expired. Refresh the page and try again." }); }
            if (!db.IsConfigured) return Results.Problem("Database is not configured.", statusCode: 503);

            var themeCode = (request.ThemeCode ?? string.Empty).Trim().ToUpperInvariant();
            if (themeCode.Length == 0) return Results.BadRequest(new { message = "Choose a theme." });

            await using var cn = db.CreateConnection();
            await cn.OpenAsync(ct);

            await using var validate = new NpgsqlCommand("""
                SELECT t.theme_id, society_manager.fn_skyfy_theme_is_entitled(@society_id, t.theme_code)
                FROM society_manager.m_theme t
                WHERE t.theme_code = @theme_code AND t.is_active
                """, cn);
            validate.Parameters.AddWithValue("society_id", societyId);
            validate.Parameters.AddWithValue("theme_code", themeCode);
            await using var validateReader = await validate.ExecuteReaderAsync(ct);
            if (!await validateReader.ReadAsync(ct)) return Results.BadRequest(new { message = "The selected theme is unavailable." });
            var themeId = validateReader.GetInt64(0);
            var entitled = validateReader.GetBoolean(1);
            await validateReader.CloseAsync();
            if (!entitled) return Results.Forbid();

            await using var tx = await cn.BeginTransactionAsync(ct);
            await SetAuditContextAsync(cn, tx, session.UserId, request.Remark, http, ct);
            await using var save = new NpgsqlCommand("""
                INSERT INTO society_manager.t_user_theme_preference
                    (user_id, society_id, theme_id, created_by, modified_by, modified_at,
                     modify_by, modify_date, modify_remark)
                VALUES
                    (@user_id, @society_id, @theme_id, @user_id, @user_id, now(),
                     @user_id, now(), @remark)
                ON CONFLICT (user_id, society_id)
                DO UPDATE SET
                    theme_id = EXCLUDED.theme_id,
                    modified_by = EXCLUDED.modified_by,
                    modified_at = now(),
                    modify_by = EXCLUDED.modify_by,
                    modify_date = now(),
                    modify_remark = EXCLUDED.modify_remark
                """, cn, tx);
            save.Parameters.AddWithValue("user_id", session.UserId);
            save.Parameters.AddWithValue("society_id", societyId);
            save.Parameters.AddWithValue("theme_id", themeId);
            save.Parameters.AddWithValue("remark", request.Remark?.Trim() ?? string.Empty);
            await save.ExecuteNonQueryAsync(ct);
            await tx.CommitAsync(ct);

            return Results.Ok(new { selectedTheme = themeCode });
        });

        app.MapGet("/api/platform/theme-entitlements", async (
            SocietyDb db, AuthService auth, HttpContext http, CancellationToken ct) =>
        {
            var session = await AuthGuard.Get(http, auth, ct);
            if (session is null) return Results.Unauthorized();
            if (session.RoleCode != "SUPER_ADMIN" ||
                !await auth.HasPermissionAsync(session.UserId, PermissionModule, "MANAGE", ct))
                return Results.Forbid();
            if (!db.IsConfigured) return Results.Problem("Database is not configured.", statusCode: 503);

            await using var cn = db.CreateConnection();
            await cn.OpenAsync(ct);
            await using var cmd = new NpgsqlCommand("""
                SELECT e.entitlement_id, e.society_id, s.society_name,
                       t.theme_code, t.theme_name, e.entitlement_status,
                       e.grant_source, e.subscription_id, e.starts_at, e.ends_at,
                       e.is_active
                FROM society_manager.t_society_theme_entitlement e
                JOIN society_manager.m_society s ON s.society_id = e.society_id
                JOIN society_manager.m_theme t ON t.theme_id = e.theme_id
                ORDER BY s.society_name, t.theme_name, e.starts_at DESC
                """, cn);
            await using var reader = await cmd.ExecuteReaderAsync(ct);
            var rows = new List<object>();
            while (await reader.ReadAsync(ct))
            {
                rows.Add(new
                {
                    entitlementId = reader.GetInt64(0),
                    societyId = reader.GetInt64(1),
                    societyName = reader.GetString(2),
                    themeCode = reader.GetString(3),
                    themeName = reader.GetString(4),
                    status = reader.GetString(5),
                    grantSource = reader.GetString(6),
                    subscriptionId = reader.IsDBNull(7) ? (long?)null : reader.GetInt64(7),
                    startsAt = reader.GetFieldValue<DateTimeOffset>(8),
                    endsAt = reader.IsDBNull(9) ? (DateTimeOffset?)null : reader.GetFieldValue<DateTimeOffset>(9),
                    isActive = reader.GetBoolean(10)
                });
            }
            return Results.Ok(rows);
        });

        app.MapPut("/api/platform/theme-entitlements", async (
            ThemeEntitlementRequest request, SocietyDb db, AuthService auth,
            HttpContext http, IAntiforgery antiforgery, CancellationToken ct) =>
        {
            var session = await AuthGuard.Get(http, auth, ct);
            if (session is null) return Results.Unauthorized();
            if (session.RoleCode != "SUPER_ADMIN" ||
                !await auth.HasPermissionAsync(session.UserId, PermissionModule, "MANAGE", ct))
                return Results.Forbid();
            try { await antiforgery.ValidateRequestAsync(http); }
            catch { return Results.BadRequest(new { message = "Security token expired. Refresh the page and try again." }); }
            if (!db.IsConfigured) return Results.Problem("Database is not configured.", statusCode: 503);

            var themeCode = (request.ThemeCode ?? string.Empty).Trim().ToUpperInvariant();
            var grantSource = (request.GrantSource ?? "MANUAL").Trim().ToUpperInvariant();
            if (request.SocietyId <= 0 || themeCode.Length == 0 || themeCode == "STANDARD")
                return Results.BadRequest(new { message = "A society and commercial theme are required." });
            if (grantSource is not ("SUBSCRIPTION" or "MANUAL" or "TRIAL"))
                return Results.BadRequest(new { message = "Invalid entitlement source." });
            if (request.IsActive && request.EndsAt is DateTimeOffset end &&
                end <= (request.StartsAt ?? DateTimeOffset.UtcNow))
                return Results.BadRequest(new { message = "The entitlement end must be later than its start." });
            if (request.IsActive && grantSource == "SUBSCRIPTION" && request.SubscriptionId is null)
                return Results.BadRequest(new { message = "A subscription is required for subscription-based activation." });

            await using var cn = db.CreateConnection();
            await cn.OpenAsync(ct);
            await using var themeCmd = new NpgsqlCommand("""
                SELECT theme_id FROM society_manager.m_theme
                WHERE theme_code = @theme_code AND is_active AND is_commercial
                """, cn);
            themeCmd.Parameters.AddWithValue("theme_code", themeCode);
            var themeValue = await themeCmd.ExecuteScalarAsync(ct);
            if (themeValue is null) return Results.BadRequest(new { message = "The commercial theme does not exist or is inactive." });
            var themeId = Convert.ToInt64(themeValue);

            if (request.IsActive && request.SubscriptionId is long subscriptionId)
            {
                await using var subscription = new NpgsqlCommand("""
                    SELECT count(*) FROM society_manager.m_society_subscription
                    WHERE subscription_id = @subscription_id AND society_id = @society_id
                      AND is_active AND start_date <= current_date AND end_date >= current_date
                    """, cn);
                subscription.Parameters.AddWithValue("subscription_id", subscriptionId);
                subscription.Parameters.AddWithValue("society_id", request.SocietyId);
                if (Convert.ToInt64(await subscription.ExecuteScalarAsync(ct)) == 0)
                    return Results.BadRequest(new { message = "The linked subscription is not active for this society." });
            }

            await using var tx = await cn.BeginTransactionAsync(ct);
            await SetAuditContextAsync(cn, tx, session.UserId, request.Remark, http, ct);
            if (request.IsActive)
            {
                await using var update = new NpgsqlCommand("""
                    UPDATE society_manager.t_society_theme_entitlement
                    SET subscription_id = @subscription_id, grant_source = @grant_source,
                        entitlement_status = 'ACTIVE', starts_at = @starts_at, ends_at = @ends_at,
                        is_active = true, modified_by = @user_id, modified_at = now(),
                        modify_by = @user_id, modify_date = now(), modify_remark = @remark
                    WHERE society_id = @society_id AND theme_id = @theme_id
                      AND is_active AND entitlement_status = 'ACTIVE'
                    """, cn, tx);
                update.Parameters.Add("subscription_id", NpgsqlTypes.NpgsqlDbType.Bigint).Value = (object?)request.SubscriptionId ?? DBNull.Value;
                update.Parameters.AddWithValue("grant_source", grantSource);
                update.Parameters.AddWithValue("starts_at", request.StartsAt ?? DateTimeOffset.UtcNow);
                update.Parameters.Add("ends_at", NpgsqlTypes.NpgsqlDbType.TimestampTz).Value = (object?)request.EndsAt ?? DBNull.Value;
                update.Parameters.AddWithValue("user_id", session.UserId);
                update.Parameters.AddWithValue("remark", request.Remark?.Trim() ?? string.Empty);
                update.Parameters.AddWithValue("society_id", request.SocietyId);
                update.Parameters.AddWithValue("theme_id", themeId);
                var affected = await update.ExecuteNonQueryAsync(ct);
                if (affected == 0)
                {
                    await using var insert = new NpgsqlCommand("""
                        INSERT INTO society_manager.t_society_theme_entitlement
                            (society_id, theme_id, subscription_id, grant_source, entitlement_status,
                             starts_at, ends_at, is_active, created_by, modified_by, modified_at,
                             modify_by, modify_date, modify_remark)
                        VALUES
                            (@society_id, @theme_id, @subscription_id, @grant_source, 'ACTIVE',
                             @starts_at, @ends_at, true, @user_id, @user_id, now(),
                             @user_id, now(), @remark)
                        """, cn, tx);
                    insert.Parameters.AddWithValue("society_id", request.SocietyId);
                    insert.Parameters.AddWithValue("theme_id", themeId);
                    insert.Parameters.Add("subscription_id", NpgsqlTypes.NpgsqlDbType.Bigint).Value = (object?)request.SubscriptionId ?? DBNull.Value;
                    insert.Parameters.AddWithValue("grant_source", grantSource);
                    insert.Parameters.AddWithValue("starts_at", request.StartsAt ?? DateTimeOffset.UtcNow);
                    insert.Parameters.Add("ends_at", NpgsqlTypes.NpgsqlDbType.TimestampTz).Value = (object?)request.EndsAt ?? DBNull.Value;
                    insert.Parameters.AddWithValue("user_id", session.UserId);
                    insert.Parameters.AddWithValue("remark", request.Remark?.Trim() ?? string.Empty);
                    await insert.ExecuteNonQueryAsync(ct);
                }
            }
            else
            {
                await using var deactivate = new NpgsqlCommand("""
                    UPDATE society_manager.t_society_theme_entitlement
                    SET entitlement_status = 'REVOKED', is_active = false,
                        modified_by = @user_id, modified_at = now(),
                        modify_by = @user_id, modify_date = now(), modify_remark = @remark
                    WHERE society_id = @society_id AND theme_id = @theme_id
                      AND is_active AND entitlement_status = 'ACTIVE'
                    """, cn, tx);
                deactivate.Parameters.AddWithValue("user_id", session.UserId);
                deactivate.Parameters.AddWithValue("remark", request.Remark?.Trim() ?? string.Empty);
                deactivate.Parameters.AddWithValue("society_id", request.SocietyId);
                deactivate.Parameters.AddWithValue("theme_id", themeId);
                await deactivate.ExecuteNonQueryAsync(ct);
            }
            await tx.CommitAsync(ct);
            return Results.Ok(new { societyId = request.SocietyId, themeCode, isActive = request.IsActive });
        });
    }

    private static async Task SetAuditContextAsync(
        NpgsqlConnection cn, NpgsqlTransaction tx, long userId, string? remark,
        HttpContext http, CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand("""
            SELECT set_config('society_manager.current_user_id', @user_id, true),
                   set_config('society_manager.modify_remark', @remark, true),
                   set_config('society360.user_id', @user_id, true),
                   set_config('society360.remark', @remark, true),
                   set_config('society360.ip', @ip, true),
                   set_config('society360.user_agent', @user_agent, true),
                   set_config('society360.request_id', @request_id, true)
            """, cn, tx);
        cmd.Parameters.AddWithValue("user_id", userId.ToString());
        cmd.Parameters.AddWithValue("remark", remark?.Trim() ?? string.Empty);
        cmd.Parameters.AddWithValue("ip", http.Connection.RemoteIpAddress?.ToString() ?? string.Empty);
        cmd.Parameters.AddWithValue("user_agent", http.Request.Headers.UserAgent.ToString());
        cmd.Parameters.AddWithValue("request_id", Guid.NewGuid().ToString("D"));
        await cmd.ExecuteNonQueryAsync(ct);
    }
}
