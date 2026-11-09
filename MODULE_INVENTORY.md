# SKYFY NEXUS — Module and Page Inventory

Source of truth for this checkpoint: `SOCIETY360_MODULE_INVENTORY.md`, `SOCIETY360_FUNCTIONALITY_MANUAL.md`, repository tree and sampled HTML/JS. Exact live menu count is **not yet verified**; this file deliberately does not invent one.

## Application surfaces

| Surface | Entry point | Scope |
|---|---|---|
| Platform / Super Admin | `wwwroot/index.html`, `wwwroot/js/index.js` | Platform dashboard, societies, subscriptions, platform billing and access/configuration |
| Society Admin | `wwwroot/modules/society-admin/index.html` | Dashboard and society operations; database-driven menu |
| Cashier | `wwwroot/modules/cashier/index.html` | Billing, collection, customer search, receipt and reports |
| Resident / Customer | `wwwroot/modules/customer/index.html` | Own account, bills, complaints |
| Migration | `wwwroot/modules/migration/index.html` | Import preview and migration |
| Super Admin Security | `wwwroot/super-admin-security.html` | Protected Super Admin security controls |
| Login | `wwwroot/login.html` | Authentication and language selector |

## Society Admin source-defined views

Existing inventory identifies 14 view sections: `home`, `customers`, `flats`, `bills`, `collection`, `complaints`, `visitors`, `parking`, `security`, `configuration`, `billing-configuration`, `billing-process`, `module-workspace`, `accounts`.

These are source view sections, not a count of live menu items. The live tree is loaded from `/api/menu` and must be captured using an authenticated session.

## Module families requiring page-by-page theme coverage

- Dashboard and analytics
- Customer Account / Consumer 360
- Society profile, buildings, wings, flats, residents, owners, tenants and family
- Billing configuration, billing process, bill register, adjustments, charges and reports
- Collection, payments, service payments, receipts, reversals, bank details and dishonoured cheques
- Complaints and service requests
- Visitors, security, gate and staff workflows
- Parking, vehicles, slots and assignment
- Administrator accounts, roles, permissions, subscription and module/submodule catalog
- Documents, notices, meetings and related workspace features
- Migration/import
- Audit trail, login/session audit, approval history and governance
- MIS and exports

## Inventory status

All families above require mapping from each live menu leaf to route, view, JS handler, API endpoint, database object, permission and translation keys. Generic `module-workspace` fallback entries must not be marked complete without a dedicated functional implementation and evidence.

Detailed acceptance gaps remain in `SOCIETY360_MODULE_INVENTORY.md` and `SOCIETY360_FUNCTIONALITY_MANUAL.md`.
