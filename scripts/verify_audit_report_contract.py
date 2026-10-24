from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
api = (ROOT / "Modules/SocietyAdmin/RequestedSocietyManagerEndpoints.cs").read_text(encoding="utf-8")
ui = (ROOT / "wwwroot/modules/society-admin/requested-workflows.js").read_text(encoding="utf-8")
html = (ROOT / "wwwroot/modules/society-admin/index.html").read_text(encoding="utf-8")
i18n = (ROOT / "wwwroot/js/i18n.js").read_text(encoding="utf-8")

route = next((line for line in api.splitlines() if 'app.MapGet("/api/sm/audit-log"' in line), "")
assert route, "Audit log API route is missing"
for code in ('"AUDIT_LOG"', '"RPT_AUDIT"', '"SUPER_AUDIT"'):
    assert code in route, f"Audit API must honor {code} permission where assigned"
assert 'where al.society_id=@s' in route, "Audit records must remain restricted to the authenticated society"
for secret in ("password_hash", "last_login_session_id", "access_token", "api_key"):
    assert secret in route, f"Audit response must explicitly redact {secret}"
assert "coalesce(al.old_data,'{}'::jsonb)-ARRAY[" in route and "coalesce(al.new_data,'{}'::jsonb)-ARRAY[" in route, "Sensitive fields must be removed from both old and new audit payloads"
assert "order by al.created_at desc limit 1000" in route, "Audit list must have deterministic newest-first bounded results"
assert "async function auditLog()" in ui and "api('/api/sm/audit-log')" in ui, "Audit UI must use the real database API"
assert "async function loginHistory(queryOverride=null)" in ui and "api('/api/sm/login-history')" in ui, "Login history UI must use the real database API"
assert "t.setFilter(row=>" in ui and "login_ip" in ui and "failure_reason" in ui, "Login history must support OR search across real login fields"
for token in ("'Login name'", "'Old Values'", "'New Values'", "'Search user / action / entity'", "new Intl.DateTimeFormat(Society360I18n.locale()"):
    assert token in ui, f"Audit UI missing expected functionality: {token}"
assert "row[k]??''" in ui and "t.setFilter(row=>" in ui, "Search must perform OR matching across the audit row"
assert "requested-workflows.js?v=20261024.22" in html, "Audit UI cache key is not bumped"
for lang in ('en', 'hi', 'mr', 'gu', 'kn', 'ta'):
    assert f" {lang}:{{'Search user / action / entity'" in i18n, f"Audit search translation missing for {lang}"
print("PASS: audit report UI uses live scoped audit rows, supports RPT_AUDIT/AUDIT_LOG/SUPER_AUDIT permissions, OR-search, localized columns and locale-aware timestamps.")
