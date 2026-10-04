(() => {
  const esc = v => String(v ?? '—').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const money = v => '₹' + Number(v || 0).toLocaleString('en-IN',{minimumFractionDigits:2,maximumFractionDigits:2});
  const dateText = v => {
    if (!v) return '—';
    const d = new Date(v);
    return Number.isNaN(d.getTime()) ? String(v) : d.toLocaleDateString('en-IN',{day:'2-digit',month:'short',year:'numeric'});
  };
  const dateTimeText = v => {
    if (!v) return '—';
    const d = new Date(v);
    return Number.isNaN(d.getTime()) ? String(v) : d.toLocaleString('en-IN',{day:'2-digit',month:'short',year:'numeric',hour:'2-digit',minute:'2-digit'});
  };

  let currentLanguage = 'en', consumerId = null, account = null, timers = [], initialized = false;
  const t = k => window.Society360I18n?.translateText(k) || k;
  const q = s => document.querySelector(s);
  const qa = s => [...document.querySelectorAll(s)];
  const currentLang = () => window.Society360I18n?.current || localStorage.getItem('society360-language') || 'en';

  function applyLanguage(){
    currentLanguage = ['en','mr','gu','kn','te'].includes(currentLang()) ? currentLang() : 'en';
    qa('[data-ca-i18n]').forEach(el => el.textContent = t(el.dataset.caI18n));
    qa('[data-ca-placeholder]').forEach(el => el.placeholder = t(el.dataset.caPlaceholder));
    const search=q('#caSearchInput'); if(search) search.placeholder=[t('Consumer ID'),t('Name'),t('Flat Number'),t('Mobile Number'),t('Email')].join(' / ');
    if(account) { renderAccount(); qa('.ca-tabs button').forEach(b=>b.classList.toggle('active',b.dataset.caTab===activeTab)); if(activeTab==='flats')renderFlats(account.profile||[]); else if(sectionMap[activeTab])loadSection(activeTab,true); }
    qa('.ca-table-search').forEach(el=>{ if(el.dataset.caPlaceholder) el.placeholder=t(el.dataset.caPlaceholder); });
  }

  async function api(url){
    const r=await fetch(url,{cache:'no-store',credentials:'same-origin'});
    if(r.status===401){location.href='/login.html';throw new Error('AUTH_REQUIRED');}
    if(r.status===403)throw new Error('FORBIDDEN');
    if(!r.ok){let msg='Request failed';try{msg=(await r.json()).message||msg}catch{}throw new Error(msg);}
    return r.json();
  }
  function debounce(fn,ms=240){let timer;return(...args)=>{clearTimeout(timer);timer=setTimeout(()=>fn(...args),ms)}}
  function show(el,on){if(!el)return;el.classList.toggle('hidden',!on)}
  function statusText(v){return t(String(v||'').trim())}
  function dueClass(v){if(!v)return '';const d=new Date(v);if(Number.isNaN(d.getTime()))return '';const today=new Date();today.setHours(0,0,0,0);d.setHours(0,0,0,0);return d<today?'due-overdue':d.getTime()===today.getTime()?'due-today':'due-upcoming'}

  let activeTab='overview';
  const sectionState={};
  const sectionMap={
    billing:{table:'caBillingTable',pager:'caBillingPager',search:'caSearchBilling'},
    payments:{table:'caPaymentsTable',pager:'caPaymentsPager',search:'caSearchPayments'},
    dues:{table:'caDuesTable',pager:'caDuesPager',search:null},
    service:{table:'caServiceTable',pager:'caServicePager',search:'caSearchService'},
    complaints:{table:'caComplaintsTable',pager:'caComplaintsPager',search:'caSearchComplaints'},
    interactions:{table:'caInteractionsTable',pager:'caInteractionsPager',search:'caSearchInteractions'},
    adjustments:{table:'caAdjustmentsTable',pager:'caAdjustmentsPager',search:'caSearchAdjustments'},
    documents:{table:'caDocumentsTable',pager:'caDocumentsPager',search:'caSearchDocuments'},
    timeline:{table:'caTimelineTable',pager:'caTimelinePager',search:'caSearchTimeline'}
  };

  function profilePrimary(){return (account?.profile||[]).find(x=>x.is_primary) || account?.profile?.[0] || {}}
  function renderAccount(){
    const p=profilePrimary(), c=account?.summary||{};
    const first=String(p.full_name||'C').trim().split(/\s+/).map(x=>x[0]).join('').slice(0,2).toUpperCase()||'C';
    q('#caAvatar').textContent=first;q('#caName').textContent=p.full_name||'—';q('#caConsumerId').textContent='CON-'+String(p.consumer_id||consumerId).padStart(8,'0');q('#caStatus').textContent=statusText(p.account_status);
    q('#caPhone').textContent=p.phone||'—';q('#caEmail').textContent=p.email||'—';q('#caPrimaryFlat').textContent=p.flat_no||'—';q('#caPrimaryWing').textContent=p.wing||'';
    q('#caOutstanding').textContent=money(c.net_outstanding??c.current_outstanding);q('#caOverdueHint').textContent=money(c.overdue_amount||0)+' · '+Number(c.overdue_days||0)+' '+t('Overdue Days');
    q('#caCurrentBill').textContent=money(c.current_bill_amount);q('#caLatestBill').textContent=(c.latest_bill_no||'—')+' · '+dateText(c.latest_bill_date);
    q('#caLastPayment').textContent=money(c.last_payment_amount);q('#caLastPaymentDate').textContent=dateTimeText(c.last_payment_date);
    q('#caOpenComplaints').textContent=c.open_complaints||0;q('#caOpenServices').textContent=c.open_service_requests||0;
    const fields=[['Consumer ID','CON-'+String(p.consumer_id||consumerId).padStart(8,'0')],['Customer Type',p.customer_type],['Mobile Number',p.phone],['Alternate Mobile',p.alternate_phone],['Email',p.email],['Address',p.address_line],['Account Status',p.account_status],['Created Date',dateTimeText(p.created_at)],['Society',p.society_name]];
    q('#caConsumerInfo').innerHTML=fields.map(([k,v])=>'<div class="ca-info-item"><small>'+esc(t(k))+'</small><strong>'+esc(v)+'</strong></div>').join('');
    const dueFields=[['Current Outstanding',money(c.current_outstanding)],['Current Bill',money(c.current_bill_amount)],['Previous Outstanding',money(c.previous_outstanding)],['Adjustments',money(c.adjustments)],['Payments Received',money(c.payments_received)],['Net Outstanding',money(c.net_outstanding)],['Due Date',dateText(c.due_date)],['Overdue Amount',money(c.overdue_amount)],['Overdue Days',c.overdue_days||0],['Last Payment',money(c.last_payment_amount)]];
    q('#caDueSummary').innerHTML=dueFields.map(([k,v])=>'<div class="item '+(k==='Overdue Amount'?'danger':'')+'"><small>'+esc(t(k))+'</small><strong>'+esc(v)+'</strong></div>').join('');
    const flatRows=account?.profile||[];
    if(q('#caFlatsTable') && !q('#caFlatsTable')._tab){renderFlats(flatRows)} else if(q('#caFlatsTable')?._tab){q('#caFlatsTable')._tab.setData(flatRows)}
    renderDuesCards(c);
  }

  function renderFlats(rows){
    const el=q('#caFlatsTable'); if(!el)return;
    if(el._tab){el._tab.destroy()}
    el._tab=new Tabulator(el,{data:rows,layout:'fitDataStretch',responsiveLayout:'collapse',placeholder:t('No records found'),columns:[
      {title:t('Flat'),field:'flat_no',headerFilter:'input'},{title:t('Wing'),field:'wing',headerFilter:'input'},{title:t('Building'),field:'building',headerFilter:'input'},
      {title:t('Area Sq.Ft.'),field:'area_sqft',formatter:c=>c.getValue()?Number(c.getValue()).toLocaleString('en-IN'):'—'},
      {title:t('Relation'),field:'relation_type',headerFilter:'input',formatter:c=>statusText(c.getValue())},
      {title:t('Occupancy'),field:'occupancy_status',headerFilter:'input',formatter:c=>statusText(c.getValue())},
      {title:t('Primary'),field:'is_primary',formatter:c=>c.getValue()?'✓':'—'}
    ]});
  }

  function renderDuesCards(c){
    const el=q('#caDuesCards');if(!el)return;
    el.innerHTML=[['Net Outstanding',money(c.net_outstanding)],['Due Date',dateText(c.due_date)],['Overdue Amount',money(c.overdue_amount)],['Overdue Days',c.overdue_days||0]].map((x,i)=>'<div class="ca-dues-card '+(i>1&&Number(c.overdue_amount||0)>0?'danger':'')+'"><small>'+esc(t(x[0]))+'</small><strong>'+esc(x[1])+'</strong></div>').join('');
  }

  function columnsFor(section){
    const eyeIcon='<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M2.2 12s3.5-6 9.8-6 9.8 6 9.8 6-3.5 6-9.8 6-9.8-6-9.8-6Z" fill="none" stroke="currentColor" stroke-width="1.8"/><circle cx="12" cy="12" r="2.6" fill="currentColor"/></svg>';const recordIcon='<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6 3h9l3 3v15H6z" fill="none" stroke="currentColor" stroke-width="1.8"/><path d="M14 3v4h4M9 12h6M9 16h6" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/></svg>';const actionButton=(icon,label)=>'<button type="button" class="ca-row-view" title="'+esc(label)+'" aria-label="'+esc(label)+'">'+icon+'</button>';const details={title:t('Details'),field:'__details',width:90,hozAlign:'center',formatter:()=>actionButton(recordIcon,t('Details')),cellClick:(e,cell)=>openRecord(cell.getRow().getData())};const billAction={title:t('View'),field:'__viewBill',width:72,hozAlign:'center',formatter:()=>actionButton(eyeIcon,t('View')),cellClick:(e,cell)=>openBill(cell.getRow().getData())};const receiptAction={title:t('View'),field:'__viewReceipt',width:72,hozAlign:'center',formatter:()=>actionButton(eyeIcon,t('View')),cellClick:(e,cell)=>openReceipt(cell.getRow().getData())};
    const cols={
      billing:[{title:t('Bill No'),field:'bill_no',headerFilter:'input'},{title:t('Bill Date'),field:'bill_date',formatter:c=>dateText(c.getValue())},{title:t('Billing Period'),field:'billing_period',formatter:c=>dateText(c.getValue())},{title:t('Previous Balance'),field:'previous_balance',formatter:c=>money(c.getValue())},{title:t('Current Bill'),field:'current_bill',formatter:c=>money(c.getValue())},{title:t('Adjustments'),field:'adjustments',formatter:c=>money(c.getValue())},{title:t('Payments'),field:'payments',formatter:c=>money(c.getValue())},{title:t('Net Amount'),field:'net_amount',formatter:c=>money(c.getValue())},{title:t('Due Date'),field:'due_date',formatter:c=>'<span class="'+dueClass(c.getValue())+'">'+esc(dateText(c.getValue()))+'</span>'},{title:t('Outstanding'),field:'outstanding',formatter:c=>money(c.getValue())},{title:t('Status'),field:'status',formatter:c=>statusText(c.getValue())},billAction],
      payments:[{title:t('Receipt No'),field:'receipt_no',headerFilter:'input'},{title:t('Payment No'),field:'payment_no',headerFilter:'input'},{title:t('Payment Date'),field:'payment_date',formatter:c=>dateTimeText(c.getValue())},{title:t('Payment Mode'),field:'payment_mode',formatter:c=>statusText(c.getValue())},{title:t('Reference No'),field:'reference_no'},{title:t('Amount'),field:'amount',formatter:c=>money(c.getValue())},{title:t('Against Bill'),field:'against_bill'},{title:t('Collected By'),field:'collected_by'},{title:t('Status'),field:'status',formatter:c=>statusText(c.getValue())},receiptAction],
      dues:[{title:t('Bill No'),field:'bill_no',headerFilter:'input'},{title:t('Bill Date'),field:'bill_date',formatter:c=>dateText(c.getValue())},{title:t('Due Date'),field:'due_date',formatter:c=>'<span class="'+dueClass(c.getValue())+'">'+esc(dateText(c.getValue()))+'</span>'},{title:t('Amount'),field:'total_amount',formatter:c=>money(c.getValue())},{title:t('Payments'),field:'paid_amount',formatter:c=>money(c.getValue())},{title:t('Outstanding'),field:'outstanding',formatter:c=>money(c.getValue())},{title:t('Overdue Days'),field:'overdue_days'},{title:t('Status'),field:'status',formatter:c=>statusText(c.getValue())},details],
      service:[{title:t('Activity No'),field:'service_no'},{title:t('Date'),field:'performed_at',formatter:c=>dateTimeText(c.getValue())},{title:t('Activity Type'),field:'activity_type',formatter:c=>statusText(c.getValue())},{title:t('Type'),field:'service_type',formatter:c=>statusText(c.getValue())},{title:t('Field'),field:'field_name'},{title:t('Old Value'),field:'old_value'},{title:t('New Value'),field:'new_value'},{title:t('Description'),field:'description'},{title:t('Status'),field:'status',formatter:c=>statusText(c.getValue())},{title:t('Changed By'),field:'changed_by'},{title:t('Changed At'),field:'changed_at',formatter:c=>dateTimeText(c.getValue())},{title:t('Assigned To'),field:'assigned_to'},{title:t('Resolution'),field:'resolution'},{title:t('Closed Date'),field:'closed_date',formatter:c=>dateTimeText(c.getValue())},details],
      complaints:[{title:t('Complaint No'),field:'complaint_no'},{title:t('Complaint Date'),field:'complaint_date',formatter:c=>dateTimeText(c.getValue())},{title:t('Complaint Type'),field:'complaint_type'},{title:t('Subject'),field:'subject'},{title:t('Priority'),field:'priority',formatter:c=>statusText(c.getValue())},{title:t('Status'),field:'status',formatter:c=>statusText(c.getValue())},{title:t('Assigned To'),field:'assigned_to'},{title:t('Resolution'),field:'resolution'},{title:t('Resolved Date'),field:'resolved_date',formatter:c=>dateTimeText(c.getValue())},details],
      interactions:[{title:t('Interaction Date'),field:'interaction_date',formatter:c=>dateTimeText(c.getValue())},{title:t('Interaction Type'),field:'interaction_type',formatter:c=>statusText(c.getValue())},{title:t('Subject'),field:'subject'},{title:t('Description'),field:'description'},{title:t('Employee / User'),field:'employee_user'},{title:t('Outcome'),field:'outcome'},{title:t('Follow-up Date'),field:'follow_up_date',formatter:c=>dateText(c.getValue())},{title:t('Remarks'),field:'remarks'},details],
      adjustments:[{title:t('Adjustment No'),field:'adjustment_id'},{title:t('Adjustment Date'),field:'adjustment_date',formatter:c=>dateTimeText(c.getValue())},{title:t('Adjustment Type'),field:'adjustment_type',formatter:c=>statusText(c.getValue())},{title:t('Reference Bill'),field:'reference_bill'},{title:t('Amount'),field:'amount',formatter:c=>money(c.getValue())},{title:t('Reason'),field:'reason'},{title:t('Approved By'),field:'approved_by'},{title:t('Status'),field:'status',formatter:c=>statusText(c.getValue())},{title:t('Remarks'),field:'remarks'},details],
      documents:[{title:t('Document Name'),field:'document_name'},{title:t('Document Type'),field:'document_type',formatter:c=>statusText(c.getValue())},{title:t('Uploaded Date'),field:'uploaded_date',formatter:c=>dateTimeText(c.getValue())},{title:t('Uploaded By'),field:'uploaded_by'},{title:t('Status'),field:'status',formatter:c=>statusText(c.getValue())},details],
      timeline:[{title:t('Event Date'),field:'event_at',formatter:c=>dateTimeText(c.getValue())},{title:t('Event Type'),field:'event_type',formatter:c=>statusText(c.getValue())},{title:t('Event'),field:'event_title'},{title:t('Description'),field:'event_description'},{title:t('Reference No'),field:'reference_no'},{title:t('Field'),field:'field_name'},{title:t('Old Value'),field:'old_value'},{title:t('New Value'),field:'new_value'},{title:t('Amount'),field:'amount',formatter:c=>c.getValue()==null?'—':money(c.getValue())},{title:t('Status'),field:'status',formatter:c=>statusText(c.getValue())},{title:t('Changed By'),field:'changed_by'},details]
    };
    return cols[section]||[];
  }

  function printPage(title,html){
    const w=window.open('about:blank','_blank','noopener,noreferrer,width=980,height=800');
    if(!w){alert(t('Please allow pop-ups to view this document.'));return;}
    w.document.write('<!doctype html><html><head><meta charset="utf-8"><title>'+esc(title)+'</title><style>body{font-family:Arial,sans-serif;margin:32px;color:#172033}h1{margin:0 0 4px;font-size:24px}h2{margin:26px 0 10px;font-size:16px}.head{display:flex;justify-content:space-between;border-bottom:2px solid #172033;padding-bottom:16px}.grid{display:grid;grid-template-columns:repeat(3,1fr);gap:12px;margin:18px 0}.item{border:1px solid #dfe4ec;border-radius:8px;padding:10px}.item small{display:block;color:#657084;margin-bottom:4px}.item strong{display:block}.amount{text-align:right;font-weight:700}.total{font-size:18px}.actions{margin:20px 0}button{padding:8px 14px;border:1px solid #ccd3df;background:#fff;border-radius:6px;cursor:pointer}@media print{.actions{display:none}body{margin:12mm}}</style></head><body>'+html+'<div class="actions"><button onclick="window.print()">'+esc(t('Print'))+'</button></div></body></html>');w.document.close();w.focus();
  }
  async function openBill(row){
    const w=window.open('about:blank','_blank','noopener,noreferrer,width=980,height=800');
    if(!w){alert(t('Please allow pop-ups to view this document.'));return;}
    try{
      const x=await api('/api/customer-account/'+consumerId+'/bill/'+row.bill_id);const b=x.bill,c=x.consumer;
      const items=x.line_items||[];const lineRows=items.map(i=>'<tr><td>'+esc(i.description)+'</td><td class="amount">'+esc(i.quantity)+'</td><td class="amount">'+money(i.rate)+'</td><td class="amount">'+money(i.amount)+'</td></tr>').join('');
      const extra=[Number(b.tax_amount)>0?'<tr><td>'+esc(t('Tax'))+'</td><td></td><td></td><td class="amount">'+money(b.tax_amount)+'</td></tr>':'',Number(b.rebate_amount)>0?'<tr><td>'+esc(t('Rebate'))+'</td><td></td><td></td><td class="amount">-'+money(b.rebate_amount)+'</td></tr>':'',Number(b.dpc_amount)>0?'<tr><td>'+esc(t('Late Fee / DPC'))+'</td><td></td><td></td><td class="amount">'+money(b.dpc_amount)+'</td></tr>':''].join('');
      const html='<div class="head"><div><h1>'+esc(t('Bill'))+'</h1><div>'+esc(b.bill_no)+'</div></div><div>'+esc(c.consumer_name)+'</div></div><h2>'+esc(t('Consumer Information'))+'</h2><div class="grid">'+[['Consumer Name',c.consumer_name],['Consumer / Account Number',c.account_no||('CON-'+c.consumer_id)],['Flat / House Number',c.flat_no],['Address',c.address],['Billing Period',dateText(b.billing_period)],['Bill Number',b.bill_no],['Bill Date',dateText(b.bill_date)],['Due Date',dateText(b.due_date)],['Payment Status',statusText(b.status)]].map(a=>'<div class="item"><small>'+esc(t(a[0]))+'</small><strong>'+esc(a[1]||'—')+'</strong></div>').join('')+'</div><h2>'+esc(t('Amount Details'))+'</h2><table width="100%" cellspacing="0" cellpadding="8" border="1"><thead><tr><th>'+esc(t('Charge'))+'</th><th>'+esc(t('Qty'))+'</th><th>'+esc(t('Rate'))+'</th><th>Amount</th></tr></thead><tbody>'+lineRows+extra+'</tbody></table><div class="grid"><div class="item"><small>'+esc(t('Previous Outstanding'))+'</small><strong>'+money(x.previous_outstanding)+'</strong></div><div class="item"><small>'+esc(t('Total Bill Amount'))+'</small><strong class="total">'+money(b.total_amount)+'</strong></div><div class="item"><small>'+esc(t('Paid Amount'))+'</small><strong>'+money(b.paid_amount)+'</strong></div><div class="item"><small>'+esc(t('Remaining Due'))+'</small><strong class="total">'+money(b.remaining_due)+'</strong></div></div>';
      w.document.write('<!doctype html><html><head><meta charset="utf-8"><title>'+esc(t('Bill'))+'</title><style>body{font-family:Arial,sans-serif;margin:32px;color:#172033}h1{margin:0 0 4px;font-size:24px}h2{margin:26px 0 10px;font-size:16px}.head{display:flex;justify-content:space-between;border-bottom:2px solid #172033;padding-bottom:16px}.grid{display:grid;grid-template-columns:repeat(3,1fr);gap:12px;margin:18px 0}.item{border:1px solid #dfe4ec;border-radius:8px;padding:10px}.item small{display:block;color:#657084;margin-bottom:4px}.item strong{display:block}.amount{text-align:right}.total{font-size:18px}@media print{body{margin:12mm}}</style></head><body>'+html+'<div class="actions"><button onclick="window.print()">'+esc(t('Print'))+'</button></div></body></html>');w.document.close();w.focus();
    }catch(e){w.close();alert(e.message||t('Request failed'))}
  }
  async function openReceipt(row){
    const w=window.open('about:blank','_blank','noopener,noreferrer,width=980,height=800');
    if(!w){alert(t('Please allow pop-ups to view this document.'));return;}
    try{
      const x=await api('/api/customer-account/'+consumerId+'/receipt/'+row.payment_id);const r=x.receipt,c=x.consumer;const bills=(x.related_bills||[]).map(v=>v.bill_no+' ('+dateText(v.billing_period)+')').join(', ');
      const html='<div class="head"><div><h1>'+esc(t('Receipt'))+'</h1><div>'+esc(r.receipt_no||r.payment_no)+'</div></div><div>'+esc(c.consumer_name)+'</div></div><h2>'+esc(t('Consumer Information'))+'</h2><div class="grid">'+[['Consumer Name',c.consumer_name],['Flat / House Number',c.flat_no],['Address',c.address],['Consumer / Account Number',c.account_no||('CON-'+c.consumer_id)],['Receipt Number',r.receipt_no],['Payment Date / Time',dateTimeText(r.payment_date)],['Payment Amount',money(r.amount)],['Payment Method',r.payment_mode],['Transaction / Reference Number',r.reference_no],['Related Bill Number',bills],['Previous Due',money(r.previous_due)],['Amount Paid',money(r.amount)],['Remaining Due',money(r.remaining_due)],['Payment Status',statusText(r.status)],['Collector / Channel',x.collector||r.payment_mode],['Remarks',r.remarks]].map(a=>'<div class="item"><small>'+esc(t(a[0]))+'</small><strong>'+esc(a[1]||'—')+'</strong></div>').join('')+'</div>';
      w.document.write('<!doctype html><html><head><meta charset="utf-8"><title>'+esc(t('Receipt'))+'</title><style>body{font-family:Arial,sans-serif;margin:32px;color:#172033}h1{margin:0 0 4px;font-size:24px}h2{margin:26px 0 10px;font-size:16px}.head{display:flex;justify-content:space-between;border-bottom:2px solid #172033;padding-bottom:16px}.grid{display:grid;grid-template-columns:repeat(3,1fr);gap:12px;margin:18px 0}.item{border:1px solid #dfe4ec;border-radius:8px;padding:10px}.item small{display:block;color:#657084;margin-bottom:4px}.item strong{display:block}@media print{body{margin:12mm}}</style></head><body>'+html+'<div class="actions"><button onclick="window.print()">'+esc(t('Print'))+'</button></div></body></html>');w.document.close();w.focus();
    }catch(e){w.close();alert(e.message||t('Request failed'))}
  }

  function openRecord(row){
    const modal=q('#caRecordModal');if(!modal)return;
    q('#caModalTitle').textContent=row.bill_no||row.payment_no||row.complaint_no||row.service_no||row.event_title||row.document_name||row.adjustment_id||t('Account Record');
    const keys=Object.keys(row).filter(k=>k!=='__details');
    q('#caModalBody').innerHTML=keys.map(k=>'<div class="ca-modal-item"><small>'+esc(t(keyLabel(k)))+'</small><div>'+esc(formatModalValue(k,row[k]))+'</div></div>').join('');
    modal.classList.remove('hidden');
  }
  function keyLabel(k){
    const map={bill_no:'Bill No',bill_date:'Bill Date',billing_period:'Billing Period',previous_balance:'Previous Balance',current_bill:'Current Bill',adjustments:'Adjustments',payments:'Payments',net_amount:'Net Amount',due_date:'Due Date',outstanding:'Outstanding',payment_no:'Payment No',receipt_no:'Receipt No',payment_date:'Payment Date',payment_mode:'Payment Mode',reference_no:'Reference No',amount:'Amount',against_bill:'Against Bill',collected_by:'Collected By',service_no:'Service / Request No',performed_at:'Date',service_type:'Type',activity_type:'Activity Type',field_name:'Field',old_value:'Old Value',new_value:'New Value',changed_by:'Changed By',changed_at:'Changed At',category:'Category',description:'Description',status:'Status',assigned_to:'Assigned To',resolution:'Resolution',closed_date:'Closed Date',complaint_no:'Complaint No',complaint_date:'Complaint Date',complaint_type:'Complaint Type',subject:'Subject',priority:'Priority',resolved_date:'Resolved Date',interaction_date:'Interaction Date',interaction_type:'Interaction Type',employee_user:'Employee / User',outcome:'Outcome',follow_up_date:'Follow-up Date',remarks:'Remarks',adjustment_id:'Adjustment No',adjustment_date:'Adjustment Date',adjustment_type:'Adjustment Type',reference_bill:'Reference Bill',reason:'Reason',approved_by:'Approved By',document_name:'Document Name',document_type:'Document Type',uploaded_date:'Uploaded Date',uploaded_by:'Uploaded By',event_at:'Event Date',event_type:'Event Type',event_title:'Event',event_description:'Description'};
    return map[k]||k.replaceAll('_',' ');
  }
  function formatModalValue(k,v){if(v==null||v==='')return '—';if(['amount','previous_balance','current_bill','adjustments','payments','net_amount','outstanding','total_amount','paid_amount'].includes(k))return money(v);if(k.includes('date')||k.endsWith('_at')||k==='created_at')return k==='created_at'?dateTimeText(v):dateText(v);return statusText(v)}

  async function loadSection(section,reset=false){
    if(!consumerId||!sectionMap[section])return;
    const st=sectionState[section] ||= {page:1,size:15,search:'',loaded:false};
    if(reset)st.page=1;
    const cfg=sectionMap[section];
    const url='/api/customer-account/'+consumerId+'/section/'+section+'?page='+st.page+'&pageSize='+st.size+'&search='+encodeURIComponent(st.search);
    const response=await api(url);const data=response.rows||[];st.total=Number(response.total||0);st.loaded=true;
    const el=q('#'+cfg.table);if(!el)return;
    if(el._tab){el._tab.destroy()}
    el._tab=new Tabulator(el,{data,layout:'fitDataStretch',responsiveLayout:'collapse',placeholder:t('No records found'),height:'auto',columns:columnsFor(section)});
    renderPager(section);
  }
  function renderPager(section){
    const cfg=sectionMap[section],st=sectionState[section];const el=q('#'+cfg.pager);if(!el)return;
    const pages=Math.max(1,Math.ceil((st.total||0)/st.size));
    el.className='ca-pager';el.innerHTML='<span>'+esc(t('Page'))+' '+st.page+' '+esc(t('of'))+' '+pages+' · '+st.total+' '+esc(t('rows'))+'</span><div><button type="button" data-pager-prev>‹</button><button type="button" data-pager-next>›</button></div>';
    const prev=el.querySelector('[data-pager-prev]'),next=el.querySelector('[data-pager-next]');prev.disabled=st.page<=1;next.disabled=st.page>=pages;
    prev.onclick=()=>{st.page--;loadSection(section)};next.onclick=()=>{st.page++;loadSection(section)};
  }

  function resetSections(){
    Object.keys(sectionState).forEach(k=>{sectionState[k]={page:1,size:15,search:'',loaded:false}});
    qa('.ca-panel').forEach(p=>p.classList.toggle('active',p.dataset.caPanel==='overview'));
    qa('#caTabs button').forEach(b=>b.classList.toggle('active',b.dataset.caTab==='overview'));
    activeTab='overview';
  }

  async function selectConsumer(id){
    consumerId=Number(id);account=null;resetSections();show(q('#caSearchResults'),false);q('#caEmpty').classList.add('hidden');q('#caAccount').classList.remove('hidden');
    q('#caConsumerInfo').innerHTML='<div class="ca-info-item"><strong>'+esc(t('Loading'))+'…</strong></div>';
    try{account=await api('/api/customer-account/'+consumerId);renderAccount();await loadSection('dues',true)}catch(e){q('#caAccount').classList.add('hidden');q('#caEmpty').classList.remove('hidden');q('#caEmpty p').textContent=e.message}
  }

  const searchConsumers=debounce(async()=>{
    const term=q('#caSearchInput')?.value.trim()||'';show(q('#caSearchResults'),false);
    if(term.length<1)return;
    try{
      const rows=await api('/api/customer-account/search?q='+encodeURIComponent(term)+'&limit=20');
      const box=q('#caSearchResults');
      if(!rows.length){box.innerHTML='<div class="ca-empty" style="border:0;padding:20px"><strong>'+esc(t('No matching consumers found'))+'</strong></div>';show(box,true);return}
      box.innerHTML=rows.map(r=>'<div class="ca-result" data-consumer="'+esc(r.consumer_id)+'"><div><small>'+esc(t('Consumer ID'))+'</small><strong>CON-'+esc(String(r.consumer_id).padStart(8,'0'))+'</strong></div><div><small>'+esc(t('Name'))+'</small><strong>'+esc(r.full_name)+'</strong></div><div><small>'+esc(t('Flat Number'))+'</small><strong>'+esc(r.flat_no||'—')+'</strong></div><div><small>'+esc(t('Wing'))+'</small><strong>'+esc(r.wing||'—')+'</strong></div><div><small>'+esc(t('Mobile Number'))+'</small><strong>'+esc(r.phone||'—')+'</strong></div><div><small>'+esc(t('Email'))+'</small><strong>'+esc(r.email||'—')+'</strong></div><div><span class="status">'+esc(statusText(r.account_status))+'</span></div></div>').join('');
      show(box,true);box.querySelectorAll('.ca-result').forEach(x=>x.onclick=()=>selectConsumer(x.dataset.consumer));
    }catch(e){console.error(e)}
  },240);

  function showTab(tab){
    activeTab=tab;qa('#caTabs button').forEach(b=>b.classList.toggle('active',b.dataset.caTab===tab));qa('.ca-panel').forEach(p=>p.classList.toggle('active',p.dataset.caPanel===tab));
    if(tab==='flats')renderFlats(account?.profile||[]);
    if(sectionMap[tab] && !sectionState[tab]?.loaded)loadSection(tab,true);
    if(tab==='dues')loadSection('dues',true);
    setTimeout(()=>{qa('.ca-panel.active .tabulator').forEach(()=>{})},30);
  }

  function bindSearchFields(){
    q('#caSearchInput')?.addEventListener('input',searchConsumers);
    q('#caClearSearch')?.addEventListener('click',()=>{q('#caSearchInput').value='';show(q('#caSearchResults'),false);q('#caSearchInput').focus()});
    qa('.ca-table-search').forEach(input=>{const section=Object.keys(sectionMap).find(k=>sectionMap[k].search===input.id);if(section)input.addEventListener('input',debounce(()=>{sectionState[section].search=input.value.trim();sectionState[section].page=1;loadSection(section)},260))});
    qa('#caTabs button').forEach(b=>b.addEventListener('click',()=>showTab(b.dataset.caTab)));
    q('#caModalClose')?.addEventListener('click',()=>q('#caRecordModal').classList.add('hidden'));
    q('#caRecordModal')?.addEventListener('click',e=>{if(e.target.id==='caRecordModal')e.currentTarget.classList.add('hidden')});
    document.addEventListener('keydown',e=>{if(e.key==='Escape')q('#caRecordModal')?.classList.add('hidden')});
    document.addEventListener('click',e=>{if(!e.target.closest('.ca-search-card'))show(q('#caSearchResults'),false)});
  }

  function init(){
    if(initialized)return;initialized=true;currentLanguage=currentLang();bindSearchFields();applyLanguage();
    window.addEventListener('society360-language-changed',applyLanguage);
    const role=sessionStorage.getItem('society360-role')||'';
    if(role==='RESIDENT'){q('#caSearchInput')?.closest('.ca-search-card')?.classList.add('hidden');selectMine()}
  }
  async function selectMine(){try{const data=await api('/api/customer-account/me');consumerId=data.consumerId;account=data;resetSections();q('#caEmpty').classList.add('hidden');q('#caAccount').classList.remove('hidden');renderAccount()}catch(e){console.error(e)}}

  window.customerAccount360={init,selectConsumer,refreshLanguage:applyLanguage};
  window.setTimeout(()=>init(),0);
})();