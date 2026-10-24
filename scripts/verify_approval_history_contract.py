from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
api=(ROOT/"Modules/SocietyAdmin/RequestedSocietyManagerEndpoints.cs").read_text(encoding="utf-8")
ui=(ROOT/"wwwroot/modules/society-admin/requested-workflows.js").read_text(encoding="utf-8")
i18n=(ROOT/"wwwroot/js/i18n.js").read_text(encoding="utf-8")
html=(ROOT/"wwwroot/modules/society-admin/index.html").read_text(encoding="utf-8")
route=next((x for x in api.splitlines() if 'app.MapGet("/api/sm/approval-history"' in x),"")
assert route,"Approval history API route missing"
assert 'HasPermissionAsync(s.UserId,"AUDIT_APPROVAL","VIEW",c)' in route,"Approval history must require its own VIEW permission"
assert 'where al.society_id=@s' in route,"Approval history must be scoped to the authenticated society"
assert "t_audit_log" in route and "'Approved','Rejected'" in route,"Approval history must derive decisions from persisted audit data, not fabricated records"
for secret in ("password_hash","access_token","api_key","last_login_session_id"):
 assert secret in route,f"Approval payload must redact {secret}"
assert "async function approvalHistory(queryOverride=null)" in ui and "api('/api/sm/approval-history')" in ui,"Approval UI must use the real endpoint"
assert "if(c==='AUDIT_APPROVAL'){approvalHistory();return true}" in ui,"Approval History menu code must route to its module"
assert "No approval history records found." in ui and "No matching approval history records." in ui,"Approval history needs explicit empty/no-match states"
assert "new Intl.DateTimeFormat(Society360I18n.locale()" in ui,"Approval timestamps must be locale-aware"
for lang in ('en','hi','mr','gu','kn','ta'):
 assert f" {lang}:{{'Approval History'" in i18n,f"Approval history translations missing for {lang}"
assert "requested-workflows.js?v=20261024.22" in html and "i18n.js?v=20261024.09" in html,"Approval asset cache keys must be bumped"
print("PASS: approval history uses sanitized society-scoped audit decisions, own permission, localized UI, search and explicit empty states.")
