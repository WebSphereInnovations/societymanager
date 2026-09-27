using ClosedXML.Excel;
using System.Text.Json;
using System.Text.RegularExpressions;
using Npgsql;

namespace Society360.Modules.Migration;

public sealed record MigrationUnitRow(int RowNumber,string? Wing,string UnitNo,string? Owner,decimal? Area,decimal? Maintenance,string UnitType,string SourceFile);

public sealed class MigrationService(IConfiguration configuration)
{
    private readonly string? _cs=configuration.GetConnectionString("Society360") ?? Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION");

    public IReadOnlyList<MigrationUnitRow> ReadExcel(Stream stream,string fileName)
    {
        using var workbook=new XLWorkbook(stream);
        var sheet=workbook.Worksheets.First();
        var rows=new List<MigrationUnitRow>();
        var used=sheet.RangeUsed();
        if(used is null) return rows;
        var headers=used.FirstRow().Cells().Select(c=>c.GetString().Trim().ToUpperInvariant()).ToList();
        int Col(string name)=>headers.FindIndex(x=>x==name)+1;
        var flatCol=Col("FLATNO"); var ownerCol=Col("OWNER"); var areaCol=Col("AREA"); var maintCol=Col("MAINT");
        if(flatCol==0 || ownerCol==0 || areaCol==0) throw new InvalidOperationException("Required columns FLATNO, OWNER and Area are missing.");
        foreach(var row in used.RowsUsed().Skip(1))
        {
            var unit=row.Cell(flatCol).GetString().Trim();
            var owner=row.Cell(ownerCol).GetString().Trim();
            var area=ToDecimal(row.Cell(areaCol).Value);
            var maint=maintCol>0?ToDecimal(row.Cell(maintCol).Value):null;
            if(string.IsNullOrWhiteSpace(unit) || unit.Contains("TOTAL",StringComparison.OrdinalIgnoreCase) || Regex.IsMatch(owner,@"^[A-F]-WING$",RegexOptions.IgnoreCase)) continue;
            var normalized=NormalizeUnit(unit);
            rows.Add(new MigrationUnitRow(row.RowNumber(),normalized.Wing,normalized.UnitNo,string.IsNullOrWhiteSpace(owner)?null:owner,area,maint,normalized.UnitType,fileName));
        }
        return rows;
    }

    private static decimal? ToDecimal(XLCellValue value)
    {
        if(value.IsNumber) return (decimal)value.GetNumber();
        return decimal.TryParse(value.ToString(),out var n)?n:null;
    }

    private static (string? Wing,string UnitNo,string UnitType) NormalizeUnit(string input)
    {
        var s=Regex.Replace(input.Trim(),@"\s+","");
        var match=Regex.Match(s,@"^(?<wing>[A-Za-z]+)[/\\-](?<unit>.+)$");
        if(match.Success) return (match.Groups["wing"].Value.ToUpperInvariant(),match.Groups["unit"].Value,"Flat");
        if(s.StartsWith("SHOP",StringComparison.OrdinalIgnoreCase) || s.StartsWith("6&7")) return (null,s.ToUpperInvariant(),"Shop");
        return (null,s,"Flat");
    }

    public async Task<long> CreateBatchAsync(long societyId,long userId,string fileName,IReadOnlyList<MigrationUnitRow> rows,CancellationToken ct)
    {
        await using var c=new NpgsqlConnection(_cs); await c.OpenAsync(ct); await using var tx=await c.BeginTransactionAsync(ct);
        var batchNo="MIG-"+DateTime.UtcNow.ToString("yyyyMMddHHmmss");
        await using var cmd=new NpgsqlCommand("call society_manager.sp_create_migration_batch(@society_id,@batch_no,@file,@user_id,NULL)",c,tx);
        cmd.Parameters.AddWithValue("society_id",societyId); cmd.Parameters.AddWithValue("batch_no",batchNo); cmd.Parameters.AddWithValue("file",fileName); cmd.Parameters.AddWithValue("user_id",userId);
        var batchId=Convert.ToInt64(await cmd.ExecuteScalarAsync(ct));
        foreach(var r in rows)
        {
            await using var ins=new NpgsqlCommand("call society_manager.sp_migration_stage_row(@batch,@society,@row,@wing,@unit,@owner,@area,@maint,@type,@raw,@user)",c,tx);
            ins.Parameters.AddWithValue("batch",batchId); ins.Parameters.AddWithValue("society",societyId); ins.Parameters.AddWithValue("row",r.RowNumber);
            ins.Parameters.AddWithValue("wing",(object?)r.Wing??DBNull.Value); ins.Parameters.AddWithValue("unit",r.UnitNo);
            ins.Parameters.AddWithValue("owner",(object?)r.Owner??DBNull.Value); ins.Parameters.AddWithValue("area",(object?)r.Area??DBNull.Value);
            ins.Parameters.AddWithValue("maint",(object?)r.Maintenance??DBNull.Value); ins.Parameters.AddWithValue("type",r.UnitType);
            ins.Parameters.AddWithValue("raw",NpgsqlTypes.NpgsqlDbType.Jsonb,JsonSerializer.Serialize(new{r.RowNumber,r.Wing,r.UnitNo,r.Owner,r.Area,r.Maintenance,r.UnitType,r.SourceFile}));
            ins.Parameters.AddWithValue("user",userId);
            await ins.ExecuteNonQueryAsync(ct);
        }
        await tx.CommitAsync(ct); return batchId;
    }

    public async Task<object> ImportAsync(long batchId,long userId,CancellationToken ct)
    {
        await using var c=new NpgsqlConnection(_cs); await c.OpenAsync(ct);
        await using var cmd=new NpgsqlCommand("select * from society_manager.fn_import_migration_units(@batch,@user)",c);
        cmd.Parameters.AddWithValue("batch",batchId); cmd.Parameters.AddWithValue("user",userId);
        await using var reader=await cmd.ExecuteReaderAsync(ct);
        if(!await reader.ReadAsync(ct)) return new { importedFlats=0,importedCustomers=0,skippedRows=0 };
        return new { importedFlats=reader.GetInt64(0), importedCustomers=reader.GetInt64(1), skippedRows=reader.GetInt64(2) };
    }
}