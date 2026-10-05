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
- Current item: `wwwroot/login.html`
- Completed in this chunk: public login/create-society UI localization gaps.
- Changes: email/phone/address labels and placeholders, close button title, subscription heading/info, create-account button, login page title, plan duration/unit labels, plan fallback/status messages now use centralized i18n keys.
- Verification: six-language key coverage for all new keys = 0 missing; inline login script `node --check` passed; `git diff --check` passed.
- Pending next items: `wwwroot/index.html`, `wwwroot/super-admin-security.html`, then `wwwroot/modules/cashier/index.html`, `wwwroot/modules/customer/index.html`, `wwwroot/modules/migration/index.html`, `wwwroot/modules/society-admin/index.html`, followed by frontend JS/CSS module chunks.

## Batch 5 — Full regression / authenticated E2E
- Status: PENDING
