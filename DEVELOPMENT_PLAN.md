# SKYFY NEXUS Development Plan

## Guardrails

- Preserve Standard Theme and every existing route/API/business rule.
- Implement a separate SKYFY NEXUS presentation layer; do not fork or replace application workflows.
- Theme and language are independent state dimensions. Language remains owned by `Society360I18n`.
- Theme access is server-authorized and organization-entitlement-backed; client state is presentation only.
- No fabricated operational statistics. All dashboard data comes from existing authenticated APIs.
- No production financial writes during visual/theme acceptance.
- No migration is applied until schema compatibility and rollback strategy are reviewed.

## Ordered phases

| Phase | Scope | Exit evidence | Status |
|---|---|---|---|
| 1 | Full repository/runtime/database/module audit | Inventory of routes, menus, APIs, DB objects, roles, translations, tables and baseline tests | In progress — source audit checkpoint only |
| 2 | Architecture and database plan | ADR, entity mapping, migration/rollback review | Pending |
| 3 | Isolated theme foundation | Theme tokens, loader, permission-aware selection and fallback | Pending |
| 4 | Design system | Shared inputs, buttons, cards, tables, dialogs, navigation | Pending |
| 5 | Dashboard | Database-backed premium dashboard and optimized building visualization | Pending |
| 6 | All modules and role surfaces | Page-by-page coverage matrix and regression evidence | Pending |
| 7 | Tabulator headers | All initialization sites and full-header acceptance | Pending |
| 8 | Localization | Six-language coverage in both themes | Pending |
| 9 | Commercial entitlements | Server-side entitlement, organization assignment, user preference, audit | Pending |
| 10 | Responsive/performance | Desktop/tablet/mobile, reduced motion, fallback and performance evidence | Pending |
| 11 | Complete testing | Auth, permissions, APIs, DB, theme, locale and workflow regression | Pending |
| 12 | Delivery | Reports, run/preview instructions, known issues and release checkpoint | Pending |

## Immediate next actions

1. Complete runtime identity verification using only the user's required Desktop Commander account.
2. Capture authenticated live menu tree and role/permission matrix.
3. Inspect all Tabulator construction sites and CSS loading order.
4. Inspect schema and existing user/organization preference patterns read-only.
5. Baseline Release build and existing smoke tests before changing code.
