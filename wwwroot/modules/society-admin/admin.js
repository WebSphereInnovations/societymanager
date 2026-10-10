const $=s=>document.querySelector(s);const $$=s=>document.querySelectorAll(s);
let session=null;
const money=v=>'₹'+Number(v||0).toLocaleString('en-IN',{maximumFractionDigits:2});
async function get(url){const r=await fetch(url,{cache:'no-store'});if(r.status===401){location.href='/login';throw 0}if(!r.ok)throw new Error('Request failed');return r.json()}
const tableRegistry=new Map();
function table(id,data,columns,opts={}){const el=$('#'+id);if(el._tab){el._tab.destroy()}const localized=columns.map(c=>({...c,title:Society360I18n.translateText(c.title)}));el._tab=new Tabulator(el,{data,layout:'fitColumns',height:'470px',pagination:true,paginationSize:15,headerFilterPlaceholder:Society360I18n.translateText('Filter...'),columns:localized,...opts});tableRegistry.set(id,{table:el._tab,columns});return el._tab}
function debounce(fn,ms=280){let t;return (...a)=>{clearTimeout(t);t=setTimeout(()=>fn(...a),ms)}}
const moduleViewMap={APP_DASHBOARD:'home',SA_DASHBOARD:'home',SA_SOCIETY_PROFILE:'configuration',SA_BUILDINGS:'flats',SA_WINGS:'flats',SA_FLATS:'flats',SA_RESIDENTS:'customers',SA_FAMILY:'customers',CRM_CUSTOMER_ACCOUNT:'customers',CRM_CUSTOMER_INTERACTION:'customers',MIS_CONSUMER_MASTER:'customers',SA_BILLING_DASH:'bills',SA_BILL_GENERATION:'bills',SA_BILL_REGISTER:'bills',SA_BILL_ADJUSTMENT:'bills',SA_REBATE:'configuration',SA_DPC:'configuration',SA_CHARGE_CONFIG:'configuration',SA_RATE_PLANS:'configuration',SA_TAX_CONFIG:'configuration',SA_COLLECTION:'collection',SA_PAYMENT_ENTRY:'collection',SA_RECEIPTS:'collection',SA_REVERSAL:'collection',SA_PARKING:'parking',SA_VEHICLES:'parking',SA_PARKING_ASSIGN:'parking',SA_COMPLAINTS:'complaints',SA_VISITORS:'visitors',SA_SECURITY:'security',SA_REPORTS:'security',SA_MIGRATION:'module-workspace',SA_AUDIT:'security',ADM_ACCOUNTS:'accounts',ADMINISTRATOR:'accounts',CASH_DASHBOARD:'home',CASH_CUSTOMER:'customers',CASH_ACCEPT_PAYMENT:'collection',CASH_RECEIPTS:'collection',CASH_ALLOCATION:'collection',CASH_REVERSAL:'collection',CASH_ADJUSTMENT:'bills',CASH_BILL_LOOKUP:'bills',NOTIFICATION_CENTER:'module-workspace'};
['BILL_RANGE','BILL_DUMMY_CYCLE','BILL_ERROR_CORRECTION','BILL_COMPUTATION','BILL_DOWNLOAD','BILL_REVERT','BILL_TRACKER','BILL_ADJUSTMENT','BILL_TARIFF','BILL_DUMMY','BILL_ESTIMATE'].forEach(x=>moduleViewMap[x]='bills');
moduleViewMap.BILLING='billing-configuration';moduleViewMap.BILLING_CONFIGURATION='billing-configuration';moduleViewMap.BILLING_PROCESS='billing-process';
['COL_ACCEPT_PAYMENT','COL_SERVICE_PAYMENT','COL_BANK_DETAILS','COL_DISHONORED'].forEach(x=>moduleViewMap[x]='collection');
['SA_RATE','SA_WAIVER','SA_TAX','SA_EFFECTIVE'].forEach(x=>moduleViewMap[x]='configuration');
['PARK_SLOT','PARK_ASSIGN','PARK_VEHICLE','PARK_CHARGE'].forEach(x=>moduleViewMap[x]='parking');
['DOC_CUSTOMER','DOC_SOCIETY','DOC_TEMPLATE','NOTICE_CREATE','NOTICE_SMS','NOTICE_PUSH','RPT_BILLING','RPT_COLLECTION','RPT_OUTSTANDING','RPT_CONSUMER','RPT_AUDIT','AUDIT_LOG','AUDIT_LOGIN','AUDIT_APPROVAL','SUPER_AUDIT'].forEach(x=>moduleViewMap[x]='module-workspace');
const menuIconMap={APP_DASHBOARD:'⌂',ADMINISTRATOR:'⚙',BILLING:'▣',COLLECTION:'₹',CRM:'◉',SECURITY:'♙',PARKING:'▤',REPORTS:'▥',DOCUMENTS:'▤',NOTICES:'◈',CONFIGURATION:'⚙',MIGRATION:'↥',AUDIT:'◷'};
function menuIcon(code){const c=String(code||'');if(c==='APP_DASHBOARD')return menuIconMap.APP_DASHBOARD;if(c.startsWith('BILL_')||c.startsWith('SA_BILL'))return menuIconMap.BILLING;if(c.startsWith('COL_')||c.includes('COLLECTION'))return menuIconMap.COLLECTION;if(c.startsWith('CRM_')||c.includes('CUSTOMER'))return menuIconMap.CRM;if(c.startsWith('SEC_')||c.includes('VISITOR'))return menuIconMap.SECURITY;if(c.startsWith('PARK_')||c.includes('PARK'))return menuIconMap.PARKING;if(c.startsWith('RPT_')||c.includes('REPORT'))return menuIconMap.REPORTS;if(c.startsWith('DOC_')||c.includes('DOCUMENT'))return menuIconMap.DOCUMENTS;if(c.startsWith('NOTICE_')||c.includes('NOTICE'))return menuIconMap.NOTICES;if(c.includes('RATE')||c.includes('TAX')||c.includes('DPC')||c.includes('REBATE')||c.includes('CONFIG'))return menuIconMap.CONFIGURATION;if(c.includes('MIGRATION'))return menuIconMap.MIGRATION;if(c.includes('AUDIT'))return menuIconMap.AUDIT;if(c.startsWith('ADM_')||c==='ADMINISTRATOR')return menuIconMap.ADMINISTRATOR;return '•';}
async function buildSystemMenu(){
 const rows=await get('/api/menu');const nav=$('#dbMenu');if(!nav)return;nav.innerHTML='';
 const roots=rows.filter(x=>!x.parent_module_code);
 roots.forEach(root=>{
  const children=rows.filter(x=>x.parent_module_code===root.module_code);
  if(children.length){
   const d=document.createElement('details');d.open=false;const s=document.createElement('summary');s.textContent=Society360I18n.translateText(root.module_name);d.appendChild(s);
   children.forEach(c=>{const b=document.createElement('button');b.type='button';b.dataset.view=moduleViewMap[c.module_code]||'module-workspace';b.dataset.moduleCode=c.module_code;b.innerHTML='<span class="menu-icon" aria-hidden="true">'+menuIcon(c.module_code)+'</span><span>'+Society360I18n.translateText(c.module_name)+'</span>';b.onclick=()=>{if(window.openRequestedModule?.(c.module_code))return;show(b.dataset.view,c.module_name)};d.appendChild(b)});nav.appendChild(d);
  }else{
   const b=document.createElement('button');b.type='button';b.dataset.view=moduleViewMap[root.module_code]||'module-workspace';b.dataset.moduleCode=root.module_code;b.innerHTML='<span class="menu-icon" aria-hidden="true">'+menuIcon(root.module_code)+'</span><span>'+Society360I18n.translateText(root.module_name)+'</span>';b.onclick=()=>{if(window.openRequestedModule?.(root.module_code))return;show(b.dataset.view,root.module_name)};nav.appendChild(b);
  }
 });
 nav.querySelectorAll('details').forEach(d=>{
  d.open=false;
  d.addEventListener('toggle',()=>{
   if(!d.open)return;
   nav.querySelectorAll('details').forEach(other=>{if(other!==d)other.open=false;});
  });
 });
}

function refreshShellLanguage(){if(!session)return;$('#heading').textContent=Society360I18n.translateText('Hello')+', '+session.displayName;const subtitle=document.querySelector('header p');if(subtitle)subtitle.textContent=Society360I18n.translateText('Manage your society operations from one connected workspace.');$('#mobileMenuToggle')?.setAttribute('aria-label',Society360I18n.translateText('Toggle navigation'))}
async function init(){
 try{
  const me=await get('/api/auth/me');session=me.session;
  if(session.roleCode!=='SOCIETY_ADMIN'&&session.roleCode!=='SUPER_ADMIN'){location.href='/';return}
  const society=me.societies.find(x=>x.societyId===session.societyId)||me.societies[0];
  $('#societyName').textContent=society?.societyName||'Society';
  $('#userName').textContent=session.displayName;$('#avatar').textContent=session.displayName.split(' ').map(x=>x[0]).slice(0,2).join('');refreshShellLanguage();
  wire();
  window.customerAccount360?.init();
  window.billingModule?.init();
  await Promise.allSettled([loadDashboard(),loadSubscription(),buildSystemMenu()]);
 }catch(e){
  if(e?.message==='AUTH_REQUIRED') location.href='/login';
 }
}
async function loadSubscription(){
 try{
  const x=await get('/api/subscription/current');
  $('#subscriptionText').textContent=x.planName+' · ₹'+Number(x.amount).toLocaleString('en-IN')+' · '+x.paymentStatus+' · '+x.daysRemaining+' days remaining';
  $('#recordSubscriptionPayment').disabled=x.paymentStatus==='Paid';
  $('#recordSubscriptionPayment').dataset.subscriptionId=x.subscriptionId;
 }catch(e){$('#subscriptionText').textContent='No active subscription found.';$('#recordSubscriptionPayment').disabled=true}
}
async function loadDashboard(){if(window.societyDashboard?.load){await window.societyDashboard.load();return}const x=await get('/api/society-admin/dashboard');$('#totalFlats').textContent=x.totalFlats;$('#occupiedFlats').textContent=x.occupiedFlats;$('#collected').textContent=money(x.collected);$('#outstanding').textContent=money(x.outstanding);$('#openComplaints').textContent=x.openComplaints;$('#insideVisitors').textContent=x.insideVisitors}
function show(view,label){
 const target=document.getElementById(view)?view:'module-workspace';
 $$('.view').forEach(x=>x.classList.toggle('active',x.id===target));
 $$('.side nav button').forEach(x=>x.classList.toggle('active',x.dataset.view===view));
 if(target==='module-workspace'){
   $('#moduleTitle').textContent=label||view;
   $('#moduleCode').textContent=(label||view).toUpperCase();
   $('#moduleInfo').textContent='This menu item is part of the Society360 module catalog and is society-scoped. Use the linked operational workspace below for the supported workflow.';
 }
 if(view==='customers')loadCustomers('');if(view==='flats')loadFlats('');if(view==='bills')loadBills('');if(view==='billing-configuration')window.billingModule?.loadConfiguration?.();if(view==='billing-process')window.billingModule?.refreshProcess?.();if(view==='collection')loadCollection();if(view==='complaints')loadComplaints('');if(view==='visitors')loadVisitors('');if(view==='parking')loadParking('');if(view==='configuration')loadConfig();if(view==='security')loadSecurity()}
window.societyAdminShow=show;
function closeMobileMenu(){const side=$('.side'),backdrop=$('#mobileMenuBackdrop'),toggle=$('#mobileMenuToggle');side?.classList.remove('mobile-open');backdrop?.classList.remove('visible');toggle?.setAttribute('aria-expanded','false');}
function wire(){
 const mobileToggle=$('#mobileMenuToggle'),mobileBackdrop=$('#mobileMenuBackdrop');
 mobileToggle?.addEventListener('click',()=>{const open=!$('.side')?.classList.contains('mobile-open');$('.side')?.classList.toggle('mobile-open',open);mobileBackdrop?.classList.toggle('visible',open);mobileToggle.setAttribute('aria-expanded',String(open));});
 mobileBackdrop?.addEventListener('click',closeMobileMenu);
 document.addEventListener('click',e=>{if(e.target.closest('#dbMenu button'))closeMobileMenu();});
 document.querySelectorAll('.side nav details').forEach(x=>{
  x.open=false;
  x.addEventListener('toggle',()=>{
   if(!x.open)return;
   document.querySelectorAll('.side nav details').forEach(y=>{if(y!==x)y.open=false});
  });
 });
 $$('[data-view]').forEach(x=>{if(x.closest('.side nav'))return;x.addEventListener('click',()=>show(x.dataset.view,x.querySelector('span')?.textContent||x.textContent.trim()))});
 $('#logout').onclick=async()=>{await fetch('/api/auth/logout',{method:'POST'});location.href='/login'};
 $('#recordSubscriptionPayment')?.addEventListener('click',async()=>{
  const b=$('#recordSubscriptionPayment');const subscriptionId=Number(b.dataset.subscriptionId||0);if(!subscriptionId)return;
  const x=await get('/api/subscription/current');if(!confirm('Record payment of ₹'+Number(x.amount).toLocaleString('en-IN')+' as '+$('#paymentMode').value+'?'))return;
  const r=await fetch('/api/subscription/payment',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({subscriptionId,amount:x.amount,paymentMode:$('#paymentMode').value,referenceNo:$('#paymentReference').value})});
  const d=await r.json();if(!r.ok){alert(d.message||'Payment failed');return}alert('Subscription payment recorded successfully.');loadSubscription(); });
 $('#flatSearch').oninput=debounce(e=>loadFlats(e.target.value));
 $('#billSearch').oninput=debounce(e=>loadBills(e.target.value));$('#complaintSearch').oninput=debounce(e=>loadComplaints(e.target.value));
 $('#visitorSearch').oninput=debounce(e=>loadVisitors(e.target.value));$('#parkingSearch').oninput=debounce(e=>loadParking(e.target.value));
 $('#language-select').value=Society360I18n.currentLanguage();$('#language-select').onchange=e=>Society360I18n.setLanguage(e.target.value);
 window.addEventListener('society360-language-changed',()=>{refreshShellLanguage();buildSystemMenu();tableRegistry.forEach(x=>{try{x.table.setColumns(x.columns.map(c=>({...c,title:Society360I18n.translateText(c.title)})))}catch{}});window.customerAccount360?.refreshLanguage?.();});
 setInterval(()=>$('#clock').textContent=new Date().toLocaleString(Society360I18n.locale()),1000);
}
async function loadCustomers(q){
  // Single source of truth: the dedicated Customer Relationship Management -> Customer Account Consumer 360 module.
  if(window.customerAccount360?.init) window.customerAccount360.init();
  if(q){const input=$('#caSearchInput');if(input){input.value=q;input.dispatchEvent(new Event('input',{bubbles:true}));}}
}async function loadSecurity(){const rows=await get('/api/society-admin/security/logins');table('loginSecurityTable',rows,[{title:'Login',field:'login_name',headerFilter:true},{title:'Name',field:'display_name',headerFilter:true},{title:'Role',field:'role_code',headerFilter:true},{title:'Last Login',field:'last_login_at',headerFilter:true},{title:'IP',field:'last_login_ip',headerFilter:true},{title:'Login Count',field:'login_count',hozAlign:'right'},{title:'Failed Count',field:'failed_login_count',hozAlign:'right'},{title:'Last Failed',field:'last_failed_at'}])}
async function loadFlats(q){const rows=await get('/api/society-admin/flats?q='+encodeURIComponent(q));table('flatTable',rows,[{title:'Flat',field:'flat_no',headerFilter:true},{title:'Wing',field:'wing',headerFilter:true},{title:'Building',field:'building',headerFilter:true},{title:'Type',field:'unit_type',headerFilter:true},{title:'Area',field:'area_sqft',hozAlign:'right'},{title:'Occupancy',field:'occupancy_status',headerFilter:true},{title:'Owner',field:'owner_name',headerFilter:true},{title:'Phone',field:'owner_phone'}])}
async function loadBills(q){const rows=await get('/api/society-admin/bills?q='+encodeURIComponent(q));table('billTable',rows,[{title:'Bill No',field:'bill_no',headerFilter:true},{title:'Month',field:'bill_month',headerFilter:true},{title:'Flat',field:'flat_no',headerFilter:true},{title:'Customer',field:'customer_name',headerFilter:true},{title:'Amount',field:'total_amount',hozAlign:'right',formatter:c=>money(c.getValue())},{title:'Paid',field:'paid_amount',hozAlign:'right',formatter:c=>money(c.getValue())},{title:'Balance',field:'balance',hozAlign:'right',formatter:c=>money(c.getValue())},{title:'Due',field:'due_date'},{title:'Status',field:'status',formatter:c=>'<span class="pill">'+c.getValue()+'</span>'}])}
async function loadCollection(){const rows=await get('/api/society-admin/collection');table('collectionTable',rows,[{title:'Payment No',field:'payment_no',headerFilter:true},{title:'Date',field:'payment_date',headerFilter:true},{title:'Flat',field:'flat_no',headerFilter:true},{title:'Customer',field:'customer_name',headerFilter:true},{title:'Amount',field:'amount',hozAlign:'right',formatter:c=>money(c.getValue())},{title:'Mode',field:'payment_mode',headerFilter:true},{title:'Reference',field:'reference_no'}])}
async function loadComplaints(q){const rows=await get('/api/society-admin/complaints?q='+encodeURIComponent(q));table('complaintTable',rows,[{title:'Complaint',field:'complaint_no',headerFilter:true},{title:'Flat',field:'flat_no',headerFilter:true},{title:'Customer',field:'customer_name',headerFilter:true},{title:'Category',field:'category',headerFilter:true},{title:'Title',field:'title',headerFilter:true},{title:'Priority',field:'priority',headerFilter:true},{title:'Status',field:'status',headerFilter:true},{title:'Created',field:'created_at'}])}
async function loadVisitors(q){const rows=await get('/api/society-admin/visitors?q='+encodeURIComponent(q));table('visitorTable',rows,[{title:'Visitor',field:'visitor_name',headerFilter:true},{title:'Phone',field:'phone',headerFilter:true},{title:'Flat',field:'flat_no',headerFilter:true},{title:'Type',field:'visitor_type',headerFilter:true},{title:'Purpose',field:'purpose'},{title:'Status',field:'status',headerFilter:true},{title:'Entry',field:'entry_time'},{title:'Exit',field:'exit_time'}])}
async function loadParking(q){const rows=await get('/api/society-admin/parking?q='+encodeURIComponent(q));table('parkingTable',rows,[{title:'Slot',field:'slot_no',headerFilter:true},{title:'Type',field:'slot_type',headerFilter:true},{title:'Charge',field:'charge',hozAlign:'right',formatter:c=>money(c.getValue())},{title:'Flat',field:'assigned_flat',headerFilter:true},{title:'Customer',field:'customer_name',headerFilter:true},{title:'Status',field:'status',formatter:c=>'<span class="pill">'+c.getValue()+'</span>'}])}
async function loadConfig(){const [charges,interest]=await Promise.all([get('/api/society-admin/config/charges'),get('/api/society-admin/config/interest')]);table('chargeConfigTable',charges,[{title:'Charge',field:'charge_code',headerFilter:true},{title:'Name',field:'charge_name',headerFilter:true},{title:'Method',field:'calculation_method',headerFilter:true},{title:'Rate',field:'rate'},{title:'Effective From',field:'effective_from'},{title:'Effective To',field:'effective_to'},{title:'Scope',field:'scope_type'}]);table('interestConfigTable',interest,[{title:'Rule',field:'rule_name',headerFilter:true},{title:'Type',field:'calculation_type',headerFilter:true},{title:'Rate',field:'rate'},{title:'Frequency',field:'frequency'},{title:'Grace Days',field:'grace_days'},{title:'Effective From',field:'effective_from'},{title:'Effective To',field:'effective_to'}])}
$('#saveCharge')?.addEventListener('click',async()=>{const r=await fetch('/api/society-admin/config/charge',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({chargeCode:$('#chargeCode').value,planName:'Future '+$('#chargeCode').value+' '+$('#chargeFrom').value,method:$('#calcMethod').value,rate:Number($('#chargeRate').value),effectiveFrom:$('#chargeFrom').value,effectiveTo:$('#chargeTo').value||null,scopeType:'Society',scopeValue:null})});alert(r.ok?'Future rate saved':'Rate save failed');if(r.ok)loadConfig()});
$('#saveInterest')?.addEventListener('click',async()=>{const r=await fetch('/api/society-admin/config/interest',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({ruleName:$('#interestName').value||'Future DPC',calculationType:'Percentage',rate:Number($('#interestRate').value),frequency:'Monthly',simpleOrCompound:$('#interestCompound').value,graceDays:Number($('#interestGrace').value||0),capAmount:null,effectiveFrom:$('#interestFrom').value,effectiveTo:null})});alert(r.ok?'DPC rule saved':'DPC save failed');if(r.ok)loadConfig()});
init();
