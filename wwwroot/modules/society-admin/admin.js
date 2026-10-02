const $=s=>document.querySelector(s);const $$=s=>document.querySelectorAll(s);
let session=null;
const money=v=>'₹'+Number(v||0).toLocaleString('en-IN',{maximumFractionDigits:2});
async function get(url){const r=await fetch(url,{cache:'no-store'});if(r.status===401){location.href='/login';throw 0}if(!r.ok){let d={};try{d=await r.json()}catch{}throw new Error(d.message||'Request failed')}return r.json()}
const tableRegistry=new Map();
function table(id,data,columns,opts={}){const el=$('#'+id);if(!el)return null;if(el._tab)el._tab.destroy();const localized=columns.map(c=>({...c,title:Society360I18n.translateText(c.title)}));el._tab=new Tabulator(el,{data,layout:'fitColumns',height:'470px',pagination:true,paginationSize:15,headerFilterPlaceholder:Society360I18n.translateText('Filter...'),columns:localized,...opts});tableRegistry.set(id,{table:el._tab,columns});return el._tab}
function debounce(fn,ms=280){let t;return(...a)=>{clearTimeout(t);t=setTimeout(()=>fn(...a),ms)}}
async function init(){
 try{
  const me=await get('/api/auth/me');session=me.session;window.society360Permissions=me.permissions||[];
  if(session.roleCode==='RESIDENT'){location.href='/modules/customer/index.html';return}
  const society=me.societies.find(x=>x.societyId===session.societyId)||me.societies[0];$('#societyName').textContent=society?.societyName||'Society';
  $('#userName').textContent=session.displayName;$('#avatar').textContent=session.displayName.split(' ').map(x=>x[0]).slice(0,2).join('');
  if(window.society360Permissions.some(x=>x.moduleCode==='APP_DASHBOARD'&&x.actionCode==='VIEW'))loadDashboard();
  wire();
 }catch(e){location.href='/login'}
}
async function loadDashboard(){try{const x=await get('/api/society-admin/dashboard');$('#totalFlats').textContent=x.totalFlats;$('#occupiedFlats').textContent=x.occupiedFlats;$('#collected').textContent=money(x.collected);$('#outstanding').textContent=money(x.outstanding);$('#openComplaints').textContent=x.openComplaints;$('#insideVisitors').textContent=x.insideVisitors}catch(e){}}
function show(view,label){const target=document.getElementById(view)?view:'home';$$('.view').forEach(x=>x.classList.toggle('active',x.id===target));$('.side nav button')?.classList.remove('active');const b=document.querySelector('.side nav button[data-view="'+target+'"]');if(b)b.classList.add('active');$('#heading').textContent=label||'Society Dashboard'}
function wire(){
 $('#logout').onclick=async()=>{await fetch('/api/auth/logout',{method:'POST'});location.href='/login'};
 $('#language-select').value=Society360I18n.current;$('#language-select').onchange=e=>Society360I18n.setLanguage(e.target.value);
 setInterval(()=>{const c=$('#clock');if(c)c.textContent=new Date().toLocaleString(Society360I18n.locale())},1000);
 window.addEventListener('society360-language-changed',()=>{tableRegistry.forEach(x=>{try{x.table.setColumns(x.columns.map(c=>({...c,title:Society360I18n.translateText(c.title)})))}catch{}});if(window.buildDatabaseMenu)window.buildDatabaseMenu()});
}
Society360I18n.init();init();