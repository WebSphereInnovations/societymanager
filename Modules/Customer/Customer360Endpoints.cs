using Npgsql;
using Society360.Security;
namespace Society360.Modules.Customer;
public static class Customer360Endpoints
{
 public static void MapCustomer360Endpoints(this WebApplication app)
 {
  app.MapGet("/api/customer/360",async(AuthService a,HttpContext h,CancellationToken c)=>await Fn(a,h,c,"fn_customer_360",21));
  app.MapGet("/api/customer/parking",async(AuthService a,HttpContext h,CancellationToken c)=>await Many(a,h,c,"fn_customer_parking",8));
  app.MapGet("/api/customer/payments",async(AuthService a,HttpContext h,CancellationToken c)=>await Many(a,h,c,"fn_customer_payments",8));
  app.MapGet("/api/customer/adjustments",async(AuthService a,HttpContext h,CancellationToken c)=>await Many(a,h,c,"fn_customer_adjustments",6));
  app.MapGet("/api/customer/documents",async(AuthService a,HttpContext h,CancellationToken c)=>await Many(a,h,c,"fn_customer_documents",4));
  app.MapGet("/api/customer/notices",async(AuthService a,HttpContext h,CancellationToken c)=>await Many(a,h,c,"fn_customer_notices",6));
 }
 static async Task<IResult> Many(AuthService a,HttpContext h,CancellationToken c,string fn,int n){
  var s=await AuthGuard.Get(h,a,c);if(s is null)return Results.Unauthorized();if(s.RoleCode!="RESIDENT")return Results.Forbid();await using var cn=new NpgsqlConnection(Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION"));await cn.OpenAsync(c);await using var cmd=new NpgsqlCommand($"select * from society_manager.{fn}(@user)",cn);cmd.Parameters.AddWithValue("user",s.UserId);await using var r=await cmd.ExecuteReaderAsync(c);var rows=new List<Dictionary<string,object?>>();while(await r.ReadAsync(c)){var row=new Dictionary<string,object?>();for(var i=0;i<n;i++)row[r.GetName(i)]=r.IsDBNull(i)?null:r.GetValue(i);rows.Add(row);}return Results.Ok(rows);
 }
 static async Task<IResult> Fn(AuthService a,HttpContext h,CancellationToken c,string fn,int n){var s=await AuthGuard.Get(h,a,c);if(s is null)return Results.Unauthorized();if(s.RoleCode!="RESIDENT")return Results.Forbid();await using var cn=new NpgsqlConnection(Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION"));await cn.OpenAsync(c);await using var cmd=new NpgsqlCommand($"select * from society_manager.{fn}(@user)",cn);cmd.Parameters.AddWithValue("user",s.UserId);await using var r=await cmd.ExecuteReaderAsync(c);var rows=new List<Dictionary<string,object?>>();while(await r.ReadAsync(c)){var row=new Dictionary<string,object?>();for(var i=0;i<n;i++)row[r.GetName(i)]=r.IsDBNull(i)?null:r.GetValue(i);rows.Add(row);}return Results.Ok(rows.FirstOrDefault());}
}