const $=s=>document.querySelector(s);const $$=s=>document.querySelectorAll(s);
let session=null;
const money=v=>'₹'+Number(v||0).toLocaleString('en-IN',{maximumFractionDigits:2});
async function get(url){const r=await fetch(url,{cache:'no-store'});if(r.status===401){location.href='/login';throw 0}if(!r.ok)throw new Error('Request failed');return r.json()}
const tableRegistry=new Map();
function table(id,data,columns,opts={}){const el=$('#'+id);if(el._tab){el._tab.destroy()}const localized=columns.map(c=>({...c,title:Society360I18n.translateText(c.title)}));el._tab=new Tabulator(el,{data,layout:'fitColumns',height:'470px',pagination:true,paginationSize:15,headerFilterPlaceholder:Society360I18n.translateText('Filter...'),columns:localized,...opts});tableRegistry.set(id,{table:el._tab,columns});return el._tab}
function debounce(fn,ms=280){let t;return (...a)=>{clearTimeout(t);t=setTimeout(()=>fn(...a),ms)}}
const moduleViewMap={APP_DASHBOARD:'home',SA_DASHBOARD:'home',SA_SOCIETY_PROFILE:'configuration',SA_BUILDINGS:'flats',SA_WINGS:'flats',SA_FLATS:'flats',SA_RESIDENTS:'customers',SA_FAMILY:'customers',SA_BILLING_DASH:'bills',SA_BILL_GENERATION:'bills',SA_BILL_REGISTER:'bills',SA_BILL_ADJUSTMENT:'bills',SA_REBATE:'configuration',SA_DPC:'configuration',SA_CHARGE_CONFIG:'configuration',SA_RATE_PLANS:'configuration',SA_TAX_CONFIG:'configuration',SA_COLLECTION:'collection',SA_PAYMENT_ENTRY:'collection',SA_RECEIPTS:'collection',SA_REVERSAL:'collection',SA_PARKING:'parking',SA_VEHICLES:'parking',SA_PARKING_ASSIGN:'parking',SA_COMPLAINTS:'complaints',SA_VISITORS:'visitors',SA_SECURITY:'security',SA_DOCUMENTS:'documents',SA_NOTICES:'notices',SA_COMMUNICATION:'communication',SA_REPORTS:'reports',SA_MIGRATION:'migration',SA_AUDIT:'audit',ADM_ACCOUNTS:'accounts',ADMINISTRATOR:'accounts',CASH_DASHBOARD:'home',CASH_CUSTOMER:'customers',CASH_ACCEPT_PAYMENT:'collection',CASH_RECEIPTS:'collection',CASH_ALLOCATION:'collection',CASH_REVERSAL:'collection',CASH_ADJUSTMENT:'bills',CASH_BILL_LOOKUP:'bills'};
async function buildDatabaseMenu(){
 const rows=await get('/api/menu');const nav=$('#dbMenu');if(!nav)return;nav.innerHTML='';
 const roots=rows.filter(x=>!x.parent_module_code);
 roots.forEach(root=>{
  const children=rows.filter(x=>x.parent_module_code===root.module_code);
  if(children.length){
   const d=document.createElement('details');d.open=false;const s=document.createElement('summary');s.textContent=Society360I18n.translateText(root.module_name);d.appendChild(s);
   children.forEach(c=>{const b=document.createElement('button');b.type='button';b.dataset.view=moduleViewMap[c.module_code]||'module-workspace';b.dataset.moduleCode=c.module_code;b.innerHTML='<span>'+Society360I18n.translateText(c.module_name)+'</span>';b.onclick=()=>{if(window.openRequestedModule?.(c.module_code))return;show(b.dataset.view,c.module_name)};d.appendChild(b)});nav.appendChild(d);
  }else{
   const b=document.createElement('button');b.type='button';b.dataset.view=moduleViewMap[root.module_code]||'module-workspace';b.dataset.moduleCode=root.module_code;b.innerHTML='<span>'+Society360I18n.translateText(root.module_name)+'</span>';b.onclick=()=>{if(window.openRequestedModule?.(root.module_code))return;show(b.dataset.view,root.module_name)};nav.appendChild(b);
  }
 });
}

async function init(){
 try{
  const me=await get('/api/auth/me');session=me.session;
  if(session.roleCode!=='SOCIETY_ADMIN'&&session.roleCode!=='SUPER_ADMIN'){location.href='/';return}
  const society=me.societies.find(x=>x.societyId===session.societyId)||me.societies[0];
  $('#societyName').textContent=society?.societyName||'Society';
  $('#userName').textContent=session.displayName;$('#avatar').textContent=session.displayName.split(' ').map(x=>x[0]).slice(0,2).join('');$('#heading').textContent='Hello, '+session.displayName;
  wire();
  wireConsumerAccount();
  await Promise.allSettled([loadDashboard(),loadSubscription(),buildDatabaseMenu()]);
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
async function loadDashboard(){const x=await get('/api/society-admin/dashboard');$('#totalFlats').textContent=x.totalFlats;$('#occupiedFlats').textContent=x.occupiedFlats;$('#collected').textContent=money(x.collected);$('#outstanding').textContent=money(x.outstanding);$('#openComplaints').textContent=x.openComplaints;$('#insideVisitors').textContent=x.insideVisitors}
function show(view,label){
 const target=document.getElementById(view)?view:'module-workspace';
 $$('.view').forEach(x=>x.classList.toggle('active',x.id===target));
 $('.side nav button').forEach(x=>x.classList.toggle('active',x.dataset.view===view));
 if(target==='module-workspace'){
   $('#moduleTitle').textContent=label||view;
   $('#moduleCode').textContent=(label||view).toUpperCase();
   $('#moduleInfo').textContent='This menu item is part of the Society360 module catalog and is society-scoped. Use the linked operational workspace below for the supported workflow.';
 }
 if(view==='customers')loadCustomers('');if(view==='flats')loadFlats('');if(view==='bills')loadBills('');if(view==='collection')loadCollection();if(view==='complaints')loadComplaints('');if(view==='visitors')loadVisitors('');if(view==='parking')loadParking('');if(view==='configuration')loadConfig();if(view==='security')loadSecurity()}
function wire(){
 document.querySelectorAll('.side nav details').forEach(x=>{
  x.open=false;
  x.addEventListener('toggle',()=>{
   if(!x.open)return;
   document.querySelectorAll('.side nav details').forEach(y=>{if(y!==x)y.open=false});
  });
 });
 $$('[data-view]').forEach(x=>{if(x.closest('.side nav'))return;x.addEventListener('click',()=>show(x.dataset.view,x.querySelector('span')?.textContent||x.textContent.trim()))});
 $('#logout').onclick=async()=>{await fetch('/api/auth/logout',{method:'POST'});location.href='/login'};
 $('#recordSubscriptionPayment').onclick=async()=>{
  const b=$('#recordSubscriptionPayment');const subscriptionId=Number(b.dataset.subscriptionId||0);if(!subscriptionId)return;
  const x=await get('/api/subscription/current');if(!confirm('Record payment of ₹'+Number(x.amount).toLocaleString('en-IN')+' as '+$('#paymentMode').value+'?'))return;
  const r=await fetch('/api/subscription/payment',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({subscriptionId,amount:x.amount,paymentMode:$('#paymentMode').value,referenceNo:$('#paymentReference').value})});
  const d=await r.json();if(!r.ok){alert(d.message||'Payment failed');return}alert('Subscription payment recorded successfully.');loadSubscription(); };
 $('#flatSearch').oninput=debounce(e=>loadFlats(e.target.value));
 $('#billSearch').oninput=debounce(e=>loadBills(e.target.value));$('#complaintSearch').oninput=debounce(e=>loadComplaints(e.target.value));
 $('#visitorSearch').oninput=debounce(e=>loadVisitors(e.target.value));$('#parkingSearch').oninput=debounce(e=>loadParking(e.target.value));
 $('#language-select').value=Society360I18n.current;$('#language-select').onchange=e=>Society360I18n.setLanguage(e.target.value);
 window.addEventListener('society360-language-changed',()=>{buildDatabaseMenu();tableRegistry.forEach(x=>{try{x.table.setColumns(x.columns.map(c=>({...c,title:Society360I18n.translateText(c.title)})))}catch{}});if(activeConsumerAccount){renderConsumerInfo(activeConsumerAccount);renderConsumerTables(activeConsumerAccount)}});
 setInterval(()=>$('#clock').textContent=new Date().toLocaleString(Society360I18n.locale()),1000);
}
let activeConsumerAccount=null;
function consumerText(v){return v===null||v===undefined||v===''?'—':String(v)}
function consumerMoney(v){return money(v)}
function showConsumerTab(tab){
 $$('.consumer-tab').forEach(b=>b.classList.toggle('active',b.dataset.consumerTab===tab));
 $$('.consumer-panel').forEach(p=>p.classList.toggle('active',p.id==='consumerPanel-'+tab));
 setTimeout(()=>tableRegistry.forEach(x=>{try{x.table.redraw(true)}catch{}}),30);
}
function renderConsumerInfo(x){
 const c=x.consumer||{},s=x.summary||{},flats=x.flats||[];
 $('#activeConsumerId').textContent='CID '+consumerText(c.consumerId);
 $('#consumerAvatar').textContent=consumerText(c.fullName).split(/\s+/).map(v=>v[0]).slice(0,2).join('').toUpperCase()||'C';
 $('#consumerName').textContent=consumerText(c.fullName);
 $('#consumerMeta').textContent=consumerText(c.customerCode)+' · '+Society360I18n.translateDataValue(consumerText(c.customerType));
 $('#consumerPhone').textContent=consumerText(c.phone);$('#consumerEmail').textContent=consumerText(c.email);
 $('#summaryConsumerId').textContent=consumerText(c.consumerId);$('#summaryFlatCount').textContent=consumerText(s.flatCount||0);
 $('#summaryOutstanding').textContent=consumerMoney(s.outstanding||0);$('#summaryNextDue').textContent=consumerText(s.nextDueDate);
 $('#consumerInfoGrid').innerHTML=[
  ['Consumer ID',c.consumerId],['Customer Code',c.customerCode],['Full Name',c.fullName],['Customer Type',c.customerType],['Mobile',c.phone],['Email',c.email]
 ].map(a=>'<div class="consumer-info-row"><span>'+Society360I18n.translateText(a[0])+'</span><strong>'+consumerText(a[1])+'</strong></div>').join('');
 $('#consumerFlatSummary').innerHTML=flats.length?flats.map(f=>'<div class="consumer-flat-chip"><div><b>'+consumerText(f.flatNo)+' · '+consumerText(f.wing)+'</b><small>'+consumerText(f.building)+' · '+Society360I18n.translateDataValue(consumerText(f.relationType))+'</small></div><strong>'+Society360I18n.translateDataValue(consumerText(f.occupancyStatus))+'</strong></div>').join(''):'<div class="muted">'+Society360I18n.translateText('No flats linked')+'</div>';
}
function dueDateFormatter(cell){
 const v=cell.getValue();if(!v)return '—';const d=new Date(v);if(Number.isNaN(d.getTime()))return consumerText(v);
 const today=new Date();today.setHours(0,0,0,0);d.setHours(0,0,0,0);
 const cls=d<today?'due-overdue':d.getTime()===today.getTime()?'due-today':'due-upcoming';
 return '<span class="'+cls+'">'+consumerText(v)+'</span>';
}
function translatedValue(cell){return Society360I18n.translateDataValue(consumerText(cell.getValue()))}
function consumerColumns(){
 return {
 flats:[{title:'Flat',field:'flatNo',headerFilter:true},{title:'Wing',field:'wing',headerFilter:true},{title:'Building',field:'building',headerFilter:true},{title:'Area Sq.Ft.',field:'areaSqft'},{title:'Relation',field:'relationType',headerFilter:true,formatter:translatedValue},{title:'Occupancy',field:'occupancyStatus',headerFilter:true,formatter:translatedValue}],
 bills:[{title:'Bill No',field:'billNo',headerFilter:true},{title:'Flat',field:'flatNo',headerFilter:true},{title:'Bill Date',field:'billDate',headerFilter:true},{title:'Due Date',field:'dueDate',headerFilter:true,formatter:dueDateFormatter},{title:'Total',field:'totalAmount',formatter:c=>consumerMoney(c.getValue())},{title:'Paid',field:'paidAmount',formatter:c=>consumerMoney(c.getValue())},{title:'Balance',field:'balance',formatter:c=>consumerMoney(c.getValue())},{title:'DPC',field:'dpcAmount',formatter:c=>consumerMoney(c.getValue())},{title:'Status',field:'status',headerFilter:true,formatter:translatedValue}],
 payments:[{title:'Payment No',field:'paymentNo',headerFilter:true},{title:'Date',field:'paymentDate',headerFilter:true},{title:'Flat',field:'flatNo',headerFilter:true},{title:'Amount',field:'amount',formatter:c=>consumerMoney(c.getValue())},{title:'Mode',field:'mode',headerFilter:true,formatter:translatedValue},{title:'Reference',field:'referenceNo',headerFilter:true},{title:'Status',field:'status',headerFilter:true,formatter:translatedValue}],
 complaints:[{title:'Complaint No',field:'complaintNo',headerFilter:true},{title:'Flat',field:'flatNo',headerFilter:true},{title:'Category',field:'category',headerFilter:true},{title:'Title',field:'title',headerFilter:true},{title:'Priority',field:'priority',headerFilter:true,formatter:translatedValue},{title:'Status',field:'status',headerFilter:true,formatter:translatedValue},{title:'Created',field:'createdAt',headerFilter:true}],
 parking:[{title:'Slot',field:'slotNo',headerFilter:true},{title:'Type',field:'slotType',headerFilter:true,formatter:translatedValue},{title:'Charge',field:'charge',formatter:c=>consumerMoney(c.getValue())},{title:'Flat',field:'flatNo',headerFilter:true},{title:'Start',field:'startDate'},{title:'End',field:'endDate'},{title:'Active',field:'isActive',formatter:translatedValue}],
 history:[{title:'Date',field:'performedAt',headerFilter:true},{title:'Module',field:'eventType',headerFilter:true},{title:'Event',field:'eventTitle',headerFilter:true},{title:'Reference',field:'referenceNo',headerFilter:true},{title:'Flat',field:'flatNo',headerFilter:true},{title:'By',field:'performedBy',headerFilter:true},{title:'Remark',field:'modifyRemark'}]
 };
}
function renderConsumerTables(x){
 const c=consumerColumns();
 table('consumerFlatsTable',x.flats||[],c.flats,{height:'420px'});
 table('consumerBillsTable',x.bills||[],c.bills,{height:'420px'});
 table('consumerPaymentsTable',x.payments||[],c.payments,{height:'420px'});
 table('consumerComplaintsTable',x.complaints||[],c.complaints,{height:'420px'});
 table('consumerParkingTable',x.parking||[],c.parking,{height:'420px'});
 table('consumerHistoryTable',x.serviceHistory||[],c.history,{height:'420px'});
}
async function openConsumerAccount(consumerId){
 const x=await get('/api/society-admin/consumer-master-account/'+encodeURIComponent(consumerId));if(!x)return;
 activeConsumerAccount=x;$('#consumerAccountEmpty').classList.add('hidden');$('#consumerAccountContent').classList.remove('hidden');renderConsumerInfo(x);renderConsumerTables(x);showConsumerTab('overview');
}
function renderConsumerSuggestions(rows){
 const box=$('#consumerSuggestions');if(!rows.length){box.innerHTML='<div class="consumer-suggestion"><div><b>'+Society360I18n.translateText('No matching customer found')+'</b><div class="consumer-suggestion-meta">'+Society360I18n.translateText('Try a flat number, name, mobile or Consumer ID.')+'</div></div></div>';box.classList.remove('hidden');return;}
 box.innerHTML=rows.map(r=>'<div class="consumer-suggestion" data-consumer-id="'+r.consumer_id+'"><div><div class="consumer-suggestion-main">'+consumerText(r.full_name)+'</div><div class="consumer-suggestion-meta">CID '+consumerText(r.consumer_id)+' · '+consumerText(r.phone)+' · '+consumerText(r.flat_count)+' '+Society360I18n.translateText('flats')+'</div></div><div class="consumer-suggestion-right"><b>'+consumerMoney(r.outstanding)+'</b>'+consumerText(r.primary_flat)+' '+consumerText(r.primary_wing)+'</div></div>').join('');
 box.classList.remove('hidden');box.querySelectorAll('[data-consumer-id]').forEach(el=>el.onclick=async()=>{box.classList.add('hidden');$('#customerSearch').value=el.querySelector('.consumer-suggestion-main').textContent;await openConsumerAccount(el.dataset.consumerId)});
}
const loadConsumerSuggestions=debounce(async q=>{if(!q.trim()){ $('#consumerSuggestions').classList.add('hidden');return;}try{const rows=await get('/api/society-admin/consumer-search?q='+encodeURIComponent(q.trim()));renderConsumerSuggestions(rows)}catch(e){console.error(e)}},180);
function wireConsumerAccount(){
 $('#customerSearch').oninput=e=>loadConsumerSuggestions(e.target.value);
 $('#clearConsumerSearch').onclick=()=>{$('#customerSearch').value='';$('#consumerSuggestions').classList.add('hidden');activeConsumerAccount=null;$('#consumerAccountContent').classList.add('hidden');$('#consumerAccountEmpty').classList.remove('hidden');};
 document.addEventListener('click',e=>{if(!e.target.closest('.consumer-searchbar'))$('#consumerSuggestions')?.classList.add('hidden')});
 $$('.consumer-tab').forEach(b=>b.onclick=()=>showConsumerTab(b.dataset.consumerTab));
}
async function loadCustomers(q){if(q){loadConsumerSuggestions(q);return;}$('#consumerAccountEmpty').classList.remove('hidden');$('#consumerAccountContent').classList.add('hidden');}
async function loadSecurity(){const rows=await get('/api/society-admin/security/logins');table('loginSecurityTable',rows,[{title:'Login',field:'login_name',headerFilter:true},{title:'Name',field:'display_name',headerFilter:true},{title:'Role',field:'role_code',headerFilter:true},{title:'Last Login',field:'last_login_at',headerFilter:true},{title:'IP',field:'last_login_ip',headerFilter:true},{title:'Login Count',field:'login_count',hozAlign:'right'},{title:'Failed Count',field:'failed_login_count',hozAlign:'right'},{title:'Last Failed',field:'last_failed_at'}])}
async function loadFlats(q){const rows=await get('/api/society-admin/flats?q='+encodeURIComponent(q));table('flatTable',rows,[{title:'Flat',field:'flat_no',headerFilter:true},{title:'Wing',field:'wing',headerFilter:true},{title:'Building',field:'building',headerFilter:true},{title:'Type',field:'unit_type',headerFilter:true},{title:'Area',field:'area_sqft',hozAlign:'right'},{title:'Occupancy',field:'occupancy_status',headerFilter:true},{title:'Owner',field:'owner_name',headerFilter:true},{title:'Phone',field:'owner_phone'}])}
async function loadBills(q){const rows=await get('/api/society-admin/bills?q='+encodeURIComponent(q));table('billTable',rows,[{title:'Bill No',field:'bill_no',headerFilter:true},{title:'Month',field:'bill_month',headerFilter:true},{title:'Flat',field:'flat_no',headerFilter:true},{title:'Customer',field:'customer_name',headerFilter:true},{title:'Amount',field:'total_amount',hozAlign:'right',formatter:c=>money(c.getValue())},{title:'Paid',field:'paid_amount',hozAlign:'right',formatter:c=>money(c.getValue())},{title:'Balance',field:'balance',hozAlign:'right',formatter:c=>money(c.getValue())},{title:'Due',field:'due_date'},{title:'Status',field:'status',formatter:c=>'<span class="pill">'+c.getValue()+'</span>'}])}
async function loadCollection(){const rows=await get('/api/society-admin/collection');table('collectionTable',rows,[{title:'Payment No',field:'payment_no',headerFilter:true},{title:'Date',field:'payment_date',headerFilter:true},{title:'Flat',field:'flat_no',headerFilter:true},{title:'Customer',field:'customer_name',headerFilter:true},{title:'Amount',field:'amount',hozAlign:'right',formatter:c=>money(c.getValue())},{title:'Mode',field:'payment_mode',headerFilter:true},{title:'Reference',field:'reference_no'}])}
async function loadComplaints(q){const rows=await get('/api/society-admin/complaints?q='+encodeURIComponent(q));table('complaintTable',rows,[{title:'Complaint',field:'complaint_no',headerFilter:true},{title:'Flat',field:'flat_no',headerFilter:true},{title:'Customer',field:'customer_name',headerFilter:true},{title:'Category',field:'category',headerFilter:true},{title:'Title',field:'title',headerFilter:true},{title:'Priority',field:'priority',headerFilter:true},{title:'Status',field:'status',headerFilter:true},{title:'Created',field:'created_at'}])}
async function loadVisitors(q){const rows=await get('/api/society-admin/visitors?q='+encodeURIComponent(q));table('visitorTable',rows,[{title:'Visitor',field:'visitor_name',headerFilter:true},{title:'Phone',field:'phone',headerFilter:true},{title:'Flat',field:'flat_no',headerFilter:true},{title:'Type',field:'visitor_type',headerFilter:true},{title:'Purpose',field:'purpose'},{title:'Status',field:'status',headerFilter:true},{title:'Entry',field:'entry_time'},{title:'Exit',field:'exit_time'}])}
async function loadParking(q){const rows=await get('/api/society-admin/parking?q='+encodeURIComponent(q));table('parkingTable',rows,[{title:'Slot',field:'slot_no',headerFilter:true},{title:'Type',field:'slot_type',headerFilter:true},{title:'Charge',field:'charge',hozAlign:'right',formatter:c=>money(c.getValue())},{title:'Flat',field:'assigned_flat',headerFilter:true},{title:'Customer',field:'customer_name',headerFilter:true},{title:'Status',field:'status',formatter:c=>'<span class="pill">'+c.getValue()+'</span>'}])}
async function loadConfig(){const [charges,interest]=await Promise.all([get('/api/society-admin/config/charges'),get('/api/society-admin/config/interest')]);table('chargeConfigTable',charges,[{title:'Charge',field:'charge_code',headerFilter:true},{title:'Name',field:'charge_name',headerFilter:true},{title:'Method',field:'calculation_method',headerFilter:true},{title:'Rate',field:'rate'},{title:'Effective From',field:'effective_from'},{title:'Effective To',field:'effective_to'},{title:'Scope',field:'scope_type'}]);table('interestConfigTable',interest,[{title:'Rule',field:'rule_name',headerFilter:true},{title:'Type',field:'calculation_type',headerFilter:true},{title:'Rate',field:'rate'},{title:'Frequency',field:'frequency'},{title:'Grace Days',field:'grace_days'},{title:'Effective From',field:'effective_from'},{title:'Effective To',field:'effective_to'}])}
const translations={en:{dash:'Dashboard',cust:'Customer 360',flat:'Flats & Residents',bill:'Billing',col:'Collection',comp:'Complaints',vis:'Visitors',park:'Parking'},hi:{dash:'डैशबोर्ड',cust:'ग्राहक 360',flat:'फ्लैट और निवासी',bill:'बिलिंग',col:'कलेक्शन',comp:'शिकायतें',vis:'विज़िटर',park:'पार्किंग'},mr:{dash:'डॅशबोर्ड',cust:'ग्राहक 360',flat:'फ्लॅट आणि रहिवासी',bill:'बिलिंग',col:'कलेक्शन',comp:'तक्रारी',vis:'अभ्यागत',park:'पार्किंग'},gu:{dash:'ડેશબોર્ડ',cust:'ગ્રાહક 360',flat:'ફ્લેટ અને રહેવાસી',bill:'બિલિંગ',col:'કલેક્શન',comp:'ફરિયાદો',vis:'મુલાકાતીઓ',park:'પાર્કિંગ'},kn:{dash:'ಡ್ಯಾಶ್‌ಬೋರ್ಡ್',cust:'ಗ್ರಾಹಕ 360',flat:'ಫ್ಲಾಟ್ ಮತ್ತು ನಿವಾಸಿಗಳು',bill:'ಬಿಲ್ಲಿಂಗ್',col:'ಸಂಗ್ರಹ',comp:'ದೂರುಗಳು',vis:'ಭೇಟಿದಾರರು',park:'ಪಾರ್ಕಿಂಗ್'},ta:{dash:'டாஷ்போர்டு',cust:'வாடிக்கையாளர் 360',flat:'ஃப்ளாட்கள் மற்றும் குடியிருப்போர்',bill:'பில்லிங்',col:'வசூல்',comp:'புகார்கள்',vis:'வருகையாளர்கள்',park:'பார்க்கிங்'}};
function applyLanguage(lang){const d=translations[lang]||translations.en;const map=[['home',d.dash],['customers',d.cust],['flats',d.flat],['bills',d.bill],['collection',d.col],['complaints',d.comp],['visitors',d.vis],['parking',d.park]];map.forEach(([v,t])=>{const b=document.querySelector('[data-view="'+v+'"] span');if(b)b.textContent=t})}
$('#saveCharge')?.addEventListener('click',async()=>{const r=await fetch('/api/society-admin/config/charge',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({chargeCode:$('#chargeCode').value,planName:'Future '+$('#chargeCode').value+' '+$('#chargeFrom').value,method:$('#calcMethod').value,rate:Number($('#chargeRate').value),effectiveFrom:$('#chargeFrom').value,effectiveTo:$('#chargeTo').value||null,scopeType:'Society',scopeValue:null})});alert(r.ok?'Future rate saved':'Rate save failed');if(r.ok)loadConfig()});
$('#saveInterest')?.addEventListener('click',async()=>{const r=await fetch('/api/society-admin/config/interest',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({ruleName:$('#interestName').value||'Future DPC',calculationType:'Percentage',rate:Number($('#interestRate').value),frequency:'Monthly',simpleOrCompound:$('#interestCompound').value,graceDays:Number($('#interestGrace').value||0),capAmount:null,effectiveFrom:$('#interestFrom').value,effectiveTo:null})});alert(r.ok?'DPC rule saved':'DPC save failed');if(r.ok)loadConfig()});
init();
