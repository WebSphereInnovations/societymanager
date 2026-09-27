using Npgsql;

namespace Society360.Data;

public sealed class SocietyDb(IConfiguration configuration)
{
    private readonly string? _connectionString =
        configuration.GetConnectionString("Society360") ??
        Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION");

    public bool IsConfigured => !string.IsNullOrWhiteSpace(_connectionString);

    public NpgsqlConnection CreateConnection()
    {
        if (!IsConfigured) throw new InvalidOperationException("Database is not configured.");
        return new NpgsqlConnection(_connectionString);
    }

    public async Task<IReadOnlyList<object>> GetSocietiesAsync(CancellationToken cancellationToken = default)
    {
        if (!IsConfigured) return [];

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);

        const string sql = """
            select society_id, society_code, society_name, is_active
            from society_manager.m_society
            order by society_name
            """;

        await using var command = new NpgsqlCommand(sql, connection);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);

        var result = new List<object>();
        while (await reader.ReadAsync(cancellationToken))
        {
            result.Add(new
            {
                societyId = reader.GetInt64(0),
                societyCode = reader.GetString(1),
                societyName = reader.GetString(2),
                isActive = reader.GetBoolean(3)
            });
        }

        return result;
    }

    public async Task<object?> GetDashboardSummaryAsync(long societyId, DateOnly month, CancellationToken cancellationToken = default)
    {
        if (!IsConfigured) return null;

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);

        await using var command = new NpgsqlCommand(
            "select * from society_manager.fn_dashboard_summary(@society_id,@month)", connection);
        command.Parameters.AddWithValue("society_id", societyId);
        command.Parameters.AddWithValue("month", month);

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken)) return null;

        return new
        {
            billed = reader.GetDecimal(0),
            collected = reader.GetDecimal(1),
            outstanding = reader.GetDecimal(2),
            occupiedFlats = reader.GetInt64(3),
            totalFlats = reader.GetInt64(4),
            openComplaints = reader.GetInt64(5)
        };
    }
}
