from pathlib import Path
import re
root=Path(__file__).resolve().parents[1]
sql=(root/'Database/047_collection_receipt_details.sql').read_text(encoding='utf-8')
api=(root/'Modules/SocietyAdmin/RequestedSocietyManagerEndpoints.cs').read_text(encoding='utf-8')
js=(root/'wwwroot/modules/society-admin/requested-workflows.js').read_text(encoding='utf-8')
i18n=(root/'wwwroot/js/i18n.js').read_text(encoding='utf-8')
assert 'CREATE OR REPLACE FUNCTION society_manager.fn_payment_receipt_details' in sql
for required in ['maintenance_amount','parking_amount','sinking_fund_amount','arrear_amount','dpc_amount','interest_arrear_amount','other_charge_amount','tax_amount','rebate_amount','society_address','society_phone','society_email','bill_allocations','charge_breakdown']:
 assert required in sql, f'missing receipt data field: {required}'
assert 'sum(allocated_amount)' in sql and 'allocated_amount' in sql
assert 'fn_payment_receipt_details(@s,@p)' in api
assert "x.charge_breakdown" in js and "x.bill_allocations" in js
assert 'JSON.parse(v)' in js, 'PostgreSQL jsonb values serialized as strings must be parsed before rendering'
assert 'requested-workflows.js?v=20261024.10' in (root/'wwwroot/modules/society-admin/index.html').read_text(encoding='utf-8')
assert "Total Allocated" in js and "Amount Received" in js
for lang in ['en','hi','mr','gu','kn','ta']:
 assert re.search(rf'\b{lang}:\{{',i18n), f'missing locale {lang}'
for label in ['Charge Breakdown','Bill Allocations','Maintenance','Parking','Sinking Fund','Arrears','DPC','Other Charges']:
 assert label in i18n, f'missing translated receipt label {label}'
print('PASS: receipt details contract covers society metadata, payment identity, actual bill allocations, component breakdown and six locale dictionaries.')
