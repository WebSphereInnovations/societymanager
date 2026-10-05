# Society360 Authentication & Security Rules

## Non-negotiable regression gate
Every change MUST preserve and re-test:
- Fresh unauthenticated root opens the login page.
- Valid login creates a real server-side session and routes to the user's authorized workspace.
- Invalid login is rejected.
- Logout revokes the server-side session and clears authentication cookies.
- Direct protected URLs, refreshes and browser-history navigation are rejected when unauthenticated.
- Protected APIs return no protected data without a valid authenticated session.
- Role/permission checks are enforced server-side.
- SocietyId is derived from the authenticated session/membership, never trusted from the browser.
- Cross-society object/API manipulation must fail.
- Passwords remain salted/hashed; authentication must never be bypassed for testing or deployment.
- Existing CSRF, rate limiting, secure cookie and security-header protections must remain enabled.

## Routing
Protected static application routes include /, /index.html, every /modules/* page, and /super-admin-security.html. The server-side route guard runs before static-file delivery. Unknown protected module paths must not become an authentication bypass.

## API authorization
Every authenticated API that returns or mutates society/user data must validate the current session and required role/permission before database access. Database calls must use the authenticated SocietyId and parameterized queries/stored procedures.

## Deployment
The application must be built, restarted using the existing launcher/configuration, and then checked on http://192.168.1.8:5180/ from a fresh unauthenticated session. Never mark deployment successful based only on a build.

## Stop-the-line rule
If login, logout, protected-route enforcement, authorization or society isolation fails after any change, STOP feature work and fix the regression first.
