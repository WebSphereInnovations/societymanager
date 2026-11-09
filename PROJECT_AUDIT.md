# SKYFY NEXUS — Existing Society360 Project Audit

Audit date: 2026-11-09 (IST)
Local repository: `C:\Users\Delta\Society360`
Local branch: `feature/skyfy-nexus-local-audit` (created from existing local HEAD `06c5cb3`)
GitHub repository: `WebSphereInnovations/societymanager`

## 1. Existing architecture

- **Backend:** ASP.NET Core .NET 8 minimal API. Project: `Society360.csproj`. Installed SDK: 8.0.425.
- **Frontend:** server-served HTML, CSS and vanilla JavaScript. This is not a React application. Do not introduce a framework rewrite for the theme.
- **Data access:** Npgsql. `SocietyDb` reads `SOCIETY360_DB_CONNECTION` (or the `Society360` connection-string key). Existing app runtime is configured and serving on port 5180.
- **Database:** PostgreSQL 18, database/schema `society_manager`, live connection currently resolves to 127.0.0.1:5432. Read-only query succeeded. The old address 192.168.1.11:5432 did not answer from this host; do not change connection configuration without an approved network diagnosis.
- **Security:** cookie authentication, AuthGuard/session validation, role-aware protected page routing, CSRF antiforgery, rate limiting and permission-aware APIs. Keep all checks server-side.
- **Localization:** centralized `Society360I18n` in `wwwroot/js/i18n.js`; configured languages are en, hi, mr, gu, kn, ta.
- **Tables:** Tabulator 6.3.1. Shared CSS exists at `wwwroot/css/tabulator-theme.css`; shared defaults exist at `wwwroot/js/tabulator-defaults.js`; multiple independent constructors remain.
- **Existing presentation:** separate platform, Society Admin, Cashier, Customer and Migration page styling. Standard Theme is not a single isolated stylesheet today; it must be frozen as the baseline before introducing a theme layer.

## 2. Live database inventory (read-only)

- 92 base tables, 0 views, 298 routines in schema `society_manager`.
- 6 societies, 17 users, 6 subscriptions.
- 254 menu/module catalog rows, including 41 root entries.
- 11 roles: ACCOUNTANT, BILLING_ADMIN, CASHIER, COLLECTOR, EMPLOYEE, GUARD, MAINTENANCE, RESIDENT, SECURITY, SOCIETY_ADMIN, SUPER_ADMIN.
- 2,866 permission rows; 5,791 role-permission mappings; 17 user-role mappings; 0 explicit user-permission overrides.
- 6 society branding rows in `m_society_branding`.
- `m_system_setting` currently has no rows.
- `m_subscription_plan.features` is JSONB and existing plans have feature flags; do not assume this alone is sufficient for auditable per-society commercial theme entitlement.

The full 254-row live catalog is captured in `MODULE_INVENTORY.md`.

## 3. Theme and preference findings

No theme-specific column was found in the inspected user, society branding, system setting, subscription, or module schema. No theme selection/persistence implementation was found in the frontend theme-reference scan. `m_society_branding` stores logo and brand color configuration, not a theme identifier. No production schema changes were made.

## 4. Frontend / backend surface inventory

HTML entry pages: 7. CSS files: 11. JS files: 16 under `wwwroot` (excluding browser profiles/temp directories). Backend module C# files: 15. SQL migration scripts: 55.

Role surfaces and key entry points:
- Platform/Super Admin: `wwwroot/index.html`, `wwwroot/js/app.js`, `wwwroot/js/index.js`.
- Society Admin: `wwwroot/modules/society-admin/index.html`; key scripts include admin.js, requested-workflows.js, customer-account.js, billing.js, dashboard.js, navigation-layout.js, account-management.js, security-visitor.js.
- Cashier: `wwwroot/modules/cashier/index.html`.
- Resident/Customer: `wwwroot/modules/customer/index.html`.
- Migration: `wwwroot/modules/migration/index.html` and `migration.js`.
- Login: `wwwroot/login.html`.
- Super Admin security: `wwwroot/super-admin-security.html`.

Backend module groups: Auth, Billing, Cashier/Payment, Customer/Customer360, CustomerAccount, Migration, Platform, SocietyAdmin/OperationalConfig, RequestedSocietyManager and SecurityVisitor.

## 5. Existing source risks / audit notes

- Society Admin live menu is produced by authenticated `GET /api/menu` through `fn_user_module_menu(bigint)`; exact per-user rendered menu still needs a role-by-role authenticated browser capture.
- Several catalogue entries route to a generic Module Workspace; each must be classified as a real page/workflow versus catalog-only/inactive before marking redesign complete.
- Tabulator constructors are spread across admin.js, billing.js, customer-account.js, requested-workflows.js, security-visitor.js, cashier/index.html, customer/index.html and index.js. A shared header policy must account for each.
- The shared Tabulator CSS currently allows wrapped titles but base table overflow and column layout must be checked for clipping and scroll behavior in real grids.
- Inputs are currently styled in multiple page-local style blocks and module CSS; no unified cross-role input sizing token system was identified in this sample.
- Existing progress records show selected module-specific work verified, but explicitly leave full CRUD, all-route localization and visible Chrome acceptance incomplete.

## 6. Runtime / build baseline

- `GET http://127.0.0.1:5180/api/health`: HTTP 200, application online, databaseConfigured true.
- Read-only PostgreSQL connection: successful via the runtime connection string; no writes were executed.
- Baseline Release build to isolated output directory `C:\Society360SkyfyAuditBuild`: succeeded, 0 warnings, 0 errors.
- No application code, database data, or migration was modified in this audit phase.

## 7. Working tree protection

At audit start, local Git reported 291 existing status entries: 5 tracked modified files and 286 untracked files, including user screenshots, diagnostics, progress files and browser artifacts. All were preserved. No reset, clean, stash, checkout or broad staging was run. A new local feature branch was created with the existing working tree carried forward unchanged.

## 8. Remaining audit gaps

- Capture authenticated live `/api/menu` for relevant roles and map all 254 catalog entries to route/view/API/permission.
- Inspect each HTML page and all forms/modals/empty/loading/error states, not only page entry points.
- Inspect every CSS input rule and every Tabulator column definition/constructor for sizing and header clipping.
- Run browser baseline at desktop/tablet/mobile with existing language selector and login/session state.
- Verify theme preference and commercial entitlement schema design against complete FK/index/trigger conventions.
