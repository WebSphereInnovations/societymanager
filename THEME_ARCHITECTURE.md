# SKYFY NEXUS Theme Architecture

## Existing application constraints

The app is ASP.NET Core .NET 8 with server-served HTML/CSS/vanilla JS, not an existing React application. Avoid introducing React Three Fiber as a framework rewrite. A lightweight Three.js module may be considered only after bundle, CSP, hosting and performance compatibility are checked.

## Proposed separation

- `standard`: existing CSS and rendering remain the default baseline.
- `skyfy-nexus`: namespaced design tokens and components under a separate theme stylesheet/module.
- Shared business workflow code and API contracts remain theme-neutral.
- Theme resolver obtains the allowed theme from an authenticated backend endpoint. Client cannot self-grant commercial access.
- A single theme controller applies a root theme attribute/class and loads only the selected theme assets.
- If entitlement lookup fails, selected theme is invalid, or WebGL is unavailable, use Standard / CSS fallback without blocking the application.
- Theme preference and language preference remain separate. Language changes continue exclusively through `Society360I18n`.

## Design system domains

Tokens: color, typography, spacing, radius, elevation, depth, input sizing, buttons, surfaces, breakpoints, animation duration and focus rings.

Components: shell/sidebar/header, cards, KPI widgets, forms, Tabulator wrappers, dialogs, alerts, empty/loading/error states, charts and visualization containers.

## 3D and motion strategy

- Use one optimized hero building scene where it adds value; prefer CSS/isometric fallback on low capability or reduced-motion devices.
- No fabricated building occupancy or operational statistics. Geometry may be illustrative, but labels/status/counts must bind to real API data.
- Lazy-load scenes only when visible; cap device pixel ratio; dispose geometries/materials/renderers; pause offscreen animations.
- Honor `prefers-reduced-motion`; support keyboard-accessible 2D selection alternatives.
- Avoid a 3D scene on every form/table page. Use it selectively for dashboard, building/wing/floor/flat navigation and facility status.

## Pending decisions

Theme state storage model, exact API endpoint, entitlement table reuse, asset bundling and CSP/WebGL policy require Phase 2 review. No implementation has begun.
