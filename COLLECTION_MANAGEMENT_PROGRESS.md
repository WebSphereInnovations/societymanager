# Collection Management Progress

Updated: 2026-10-24

## Objective
Complete the existing Society360 Collection Management workflow against the existing PostgreSQL schema, preserving authentication and society isolation. No dummy customers, dues, or payments.

## Repository and architecture
- Repository: `C:\Users\Delta\Society360`
- Branch: `main`; last previously pushed commit before this work: `d8dc9c2`.
- Backend: ASP.NET Core / Npgsql.
- Database: PostgreSQL schema `society_manager`; connection comes from `SOCIETY360_DB_CONNECTION` (never write the secret to this file).
- Existing Collection UI and API: `wwwroot/modules/society-admin/requested-workflows.js`, `Modules/SocietyAdmin/RequestedSocietyManagerEndpoints.cs`.
- Existing payment tables: `t_payment`, `t_receipt`, `t_payment_allocation`, `t_bill`; customer-to-flat link: `m_customer_flat`.

## Implemented in this work session
- Added migration `Database/044_collection_atomic_payment_allocation.sql`.
- Migration adds nullable `t_payment.tag`; ensures processed-month column has no default; replaces the 12-argument `sp_accept_payment` called by the existing API.
- Payment function validates customer/society/flat link, payment mode and positive currency amount; serializes collection for the selected society/flat; locks eligible bills; applies oldest-due-first allocations; creates payment, receipt and allocation rows in the same PostgreSQL transaction; updates bill paid/status fields; rejects excess amounts rather than silently creating credit; explicitly inserts SQL NULL for `processed_billing_month`, `processed_date`, and `tag`.
- Collection UI now has a re-enter amount field, validates matching amounts in cents, and refreshes the current collection search after a successful payment.
- Applied migration to the configured PostgreSQL database successfully: BEGIN, ALTER TABLE, ALTER TABLE, CREATE FUNCTION, COMMIT.
- Release build succeeded: 0 warnings, 0 errors (using `C:\Users\Delta\.dotnet\dotnet.exe build -c Release --no-restore`).

## Important findings / accounting behavior
- Before this migration, actual `t_payment` had `processed_billing_month` but no `tag`.
- Existing UI called a 12-argument `sp_accept_payment`; repository SQL files 018/019 defined only the 8-argument version, so API/function signatures were inconsistent.
- Existing schema has `t_payment_allocation`, with per-bill allocations.
- Excess payment is rejected because no verified customer-credit policy was found. Service charges are a separate service-payment workflow; bill-payment allocation only applies to eligible `t_bill` balances.
- Eligible bill balance is `GREATEST(total_amount - paid_amount, 0)`, excluding Paid, Cancelled, Void, and Reversed; oldest due date first. This rule should be reviewed against any additional project-specific reversal statuses before declaring accounting acceptance complete.
- No live payment was intentionally made. A rollback-only end-to-end SQL test was attempted but its initial candidate-selection query was incorrect; a later attempt was blocked by tool safety checks. Do not claim the payment function's persisted-row invariant has been integration-tested yet.

## Verification status
- [x] Migration applied to configured DB.
- [x] .NET Release build passed (0 warnings / 0 errors).
- [x] JavaScript syntax check after latest UI edit (`node --check` passed).
- [x] PostgreSQL metadata verification: `tag` is nullable text; `processed_billing_month` has no default; active `sp_accept_payment` signature matches the 12-argument API call.
- [ ] Safe rollback-only transaction test on a known eligible test account, with direct SQL assertions for payment amount = allocation sum and metadata SQL NULL. An attempted test was not completed; no live payment was created.
- [ ] Authenticated Chrome test of collection search, amount match validation, payment save, receipt, updated dues, refresh, and responsive layout. Authenticated browser session/test account was not available in this batch.
- [ ] Verify payment history UI; current module loads a receipt after save but does not yet provide a dedicated per-customer payment-history view.
- [ ] Full six-language audit of all Collection Management labels/messages.
- [ ] Confirm search returns only the intended account and current dues are reconciled against bill records; UI currently displays aggregate dues from the existing DB search function.
- [ ] Run complete project tests, review final diff, commit and push.

- [x] Runtime smoke: `GET /api/health` returned 200; unauthenticated `GET /api/sm/collection/search?q=` and receipt lookup returned 401, as expected.\r\n- [x] Commit/push succeeded: `3fdc74e Harden collection payment allocation and null metadata` pushed to `origin/main`.\r\n\r\n## 2026-10-24 continuation: account summary and payment history
- Added `Database/045_collection_account_summary_history.sql` and applied it successfully to the configured PostgreSQL database. It updates collection search so `current_dues` is derived from eligible unpaid bill balances only (excluding Paid, Cancelled, Void, Reversed), and adds account summary and customer/flat payment-history functions.
- Added authenticated endpoints `GET /api/sm/collection/flat/{flatId}/summary` and `GET /api/sm/collection/customer/{customerId}/flat/{flatId}/history`, both scoped to the current session society and guarded by `COL_ACCEPT_PAYMENT` VIEW permission.
- Collection UI now loads account breakdown and payment history when a customer/flat is selected, has a history table, and shows bank/cheque/DD fields for the corresponding payment modes. The outstanding calculation excludes service charges; pending service charges are shown separately because the payment allocator applies receipts to bills only.
- Added translations for the newly added summary/history labels in the six configured locales: English, Hindi, Marathi, Gujarati, Kannada, Tamil.
- Verification executed: migration 045 applied; read-only PostgreSQL reconciliation returned `SEARCH_VS_SQL=PASS`, `SUMMARY_VS_SQL=PASS`, `HISTORY_FUNCTION=PASS`; `node --check` passed for requested-workflows.js and i18n.js; Release build passed with 0 warnings/0 errors; `/api/health` returned 200; new summary/history endpoints returned 401 without authentication as expected; `git diff --check` passed.
- Still not verified: no isolated test database/test account was available in this session, so no payment was inserted. Therefore persisted `processed_billing_month IS NULL` and `tag IS NULL`, rollback, concurrent allocation, duplicate-request idempotency, and actual payment/receipt persistence have not been tested. Authenticated Chrome collection screen/workflow and full six-language UI audit remain not run because no authenticated browser automation session/test credentials were available.
## Exact next actions
1. Run `node --check wwwroot/modules/society-admin/requested-workflows.js` if Node is available; otherwise use an available JS parser.
2. Query PostgreSQL metadata to confirm `tag` exists and payment function is the 12-argument definition.
3. Run a safe, explicit rollback-only test only with a verified valid test record/user/payment mode; assert inserted payment `processed_billing_month IS NULL AND tag IS NULL`, allocation sum equals payment amount, then rollback and confirm no test payment remains.
4. Start/restart app, exercise authenticated Chrome workflow with an authorized test account (do not bypass login).
5. Complete remaining UI/history/i18n tests, inspect `git diff`, and push only after verification. Do not stage unrelated untracked scripts/artifacts.
