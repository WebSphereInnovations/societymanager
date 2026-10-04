(function(){
'use strict';
async function loadAccountTypes(){
 const rows=await get('/api/society-admin/accounts/types');$('#accountType').innerHTML=rows.map(x=>'<option value="'+x.role_code+'">'+x.role_name+'</option>').join('');
}
async function loadAccountRights(userId=0){
 const rows=await get(userId?'/api/society-admin/accounts/'+userId+'/rights':'/api/society-admin/accounts/rights');
 renderRights($('#accountRights'),rows);
}
function renderRights(el,rows){
 const map=new Map();rows.forEach(x=>{const p=x.parent_module_code||'__root';if(!map.has(p))map.set(p,[]);map.get(p).push(x)});
 el.innerHTML='';
 map.forEach((items,parent)=>{
  const group=document.createElement('div');group.className='right-group';
  const modules=new Map();items.forEach(x=>{if(!modules.has(x.module_code))modules.set(x.module_code,[]);modules.get(x.module_code).push(x)});
  modules.forEach(actions=>{
   const x=actions[0];const row=document.createElement('div');row.className='right-row '+(x.parent_module_code?'right-child':'');
   const title=document.createElement('span');title.textContent=accountLabel(x);row.appendChild(title);
   const acts=document.createElement('div');acts.className='right-actions';
   actions.forEach(a=>{const label=document.createElement('label');const cb=document.createElement('input');cb.type='checkbox';cb.dataset.module=a.module_code;cb.dataset.action=a.action_code;cb.checked=!!a.granted;label.append(cb,document.createTextNode(' '+a.action_code));acts.appendChild(label)});
   row.appendChild(acts);group.appendChild(row);
  });el.appendChild(group);
 });
}
function collectRights(selector){
 return [...document.querySelectorAll(selector+' input[data-module]:checked')].map(x=>({moduleCode:x.dataset.module,actionCode:x.dataset.action,granted:true}));
}
async function loadAccounts(q=''){
 const rows=await get('/api/society-admin/accounts?q='+encodeURIComponent(q));
 const cols=[
  {title:'Login Name',field:'login_name',headerFilter:true},{title:'Display Name',field:'display_name',headerFilter:true},
  {title:'Account Type',field:'account_type_name',headerFilter:true},{title:'Mobile Number',field:'phone',headerFilter:true},
  {title:'Valid From',field:'valid_from',headerFilter:true},{title:'Valid To',field:'valid_to',headerFilter:true},
  {title:'Status',field:'is_active',formatter:c=>c.getValue()?'Active':'Blocked'},{title:'Last Login',field:'last_login_at'},
  {title:'Login Count',field:'login_count'},{title:'Action',formatter:()=>'<button class="account-edit">Edit Existing</button>',width:125,hozAlign:'center'}
 ];
 const t=table('accountTable',rows,cols,{height:'560px'});
 t.on('rowClick',(e,row)=>{window.selectedAccount=row.getData();if(e.target.classList.contains('account-edit'))editAccount(row.getData())});
}
function resetAccountForm(){
 $('#accountUserId').value='';$('#accountLogin').value='';$('#accountName').value='';$('#accountEmail').value='';$('#accountPhone').value='';
 $('#accountPassword').value='';$('#accountValidFrom').value=new Date().toISOString().slice(0,10);$('#accountValidTo').value='';$('#accountRemark').value='';
 $('#accountFormTitle').textContent='Create New Employee Account';$('#accountFormMode').textContent='NEW';$('#passwordRequiredMark').textContent='*';
 $('#accountFormHelp').textContent='Enter the employee details, validity and exact access rights.';loadAccountRights(0);
}
async function editAccount(d){
 $('#accountUserId').value=d.user_id;$('#accountLogin').value=d.login_name||'';$('#accountName').value=d.display_name||'';$('#accountEmail').value=d.email||'';$('#accountPhone').value=d.phone||'';
 $('#accountPassword').value='';$('#accountType').value=d.account_type_code||d.role_code||$('#accountType').value;$('#accountValidFrom').value=d.valid_from||new Date().toISOString().slice(0,10);$('#accountValidTo').value=d.valid_to||'';$('#accountRemark').value='';
 $('#accountFormTitle').textContent='Edit Existing Employee Account';$('#accountFormMode').textContent='EDIT';$('#passwordRequiredMark').textContent='';
 $('#accountFormHelp').textContent='Update this existing account. Leave Password blank to keep the current password.';await loadAccountRights(d.user_id);
 document.querySelector('[data-admin-tab="accounts"]').click();window.scrollTo({top:0,behavior:'smooth'});
}
async function saveAccount(){
 const button=$('#saveAccount');if(button.disabled)return;
 const payload={userId:Number($('#accountUserId').value||0),loginName:$('#accountLogin').value.trim(),displayName:$('#accountName').value.trim(),email:$('#accountEmail').value.trim()||null,phone:$('#accountPhone').value.trim()||null,accountType:$('#accountType').value,password:$('#accountPassword').value||null,validFrom:$('#accountValidFrom').value,validTo:$('#accountValidTo').value||null,rights:collectRights('#accountRights'),remark:$('#accountRemark').value.trim()};
 if(!payload.loginName||!payload.displayName||!payload.accountType||!payload.validFrom){alert('Please complete all required account fields.');return}
 if(!payload.userId&&!payload.password){alert('Password is required for a new account.');return}
 if(payload.password&&payload.password.length<10){alert('Password must contain at least 10 characters.');return}
 if(payload.validTo&&payload.validTo<payload.validFrom){alert('Valid To cannot be before Valid From.');return}
 button.disabled=true;button.textContent='Saving...';
 try{const r=await fetch('/api/society-admin/accounts/save',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(payload)});const raw=await r.text();let d={};try{d=JSON.parse(raw)}catch{}if(!r.ok){alert(d.message||raw||'Account could not be saved.');return}alert('Account saved successfully.');resetAccountForm();await loadAccounts($('#accountSearch').value)}catch(e){alert('Account could not be saved. Please check the server connection.')}finally{button.disabled=false;button.textContent='Save Account'}
}
async function loadRoles(){
 const rows=await get('/api/society-admin/roles');
 const t=table('roleTable',rows,[{title:'Role Code',field:'role_code',headerFilter:true},{title:'Role Name',field:'role_name',headerFilter:true},{title:'Description',field:'description'},{title:'System Role',field:'is_system'},{title:'Users',field:'user_count'},{title:'Action',formatter:()=>'<button class="account-edit">Edit Rights</button>',width:105}]);
 t.on('rowClick',(e,row)=>{if(e.target.classList.contains('account-edit'))editRole(row.getData())});
}
async function editRole(d){
 $('#roleId').value=d.role_id;$('#roleCode').value=d.role_code||'';$('#roleName').value=d.role_name||'';$('#roleDescription').value=d.description||'';$('#roleFormTitle').textContent='Edit Role: '+d.role_name;
 const rows=await get('/api/society-admin/roles/'+d.role_id+'/rights');renderRights($('#roleRights'),rows);
}
function clearRole(){$('#roleId').value='';$('#roleCode').value='';$('#roleName').value='';$('#roleDescription').value='';$('#roleFormTitle').textContent='Create New Role';$('#roleRights').innerHTML=''}
async function saveRole(){
 const p={roleId:Number($('#roleId').value||0),roleCode:$('#roleCode').value.trim(),roleName:$('#roleName').value.trim(),description:$('#roleDescription').value.trim()||null,rights:collectRights('#roleRights'),remark:'Role rights maintenance'};
 if(!p.roleCode||!p.roleName){alert('Role Code and Role Name are required.');return}
 const r=await fetch('/api/society-admin/roles/save',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(p)});const d=await r.json().catch(()=>({}));if(!r.ok){alert(d.message||'Role could not be saved.');return}alert('Role saved successfully.');clearRole();loadRoles();
}
async function loadMenus(){
 const rows=await get('/api/society-admin/menu-catalog');
 const parents=rows.filter(x=>!x.parent_module_code);$('#menuParent').innerHTML='<option value="">No Parent — Top Level Menu</option>'+parents.map(x=>'<option value="'+x.module_code+'">'+x.module_name+'</option>').join('');
 const t=table('menuTable',rows,[{title:'Code',field:'module_code',headerFilter:true},{title:'Menu / Submenu',field:'module_name',headerFilter:true},{title:'Parent Menu',field:'parent_module_code',headerFilter:true},{title:'Order',field:'display_order'},{title:'Visible',field:'visible',formatter:c=>c.getValue()?'Yes':'No'},{title:'Active',field:'is_active',formatter:c=>c.getValue()?'Yes':'No'},{title:'Children',field:'child_count'},{title:'Permissions',field:'permission_count'},{title:'Action',formatter:()=>'<button class="account-edit">Edit</button>',width:70}]);
 t.on('rowClick',(e,row)=>{if(e.target.classList.contains('account-edit'))editMenu(row.getData())});
}
function editMenu(d){$('#menuId').value=d.module_id;$('#menuCode').value=d.module_code||'';$('#menuCode').disabled=true;$('#menuName').value=d.module_name||'';$('#menuParent').value=d.parent_module_code||'';$('#menuOrder').value=d.display_order??100;$('#menuVisible').value=String(!!d.visible);$('#menuRemark').value='';$('#menuFormTitle').textContent='Edit Menu / Submenu'}
function clearMenu(){$('#menuId').value='';$('#menuCode').value='';$('#menuCode').disabled=false;$('#menuName').value='';$('#menuParent').value='';$('#menuOrder').value=100;$('#menuVisible').value='true';$('#menuRemark').value='';$('#menuFormTitle').textContent='Add Menu / Submenu'}
async function saveMenu(){
 const p={moduleId:Number($('#menuId').value||0),moduleCode:$('#menuCode').value.trim(),moduleName:$('#menuName').value.trim(),parentModuleCode:$('#menuParent').value||null,displayOrder:Number($('#menuOrder').value||100),visible:$('#menuVisible').value==='true',remark:$('#menuRemark').value.trim()};
 if(!p.moduleCode||!p.moduleName){alert('Menu Code and Menu Name are required.');return}
 const r=await fetch('/api/society-admin/menu-catalog/save',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(p)});const d=await r.json().catch(()=>({}));if(!r.ok){alert(d.message||'Menu could not be saved.');return}alert('Menu saved successfully.');clearMenu();loadMenus();buildDatabaseMenu();
}
function wireAdminTabs(){
 document.querySelectorAll('.admin-tab').forEach(b=>b.onclick=()=>{document.querySelectorAll('.admin-tab').forEach(x=>x.classList.toggle('active',x===b));document.querySelectorAll('.admin-tab-panel').forEach(x=>x.classList.toggle('active',x.id==='adminTab-'+b.dataset.adminTab));if(b.dataset.adminTab==='roles')loadRoles();if(b.dataset.adminTab==='menus')loadMenus()});
 $('#newAccount').onclick=resetAccountForm;$('#editSelectedAccount').onclick=()=>window.selectedAccount?editAccount(window.selectedAccount):alert('Select an existing account from the list first.');
 $('#selectAllRights').onclick=()=>document.querySelectorAll('#accountRights input[type=checkbox]').forEach(x=>x.checked=true);$('#clearAllRights').onclick=()=>document.querySelectorAll('#accountRights input[type=checkbox]').forEach(x=>x.checked=false);
 $('#saveAccount').onclick=saveAccount;$('#resetAccount').onclick=resetAccountForm;$('#accountSearch').oninput=debounce(e=>loadAccounts(e.target.value));
 $('#newRole').onclick=clearRole;$('#clearRole').onclick=clearRole;$('#saveRole').onclick=saveRole;
 $('#newMenu').onclick=clearMenu;$('#clearMenu').onclick=clearMenu;$('#saveMenu').onclick=saveMenu;
}
window.buildDatabaseMenu=buildDatabaseMenu;
window.openAdminSection=function(section){
 show('accounts');
 const tabs=document.querySelector('.admin-tabs');
 const panels={account:document.querySelector('#adminTab-accounts'),roles:document.querySelector('#adminTab-roles'),menus:document.querySelector('#adminTab-menus')};
 if(tabs)tabs.style.display='none';
 Object.values(panels).forEach(x=>x?.classList.remove('active'));
 if(section==='create'){panels.account?.classList.add('active');resetAccountForm();return true}
 if(section==='manage'){panels.account?.classList.add('active');return true}
 if(section==='roles'){panels.roles?.classList.add('active');loadRoles();return true}
 if(section==='menus'){panels.menus?.classList.add('active');loadMenus();return true}
 return false;
};
window.openCustomer=()=>{};
wireAdminTabs();loadAccountTypes();resetAccountForm();loadAccounts();buildDatabaseMenu();
})();