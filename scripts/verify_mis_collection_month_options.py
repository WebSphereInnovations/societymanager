from pathlib import Path
root=Path(__file__).resolve().parents[1]
sql=(root/"Database/050_mis_report_specific_month_options.sql").read_text(encoding="utf-8")
js=(root/"wwwroot/modules/society-admin/requested-workflows.js").read_text(encoding="utf-8")
html=(root/"wwwroot/modules/society-admin/index.html").read_text(encoding="utf-8")
program=(root/"Program.cs").read_text(encoding="utf-8")
assert "CREATE OR REPLACE FUNCTION society_manager.fn_mis_filter_options(p_society_id bigint)" in sql
assert "FROM society_manager.t_bill b" in sql and "FROM society_manager.t_payment p" in sql
assert "'BILL_MONTH'::varchar" in sql and "'PAYMENT_MONTH'::varchar" in sql and "'MONTH'::varchar" in sql
assert "row_number() OVER(ORDER BY x.month_start DESC)::integer" in sql
assert "p.society_id=p_society_id" in sql and "b.society_id=p_society_id" in sql
assert "monthGroup=k==='billing'?'BILL_MONTH':k==='collection'?'PAYMENT_MONTH':'MONTH'" in js
assert "months.find(x=>String(x.option_code)===currentMonthCode)" in js
assert "[...months].sort((a,b)=>String(b.option_code).localeCompare(String(a.option_code)))[0]?.option_code" in js
assert 'requested-workflows.js?v=20261024.17' in html
assert '--apply-mis-report-specific-month-options' in program and '050_mis_report_specific_month_options.sql' in program
print("PASS: MIS reports use distinct society-scoped bill/payment month lists, combined MONTH remains available, and UI defaults to current/latest within each report's own month set.")
