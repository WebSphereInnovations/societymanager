# Society360 Execution Progress

Last updated: 2026-10-24 (IST)
Repository: `C:\Users\Delta\Society360` — `WebSphereInnovations/societymanager`, branch `main`.

## Current checkpoint

- Last commit at task start: `f8efa8e` — `Fix cash collection null date parameter`.
- Working tree at task start already contained seven modified tracked files plus many untracked QA scripts, backups, and screenshots. These pre-existing changes/artifacts have been preserved; no reset/clean/stage-all was run.
- Current runtime: `http://192.168.1.8:5180/`; read-only `GET /api/health` returned HTTP 200 with `status=online` and `databaseConfigured=true`.
- Existing Chrome session was previously verified on the visible Windows desktop at the Society360 Society Admin screen, society `Lakeview Residency`, and Collection Management > Accept Payment. Chrome was not restarted or signed out in this pass.
- A read-only automated navigation audit was attempted with `scripts/navigation_inventory_chrome_e2e.py`; it failed immediately because `127.0.0.1:9335/json/list` refused the connection. The script did not click or change the application because it failed before attaching. Do not claim full live menu enumeration or a full Chrome navigation pass.
- Created `SOCIETY360_MODULE_INVENTORY.md` and `SOCIETY360_FUNCTIONALITY_MANUAL.md` with evidence-backed source route/module families, known implementation state, required workflows and explicit unverified/blocked acceptance. The inventory deliberately leaves the live menu count and complete functional/partial/nonfunctional/blocked totals as **not yet verified**, rather than inventing numbers. `index.html` has 14 source-defined view sections; that is not the same as live menu count.
- Six configured language keys currently in the application: English (`en`), Hindi (`hi`), Marathi (`mr`), Gujarati (`gu`), Kannada (`kn`), Tamil (`ta`). Prior same-day Collection Management evidence documents selector switching and visible translations; project-wide per-menu six-language acceptance remains incomplete.

## Verification run during this checkpoint

| Check | Result | Evidence |
|---|---|---|
| Release build from current source to isolated output | PASS | `C:\Users\Delta\.dotnet\dotnet.exe build C:\Users\Delta\Society360\Society360.csproj -c Release --no-restore -o C:\Society360BuildResume8`; 0 warnings, 0 errors |
| `requested-workflows.js` syntax | PASS | `node --check` returned no error |
| `i18n.js` syntax | PASS | `node --check` returned no error |
| `git diff --check` | PASS | No whitespace errors; Git emitted only expected line-ending warnings |
| Local health endpoint | PASS | HTTP 200; database configured |
| Automated live menu navigation | BLOCKED | Chrome CDP endpoint `127.0.0.1:9335` unavailable; no menu clicks occurred |
| Payment transaction / receipt persistence | NOT RUN | No test DB isolation fingerprint or explicitly authorized test remittance verified; no financial write performed |

## Active implementation state

- Pre-existing uncommitted changes include collection search-first consumer selection, payment form/receipt lifecycle, UTC normalization for PostgreSQL timestamp parameters, i18n resource updates, and dashboard/menu styling/behavior. Preserve these changes; review their complete diff before commit.
- Collection progress is documented in `COLLECTION_MANAGEMENT_PROGRESS.md`. Existing evidence includes visible search, selected consumer/account summary, no-result state, payment mode options, blank-amount validation and locale-switch checks. The successful payment/receipt/database persistence path is still unverified and must not be marked complete.
- `SOCIETY360_MODULE_INVENTORY.md`: live menu/submenu total pending actual `/api/menu` tree capture; no false completion counts.
- `SOCIETY360_FUNCTIONALITY_MANUAL.md`: domain workflows, role/data/audit rules and acceptance criteria written; modules routed to generic `module-workspace` are explicitly treated as unverified placeholders until real module-specific behavior is demonstrated.

## Blockers and safety limits

1. The live menu tree must be captured through the existing authenticated session. Do not restart/sign out the user's Chrome session just to obtain CDP. Restore an authorized automation channel or use an approved visible UI automation path.
2. The environment variable `SOCIETY360_DB_CONNECTION` is configured but prior inspection could not independently establish its host/database identity without exposing secret material. Before any payment, bill finalization, rate update, import, or other financial/irreversible write test, produce a non-secret database fingerprint and confirm isolated test data.
3. No real production payment was created. Do not create arbitrary transactions to satisfy a test. Use read-only verification or an explicitly authorized isolated test environment.
4. Full cross-society authorization needs a second authorized society context/account; do not claim tenant-isolation testing complete without it.
5. Current changes are not yet committed/pushed as a logical checkpoint. Do not stage unrelated screenshots/scripts/backups. Review and stage only intentional source/documentation changes after their verification.

## Next actions, in order

1. Obtain authenticated live `/api/menu` inventory without disturbing the current visible Chrome session; save genuine results and calculate menu counts from that tree plus route/API inspection.
2. Map each menu code to module-specific UI, backend handlers, database procedures/tables and translations. Flag all `module-workspace` fallback routes as unimplemented until proven otherwise.
3. Finish safe Collection Management checks: verify latest source is the running build without disrupting the user's session; test only read-only/invalid-input paths until DB isolation is confirmed. Then run an isolated successful payment/receipt/persistence workflow if prerequisites become available.
4. Continue P0 modules in sequence: dashboard totals and regression; Customer Account; Billing configuration/process; collection; authorization/account management; property and security workflows.
5. For every module, update inventory only after UI, DB persistence, permission/society scope, regression and all six locales pass. Maintain screenshots/test IDs only when genuine.
6. Inspect `git diff`, stage only the intended module/docs changes, run build/tests again, commit and push to `origin/main` only after safe verification and confirmed GitHub success.


## 2026-10-24 follow-up — Dashboard selected-period total card

- Verified the dashboard frontend sets `#kpiPeriodOutstanding` from `s.billedAmount`, not `s.periodOutstanding` or `s.currentOutstanding`. In `Database/041_dashboard_analytics.sql`, `billed_amount` is computed from `SUM(total_amount)` over the selected-period `bill_scope`; this includes paid and unpaid eligible bills. `period_outstanding` separately sums `balance_amount`, and `current_outstanding` uses open bill balances. This supports the requested distinction: the period total card shows the full billed total for the selected period, while Current outstanding and Overdue amount remain balance metrics.
- Removed the redundant `Billed amount` subtitle from the `Total outstanding (period)` KPI card in `wwwroot/modules/society-admin/index.html`, so the same metric is not displayed twice. No API contract, SQL calculation, billing workflow, or database record was changed.
- A fresh isolated Release build after this HTML change is running as PID 17616; collect the result before marking this step build-verified. Prior current-source isolated build passed with 0 warnings/errors. `requested-workflows.js`, `i18n.js`, and `git diff --check` had passed in the preceding validation pass.
- Browser visual confirmation of this final subtitle removal is **not yet verified** because Chrome DevTools endpoint 9335 is unavailable; the current authenticated visible Chrome session was not restarted. No database writes were made.
- Follow-up result: isolated Release build to `C:\Society360BuildResume9` **PASS** (0 warnings, 0 errors). Added and ran `scripts/verify_dashboard_period_total_contract.py`; **PASS** confirms the card displays the database-provided full period billed total, the duplicate `Billed amount` subtitle is absent, and period/current balance fields remain distinct. `node --check` passed for dashboard, collection workflow, and i18n JavaScript; `git diff --check` passed (line-ending warnings only). This is source/build/static-contract evidence, not a replacement for visible Chrome confirmation.


## Git checkpoint result

- Documentation/test checkpoint committed and pushed successfully: `fbab98d` (`Add Society360 module audit checkpoint`), `main -> origin/main` confirmed by Git output. Commit includes only the two Society360 audit documents, this progress file, and `scripts/verify_dashboard_period_total_contract.py`.
- Pre-existing modified application files, browser screenshots, backups, and QA artifacts were deliberately not staged. The Dashboard subtitle source edit remains in the working tree and is not yet pushed; its source/build/static-contract checks pass, but actual visible Chrome confirmation is pending. The broader Collection Management source changes remain uncommitted and payment-write acceptance is still blocked as described above.


## 2026-10-24 — Collection Management receipt-details implementation

### Actual application changes
- Added additive, repeatable migration `Database/047_collection_receipt_details.sql`, creating `society_manager.fn_payment_receipt_details` without replacing the existing `fn_payment_receipt` contract. It returns society address/contact/branding, receipt/payment identifiers and timestamps, customer/consumer/property identifiers, JSON charge components derived from actual allocated bills, and bill allocation rows.
- Updated `Modules/SocietyAdmin/RequestedSocietyManagerEndpoints.cs` so the existing authenticated, society-scoped receipt endpoint calls the new read model. It retains the `COL_ACCEPT_PAYMENT` permission guard and current session society filter.
- Updated `wwwroot/modules/society-admin/requested-workflows.js` receipt rendering to include society contact information, itemized charge breakdown, bill allocation details, and a reconciliation total. Discovered through the real browser API response that PostgreSQL JSONB fields are serialized as JSON strings by the existing generic `Rows` helper; added defensive parsing before rendering. Bumped the script cache key to `requested-workflows.js?v=20261024.10` and i18n key to `i18n.js?v=20261024.03`.
- Added localized receipt labels in `wwwroot/js/i18n.js` for English, Hindi, Marathi, Gujarati, Kannada and Tamil. The schema currently has explicit DPC, interest-on-arrears, arrears, maintenance, parking, sinking-fund, other-charge, tax and rebate columns; it does not expose a distinct `penalty_amount` column. The receipt therefore shows actual DPC and other-charge values rather than inventing a separate penalty value. The residual category is labelled `Current Dues / Unclassified` when historical bill component fields do not break the full amount down further.

### Database and build evidence
- Applied migration 047 to the configured database after a non-secret fingerprint check: database `society_manager`, server `127.0.0.1/32`, schema `society_manager`; required `t_payment_allocation` and `t_bill` tables were present. Migration succeeded; function result signature verified.
- Read-only DB reconciliation on the latest existing payment with bill allocations: amount `1100.00`, sum of payment allocations `1100.00`, sum of receipt charge breakdown `1100.00`, one allocated bill, receipt present. No payment or other financial row was created or modified for this test.
- Real authenticated Chrome session was left open. Using visible Windows UI automation, opened Collection Management → Accept Payment. Chrome was also navigated in a new tab to the existing receipt API for payment 27; the browser's accessible JSON response contained `charge_breakdown`, `bill_allocations`, and receipt fields. This exposed the JSONB-as-string rendering bug, which has now been fixed in source. The latest JSON parsing correction and cache-key bump have not yet been reloaded/retested in the receipt UI.
- Release build passed after the API endpoint change: 0 warnings, 0 errors. `node --check` passed for `requested-workflows.js` and `i18n.js`; `git diff --check` passed. The receipt static-contract test passed before the final JSON parsing guard/cache-key bump; rerun it after the last edit.
- Six-locale visible UI test via Windows UI Automation successfully selected English, Hindi, Marathi, Gujarati and Kannada and found the expected Collection Management search label in the page accessibility tree. Tamil label matching was not confirmed in that pass and must be retested. The test used actual selector keyboard interactions; locale output in the PowerShell console is not reliable for non-ASCII display, so rely on UIA label matching rather than console rendering.

### Still incomplete / not to be claimed as complete
- Successful new payment transaction, receipt print/PDF workflow and post-payment customer balance reconciliation remain untested because no isolated test DB or explicitly authorized test remittance was established. No payment was submitted.
- After the latest JSONB parsing fix, reload the visible Chrome application, open an existing receipt through an authorized UI workflow if available, verify the itemized rows and totals, and retest all six locale labels (especially Tamil). Do not use a real financial write just to test the print path.
- The module remains **Partial**, not Fully functional. Existing Collection Management UI/source changes were preserved; no broad reset/clean was performed.


## 2026-10-24 — Outstanding / Aging report implemented and visible-Chrome verified

### Actual application changes
- Added additive migration `Database/048_outstanding_aging_report.sql` defining `society_manager.fn_mis_outstanding(p_society_id,p_as_of_date)`. It returns bill ID/number/month/due date, flat, primary customer, total/paid/outstanding amounts, days overdue, aging bucket and bill status. It filters to the authenticated society, excludes zero-balance and closed/void/reversed bills, and computes aging in PostgreSQL. No financial records were modified.
- Added authenticated route `GET /api/sm/reports/outstanding?asOf=YYYY-MM-DD` guarded by `RPT_OUTSTANDING` and routed through the existing session-scoped `Query` helper.
- Replaced the `RPT_OUTSTANDING` generic-workspace fallback with a real date-filtered Tabulator report. It includes header filtering, sorting/pagination through the existing grid helper, currency-formatted amount columns, translated aging buckets, localized error feedback, and a language-change handler that re-renders the report while preserving the selected as-of date.
- Added report labels and aging-bucket translations for English, Hindi, Marathi, Gujarati, Kannada and Tamil. Bumped the workflow asset cache key to `requested-workflows.js?v=20261024.12`; i18n remains `i18n.js?v=20261024.04`.

### Verification evidence
- Applied migration 048 after a non-secret fingerprint check (`society_manager` database/schema, local PostgreSQL server, `t_bill` present). The report function ran read-only for the society linked to an existing payment: 22 rows, total outstanding `47300.00`, 22 overdue rows, 0 rows in 90+ days, and every returned outstanding amount positive.
- Release build after report route/UI/i18n changes passed with 0 warnings and 0 errors. `scripts/verify_receipt_details_contract.py` and `scripts/verify_outstanding_report_contract.py` passed; `node --check` passed for `requested-workflows.js` and `i18n.js`; `git diff --check` passed.
- Restarted the application and confirmed `/api/health` returned HTTP 200 with database configured.
- Visible Chrome: hard-reloaded Society Admin, opened Reports & Analytics, scrolled the actual navigation container to the Outstanding / Aging submenu, and clicked it. UI Automation confirmed `outstandingAsOf`, `outstandingRefresh`, and `outstandingTable` exist and the rendered table exposes the expected bill, period, due date, flat, consumer, amount, overdue-day, aging-bucket and status columns. A direct authenticated browser request to the report API returned 22 rows totaling `47300.00`, all positive, with `aging_bucket` present.
- Visible-Chrome language switching on the Outstanding / Aging screen passed for all six configured languages. In each language, the report heading and as-of-date label matched the expected translation; the selected date remained unchanged. English was restored at the end.
- Date field was visible and Refresh was clicked, but a second date value could not be reliably set through UI Automation; alternate-date UI filtering remains unverified. No write operations were performed.

### Remaining scope / status
- Outstanding / Aging is implemented and its read-only UI/API/language path is verified; it is not evidence that all Reports & Exports menus are complete. Billing, Collection, Consumer and Audit report routes still require full menu-specific workflow verification and export acceptance.
- Collection Management receipt-details implementation remains partial: the receipt API and existing-payment allocation totals reconcile, but a successful payment transaction, actual print/PDF popup and post-payment Customer Account balance reconciliation are still blocked on an approved isolated test fixture/remittance. No production payment was created.


## 2026-10-24 — Collection UI regression and receipt timestamp refinement

### Actual source changes
- wwwroot/modules/society-admin/requested-workflows.js: receipt rendering now formats INR currency with Intl.NumberFormat using the active Society360 locale, formats timestamps with locale-aware Intl.DateTimeFormat, and shows separate Receipt Date / Time and Payment Date rows. This preserves the receipt endpoint contract and uses only actual receipt/payment timestamps.
- wwwroot/js/i18n.js: added the Receipt Date / Time label for English, Hindi, Marathi, Gujarati, Kannada and Tamil.
- wwwroot/modules/society-admin/index.html: bumped static asset cache keys to requested-workflows.js?v=20261024.15 and i18n.js?v=20261024.05.
- scripts/verify_receipt_details_contract.py and scripts/verify_outstanding_report_contract.py: aligned expected cache key; receipt contract now checks locale-aware currency/time formatting and all six timestamp label dictionaries.
- Earlier Release build C:\Society360BuildResume10 passed after the receipt date/time source change with 0 warnings and 0 errors. This latest cache-key-only change does not alter C# compilation.

### Genuine visible Chrome evidence
- Opened a new tab in the existing Chrome profile at http://192.168.1.8:5180/ without closing the existing ChatGPT tab. The Society360 page loaded in the visible browser and showed authenticated Society Admin context for Lakeview Residency.
- Opened Collection Management → Accept Payment through actual mouse interaction in the visible Chrome UI.
- Search for Rahul returned 20 visible consumer results. Selected the first result through the visible UI. The screen showed the database-backed account summary: Current Bill ₹2,200.00, arrears ₹0.00, DPC/Penalty ₹0.00, rebate/credit ₹0.00, previously paid ₹0.00, pending service charges ₹0.00, Outstanding Amount ₹2,200.00 and 1 unpaid bill. A genuine desktop screenshot was captured to C:\Users\Delta\Society360\collection-live-accept-payment-check.png.
- Clicked Save with the amount left blank. The actual UI displayed the validation text Enter a valid amount greater than zero. twice (inline + toast), and no payment-success message appeared. No financial write was submitted.
- Receipt/outstanding/dashboard static contracts passed; JavaScript syntax checks passed; git diff --check passed (only expected line-ending warnings).

### Remaining acceptance
- The six-language regression automation attempt hit a UI Automation selector lookup issue after the first language iteration. It is not recorded as a six-language pass for this latest receipt timestamp change. Re-run using the selector's stable AutomationId, verify the form and selected customer remain intact in each locale, and restore English.
- The visible payment-history receipt action and print/PDF layout have not yet been exercised against an existing payment in the UI. A new payment was not created. The existing payment API/SQL allocation reconciliation remains read-only evidence from the previous checkpoint.
- Collection Management remains Partial, not Fully functional. Successful payment/receipt/customer-balance end-to-end acceptance is still gated on safe existing-payment UI verification and the production-write safety rule.


## 2026-10-24 — MIS report date semantics, export permissions, and Chrome download blocker

### Implemented
- Added Database/049_mis_collection_month_options.sql and Database/050_mis_report_specific_month_options.sql. Both are repeatable CREATE OR REPLACE migrations. Migration 049 combined bill months and payment months; live testing then exposed a cross-report regression, so migration 050 now exposes separate BILL_MONTH and PAYMENT_MONTH option groups while retaining combined MONTH for backward compatibility.
- Added command-line migration runners in Program.cs. Migration 049 and migration 050 were applied successfully after correcting the first SELECT output aliases. These are function-only changes; no payment, bill, or customer records were written.
- Updated requested-workflows.js to choose BILL_MONTH for Billing Data and PAYMENT_MONTH for Collection Details, preferring the current month when it exists and otherwise the latest available month. Asset key is requested-workflows.js?v=20261024.17.
- Added explicit XLSX export permission mappings for MIS_CONSUMER_MASTER, MIS_BILLING_DATA, MIS_COLLECTION_DETAILS, MIS_COMPLAINT_HISTORY, RPT_OUTSTANDING, RPT_BILLING, RPT_COLLECTION, RPT_CONSUMER and RPT_AUDIT in SocietyAdminEndpoints.cs. Server-side EXPORT permission enforcement remains in place.
- Updated the XLSX download lifecycle in admin.js to delay blob URL revocation by five seconds, and replaced the misleading “Export successful” toast with a localized notice telling the user to check Chrome Download history if no file appears. Added the notice in all six configured languages in i18n.js; asset keys are admin.js v20261024.03 and i18n.js v20261024.06.
- Added/updated static regression contracts: verify_mis_collection_month_options.py, verify_mis_export_permission_contract.py, verify_receipt_details_contract.py, verify_outstanding_report_contract.py and verify_dashboard_period_total_contract.py.

### Genuine visible Chrome results
- After migration 049, Collection Details changed from August 2026 with no rows to October 2026 with the actual October payment row.
- Migration 050 fixed the cross-report regression: in visible Chrome, Billing Data defaults to August 2026 (latest bill month with data) and Collection Details defaults to October 2026 (payment month). Both showed nonempty accessible table content; no financial writes were performed.
- Consumer Master Data report opened in visible Chrome with database-backed rows. Changing the Wing filter and pressing Show returned a filtered dataset; this was a read-only operation.
- Existing payment receipt was opened from the real Collection Management payment history in visible Chrome. The receipt showed receipt number, date/time, INR amounts, itemized charge breakdown, bill allocation and Print / Save as PDF control. Amount received and total allocated both displayed ₹1,100.00 for that existing payment. No new payment was created.
- Blank payment amount validation was tested in the actual UI: “Enter a valid amount greater than zero.” appeared, and no success message or payment write occurred.
- XLSX export endpoint returned a successful response and the permission mapping is present. Chrome Download history explicitly showed Chrome blocked the XLSX download because the site uses an insecure HTTP connection. The generated download remained as .crdownload; the app must not bypass this browser security policy. The user-facing toast now explains to check Download history. Final workbook file delivery remains externally blocked until a secure origin or an explicit user-approved browser decision is available.
- A genuine desktop screenshot of the Collection Details result is stored on the remote test machine at C:\Users\Delta\Society360\collection-live-accept-payment-check.png. It is not a sandbox-hosted downloadable attachment.

### Verification and remaining gaps
- Release build to C:\Society360BuildResume13 passed with 0 warnings and 0 errors. The latest SQL alias correction was applied via the already-built migration runner; C# source did not change after that build.
- After the final localized export-notice edit, all five static report/receipt/dashboard/export/month-group contracts passed, node syntax checks passed for admin.js, requested-workflows.js and i18n.js, git diff --check passed (line-ending warnings only), and GET /api/health returned HTTP 200.
- Full six-language receipt-popup verification remains inconclusive because the UI Automation selector did not reliably report the selected locale. The translation resources include all six receipt and export-notice keys, but do not claim complete per-locale browser acceptance.
- Collection Management remains Partial: existing customer search/selection, real dues/history, existing receipt display and blank-amount validation were verified. Successful payment creation, partial-payment allocation, post-payment balance reconciliation and receipt persistence were not run because an isolated test fixture/remittance was not approved.
- The HTTP-only XLSX browser restriction, project-wide live menu enumeration, Audit report workflow, and remaining module-specific full-stack acceptance are still open.

- Implementation commit 697b240 (Fix MIS report periods and export feedback) was pushed successfully to origin/main. The unrelated pre-existing admin.css/dashboard.js edits and the many pre-existing QA/screenshot artifacts remain unstaged and preserved.

- Additional visible Chrome acceptance after commit: MIS Complaint History loaded database-backed rows, the Complaint Status filter changed to In Progress and Show returned a smaller nonempty result set (accessible data items decreased from 99 to 54). Read-only only; no complaint record was modified.


## 2026-10-24 — Customer Account cross-module read-only verification

- Opened Customer Relationship Management → Customer Account in the actual visible Chrome session. Search by consumer name displayed matching live records directly below the search field; selected the consumer associated with the existing October payment.
- The single-consumer account summary showed Current Outstanding ₹1,100, Current Bill ₹2,200 and Last Payment ₹1,100. These values reconcile with the same consumer's Collection Details row and the existing ₹1,100 receipt. Four account tabs were present, including Payments and Service History. No write was performed.
- Screenshot captured at C:\Users\Delta\Society360\customer-account-existing-payment-check.png. Collection Details screenshot recaptured at C:\Users\Delta\Society360\mis-collection-details-october-check.png.
- Customer Account remains Partial: this was a read-only cross-module consistency test, not a full CRUD, refresh/re-login, multi-flat or six-language acceptance run.


## 2026-10-24 — Audit Trail / RPT_AUDIT implementation and visible Chrome acceptance

### Actual application implementation
- `Modules/SocietyAdmin/RequestedSocietyManagerEndpoints.cs`: the existing `GET /api/sm/audit-log` endpoint now permits a user who has `AUDIT_LOG`, `RPT_AUDIT`, or `SUPER_AUDIT` VIEW rights. The query remains scoped to the authenticated session's `SocietyId`, newest-first and capped at 1,000 rows. The returned `old_data` and `new_data` JSONB now removes sensitive keys (`password_hash`, password/token/secret/cookie fields, authorization/API keys and `last_login_session_id`) before serialization. This was a concrete defect found by inspecting real audit rows in the UI.
- `wwwroot/modules/society-admin/requested-workflows.js`: Audit Trail now localizes the title, search label, columns and Refresh button; displays locale-aware timestamps; exposes login name and separate old/new value fields; supports OR-style search across user, login, entity, record, action and payload fields; and re-fetches/re-renders after language changes.
- `wwwroot/js/i18n.js`: added the Audit Trail search/login/old/new field labels in English, Hindi, Marathi, Gujarati, Kannada and Tamil. `wwwroot/modules/society-admin/index.html` cache keys bumped to `requested-workflows.js?v=20261024.20` and `i18n.js?v=20261024.07`.
- Added `scripts/verify_audit_report_contract.py` and UI automation scripts `scripts/audit_report_visible_acceptance.ps1`, `scripts/audit_report_six_language_visible_uia.ps1`, `scripts/select_society360_tab_uia.ps1` and `scripts/open_reports_menu_visible_uia.ps1` for reproducible checks.

### Build and test evidence
- Release build to `C:\Society360BuildAuditReport20261024b` **PASS** (0 warnings, 0 errors). `node --check` passed for `requested-workflows.js` and `i18n.js`. `scripts/verify_audit_report_contract.py` passed. `git diff --check` passed (only existing line-ending normalization warnings).
- Restarted only the Society360 ASP.NET Core process after confirming it was the expected prior build; the existing Chrome profile/session and other tabs remained open. New runtime PID `19756`; `/api/health` returned HTTP 200 and `databaseConfigured=true`.
- Genuine visible Chrome UI: switched to the existing Society360 tab, reloaded the application, expanded Audit & Governance and clicked Audit Trail. The real UI displayed the Audit Log panel, search field, Refresh button, Excel toolbar and actual PostgreSQL-backed audit rows. Before redaction, UI inspection revealed `password_hash` and `last_login_session_id` in historical `m_user` audit payloads; after the API projection was updated and the app restarted, the visible audit UI showed **0 visible sensitive-field matches** across 40 visible row items.
- Actual UI search acceptance: searching `t_receipt` reduced visible audit rows from 40 to 22; clearing search restored the list. No data was changed.
- Actual UI language-selector test: English, Hindi, Marathi, Gujarati, Kannada and Tamil were each selected using the visible language control. The audit search label was detected in every language and was no longer English in each non-English locale. English was restored at the end. This is evidence for the Audit Trail labels only, not project-wide language acceptance.

### Remaining audit family acceptance
- `AUDIT_TRAIL` / `RPT_AUDIT`: UI search, row display, sensitive payload redaction and six-language search-label switching passed. Still needs a dedicated role with only `RPT_AUDIT` to prove permission branch behavior; the current authorized Society Admin session does not isolate that role case.
- `AUDIT_LOGIN` / Login / Session Audit remains incomplete: existing API is database-backed and society-scoped, but the current UI lacks full localization/date formatting and OR-search; implement and test next.
- `AUDIT_APPROVAL` / Approval History remains unverified and likely needs its own database-backed read model. Inspect actual schema/handlers before implementing; do not invent approval records.
- No financial writes or audit-row writes were made. The audit view remains read-only. Full live menu count is still pending; only this visible submenu was tested.


## 2026-10-24 — Login / Session Audit: write-path repair and safe UI verification

- Root cause evidence: a read-only Npgsql probe against the configured `society_manager` database showed `t_user_login_history` and `t_user_login_audit` each had zero rows for the society despite the account-level login fields being populated. The SQL source contained multiple legacy login procedure variants, so relying on overloaded `sp_record_login_success` / `sp_record_login_failure` calls was ambiguous. No credentials or connection string were emitted.
- Added versioned migration `Database/042_login_history_write_path.sql`: adds nullable `society_id` to `t_user_login_history`, adds a society/created-time index and FK, backfills society IDs for existing known-user history, and creates explicit `sp_record_login_success_v2` / `sp_record_login_failure_v2` procedures. Success upserts the one-row-per-user login summary without resetting an existing login count, updates `m_user.last_login_ip` / `last_login_at` / `login_count`, and inserts an event row. Failure inserts an event row with known society scope when available. Session IDs are not stored as trace IDs.
- Updated `Modules/Auth/AuthService.cs` to call the explicit v2 procedures; updated both login entry points in `Program.cs`; updated `/api/sm/login-history` to filter by `h.society_id=@s` so known-user failures can be scoped without relying on an inner user join. Unknown login attempts with no known society remain unexposed to society-scoped views.
- Applied migration 042 successfully to the configured `society_manager` database through an explicit transaction; verification confirmed the new column and both procedures exist. This is a schema-only, backward-compatible change plus deterministic backfill; no login-history rows were fabricated.
- Safe rollback-only procedure test: inside one transaction the new success and failure procedures created two transient history events and one summary row; the transaction was rolled back, and post-rollback history and summary counts matched their before-test values. No event or account change persisted. Because there is no isolated test DB and the user is already authenticated, a real new login event was not generated merely to populate the report.
- `wwwroot/modules/society-admin/requested-workflows.js`: Login / Session Audit now has localized title/columns, locale-aware timestamps, OR-search over user/login/IP/status/failure/trace/user-agent, a Refresh button, search-state preservation across refresh/language change, and a localized explicit empty state / no-match state. `wwwroot/js/i18n.js` adds those empty-state strings in all six configured languages. Asset cache keys bumped to `requested-workflows.js?v=20261024.21` and `i18n.js?v=20261024.08`.
- Static contract tests `scripts/verify_login_history_write_path.py` and `scripts/verify_audit_report_contract.py` passed. Release build to `C:\Society360BuildLoginHistory20261024` passed with 0 warnings/errors. The live app was restarted to this build; health returned HTTP 200 and `databaseConfigured=true` (runtime PID 21704).
- Visible Chrome acceptance: Login / Session Audit opened in the actual Society360 tab; search input and explicit empty state were present, with 0 persisted history rows because no new real login occurred after migration. Visible UI language test selected English, Hindi, Marathi, Gujarati, Kannada and Tamil; search label changed out of English in all five non-English locales and English was restored. A true persisted successful/failed login workflow remains pending a real authorized login or isolated test account.


## 2026-10-24 — Approval History implemented as a real audit-backed view

- Inspected the SQL migration sources: no dedicated generic `t_approval_history` table or `AUDIT_APPROVAL` read API existed; visitor invitation approvals are stored separately and cannot be presented as a universal approval ledger. To avoid fabricating approval rows, implemented Approval History as a read-only projection of actual `society_manager.t_audit_log` events whose action indicates approve/reject or whose persisted status changes to Approved/Rejected.
- Added `GET /api/sm/approval-history` in `Modules/SocietyAdmin/RequestedSocietyManagerEndpoints.cs`. It requires `AUDIT_APPROVAL` VIEW, filters by the authenticated session's society, limits results to the newest 1,000 entries, derives the decision from actual old/new JSONB status values, and removes the same sensitive password/token/session fields as Audit Trail.
- Added `approvalHistory()` and `AUDIT_APPROVAL` navigation dispatch in `wwwroot/modules/society-admin/requested-workflows.js`: real endpoint, locale-aware timestamps, approver/login/entity/record/action/decision/old-new fields, OR search, refresh, preserved search during language changes, and an explicit localized empty/no-match state. Added six-language translations in `wwwroot/js/i18n.js`; asset cache keys now `requested-workflows.js?v=20261024.22` and `i18n.js?v=20261024.09`.
- Added `scripts/verify_approval_history_contract.py`. All three static contract scripts passed (`verify_audit_report_contract.py`, `verify_login_history_write_path.py`, `verify_approval_history_contract.py`); Node syntax checks passed for `requested-workflows.js` and `i18n.js`; `git diff --check` passed with only line-ending warnings. Release build `C:\Society360BuildApprovalHistory20261024` passed with 0 warnings/errors.
- Restarted the expected prior Society360 process to the new build (PID `19676`); `/api/health` returned HTTP 200 and `databaseConfigured=true`.
- Visible Chrome acceptance: opened the actual Audit & Governance > Approval History menu. The page rendered the search field and explicit empty state, with 0 matching persisted approval decisions in the current society. The six-language UI selector test passed for English, Hindi, Marathi, Gujarati, Kannada and Tamil; the search label changed out of English in every non-English locale and English was restored. No approval records were fabricated or modified.
- Remaining acceptance: verify a real persisted approval decision appears after a legitimate approval workflow, test a dedicated `AUDIT_APPROVAL`-only role and cross-society denial, and inspect whether future approval workflows need a normalized durable approval ledger beyond the existing audit trail.
