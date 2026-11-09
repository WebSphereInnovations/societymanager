# SKYFY NEXUS Theme Architecture

## Existing constraints

ASP.NET Core .NET 8 + static HTML/CSS + vanilla JavaScript. Preserve current role entry points and all business logic. Existing standard styling is spread across role-specific CSS and inline style blocks; theme activation therefore needs a controlled shared bootstrap plus namespaced theme styles.

## Proposed runtime model

- Default: `standard`. Existing CSS and behavior remain unchanged when this is selected.
- Commercial: `skyfy-nexus`. New namespaced stylesheet and optional visualization module.
- Backend endpoint returns the authenticated user's allowed themes, active society and selected theme after checking entitlement.
- Theme preference endpoint accepts only a theme the organization is entitled to; it must not accept society identity from the browser as authority.
- Bootstrap applies a root `data-s360-theme` value and loads theme assets only after server authorization. If the endpoint fails, theme is unknown, entitlement expires or rendering fails, use Standard.
- Locale continues to be managed only by Society360I18n. Theme controller must never read/write the language key.
- Add a theme picker only when the user has theme-selection permission and the organization is entitled to SKYFY NEXUS.

## Shared design system

Central tokens: palette, type scale, spacing, radius, elevation, glass surfaces, depth, input height, input padding, button variants, table header sizing, modal layout, animation timings, responsive breakpoints, focus and reduced-motion behavior.

Shared visual components: application shell, sidebar/header, breadcrumbs, cards/KPIs, forms, Tabulator wrappers, dialogs, toasts, empty/loading/error states, chart containers and building visualization container.

## 3D strategy

- Use a lightweight Three.js module only after CSP, asset hosting, bundle and browser support checks. Do not add React Three Fiber to a vanilla JS project.
- Load one optimized building scene lazily on the dashboard and selected building/floor contexts; not on every form.
- Use API-backed counts/status for occupancy and operational indicators. Geometry may be illustrative, but never invent society data.
- Cap pixel ratio, pause offscreen rendering, dispose resources, honor prefers-reduced-motion, and provide CSS/isometric fallback when WebGL is unavailable.
- All building/floor/flat interaction must have keyboard-accessible non-3D alternatives.

## Theme and language independence

Store theme preference separately from `m_user.preferred_language` and existing i18n local/session state. Theme switching must not reset locale; locale switching must not reset theme.


## Phase 2 decisions — theme access contract

- Permission namespace: `THEME_PREFERENCES` with `VIEW`, `UPDATE`, `MANAGE`. Existing `AuthService.HasPermissionAsync` is the enforcement point. Initial grants: Society Admin receives VIEW/UPDATE; Super Admin receives VIEW/UPDATE/MANAGE. Other roles receive no default theme access; the existing role-rights system can grant it later.
- User theme preference is scoped by `(user_id,society_id)` and has a composite FK to `m_user_society`; this prevents storing a preference for an organization the user is not a member of.
- Organization commercial entitlement is separate from user preference. A user preference cannot grant access.
- Standard is always the fallback. SKYFY NEXUS is offered only if the current society has a valid active entitlement and the user has VIEW permission.
- Preference writes require UPDATE permission, current session society scope and a valid entitlement for commercial themes.
- Entitlement management requires MANAGE permission and is restricted to Super Admin.
- API contract: `GET /api/theme/options`, `PUT /api/theme/preference`; platform management endpoints will expose entitlement list/activation/deactivation under Super Admin authorization. Mutating requests must validate antiforgery tokens.
- Theme preference changes never update `m_user.preferred_language` or any i18n storage key.

## Migration draft

`Database/051_skyfy_nexus_theme_entitlements.sql` creates the theme catalog/configuration, society entitlement and user preference tables, role permissions, audit/stamp triggers and `fn_skyfy_theme_is_entitled`. Matching rollback script is `Database/051_skyfy_nexus_theme_entitlements_rollback.sql`. Both were tested together in one read-only-in-effect transaction that was rolled back; neither has been applied to the live schema.


## Implemented foundation — 2026-11-09

- Server-side APIs now expose theme options, per-user/per-society preference persistence, and Super Admin entitlement list/activation/deactivation.
- API access uses AuthGuard, existing role/action permission checks and antiforgery validation for mutations.
- The theme bootstrap loads only after authenticated API options return. It uses database preferences, does not use localStorage, and falls back to Standard on failures.
- Theme picker labels are translated through the existing six-language i18n runtime.
- `theme-controller.css` styles only the new picker. `skyfy-nexus.css` is fully namespaced under `html[data-s360-theme="skyfy-nexus"]`, so Standard styling is not overridden.
- Six authenticated page entry points load the controller; login remains unchanged.
- The visual layer currently provides dark glass surfaces, shared input/button/table styling, responsive behavior, reduced-motion rules and a reusable CSS 3D building primitive. The building primitive is not yet wired to live dashboard data.


## Dashboard visual module

`wwwroot/js/skyfy-dashboard.js` listens for the authorized theme-applied event and adds a dedicated Society Admin visual panel after the existing dashboard hero. It does not alter `dashboard.js`, dashboard API contracts, filters, totals or drilldowns. The building picker mirrors the existing database-populated `#dashBuilding` filter and reloads the existing analytics. Displayed values are read from the existing dashboard's rendered API-backed metrics. The 3D tower geometry is illustrative only; no synthetic floor, apartment, occupancy or visitor records are created. CSS 3D keeps this scene lightweight and WebGL-independent.


## Login and in-app preference experience

The theme trigger is inserted immediately after the language selector. On `login.html`, the controller reads only the anonymous active-theme catalog and applies a browser-local visual preview; it stores the selected theme in `society360-guest-theme`. After authentication, `/api/theme/options` supplies the full active catalog plus a per-society `isAvailable` flag. The guest selection is saved through the existing CSRF-protected preference endpoint only when the signed-in user has UPDATE permission and the society is entitled. Otherwise the authenticated saved preference (normally Standard) is applied and the commercial card remains visible but locked.

The theme gallery is a centered accessible dialog. Society Admin also receives a `Society Manager Preferences` navigation group with `Navigation Settings` and `Themes`. Navigation Settings is a centered dialog for left/right/top layout and compact sidebar mode. Navigation layout/collapse continue to use the existing browser-local preference keys; theme preference remains account + society scoped in PostgreSQL.
