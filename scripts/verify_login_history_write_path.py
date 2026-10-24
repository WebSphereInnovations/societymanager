from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
api = (ROOT / "Modules/Auth/AuthService.cs").read_text(encoding="utf-8")
program = (ROOT / "Program.cs").read_text(encoding="utf-8")
endpoint = (ROOT / "Modules/SocietyAdmin/RequestedSocietyManagerEndpoints.cs").read_text(encoding="utf-8")
ui = (ROOT / "wwwroot/modules/society-admin/requested-workflows.js").read_text(encoding="utf-8")
i18n = (ROOT / "wwwroot/js/i18n.js").read_text(encoding="utf-8")
html = (ROOT / "wwwroot/modules/society-admin/index.html").read_text(encoding="utf-8")
migration = (ROOT / "Database/042_login_history_write_path.sql").read_text(encoding="utf-8")

assert "sp_record_login_success_v2" in api and "sp_record_login_failure_v2" in api, "Authentication must use unambiguous v2 login-audit procedures"
assert "session_id" not in api[api.index("RecordLoginSuccessAsync"):api.index("RecordLoginFailureAsync")], "Session identifiers must not be stored as login-history trace IDs"
assert program.count("RecordLoginSuccessAsync(") == 2, "Both login entry points must use the updated login-audit writer"
assert "ADD COLUMN IF NOT EXISTS society_id bigint" in migration and "ix_user_login_history_society_created" in migration, "Migration must add indexed society scope to history"
assert "INSERT INTO society_manager.t_user_login_history" in migration and "INSERT INTO society_manager.t_user_login_audit" in migration, "Migration must persist events and maintain the per-user summary"
assert "login_count = GREATEST(" in migration, "Migration must preserve the existing login count when initializing the summary table"
route = next((line for line in endpoint.splitlines() if 'app.MapGet("/api/sm/login-history"' in line), "")
assert "where h.society_id=@s" in route, "Login history reads must scope by stored society ID, including known-user failed attempts"
assert "No login history records found." in ui and "No matching login history records." in ui, "Login history must show meaningful empty and no-match states"
assert "savedQuery=queryOverride" in ui and "loginHistory($('#loginQ')?.value||'')" in ui, "Search text must survive refresh and language changes"
for lang in ('en', 'hi', 'mr', 'gu', 'kn', 'ta'):
    assert f" {lang}:{{'No login history records found.'" in i18n, f"Empty-state translation missing for {lang}"
assert "requested-workflows.js?v=20261024.22" in html and "i18n.js?v=20261024.09" in html, "Login-history cache keys must be refreshed"
print("PASS: login event writes use explicit procedures; society-scoped history and per-user count are preserved; UI search, empty states and six-language resources are wired.")
