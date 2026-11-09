(() => {
  'use strict';
  const STYLE_ID='s360-skyfy-theme-style';
  const STYLE_URL='/css/skyfy-nexus.css?v=20261109.03';
  const GUEST_KEY='society360-guest-theme';
  let currentTheme='STANDARD', themes=[], authenticated=false, canChange=false, modal=null, trigger=null, busy=false;
  const t=(s)=>window.Society360I18n?.translateText?.(s)||s;
  const emit=(code)=>window.dispatchEvent(new CustomEvent('s360:theme-applied',{detail:{themeCode:code}}));
  const guestPage=()=>!!document.querySelector('#login-form');
  const normalize=(v)=>String(v||'STANDARD').trim().toUpperCase();
  const themeName=(x)=>normalize(x.themeCode)==='STANDARD'?t('Standard Theme'):normalize(x.themeCode)==='SKYFY_NEXUS'?'SKYFY NEXUS':x.themeName||x.themeCode;
  function toast(message,kind='success'){
    let el=document.getElementById('s360-theme-toast');
    if(!el){el=document.createElement('div');el.id='s360-theme-toast';el.className='s360-theme-toast';el.setAttribute('role','status');el.setAttribute('aria-live','polite');document.body.appendChild(el);}
    el.dataset.kind=kind;el.textContent=t(message);el.classList.add('is-visible');
    clearTimeout(el._hideTimer);el._hideTimer=setTimeout(()=>el.classList.remove('is-visible'),2600);
  }
  function applyTheme(code){
    const next=normalize(code);
    if(next==='SKYFY_NEXUS'){
      return new Promise(resolve=>{
        const existing=document.getElementById(STYLE_ID);
        if(existing){document.documentElement.dataset.s360Theme='skyfy-nexus';emit(next);resolve(true);return;}
        const link=document.createElement('link');link.id=STYLE_ID;link.rel='stylesheet';link.href=STYLE_URL;
        link.onload=()=>{document.documentElement.dataset.s360Theme='skyfy-nexus';emit(next);resolve(true);};
        link.onerror=()=>{link.remove();document.documentElement.dataset.s360Theme='standard';emit('STANDARD');resolve(false);};
        document.head.appendChild(link);
      });
    }
    document.documentElement.dataset.s360Theme='standard';document.getElementById(STYLE_ID)?.remove();emit('STANDARD');return Promise.resolve(true);
  }
  async function csrf(){
    const r=await fetch('/api/security/csrf',{credentials:'same-origin',cache:'no-store',headers:{Accept:'application/json'}});
    if(!r.ok)throw new Error('csrf');const p=await r.json();if(!p.token)throw new Error('csrf');return p.token;
  }
  async function persist(code){
    const token=await csrf();
    const r=await fetch('/api/theme/preference',{method:'PUT',credentials:'same-origin',cache:'no-store',
      headers:{'Content-Type':'application/json','X-CSRF-TOKEN':token,Accept:'application/json'},
      body:JSON.stringify({themeCode:code,remark:'User changed application theme'})});
    if(!r.ok)throw new Error('save');
  }
  function ensureModal(){
    if(modal)return modal;
    modal=document.createElement('div');modal.id='s360-theme-modal';modal.className='s360-preference-backdrop';modal.hidden=true;
    modal.innerHTML='<section class="s360-preference-dialog" role="dialog" aria-modal="true" aria-labelledby="s360-theme-title"><header class="s360-preference-head"><div><span class="s360-preference-kicker">SOCIETY360</span><h2 id="s360-theme-title"></h2><p id="s360-theme-description"></p></div><button type="button" class="s360-preference-close" aria-label="Close">×</button></header><div id="s360-theme-gallery" class="s360-theme-gallery"></div><footer class="s360-preference-foot"><span id="s360-theme-status" role="status"></span><button type="button" class="s360-preference-done"></button></footer></section>';
    document.body.appendChild(modal);
    modal.querySelector('.s360-preference-close').addEventListener('click',closeModal);
    modal.querySelector('.s360-preference-done').addEventListener('click',closeModal);
    modal.addEventListener('click',e=>{if(e.target===modal)closeModal();});
    document.addEventListener('keydown',e=>{if(e.key==='Escape'&&modal&&!modal.hidden)closeModal(true);});
    return modal;
  }
  function closeModal(restore=true){if(!modal)return;modal.hidden=true;if(restore)trigger?.focus();}
  function renderGallery(){
    const m=ensureModal(),gallery=m.querySelector('#s360-theme-gallery'),status=m.querySelector('#s360-theme-status');
    m.querySelector('#s360-theme-title').textContent=t('Choose your theme');
    m.querySelector('#s360-theme-description').textContent=t(authenticated?'Select an available theme for your Society360 workspace.':'Preview a theme before signing in. Your society entitlement is checked after login.');
    m.querySelector('.s360-preference-done').textContent=t('Done');gallery.replaceChildren();
    const list=themes.length?themes:[{themeCode:'STANDARD',themeName:'Standard Theme',isCommercial:false}];
    list.forEach(item=>{
      const code=normalize(item.themeCode),card=document.createElement('button');card.type='button';card.className='s360-theme-card';
      card.dataset.theme=code;card.setAttribute('aria-pressed',String(code===currentTheme));
      const visual=document.createElement('span');visual.className='s360-theme-card__preview '+(code==='SKYFY_NEXUS'?'is-skyfy':'is-standard');
      visual.innerHTML=code==='SKYFY_NEXUS'?'<i></i><i></i><i></i><b>360</b>':'<i></i><i></i><i></i><b>360</b>';
      const title=document.createElement('strong');title.textContent=themeName(item);
      const desc=document.createElement('small');desc.textContent=code==='SKYFY_NEXUS'?t('Futuristic dark glass and smart community visuals.'):t('Clean, familiar Society360 workspace.');
      const meta=document.createElement('span');meta.className='s360-theme-card__meta';
      const locked=authenticated&&item.isAvailable===false;
      meta.textContent=locked?t('Available with a commercial plan'):(code==='SKYFY_NEXUS'?(item.isCommercial?t('Commercial theme'):''):t('Included'));
      const selected=document.createElement('span');selected.className='s360-theme-card__selected';selected.textContent=code===currentTheme?t('Selected'):'';
      card.append(visual,title,desc,meta,selected);card.disabled=busy||(authenticated&&(locked||(!canChange&&code!==currentTheme)));
      card.addEventListener('click',()=>chooseTheme(code));gallery.appendChild(card);
    });
    status.textContent=authenticated&&!canChange?t('Your account does not have permission to change themes.'):(!authenticated?t('Preview only until you sign in.'):t('Your selection is saved to your account.'));
  }
  async function chooseTheme(code){
    if(busy)return;const next=normalize(code),previous=currentTheme;
    const selectedOption=themes.find(x=>normalize(x.themeCode)===next);
    if(authenticated&&selectedOption?.isAvailable===false){toast('The selected theme is not included in this society plan.','error');return;}
    if(authenticated&&!canChange&&next!==currentTheme){toast('Your account does not have permission to change themes.','error');return;}
    busy=true;modal.querySelectorAll('.s360-theme-card').forEach(x=>x.disabled=true);
    const ok=await applyTheme(next);
    if(!ok){busy=false;await applyTheme(previous);renderGallery();toast('Could not load the selected theme.','error');return;}
    if(!authenticated){
      currentTheme=next;try{localStorage.setItem(GUEST_KEY,next);}catch{}
      busy=false;renderGallery();toast('Theme preview updated. Sign in to apply your society theme.','success');return;
    }
    try{
      await persist(next);currentTheme=next;try{localStorage.removeItem(GUEST_KEY);}catch{}
      busy=false;renderGallery();toast('Theme updated successfully.');
    }catch{
      await applyTheme(previous);currentTheme=previous;busy=false;renderGallery();toast('Could not change theme.','error');
    }
  }
  function openModal(source){
    trigger=source||trigger;renderGallery();modal.hidden=false;modal.querySelector('.s360-preference-close').focus();
  }
  function addTrigger(){
    const language=document.querySelector('#language-select');
    if(!language||document.getElementById('s360-theme-trigger'))return;
    const host=language.closest('.language-wrap,.lang')||language;
    const button=document.createElement('button');button.type='button';button.id='s360-theme-trigger';button.className='s360-theme-trigger';
    button.innerHTML='<span aria-hidden="true">◐</span><span class="s360-theme-trigger__text"></span>';
    button.querySelector('.s360-theme-trigger__text').textContent=t('Theme');
    button.setAttribute('aria-haspopup','dialog');button.addEventListener('click',()=>openModal(button));
    if(host&&host.parentElement){host.insertAdjacentElement('afterend',button);}else{document.body.appendChild(button);}
    trigger=button;
  }
  function refreshLanguage(){
    const b=document.getElementById('s360-theme-trigger');if(b){b.querySelector('.s360-theme-trigger__text').textContent=t('Theme');b.setAttribute('aria-label',t('Choose your theme'));}
    if(modal&&!modal.hidden)renderGallery();
  }
  async function initGuest(){
    const r=await fetch('/api/theme/catalog',{credentials:'same-origin',cache:'no-store',headers:{Accept:'application/json'}});
    if(!r.ok)throw new Error('catalog');const p=await r.json();themes=Array.isArray(p.themes)?p.themes:[];
    const stored=normalize(localStorage.getItem(GUEST_KEY)||'STANDARD');
    currentTheme=themes.some(x=>normalize(x.themeCode)===stored)?stored:'STANDARD';
    await applyTheme(currentTheme);addTrigger();
  }
  async function initAuthenticated(){
    const r=await fetch('/api/theme/options',{credentials:'same-origin',cache:'no-store',headers:{Accept:'application/json'}});
    if(!r.ok)throw new Error('options');const p=await r.json();
    themes=Array.isArray(p.themes)?p.themes:[];authenticated=true;canChange=!!p.canChange;
    const saved=normalize(p.selectedTheme||'STANDARD');
    const guest=normalize(localStorage.getItem(GUEST_KEY)||'');
    const guestEntry=themes.find(x=>normalize(x.themeCode)===guest);
    const guestAllowed=!!guest&&canChange&&!!guestEntry&&guestEntry.isAvailable!==false;
    currentTheme=guestAllowed?guest:saved;
    const applied=await applyTheme(currentTheme);if(!applied)currentTheme='STANDARD';
    addTrigger();
    if(guestAllowed){
      if(currentTheme!==saved){
        try{await persist(currentTheme);}catch{await applyTheme(saved);currentTheme=saved;toast('Your pre-login theme is not available for this society.','error');}
      }
      localStorage.removeItem(GUEST_KEY);
    }else if(guest&&guest!==saved){
      localStorage.removeItem(GUEST_KEY);
      if(!guestEntry||guestEntry.isAvailable===false)toast('The selected theme is not included in this society plan.','error');
      else if(!canChange)toast('Your account does not have permission to change themes.','error');
    }
  }
  window.addEventListener('society360-language-changed',refreshLanguage);
  window.addEventListener('s360:open-themes',()=>openModal(document.getElementById('s360-theme-trigger')));
  async function initialize(){
    document.documentElement.dataset.s360Theme='standard';
    try{if(guestPage())await initGuest();else await initAuthenticated();}
    catch{document.documentElement.dataset.s360Theme='standard';document.getElementById(STYLE_ID)?.remove();emit('STANDARD');if(guestPage())addTrigger();}
  }
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',initialize,{once:true});else initialize();
})();