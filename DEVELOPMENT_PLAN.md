# SKYFY NEXUS — Development Plan

## Guardrails

- Keep the existing Standard Theme as the default and preserve its current rendering and behavior.
- Do not rewrite ASP.NET Core/vanilla JS into React.
- Shared business workflows and API contracts remain theme-neutral.
- Theme and language are independent. Only `Society360I18n` owns language state.
- Theme availability is decided by authenticated backend entitlement, never by a client flag.
- No mock operational statistics. Dashboard data must come from current APIs.
- No destructive database operation or financial write for visual acceptance.
- Do not stage/commit any pre-existing user changes as part of SKYFY work.

## Ordered phases and exit criteria

| Phase | Work | Exit criteria | Status |
|---|---|---|---|
| 1 | Full project audit | Route/menu/API/DB/role/i18n/table inventory and baseline tests | In progress — source and DB audit checkpoint captured; authenticated role-by-role route and visual sweep remain |
| 2 | Architecture/database planning | Reviewed theme model, API contract, migration + rollback plan | In progress — proposed design documented; final schema review pending |
| 3 | Theme foundation | isolated loader, Standard fallback, server-authorized selection | Not started |
| 4 | Design system | tokens and shared input/button/card/table/modal/navigation styles | Not started |
| 5 | Dashboard | responsive premium dashboard, real API data, optimized building visual | Not started |
| 6 | All modules | every live route and role page themed with workflow regression | Not started |
| 7 | Tabulator | all grids show full headers and retain sorting/filter/paging/export | Not started |
| 8 | Localization | all new labels in six languages, dual-theme regression | Not started |
| 9 | Commercial entitlement | database entitlement, activation, organization and user preference | Not started |
| 10 | Responsive/performance | desktop/tablet/mobile, reduced-motion, no-WebGL fallback | Not started |
| 11 | Complete testing | authentication, permission, tenant, CRUD, DB, i18n, theme tests | Not started |
| 12 | Delivery | final report, known issues, preview/run instructions | Not started |

## Immediate next actions

1. Finish page-level inventory and authenticated menu capture for all available roles.
2. Review database constraints, foreign keys, indexes, migration runner and subscription assignment semantics.
3. Finalize architecture and reversible migration proposal.
4. Only after audit exit, implement the isolated theme resolver and static theme assets.
