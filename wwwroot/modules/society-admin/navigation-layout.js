(function(){
'use strict';
const side=document.querySelector('.side'),nav=document.querySelector('#dbMenu'),mobileToggle=document.querySelector('#mobileMenuToggle');
if(!side||!nav)return;
const allowedLayouts=new Set(['left','right','top']),layoutKey='society360-navigation-layout',collapsedKey='society360-navigation-collapsed';
const t=(key)=>window.Society360I18n?.translateText?.(key)||key;
let layout='left',collapsed=false,modal=null,observer=null;
function validLayout(value){return allowedLayouts.has(value)?value:'left';}
function closeOpenGroups(except){nav.querySelectorAll('details[open]').forEach(group=>{if(group!==except&&!group.contains(except))group.open=false;});}
function applyLayout(value,save=true){
 layout=validLayout(value);if(save){try{localStorage.setItem(layoutKey,layout)}catch{}}
 document.body.classList.remove('nav-layout-left','nav-layout-right','nav-layout-top');document.body.classList.add('nav-layout-'+layout);
 side.classList.remove('nav-layout-left','nav-layout-right','nav-layout-top');side.classList.add('nav-layout-'+layout);side.dataset.navLayout=layout;
 document.body.classList.toggle('nav-collapsed',collapsed&&layout!=='top');side.classList.toggle('nav-collapsed',collapsed&&layout!=='top');
 side.classList.remove('mobile-open');document.querySelector('#mobileMenuBackdrop')?.classList.remove('visible');mobileToggle?.setAttribute('aria-expanded','false');
 closeOpenGroups();if(modal&&!modal.hidden)renderModal();
}
function applyCollapsed(value,save=true){
 collapsed=Boolean(value);if(save){try{localStorage.setItem(collapsedKey,collapsed?'1':'0')}catch{}}
 side.classList.toggle('nav-collapsed',collapsed&&layout!=='top');document.body.classList.toggle('nav-collapsed',collapsed&&layout!=='top');
}
function positionSubmenu(group){
 if(layout!=='top'||!group)return;const submenu=group.querySelector(':scope > .nav-submenu');if(!submenu)return;
 const rect=group.getBoundingClientRect(),topLevel=group.parentElement===nav,width=Math.min(window.innerWidth<=760?300:260,window.innerWidth-24);
 if(window.innerWidth<=760){
  const top=topLevel?Math.min(rect.bottom+7,window.innerHeight-140):Math.max(8,Math.min(rect.top,window.innerHeight-140));
  const left=topLevel?Math.max(12,Math.min(rect.left,window.innerWidth-width-12)):(rect.right+width<=window.innerWidth-12?rect.right+4:Math.max(12,rect.left-width-4));
  submenu.style.position='fixed';submenu.style.top=top+'px';submenu.style.left=left+'px';submenu.style.right='auto';submenu.style.width=width+'px';submenu.style.maxHeight=Math.max(120,window.innerHeight-top-12)+'px';
  submenu.dataset.align=left+width>window.innerWidth-12?'right':'left';return;
 }
 ['position','top','left','right','width','maxHeight'].forEach(key=>submenu.style[key]='');
 if(topLevel)submenu.dataset.align=(rect.left+width>window.innerWidth-12)?'right':'left';
 else submenu.dataset.align=(rect.right+width>window.innerWidth-12)?'left':'right';
}
function onNavigate(){if(layout==='top')closeOpenGroups();side.classList.remove('mobile-open');document.querySelector('#mobileMenuBackdrop')?.classList.remove('visible');mobileToggle?.setAttribute('aria-expanded','false');}
function ensureModal(){
 if(modal)return modal;modal=document.createElement('div');modal.id='s360-navigation-modal';modal.className='s360-preference-backdrop';modal.hidden=true;
 modal.innerHTML='<section class="s360-preference-dialog s360-navigation-dialog" role="dialog" aria-modal="true" aria-labelledby="s360-navigation-title"><header class="s360-preference-head"><div><span class="s360-preference-kicker">SOCIETY360 PREFERENCES</span><h2 id="s360-navigation-title"></h2><p id="s360-navigation-description"></p></div><button type="button" class="s360-preference-close" aria-label="Close">×</button></header><div class="s360-navigation-options"></div><label class="s360-navigation-collapse"><input type="checkbox" id="s360-navigation-collapsed"><span><strong></strong><small></small></span></label><footer class="s360-preference-foot"><span id="s360-navigation-status" role="status"></span><button type="button" class="s360-preference-done"></button></footer></section>';
 document.body.appendChild(modal);modal.querySelector('.s360-preference-close').addEventListener('click',closeModal);modal.querySelector('.s360-preference-done').addEventListener('click',closeModal);
 modal.addEventListener('click',event=>{if(event.target===modal)closeModal();});modal.querySelector('#s360-navigation-collapsed').addEventListener('change',event=>applyCollapsed(event.target.checked));
 document.addEventListener('keydown',event=>{if(event.key==='Escape'&&modal&&!modal.hidden){closeModal(true);event.preventDefault();}});
 return modal;
}
function renderModal(){
 const m=ensureModal();m.querySelector('#s360-navigation-title').textContent=t('Navigation Settings');m.querySelector('#s360-navigation-description').textContent=t('Choose how the application navigation is displayed.');
 const choices=[['left','Left sidebar','☰','A fixed navigation panel on the left.'],['right','Right sidebar','☷','A fixed navigation panel on the right.'],['top','Top navigation','▤','A horizontal navigation bar across the top.']];
 const box=m.querySelector('.s360-navigation-options');box.replaceChildren();
 choices.forEach(([code,title,icon,description])=>{const button=document.createElement('button');button.type='button';button.className='s360-navigation-choice'+(layout===code?' is-selected':'');button.setAttribute('aria-pressed',String(layout===code));
  const symbol=document.createElement('span');symbol.className='s360-navigation-choice__icon';symbol.textContent=icon;const name=document.createElement('strong');name.textContent=t(title);const detail=document.createElement('small');detail.textContent=t(description);const tick=document.createElement('span');tick.className='s360-navigation-choice__tick';tick.textContent=layout===code?'✓':'';
  button.append(symbol,name,detail,tick);button.addEventListener('click',()=>{applyLayout(code);renderModal();m.querySelector('#s360-navigation-status').textContent=t('Navigation layout updated.');});box.appendChild(button);
 });
 const toggle=m.querySelector('#s360-navigation-collapsed');toggle.checked=collapsed;toggle.disabled=layout==='top';m.querySelector('.s360-navigation-collapse strong').textContent=t('Compact sidebar');m.querySelector('.s360-navigation-collapse small').textContent=t('Use icons only to create more workspace.');m.querySelector('.s360-preference-done').textContent=t('Done');
}
function openSettings(){renderModal();modal.hidden=false;modal.querySelector('.s360-preference-close').focus();}
function closeModal(restore=true){if(!modal)return;modal.hidden=true;if(restore)nav.querySelector('[data-s360-pref-action="navigation"]')?.focus();}
function appendPreferences(){
 if(nav.querySelector('[data-s360-preferences]'))return;
 const group=document.createElement('details');group.className='nav-group s360-preferences-menu';group.dataset.s360Preferences='';
 const summary=document.createElement('summary');summary.textContent=t('Society Manager Preferences');summary.title=summary.textContent;summary.setAttribute('aria-label',summary.textContent);
 const submenu=document.createElement('div');submenu.className='nav-submenu';submenu.setAttribute('role','group');submenu.setAttribute('aria-label',summary.textContent);
 [['navigation','Navigation Settings','☷'],['themes','Themes','◐']].forEach(([action,label,icon])=>{const button=document.createElement('button');button.type='button';button.className='nav-item';button.dataset.s360PrefAction=action;
  const glyph=document.createElement('span');glyph.className='menu-icon';glyph.setAttribute('aria-hidden','true');glyph.textContent=icon;const text=document.createElement('span');text.className='menu-label';text.textContent=t(label);button.append(glyph,text);
  button.addEventListener('click',()=>{onNavigate();if(action==='navigation')openSettings();else window.dispatchEvent(new CustomEvent('s360:open-themes'));});submenu.appendChild(button);
 });
 group.append(summary,submenu);group.addEventListener('toggle',()=>{if(!group.open)return;closeOpenGroups(group);if(layout==='top')positionSubmenu(group);});nav.appendChild(group);
}
function refreshLanguage(){const group=nav.querySelector('[data-s360-preferences]');if(group){group.querySelector('summary').textContent=t('Society Manager Preferences');group.querySelectorAll('[data-s360-pref-action]').forEach(button=>{button.querySelector('.menu-label').textContent=t(button.dataset.s360PrefAction==='navigation'?'Navigation Settings':'Themes');});}nav.setAttribute('aria-label',t('Application navigation'));if(modal&&!modal.hidden)renderModal();}
nav.addEventListener('focusin',event=>{if(layout!=='top')return;const group=event.target.closest?.('#dbMenu details');if(group?.open){closeOpenGroups(group);positionSubmenu(group);}});
document.addEventListener('keydown',event=>{
 if(event.key==='Escape'){const openGroup=nav.querySelector('details[open]');if(openGroup){const summary=openGroup.querySelector(':scope > summary');closeOpenGroups();summary?.focus();event.preventDefault();return;}}
 if(layout==='top'&&(event.key==='ArrowRight'||event.key==='ArrowLeft')){const current=event.target.closest('#dbMenu > button, #dbMenu > details > summary');if(!current)return;const items=Array.from(nav.children).map(element=>element.matches('details')?element.querySelector(':scope > summary'):element).filter(Boolean);const index=items.indexOf(current);if(index<0)return;items[(index+(event.key==='ArrowRight'?1:-1)+items.length)%items.length]?.focus();event.preventDefault();}
 if(event.key==='ArrowDown'&&event.target.matches('#dbMenu summary')){const group=event.target.parentElement;group.open=true;positionSubmenu(group);group.querySelector('.nav-submenu button,.nav-submenu summary')?.focus();event.preventDefault();}
});
window.addEventListener('resize',()=>nav.querySelectorAll('details[open]').forEach(positionSubmenu));window.addEventListener('society360-language-changed',refreshLanguage);
observer=new MutationObserver(appendPreferences);observer.observe(nav,{childList:true});appendPreferences();
try{layout=validLayout(localStorage.getItem(layoutKey)||'left');collapsed=localStorage.getItem(collapsedKey)==='1';}catch{}
applyLayout(layout,false);applyCollapsed(collapsed,false);
window.NavigationLayout={applyLayout,applyCollapsed,positionSubmenu,onNavigate,openSettings,get layout(){return layout},get collapsed(){return collapsed}};
})();