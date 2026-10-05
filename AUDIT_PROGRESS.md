# Society360 Production Audit Progress

## Batch 1 — Global localization resources
- Status: COMPLETE
- Six active languages: en, hi, mr, gu, kn, ta
- All English resource keys present in all six dictionaries
- Gujarati corruption fixed
- Browser switch matrix verified: en -> hi -> mr -> gu -> kn -> ta -> en
- Build: 0 warnings, 0 errors
- Commit: e58e187

## Batch 2 — Tenant isolation / API security
- Status: COMPLETE
- Society selection is membership-checked by fn_set_session_society.
- Society-scoped APIs derive the active society from the authenticated session.
- Customer/account/document/payment/security object-ID APIs pass the session society into DB routines.
- Cross-society read test: customer 1 from society 1 returned no account when queried through society 9.
- Global menu/role mutation endpoints are restricted to SUPER_ADMIN because their backing configuration is global.
- Build after security change: 0 warnings, 0 errors.
- Commit: 626b60f

## Batch 3 — Validation / error localization
- Status: COMPLETE
- Raw PostgreSQL error text removed from user-facing API responses; server-side logging remains where needed.
- Central six-language API validation/error translations added.
- Global mobile/email/required-field JSON validation remains enforced server-side.
- Unicode/replacement-character scan of wwwroot: 0 U+FFFD and 0 ???? runs.
- Build: 0 warnings, 0 errors.
- Commit: dc0f008

## Batch 4A — Authenticated i18n propagation root cause
- Status: COMPLETE
- Reproduced the shared runtime failure path by inspecting the authenticated selector/state wiring and two authenticated module patterns (`wwwroot/modules/society-admin/index.html` + `admin.js`, and `wwwroot/modules/cashier/index.html`).
- Root cause: the shared `i18n.js` runtime did not own the authenticated language-selector change path; only some pages wired `#language-select` themselves. This violated the single language-state rule and left modules such as Cashier without a reliable selector -> `Society360I18n.setLanguage()` path.
- Second root cause: arbitrary DOM text used a per-node WeakMap source only. When authenticated modules replaced DOM nodes with already-translated text, the new node could treat the previous-language text as its source, preventing reliable Hindi/Marathi/Gujarati/etc. -> English reversal and cross-language switching.
- Fixed centrally in `wwwroot/js/i18n.js`: one delegated selector handler for `#language-select` / `[data-language-selector]`, one localStorage-backed active language state, canonical source-text recovery before translating newly created/re-rendered text nodes, and no reload requirement.
- Bumped the shared i18n cache-busting reference from `20261004.12` to `20261005.01` on all seven HTML/JS references so authenticated browsers receive the root-cause fix instead of a cached runtime.
- Updated `MULTILINGUAL_DEVELOPMENT_RULES.md` with the single active language-state, centralized selector handler, and canonical dynamic-text source requirements.
- Verification: `node --check wwwroot/js/i18n.js` passed; `git diff --check` passed; wwwroot replacement-character/???? scan returned 0; stale i18n cache references returned 0.
- Browser-authenticated visual E2E could not be freshly claimed in this small batch because no authenticated browser automation session was available; the root-cause code path was verified statically and through the shared runtime implementation. Full authenticated E2E remains Batch 5.

## Batch 4B — Cashier authenticated page complete
- Status: COMPLETE
- Page audited: `wwwroot/modules/cashier/index.html` including its inline authenticated runtime and all directly rendered customer/payment/bill/collection/report content.
- Visible HTML audit: 69 distinct English text candidates; 0 missing central translation keys after cashier vocabulary coverage was added.
- Form audit: search, amount, reference/cheque, remarks placeholders and Cash/UPI/Bank Transfer/Cheque options are routed through central i18n attributes/resources.
- Dynamic audit: customer search Tabulator headers use centralized field aliases; bill/collection report headers use centralized translation lookup; selected-customer, Customer 360, payment and workspace labels use `Society360I18n.t`; language-change event rebuilds dynamic tables/content without reload.
- Added cashier/collection vocabulary for all six active languages: en, hi, mr, gu, kn, ta.
- Bumped shared i18n cache reference to `20261005.02` so the authenticated runtime receives the updated dictionaries/rendering code.
- Verification: `node --check wwwroot/js/i18n.js` passed; extracted Cashier inline JavaScript `node --check` passed; visible HTML candidate audit reported 0 missing keys; Unicode/???? scan returned 0; `git diff --check` passed.
- Full live authenticated visual switching for this route remains part of Batch 5; this batch did not claim a browser visual E2E pass.

## Batch 4 — Module/page UI audit
- Status: IN PROGRESS
- Completed item: wwwroot/login.html
- Completed item: wwwroot/index.html
- Completed item: wwwroot/super-admin-security.html
- super-admin-security.html fixes: all headings, labels, buttons, placeholders, security text, role badge, title and dashboard link use centralized i18n keys.
- Added wwwroot/js/super-admin-security.js; removed page-specific inline application logic and added language-change reapplication.
- Security/auth API outcomes now expose stable translation codes for login-name change, password change and invalid encrypted-value errors; frontend translates codes centrally.
- Added permanent project rule: MULTILINGUAL_DEVELOPMENT_RULES.md.
- Verification: super-admin-security.js and i18n.js node syntax checks passed; page has no inline application script and uses external page JS; all 40 new security-page keys have six-language coverage with 0 missing; targeted i18n Unicode check found 0 U+FFFD and 0 ???? runs; git diff --check passed.
- Full browser language-switch verification for this authenticated route remains part of Batch 5 because it requires a live authenticated session; this batch did not claim that visual E2E test.
- Completed item: wwwroot/modules/cashier/index.html (Batch 4B). Do not repeat it.
- Pending next items: wwwroot/modules/customer/index.html, wwwroot/modules/migration/index.html, wwwroot/modules/society-admin/index.html, followed by frontend JS/CSS module chunks. Completed pages must not be repeated.
- Existing central i18n changes remain part of the saved repository state.

## Batch 4C — Customer Account authenticated UI audit
- Status: COMPLETE
- Menu audited: Customer Relationship Management.
- Submenu audited: Customer Account (`wwwroot/modules/society-admin/index.html`, `data-module-code=CRM_CUSTOMER_ACCOUNT`).
- Actual authenticated browser screen was inspected after login; search was exercised with a real consumer (`CON-00000001`) so the selected-consumer overview, account summary, dynamic status/role values and visible tabs were rendered and inspected.
- Found and fixed the shared i18n root cause where translated DOM text could become the source for later switches. Central canonical-source recovery now recognizes values from every configured dictionary and dynamic text updates are observed through characterData mutations as well as added DOM nodes.
- Added complete Customer Account vocabulary for all six active languages: en, hi, mr, gu, kn, ta, including search/help text, account labels, tabs, dynamic status/role labels, previous outstanding, logout and authenticated navigation labels.
- Verified actual rendered UI switching: English -> Hindi -> English, English -> Marathi -> English, English -> Gujarati -> English, English -> Kannada -> English, and English -> Tamil -> English on the authenticated Customer Account screen. No English leftovers were found in the translated UI except intentional proper/data values such as society name, consumer name, IDs, email, dates and wing name.
- Verified reverse switching after translated DOM re-rendering; the shared observer fix prevents stale previous-language text.
- `node --check wwwroot/js/i18n.js` passed. HTML cache-busting references updated to `20261005.08` without content-encoding corruption. Temporary browser/audit files removed.
- Saved state is ready to continue from `wwwroot/modules/customer/index.html`; do not repeat Customer Account unless regression testing requires it.

## Batch 5 — Full regression / authenticated E2E
- Status: PENDING
- Must verify every authenticated route with English -> each supported language -> English without reload, navigation persistence, reload persistence, dynamic validation/toast/status text, and no stale text/????/undefined.


## Batch 5A — Login/authentication blocker + regression baseline
- Status: COMPLETE
- Actual blocker diagnosed: the tracked `scripts/Start-Society360.ps1` had been corrupted by Desktop Commander wrapper output (`[Reading ...]` / `[executed on device ...]`). The script therefore failed PowerShell parsing and prevented clean application restarts. It was restored to a clean launcher that loads the user DB connection string and starts Kestrel on `http://0.0.0.0:5180`.
- Runtime security was preserved: cookie authentication, server-side session validation, protected-route redirect, role-based routing and SocietyId/session checks were not bypassed or disabled.
- Shared i18n runtime was hardened against its own MutationObserver reprocessing by adding an apply guard. The guard prevents translation passes from recursively reacting to their own character-data mutations.
- Login page was audited for missing centralized translation coverage. Added the missing placeholder/title/signup/subscription vocabulary to all six active languages and localized the remaining visible signup/plan runtime strings. Login i18n cache-busting was advanced to `20261005.09` across the existing seven HTML references.
- Fresh clean build: 0 warnings, 0 errors.
- Fresh server start through the repaired launcher: Kestrel listening on `0.0.0.0:5180`.
- HTTP verification: `/login.html` returned 200 locally and through `192.168.1.8:5180`; `/api/health` returned online/databaseConfigured=true; unauthenticated `/modules/society-admin/index.html` returned 302 to `/login.html`.
- Fresh-session functional auth regression using a temporary DB-created test account: login API 200 with route, auth cookie issued, `/api/auth/me` 200 with session, logout 200, subsequent `/api/auth/me` 401, protected root redirected 302 to `/login.html`; temporary account and its audit/login-status rows were cleaned up.
- Login page translation coverage check: 32 distinct `data-i18n`/placeholder keys, missing=0 for en/hi/mr/gu/kn/ta. Active runtime language configuration remains exactly `en, hi, mr, gu, kn, ta`.
- Existing authenticated Customer Account visual language-switch regression remains recorded in Batch 4C. The full all-route Batch 5 authenticated visual sweep is still pending; do not mark the overall localization audit complete until that sweep is performed.
