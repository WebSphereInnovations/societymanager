# SKYFY NEXUS Remaining Tasks

## Phase 1 — audit (open)

- [ ] Confirm Desktop Commander identity is exactly `rahulp@elinktechnologies.net`; do not use another account.
- [ ] Inspect local git status, branches, uncommitted files and latest local commit without reset/clean.
- [ ] Verify running app, ports and build output.
- [ ] Read-only DB catalog: organizations/societies, users, roles, permissions, subscriptions, entitlements, preference tables, audit conventions.
- [ ] Capture authenticated live `/api/menu` tree for each relevant role.
- [ ] Enumerate every route, submenu, API handler, CRUD workflow and translation key.
- [ ] Enumerate every Tabulator constructor, shared default and CSS source.
- [ ] Record baseline build, API smoke and visible Chrome results.

## Phase 2 — architecture

- [ ] Decide reuse versus new tables for theme catalog, entitlement, organization assignment and user preference.
- [ ] Define API contracts and backend authorization.
- [ ] Define reversible migration and fallback behavior.
- [ ] Define CSS/asset loading strategy across every role surface.

## Implementation and acceptance

- [ ] Build isolated SKYFY NEXUS theme foundation.
- [ ] Implement shared commercial design system.
- [ ] Implement database-backed theme switch and entitlement.
- [ ] Redesign dashboard with real API data and optimized building visualization.
- [ ] Redesign every live menu/submenu and role-specific page.
- [ ] Fix every Tabulator header and verify all table actions.
- [ ] Complete six-language translations for all new UI.
- [ ] Test desktop/tablet/mobile and reduced-motion/WebGL fallback.
- [ ] Run security, CRUD, data persistence, permissions and tenant-isolation regression.
- [ ] Publish detailed final report and preview/run instructions.

## Blocker

Runtime and database inspection are pending. Do not mark Phase 1 complete or start production schema changes until these checks are available.
