# SKYFY NEXUS Testing Report

## Baseline checks performed 2026-11-09

| Check | Result | Evidence |
|---|---|---|
| Sandman device | PASS | Device online |
| Local repository | PASS | `C:\Users\Delta\Society360` |
| Git preservation | PASS | 291 pre-existing status entries preserved; no cleanup/reset |
| .NET SDK | PASS | 8.0.425 |
| Runtime health | PASS | `/api/health` returned HTTP 200; application online and DB configured |
| PostgreSQL read-only connection | PASS | Runtime connection string connected to local PostgreSQL; read-only transaction rolled back |
| DB inventory | PASS | 92 tables, 298 routines, 254 modules, 11 roles, 2,866 permissions |
| Release baseline build | PASS | Isolated output build succeeded, 0 warnings, 0 errors |
| Standard theme baseline | NOT COMPLETE | No full visible Chrome comparison yet |
| Theme switch / entitlement | NOT IMPLEMENTED | Later phases |
| Six-language dual-theme test | NOT RUN | No theme code yet |
| All routes / role menus | PARTIAL | Catalog captured; authenticated role-specific menu capture pending |
| Tabulator full header acceptance | NOT RUN | Constructors identified; live grids not visually tested |
| Desktop/tablet/mobile | NOT RUN | Requires full page visual pass |

## Safety

Database inspection ran inside read-only transactions. No production data was inserted, updated or deleted. No schema migration was applied. Existing app process on port 5180 was not stopped or restarted.


## Expanded audit evidence

- [x] Live menu function: role-filtered outputs queried read-only for the three role codes with active user records.
- [x] HTML page control counts recorded for all seven page entry points.
- [x] API route declaration scan: 158 across 10 endpoint files.
- [x] Schema migration convention inspected: numbered SQL scripts are applied outside the runtime MigrationService; no schema-migration ledger table was found in the inspected schema.
- [ ] Visible Chrome comparison is still not performed; remote tooling exposes shell/file operations but no visible browser mouse/keyboard/screenshot action. CDP ports 9222, 9333, 9334 and 9335 were unavailable.


## Phase 2 migration validation

- [x] Migration 051 DDL executed in a transaction: table creation, indexes, triggers, permissions, role grants and entitlement function all succeeded.
- [x] Rollback script executed in the same transaction: permissions, tables and functions removed successfully.
- [x] Outer transaction rolled back; post-check found no theme tables or permission rows persisted.
- [ ] Migration has not been applied to the live database.


## Latest implementation and runtime validation — 2026-11-09

| Test | Result | Evidence |
|---|---|---|
| Pre-migration database backup | PASS | Custom-format schema backup created outside repo, 2,899,561 bytes |
| Migration 051 | PASS | Applied to configured `society_manager` database |
| Migration rollback | PASS | Transactional up/down test passed; live schema was not removed |
| Entitlement function | PASS | Standard true; SKYFY false without active entitlement |
| No automatic paid grants | PASS | 0 entitlement rows and 0 user preferences |
| Entitlement audit triggers | PASS | Transaction-only insert generated two audit events; transaction rolled back |
| Release build | PASS | 0 warnings, 0 errors |
| Theme controller JS syntax | PASS | `node --check` |
| i18n JS syntax | PASS | `node --check` |
| Health endpoint | PASS | `192.168.1.8:5180/api/health` HTTP 200 |
| Theme options unauthenticated | PASS | HTTP 401 |
| Entitlement list unauthenticated | PASS | HTTP 401 |
| Theme JS/CSS static assets | PASS | HTTP 200 |
| Authenticated preference save | NOT RUN | No authenticated browser session exercised |
| Super Admin entitlement UI workflow | NOT RUN | API exists; UI not yet built |
| Visible Chrome visual comparison | NOT RUN | CDP ports unavailable; no visible browser control tool exposed |
| Full page/module/3D/Tabulator regression | NOT RUN | Remaining phases |

The new backend/API and CSS layer are a foundation only; this does not certify the commercial theme or all modules complete.


## Dashboard component smoke test

A temporary, isolated fixture was served locally and tested with headless Chrome using mocked theme API responses and sample DOM values. Verified:
- SKYFY theme event inserts the dashboard building component.
- Six metric values bind from the existing dashboard DOM.
- Building selection updates the existing API-backed filter and calls the existing dashboard reload function.
- Language-change event updates the component label.
- Switching to Standard removes the 3D component; switching back to SKYFY recreates it.
- Theme preference PUT flow is invoked in the mocked browser fixture.

The temporary fixture and browser profile were removed after the test. This is a frontend logic smoke test only, not authenticated Chrome acceptance or verification against a live society's dashboard values.


## Permission integration test correction

The first permission-function test returned false for all roles because the existing `fn_user_permissions` implementation requires an active `m_module` catalog row. Migration 051 was corrected to seed a hidden active `THEME_PREFERENCES` module row (`visible=false`) and the rollback removes it. After reapplying the migration:
- Society Admin: VIEW=true, UPDATE=true, MANAGE=false.
- Super Admin: VIEW=true, UPDATE=true, MANAGE=true.
- Collector and Resident: all false.
- Visible menu function exposes zero `THEME_PREFERENCES` menu entries.

This correction is included in the current migration file and live database.


## Theme and navigation preferences QA — 2026-11-09

| Check | Result |
|---|---|
| JavaScript syntax for theme controller, navigation layout and i18n | PASS |
| .NET 8 build after theme catalog and availability endpoint changes | PASS — 0 warnings, 0 errors |
| Public theme catalog endpoint | PASS — HTTP 200; active Standard and SKYFY entries returned |
| Authenticated options endpoint without a session | PASS — HTTP 401 (protected) |
| Pre-login Chrome theme button beside language selector | PASS |
| Pre-login gallery lists Standard and SKYFY; selecting SKYFY applies preview and stores guest preference | PASS |
| Authenticated eligible mock session transfers guest SKYFY selection via preference PUT and clears guest preference | PASS |
| Authenticated non-entitled mock session falls back to Standard, does not save SKYFY, and shows SKYFY locked | PASS |
| Society Manager Preferences menu and both submenus | PASS |
| Centered Navigation Settings modal and left/right/top choices | PASS |
| Theme submenu opens centered theme gallery | PASS |
| Six-language translation codepoint audit | PASS |
| Responsive modal width at tested 500 CSS-pixel viewport | PASS — dialog width 480 px |
| Actual user-authenticated live Chrome session | PENDING |

The browser fixtures used isolated temporary HTML files and deterministic mocked authenticated responses for entitlement/save-flow coverage. The real API's public catalog and unauthenticated protection status were separately checked against the running local app. No society entitlement or user preference records were changed by the test fixtures.

The actual local `/login.html` (not only the isolated fixture) was opened in headless Chrome after the final asset cache version update. DOM assertions confirmed the login form, language selector, and dynamically inserted theme trigger were all present. The isolated fixture remains the interaction test for selecting and applying a guest preview.
