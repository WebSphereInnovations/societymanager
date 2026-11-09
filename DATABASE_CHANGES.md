# SKYFY NEXUS Database Change Register

## Current status

No database changes have been made for SKYFY NEXUS. No production migration has been authored or applied.

Existing application database is PostgreSQL, accessed through Npgsql, with the documented schema `society_manager`. Existing numbered SQL migrations under `Database/` are the migration convention. Current exact production schema and data fingerprint must be re-read in a controlled read-only session before design approval.

## Candidate logical entities (not yet approved)

Potential needs from the commercial requirement:

- Theme catalog/version and configuration
- Organization/society theme entitlement/assignment
- User theme preference
- Theme activation status and audit history
- Future subscription linkage

Before creating any table, inspect existing organization, subscription, module entitlement, user preference and audit entities. Reuse compatible existing structures when possible. Do not create duplicate organization or subscription records.

## Required design properties

- Standard is the safe default for existing organizations and users.
- SKYFY NEXUS is available only when the backend confirms an active entitlement.
- Organization entitlement is authoritative; user preference may select only among themes entitled to that organization.
- Unauthorized theme requests must be rejected server-side and safely fall back to Standard.
- Preferences must be scoped to the correct organization/user and persisted without coupling to language.
- Include constraints, indexes, timestamps, modify-by/remark conventions, audit and reversible rollback.
- Migration must be backward-compatible and must not rewrite existing business records.

## Migration status

Pending Phase 2 schema discovery and design review. No migration number reserved.
