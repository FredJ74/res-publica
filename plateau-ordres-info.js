// Descriptions des ordres sur écran tactile. Présentation locale uniquement.
// Les boutons d'ordre et leurs handlers restent les nœuds d'origine.
(function(global){
  'use strict';
  const doc=global.document, tactile=global.matchMedia('(any-pointer: coarse)');
  let dialog, heading, content, closeButton, origin=null, scrollers=[], scheduled=false;
  const sources=new WeakMap();
  const label=key=>global.i18next?.t('plateau.'+key,{defaultValue:key==='description'?'Description':'Fermer'})
    ||(key==='description'?'Description':'Fermer');
  function orderName(button){
    const name=button.querySelector('[data-rp-order-fn]');
    if(name)return name.textContent.trim();
    const clone=button.cloneNode(true);
    clone.querySelectorAll('.pa-cost,.action-gain,i').forEach(n=>n.remove());
    return clone.textContent.trim();
  }
  function descriptor(button){
    try{return JSON.parse(decodeURIComponent(button.getAttribute('data-rp-tip')||''));}catch(_){return null;}
  }
  function refreshOpen(){
    if(!dialog?.open||!origin)return;
    const button=sources.get(origin);
    if(!button?.isConnected){dialog.close();return;}
    dialog.dir=global.RP_I18N_GAME_ENABLED===true&&global.RPPlateauI18n?.language?.()==='ar'?'rtl':'ltr';
    heading.textContent=label('description')+' — '+orderName(button);
    closeButton.textContent=label('closeButton');
    const p=descriptor(button),parts=[];
    if(p?.blocage)parts.push(p.blocage);
    const tooltip=button.getAttribute('title')||'';
    if(tooltip)parts.push(tooltip);
    // Pour une infobulle remplacée par un motif de blocage, conserver aussi
    // les détails d'affichage déjà calculés. Aucune condition n'est réévaluée.
    if(p?.details&&global.RPSovarkaInfobullesI18n){
      const detail=global.RPSovarkaInfobullesI18n.infobulle(p.details);
      if(detail&&!parts.includes(detail))parts.push(detail);
    }
    content.textContent=[...new Set(parts)].join('\n\n').replaceAll(' | ','\n\n');
  }
  function createDialog(){
    if(dialog)return;
    dialog=doc.createElement('dialog');
    dialog.className='modal-box cpj-dialogue rp-order-info-dialog';
    dialog.setAttribute('aria-labelledby','rp-order-info-heading');
    heading=doc.createElement('h2');heading.id='rp-order-info-heading';heading.className='modal-title';
    content=doc.createElement('div');content.className='rp-order-info-content';content.id='rp-order-info-content';
    dialog.setAttribute('aria-describedby',content.id);
    closeButton=doc.createElement('button');closeButton.type='button';closeButton.className='cpj-touche';
    closeButton.addEventListener('click',()=>dialog.close());
    dialog.append(heading,content,closeButton);doc.body.append(dialog);
    dialog.addEventListener('close',()=>{
      const previous=origin;origin=null;
      for(const [element,x,y]of scrollers){if(element.isConnected){element.scrollLeft=x;element.scrollTop=y;}}
      scrollers=[];
      if(previous?.isConnected)previous.focus({preventScroll:true});
    });
    dialog.addEventListener('click',event=>{
      if(event.target!==dialog)return;
      const r=dialog.getBoundingClientRect();
      if(event.clientX<r.left||event.clientX>r.right||event.clientY<r.top||event.clientY>r.bottom)dialog.close();
    });
  }
  function open(info){
    if(!tactile.matches||dialog?.open)return;
    const button=sources.get(info);if(!button?.isConnected)return;
    createDialog();origin=info;scrollers=[];
    for(let e=info.parentElement;e;e=e.parentElement)if(e.scrollHeight>e.clientHeight||e.scrollWidth>e.clientWidth)scrollers.push([e,e.scrollLeft,e.scrollTop]);
    // Le dialogue natif reste au-dessus des fenêtres existantes, qui ne sont
    // ni remplacées ni fermées. Le navigateur rend leur contenu inerte.
    dialog.showModal();refreshOpen();closeButton.focus({preventScroll:true});
  }
  function refresh(){
    if(!tactile.matches)return;
    for(const info of doc.querySelectorAll('.rp-order-info-button')){
      const button=sources.get(info);if(!button)continue;
      info.setAttribute('aria-label',label('description')+' — '+orderName(button));
    }
    refreshOpen();
  }
  function enhance(){
    scheduled=false;
    if(!tactile.matches)return;
    for(const button of doc.querySelectorAll('.action-btn')){
      if(button.parentElement?.classList.contains('rp-order-info-row'))continue;
      if(!button.hasAttribute('title')&&!button.querySelector('[data-rp-order-fn]'))continue;
      const row=doc.createElement('div');row.className='rp-order-info-row';
      const info=doc.createElement('button');info.type='button';info.className='cpj-touche rp-order-info-button';
      info.textContent='ⓘ';info.setAttribute('aria-haspopup','dialog');
      info.setAttribute('aria-label',label('description')+' — '+orderName(button));
      sources.set(info,button);
      // Un vrai bouton frère : il reste disponible même si l'ordre est disabled.
      info.addEventListener('click',event=>{event.preventDefault();event.stopPropagation();open(info);});
      button.before(row);row.append(button,info);
    }
    refreshOpen();
  }
  const observer=new MutationObserver(records=>{
    if(!tactile.matches||scheduled||records.every(r=>dialog?.contains(r.target)))return;
    scheduled=true;global.queueMicrotask(enhance);
  });
  function mode(){
    if(tactile.matches){enhance();return;}
    if(dialog?.open)dialog.close();
    for(const row of doc.querySelectorAll('.rp-order-info-row')){
      const button=row.querySelector('.action-btn');if(button)row.replaceWith(button);else row.remove();
    }
  }
  // Ne pas laisser le piège clavier d'une fenêtre située dessous fermer cette
  // fenêtre ou voler le focus du dialogue natif. Aucun autre raccourci changé.
  doc.addEventListener('keydown',event=>{
    if(!dialog?.open)return;
    if(event.key==='Escape'||event.key==='Tab'){
      event.preventDefault();event.stopImmediatePropagation();
      if(event.key==='Escape')dialog.close();else closeButton.focus({preventScroll:true});
    }
  },true);
  tactile.addEventListener('change',mode);
  // Le rappel s'exécute après ceux qui traduisent les libellés et data-rp-tip.
  (global.RP_I18N_CHANGE_CALLBACKS=global.RP_I18N_CHANGE_CALLBACKS||[]).push(refresh);
  observer.observe(doc.body,{childList:true,subtree:true});mode();
})(window);
