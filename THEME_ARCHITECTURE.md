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
