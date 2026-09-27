let lastFile=null;
let csrfToken=null;
(async()=>{const r=await fetch('/api/security/csrf'); if(r.ok){csrfToken=(await r.json()).token;}})();
function setStatus(x){document.getElementById('status').textContent=x}
function file(){return document.getElementById('file').files[0]}
async function preview(){
  const f=file(); if(!f){setStatus('Please select an Excel file.');return}
  const fd=new FormData(); fd.append('file',f);
  const r=await fetch('/api/migration/preview',{method:'POST',headers:{'X-CSRF-TOKEN':csrfToken||''},body:fd});
  const d=await r.json(); if(!r.ok){setStatus(d.message||'Preview failed.');return}
  lastFile=f; document.getElementById('summary').innerHTML='<span class="badge ok">'+d.total+' importable rows</span> &nbsp; '+d.file;
  document.getElementById('grid').innerHTML=d.rows.map(x=>'<tr><td>'+x.rowNumber+'</td><td>'+esc(x.wing)+'</td><td>'+esc(x.unitNo)+'</td><td>'+esc(x.unitType)+'</td><td>'+esc(x.owner)+'</td><td>'+fmt(x.area)+'</td><td>'+fmt(x.maintenance)+'</td></tr>').join('');
  setStatus('Preview ready. Wing names and total rows are normalized; no master records were changed.');
}
async function importData(){
  const f=lastFile||file(); if(!f){setStatus('Please preview an Excel file first.');return}
  if(!confirm('Import this migration file into the currently selected society?')) return;
  const fd=new FormData(); fd.append('file',f);
  const r=await fetch('/api/migration/import',{method:'POST',headers:{'X-CSRF-TOKEN':csrfToken||''},body:fd});
  const d=await r.json(); if(!r.ok){setStatus(d.message||'Import failed.');return}
  setStatus('Imported batch '+d.batchId+': '+d.result.importedFlats+' flats, '+d.result.importedCustomers+' customers. Skipped/error rows: '+d.result.skippedRows+'.');
}
function esc(v){return v==null?'':String(v).replace(/[&<>"]/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[m]))}
function fmt(v){return v==null?'':Number(v).toLocaleString('en-IN',{maximumFractionDigits:2})}