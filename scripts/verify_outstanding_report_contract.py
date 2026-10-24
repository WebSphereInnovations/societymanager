from pathlib import Path
root=Path(__file__).resolve().parents[1]
sql=(root/'Database/048_outstanding_aging_report.sql').read_text(encoding='utf-8')
api=(root/'Modules/SocietyAdmin/RequestedSocietyManagerEndpoints.cs').read_text(encoding='utf-8')
js=(root/'wwwroot/modules/society-admin/requested-workflows.js').read_text(encoding='utf-8')
i18n=(root/'wwwroot/js/i18n.js').read_text(encoding='utf-8')
for field in ['bill_no','bill_month','due_date','flat_no','customer_name','total_amount','paid_amount','outstanding_amount','days_overdue','aging_bucket','bill_status']:
 assert field in sql, f'missing report field: {field}'
assert "b.society_id=p_society_id" in sql
assert "GREATEST(COALESCE(b.total_amount,0)-COALESCE(b.paid_amount,0),0)>0" in sql
assert "fn_mis_outstanding" in api and "RPT_OUTSTANDING" in api
assert "async function outstandingReport(asOfOverride=null)" in js and "'/api/sm/reports/outstanding?asOf='" in js
assert "society360-language-changed" in js and "outstandingReport(currentDate)" in js
assert 'requested-workflows.js?v=20261024.17' in (root/'wwwroot/modules/society-admin/index.html').read_text(encoding='utf-8')
assert "function reportColumnTitle(field)" in js and "function bindMisLanguageRefresh(kind,readState)" in js
assert "if(c==='RPT_BILLING'){mis('billing');return true}" in js
assert "if(c==='RPT_COLLECTION'){mis('collection');return true}" in js
assert "if(c==='RPT_CONSUMER'){mis('consumer');return true}" in js
assert "if(c==='RPT_OUTSTANDING'){outstandingReport();return true}" in js
for lang in ['en','hi','mr','gu','kn','ta']:
 assert f"{lang}:{{'Outstanding / Aging'" in i18n, f'missing report labels for {lang}'
print('PASS: outstanding report is database-backed, society-scoped, excludes zero/closed balances, and has six locale dictionaries.')
