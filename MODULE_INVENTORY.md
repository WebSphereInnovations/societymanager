# SKYFY NEXUS — Complete Existing Module Inventory

## Live PostgreSQL module catalog snapshot

Source: read-only query of `society_manager.m_module`, 2026-11-09.
Total rows: 254. Root entries: 41. The menu API applies the current user's role and permissions; visible/active flags below are catalog state, not proof that a given user sees the item.

```text
APP_DASHBOARD | ROOT | Dashboard | visible=true | active=true
ADMINISTRATOR | ROOT | Administrator | visible=true | active=true
DASHBOARD | ROOT | Dashboard | visible=false | active=true
SUPER_DASHBOARD | ROOT | Dashboard | visible=false | active=true
BACK_OFFICE | ROOT | Back Office | visible=true | active=true
SOCIETY | ROOT | Society Management | visible=false | active=true
SOCIETY_MANAGEMENT | ROOT | Society Management | visible=true | active=true
BILLING_MANAGEMENT | ROOT | Billing Management | visible=false | active=false
USERS | ROOT | Users | visible=false | active=true
COLLECTION_MANAGEMENT | ROOT | Collection Management | visible=true | active=true
ROLES | ROOT | Roles & Rights | visible=false | active=true
CONFIGURATION | ROOT | Configuration | visible=false | active=true
CONNECTION_MANAGEMENT | ROOT | Connection Management | visible=false | active=false
CRM | ROOT | Customer Relationship Management | visible=true | active=true
FLATS | ROOT | Buildings / Wings / Flats | visible=false | active=true
RESIDENTS | ROOT | Residents | visible=false | active=true
BILLING | ROOT | Billing | visible=true | active=true
DEVICE_AUTH | ROOT | Device Authorization | visible=false | active=false
COLLECTION | ROOT | Collection & Receipts | visible=false | active=true
METER_MANAGEMENT | ROOT | Meter Management System | visible=false | active=false
NOTIFICATION_CENTER | ROOT | Notification Center | visible=true | active=true
MIS | ROOT | MIS | visible=true | active=true
PARKING | ROOT | Parking & Vehicles | visible=false | active=true
COMPLAINTS | ROOT | Complaints | visible=false | active=true
RECOVERY_MANAGEMENT | ROOT | Recovery Management [Discon & Recon] | visible=false | active=false
VISITORS | ROOT | Visitors & Security | visible=false | active=true
DOCUMENTS | ROOT | Documents | visible=false | active=true
WATER_DISTRIBUTION | ROOT | Water Distribution Management | visible=false | active=false
NOTICES | ROOT | Notices & Communication | visible=false | active=true
SOCIETY_ADMIN_EXTRA | ROOT | Society Administration | visible=true | active=true
REPORTS | ROOT | Reports | visible=false | active=true
SECURITY_VISITOR | ROOT | Security & Visitor Management | visible=true | active=true
MIGRATION | ROOT | Migration | visible=false | active=true
PARKING_MANAGEMENT | ROOT | Parking Management | visible=true | active=true
AUDIT | ROOT | Audit | visible=true | active=true
DOCUMENT_MANAGEMENT | ROOT | Document Management | visible=true | active=true
NOTICE_COMMUNICATION | ROOT | Notice & Communication | visible=true | active=true
REPORTING_ANALYTICS | ROOT | Reports & Analytics | visible=true | active=true
AUDIT_GOVERNANCE | ROOT | Audit & Governance | visible=true | active=true
MIGRATION_CONTROL | ROOT | Migration Control | visible=false | active=true
SUBSCRIPTION_PLATFORM | ROOT | Subscription & Platform Billing | visible=false | active=true
ADMIN_CREATE_ACCOUNT | ADM_ACCOUNTS | Create Account | visible=true | active=true
ADMIN_MANAGE_ACCOUNT | ADM_ACCOUNTS | Manage / Edit Account | visible=true | active=true
ADM_ACCOUNTS | ADMINISTRATOR | Manage Account | visible=true | active=true
ADM_CONTRACTOR | ADMINISTRATOR | Add / Edit Contractor | visible=false | active=false
ADM_EMPLOYEE | ADMINISTRATOR | Add / Edit Employee | visible=false | active=false
ADM_ROLE_MASTER | ADMINISTRATOR | Role Master | visible=false | active=false
ADM_CUSTOMER_COUNTS | ADMINISTRATOR | Customer Counts | visible=false | active=false
ADMIN_SUBSCRIPTION | ADMINISTRATOR | Subscription & Billing Plan | visible=true | active=true
ADM_SMS_CONFIG | ADMINISTRATOR | SMS Configuration | visible=false | active=false
ADM_MASTER_DATA | ADMINISTRATOR | Master Data Entry | visible=false | active=false
ADM_COLLECTION_CONFIG | ADMINISTRATOR | Collection Configuration | visible=false | active=false
ADM_SEND_SMS | ADMINISTRATOR | Send SMS Manually | visible=false | active=false
ROLE_RIGHTS | ADMINISTRATOR | Role & Rights | visible=true | active=true
MODULE_SUBMODULE | ADMINISTRATOR | Module & Submodule | visible=true | active=true
DASH_BILLING | APP_DASHBOARD | Billing | visible=false | active=true
DASH_COLLECTION | APP_DASHBOARD | Collection | visible=false | active=true
DASH_CRM | APP_DASHBOARD | CRM | visible=false | active=true
DASH_RTS | APP_DASHBOARD | RTS | visible=false | active=false
SA_AUDIT | AUDIT | Audit Trail | visible=false | active=true
SUPER_AUDIT | AUDIT | Audit Log | visible=true | active=true
AUDIT_LOG | AUDIT_GOVERNANCE | Audit Trail | visible=true | active=true
AUDIT_LOGIN | AUDIT_GOVERNANCE | Login / Session Audit | visible=true | active=true
AUDIT_APPROVAL | AUDIT_GOVERNANCE | Approval History | visible=true | active=true
BACKOFFICE_TICKET | BACK_OFFICE | Raise Ticket | visible=true | active=true
BO_TICKET | BACK_OFFICE | Raise Ticket [IT Help Desk] | visible=false | active=true
BO_HELPDESK | BACK_OFFICE | IT Help Desk Dashboard | visible=false | active=true
BACKOFFICE_DOCUMENT | BACK_OFFICE | Document Management System | visible=true | active=true
BO_DOCUMENTS | BACK_OFFICE | Document Management System | visible=false | active=true
BACKOFFICE_SERVICE | BACK_OFFICE | Update Service Attribute | visible=true | active=true
BO_SERVICE_ATTRIBUTES | BACK_OFFICE | Update Service Attributes | visible=false | active=true
BACKOFFICE_MIGRATION | BACK_OFFICE | Master Data Migration | visible=false | active=true
BO_MASTER_MIGRATION | BACK_OFFICE | Master Data Migration | visible=false | active=true
BO_CONSUMER_MIGRATION | BACK_OFFICE | New Consumer Migration | visible=false | active=true
CUST_BILLS | BILLING | My Bills | visible=true | active=true
SA_BILLING_DASH | BILLING | Billing Dashboard | visible=false | active=false
BILLING_CONFIGURATION | BILLING | Billing Configuration | visible=true | active=true
SA_BILL_GENERATION | BILLING | Bill Generation | visible=false | active=false
BILLING_PROCESS | BILLING | Billing Process | visible=true | active=true
CASH_BILL_LOOKUP | BILLING | Bill Lookup | visible=false | active=true
SA_BILL_REGISTER | BILLING | Bill Register | visible=false | active=false
CASH_ADJUSTMENT | BILLING | Adjustment | visible=false | active=true
CUST_ADJUSTMENTS | BILLING | My Adjustments | visible=true | active=true
SA_BILL_ADJUSTMENT | BILLING | Billing Adjustment | visible=false | active=false
BILL_RANGE | BILLING_MANAGEMENT | Billing Range Interface | visible=false | active=false
BILL_DUMMY_CYCLE | BILLING_MANAGEMENT | Dummy Cycle Bill Schedule | visible=false | active=false
BILL_ERROR_CORRECTION | BILLING_MANAGEMENT | Error Warning Correction | visible=false | active=false
BILL_COMPUTATION | BILLING_MANAGEMENT | Bill Computation | visible=false | active=false
BILL_DOWNLOAD | BILLING_MANAGEMENT | Download Bill | visible=false | active=false
BILL_REVERT | BILLING_MANAGEMENT | Revert Billing | visible=false | active=false
BILL_TRACKER | BILLING_MANAGEMENT | Billing Tracker Report | visible=false | active=false
BILL_ADJUSTMENT | BILLING_MANAGEMENT | Billing Adjustment | visible=false | active=false
BILL_TARIFF | BILLING_MANAGEMENT | Tariff Rate Details | visible=false | active=false
BILL_DUMMY | BILLING_MANAGEMENT | Dummy Billing | visible=false | active=false
BILL_ESTIMATE | BILLING_MANAGEMENT | Estimated Average Unit Interface | visible=false | active=false
CASH_CUSTOMER | COLLECTION | Customer Search | visible=false | active=true
CUST_PAYMENTS | COLLECTION | My Payments | visible=true | active=true
SA_COLLECTION | COLLECTION | Collection | visible=false | active=true
CASH_ACCEPT_PAYMENT | COLLECTION | Accept Payment | visible=false | active=true
CUST_RECEIPTS | COLLECTION | My Receipts | visible=true | active=true
SA_PAYMENT_ENTRY | COLLECTION | Payment Entry | visible=false | active=true
CASH_RECEIPTS | COLLECTION | Receipt Reprint | visible=false | active=true
SA_RECEIPTS | COLLECTION | Receipts | visible=false | active=true
CASH_ALLOCATION | COLLECTION | Payment Allocation | visible=false | active=true
SA_REVERSAL | COLLECTION | Collection Reversal | visible=false | active=true
CASH_REVERSAL | COLLECTION | Payment Reversal | visible=false | active=true
COL_ACCEPT | COLLECTION_MANAGEMENT | Accept Payment | visible=false | active=true
COL_ACCEPT_PAYMENT | COLLECTION_MANAGEMENT | Accept Payment | visible=true | active=true
COL_SERVICE | COLLECTION_MANAGEMENT | Accept Services Payment | visible=false | active=true
COL_SERVICE_PAYMENT | COLLECTION_MANAGEMENT | Accept Services Payment | visible=true | active=true
COL_BANK | COLLECTION_MANAGEMENT | Add / Edit Bank Details | visible=false | active=true
COL_BANK_DETAILS | COLLECTION_MANAGEMENT | Add / Edit Bank Details | visible=true | active=true
COL_CENTER | COLLECTION_MANAGEMENT | Add / Edit Collection Center | visible=false | active=true
COL_CANCEL_SUMMARY | COLLECTION_MANAGEMENT | Cancel Receipt Summary | visible=false | active=true
COL_DAILY | COLLECTION_MANAGEMENT | Daily Collection Report | visible=false | active=true
COL_CHEQUE | COLLECTION_MANAGEMENT | Dishonored Cheque | visible=false | active=true
COL_DISHONORED | COLLECTION_MANAGEMENT | Dishonored Cheque | visible=true | active=true
COL_COUNTER | COLLECTION_MANAGEMENT | Payment Collection Counter Report | visible=false | active=true
COL_RECON | COLLECTION_MANAGEMENT | Payment Reconciliation | visible=false | active=true
COL_RECEIPT_CANCEL | COLLECTION_MANAGEMENT | Receipt Cancellation | visible=false | active=true
COL_CANCEL_AUTH | COLLECTION_MANAGEMENT | Receipt Cancelled Authentication | visible=false | active=true
CUST_COMPLAINTS | COMPLAINTS | My Complaints | visible=true | active=true
SA_COMPLAINTS | COMPLAINTS | Complaints | visible=false | active=true
SUPER_SETTINGS | CONFIGURATION | System Settings | visible=true | active=true
SA_CHARGE_CONFIG | CONFIGURATION | Charge & Rate Configuration | visible=false | active=false
SA_RATE_PLANS | CONFIGURATION | Rate Plans & Effective Dates | visible=false | active=false
SA_TAX_CONFIG | CONFIGURATION | Tax / GST Configuration | visible=false | active=false
CONN_APPLICATION | CONNECTION_MANAGEMENT | Connection Application | visible=false | active=false
CONN_SERVICE | CONNECTION_MANAGEMENT | Service / Connection Details | visible=false | active=false
CONN_TRANSFER | CONNECTION_MANAGEMENT | Connection Transfer | visible=false | active=false
CONN_DISCON_RECON | CONNECTION_MANAGEMENT | Disconnection / Reconnection | visible=false | active=false
CONN_HISTORY | CONNECTION_MANAGEMENT | Connection History | visible=false | active=false
CRM_CUSTOMER_SEARCH | CRM | Customer Search | visible=false | active=false
CRM_CUSTOMER_360 | CRM | Customer 360 | visible=false | active=false
CRM_CUSTOMER_ACCOUNT | CRM | Customer Account | visible=true | active=true
CRM_CUSTOMER_INTERACTION | CRM | Customer Interaction | visible=true | active=true
CRM_INTERACTION | CRM | Customer Interactions | visible=false | active=false
CRM_COMPLAINT | CRM | Complaints / Grievances | visible=false | active=false
CRM_SERVICE_REQUEST | CRM | Service Requests | visible=false | active=false
CASH_DASHBOARD | DASHBOARD | Dashboard | visible=false | active=true
CUST_DASHBOARD | DASHBOARD | My Dashboard | visible=true | active=true
SA_DASHBOARD | DASHBOARD | Dashboard | visible=false | active=true
DEV_REGISTER | DEVICE_AUTH | Device Registration | visible=false | active=false
DEV_ASSIGN | DEVICE_AUTH | Device Assignment | visible=false | active=false
DEV_AUTH | DEVICE_AUTH | Device Authentication | visible=false | active=false
DEV_STATUS | DEVICE_AUTH | Device Status | visible=false | active=false
DOC_CUSTOMER | DOCUMENT_MANAGEMENT | Customer Documents | visible=true | active=true
DOC_SOCIETY | DOCUMENT_MANAGEMENT | Society Documents | visible=true | active=true
DOC_TEMPLATE | DOCUMENT_MANAGEMENT | Templates | visible=true | active=true
CUST_DOCUMENTS | DOCUMENTS | My Documents | visible=true | active=true
SA_DOCUMENTS | DOCUMENTS | Documents | visible=false | active=true
SA_BUILDINGS | FLATS | Buildings | visible=false | active=true
SA_WINGS | FLATS | Wings | visible=false | active=true
SA_FLATS | FLATS | Flats | visible=false | active=true
MTR_MASTER | METER_MANAGEMENT | Meter Master | visible=false | active=false
MTR_ASSIGN | METER_MANAGEMENT | Meter Assignment | visible=false | active=false
MTR_REPLACEMENT | METER_MANAGEMENT | Meter Replacement | visible=false | active=false
MTR_TEST | METER_MANAGEMENT | Meter Testing | visible=false | active=false
MTR_HISTORY | METER_MANAGEMENT | Meter History | visible=false | active=false
SA_MIGRATION | MIGRATION | Back Office Migration | visible=false | active=true
MIG_PREVIEW | MIGRATION_CONTROL | Migration Preview | visible=false | active=true
MIG_VALIDATE | MIGRATION_CONTROL | Migration Validation | visible=false | active=true
MIG_IMPORT | MIGRATION_CONTROL | Import / Commit | visible=false | active=true
MIG_ERRORS | MIGRATION_CONTROL | Error Download | visible=false | active=true
MIG_BATCH | MIGRATION_CONTROL | Batch History / Rollback | visible=false | active=true
MIS_BILLING | MIS | Billing MIS | visible=false | active=true
MIS_CONSUMER_MASTER | MIS | Consumer Master Data | visible=true | active=true
MIS_BILLING_DATA | MIS | Billing Data | visible=true | active=true
MIS_COLLECTION | MIS | Collection MIS | visible=false | active=true
MIS_COLLECTION_DETAILS | MIS | Collection Details | visible=true | active=true
MIS_CONSUMER | MIS | Consumer MIS | visible=false | active=true
MIS_COMPLAINT_HISTORY | MIS | Complaint History | visible=true | active=true
MIS_METER | MIS | Meter MIS | visible=false | active=false
MIS_EXCEPTION | MIS | Exception MIS | visible=false | active=true
NOTICE_CREATE | NOTICE_COMMUNICATION | Notice Management | visible=true | active=true
NOTICE_SMS | NOTICE_COMMUNICATION | SMS / Email | visible=true | active=true
NOTICE_PUSH | NOTICE_COMMUNICATION | Notifications | visible=true | active=true
CUST_NOTICES | NOTICES | Society Notices | visible=true | active=true
SA_NOTICES | NOTICES | Notices | visible=false | active=true
CUST_NOTIFICATIONS | NOTICES | Notifications | visible=true | active=true
SA_COMMUNICATION | NOTICES | SMS / Email / Notifications | visible=false | active=true
CUST_PARKING | PARKING | My Parking | visible=true | active=true
SA_PARKING | PARKING | Parking Slots | visible=false | active=true
CUST_VEHICLES | PARKING | My Vehicles | visible=true | active=true
SA_VEHICLES | PARKING | Vehicles | visible=false | active=true
SA_PARKING_ASSIGN | PARKING | Parking Assignment | visible=false | active=true
PARK_SLOT | PARKING_MANAGEMENT | Parking Slots | visible=true | active=true
PARK_ASSIGN | PARKING_MANAGEMENT | Parking Assignment | visible=true | active=true
PARK_VEHICLE | PARKING_MANAGEMENT | Vehicles | visible=true | active=true
PARK_CHARGE | PARKING_MANAGEMENT | Parking Charges | visible=true | active=true
RECOVERY_DUE | RECOVERY_MANAGEMENT | Recovery Due List | visible=false | active=false
RECOVERY_DISCON | RECOVERY_MANAGEMENT | Disconnection | visible=false | active=false
RECOVERY_RECON | RECOVERY_MANAGEMENT | Reconnection | visible=false | active=false
RECOVERY_TRACKER | RECOVERY_MANAGEMENT | Recovery Tracker | visible=false | active=false
RPT_BILLING | REPORTING_ANALYTICS | Billing Reports | visible=true | active=true
RPT_COLLECTION | REPORTING_ANALYTICS | Collection Reports | visible=true | active=true
RPT_OUTSTANDING | REPORTING_ANALYTICS | Outstanding / Aging | visible=true | active=true
RPT_CONSUMER | REPORTING_ANALYTICS | Consumer Reports | visible=true | active=true
RPT_AUDIT | REPORTING_ANALYTICS | Audit Reports | visible=true | active=true
SA_REPORTS | REPORTS | Reports | visible=false | active=true
CUST_PROFILE | RESIDENTS | My Profile | visible=true | active=true
SA_RESIDENTS | RESIDENTS | Residents / Owners | visible=false | active=true
CUST_FLAT | RESIDENTS | My Flat / Unit | visible=true | active=true
SA_FAMILY | RESIDENTS | Family / Occupants | visible=false | active=true
CUST_FAMILY | RESIDENTS | Family Members | visible=true | active=true
SUPER_ROLES | ROLES | Roles & Rights | visible=true | active=true
SUPER_MODULES | ROLES | Modules & Submodules | visible=true | active=true
SUPER_SECURITY | ROLES | Security & Sessions | visible=true | active=true
SEC_DASHBOARD | SECURITY_VISITOR | Security Dashboard | visible=true | active=true
SEC_GUARDS | SECURITY_VISITOR | Guard Management | visible=true | active=true
SEC_ROSTER | SECURITY_VISITOR | Shift / Roster Management | visible=true | active=true
SEC_GATES | SECURITY_VISITOR | Gate Management | visible=true | active=true
SEC_INCIDENTS | SECURITY_VISITOR | Security Incident Management | visible=true | active=true
SEC_REPORTS | SECURITY_VISITOR | Security Reports | visible=true | active=true
VIS_DASHBOARD | SECURITY_VISITOR | Visitor Dashboard | visible=true | active=true
VIS_PREAPPROVAL | SECURITY_VISITOR | Pre-Approved Visitor | visible=true | active=true
VIS_WALKIN | SECURITY_VISITOR | Walk-in Visitor | visible=true | active=true
VIS_ENTRY_EXIT | SECURITY_VISITOR | Visitor Entry / Exit | visible=true | active=true
VIS_SERVICE | SECURITY_VISITOR | Delivery / Service Provider | visible=true | active=true
VIS_VEHICLE | SECURITY_VISITOR | Vehicle Management | visible=true | active=true
VIS_HISTORY | SECURITY_VISITOR | Visitor History | visible=true | active=true
VIS_BLACKLIST | SECURITY_VISITOR | Blacklist / Restricted Visitor | visible=true | active=true
SEC_GATE | SECURITY_VISITOR | Gate Dashboard | visible=true | active=true
SEC_VISITOR | SECURITY_VISITOR | Visitor Entry / Exit | visible=true | active=true
SEC_APPROVAL | SECURITY_VISITOR | Resident Visitor Approval | visible=true | active=true
SEC_VEHICLE | SECURITY_VISITOR | Vehicle Entry / Exit | visible=true | active=true
SA_SOCIETY_PROFILE | SOCIETY | Society Profile | visible=false | active=true
SUPER_SOCIETIES | SOCIETY | Societies | visible=true | active=true
SUPER_SUBSCRIPTIONS | SOCIETY | Subscriptions & Plans | visible=true | active=true
SUPER_PLATFORM_BILLING | SOCIETY | Platform Billing | visible=true | active=true
SA_RATE | SOCIETY_ADMIN_EXTRA | Rate / Tariff Configuration | visible=true | active=true
SA_DPC | SOCIETY_ADMIN_EXTRA | DPC / Interest Configuration | visible=false | active=false
SA_REBATE | SOCIETY_ADMIN_EXTRA | Rebate Configuration | visible=false | active=false
SA_WAIVER | SOCIETY_ADMIN_EXTRA | Waiver / Adjustment Rules | visible=true | active=true
SA_TAX | SOCIETY_ADMIN_EXTRA | Tax / GST Configuration | visible=true | active=true
SA_EFFECTIVE | SOCIETY_ADMIN_EXTRA | Effective Date / Versioning | visible=true | active=true
SOC_NEW_BUILDING | SOCIETY_MANAGEMENT | New Building | visible=false | active=true
SOC_NEW_WING | SOCIETY_MANAGEMENT | New Wing | visible=false | active=true
SOC_NEW_FLAT | SOCIETY_MANAGEMENT | New Flat | visible=true | active=true
SOC_NEW_PARKING | SOCIETY_MANAGEMENT | New Parking | visible=true | active=true
SOC_CUSTOMER | SOCIETY_MANAGEMENT | Customer | visible=true | active=true
SOC_CUSTOMER_MASTER | SOCIETY_MANAGEMENT | Customer / Area Management | visible=false | active=true
SOC_AREA_UPDATE | SOCIETY_MANAGEMENT | Area Update | visible=true | active=true
SUB_PLANS | SUBSCRIPTION_PLATFORM | Subscription Plans | visible=false | active=true
SUB_ACTIVE | SUBSCRIPTION_PLATFORM | Society Subscriptions | visible=false | active=true
SUB_PAYMENT | SUBSCRIPTION_PLATFORM | Subscription Payments | visible=false | active=true
SUB_RENEWAL | SUBSCRIPTION_PLATFORM | Renewal / Expiry | visible=false | active=true
SUPER_USERS | USERS | Users | visible=true | active=true
SA_VISITORS | VISITORS | Visitor Entry | visible=false | active=true
SA_SECURITY | VISITORS | Security / Gate | visible=false | active=true
WATER_CONSUMPTION | WATER_DISTRIBUTION | Water Consumption | visible=false | active=false
WATER_TANK | WATER_DISTRIBUTION | Tank / Supply Management | visible=false | active=false
WATER_SCHEDULE | WATER_DISTRIBUTION | Supply Schedule | visible=false | active=false
WATER_ZONE | WATER_DISTRIBUTION | Zone Management | visible=false | active=false
```

## Application pages and role surfaces

| Surface | Entry point | Existing functions / module families |
|---|---|---|
| Login | `wwwroot/login.html` | authentication, language selector, validation and session handling |
| Platform/Super Admin | `wwwroot/index.html` | societies, subscriptions/plans, platform billing, user/role/module/security configuration |
| Society Admin | `wwwroot/modules/society-admin/index.html` | dashboard, customer account, flats/residents, billing, collection, complaints, visitors, parking, security/audit, configuration, accounts/roles/menu and module workspace |
| Cashier | `wwwroot/modules/cashier/index.html` | customer search, bill lookup, payment, receipt, allocation, reversals and reports |
| Resident/Customer | `wwwroot/modules/customer/index.html` | own profile, flats, bills, payments, receipts, complaints, documents, notices, parking and family modules |
| Migration | `wwwroot/modules/migration/index.html` | import preview, validation, commit/import, errors, batch history/rollback |
| Super Admin Security | `wwwroot/super-admin-security.html` | protected security/session administration |

## Society Admin source-defined views

Existing source inventory identifies 14 view sections: home, customers, flats, bills, collection, complaints, visitors, parking, security, configuration, billing-configuration, billing-process, module-workspace, accounts. Other menu codes are routed by admin.js/requested-workflows.js/security-visitor.js and must be mapped to the live DB catalog.

## Module families requiring page-by-page coverage

- Dashboard and analytics
- Administrator accounts, roles, permissions, menu/submenu and subscription/billing plan
- Society profile, buildings, wings, flats, residents, owners, tenants, family and area
- Billing configuration/process, bill register, rate/tariff, DPC, rebates, waivers, tax, adjustments and reports
- Collection, payment entry, service payments, bank details, receipts, reversal, reconciliation and dishonoured cheques
- Customer Account / Consumer 360 and customer interactions
- Complaints, service requests and complaint history
- Visitor pre-approval, walk-in, entry/exit, delivery/service providers, visitor history and blacklist
- Security dashboard, guards, rosters/shifts, gates, incidents and security reports
- Parking slots, assignments, vehicles and charges
- Documents, templates, notices, SMS/email and notifications
- MIS consumer master, billing data, collection details and complaint history
- Migration preview, validation, import, errors, batches and rollback
- Audit trail, login/session audit, approval history and reports
- Platform subscriptions, plan management, society billing and platform billing
- Catalogue-only/inactive groups: meter management, water distribution, device authorization, recovery/disconnection/reconnection and connection management. Preserve their existing availability/permissions; do not fabricate implementations.

## Tabulator constructor inventory (source scan)

1. `wwwroot/js/index.js` — platform data grid.
2. `wwwroot/modules/cashier/index.html` — customer, bill and collection grids.
3. `wwwroot/modules/customer/index.html` — resident bills and complaints grids.
4. `wwwroot/modules/society-admin/admin.js` — shared Society Admin table helper.
5. `wwwroot/modules/society-admin/billing.js` — billing grid helper.
6. `wwwroot/modules/society-admin/customer-account.js` — server-paginated Consumer 360 section grids.
7. `wwwroot/modules/society-admin/requested-workflows.js` — requested operational workflow grids.
8. `wwwroot/modules/society-admin/security-visitor.js` — security/visitor grids.

Do not replace server-side paging in Customer Account with local paging. Header visibility must be fixed while preserving each data source and export behavior.


## Authenticated role menu snapshot

Read-only execution of `society_manager.fn_user_module_menu(user_id)` against active users (deduplicated by module code):

| Active role code | Distinct menu codes | Root menu items |
|---|---:|---:|
| RESIDENT | 4 | 1 |
| SOCIETY_ADMIN | 105 | 17 |
| SUPER_ADMIN | 105 | 17 |

The database has 11 role definitions, but only these three role codes had active user records in the queried `m_user` rows. CASHIER, COLLECTOR, GUARD, SECURITY, ACCOUNTANT, BILLING_ADMIN, EMPLOYEE and MAINTENANCE need a safe authorized test user before visible per-role UI acceptance. Do not create users or alter role assignments just for this audit.
