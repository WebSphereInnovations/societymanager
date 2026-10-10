(function(){
'use strict';
const $=s=>document.querySelector(s);
const money=n=>new Intl.NumberFormat(window.Society360I18n?.locale?.()||'en-IN',{style:'currency',currency:'INR',maximumFractionDigits:2}).format(Number(n||0));
const number=n=>new Intl.NumberFormat(window.Society360I18n?.locale?.()||'en-IN',{maximumFractionDigits:1}).format(Number(n||0));
const tr=s=>window.Society360I18n?.translateText?.(String(s??''))??String(s??'');
const colors=['#7968e8','#28b99a','#4d91d7','#e7a94e','#df7180','#8d6bc7','#54b6c6','#a1b66a','#b48b6b'];
let lastData=null,requestController=null,requestSequence=0,filterOptionsReady=false;
const todayLocal=()=>{const d=new Date();return new Date(d.getTime()-d.getTimezoneOffset()*60000).toISOString().slice(0,10)};
const dateAdd=(value,days)=>{const d=new Date(value+'T12:00:00');d.setDate(d.getDate()+days);return d.toISOString().slice(0,10)};
function t(key){return tr(key)}
function setDefaultDates(preset){
 const today=todayLocal(),d=new Date(today+'T12:00:00');let from=today;
 if(preset==='week'){from=dateAdd(today,-((d.getDay()+6)%7));}
 else if(preset==='quarter'){const month=Math.floor(d.getMonth()/3)*3;from=new Date(d.getFullYear(),month,1,12).toISOString().slice(0,10);}
 else if(preset==='year'){from=d.getFullYear()+'-01-01';}
 else if(preset==='financial-year'){const fyStartYear=d.getMonth()>=3?d.getFullYear():d.getFullYear()-1;from=fyStartYear+'-04-01';}
 else {from=d.getFullYear()+'-'+String(d.getMonth()+1).padStart(2,'0')+'-01';}
 $('#dashFrom').value=from;$('#dashTo').value=today;
}
function readFilters(){
 return {from:$('#dashFrom').value,to:$('#dashTo').value,buildingId:$('#dashBuilding').value,unitType:$('#dashUnitType').value,customerType:$('#dashCustomerType').value,paymentMode:$('#dashPaymentMode').value,billStatus:$('#dashBillStatus').value};
}
function queryString(f){const p=new URLSearchParams();Object.entries(f).forEach(([k,v])=>{if(v!==''&&v!=null)p.set(k,v)});return p.toString()}
function showError(message){const el=$('#dashboardError');el.hidden=!message;el.textContent=message||''}
function setStatus(message){$('#dashboardStatus').textContent=t(message)}
function setLoading(){
 setStatus('Loading dashboard data');showError('');
 ['#dashboardTrend','#dashboardOccupancy','#dashboardPaymentModes','#dashboardBillStatuses','#dashboardCustomerTypes','#dashboardUnitTypes','#dashboardComplaintStatuses'].forEach(s=>{const e=$(s);if(e)e.innerHTML='<div class="dash-empty">'+t('Loading chart')+'</div>'});
}
async function load(){
 if(!$('#dashboardKpis'))return;
 if(requestController)requestController.abort();
 requestController=new AbortController();const seq=++requestSequence;const f=readFilters();
 if(!f.from||!f.to){showError(t('Choose both a start date and an end date.'));return}
 if(f.from>f.to){showError(t('Start date must be on or before end date.'));return}
 setLoading();
 try{
  const response=await fetch('/api/society-admin/dashboard/analytics?'+queryString(f),{cache:'no-store',signal:requestController.signal});
  if(!response.ok){if(response.status===401){location.href='/login.html';return}if(response.status===403)throw new Error(t('You do not have permission to view dashboard analytics.'));throw new Error(t('Dashboard data could not be loaded.'))}
  const data=await response.json();if(seq!==requestSequence)return;
  lastData=data;render(data);showError('');
 }catch(e){if(e.name==='AbortError')return;showError(e.message||t('Dashboard data could not be loaded.'));setStatus('Dashboard data unavailable')}
}
function fillSelect(id,items,allLabel,valueKey,labelKey){
 const el=$(id);if(!el)return;const previous=el.value;el.replaceChildren();
 const all=document.createElement('option');all.value='';all.textContent=t(allLabel);el.appendChild(all);
 (items||[]).forEach(item=>{const o=document.createElement('option');o.value=item[valueKey]??'';o.textContent=t(item[labelKey]??item.value??item.label??'');el.appendChild(o)});
 if([...el.options].some(o=>o.value===previous))el.value=previous;else el.value='';
}
function renderFilterOptions(filters){
 if(!filters)return;
 const before=readFilters();
 fillSelect('#dashBuilding',filters.buildings,'All buildings','id','label');
 fillSelect('#dashUnitType',filters.unitTypes,'All unit types','value','label');
 fillSelect('#dashCustomerType',filters.customerTypes,'All customer types','value','label');
 fillSelect('#dashPaymentMode',filters.paymentModes,'All payment modes','value','label');
 fillSelect('#dashBillStatus',filters.billStatuses,'All bill statuses','value','label');
 const after=readFilters();
 // The first response builds the options only. If a value disappeared from live data, reset it and reload once.
 if(filterOptionsReady&&Object.keys(before).some(k=>before[k]!==after[k])){filterOptionsReady=false;load();return}
 filterOptionsReady=true;
}
function render(data){
 renderFilterOptions(data.filters);
 const s=data.summary||{},period=data.period||{};
 $('#dashboardPeriodLabel').textContent=(period.from||'—')+' – '+(period.to||'—');
 $('#dashboardUpdated').textContent=data.lastUpdated?new Date(data.lastUpdated).toLocaleString(window.Society360I18n?.locale?.()||'en-IN'):'—';
 $('#heroCollected').textContent=money(s.collectedAmount);
 $('#heroOccupancy').textContent=number(s.occupancyRate||0)+'%';
 $('#kpiCustomers').textContent=number(s.totalCustomers);
 $('#kpiCustomersDetail').textContent=number(s.activeCustomers)+' '+t('active')+' · '+number(s.newCustomers)+' '+t('new in period');
 $('#kpiActiveCustomers').textContent=number(s.activeCustomers);
 $('#kpiFlats').textContent=number(s.totalFlats);
 $('#kpiFlatsDetail').textContent=number(s.totalBuildings)+' '+t('buildings')+' · '+number(s.totalWings)+' '+t('wings');
 $('#kpiBilled').textContent=money(s.billedAmount);
 $('#kpiBillsDetail').textContent=number(s.billsCount)+' '+t('valid bills in period');
 $('#kpiCollected').textContent=money(s.collectedAmount);
 $('#kpiCollectionDetail').textContent=number(s.collectionRate||0)+'% '+t('of billed amount in period');
 $('#kpiOutstanding').textContent=money(s.currentOutstanding);
 $('#kpiOverdue').textContent=money(s.overdueAmount);
 $('#kpiOverdueDetail').textContent=number(s.overdueBills)+' '+t('overdue bills');
 $('#kpiOccupancy').textContent=number(s.occupancyRate||0)+'%';
 $('#kpiOccupancyProgress').style.width=Math.max(0,Math.min(100,Number(s.occupancyRate||0)))+'%';
 $('#kpiOccupancyDetail').textContent=number(s.occupiedFlats)+' / '+number(s.totalFlats)+' '+t('active units occupied');
 $('#kpiComplaints').textContent=number(s.openComplaints);
 $('#kpiOperationsDetail').textContent=number(s.insideVisitors)+' '+t('visitors currently inside');
 $('#kpiVisitors').textContent=number(s.insideVisitors);
 $('#kpiParking').textContent=number(s.parkingSlots);
 $('#kpiMigration').textContent=number(s.migrationBatches);
 $('#kpiAssignedParking').textContent=number(s.assignedParkingSlots);
 $('#kpiCustomerDocuments').textContent=number(s.customerDocuments);
 $('#kpiSocietyDocuments').textContent=number(s.societyDocuments);
 $('#kpiNotices').textContent=number(s.publishedNotices);
 $('#kpiNotifications').textContent=number(s.pendingNotifications);
 $('#kpiTickets').textContent=number(s.openTickets);
 $('#kpiSecurityIncidents').textContent=number(s.openSecurityIncidents);
 $('#kpiServiceCharges').textContent=number(s.pendingServiceCharges);
 $('#kpiDishonored').textContent=number(s.dishonoredCheques);
 $('#kpiGuards').textContent=number(s.activeGuards);
 drawTrend(data.trends||[]);
 drawDonut('#dashboardOccupancy',data.occupancy||[],'count','count','units','flats');
 drawDonut('#dashboardPaymentModes',data.paymentModes||[],'amount','amount','collected','collection');
 drawBars('#dashboardBillStatuses',data.billStatuses||[],'count','count','bills');
 drawBars('#dashboardCustomerTypes',data.customerTypes||[],'count','count','customers');
 drawBars('#dashboardUnitTypes',data.unitTypes||[],'count','count','units');
 drawBars('#dashboardComplaintStatuses',data.complaintStatuses||[],'count','count','complaints');
 setStatus((s.totalCustomers+s.totalFlats+s.billsCount)===0?'Dashboard loaded — no matching records for this selection.':'Dashboard data loaded from the database');
}
function drawTrend(rows){
 const root=$('#dashboardTrend');if(!rows.length){root.innerHTML='<div class="dash-empty-state">'+t('No billing or collection records in this period.')+'</div>';return}
 const W=760,H=220,L=48,R=14,T=14,B=31,innerW=W-L-R,innerH=H-T-B;
 const max=Math.max(1,...rows.map(x=>Math.max(Number(x.billed||0),Number(x.collected||0))));
 const x=i=>L+(rows.length===1?innerW/2:i*innerW/(rows.length-1));
 const y=v=>T+innerH-(Number(v||0)/max)*innerH;
 let svg='<svg viewBox="0 0 '+W+' '+H+'" role="img" aria-label="'+t('Monthly billing and collection trend')+'">';
 for(let i=0;i<4;i++){const yy=T+i*innerH/3;svg+='<line class="chart-gridline" x1="'+L+'" y1="'+yy+'" x2="'+(W-R)+'" y2="'+yy+'"/><text class="chart-axis-label" x="'+(L-8)+'" y="'+(yy+4)+'" text-anchor="end">'+shortMoney(max*(1-i/3))+'</text>'}
 for(const [key,color,label] of [['billed','#7968e8','Billed'],['collected','#28b99a','Collected']]){
  const points=rows.map((r,i)=>x(i)+','+y(r[key])).join(' ');
  svg+='<polyline fill="none" stroke="'+color+'" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" points="'+points+'"/>';
  rows.forEach((r,i)=>{const value=Number(r[key]||0);svg+='<circle cx="'+x(i)+'" cy="'+y(value)+'" r="4" fill="'+color+'" stroke="#fff" stroke-width="2"><title>'+t(r.label||r.month)+' · '+t(label)+': '+money(value)+'</title></circle>'});
 }
 rows.forEach((r,i)=>{svg+='<text class="chart-axis-label" x="'+x(i)+'" y="'+(H-8)+'" text-anchor="middle">'+escapeHtml(t(r.label||r.month))+'</text>'});
 svg+='</svg>';root.innerHTML=svg;
}
function shortMoney(v){v=Number(v||0);if(v>=10000000)return '₹'+number(v/10000000)+'Cr';if(v>=100000)return '₹'+number(v/100000)+'L';if(v>=1000)return '₹'+number(v/1000)+'k';return '₹'+number(v)}
function drawDonut(selector,rows,valueKey,detailKey,centerLabel,drillType){
 const root=$(selector);const valid=rows.filter(r=>Number(r[valueKey]||0)>0);const total=valid.reduce((a,r)=>a+Number(r[valueKey]||0),0);
 if(!valid.length||!total){root.innerHTML='<div class="dash-empty-state">'+t('No records for this selection.')+'</div>';return}
 let acc=0;const stops=valid.map((r,i)=>{const start=acc;acc+=Number(r[valueKey]||0)/total*100;return colors[i%colors.length]+' '+start+'% '+acc+'%'}).join(',');
 const center=drillType==='flats'?number(total):drillType==='collection'?money(total):number(total);
 const legend=valid.map((r,i)=>'<button type="button" data-dash-drill="'+drillType+'" data-dash-label="'+escapeAttr(r.label)+'" title="'+escapeAttr(t(r.label)+': '+(drillType==='collection'?money(r[valueKey]):number(r[valueKey])))+'"><i style="background:'+colors[i%colors.length]+'"></i><span class="legend-label">'+escapeHtml(t(r.label))+'</span><b>'+escapeHtml(drillType==='collection'?money(r[valueKey]):number(r[valueKey]))+'</b><small>'+number(Number(r[valueKey]||0)/total*100)+'%</small></button>').join('');
 root.innerHTML='<div class="dash-donut" style="background:conic-gradient('+stops+')"><div class="dash-donut-center"><b>'+escapeHtml(center)+'</b><small>'+t(centerLabel)+'</small></div></div><div class="dash-chart-legend">'+legend+'</div>';
}
function drawBars(selector,rows,valueKey,detailKey,drillType){
 const root=$(selector);const valid=rows.filter(r=>Number(r[valueKey]||0)>=0);if(!valid.length||valid.every(r=>Number(r[valueKey]||0)===0)){root.innerHTML='<div class="dash-empty-state">'+t('No records for this selection.')+'</div>';return}
 const max=Math.max(1,...valid.map(r=>Number(r[valueKey]||0)));
 root.innerHTML=valid.map((r,i)=>{const value=Number(r[valueKey]||0);return '<div class="dash-bar-row"><button type="button" data-dash-drill="'+drillType+'" data-dash-label="'+escapeAttr(r.label)+'" title="'+escapeAttr(t(r.label)+': '+number(value))+'"><span class="dash-bar-label">'+escapeHtml(t(r.label))+'</span><span class="dash-bar-track"><span class="dash-bar-fill" style="display:block;width:'+Math.max(value>0?2:0,value/max*100)+'%;background:'+colors[i%colors.length]+'"></span></span><span class="dash-bar-value">'+number(value)+'</span></button></div>'}).join('');
}
function escapeHtml(v){return String(v??'').replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]))}
function escapeAttr(v){return escapeHtml(v).replace(/'/g,'&#39;')}
const drillColumns={
 customers:[['customer_id','Customer ID'],['customer_code','Customer Code'],['full_name','Customer Name'],['customer_type','Customer Type'],['phone','Mobile'],['email','Email'],['is_active','Active']],
 flats:[['flat_no','Flat'],['wing','Wing'],['building','Building'],['unit_type','Unit type'],['area_sqft','Area'],['occupancy_status','Occupancy'],['owner_name','Owner'],['owner_phone','Phone']],
 units:[['flat_no','Flat'],['wing','Wing'],['building','Building'],['unit_type','Unit type'],['area_sqft','Area'],['occupancy_status','Occupancy'],['owner_name','Owner'],['owner_phone','Phone']],
 bills:[['bill_no','Bill No'],['bill_month','Month'],['flat_no','Flat'],['customer_name','Customer'],['total_amount','Amount'],['paid_amount','Paid'],['balance','Balance'],['due_date','Due'],['status','Status']],
 outstanding:[['bill_no','Bill No'],['bill_month','Month'],['flat_no','Flat'],['customer_name','Customer'],['total_amount','Amount'],['paid_amount','Paid'],['balance','Balance'],['due_date','Due'],['status','Status']],
 overdue:[['bill_no','Bill No'],['bill_month','Month'],['flat_no','Flat'],['customer_name','Customer'],['total_amount','Amount'],['paid_amount','Paid'],['balance','Balance'],['due_date','Due'],['status','Status']],
 collection:[['payment_no','Payment No'],['payment_date','Date'],['flat_no','Flat'],['customer_name','Customer'],['amount','Amount'],['payment_mode','Mode'],['reference_no','Reference']],
 complaints:[['complaint_no','Complaint'],['flat_no','Flat'],['customer_name','Customer'],['category','Category'],['title','Title'],['priority','Priority'],['status','Status'],['created_at','Created']],
 visitors:[['visitor_name','Visitor'],['phone','Phone'],['flat_no','Flat'],['visitor_type','Type'],['purpose','Purpose'],['status','Status'],['entry_time','Entry'],['exit_time','Exit']],
 parking:[['slot_no','Slot'],['slot_type','Type'],['charge','Charge'],['assigned_flat','Assigned Flat'],['customer_name','Customer'],['status','Status']],
 assignedparking:[['slot_no','Slot'],['slot_type','Type'],['charge','Charge'],['assigned_flat','Assigned Flat'],['customer_name','Customer'],['status','Status']]
};
const drillTitles={customers:'Customers',flats:'Properties & units',units:'Unit type distribution',bills:'Billed amount',outstanding:'Current outstanding',overdue:'Overdue amount',collection:'Collections received',complaints:'Open complaints',visitors:'Visitors inside',parking:'Active parking slots',assignedparking:'Assigned parking'};
let activeDrill=null,activeDrillRows=[],drillTrigger=null;
function updateDrillHeader(){if(!activeDrill)return;const f=readFilters();const periodApplies=['bills','collection'].includes(activeDrill.type)||(['complaints','visitors'].includes(activeDrill.type)&&!!activeDrill.label);const periodText=periodApplies?(f.from||'—')+' – '+(f.to||'—'):t('Current snapshot');$('#dashboardDrillTitle').textContent=t(drillTitles[activeDrill.type]||'Record details');$('#dashboardDrillSubtitle').textContent=(activeDrill.label?t('Filtered by')+': '+t(activeDrill.label)+' · ':'')+periodText;$('#dashboardDrillClose')?.setAttribute('aria-label',t('Close'))}
function closeDrilldown(){const modal=$('#dashboardDrillModal');if(modal)modal.hidden=true;activeDrill=null;activeDrillRows=[];if(drillTrigger?.focus)drillTrigger.focus()}
function renderDrillRows(type,rows){
 const cols=drillColumns[type]||drillColumns.flats,wrap=$('#dashboardDrillTableWrap');
 if(!rows.length){wrap.innerHTML='<div class="dash-modal-empty">'+t('No records for this selection.')+'</div>';$('#dashboardDrillCount').textContent='0 '+t('records');return}
 const head='<thead><tr>'+cols.map(c=>'<th>'+escapeHtml(t(c[1]))+'</th>').join('')+'</tr></thead>';
 const body='<tbody>'+rows.map(row=>'<tr>'+cols.map(([key])=>{let value=row[key];if(value===null||value===undefined)value='—';else if(typeof value==='boolean')value=t(value?'Yes':'No');else if(['total_amount','paid_amount','balance','amount','charge'].includes(key))value=money(value);else if(key==='area_sqft')value=number(value);else if(['due_date','payment_date','bill_month'].includes(key)&&value){const d=new Date(value);if(!Number.isNaN(d.getTime()))value=d.toLocaleDateString(window.Society360I18n?.locale?.()||'en-IN')}else if(['created_at','entry_time','exit_time'].includes(key)&&value){const d=new Date(value);if(!Number.isNaN(d.getTime()))value=d.toLocaleString(window.Society360I18n?.locale?.()||'en-IN')}else if(typeof value==='object')value=String(value);return '<td>'+escapeHtml(t(value))+'</td>'}).join('')+'</tr>').join('')+'</tbody>';
 wrap.innerHTML='<table class="dash-modal-table">'+head+body+'</table>';
 $('#dashboardDrillCount').textContent=number(rows.length)+' '+t('records')+(rows.length===250?' · '+t('showing up to 250'):'');
}
async function openDashboardDrilldown(type,label,trigger){
 const kind=type.toLowerCase(),f=readFilters();
 activeDrill={type:kind,label:label||''};activeDrillRows=[];drillTrigger=trigger||document.activeElement;updateDrillHeader();
 $('#dashboardDrillState').textContent=t('Loading records');
 $('#dashboardDrillTableWrap').innerHTML='';$('#dashboardDrillCount').textContent='';
 $('#dashboardDrillModal').hidden=false;$('#dashboardDrillClose').focus();
 try{
  const query=queryString({...f,type:kind,label:label||''});
  const response=await fetch('/api/society-admin/dashboard/drilldown?'+query,{cache:'no-store'});
  const rows=await response.json();
  if(!response.ok)throw new Error(rows.message||t('Records could not be loaded.'));
  activeDrillRows=rows;$('#dashboardDrillState').textContent=rows.length?t('Filtered records from the database'):t('No records for this selection.');
  renderDrillRows(kind,rows);
 }catch(e){$('#dashboardDrillState').textContent=e.message||t('Records could not be loaded.');$('#dashboardDrillTableWrap').innerHTML='';$('#dashboardDrillCount').textContent=''}
}
function navigateDrill(type,label){
 const requested={documents:'BACKOFFICE_DOCUMENT',notifications:'NOTIFICATION_CENTER',tickets:'BACKOFFICE_TICKET',securityincidents:'SEC_INCIDENTS',securityguards:'SEC_GUARDS',servicecharges:'BACKOFFICE_SERVICE',dishonoredcheques:'COL_DISHONORED',migration:'BACKOFFICE_MIGRATION'};
 if(requested[type]&&window.openRequestedModule?.(requested[type]))return;
 const mapping={customers:'customers',flats:'flats',units:'flats',bills:'bills',collection:'collection',outstanding:'bills',overdue:'bills',complaints:'complaints',visitors:'visitors',parking:'parking',assignedparking:'parking',migration:'module-workspace',securityincidents:'security',securityguards:'security'};
 const view=mapping[type]||'module-workspace';
 if(window.societyAdminShow)window.societyAdminShow(view,t(type==='outstanding'||type==='overdue'?'Billing':type));
 if(view==='bills'&&label&&$('#billSearch')){$('#billSearch').value=label;$('#billSearch').dispatchEvent(new Event('input',{bubbles:true}))}
 if(view==='customers'&&label&&$('#caSearchInput')){$('#caSearchInput').value=label;$('#caSearchInput').dispatchEvent(new Event('input',{bubbles:true}))}
 if(view==='flats'&&label&&$('#flatSearch')){$('#flatSearch').value=label;$('#flatSearch').dispatchEvent(new Event('input',{bubbles:true}))}
}
function drill(type,label,trigger){
 const kind=String(type||'').toLowerCase();
 if(drillColumns[kind]){openDashboardDrilldown(kind,label,trigger);return}
 navigateDrill(kind,label);
}
function init(){
 if(!$('#dashboardKpis'))return;
 setDefaultDates('month');
 $('#dashPreset').addEventListener('change',e=>{if(e.target.value!=='custom'){setDefaultDates(e.target.value);load()}});
 $('#dashApply').addEventListener('click',load);
 $('#dashboardRefresh').addEventListener('click',load);
 ['#dashFrom','#dashTo'].forEach(id=>$(id).addEventListener('change',()=>{if($('#dashPreset').value!=='custom')$('#dashPreset').value='custom'}));
 $('#dashReset').addEventListener('click',()=>{['#dashBuilding','#dashUnitType','#dashCustomerType','#dashPaymentMode','#dashBillStatus'].forEach(id=>$(id).value='');$('#dashPreset').value='month';setDefaultDates('month');load()});
 document.addEventListener('click',e=>{
  if(e.target.closest('[data-dash-modal-close]')||e.target.closest('#dashboardDrillClose')){closeDrilldown();return}
  if(e.target.closest('#dashboardDrillOpenModule')){const d=activeDrill;closeDrilldown();if(d)navigateDrill(d.type,d.label);return}
  const el=e.target.closest('[data-dash-drill]');if(el)drill(el.dataset.dashDrill,el.dataset.dashLabel||'',el)
 });
 document.addEventListener('keydown',e=>{if(e.key==='Escape'&&$('#dashboardDrillModal')&&!$('#dashboardDrillModal').hidden)closeDrilldown()});
 window.addEventListener('society360-language-changed',()=>{if(lastData)render(lastData);if(activeDrill&&!$('#dashboardDrillModal').hidden){updateDrillHeader();renderDrillRows(activeDrill.type,activeDrillRows);$('#dashboardDrillState').textContent=activeDrillRows.length?t('Filtered records from the database'):t('No records for this selection.')}});
 load();
}
window.societyDashboard={load,refresh:load};
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',init,{once:true});else init();
})();