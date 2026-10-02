(function(){
'use strict';
const accountViewMap={
 ADM_ACCOUNTS:'accounts',
 CRM:'customers',CRM_CUSTOMER_SEARCH:'customers',CRM_CUSTOMER_360:'customers',
 FLATS:'flats',RESIDENTS:'flats',
 BILLING_MANAGEMENT:'bills',BILL_DOWNLOAD:'bills',BILL_COMPUTATION:'bills',
 COLLECTION_MANAGEMENT:'collection',COL_ACCEPT:'collection',COL_SERVICE:'collection',COL_DAILY:'collection',
 CRM_COMPLAINT:'complaints',COMPLAINTS:'complaints',
 SECURITY_VISITOR:'visitors',SEC_VISITOR:'visitors',SEC_APPROVAL:'visitors',SEC_GATE:'security',SEC_VEHICLE:'security',
 PARKING_MANAGEMENT:'parking',PARK_SLOT:'parking',PARK_ASSIGN:'parking',PARK_VEHICLE:'parking',
 APP_DASHBOARD:'home',DASH_BILLING:'bills',DASH_COLLECTION:'collection',DASH_CRM:'customers',
 SOCIETY_ADMIN_EXTRA:'configuration',REPORTING_ANALYTICS:'reports',AUDIT_GOVERNANCE:'security'
};
const accountIcons={ADMINISTRATOR:'⚙',CRM:'◎',BILLING_MANAGEMENT:'₹',COLLECTION_MANAGEMENT:'◈',SECURITY_VISITOR:'◉',PARKING_MANAGEMENT:'◆',FLATS:'▦',RESIDENTS:'▦',APP_DASHBOARD:'⌂'};
function accountView(code){return accountViewMap[code]||'module-workspace'}
function accountLabel(x){return Society360I18n.translateText(x.module_name||x.moduleName||x.module_code||x.moduleCode)}
async function buildDatabaseMenu(){
 try{
  const rows=await get('/api/menu');
  const nav=document.querySelector('#dbMenu');if(!nav)return;
  nav.innerHTML='';
  const groups=new Map();
  rows.forEach(x=>{const p=x.parent_module_code||'__root';if(!groups.has(p))groups.set(p,[]);groups.get(p).push(x)});
  const roots=rows.filter(x=>!x.parent_module_code);
  roots.forEach(root=>{
   const children=rows.filter(x=>x.parent_module_code===root.module_code);
   if(children.length){
    const d=document.createElement('details');d.open=true;
    const s=document.createElement('summary');s.textContent=accountLabel(root);d.appendChild(s);
    children.forEach(c=>d.appendChild(menuButton(c)));
    nav.appendChild(d);
   }else nav.appendChild(menuButton(root));
  });
  if(!rows.some(x=>x.module_code==='APP_DASHBOARD'))show('module-workspace','Access');
 }catch(e){}
}
function menuButton(x){
 const b=document.createElement('button');
 b.type='button';b.dataset.view=accountView(x.module_code);b.dataset.moduleCode=x.module_code;
 b.innerHTML=(accountIcons[x.module_code]||'•')+' <span>'+accountLabel(x)+'</span>';
 b.addEventListener('click',()=>show(b.dataset.view,b.querySelector('span')?.textContent||x.module_name));
 return b;
}
async function loadAccountTypes(){
 const rows=await get('/api/society-admin/accounts/types');
 const el=$('#accountType');el.innerHTML=rows.map(x=>'<option value="'+x.role_code+'">'+x.role_name+'</option>').join('');
}
async function loadAccountRights(userId=0){
 const rows=await get(userId?'/api/society-admin/accounts/'+userId+'/rights':'/api/society-admin/accounts/rights');
 const map=new Map();
 rows.forEach(x=>{const p=x.parent_module_code||'__root';if(!map.has(p))map.set(p,[]);map.get(p).push(x)});
 const el=$('#accountRights');el.innerHTML='';
 map.forEach((items,parent)=>{
  const group=document.createElement('div');group.className='right-group';
  const parentItem=items.find(x=>x.module_code===parent)||items[0];
  if(parent!=='__root'){
   const head=document.createElement('div');head.className='right-row right-parent';head.textContent=parentItem.parent_module_code?parent:parentItem.module_name;group.appendChild(head);
  }
  const modules=new Map();
  items.forEach(x=>{if(!modules.has(x.module_code))modules.set(x.module_code,[]);modules.get(x.module_code).push(x)});
  modules.forEach(actions=>{
   const x=actions[0];const row=document.createElement('div');row.className='right-row '+(x.parent_module_code?'right-child':'');
   const title=document.createElement('span');title.textContent=accountLabel(x);row.appendChild(title);
   const acts=document.createElement('div');acts.className='right-actions';
   actions.forEach(a=>{
    const label=document.createElement('label');const cb=document.createElement('input');cb.type='checkbox';cb.dataset.module=a.module_code;cb.dataset.action=a.action_code;cb.checked=!!a.granted;label.append(cb,document.createTextNode(' '+a.action_code));acts.appendChild(label);
   });
   row.appendChild(acts);group.appendChild(row);
  });
  el.appendChild(group);
 });
}
function collectAccountRights(){
 return [...document.querySelectorAll('#accountRights input[data-module]:checked')].map(x=>({moduleCode:x.dataset.module,actionCode:x.dataset.action,granted:true}));
}
async function loadAccounts(q=''){
 const rows=await get('/api/society-admin/accounts?q='+encodeURIComponent(q));
 const cols=[
  {title:'Login',field:'login_name',headerFilter:true},{title:'Name',field:'display_name',headerFilter:true},
  {title:'Account Type',field:'account_type_name',headerFilter:true},{title:'Mobile',field:'phone',headerFilter:true},
  {title:'Valid From',field:'valid_from',headerFilter:true},{title:'Valid To',field:'valid_to',headerFilter:true},
  {title:'Status',field:'is_active',formatter:c=>c.getValue()?'Active':'Blocked'},
  {title:'Last Login',field:'last_login_at'},{title:'Logins',field:'login_count'},
  {title:'Actions',formatter:()=>'<button class="account-edit">Edit</button> <button class="account-toggle">Block</button>',width:150,hozAlign:'center'}
 ];
 const t=table('accountTable',rows,cols,{height:'560px'});
 t.on('cellClick',(e,cell)=>{
  const d=cell.getRow().getData();
  if(e.target.classList.contains('account-edit'))editAccount(d);
  if(e.target.classList.contains('account-toggle'))toggleAccount(d);
 });
}
function resetAccountForm(){
 $('#accountUserId').value='';$('#accountLogin').value='';$('#accountName').value='';$('#accountEmail').value='';$('#accountPhone').value='';
 $('#accountPassword').value='';$('#accountValidFrom').value=new Date().toISOString().slice(0,10);$('#accountValidTo').value='';$('#accountRemark').value='';
 $('#accountFormTitle').textContent=Society360I18n.translateText('Create Account');
 $('#accountFormMode').textContent='NEW';$('#passwordRequiredMark').textContent='*';
 loadAccountRights(0);
}
async function editAccount(d){
 $('#accountUserId').value=d.user_id;$('#accountLogin').value=d.login_name;$('#accountName').value=d.display_name;$('#accountEmail').value=d.email||'';
 $('#accountPhone').value=d.phone||'';$('#accountType').value=d.account_type_code;$('#accountPassword').value='';$('#accountValidFrom').value=d.valid_from||'';
 $('#accountValidTo').value=d.valid_to||'';$('#accountRemark').value='';$('#accountFormTitle').textContent='Edit Account';$('#accountFormMode').textContent='EDIT';$('#passwordRequiredMark').textContent='';await loadAccountRights(d.user_id);show('accounts','Manage Accounts');
}
async function saveAccount(){
 const button=$('#saveAccount');
 if(button.disabled)return;
 const payload={
  userId:Number($('#accountUserId').value||0),loginName:$('#accountLogin').value.trim(),displayName:$('#accountName').value.trim(),
  email:$('#accountEmail').value.trim()||null,phone:$('#accountPhone').value.trim()||null,accountType:$('#accountType').value,
  password:$('#accountPassword').value||null,validFrom:$('#accountValidFrom').value,validTo:$('#accountValidTo').value||null,
  rights:collectAccountRights(),remark:$('#accountRemark').value.trim()||null
 };
 if(!payload.loginName||!payload.displayName||!payload.accountType||!payload.validFrom){alert('Please complete the account details.');return}
 if(!payload.userId&&!payload.password){alert('Password is required for a new account.');return}
 if(payload.password&&payload.password.length<10){alert('Password must contain at least 10 characters.');return}
 if(payload.validTo&&payload.validTo<payload.validFrom){alert('Valid To cannot be before Valid From.');return}
 button.disabled=true;button.textContent='Saving...';
 try{
  const r=await fetch('/api/society-admin/accounts/save',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(payload)});
  const raw=await r.text();let d={};try{d=JSON.parse(raw)}catch{}
  if(!r.ok){alert(d.message||raw||'Account could not be saved.');return}
  alert('Account saved successfully.');resetAccountForm();await loadAccounts($('#accountSearch').value);
 }catch(e){alert('Account could not be saved. Please check the server connection and try again.');}
 finally{button.disabled=false;button.textContent='Save Account';}
}
async function toggleAccount(d){
 const action=d.is_active?'block':'unblock';
 if(!confirm('Do you want to '+action+' '+d.login_name+'?'))return;
 const r=await fetch('/api/society-admin/accounts/status',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({userId:d.user_id,isActive:!d.is_active,remark:'Account '+action})});
 const x=await r.json();if(!r.ok){alert(x.message||'Account status could not be changed.');return}loadAccounts($('#accountSearch').value);
}
window.buildDatabaseMenu=buildDatabaseMenu;
async function initAccountManagement(){
 await buildDatabaseMenu();
 try{await loadAccountTypes();resetAccountForm();loadAccounts('');}catch(e){}
 $('#accountSearch')?.addEventListener('input',debounce(e=>loadAccounts(e.target.value)));
 $('#saveAccount')?.addEventListener('click',saveAccount);
 $('#resetAccount')?.addEventListener('click',resetAccountForm);
 $('#selectAllRights')?.addEventListener('click',()=>document.querySelectorAll('#accountRights input').forEach(x=>x.checked=true));
 $('#clearAllRights')?.addEventListener('click',()=>document.querySelectorAll('#accountRights input').forEach(x=>x.checked=false));
}
window.openCustomer=async function(id){
 const x=await get('/api/society-admin/consumer-account/'+id);
 const d=$('#customer360');d.classList.remove('hidden');
 const c=x.customer;
 d.innerHTML='<div class="panel" style="margin-bottom:12px"><span class="eyebrow">CONSUMER ACCOUNT</span><h2 style="margin:6px 0">'+(c.fullName||'')+'</h2><div class="cards" style="grid-template-columns:repeat(4,1fr);margin-top:10px"><article><small>Mobile</small><strong>'+(c.phone||'—')+'</strong></article><article><small>Email</small><strong>'+(c.email||'—')+'</strong></article><article><small>Consumer Code</small><strong>'+(c.customerCode||'—')+'</strong></article><article><small>Type</small><strong>'+(c.customerType||'—')+'</strong></article></div></div><div class="panel"><h3>Flats</h3><div id="consumerFlatTable"></div></div>';
 table('consumerFlatTable',x.flats,[{title:'Flat',field:'flat_no',headerFilter:true},{title:'Wing',field:'wing',headerFilter:true},{title:'Building',field:'building',headerFilter:true},{title:'Area',field:'area_sqft'},{title:'Relation',field:'relation_type'},{title:'Last Bill',field:'last_bill_date'},{title:'Bill Amount',field:'last_bill_amount',formatter:c=>money(c.getValue())},{title:'Arrear',field:'arrear',formatter:c=>money(c.getValue())},{title:'Last Payment',field:'last_payment_date'}],{height:'380px'});
 d.scrollIntoView({behavior:'smooth',block:'start'});
};
const originalInit=window.init;
window.addEventListener('load',()=>{initAccountManagement();});
})();