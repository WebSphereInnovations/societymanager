(function(){
'use strict';
const metricDefs=[
  ['total_societies','societies','systemTotal'],
  ['active_societies','activeSocieties','currentlyActive'],
  ['total_flats','flats','acrossAllSocieties'],
  ['total_customers','customers','registeredCustomers'],
  ['active_subscriptions','activeSubscriptions','currentSubscriptions'],
  ['expiring_30_days','expiring30Days','requiresAttention']
];
const tableHeaders={society_id:'societyId',society_name:'societyName',plan_name:'planName',status:'status',start_date:'startDate',end_date:'endDate',days_remaining:'daysRemaining'};
const t=k=>window.Society360I18n?window.Society360I18n.t(k):k;
function renderMetrics(m){
 const root=document.getElementById('platform-metrics'); if(!root)return;
 root.innerHTML=metricDefs.map(([field,key])=>'<article class="metric"><div class="metric-top"><span>'+t(key)+'</span></div><strong>'+String(m[field]??'—')+'</strong></article>').join('');
 document.querySelectorAll('[data-platform]').forEach(el=>{
  const f=el.getAttribute('data-platform');
  const v=f==='societies'?m.total_societies:f==='active'?m.active_societies:f==='flats'?m.total_flats:f==='customers'?m.total_customers:f==='subscriptions'?m.active_subscriptions:f==='expiring'?m.expiring_30_days:null;
  if(v!==null&&v!==undefined)el.textContent=String(v);
 });
}
async function loadDashboard(){try{const r=await fetch('/api/platform/dashboard',{cache:'no-store'});if(r.ok){const d=await r.json();if(d&&d[0])renderMetrics(d[0]);}}catch{}}
async function loadSubscriptions(){
 const root=document.getElementById('subscription-table'); if(!root||!window.Tabulator)return;
 try{const r=await fetch('/api/platform/subscriptions',{cache:'no-store'});const data=r.ok?await r.json():[];
  const columns=Object.keys(data[0]||{}).map(k=>({title:t(tableHeaders[k]||k.replaceAll('_',' ')),field:k,headerFilter:true}));
  if(root._tabulator)root._tabulator.destroy();
  root._tabulator=new Tabulator(root,{data,layout:'fitColumns',height:'260px',pagination:true,columns});
 }catch{}
}
function applyDashboardLanguage(){if(window.Society360I18n)window.Society360I18n.apply();loadDashboard();loadSubscriptions();}
document.addEventListener('DOMContentLoaded',()=>{loadDashboard();loadSubscriptions();});
window.addEventListener('society360-language-changed',applyDashboardLanguage);
})();