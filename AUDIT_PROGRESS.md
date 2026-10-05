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
- Society selection is membership-checked by `fn_set_session_society`.
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
- Unicode/replacement-character scan of `wwwroot`: 0 U+FFFD and 0 `????` runs.
- Build: 0 warnings, 0 errors.
- Commit: dc0f008

## Batch 4 — Module/page UI audit
- Status: IN PROGRESS
- Completed item: `wwwroot/login.html`
- Completed item: `wwwroot/index.html`
- `index.html` fixes: platform/access/operations navigation labels, dashboard headings/cards, platform control/data text, dashboard title, footer text, and dynamic metric/table labels now use centralized i18n keys.
- Added `wwwroot/js/index.js` so platform dashboard/subscription data re-renders through the central language-change event instead of an inline renderer.
- Added/verified six-language keys for the dashboard page: 0 missing across en, hi, mr, gu, kn, ta.
- Verification: `node --check wwwroot/js/index.js` passed; `node --check wwwroot/js/i18n.js` passed; `git diff --check` passed; targeted Unicode check found 0 U+FFFD and 0 `????` runs in i18n resources; old inline dashboard fetch renderer absent.
- Build attempt: blocked by the currently running Society360 process holding `bin\\Debug\\net8.0\\Society360.exe`; compiler reported file-lock retry warnings rather than source errors. No server process was stopped.
- Pending next items: `wwwroot/super-admin-security.html`, then `wwwroot/modules/cashier/index.html`, `wwwroot/modules/customer/index.html`, `wwwroot/modules/migration/index.html`, `wwwroot/modules/society-admin/index.html`, followed by frontend JS/CSS module chunks.
- Important: the existing central `i18n.js` working tree changes are retained and must be verified before the next batch; do not repeat completed page work.

## Batch 5 — Full regression / authenticated E2E
- Status: PENDING
