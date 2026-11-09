(() => {
'use strict';
const STYLE_ID='s360-skyfy-theme-style',ENGINE_ID='s360-dynamic-color-engine';
const STYLE_URL='/css/skyfy-nexus.css?v=20261109.06',ENGINE_URL='/css/dynamic-color-engine.css?v=20261109.16';
const GUEST_KEY='society360-guest-theme';
const PALETTES=[
 ['SKYFY_BLUE','SKYFY BLUE','#2583ff','#091b3b','#39d8ff','#071326','#102441','#eff7ff','#294a70'],
 ['RUBY_RED','RUBY RED','#e33455','#4a1020','#ff7187','#170b12','#2b1420','#fff0f3','#663044'],
 ['ROYAL_PURPLE','ROYAL PURPLE','#9565ff','#25134f','#d2a5ff','#100c24','#21183d','#f6f0ff','#4d3975'],
 ['EMERALD_GREEN','EMERALD GREEN','#12b981','#073b2d','#70f0bd','#071a16','#102c24','#eafff5','#285a49'],
 ['GOLDEN_LUXURY','GOLDEN LUXURY','#c79a42','#3b2914','#f4d58a','#17120b','#2b2114','#fff7e6','#69532e'],
 ['CYBER_CYAN','CYBER CYAN','#00c9df','#07344a','#63f3ff','#06151e','#0d2935','#e8fcff','#1b5968'],
 ['SUNSET_ORANGE','SUNSET ORANGE','#f07835','#4a241b','#ffb06d','#1b100d','#30201b','#fff3eb','#704330'],
 ['ARCTIC_SILVER','ARCTIC SILVER','#8da9c2','#34485d','#c6e7ff','#101923','#202d3a','#f3f8fc','#536b80']
];
const MODES=[['DARK','Dark mode'],['LIGHT','Light mode'],['GLASS','Premium glass'],['GRADIENT','Dynamic gradient']];
let currentTheme='STANDARD',currentMode='DARK',themes=[],authenticated=false,canChange=false,canCustomize=false,canOrg=false,modal=null,trigger=null,busy=false,customColors={};
const t=s=>window.Society360I18n?.translateText?.(s)||s;
const norm=v=>String(v||'STANDARD').trim().toUpperCase();
const palette=code=>{
 const fallback=PALETTES.find(x=>x[0]===code)||PALETTES[0];
 const item=themes.find(x=>norm(x.themeCode)===norm(code));
 const db=item?.palette||{};
 return [norm(code),item?.themeName||fallback[1],db.primary||fallback[2],db.secondary||fallback[3],db.accent||fallback[4],db.background||fallback[5],db.surface||fallback[6],db.text||fallback[7],db.border||fallback[8]];
};
const paletteObject=code=>{const p=palette(code);return {primary:p[2],secondary:p[3],accent:p[4],background:p[5],surface:p[6],text:p[7],border:p[8]};};
const emit=()=>window.dispatchEvent(new CustomEvent('s360:theme-applied',{detail:{themeCode:currentTheme,mode:currentMode,palette:palette(currentTheme)}}));
const guestPage=()=>!!document.querySelector('#login-form');
const colorMix=(a,b,t)=>{const x=a.match(/^#([0-9a-f]{6})$/i),y=b.match(/^#([0-9a-f]{6})$/i);if(!x||!y)return a;const A=x[1],B=y[1];return '#'+[0,2,4].map(i=>Math.round(parseInt(A.slice(i,i+2),16)*(1-t)+parseInt(B.slice(i,i+2),16)*t).toString(16).padStart(2,'0')).join('');};
const bestInk=backgrounds=>{const candidates=['#f8fbff','#111827'];return candidates.sort((a,b)=>Math.min(...backgrounds.map(bg=>contrast(b,bg)))-Math.min(...backgrounds.map(bg=>contrast(a,bg))))[0];};
const safeButtonPair=backgrounds=>{const options=[{ink:'#ffffff',target:'#000000'},{ink:'#111827',target:'#ffffff'}].map(option=>{let cost=0;const adjusted=backgrounds.map(bg=>{if(contrast(option.ink,bg)>=4.5)return bg;let lo=0,hi=1,best=option.target;for(let i=0;i<24;i++){const mid=(lo+hi)/2,candidate=colorMix(bg,option.target,mid);if(contrast(option.ink,candidate)>=4.5){best=candidate;hi=mid;}else lo=mid;}cost+=hi;return best;});return {...option,adjusted,cost};});return options.sort((a,b)=>a.cost-b.cost)[0];};
const ensureContrast=(foreground,background,minimum=4.5)=>{if(contrast(foreground,background)>=minimum)return foreground;const target=contrast('#ffffff',background)>=contrast('#111827',background)?'#ffffff':'#111827';let lo=0,hi=1,best=target;for(let i=0;i<24;i++){const mid=(lo+hi)/2,candidate=colorMix(foreground,target,mid);if(contrast(candidate,background)>=minimum){best=candidate;hi=mid;}else lo=mid;}return best;};
function setColors(colors){
 const root=document.documentElement,mode=root.dataset.s360Mode||'DARK',light=mode==='LIGHT';
 const valid=(v,fallback)=>/^#[0-9a-f]{6}$/i.test(v||'')?v:fallback;
 const primary=valid(colors?.primary,'#2583ff'),secondary=light?'#e7edf5':valid(colors?.secondary,'#091b3b'),accent=valid(colors?.accent,'#39d8ff'),background=light?'#f4f7fb':valid(colors?.background,'#071326'),surface=light?'#ffffff':valid(colors?.surface,'#102441'),border=light?'#d5deea':valid(colors?.border,'#294a70');
 const requested=light?'#182334':valid(colors?.text,'#eff7ff'),safeText=contrast(requested,surface)>=4.5&&contrast(requested,background)>=4.5?requested:bestInk([surface,background,secondary]);
 const buttonPair=safeButtonPair([primary,accent]),onPrimary=buttonPair.ink,onAccent=bestInk([accent]),onSecondary=bestInk([secondary]);
 const link=ensureContrast(accent,surface,4.5),focus=ensureContrast(accent,surface,3);
 const vars={primary,secondary,accent,bg:background,surface,text:safeText,border,muted:safeText,'page-background':background,'surface-background':surface,'surface-secondary':secondary,'text-primary':safeText,'text-secondary':safeText,'text-muted':safeText,'text-on-primary':onPrimary,'text-on-accent':onAccent,'button-primary':buttonPair.adjusted[0],'button-accent':buttonPair.adjusted[1],'menu-background':secondary,'menu-text':onSecondary,'menu-active-background':buttonPair.adjusted[0],'menu-active-text':onPrimary,'input-background':surface,'input-text':safeText,'input-placeholder':safeText,'table-header-background':secondary,'table-header-text':onSecondary,'border-color':border,'focus-color':focus,'link-color':link};
 Object.entries(vars).forEach(([key,value])=>root.style.setProperty('--s360-'+key,value));
 root.style.setProperty('--s360-glow','color-mix(in srgb,'+accent+' 28%,transparent)');
 root.style.setProperty('--s360-gradient','linear-gradient(135deg,'+secondary+','+background+' 55%,'+surface+')');
}
function ensureStyles(){
 return new Promise(resolve=>{
  const add=(id,href)=>new Promise(done=>{if(document.getElementById(id)){done(true);return;}const l=document.createElement('link');l.id=id;l.rel='stylesheet';l.href=href;l.onload=()=>done(true);l.onerror=()=>{l.remove();done(false);};document.head.append(l);});
  Promise.all([add(STYLE_ID,STYLE_URL),add(ENGINE_ID,ENGINE_URL)]).then(x=>resolve(x.every(Boolean)));
 });
}
async function applyTheme(code,mode=currentMode,colors=customColors){
 const next=norm(code);
 if(next==='STANDARD'){
  currentTheme='STANDARD';customColors={};
  document.documentElement.dataset.s360Theme='standard';delete document.documentElement.dataset.s360Palette;delete document.documentElement.dataset.s360Mode;
  ['primary','secondary','accent','bg','surface','text','border','muted','page-background','surface-background','surface-secondary','text-primary','text-secondary','text-muted','text-on-primary','text-on-accent','button-primary','button-accent','menu-background','menu-text','menu-active-background','menu-active-text','input-background','input-text','input-placeholder','table-header-background','table-header-text','border-color','focus-color','link-color','glow','gradient'].forEach(k=>document.documentElement.style.removeProperty('--s360-'+k));emit();return true;
 }
 const ok=await ensureStyles();if(!ok)return false;
 const root=document.documentElement;root.dataset.s360Theme='skyfy-nexus';root.dataset.s360Palette=next;root.dataset.s360Mode=MODES.some(x=>x[0]===mode)?mode:'DARK';
 currentTheme=next;currentMode=root.dataset.s360Mode;setColors({...paletteObject(next),...(colors||{})});emit();return true;
}
async function csrf(){const r=await fetch('/api/security/csrf',{credentials:'same-origin',cache:'no-store'});if(!r.ok)throw Error('Security token unavailable');const x=await r.json();if(!x.token)throw Error('Security token missing');return x.token;}
async function persist(code=currentTheme,mode=currentMode,colors=customColors,org=false){
 const token=await csrf(),url=org?'/api/theme/organization-preference':'/api/theme/preference';
 const r=await fetch(url,{method:'PUT',credentials:'same-origin',cache:'no-store',headers:{'Content-Type':'application/json','X-CSRF-TOKEN':token,Accept:'application/json'},body:JSON.stringify({themeCode:code,themeMode:mode,customColors:colors,remark:'Updated through Society360 Dynamic Color Theme Engine'})});
 if(!r.ok){const x=await r.json().catch(()=>({}));throw Error(x.message||'Could not save color preferences');}
}
function toast(msg,error=false){let e=document.getElementById('s360-theme-toast');if(!e){e=document.createElement('div');e.id='s360-theme-toast';e.className='s360-theme-toast';e.setAttribute('role','status');document.body.append(e);}e.textContent=t(msg);e.dataset.kind=error?'error':'success';e.classList.add('is-visible');clearTimeout(e._timer);e._timer=setTimeout(()=>e.classList.remove('is-visible'),2800);}
function previewMarkup(p){return '<span class="s360-color-preview" style="--pv1:'+p[2]+';--pv2:'+p[3]+';--pv3:'+p[4]+';--pvbg:'+p[5]+';--pvsurface:'+p[6]+'"><i></i><i></i><i></i><b>360</b><em>Live</em></span>';}
function ensureModal(){
 if(modal)return modal;
 modal=document.createElement('div');modal.id='s360-theme-modal';modal.className='s360-preference-backdrop';modal.hidden=true;
 modal.innerHTML='<section class="s360-preference-dialog s360-color-dialog" role="dialog" aria-modal="true" aria-labelledby="s360-theme-title"><header class="s360-preference-head"><div><span class="s360-preference-kicker">SOCIETY360 / THEMES</span><h2 id="s360-theme-title"></h2><p id="s360-theme-description"></p></div><button type="button" class="s360-preference-close" aria-label="Close">X</button></header><div class="s360-color-modes" role="group" aria-label="Appearance mode"></div><div id="s360-theme-gallery" class="s360-theme-gallery s360-color-gallery"></div><section class="s360-color-custom"><div class="s360-color-custom__head"><div><strong>Custom color preset</strong><small>Available to administrators with theme customization permission.</small></div><button type="button" class="s360-color-reset">Reset palette</button></div><div class="s360-color-fields"></div><div class="s360-color-contrast" role="status"></div></section><footer class="s360-preference-foot"><span id="s360-theme-status" role="status"></span><div class="s360-color-actions"><button type="button" class="s360-color-org">Set society default</button><button type="button" class="s360-color-save">Save custom colors</button><button type="button" class="s360-preference-done">Done</button></div></footer></section>';
 document.body.append(modal);
 modal.querySelector('.s360-preference-close').onclick=()=>closeModal();
 modal.querySelector('.s360-preference-done').onclick=()=>closeModal();
 modal.querySelector('.s360-color-org').onclick=()=>save(true);
 modal.querySelector('.s360-color-save').onclick=()=>save(false);
 modal.querySelector('.s360-color-reset').onclick=()=>{customColors={};applyTheme(currentTheme,currentMode,customColors);render();};
 modal.addEventListener('click',e=>{if(e.target===modal)closeModal();});
 document.addEventListener('keydown',e=>{if(e.key==='Escape'&&modal&&!modal.hidden)closeModal(true);});
 return modal;
}
function closeModal(restore=true){if(modal)modal.hidden=true;if(restore)trigger?.focus();}
function render(){
 const m=ensureModal(),gallery=m.querySelector('#s360-theme-gallery'),modes=m.querySelector('.s360-color-modes');
 m.querySelector('#s360-theme-title').textContent=t('Themes');
 m.querySelector('#s360-theme-description').textContent=t(authenticated?'Choose a premium palette and appearance mode. Your preferences are saved to the database.':'Preview a premium palette before signing in.');
 gallery.replaceChildren();modes.replaceChildren();
 MODES.forEach(([code,label])=>{const b=document.createElement('button');b.type='button';b.className='s360-mode-option';b.textContent=t(label);b.disabled=authenticated&&!canChange;b.setAttribute('aria-pressed',String(currentMode===code));b.onclick=()=>changeMode(code);modes.append(b);});
 const items=themes.length?themes:[{themeCode:'STANDARD',themeName:'Standard Theme',isAvailable:true},...PALETTES.map(p=>({themeCode:p[0],themeName:p[1],isAvailable:true,isCommercial:true}))];
 items.forEach(item=>{
  const code=norm(item.themeCode);
  const p=palette(code),card=document.createElement('button');card.type='button';card.className='s360-theme-card s360-color-card';card.dataset.theme=code;card.setAttribute('aria-pressed',String(code===currentTheme));
  card.innerHTML=(code==='STANDARD'?'<span class="s360-color-preview s360-color-preview-standard"><i></i><i></i><i></i><b>360</b><em>Classic</em></span>':previewMarkup(p))+'<strong>'+(code==='STANDARD'?t('Standard Theme'):p[1])+'</strong><small>'+(code==='STANDARD'?t('Original Society360 appearance'):p[2]+' / '+p[4]+' / '+p[3])+'</small><span class="s360-theme-card__meta">'+(item.isAvailable===false?t('Locked by plan'):(code==='STANDARD'?t('Default'):t('Included')))+'</span>';
  card.disabled=busy||(authenticated&&(item.isAvailable===false||(!canChange&&code!==currentTheme)));
  card.onclick=()=>chooseTheme(code);gallery.append(card);
 });
 const fields=m.querySelector('.s360-color-fields');fields.replaceChildren();
 const p=palette(currentTheme);const labels=[['primary','Primary'],['secondary','Secondary'],['accent','Accent'],['background','Background'],['surface','Surface'],['text','Text'],['border','Border']];
 labels.forEach(([key,label],i)=>{const wrap=document.createElement('label');wrap.className='s360-color-field';const input=document.createElement('input');input.type='color';input.value=customColors[key]||p[i+2];input.disabled=!authenticated||!canCustomize;input.oninput=()=>{customColors[key]=input.value;applyTheme(currentTheme,currentMode,customColors);contrastStatus();};wrap.append(input,document.createTextNode(t(label)));fields.append(wrap);});
 m.querySelector('.s360-color-custom').hidden=!authenticated||!canCustomize||currentTheme==='STANDARD';
 m.querySelector('.s360-color-org').hidden=!authenticated||!canOrg;
 m.querySelector('.s360-color-save').hidden=!authenticated||!canCustomize||currentTheme==='STANDARD';
 modes.hidden=currentTheme==='STANDARD';
 m.querySelector('#s360-theme-status').textContent=t(authenticated?'Changes are stored in your Society360 database profile.':'Preview only - sign in to save preferences.');
 contrastStatus();
}
function contrastStatus(){
 const el=modal?.querySelector('.s360-color-contrast');if(!el)return;
 const fg=customColors.text||palette(currentTheme)[7],bg=customColors.background||palette(currentTheme)[5];
 const ratio=contrast(fg,bg);el.textContent=t('Text contrast:')+' '+ratio.toFixed(2)+':1 '+(ratio>=4.5?' - '+t('WCAG AA passed'):' - '+t('Select a higher-contrast text/background pair'));
 el.dataset.valid=String(ratio>=4.5);
}
function contrast(fg,bg){
 const lum=h=>{const c=[1,3,5].map(i=>parseInt(h.slice(i,i+2),16)/255).map(v=>v<=.04045?v/12.92:Math.pow((v+.055)/1.055,2.4));return .2126*c[0]+.7152*c[1]+.0722*c[2];};
 const a=lum(fg),b=lum(bg);return (Math.max(a,b)+.05)/(Math.min(a,b)+.05);
}
async function chooseTheme(code){
 if(busy)return;const p=palette(code),previous=currentTheme;busy=true;
 if(!await applyTheme(code,currentMode,{})){busy=false;toast('Unable to load this color theme.',true);return;}
 if(!authenticated){currentTheme=code;try{localStorage.setItem(GUEST_KEY,code);}catch{}busy=false;render();toast('Live preview updated. Sign in to save this palette.');return;}
 try{await persist(code,currentMode,{});currentTheme=code;customColors={};busy=false;render();toast('Color theme saved successfully.');}
 catch(e){await applyTheme(previous,currentMode,customColors);busy=false;render();toast(e.message,true);}
}
async function changeMode(mode){
 const old=currentMode;currentMode=mode;await applyTheme(currentTheme,mode,customColors);render();
 if(authenticated){try{await persist(currentTheme,mode,customColors);toast('Appearance mode saved.');}catch(e){currentMode=old;await applyTheme(currentTheme,old,customColors);render();toast(e.message,true);}}
}
async function save(org=false){
 if(busy)return;
 const fg=customColors.text||palette(currentTheme)[7],bg=customColors.background||palette(currentTheme)[5];
 if(contrast(fg,bg)<4.5){toast('Improve text contrast to at least 4.5:1 before saving.',true);return;}
 busy=true;
 try{await persist(currentTheme,currentMode,customColors,org);busy=false;toast(org?'Society default theme saved.':'Custom colors saved.');}
 catch(e){busy=false;toast(e.message,true);}
}
function openModal(source){trigger=source||trigger;render();modal.hidden=false;modal.querySelector('.s360-preference-close').focus();}
function addTrigger(){
 const language=document.querySelector('#language-select');if(!language||document.getElementById('s360-theme-trigger'))return;
 const host=language.closest('.language-wrap,.lang')||language;const b=document.createElement('button');b.type='button';b.id='s360-theme-trigger';b.className='s360-theme-trigger';b.innerHTML='<span aria-hidden="true">Aa</span><span class="s360-theme-trigger__text"></span>';b.querySelector('.s360-theme-trigger__text').textContent=t('Themes');b.setAttribute('aria-haspopup','dialog');b.onclick=()=>openModal(b);
 if(host.parentElement)host.insertAdjacentElement('afterend',b);else document.body.append(b);trigger=b;
}
async function loadGuest(){
 const r=await fetch('/api/theme/catalog',{credentials:'same-origin',cache:'no-store'});if(!r.ok)throw Error('catalog');const p=await r.json();themes=p.themes||[];
 let code=norm(localStorage.getItem(GUEST_KEY)||'STANDARD');if(!themes.some(x=>norm(x.themeCode)===code))code='STANDARD';
 currentTheme=code;await applyTheme(code);addTrigger();
}
async function loadAuthenticated(){
 const r=await fetch('/api/theme/options',{credentials:'same-origin',cache:'no-store'});if(!r.ok)throw Error('options');const p=await r.json();
 themes=p.themes||[];authenticated=true;canChange=!!p.canChange;canCustomize=!!p.canCustomize;canOrg=!!p.canSetOrganizationDefault;
 const saved=norm(p.selectedTheme||'STANDARD'),guestRaw=localStorage.getItem(GUEST_KEY),guest=guestRaw?norm(guestRaw):'';
 const guestItem=guest?themes.find(x=>norm(x.themeCode)===guest):null;
 currentTheme=guest&&canChange&&guestItem?.isAvailable!==false?guest:saved;
 currentMode=p.selectedMode||p.organizationDefault?.mode||'DARK';customColors=p.customColors||{};
 await applyTheme(currentTheme,currentMode,customColors);addTrigger();
 if(guest&&guest!==saved){try{if(currentTheme===guest)await persist(currentTheme,currentMode,customColors);}catch{currentTheme=saved;await applyTheme(saved,currentMode,{});}localStorage.removeItem(GUEST_KEY);}
}
window.addEventListener('society360-language-changed',()=>{const b=document.querySelector('#s360-theme-trigger .s360-theme-trigger__text');if(b)b.textContent=t('Themes');if(modal&&!modal.hidden)render();});
window.addEventListener('s360:open-themes',()=>openModal(document.getElementById('s360-theme-trigger')));
async function init(){document.documentElement.dataset.s360Theme='standard';try{if(guestPage())await loadGuest();else await loadAuthenticated();}catch{document.documentElement.dataset.s360Theme='standard';if(guestPage())addTrigger();}}
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',init,{once:true});else init();
})();