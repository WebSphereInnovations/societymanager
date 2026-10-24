# Society360 Functionality Manual

Last updated: 2026-10-24 (IST). This manual describes expected operational workflows for the existing Society360 application. Existing source/API behavior takes precedence where a rule is already implemented; any unconfirmed business rule is explicitly marked as a decision rather than silently invented.

## Global operating rules

- **Roles:** Super Admin, Society Admin, and the specific cashier/collection, guard/security, and resident/customer roles that exist in the current role catalog. Actual role names and grants must be read from the database, not assumed from the UI. Enforce permissions on the server/API as well as hiding controls in the client.
- **Society isolation:** derive the active society from the authenticated session and enforce it in every query and mutation. Never trust a client-supplied society ID for authorization. Search, details, export, documents, receipts, and history must not disclose another society's records.
- **Persistence:** PostgreSQL through the existing ASP.NET Core/Npgsql architecture is the source of truth. Use the existing stored procedures/ORM/data-access conventions and versioned migrations. Never silently substitute mock data on API failure.
- **Audit:** preserve existing `modify-by`, `modify-date`, and `modify-remark` conventions; remarks may be empty when the existing schema allows it. Sensitive changes should retain history. Financial records should use reversal/void/adjustment flows rather than destructive deletion when required by the existing accounting model.
- **Concurrency and reliability:** server-side validation, parameterized database access, constraints, atomic transactions, clear errors, and idempotency for retried requests. A multi-step financial operation must roll back as a unit.
- **Localization:** the configured set is English, Hindi, Marathi, Gujarati, Kannada, Tamil. Keep canonical API/status identifiers stable; translate only presentation. Localize navigation, labels, placeholders, errors, confirmations, empty/loading states, table headers/filters/pagination, receipts/print output and report headers. Preserve user input when switching language where practical.
- **Common acceptance for every module:** authorized login; role access; actual UI navigation; valid and invalid input; search/filter/sort/pagination where applicable; success and failure feedback; database persistence; refresh/re-login persistence; unauthorized direct route/API denial; cross-society isolation; responsive desktop/mobile layout; all six languages; regression of existing workflows.

## 1. Dashboard (`home`)

**Purpose / users:** give an authorized society operator an accurate current and period-based operational/financial overview.

**Workflow:** open Dashboard → choose period/custom dates and supported dimensions → apply filters → inspect KPIs/charts → open a drill-down → navigate to the relevant module → refresh or change period.

**Data / rules:** use the existing dashboard analytics APIs and PostgreSQL-derived records. Keep current outstanding (open balance as of now) distinct from selected-period total billed/assessed amount and selected-period collection. Do not label a billed total as outstanding. For a period total, define inclusion of paid and unpaid bills consistently with the existing bill-period model; show a single unambiguous metric label. Exclude void/cancelled/failed records only according to existing accounting rules. Dashboard numbers must reconcile with source lists and reports.

**Validations / failures:** reject inverted date ranges; show localized API errors and loading/empty states; never replace a failed request with invented zeroes or sample data. Drill-downs must preserve filters and society scope.

**Acceptance:** compare KPIs with read-only SQL/API totals for the same period; test presets/custom dates, all filter dimensions, drill-down navigation, role/society scope, mobile layout and six locales.

## 2. Customer Account / Consumer 360 (`customers`)

**Purpose / users:** one selected consumer's master profile, multiple properties/units, balances, bills, payments, services, complaints, interactions, adjustments, documents and timeline.

**Workflow:** search by consumer ID/name/flat/mobile/email → choose a matching result → inspect one consumer's profile → open tabs for units, billing, payments, dues, service, complaints, interactions, adjustments, documents and timeline → follow a record link to the owning module.

**Inputs / validation:** partial-prefix search must be debounced and race-safe; empty and no-match results are distinct from request failures. IDs are canonical and stable; do not join records by display name alone. Only selected consumer records and authorized linked units may be shown.

**Data / relationships:** consumer master relates to flats/units, bills, payments/allocations, service charges, complaints, adjustments and documents. Each tab must use actual scoped APIs, server-side pagination/filtering where supported, and stable sort order. Export must honor the exact active filters and permission scope.

**Acceptance:** test multiple flats, name/ID/flat/mobile search, no result/error, every tab, paging/search/export, cross-module record links, refresh/re-login, unauthorized references, all six locales and responsive layout.

## 3. Society profile, building/wing, flat, resident/family (`flats`, `customers`, `configuration`)

**Purpose / users:** maintain the society's property hierarchy and resident ownership/occupancy links.

**Workflow:** select the appropriate Society Profile / Building / Wing / Flat / Resident menu → search/list → create or edit a record using the existing form → validate identifiers and relationships → save → verify list/detail and linked Customer Account → inspect audit history.

**Validation:** enforce required codes/names, valid parent-child relationships, unique keys where defined, valid occupancy/ownership dates and permitted status transitions. Do not cascade-delete financially referenced units or residents without an existing supported archival workflow.

**Data:** preserve society → building/wing → flat/unit and consumer/resident relationships. A resident can be linked to multiple units if the schema permits it. Parking, billing and documents must reference stable IDs, not mutable labels.

**Acceptance:** safe test fixtures only; duplicate and missing-parent validation; relationship integrity; role permissions; audit; list/search/pagination; language and mobile regression.

## 4. Billing configuration and rate master (`billing-configuration`, `configuration`)

**Purpose / users:** configure billing frequency, DPC applicability/rate/application basis, property-specific charge rates, effective dates and remarks.

**Workflow:** load current configuration and history → edit permitted fields → validate effective dates/rates → save → confirm new version appears in history → verify only future eligible billing uses the new version.

**Rules:** use existing rate codes and canonical values. Effective dates must not accidentally overlap or rewrite historical bills. Validate nonnegative rates, supported frequency/type, valid date ranges, and DPC rules. Changes require appropriate administrator permission and audit fields. Any ambiguous effective-date overlap rule must be resolved from current DB constraints/procedure behavior before changing it.

**Acceptance:** verify save/history in an isolated test database; invalid dates/rates; effective-version selection; historical bill immutability; six-language form/validation/history; no production rate changes during testing.

## 5. Billing process / bill register / adjustments (`billing-process`, `bills`)

**Purpose / users:** preview, validate and finalize bills for a selected billing month, then inspect and correct supported bill records.

**Workflow:** choose the next billing month → verify all mandatory rates → start a preview → review eligible units and calculations → resolve validation errors → finalize only when authorized → verify persisted bill rows/register and downstream Customer Account/dashboard totals.

**Rules:** use canonical month format `YYYYMM` where required. Keep raw arrears separate from calculated DPC/interest and other charges. Prevent duplicate finalization for the same society/month; use a transaction and safe retry/idempotency. Do not rewrite historical rates or delete posted financial records. Reversal, correction and adjustment workflows must preserve history.

**Acceptance:** preview reconciliation to underlying charges; missing-rate block; duplicate-submit behavior; failed-finalization rollback; final rows visible after refresh/re-login; source/register/account/dashboard consistency; permissions and six languages. Do not finalize production bills during verification.

## 6. Collection Management / Accept Payment / receipts (`collection`)

**Purpose / users:** record authorized customer payments and allocate them to due bills while issuing a traceable receipt. Collection/Cashier role must only see permitted menus and society records.

**Workflow:** search by consumer identifier/name/mobile/flat → select one consumer → review current bill, arrears, DPC/penalty, credits, service charges, prior payments and outstanding → enter payment amount and confirmation amount → choose payment date/mode and required reference/bank/cheque details → submit once → retrieve the server-created receipt → print/save PDF if supported → verify allocation/history/balance after refresh.

**Validation / data integrity:** reject blank, nonpositive, malformed or mismatched amounts; enforce valid date and supported payment mode; require cheque/DD/reference fields according to existing rules; protect against duplicate submission and double allocation; use a database transaction; use UTC when binding PostgreSQL `timestamptz` values. Never fabricate a receipt or display success before the API succeeds. If receipt retrieval fails after a successful payment, surface the payment identifier and warn against blind retry.

**Database verification:** verify the payment row, allocated amounts, receipt identifier, society/consumer links, audit values and existing required NULL/tag/month semantics. Reconcile payment amount with allocations according to the existing accounting procedure. Do not use production data for synthetic payment tests.

**Other collection submodules:** service payment must use the real service-charge balance; bank details must validate and audit changes; dishonoured cheque workflow must link the original cheque/payment and preserve financial history; reversal must require authorization and preserve original entries.

**Acceptance:** only against a confirmed isolated test DB and explicitly approved test customer/remittance: valid/invalid payment modes, duplicate request, server failure/rollback, receipt print, refresh/re-login, allocation and balance reconciliation, six-language UI and unauthorized-access tests. Without those prerequisites, do read-only checks and mark write acceptance blocked.

## 7. Complaints / service requests (`complaints`)

**Purpose / users:** register and track resident issues from submission through assignment, status changes, resolution and closure.

**Workflow:** create/select complaint → validate consumer/unit and category → assign authorized staff → add comments/status changes → notify permitted parties → resolve/close → inspect history.

**Data / rules:** stable complaint ID, society/consumer/unit references, category, priority, status, assignee, timestamps and audit history. Enforce allowed status transitions and role rights; don't expose private complaint content across societies.

**Acceptance:** creation, search, assignment, valid/invalid transition, comments/history, notification outcome, closed-record behavior, role restrictions, refresh persistence, all six languages.

## 8. Visitor / guard / security (`visitors`, `security`)

**Purpose / users:** record visitor entry/exit and support authorized security operations.

**Workflow:** authorized guard records visitor and intended flat/host → validate required visitor/time fields → mark entry → record exit → review currently inside and past visits. Security/audit pages are read-only unless a specific supported administrative action exists.

**Data / rules:** actual visit timestamps and society/unit references; prevent unauthorized edits and cross-society lookup. Protect sensitive visitor information. Security audit should not allow deletion or alteration of audit history.

**Acceptance:** entry/exit lifecycle, duplicate/invalid transitions, current-inside list, search/date filters, permissions, audit immutability, mobile UI and all six languages.

## 9. Parking / vehicles / assignments (`parking`)

**Purpose / users:** manage parking slots, vehicles, assignments and applicable charges.

**Workflow:** create/configure a slot → link a permitted unit/consumer and vehicle → assign/reassign/release → inspect availability and any configured charge → verify history.

**Rules:** prevent conflicting active assignments and duplicate slot occupancy; validate vehicle/slot identifiers; retain assignment history and audit. Never delete an occupied slot or break bill/payment references.

**Acceptance:** slot CRUD where supported, assignment/release, duplicate/conflict rejection, consumer links, search/pagination/export, persistence, society isolation and six languages.

## 10. Administrator / employee accounts / roles and rights / menu catalog (`accounts`)

**Purpose / users:** authorized administrators maintain employee accounts, validity, roles, action rights and visible menu catalog.

**Workflow:** list/search account → create or edit identity/contact/validity → assign account type and granular module/submodule/action rights → save → verify effective permissions through actual API authorization. Role workflow: select/create role → configure rights → save → verify. Menu workflow: create/edit code, label, parent, order and visibility → save → verify navigation and rights.

**Security:** passwords must be stored with the project's approved password-hashing mechanism, never logged or returned. Enforce blocked/expired accounts and permissions server-side. Client-side menu hiding is not authorization. Prevent self-lockout or privilege escalation according to existing rules. Audit account/role/menu changes. Do not modify production accounts/roles in acceptance tests.

**Acceptance:** safe isolated test account only; required fields, duplicate login, expiry/blocking, role matrix, direct API denial, hidden menu behavior, password reset/change, audit and all six languages.

## 11. Documents and notices (`module-workspace` until module-specific route is proven)

**Purpose / users:** maintain society/customer documents and deliver notices through supported channels.

**Expected document workflow:** select authorized society/consumer → upload supported file and metadata → validate type/size/ownership → save → list/search → download only with authorization → verify audit and association.

**Expected notice workflow:** draft notice → validate title/content/audience/schedule → preview → publish/send through configured provider → track delivery/failure status → retain history.

**Important status:** source currently maps `DOC_CUSTOMER`, `DOC_SOCIETY`, `DOC_TEMPLATE`, `NOTICE_CREATE`, `NOTICE_SMS`, and `NOTICE_PUSH` to the generic `module-workspace`. Until an actual module-specific form/API is demonstrated, these are **not accepted as implemented**. Provider credentials and delivery services are external dependencies; do not simulate successful delivery.

**Acceptance:** verify actual endpoint/provider availability, access-controlled file handling, audience scoping, delivery outcomes, failures/retries, audit, mobile layout and all six languages.

## 12. Reports and exports (`module-workspace` until verified)

**Purpose / users:** provide accurate bill, collection, outstanding, consumer and audit reporting.

**Workflow:** choose report → set period and supported filters → run query → inspect totals and rows → page/sort/search → export exactly the authorized filtered dataset. Billing Data uses bill-period options; Collection Details uses payment-date options. The options API retains the combined MONTH group for backward compatibility and adds BILL_MONTH and PAYMENT_MONTH groups so these reports do not filter against the wrong date basis.

**Rules:** report calculations must reconcile with source records; exclude statuses only according to existing accounting rules. Exports must enforce the same permission and society scope as the UI, sanitize filenames/values as needed, and localize headers without changing canonical identifiers. Chrome currently blocks the generated XLSX download from the configured HTTP origin as an insecure download; the app must not bypass this browser security policy. Until a secure origin or user-approved browser decision is available, tell the user to check Chrome Download history.

**Important status:** `RPT_BILLING`, `RPT_COLLECTION`, `RPT_OUTSTANDING`, `RPT_CONSUMER`, and `RPT_AUDIT` currently map to the generic workspace in `admin.js`; actual report-specific behavior must be verified before acceptance.

## 13. Migration (`SA_MIGRATION` / `MIGRATION`)

**Purpose / users:** controlled import/migration of legacy society data.

**Expected workflow:** choose supported import format → upload to staging → validate schema/required fields/references/duplicates → preview rejected and accepted rows → authorize execution → import atomically or by documented resumable batch → provide a reconciliation report and audit trail.

**Rules:** no partial silent success; never overwrite existing records without an explicit supported policy. Migration must be idempotent or have a reliable batch identity and rollback/recovery plan. No production import tests.

**Important status:** current mapping routes migration codes to generic workspace; the actual migration workflow is unverified and must not be called complete based on dashboard counters.

## 14. Notifications / subscription / common navigation

**Notifications:** show actual pending/sent/failed records; mark-read or retry only where supported and authorized; respect recipient and society scope. Provider delivery is blocked until its configured integration is verified. `NOTIFICATION_CENTER` currently maps to the generic workspace.

**Subscription:** current code loads `/api/subscription/current` and renders plan/payment status. Verify plan history, renewal/expiry, payment confirmation and administrator rights; never mark a payment successful without a trusted persisted transaction.

**Navigation:** menu tree is loaded from `/api/menu`, grouped by parent module code and translated with the centralized i18n layer. Verify every leaf code maps to a real module workflow; unknown codes falling back to `module-workspace` are placeholder candidates. Hidden/unauthorized routes must remain protected by backend authorization.

## Test record template

For each menu/submenu record: exact DB menu ID/code/name/parent; route/view; role and active society context (non-secret); UI workflow and timestamp; API calls/status; relevant DB query or before/after row counts without personal data; test environment fingerprint; locale; screenshot path if genuinely captured; regression result; defects; final status. Never record passwords, cookies, tokens, or connection strings.


## Implementation update — 2026-10-24: Outstanding / Aging report

`RPT_OUTSTANDING` now uses the dedicated `GET /api/sm/reports/outstanding?asOf=YYYY-MM-DD` route and `society_manager.fn_mis_outstanding`. The function scopes all bill rows to the authenticated society ID supplied by the existing guarded query helper, excludes closed/zero-balance bills, and calculates days overdue and the 1–30 / 31–60 / 61–90 / 90+ aging bucket in SQL. The screen presents bill number, billing period, due date, flat, primary consumer, total/paid/outstanding amounts, days overdue, aging bucket and status. The as-of date is a read-only report filter, not a bill mutation. The report re-renders its localized heading, date control and columns when the six-language selector changes, preserving the current date. Verified with real read-only data in visible Chrome and all six configured languages; alternate-date UI interaction and export acceptance remain pending.
