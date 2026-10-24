from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
html = (ROOT / "wwwroot/modules/society-admin/index.html").read_text(encoding="utf-8")
js = (ROOT / "wwwroot/modules/society-admin/dashboard.js").read_text(encoding="utf-8")
sql = (ROOT / "Database/041_dashboard_analytics.sql").read_text(encoding="utf-8")

match = re.search(r'<article class="dash-kpi kpi-period-outstanding">(.*?)</article>', html, re.S)
assert match, "Selected-period total KPI card is missing"
card = match.group(1)
assert 'data-i18n="Total outstanding (period)"' in card, "Selected-period total label is missing"
assert 'id="kpiPeriodOutstanding"' in card, "Selected-period total value target is missing"
assert 'Billed amount' not in card, "Redundant Billed amount subtitle must stay hidden"
assert "$('#kpiPeriodOutstanding').textContent=money(s.billedAmount);" in js, "KPI must show database-provided full period billed total, including paid bills"
assert "(SELECT COALESCE(sum(total_amount),0) FROM bill_scope) AS billed_amount" in sql, "Period total must aggregate actual bill totals"
assert "(SELECT COALESCE(sum(balance_amount),0) FROM bill_scope) AS period_outstanding" in sql, "Period unpaid balance must remain a separate API metric"
assert "(SELECT COALESCE(sum(GREATEST(COALESCE(total_amount,0)-COALESCE(paid_amount,0),0)),0) FROM all_open_bills) AS current_outstanding" in sql, "Current outstanding must remain based on unpaid open-bill balances"
assert "'billedAmount', billed_amount" in sql and "'periodOutstanding', period_outstanding" in sql and "'currentOutstanding', current_outstanding" in sql, "API contract must expose distinct period total and balance metrics"
print("PASS: period total card shows the database-backed full billed total; redundant subtitle is absent; period and current balances remain distinct.")
