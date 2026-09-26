[Reading 40 lines from start (total: 40 lines, 0 remaining)]

const bills=[
{id:'INV-2609-0412',flat:'A-402',resident:'Aarav Mehta',type:'Maintenance',amount:4850,date:'26 Sep 2026',status:'Paid'},
{id:'INV-2609-0408',flat:'B-1102',resident:'Neha Shah',type:'Maintenance + Parking',amount:6350,date:'26 Sep 2026',status:'Paid'},
{id:'INV-2609-0397',flat:'C-803',resident:'Rohan Patil',type:'Maintenance',amount:4200,date:'25 Sep 2026',status:'Partial'},
{id:'INV-2609-0389',flat:'A-706',resident:'Isha Kulkarni',type:'Maintenance',amount:5100,date:'25 Sep 2026',status:'Pending'},
{id:'INV-2609-0381',flat:'B-504',resident:'Vivek Joshi',type:'Maintenance + Water',amount:5650,date:'24 Sep 2026',status:'Paid'}
];

let billingTable;
function renderBillingTable(){
  if(billingTable) billingTable.destroy();
  billingTable=new Tabulator('#billing-table',{data:bills,layout:'fitColumns',height:'245px',rowHeight:42,responsiveLayout:'collapse',columns:[
    {title:Society360I18n.t('invoice'),field:'id',width:145},
    {title:Society360I18n.t('flat'),field:'flat',width:72},
    {title:Society360I18n.t('resident'),field:'resident',minWidth:130},
    {title:Society360I18n.t('type'),field:'type',minWidth:145},
    {title:Society360I18n.t('amount'),field:'amount',hozAlign:'right',formatter:c=>'₹'+Number(c.getValue()).toLocaleString(Society360I18n.locale())},
    {title:Society360I18n.t('date'),field:'date',width:112},
    {title:Society360I18n.t('status'),field:'status',width:85,formatter:c=>{const v=c.getValue();const key=v.toLowerCase();return '<span class="status '+key+'">'+(Society360I18n.t(key)||v)+'</span>';}}
  ]});
}

async function loadSystemHealth(){
  try{
    const r=await fetch('/api/health',{cache:'no-store'});
    const h=await r.json();
    const live=document.querySelector('.live');
    live.innerHTML='<span></span><span>'+Society360I18n.t('liveSystem')+' · '+(h.databaseConfigured?Society360I18n.t('dbConnected'):Society360I18n.t('dbPending'))+'</span>';
  }catch{
    document.querySelector('.live').innerHTML='<span style="background:#ef6b77"></span><span>'+Society360I18n.t('apiUnavailable')+'</span>';
  }
}
function clock(){const d=new Date();document.querySelector('#clock').textContent=d.toLocaleDateString(Society360I18n.locale(),{weekday:'short',day:'2-digit',month:'short',year:'numeric'})+' · '+d.toLocaleTimeString(Society360I18n.locale(),{hour:'2-digit',minute:'2-digit',second:'2-digit'});}
function refreshLocalized(){Society360I18n.apply();renderBillingTable();loadSystemHealth();clock();}
Society360I18n.init();
document.querySelector('#language-select').addEventListener('change',e=>Society360I18n.setLanguage(e.target.value));
window.addEventListener('society360-language-changed',refreshLocalized);
clock();setInterval(clock,1000);loadSystemHealth();renderBillingTable();
document.querySelectorAll('nav a').forEach(a=>a.addEventListener('click',()=>{document.querySelectorAll('nav a').forEach(x=>x.classList.remove('active'));a.classList.add('active');}));
document.querySelector('.primary').addEventListener('click',()=>alert(Society360I18n.t('createBill')+' workspace is the next connected module.'));

[executed on device: Sandman (3c28f028-a467-4934-be2f-752a8db6b6a8)]