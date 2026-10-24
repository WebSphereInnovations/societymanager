from pathlib import Path
root=Path(__file__).resolve().parents[1]
src=(root/"Modules/SocietyAdmin/SocietyAdminEndpoints.cs").read_text(encoding="utf-8")
admin=(root/"wwwroot/modules/society-admin/admin.js").read_text(encoding="utf-8")
html=(root/"wwwroot/modules/society-admin/index.html").read_text(encoding="utf-8")
for code in ["MIS_CONSUMER_MASTER","MIS_BILLING_DATA","MIS_COLLECTION_DETAILS","MIS_COMPLAINT_HISTORY","RPT_OUTSTANDING","RPT_BILLING","RPT_COLLECTION","RPT_CONSUMER","RPT_AUDIT"]:
 assert f'"{code}" => "{code}"' in src, f"Missing export permission mapping for {code}"
assert 'HasPermissionAsync(session.UserId,module,"EXPORT",ct)' in src
assert 'Export is not enabled for this table.' in src
assert "setTimeout(()=>URL.revokeObjectURL(url),5000);" in admin, "Blob URL must remain valid long enough for Chrome to finish downloading the workbook"
assert "a.click();a.remove();URL.revokeObjectURL(url);" not in admin, "Immediate blob URL revocation can leave an incomplete .crdownload file"
assert 'admin.js?v=20261024.03' in html, "Browser cache key must change after the export feedback fix"
assert 'i18n.js?v=20261024.06' in html, "Browser cache key must change after the localized export notice was added"
assert "Export prepared. If no file appears, check Chrome Download history." in admin
assert "Society360I18n.translateText('Export prepared. If no file appears, check Chrome Download history.')" in admin
for lang in ['en','hi','mr','gu','kn','ta']:
 assert f"{lang}:{{'Export prepared. If no file appears, check Chrome Download history.'" in (root/'wwwroot/js/i18n.js').read_text(encoding='utf-8'), f'missing localized export notice for {lang}'
print("PASS: report export permissions are mapped and enforced server-side; workbook blob URL is revoked after a 5-second download grace period.")
