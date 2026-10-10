(() => {
  const $ = s => document.querySelector(s);
  const t = k => window.Society360I18n?.translateText(k) || k;
  let runId = 0;
  let propertyTypes = [];
  let chargeTypes = [];

  async function api(url, options) {
    const r = await fetch(url, { cache: 'no-store', ...options });
    if (r.status === 401) { location.href = '/login.html'; throw new Error('AUTH_REQUIRED'); }
    const d = await r.json().catch(() => ({}));
    if (!r.ok) throw new Error(d.message || t('Billing could not be completed.'));
    return d;
  }

  const money = v => '₹' + Number(v || 0).toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  const dateToday = () => new Date().toISOString().slice(0,10);

  function table(id, data, columns) {
    const el = $(id); if (!el || !window.Tabulator) return;
    if (el._tab) el._tab.destroy();
    el._tab = new Tabulator(el, {
      data, layout:'fitColumns', height:'430px', pagination:true, paginationSize:15,
      headerFilterPlaceholder:t('Search'),
      columns:columns.map(c=>({...c,title:t(c.title)}))
    });
  }

  function bindChargeTypeOptions() {
    const select = $('#billingChargeType');
    if (!select) return;
    select.innerHTML = chargeTypes.map(x =>
      '<option value="' + x.charge_type_id + '">' +
      t(x.charge_code) + ' — ' + t(x.charge_name) + '</option>'
    ).join('');
    syncSelectedCharge();
  }

  function syncSelectedCharge() {
    const select = $('#billingChargeType'), code = $('#billingChargeCode');
    if (!select || !code) return;
    const x = chargeTypes.find(v => String(v.charge_type_id) === String(select.value));
    code.value = x?.charge_code || '';
  }

  async function loadConfiguration() {
    const all = await Promise.all([
      api('/api/billing/config'),
      api('/api/billing/config/history'),
      api('/api/billing/frequencies'),
      api('/api/billing/dpc-options'),
      api('/api/billing/property-types'),
      api('/api/billing/charge-types'),
      api('/api/billing/rates')
    ]);
    const [config,history,frequencies,dpcOptions,types,charges,rates] = all;
    propertyTypes = types || [];
    chargeTypes = charges || [];

    const c=config?.[0], freq=$('#billingFrequency'), dpc=$('#billingDpcApplyOn');
    freq.innerHTML=(frequencies||[]).map(x=>'<option value="'+x.frequency_months+'">'+t(x.frequency_name)+'</option>').join('');
    dpc.innerHTML=(dpcOptions||[]).map(x=>'<option value="'+x.apply_code+'">'+t(x.apply_name)+'</option>').join('');

    if(c){
      freq.value=c.billing_frequency_months;
      $('#billingDpcApplicable').value=String(c.dpc_applicable);
      dpc.value=c.dpc_apply_on;
      $('#billingDpcRate').value=c.dpc_rate??0;
      $('#billingEffectiveFrom').value=c.effective_from||dateToday();
      $('#billingEffectiveTo').value=c.effective_to||'';
      $('#billingConfigRemark').value=c.modify_remark||'';
    } else {
      $('#billingEffectiveFrom').value=dateToday();
    }

    $('#billingPropertyType').innerHTML=propertyTypes.map(x=>'<option value="'+x.billing_property_type_id+'">'+t(x.property_type_name)+'</option>').join('');
    bindChargeTypeOptions();
    if (!$('#billingRateFrom').value) $('#billingRateFrom').value=dateToday();

    table('#billingConfigHistoryTable',history||[],[
      {title:'Old Value',field:'old_frequency_months',headerFilter:true},
      {title:'New Value',field:'new_frequency_months',headerFilter:true},
      {title:'DPC Applicable',field:'new_dpc_applicable'},
      {title:'DPC Apply On',field:'new_dpc_apply_on'},
      {title:'DPC Rate',field:'new_dpc_rate'},
      {title:'Effective From',field:'effective_from'},
      {title:'Effective To',field:'effective_to'},
      {title:'Modify Remark',field:'modify_remark'},
      {title:'Active',field:'active'},
      {title:'Modified',field:'modify_date'}
    ]);
    renderRates(rates||[]);
  }

  function renderRates(rates) {
    table('#billingRateTable',rates,[
      {title:'Property Type',field:'property_type_name',headerFilter:true},
      {title:'Charge',field:'charge_code',headerFilter:true},
      {title:'Charge Name',field:'charge_name',headerFilter:true},
      {title:'Rate Type',field:'rate_type',headerFilter:true},
      {title:'Rate',field:'rate',hozAlign:'right',formatter:c=>money(c.getValue())},
      {title:'Effective From',field:'effective_from'},
      {title:'Effective To',field:'effective_to'},
      {title:'Active',field:'is_active'}
    ]);
  }

  async function saveConfig() {
    const payload={
      frequencyMonths:Number($('#billingFrequency').value),
      dpcApplicable:$('#billingDpcApplicable').value==='true',
      dpcApplyOn:$('#billingDpcApplyOn').value,
      dpcRate:Number($('#billingDpcRate').value||0),
      dpcCalculationType:'Percentage',
      effectiveFrom:$('#billingEffectiveFrom').value,
      effectiveTo:$('#billingEffectiveTo').value||null,
      remark:$('#billingConfigRemark').value||''
    };
    await api('/api/billing/config',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(payload)});
    window.Society360Toast?.success('Configuration saved successfully.');
    await loadConfiguration(); await refreshProcess();
  }

  async function saveRate() {
    const payload={
      id:0,
      propertyTypeId:Number($('#billingPropertyType').value),
      chargeTypeId:Number($('#billingChargeType').value),
      rateType:$('#billingRateType').value,
      rate:Number($('#billingRateValue').value||0),
      effectiveFrom:$('#billingRateFrom').value,
      effectiveTo:$('#billingRateTo').value||null,
      remark:$('#billingRateRemark').value||''
    };
    if(!payload.propertyTypeId||!payload.chargeTypeId||!payload.effectiveFrom||!Number.isFinite(payload.rate)||payload.rate<0){
      window.Society360Toast?.warning('Please complete the required rate fields.'); return;
    }
    await api('/api/billing/rate',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(payload)});
    window.Society360Toast?.success('Rate saved successfully.');
    $('#billingRateValue').value=''; $('#billingRateTo').value='';
    await loadConfiguration(); await refreshProcess();
  }

  async function refreshProcess() {
    const all=await Promise.all([api('/api/billing/next-month'),api('/api/billing/rates'),api('/api/billing/missing-rates')]);
    const next=all[0],rates=all[1]||[],missing=all[2]||[];
    $('#billingNextMonth').textContent=next?.value||'—';
    const grouped={};
    rates.forEach(r=>{
      const k=r.property_type_name||'—';
      grouped[k] ||= [];
      grouped[k].push(t(r.charge_name)+': '+money(r.rate)+' ('+t(r.rate_type)+')');
    });
    $('#billingCurrentRates').innerHTML=Object.entries(grouped).map(x=>
      '<div class="billing-rate-group"><strong>'+t(x[0])+'</strong><span>'+x[1].join(' · ')+'</span></div>'
    ).join('')||'<div class="billing-empty">'+t('No billing rates are configured.')+'</div>';
    $('#billingMissingRates').innerHTML=missing.length
      ? '<div class="billing-missing-title">'+t('Missing Mandatory Rates')+'</div>'+missing.map(x=>'<div>'+t(x.property_type_name)+' — '+t(x.charge_name)+'</div>').join('')
      : '<div class="billing-ready">'+t('All mandatory rates are configured.')+'</div>';
    $('#startBilling').disabled=missing.length>0;
  }

  async function startBilling() {
    const missing=await api('/api/billing/missing-rates');
    if((missing||[]).length){window.Society360Toast?.warning('Please configure all mandatory rates before starting billing.');return;}
    const result=await api('/api/billing/start',{method:'POST'});
    runId=Number(result.id||0);
    $('#billingRunLabel').textContent=t('Billing Run')+' #'+runId;
    await loadPreview();
    window.Society360Toast?.success('Billing preparation completed successfully.');
  }

  async function loadPreview() {
    if(!runId)return;
    const rows=await api('/api/billing/preview/'+runId);
    table('#billingPreviewTable',rows||[],[
      {title:'Customer',field:'customer_name',headerFilter:true},
      {title:'Customer Number',field:'customer_number',headerFilter:true},
      {title:'Flat Number',field:'flat_no',headerFilter:true},
      {title:'Bill Month',field:'billing_month'},
      {title:'Maintenance',field:'maintenance_amount',hozAlign:'right',formatter:c=>money(c.getValue())},
      {title:'Sinking Fund',field:'sinking_fund_amount',hozAlign:'right',formatter:c=>money(c.getValue())},
      {title:'Parking',field:'parking_amount',hozAlign:'right',formatter:c=>money(c.getValue())},
      {title:'Other Charges',field:'other_charge_amount',hozAlign:'right',formatter:c=>money(c.getValue())},
      {title:'Arrear',field:'arrear_amount',hozAlign:'right',formatter:c=>money(c.getValue())},
      {title:'Interest Arrear',field:'interest_arrear_amount',hozAlign:'right',formatter:c=>money(c.getValue())},
      {title:'Total',field:'total_amount',hozAlign:'right',formatter:c=>money(c.getValue())},
      {title:'Payment',field:'payment_amount',hozAlign:'right',formatter:c=>money(c.getValue())},
      {title:'Balance',field:'balance_amount',hozAlign:'right',formatter:c=>money(c.getValue())},
      {title:'Last Payment Amount',field:'last_payment_amount',hozAlign:'right',formatter:c=>money(c.getValue())},
      {title:'Last Payment Date',field:'last_payment_date',formatter:c=>c.getValue()?new Date(c.getValue()).toLocaleString(Society360I18n.locale()):'—'},
      {title:'Status',field:'status'}
    ]);
    $('#finalizeBilling').disabled=!(rows&&rows.length);
  }

  async function finalizeBilling() {
    if(!runId)return;
    const message=t('Once this billing process is finalized, it cannot be reverted. Are you sure you want to finalize the bill?');
    if(!window.confirm(message))return;
    await api('/api/billing/finalize',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({runId,confirm:true})});
    window.Society360Toast?.success('Billing completed successfully.');
    runId=0; $('#billingRunLabel').textContent=''; $('#billingPreviewTable').innerHTML=''; $('#finalizeBilling').disabled=true;
    await refreshProcess();
  }

  function bind() {
    $('#billingChargeType')?.addEventListener('change',syncSelectedCharge);
    $('#saveBillingConfig')?.addEventListener('click',()=>saveConfig().catch(e=>window.Society360Toast?.error(e.message)));
    $('#saveBillingRate')?.addEventListener('click',()=>saveRate().catch(e=>window.Society360Toast?.error(e.message)));
    $('#startBilling')?.addEventListener('click',()=>startBilling().catch(e=>window.Society360Toast?.error(e.message)));
    $('#finalizeBilling')?.addEventListener('click',()=>finalizeBilling().catch(e=>window.Society360Toast?.error(e.message)));
    window.addEventListener('society360-language-changed',()=>{
      if($('#billing-configuration')?.classList.contains('active'))loadConfiguration().catch(()=>{});
      if($('#billing-process')?.classList.contains('active')){refreshProcess().catch(()=>{});if(runId)loadPreview().catch(()=>{});}
    });
  }

  async function init() {
    bind();
    try { await loadConfiguration(); await refreshProcess(); }
    catch(e) { if(e.message!=='AUTH_REQUIRED')window.Society360Toast?.error(e.message); }
  }

  window.billingModule={init,refreshProcess,loadConfiguration,loadPreview};
})();
