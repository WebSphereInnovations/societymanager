# SKYFY NEXUS Remaining Tasks

## Phase 1 — audit

- [ ] Capture authenticated `/api/menu` result for each available role, preserving role permissions.
- [ ] Map all 254 catalog codes to actual route/view/API and mark implemented, partial, catalog-only or inactive.
- [ ] Inspect every page's form controls, modals, validation, loading, empty and error states.
- [ ] Enumerate CSS input rules and normalize only inside the SKYFY layer.
- [ ] Enumerate Tabulator columns and check clipping/scroll behavior across all constructors.
- [ ] Capture desktop/tablet/mobile Standard Theme baseline and current language switching.
- [ ] Review all relevant FK/index/trigger/migration conventions.

## Phase 2 — architecture

- [ ] Finalize theme master, society entitlement/activation, user preference and configuration schema.
- [ ] Decide how subscription plan features connect to theme entitlement.
- [ ] Define secure API contracts and server-side authorization.
- [ ] Write additive reversible migration and rollback plan; do not apply until reviewed.

## Phases 3–12

- [ ] Isolated theme bootstrap and Standard fallback.
- [ ] SKYFY NEXUS design tokens and shared component layer.
- [ ] Theme picker and database persistence.
- [ ] Premium dashboard with real API metrics and optimized building scene.
- [ ] Every active route across platform, Society Admin, Cashier, Resident and Migration.
- [ ] Full Tabulator header wrapping/scroll fix without breaking server-side paging/export.
- [ ] Six-language translation coverage for every new string.
- [ ] Commercial entitlement and organization activation.
- [ ] Responsive, reduced-motion and no-WebGL fallback.
- [ ] Full authentication, role, tenant, CRUD, DB, theme, language and performance regression.
- [ ] Final delivery report and preview instructions.

## Current blockers

- Live authenticated menu capture for each role is not yet recorded.
- Visible Chrome page-by-page acceptance is not yet performed.
- Database theme migration is only proposed; no schema change has been made.


## Additional audit gaps

- [ ] Obtain authorized test sessions for CASHIER, COLLECTOR, GUARD, SECURITY, ACCOUNTANT, BILLING_ADMIN, EMPLOYEE and MAINTENANCE roles before role-by-role visual acceptance.
- [ ] Complete visible browser baseline; the current remote toolset has no visible browser-control action and no Chrome CDP debug port is listening.
- [ ] Review the full API-to-view route map and all form/modal event handlers before any module-level theme changes.


## Phase 2 / Phase 3

- [ ] Implement `GET /api/theme/options` and `PUT /api/theme/preference` using AuthGuard, HasPermissionAsync and antiforgery validation.
- [ ] Implement Super Admin entitlement list/activate/deactivate endpoints.
- [ ] Compile and test API contracts against a disposable test schema/database before applying migration 051 to the working DB.
- [ ] Implement the theme bootstrap/controller and keep Standard as fallback.
- [ ] Only then add theme assets to the role pages.


## Current next implementation steps

- [ ] Build the Super Admin entitlement management screen on top of the new protected endpoints.
- [ ] Exercise authenticated theme options and preference persistence using a valid authorized browser session.
- [ ] Build the SKYFY NEXUS dashboard with actual Society360 dashboard API metrics and a lazy, optimized building scene.
- [ ] Complete shared page shell/sidebar/header/card/modal/empty/loading/error styles for each role surface.
- [ ] Map and redesign every active route and inner workflow; no generic workspace may be marked complete without evidence.
- [ ] Implement the project-wide Tabulator header fix in shared defaults and all independent constructors, including Standard Theme regression.
- [ ] Verify all six languages in both themes, including dynamically injected controls and long labels.
- [ ] Complete desktop/tablet/mobile and reduced-motion/WebGL fallback checks.
- [ ] Run authenticated CRUD, role, tenant-isolation, export, report and API regression.
