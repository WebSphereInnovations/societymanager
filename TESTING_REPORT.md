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
