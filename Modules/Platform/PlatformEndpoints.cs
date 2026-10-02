using Npgsql;
using Society360.Data;
using Society360.Security;
namespace Society360.Modules.Platform;
public static class PlatformEndpoints
{
 public static void MapPlatformEndpoints(this WebApplication app)
 {
  app.MapGet("/api/menu",async(AuthService a,HttpContext h,CancellationToken c)=>{
   var s=await AuthGuard.Get(h,a,c); if(s is null)return Results.Unauthorized();
   await using var cn=new NpgsqlConnection(Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION")); await cn.OpenAsync(c);
   await using var cmd=new NpgsqlCommand("select * from society_manager.fn_user_module_menu(@user_id)",cn); cmd.Parameters.AddWithValue("user_id",s.UserId);
   await using var r=await cmd.ExecuteReaderAsync(c); var rows=new List<Dictionary<string,object?>>(); while(await r.ReadAsync(c)){var x=new Dictionary<string,object?>();for(var i=0;i<4;i++)x[r.GetName(i)]=r.IsDBNull(i)?null:r.GetValue(i);rows.Add(x);} return Results.Ok(rows);
  });
  app.MapGet("/api/platform/dashboard",async(AuthService a,HttpContext h,CancellationToken c)=>await Fn(a,h,c,"fn_super_admin_dashboard",8));
  app.MapGet("/api/platform/societies",async(AuthService a,HttpContext h,CancellationToken c)=>await Fn(a,h,c,"fn_super_admin_societies",10));
  app.MapGet("/api/platform/subscriptions",async(AuthService a,HttpContext h,CancellationToken c)=>await Fn(a,h,c,"fn_super_admin_subscriptions",9));
 }
 static async Task<IResult> Fn(AuthService a,HttpContext h,CancellationToken c,string fn,int n)
 {
  var s=await AuthGuard.Get(h,a,c); if(s is null)return Results.Unauthorized(); if(s.RoleCode!="SUPER_ADMIN")return Results.Forbid();
  await using var cn=new NpgsqlConnection(Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION")); await cn.OpenAsync(c);
  await using var cmd=new NpgsqlCommand($"select * from society_manager.{fn}()",cn); await using var r=await cmd.ExecuteReaderAsync(c);
  var rows=new List<Dictionary<string,object?>>(); while(await r.ReadAsync(c)){var row=new Dictionary<string,object?>();for(var i=0;i<n;i++)row[r.GetName(i)]=r.IsDBNull(i)?null:r.GetValue(i);rows.Add(row);} return Results.Ok(rows);
 }
}