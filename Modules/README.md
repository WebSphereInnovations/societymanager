# Society360 module structure

- Auth: login, sessions, password and connection protection
- Configuration: society settings, rates, rules, branding and languages
- Residents: flats, owners, tenants and member relationships
- Billing: bill generation, bill lines, arrears, DPC and adjustments
- Collection: payments, allocations, receipts and reversals
- CRM: complaints, follow-up and customer communication
- Parking: slots, vehicles and assignments
- Visitors: security and visitor entries
- Documents: society/customer documents
- Reports: operational and financial reports
- Migration: legacy Excel/CSV import, preview, validation and audit
- Shared Data: PostgreSQL access and common services

New module code should be placed in its module folder instead of mixing unrelated files in the project root.
