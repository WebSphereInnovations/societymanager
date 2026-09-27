using System.Security.Cryptography;
using Npgsql;

namespace Society360.Data;

public sealed class AuthService(IConfiguration configuration)
{
    private readonly string? _connectionString =
        configuration.GetConnectionString("Society360") ??
        Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION");

    public bool IsConfigured => !string.IsNullOrWhiteSpace(_connectionString);

    public async Task<AuthUser?> AuthenticateAsync(string login, string password, CancellationToken ct)
    {
        if (!IsConfigured) return null;
        await using var cn = new NpgsqlConnection(_connectionString);
        await cn.OpenAsync(ct);
        await using var cmd = new NpgsqlCommand(
            "select * from society_manager.fn_authenticate_user(@login,@password)", cn);
        cmd.Parameters.AddWithValue("login", login);
        cmd.Parameters.AddWithValue("password", password);
        await using var r = await cmd.ExecuteReaderAsync(ct);
        if (!await r.ReadAsync(ct)) return null;
        return new AuthUser(r.GetInt64(0),r.GetString(1),r.GetString(2),            r.GetString(3),r.GetString(4));
    }

    public async Task<IReadOnlyList<SocietyOption>> GetSocietiesAsync(long userId, CancellationToken ct)
    {
        var result = new List<SocietyOption>();
        if (!IsConfigured) return result;
        await using var cn = new NpgsqlConnection(_connectionString);
        await cn.OpenAsync(ct);
        await using var cmd = new NpgsqlCommand(
            "select * from society_manager.fn_user_societies(@user_id)", cn);
        cmd.Parameters.AddWithValue("user_id", userId);
        await using var r = await cmd.ExecuteReaderAsync(ct);
        while (await r.ReadAsync(ct))
            result.Add(new SocietyOption(r.GetInt64(0),r.GetString(1),r.GetString(2),r.GetBoolean(3)));
        return result;
    }

    public async Task<IReadOnlyList<PermissionItem>> GetPermissionsAsync(long userId, CancellationToken ct)
    {
        var result = new List<PermissionItem>();
        if (!IsConfigured) return result;
        await using var cn = new NpgsqlConnection(_connectionString);
        await cn.OpenAsync(ct);
        await using var cmd = new NpgsqlCommand(            "select * from society_manager.fn_user_permissions(@user_id)", cn);
        cmd.Parameters.AddWithValue("user_id", userId);
        await using var r = await cmd.ExecuteReaderAsync(ct);
        while (await r.ReadAsync(ct))
            result.Add(new PermissionItem(r.GetString(0),r.GetString(1)));
        return result;
    }

    public async Task<string> CreateSessionAsync(long userId, long? societyId, CancellationToken ct)
    {
        if (!IsConfigured) throw new InvalidOperationException("Database is not configured.");
        var raw = Convert.ToBase64String(RandomNumberGenerator.GetBytes(48));
        var hash = Convert.ToHexString(SHA256.HashData(System.Text.Encoding.UTF8.GetBytes(raw)));
        await using var cn = new NpgsqlConnection(_connectionString);
        await cn.OpenAsync(ct);
        await using var cmd = new NpgsqlCommand(
            "select society_manager.fn_create_session(@user_id,@token_hash,@society_id,@expires_at)", cn);
        cmd.Parameters.AddWithValue("user_id",userId);
        cmd.Parameters.AddWithValue("token_hash",hash);
        cmd.Parameters.AddWithValue("society_id",(object?)societyId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("expires_at",DateTimeOffset.UtcNow.AddHours(8));
        await cmd.ExecuteScalarAsync(ct);
        return raw;
    }
    public async Task<SessionContext?> GetSessionAsync(string rawToken, CancellationToken ct)
    {
        if (!IsConfigured || string.IsNullOrWhiteSpace(rawToken)) return null;
        var hash = Convert.ToHexString(SHA256.HashData(System.Text.Encoding.UTF8.GetBytes(rawToken)));
        await using var cn = new NpgsqlConnection(_connectionString);
        await cn.OpenAsync(ct);
        await using var cmd = new NpgsqlCommand(
            "select * from society_manager.fn_session_context(@token_hash)", cn);
        cmd.Parameters.AddWithValue("token_hash",hash);
        await using var r = await cmd.ExecuteReaderAsync(ct);
        if (!await r.ReadAsync(ct)) return null;
        return new SessionContext(r.GetGuid(0),r.GetInt64(1),r.IsDBNull(2)?null:r.GetInt64(2),
            r.GetString(3),r.GetString(4),r.GetString(5));
    }

    public async Task<bool> SelectSocietyAsync(string rawToken,long societyId,CancellationToken ct)
    {
        if (!IsConfigured || string.IsNullOrWhiteSpace(rawToken)) return false;
        var hash = Convert.ToHexString(SHA256.HashData(System.Text.Encoding.UTF8.GetBytes(rawToken)));
        await using var cn = new NpgsqlConnection(_connectionString);
        await cn.OpenAsync(ct);
        await using var cmd = new NpgsqlCommand(
            "select society_manager.fn_set_session_society(@token_hash,@society_id)", cn);
        cmd.Parameters.AddWithValue("token_hash",hash);
        cmd.Parameters.AddWithValue("society_id",societyId);
        return Convert.ToBoolean(await cmd.ExecuteScalarAsync(ct));
    }

    public async Task RevokeSessionAsync(string rawToken, CancellationToken ct)
    {
        if (!IsConfigured || string.IsNullOrWhiteSpace(rawToken)) return;
        var hash = Convert.ToHexString(SHA256.HashData(System.Text.Encoding.UTF8.GetBytes(rawToken)));
        await using var cn = new NpgsqlConnection(_connectionString);
        await cn.OpenAsync(ct);
        await using var cmd = new NpgsqlCommand(
            "select society_manager.fn_revoke_session(@token_hash)", cn);
        cmd.Parameters.AddWithValue("token_hash",hash);
        await cmd.ExecuteNonQueryAsync(ct);    }

    public async Task<bool> ChangeLoginNameAsync(long userId,string currentPassword,string newLogin,CancellationToken ct)
    {
        if (!IsConfigured) return false;
        await using var cn = new NpgsqlConnection(_connectionString);
        await cn.OpenAsync(ct);
        await using var cmd = new NpgsqlCommand(
            "select society_manager.fn_change_user_login(@user_id,@current_password,@new_login)",cn);
        cmd.Parameters.AddWithValue("user_id",userId);
        cmd.Parameters.AddWithValue("current_password",currentPassword);
        cmd.Parameters.AddWithValue("new_login",newLogin);
        return Convert.ToBoolean(await cmd.ExecuteScalarAsync(ct));
    }

    public async Task<bool> ChangePasswordAsync(long userId,string currentPassword,string newPassword,CancellationToken ct)
    {
        if (!IsConfigured) return false;
        await using var cn = new NpgsqlConnection(_connectionString);
        await cn.OpenAsync(ct);
        await using var cmd = new NpgsqlCommand(
            "select society_manager.fn_change_user_password(@user_id,@current_password,@new_password)",cn);
        cmd.Parameters.AddWithValue("user_id",userId);
        cmd.Parameters.AddWithValue("current_password",currentPassword);
        cmd.Parameters.AddWithValue("new_password",newPassword);
        return Convert.ToBoolean(await cmd.ExecuteScalarAsync(ct));
    }
}

public sealed record AuthUser(long UserId,string LoginName,string DisplayName,string RoleCode,string PreferredLanguage);
public sealed record SocietyOption(long SocietyId,string SocietyCode,string SocietyName,bool IsDefault);
public sealed record PermissionItem(string ModuleCode,string ActionCode);
public sealed record SessionContext(Guid SessionId,long UserId,long? SocietyId,string LoginName,string DisplayName,string RoleCode);
