# SKYFY NEXUS Database Change Register

## Existing database facts

PostgreSQL 18; database/schema `society_manager`. Read-only snapshot: 92 base tables, 298 routines, 6 societies, 17 users, 6 subscriptions, 254 module catalog rows. Existing migration convention is numbered SQL scripts under `Database/`; 55 SQL scripts were found.

Existing relevant structures:
- `m_society_branding`: society logo and brand colors; six records; no theme identifier.
- `m_society_subscription` and `m_subscription_plan`: subscription linkage and plan feature JSONB.
- `m_system_setting`: key/value setting table; currently zero rows.
- `m_user`: preferred_language exists; no theme preference.
- `m_module`, `m_permission`, `m_role_permission`, `m_user_permission`: current menu/permission system.
- No theme-specific columns found in inspected tables.

## Proposed logical model (not yet implemented)

Do not create these tables until FK/index/trigger and migration runner conventions are reviewed.

1. `m_theme`: theme code, display name, version, commercial flag, active/default flags, metadata.
2. `t_society_theme_entitlement`: society_id, theme_id, subscription_id (nullable only for explicit admin grants), activation status, start/end, audit fields. This is the backend authority for whether an organization may select a commercial theme.
3. `t_user_theme_preference`: user_id, society_id, theme_id, audit fields. Unique per user + society. It must not change preferred_language.
4. Optional theme configuration table only if the current branding/settings JSON cannot cleanly hold versioned theme tokens; avoid duplicating logo/brand data.

Standard is seeded as the default available theme. SKYFY NEXUS is catalogued as commercial and remains unavailable unless a valid active entitlement exists. A preference cannot grant entitlement.

## Backend enforcement

- Authenticated theme resolver checks user, selected society, active entitlement and theme activation.
- Every theme-selection write checks permission and entitlement server-side.
- Invalid/expired/unentitled preference returns Standard safely.
- Organization scoping must use the authenticated session's society_id, not a caller-supplied arbitrary society.
- All writes include existing created/modified/modify_by/modify_date/modify_remark conventions and audit trail.
- Migration must be additive, idempotent, backward-compatible, reversible and must not rewrite existing customer/billing data.

## Status

No SQL migration has been created or applied. No production database writes were performed.
