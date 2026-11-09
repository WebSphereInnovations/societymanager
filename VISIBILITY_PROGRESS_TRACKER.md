# Society360 / SKYFY NEXUS â€“ Visibility & Contrast Progress Tracker

Last updated: 2026-11-09
Branch: `feature/skyfy-nexus-local-audit`
Application under test: `http://192.168.1.8:5180/`

## Current verified progress

- Real Google Chrome 156 with local Selenium 4.50 was used; no dedicated ChatGPT browser-control tool was exposed, so Chrome automation was run locally on the authorized development machine.
- Public login page and Themes modal were rendered and contrast-audited.
- All 8 palettes Ã— all 4 appearance modes were exercised: **32 combinations**.
- Both rendered surfaces (login page and Themes modal) were audited per combination: **64 surfaces, 0 remaining contrast failures** in this tested scope.
- Input/select/button/modal-control checks ran in normal, theme-card-hover and selected-mode-hover states: **96 states × 23 controls = 2,208 control checks, 0 failures**.
- Final screenshot set: 32 palette/mode modal captures, 4 SKYFY BLUE login-page mode captures, desktop and 390px mobile captures.
- Responsive mobile-emulation test at 390 Ã— 844 CSS px: document width 390, body width 390, modal width 370, right edge 380; no horizontal overflow. Nine theme cards remained visible in the scrollable gallery.
- Login-language smoke test: English, Hindi, Marathi, Gujarati, Kannada and Tamil all switched without `???`, `undefined` or `null` in the visible login text; the Themes trigger translated in each language.
- Standard-theme reset test passed: `data-s360-theme=standard`, palette/mode attributes absent, and semantic SKYFY text token cleared.
- Initial unauthenticated profile scan found no active session. On 2026-11-09 the user signed in through the dedicated Chrome audit window; authenticated Society Admin access is now confirmed at `/modules/society-admin/index.html` as Lakeview Society Admin. No auth bypass was used.

## Scope and safety

- Visual-only changes. No API endpoint, auth/authorization, database schema/data, route handler, CRUD, search, filter, sorting, pagination, report or entitlement logic was intentionally changed.
- Existing working tree already contains many unrelated modified/untracked files. Do not reset, clean, stage or commit unrelated work.
- Module catalog source `MODULE_INVENTORY.md` records **254 `m_module` entries**, including **41 root entries**. Catalog flags are not proof that a particular logged-in role can access an item.
- Route mapping and role visibility remain pending until an authorized Society Admin / Super Admin / Cashier / Customer session is available.

## Root causes identified and corrected in the tested scope

1. Global muted/label styling forced pale theme text onto the white login form surface. The login shell/form/signup surfaces now use theme semantic surfaces and matching text tokens.
2. Bright palette primary/accent gradients used a fixed white foreground, failing contrast on several palettes. Foreground and gradient stops are now calculated/adjusted as a pair to meet 4.5:1.
3. Theme trigger, signup CTA and support launcher inherited button gradients/text colors that did not suit their actual surfaces. They now use explicit semantic surfaces and contrast-safe text.
4. Theme modal kicker, palette metadata and status text used fixed lavender/light colors on backgrounds where contrast varied. These now use semantic text tokens.
5. A legacy SKYFY selector assigned a dark background to every theme-card `small`, including in light mode. That background was removed; the text now sits on the card surface.
6. Standard palette preview label had insufficient contrast. Its preview-specific foreground was darkened.
7. Brand-mark gradient's lightest stop did not meet the large-text contrast threshold. The mark now uses a darker two-stop gradient.
8. Theme token values could leak after switching back to Standard. Semantic variables are cleared when Standard is selected.

These are root-cause groups, not a count of every individual rendered text node across the full app.

## Theme/mode matrix â€“ login page + Themes modal only

| Palette | Dark | Light | Glass | Gradient |
|---|---|---|---|---|
| SKYFY BLUE | PASS | PASS | PASS | PASS |
| RUBY RED | PASS | PASS | PASS | PASS |
| ROYAL PURPLE | PASS | PASS | PASS | PASS |
| EMERALD GREEN | PASS | PASS | PASS | PASS |
| GOLDEN LUXURY | PASS | PASS | PASS | PASS |
| CYBER CYAN | PASS | PASS | PASS | PASS |
| SUNSET ORANGE | PASS | PASS | PASS | PASS |
| ARCTIC SILVER | PASS | PASS | PASS | PASS |

Contrast result: 0 failures in the 64 audited login/theme-modal surfaces. This result must not be generalized to authenticated modules that have not yet been rendered.

## Page checklist

| Page | Route | Scope actually inspected | Result | Screenshot |
|---|---|---|---|---|
| Login | `/login.html` | Login form, language selector, Themes trigger, theme modal, palette cards, mode controls, support launcher; 8 palettes Ã— 4 modes | Verified â€“ 0 contrast failures | `visibility-screenshots/final-login-DARK.png` and `final-login-LIGHT.png`, `final-login-GLASS.png`, `final-login-GRADIENT.png` |
| Society Admin shell | `/modules/society-admin/index.html` | Authenticated dashboard rendered; navigation opened; Collection Management > Accept Payment workspace opened in the SPA; screenshot captured | In progress â€“ detailed page/theme contrast audit pending | `visibility-screenshots/final-society-admin-dashboard-authenticated.png`, `final-society-admin-dashboard-authenticated-nav.png`, `final-society-admin-accept-payment.png` |
| Cashier shell | `/modules/cashier/index.html` | Not visually inspected | Pending authenticated visual inspection | â€” |
| Customer shell | `/modules/customer/index.html` | Not visually inspected | Pending authenticated visual inspection | â€” |
| Migration shell | `/modules/migration/index.html` | Not visually inspected | Pending authenticated visual inspection | â€” |
| Main shell | `/index.html` | Not visually inspected | Pending authenticated visual inspection | â€” |
| Super Admin Security | `/super-admin-security.html` | Not visually inspected | Pending authorized Super Admin session | â€” |
| Super Admin Themes access | `/super-admin-theme-access.html` | Not visually inspected | Pending authorized Super Admin session | â€” |

## Main menu / submenu / module checklist

Source: all 254 catalog records parsed from `MODULE_INVENTORY.md`. Every row remains pending until the item is opened under an authorized role and its rendered states are checked. `Pending route mapping` means no route was guessed from a module code.

| Main menu | Full catalog path | Module code | Route | Catalog visible | Catalog active | Palette/mode | Hover/active/expanded | Screenshot | Status |
|---|---|---|---|---|---|---|---|---|---|
| Dashboard | Dashboard | `APP_DASHBOARD` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Administrator | Administrator | `ADMINISTRATOR` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Dashboard | Dashboard | `DASHBOARD` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Dashboard | Dashboard | `SUPER_DASHBOARD` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Back Office | Back Office | `BACK_OFFICE` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Society Management | Society Management | `SOCIETY` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Society Management | Society Management | `SOCIETY_MANAGEMENT` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Billing Management | Billing Management | `BILLING_MANAGEMENT` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Users | Users | `USERS` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Collection Management | Collection Management | `COLLECTION_MANAGEMENT` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Roles & Rights | Roles & Rights | `ROLES` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Configuration | Configuration | `CONFIGURATION` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Connection Management | Connection Management | `CONNECTION_MANAGEMENT` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Customer Relationship Management | Customer Relationship Management | `CRM` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Buildings / Wings / Flats | Buildings / Wings / Flats | `FLATS` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Residents | Residents | `RESIDENTS` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Billing | Billing | `BILLING` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Device Authorization | Device Authorization | `DEVICE_AUTH` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Collection & Receipts | Collection & Receipts | `COLLECTION` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Meter Management System | Meter Management System | `METER_MANAGEMENT` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Notification Center | Notification Center | `NOTIFICATION_CENTER` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| MIS | MIS | `MIS` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Parking & Vehicles | Parking & Vehicles | `PARKING` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Complaints | Complaints | `COMPLAINTS` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Recovery Management [Discon & Recon] | Recovery Management [Discon & Recon] | `RECOVERY_MANAGEMENT` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Visitors & Security | Visitors & Security | `VISITORS` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Documents | Documents | `DOCUMENTS` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Water Distribution Management | Water Distribution Management | `WATER_DISTRIBUTION` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Notices & Communication | Notices & Communication | `NOTICES` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Society Administration | Society Administration | `SOCIETY_ADMIN_EXTRA` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Reports | Reports | `REPORTS` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Security & Visitor Management | Security & Visitor Management | `SECURITY_VISITOR` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Migration | Migration | `MIGRATION` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Parking Management | Parking Management | `PARKING_MANAGEMENT` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Audit | Audit | `AUDIT` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Document Management | Document Management | `DOCUMENT_MANAGEMENT` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Notice & Communication | Notice & Communication | `NOTICE_COMMUNICATION` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Reports & Analytics | Reports & Analytics | `REPORTING_ANALYTICS` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Audit & Governance | Audit & Governance | `AUDIT_GOVERNANCE` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Migration Control | Migration Control | `MIGRATION_CONTROL` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Subscription & Platform Billing | Subscription & Platform Billing | `SUBSCRIPTION_PLATFORM` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Administrator | Administrator / Manage Account / Create Account | `ADMIN_CREATE_ACCOUNT` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Administrator | Administrator / Manage Account / Manage / Edit Account | `ADMIN_MANAGE_ACCOUNT` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Administrator | Administrator / Manage Account | `ADM_ACCOUNTS` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Administrator | Administrator / Add / Edit Contractor | `ADM_CONTRACTOR` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Administrator | Administrator / Add / Edit Employee | `ADM_EMPLOYEE` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Administrator | Administrator / Role Master | `ADM_ROLE_MASTER` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Administrator | Administrator / Customer Counts | `ADM_CUSTOMER_COUNTS` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Administrator | Administrator / Subscription & Billing Plan | `ADMIN_SUBSCRIPTION` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Administrator | Administrator / SMS Configuration | `ADM_SMS_CONFIG` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Administrator | Administrator / Master Data Entry | `ADM_MASTER_DATA` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Administrator | Administrator / Collection Configuration | `ADM_COLLECTION_CONFIG` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Administrator | Administrator / Send SMS Manually | `ADM_SEND_SMS` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Administrator | Administrator / Role & Rights | `ROLE_RIGHTS` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Administrator | Administrator / Module & Submodule | `MODULE_SUBMODULE` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Dashboard | Dashboard / Billing | `DASH_BILLING` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Dashboard | Dashboard / Collection | `DASH_COLLECTION` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Dashboard | Dashboard / CRM | `DASH_CRM` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Dashboard | Dashboard / RTS | `DASH_RTS` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Audit | Audit / Audit Trail | `SA_AUDIT` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Audit | Audit / Audit Log | `SUPER_AUDIT` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Audit & Governance | Audit & Governance / Audit Trail | `AUDIT_LOG` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Audit & Governance | Audit & Governance / Login / Session Audit | `AUDIT_LOGIN` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Audit & Governance | Audit & Governance / Approval History | `AUDIT_APPROVAL` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Back Office | Back Office / Raise Ticket | `BACKOFFICE_TICKET` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Back Office | Back Office / Raise Ticket [IT Help Desk] | `BO_TICKET` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Back Office | Back Office / IT Help Desk Dashboard | `BO_HELPDESK` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Back Office | Back Office / Document Management System | `BACKOFFICE_DOCUMENT` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Back Office | Back Office / Document Management System | `BO_DOCUMENTS` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Back Office | Back Office / Update Service Attribute | `BACKOFFICE_SERVICE` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Back Office | Back Office / Update Service Attributes | `BO_SERVICE_ATTRIBUTES` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Back Office | Back Office / Master Data Migration | `BACKOFFICE_MIGRATION` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Back Office | Back Office / Master Data Migration | `BO_MASTER_MIGRATION` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Back Office | Back Office / New Consumer Migration | `BO_CONSUMER_MIGRATION` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Billing | Billing / My Bills | `CUST_BILLS` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Billing | Billing / Billing Dashboard | `SA_BILLING_DASH` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Billing | Billing / Billing Configuration | `BILLING_CONFIGURATION` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Billing | Billing / Bill Generation | `SA_BILL_GENERATION` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Billing | Billing / Billing Process | `BILLING_PROCESS` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Billing | Billing / Bill Lookup | `CASH_BILL_LOOKUP` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Billing | Billing / Bill Register | `SA_BILL_REGISTER` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Billing | Billing / Adjustment | `CASH_ADJUSTMENT` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Billing | Billing / My Adjustments | `CUST_ADJUSTMENTS` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Billing | Billing / Billing Adjustment | `SA_BILL_ADJUSTMENT` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Billing Management | Billing Management / Billing Range Interface | `BILL_RANGE` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Billing Management | Billing Management / Dummy Cycle Bill Schedule | `BILL_DUMMY_CYCLE` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Billing Management | Billing Management / Error Warning Correction | `BILL_ERROR_CORRECTION` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Billing Management | Billing Management / Bill Computation | `BILL_COMPUTATION` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Billing Management | Billing Management / Download Bill | `BILL_DOWNLOAD` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Billing Management | Billing Management / Revert Billing | `BILL_REVERT` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Billing Management | Billing Management / Billing Tracker Report | `BILL_TRACKER` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Billing Management | Billing Management / Billing Adjustment | `BILL_ADJUSTMENT` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Billing Management | Billing Management / Tariff Rate Details | `BILL_TARIFF` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Billing Management | Billing Management / Dummy Billing | `BILL_DUMMY` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Billing Management | Billing Management / Estimated Average Unit Interface | `BILL_ESTIMATE` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Collection & Receipts | Collection & Receipts / Customer Search | `CASH_CUSTOMER` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Collection & Receipts | Collection & Receipts / My Payments | `CUST_PAYMENTS` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Collection & Receipts | Collection & Receipts / Collection | `SA_COLLECTION` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Collection & Receipts | Collection & Receipts / Accept Payment | `CASH_ACCEPT_PAYMENT` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Collection & Receipts | Collection & Receipts / My Receipts | `CUST_RECEIPTS` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Collection & Receipts | Collection & Receipts / Payment Entry | `SA_PAYMENT_ENTRY` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Collection & Receipts | Collection & Receipts / Receipt Reprint | `CASH_RECEIPTS` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Collection & Receipts | Collection & Receipts / Receipts | `SA_RECEIPTS` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Collection & Receipts | Collection & Receipts / Payment Allocation | `CASH_ALLOCATION` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Collection & Receipts | Collection & Receipts / Collection Reversal | `SA_REVERSAL` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Collection & Receipts | Collection & Receipts / Payment Reversal | `CASH_REVERSAL` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Collection Management | Collection Management / Accept Payment | `COL_ACCEPT` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Collection Management | Collection Management / Accept Payment | `COL_ACCEPT_PAYMENT` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Collection Management | Collection Management / Accept Services Payment | `COL_SERVICE` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Collection Management | Collection Management / Accept Services Payment | `COL_SERVICE_PAYMENT` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Collection Management | Collection Management / Add / Edit Bank Details | `COL_BANK` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Collection Management | Collection Management / Add / Edit Bank Details | `COL_BANK_DETAILS` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Collection Management | Collection Management / Add / Edit Collection Center | `COL_CENTER` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Collection Management | Collection Management / Cancel Receipt Summary | `COL_CANCEL_SUMMARY` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Collection Management | Collection Management / Daily Collection Report | `COL_DAILY` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Collection Management | Collection Management / Dishonored Cheque | `COL_CHEQUE` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Collection Management | Collection Management / Dishonored Cheque | `COL_DISHONORED` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Collection Management | Collection Management / Payment Collection Counter Report | `COL_COUNTER` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Collection Management | Collection Management / Payment Reconciliation | `COL_RECON` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Collection Management | Collection Management / Receipt Cancellation | `COL_RECEIPT_CANCEL` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Collection Management | Collection Management / Receipt Cancelled Authentication | `COL_CANCEL_AUTH` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Complaints | Complaints / My Complaints | `CUST_COMPLAINTS` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Complaints | Complaints / Complaints | `SA_COMPLAINTS` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Configuration | Configuration / System Settings | `SUPER_SETTINGS` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Configuration | Configuration / Charge & Rate Configuration | `SA_CHARGE_CONFIG` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Configuration | Configuration / Rate Plans & Effective Dates | `SA_RATE_PLANS` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Configuration | Configuration / Tax / GST Configuration | `SA_TAX_CONFIG` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Connection Management | Connection Management / Connection Application | `CONN_APPLICATION` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Connection Management | Connection Management / Service / Connection Details | `CONN_SERVICE` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Connection Management | Connection Management / Connection Transfer | `CONN_TRANSFER` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Connection Management | Connection Management / Disconnection / Reconnection | `CONN_DISCON_RECON` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Connection Management | Connection Management / Connection History | `CONN_HISTORY` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Customer Relationship Management | Customer Relationship Management / Customer Search | `CRM_CUSTOMER_SEARCH` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Customer Relationship Management | Customer Relationship Management / Customer 360 | `CRM_CUSTOMER_360` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Customer Relationship Management | Customer Relationship Management / Customer Account | `CRM_CUSTOMER_ACCOUNT` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Customer Relationship Management | Customer Relationship Management / Customer Interaction | `CRM_CUSTOMER_INTERACTION` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Customer Relationship Management | Customer Relationship Management / Customer Interactions | `CRM_INTERACTION` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Customer Relationship Management | Customer Relationship Management / Complaints / Grievances | `CRM_COMPLAINT` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Customer Relationship Management | Customer Relationship Management / Service Requests | `CRM_SERVICE_REQUEST` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Dashboard | Dashboard / Dashboard | `CASH_DASHBOARD` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Dashboard | Dashboard / My Dashboard | `CUST_DASHBOARD` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Dashboard | Dashboard / Dashboard | `SA_DASHBOARD` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Device Authorization | Device Authorization / Device Registration | `DEV_REGISTER` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Device Authorization | Device Authorization / Device Assignment | `DEV_ASSIGN` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Device Authorization | Device Authorization / Device Authentication | `DEV_AUTH` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Device Authorization | Device Authorization / Device Status | `DEV_STATUS` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Document Management | Document Management / Customer Documents | `DOC_CUSTOMER` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Document Management | Document Management / Society Documents | `DOC_SOCIETY` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Document Management | Document Management / Templates | `DOC_TEMPLATE` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Documents | Documents / My Documents | `CUST_DOCUMENTS` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Documents | Documents / Documents | `SA_DOCUMENTS` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Buildings / Wings / Flats | Buildings / Wings / Flats / Buildings | `SA_BUILDINGS` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Buildings / Wings / Flats | Buildings / Wings / Flats / Wings | `SA_WINGS` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Buildings / Wings / Flats | Buildings / Wings / Flats / Flats | `SA_FLATS` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Meter Management System | Meter Management System / Meter Master | `MTR_MASTER` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Meter Management System | Meter Management System / Meter Assignment | `MTR_ASSIGN` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Meter Management System | Meter Management System / Meter Replacement | `MTR_REPLACEMENT` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Meter Management System | Meter Management System / Meter Testing | `MTR_TEST` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Meter Management System | Meter Management System / Meter History | `MTR_HISTORY` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Migration | Migration / Back Office Migration | `SA_MIGRATION` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Migration Control | Migration Control / Migration Preview | `MIG_PREVIEW` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Migration Control | Migration Control / Migration Validation | `MIG_VALIDATE` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Migration Control | Migration Control / Import / Commit | `MIG_IMPORT` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Migration Control | Migration Control / Error Download | `MIG_ERRORS` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Migration Control | Migration Control / Batch History / Rollback | `MIG_BATCH` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| MIS | MIS / Billing MIS | `MIS_BILLING` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| MIS | MIS / Consumer Master Data | `MIS_CONSUMER_MASTER` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| MIS | MIS / Billing Data | `MIS_BILLING_DATA` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| MIS | MIS / Collection MIS | `MIS_COLLECTION` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| MIS | MIS / Collection Details | `MIS_COLLECTION_DETAILS` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| MIS | MIS / Consumer MIS | `MIS_CONSUMER` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| MIS | MIS / Complaint History | `MIS_COMPLAINT_HISTORY` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| MIS | MIS / Meter MIS | `MIS_METER` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| MIS | MIS / Exception MIS | `MIS_EXCEPTION` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Notice & Communication | Notice & Communication / Notice Management | `NOTICE_CREATE` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Notice & Communication | Notice & Communication / SMS / Email | `NOTICE_SMS` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Notice & Communication | Notice & Communication / Notifications | `NOTICE_PUSH` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Notices & Communication | Notices & Communication / Society Notices | `CUST_NOTICES` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Notices & Communication | Notices & Communication / Notices | `SA_NOTICES` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Notices & Communication | Notices & Communication / Notifications | `CUST_NOTIFICATIONS` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Notices & Communication | Notices & Communication / SMS / Email / Notifications | `SA_COMMUNICATION` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Parking & Vehicles | Parking & Vehicles / My Parking | `CUST_PARKING` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Parking & Vehicles | Parking & Vehicles / Parking Slots | `SA_PARKING` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Parking & Vehicles | Parking & Vehicles / My Vehicles | `CUST_VEHICLES` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Parking & Vehicles | Parking & Vehicles / Vehicles | `SA_VEHICLES` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Parking & Vehicles | Parking & Vehicles / Parking Assignment | `SA_PARKING_ASSIGN` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Parking Management | Parking Management / Parking Slots | `PARK_SLOT` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Parking Management | Parking Management / Parking Assignment | `PARK_ASSIGN` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Parking Management | Parking Management / Vehicles | `PARK_VEHICLE` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Parking Management | Parking Management / Parking Charges | `PARK_CHARGE` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Recovery Management [Discon & Recon] | Recovery Management [Discon & Recon] / Recovery Due List | `RECOVERY_DUE` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Recovery Management [Discon & Recon] | Recovery Management [Discon & Recon] / Disconnection | `RECOVERY_DISCON` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Recovery Management [Discon & Recon] | Recovery Management [Discon & Recon] / Reconnection | `RECOVERY_RECON` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Recovery Management [Discon & Recon] | Recovery Management [Discon & Recon] / Recovery Tracker | `RECOVERY_TRACKER` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Reports & Analytics | Reports & Analytics / Billing Reports | `RPT_BILLING` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Reports & Analytics | Reports & Analytics / Collection Reports | `RPT_COLLECTION` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Reports & Analytics | Reports & Analytics / Outstanding / Aging | `RPT_OUTSTANDING` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Reports & Analytics | Reports & Analytics / Consumer Reports | `RPT_CONSUMER` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Reports & Analytics | Reports & Analytics / Audit Reports | `RPT_AUDIT` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Reports | Reports / Reports | `SA_REPORTS` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Residents | Residents / My Profile | `CUST_PROFILE` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Residents | Residents / Residents / Owners | `SA_RESIDENTS` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Residents | Residents / My Flat / Unit | `CUST_FLAT` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Residents | Residents / Family / Occupants | `SA_FAMILY` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Residents | Residents / Family Members | `CUST_FAMILY` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Roles & Rights | Roles & Rights / Roles & Rights | `SUPER_ROLES` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Roles & Rights | Roles & Rights / Modules & Submodules | `SUPER_MODULES` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Roles & Rights | Roles & Rights / Security & Sessions | `SUPER_SECURITY` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Security & Visitor Management | Security & Visitor Management / Security Dashboard | `SEC_DASHBOARD` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Security & Visitor Management | Security & Visitor Management / Guard Management | `SEC_GUARDS` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Security & Visitor Management | Security & Visitor Management / Shift / Roster Management | `SEC_ROSTER` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Security & Visitor Management | Security & Visitor Management / Gate Management | `SEC_GATES` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Security & Visitor Management | Security & Visitor Management / Security Incident Management | `SEC_INCIDENTS` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Security & Visitor Management | Security & Visitor Management / Security Reports | `SEC_REPORTS` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Security & Visitor Management | Security & Visitor Management / Visitor Dashboard | `VIS_DASHBOARD` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Security & Visitor Management | Security & Visitor Management / Pre-Approved Visitor | `VIS_PREAPPROVAL` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Security & Visitor Management | Security & Visitor Management / Walk-in Visitor | `VIS_WALKIN` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Security & Visitor Management | Security & Visitor Management / Visitor Entry / Exit | `VIS_ENTRY_EXIT` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Security & Visitor Management | Security & Visitor Management / Delivery / Service Provider | `VIS_SERVICE` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Security & Visitor Management | Security & Visitor Management / Vehicle Management | `VIS_VEHICLE` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Security & Visitor Management | Security & Visitor Management / Visitor History | `VIS_HISTORY` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Security & Visitor Management | Security & Visitor Management / Blacklist / Restricted Visitor | `VIS_BLACKLIST` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Security & Visitor Management | Security & Visitor Management / Gate Dashboard | `SEC_GATE` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Security & Visitor Management | Security & Visitor Management / Visitor Entry / Exit | `SEC_VISITOR` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Security & Visitor Management | Security & Visitor Management / Resident Visitor Approval | `SEC_APPROVAL` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Security & Visitor Management | Security & Visitor Management / Vehicle Entry / Exit | `SEC_VEHICLE` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Society Management | Society Management / Society Profile | `SA_SOCIETY_PROFILE` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Society Management | Society Management / Societies | `SUPER_SOCIETIES` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Society Management | Society Management / Subscriptions & Plans | `SUPER_SUBSCRIPTIONS` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Society Management | Society Management / Platform Billing | `SUPER_PLATFORM_BILLING` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Society Administration | Society Administration / Rate / Tariff Configuration | `SA_RATE` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Society Administration | Society Administration / DPC / Interest Configuration | `SA_DPC` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Society Administration | Society Administration / Rebate Configuration | `SA_REBATE` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Society Administration | Society Administration / Waiver / Adjustment Rules | `SA_WAIVER` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Society Administration | Society Administration / Tax / GST Configuration | `SA_TAX` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Society Administration | Society Administration / Effective Date / Versioning | `SA_EFFECTIVE` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Society Management | Society Management / New Building | `SOC_NEW_BUILDING` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Society Management | Society Management / New Wing | `SOC_NEW_WING` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Society Management | Society Management / New Flat | `SOC_NEW_FLAT` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Society Management | Society Management / New Parking | `SOC_NEW_PARKING` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Society Management | Society Management / Customer | `SOC_CUSTOMER` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Society Management | Society Management / Customer / Area Management | `SOC_CUSTOMER_MASTER` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Society Management | Society Management / Area Update | `SOC_AREA_UPDATE` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Subscription & Platform Billing | Subscription & Platform Billing / Subscription Plans | `SUB_PLANS` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Subscription & Platform Billing | Subscription & Platform Billing / Society Subscriptions | `SUB_ACTIVE` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Subscription & Platform Billing | Subscription & Platform Billing / Subscription Payments | `SUB_PAYMENT` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Subscription & Platform Billing | Subscription & Platform Billing / Renewal / Expiry | `SUB_RENEWAL` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Users | Users / Users | `SUPER_USERS` | Pending route mapping | true | true | Pending | Pending | Pending | Pending authenticated inspection |
| Visitors & Security | Visitors & Security / Visitor Entry | `SA_VISITORS` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Visitors & Security | Visitors & Security / Security / Gate | `SA_SECURITY` | Pending route mapping | false | true | Pending | Pending | Pending | Pending authenticated inspection |
| Water Distribution Management | Water Distribution Management / Water Consumption | `WATER_CONSUMPTION` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Water Distribution Management | Water Distribution Management / Tank / Supply Management | `WATER_TANK` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Water Distribution Management | Water Distribution Management / Supply Schedule | `WATER_SCHEDULE` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |
| Water Distribution Management | Water Distribution Management / Zone Management | `WATER_ZONE` | Pending route mapping | false | false | Pending | Pending | Pending | Pending authenticated inspection |

## Screenshots and machine-readable evidence

- `visibility-screenshots/login-contrast-matrix-final.json` â€“ 32 combinations Ã— 2 surfaces, final contrast results (all zero failures).
- `visibility-screenshots/final-<PALETTE>-<MODE>-modal.png` â€“ 32 final theme modal screenshots.
- `visibility-screenshots/final-login-DARK.png`
- `visibility-screenshots/final-login-LIGHT.png`
- `visibility-screenshots/final-login-GLASS.png`
- `visibility-screenshots/final-login-GRADIENT.png`
- `visibility-screenshots/final-desktop-dark-theme-modal.png`
- `visibility-screenshots/final-mobile-dark-theme-modal.png`
- `visibility-screenshots/final-mobile-390-dark-theme-modal.png`

## Modified files in this visibility pass

- `wwwroot/js/theme-controller.js` â€“ centralized semantic token calculation, contrast-safe button foreground/background pairing, Standard token cleanup, dynamic CSS cache version.
- `wwwroot/css/dynamic-color-engine.css` â€“ scoped semantic component tokens and surfaces for controls, navigation, tables, modal, login/signup and support launcher.
- `wwwroot/css/theme-controller.css` â€“ removed hard-coded dark background from theme-card small text that leaked into light mode.
- Cache-busted `theme-controller.js` references in: `wwwroot/index.html`, `wwwroot/login.html`, `wwwroot/super-admin-security.html`, `wwwroot/super-admin-theme-access.html`, `wwwroot/modules/cashier/index.html`, `wwwroot/modules/customer/index.html`, `wwwroot/modules/migration/index.html`, `wwwroot/modules/society-admin/index.html`.

## Regression / static checks

- `node --check wwwroot/js/theme-controller.js` â€“ passed.
- `git diff --check` for touched visibility source files â€“ passed.
- Live login page and theme catalog HTTP smoke â€“ passed in prior baseline; theme options remain protected (unauthenticated 401 expected).
- Guest palette preview and all four modes â€“ exercised in Chrome.
- Standard theme reset â€“ passed.
- Six login languages â€“ switched without broken placeholder text.
- Mobile 390px viewport â€“ no horizontal overflow.
- Authenticated menu/API/Tabulator/CRUD regression â€“ **not run**, because no authorized development session was available. No claim of full application regression completion.

## Current totals

- Main menus visually inspected: **0** (authentication required; catalog rows are not visual proof).
- Submenus visually inspected: **0**.
- Pages visually inspected: **1 public page** (`/login.html`) plus the Themes modal component.
- Palette/mode combinations tested: **32**.
- Rendered surfaces contrast-audited: **64**.
- Form/select/button/modal control checks: **2,208**, across 96 normal/hover states.
- Contrast failures remaining in tested surfaces: **0**.
- Root-cause groups corrected in tested scope: **8**.
- Total app-wide contrast failures remaining: **Not yet measurable** until all authenticated menus/pages are rendered.

## Exact next item â€“ resume here

1. Sign in to the dedicated Chrome audit window currently open at `http://192.168.1.8:5180/login.html` using an authorized Society Admin development account; then notify me that login is complete. Do not send the password in chat and do not bypass auth.
2. Open the Society Admin shell in Chrome, record the actual visible root menus and click each menu/submenu individually.
3. Map each visible catalog row to its actual route/page; update the corresponding row above immediately after each visual check.
4. Run the rendered contrast audit across all 8 Ã— 4 theme/mode combinations for every page and key component; capture a screenshot for each corrected page.
5. Repeat role-specific menu checks and the same process for Super Admin, Cashier and Customer.

## Completion policy

No module, submenu or page may be marked complete based on source inspection, route HTTP 200, or another page's result. Completion requires actual Chrome rendering, recorded foreground/background contrast, hover/active/expanded/disabled states where present, responsive review, screenshot reference and a retest after correction.


## Authenticated continuation – 2026-11-09

- Dedicated Chrome CDP window now has a real Society Admin session. Verified page title `Society360 — Society Admin`, user `Lakeview Society Admin`, society `Lakeview Residency`; dashboard content and DB-backed metrics rendered.
- Opened the navigation drawer using its normal UI control. The actual rendered Society Admin navigation contains 17 `details.nav-group` sections, including Administrator, Back Office, Society Management, Collection Management, CRM, Billing, MIS, Society Administration, Security & Visitor Management, Parking Management, Audit, Document Management, Notice & Communication, Reports & Analytics, Audit & Governance and Preferences.
- Enumerated visible menu-item labels and their real `data-module-code` / `data-view` values from the rendered DOM. This is a live role-specific navigation snapshot, not an assumption from the module catalog.
- Opened Collection Management > Accept Payment through the actual menu control. The app stayed in its existing SPA route `/modules/society-admin/index.html` and rendered the Collection Management workspace with Accept Payment, Accept Services Payment, Add / Edit Bank Details, Dishonored Cheque and Search customer. No payment was submitted and no data was changed.
- Captured authenticated dashboard, expanded navigation and Accept Payment workspace screenshots in `visibility-screenshots/`.
- Remaining: detailed text-node contrast scan and hover/active/disabled states for this workspace; visit every visible menu/submenu; exercise all 8 palettes × 4 modes on authenticated pages; inspect responsive layouts; repeat only with separately authorized Super Admin, Cashier and Customer sessions. No role is marked complete from catalog presence alone.

## Implementation and authenticated Chrome verification – superseding update 2026-11-09

The earlier entry stating that authenticated navigation was unavailable is superseded: the user signed in to the dedicated Chrome audit window. The live authenticated user is Lakeview Society Admin for Lakeview Residency.

### Source corrections now saved
- `wwwroot/js/theme-controller.js`: `--s360-menu-active-background` now uses `buttonPair.adjusted[0]`, ensuring the foreground/background pair is contrast-adjusted.
- `wwwroot/css/dynamic-color-engine.css`: added semantic styling for authenticated workspace panels/cards, headings, paragraphs/helper text, labels, inputs/selects/textareas, placeholders/options, neutral and selected buttons, focus-visible and disabled states; added sidebar logo/profile/avatar, active/hover nav descendants, and Navigation Settings dialog corrections.
- Cache-bust reference: `dynamic-color-engine.css?v=20261109.16`.

### Actual Chrome results
- 71 visible Society Admin navigation entries opened after the latest CSS patch; 0 navigation exceptions; 69 distinct module codes. 71 final screenshots: `visibility-screenshots/menu-final-*.png`; index: `society-admin-menu-sweep-final.json`.
- 32 combinations on Accept Payment and 32 combinations on Create Account (8 palettes × Dark, Light, Glass, Dynamic Gradient). Matrices and 64 screenshots are saved under `visibility-screenshots/`.
- Create Account component contrast calculations across the 32 combinations: inputs minimum 13.11:1; neutral buttons minimum 8.80:1; labels minimum 8.82:1; none below 4.5:1.
- Ruby Red / Light selected menu and Navigation Settings selected choice were measured at 4.51:1 after the active-token correction. Navigation Settings collapse label 13.42:1. Avatar 4.51:1; account helper paragraph on white form surface 8.82:1.
- Mobile emulation 390×844 checked for Dashboard and Create Account; no horizontal overflow.
- Existing Dashboard 3D building and elevator animations are present and running (8s building / 9s elevator).
- Language selector switched English, Hindi, Marathi, Gujarati, Kannada and Tamil; no `???`, `undefined` or `null` strings detected. Some data/status values remain English; do not treat this as complete translation coverage.

### Exact last completed item / next item
- Last fully matrix-tested page: Society Admin → Administrator → Create Account.
- Latest menu-wide pass: all 71 rendered navigation entries opened and final screenshots captured; this is a navigation/render smoke pass, not a full workflow or every-control acceptance pass.
- Next page to fully inspect: Society Admin → Administrator → Manage / Edit Account. Continue through all inner pages and component states.

### Limits that remain explicit
- Only Society Admin authorized session available. Super Admin, Cashier and Customer roles cannot be marked verified without their authorized sessions.
- A full per-text pixel-level contrast audit of every page and all 32 theme/mode combinations per page is not yet complete. Do not mark untested pages complete.
- No API, auth, database, CRUD or payment logic was modified.

## Final v16 follow-up – 2026-11-09

- Latest cache-bust is `dynamic-color-engine.css?v=20261109.16`. Follow-up CSS now also corrects sidebar logo/profile metadata, avatar foreground/background, selected/hover nav descendants, all workspace h1–h4 and paragraph/small text, footer/breadcrumb text, and Navigation Settings dialog option/collapse labels.
- A final post-v16 Chrome sweep opened all 71 rendered Society Admin navigation entries; 71/71 opened, 0 errors, 69 distinct module codes. 71 final screenshots are `visibility-screenshots/menu-v16-g*-i*.png`; index `society-admin-menu-sweep-v16.json`.
- Post-v16 Chrome was restored to Dashboard, Ruby Red / Light, English. CSS version 16 was confirmed loaded; resource timing contained no response status >=400.
- Live style checks after correction: Ruby Red / Light avatar 4.51:1; selected Navigation Settings option text inherits the contrast-safe selected text; Navigation Settings collapse label 13.42:1; account helper text on the form surface 8.82:1. Sidebar logo and role/society metadata now use dark semantic text on the light sidebar surface.
- The 3D building model itself runs the 8s drift animation; the elevator cabin runs the 9s travel animation. The building face is intentionally static within the animated 3D model.
