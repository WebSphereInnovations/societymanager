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
- Pending next items: wwwroot/modules/cashier/index.html, wwwroot/modules/customer/index.html, wwwroot/modules/migration/index.html, wwwroot/modules/society-admin/index.html, followed by frontend JS/CSS module chunks. Completed pages must not be repeated.
- Existing central i18n changes remain part of the saved repository state.

## Batch 5 — Full regression / authenticated E2E
- Status: PENDING
- Must verify every authenticated route with English -> each supported language -> English without reload, navigation persistence, reload persistence, dynamic validation/toast/status text, and no stale text/????/undefined.
