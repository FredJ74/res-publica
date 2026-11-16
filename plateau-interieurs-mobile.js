/* Intérieurs mobiles : commandes de consultation seulement, données reprises du DOM métier. */
(() => {
  'use strict';
  const mobile=window.matchMedia('(max-width:1023px)');
  const vue=document.getElementById('vue-batiment');
  const header=vue?.querySelector('.batiment-header');
  const rooms=vue?.querySelector('#pieces-tabs');
  const actionbar=vue?.querySelector('#actionbar-batiment');
  const image=vue?.querySelector('#piece-image');
  if(!vue||!header||!rooms||!actionbar||!image)return;

  const traductions={
    fr:['Pièces','Ordres','Informations'],en:['Rooms','Actions','Information'],
    es:['Salas','Acciones','Información'],de:['Räume','Aktionen','Informationen'],
    ru:['Комнаты','Действия','Информация'],ko:['공간','행동','정보'],
    ar:['الغرف','الأوامر','معلومات'],pt:['Salas','Ações','Informações'],
    'zh-TW':['房間','操作','資訊']
  };
  const nav=document.createElement('nav');nav.className='hg-room-tabs';
  const info=document.createElement('section');info.className='hg-room-info';
  info.id='hg-room-info';info.setAttribute('role','region');info.hidden=true;
  const title=document.createElement('strong');const desc=document.createElement('div');
  info.append(title,desc);
  const buttons=Array.from({length:3},(_,i)=>{
    const button=document.createElement('button');
    button.type='button';button.dataset.roomTab=String(i);
    button.setAttribute('aria-pressed','false');
    button.addEventListener('click',()=>{
      if(!mobile.matches)return;
      buttons.forEach((b,j)=>b.setAttribute('aria-pressed',String(i===j)));
      info.hidden=i!==2;
      if(i===0)rooms.scrollIntoView({block:'nearest',behavior:'smooth'});
      if(i===1)actionbar.scrollIntoView({block:'nearest',behavior:'smooth'});
      if(i===2)info.scrollIntoView({block:'nearest',behavior:'smooth'});
    });
    nav.append(button);return button;
  });
  // Afficher les acces des l'entree dans le batiment, pas apres l'image.
  header.after(nav,info);

  function translate(){
    const lang=document.documentElement.lang||'fr';
    const key=traductions[lang]?lang:traductions[lang.split('-')[0]]?lang.split('-')[0]:'fr';
    buttons.forEach((b,i)=>b.textContent=traductions[key][i]);
    nav.setAttribute('aria-label',traductions[key][2]);
  }
  const roomName=document.getElementById('piece-nom');
  const roomDesc=document.getElementById('piece-desc');
  function update(){
    title.textContent=roomName?.textContent?.trim() || document.getElementById('bat-nom')?.textContent?.trim() || '';
    desc.textContent=roomDesc?.textContent?.trim() || '';
    desc.hidden=!desc.textContent;
  }
  const watch=(node,fn)=>node&&new MutationObserver(fn).observe(node,{subtree:true,childList:true,characterData:true});
  watch(roomName,update);watch(roomDesc,update);
  new MutationObserver(translate).observe(document.documentElement,{attributes:true,attributeFilter:['lang']});
  mobile.addEventListener?.('change',()=>{if(!mobile.matches){info.hidden=true;buttons.forEach(b=>b.setAttribute('aria-pressed','false'));}});
  translate();update();
})();
