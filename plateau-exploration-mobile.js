/* Exploration mobile : onglets de consultation, sans commande metier nouvelle. */
(() => {
  'use strict';
  const mq = window.matchMedia('(max-width: 1023px)');
  const vue = document.getElementById('vue-rue');
  const lieu = document.getElementById('loc-city');
  const pa = document.getElementById('r-pa');
  const argent = document.getElementById('r-arg');
  const actions = document.getElementById('actionbar');
  if (!vue || !actions) return;

  const labels = {
    fr:['Lieux visibles','Ordres','Informations'],en:['Visible places','Actions','Information'],
    es:['Lugares visibles','Acciones','Información'],ru:['Места','Действия','Информация'],
    de:['Sichtbare Orte','Aktionen','Informationen'],ko:['보이는 장소','행동','정보'],
    ar:['الأماكن','الإجراءات','معلومات'],pt:['Locais visíveis','Ações','Informações'],
    'zh-TW':['可見地點','操作','資訊']
  };
  const head = document.createElement('div'); head.className = 'hg-explore-head';
  const place = document.createElement('div'); place.className = 'hg-explore-place';
  const stats = document.createElement('div'); stats.className = 'hg-explore-stats';
  const paView = document.createElement('span');
  const argentView = document.createElement('span');
  stats.append(paView, argentView); head.append(place,stats);
  const bar = document.getElementById('hg-explore-primary') || document.createElement('nav');bar.className='hg-explore-tabs';
  const info = document.createElement('section');info.className='hg-explore-info';info.hidden=true;
  info.id='hg-explore-info';info.setAttribute('role','region');
  const infoTitle=document.createElement('strong');
  const infoDesc=document.createElement('div');
  info.append(infoTitle,infoDesc);
  const touches = Array.from({length:3}, (_,i) => {
    const b=bar.querySelector('[data-explore-tab="'+i+'"]') || document.createElement('button');b.type='button';
    b.setAttribute('aria-pressed','false'); b.dataset.exploreTab=String(i);
    b.addEventListener('click', () => {
      if (!mq.matches) return;
      touches.forEach((t,j)=>t.setAttribute('aria-pressed',String(i===j)));
      info.hidden=i!==2;
      if(i===0){
        const details=vue.querySelector('.hg-lieux-tactiles');
        if(details){details.open=true;details.scrollIntoView({block:'nearest',behavior:'smooth'});}
        else vue.querySelector('#rue-image')?.scrollIntoView({block:'start',behavior:'smooth'});
      }else if(i===1){actions.scrollIntoView({block:'nearest',behavior:'smooth'});}
      else info.scrollIntoView({block:'nearest',behavior:'smooth'});
    });
    if(!b.isConnected)bar.append(b);return b;
  });
  const scene = vue.querySelector('.rue-container');
  // Le menu doit etre visible AVANT le decor, sans defilement.
  scene?.before(head,info); if(bar.parentElement!==vue)head.after(bar);

  function traduire(){
    const langue=document.documentElement.lang||'fr';
    const code=labels[langue] ? langue : labels[langue.split('-')[0]] ? langue.split('-')[0] : 'fr';
    touches.forEach((b,i)=>b.textContent=labels[code][i]);
    bar.setAttribute('aria-label',labels[code][2]);
  }
  function contenu(){
    const nom=lieu?.textContent?.trim() || document.getElementById('city-name-display')?.textContent?.trim()
      || document.getElementById('rue-title')?.textContent?.trim() || '';
    place.textContent=nom;
    paView.textContent='PA : '+(pa?.textContent?.trim()||'—');
    argentView.textContent=argent?.textContent?.trim()||'—';
    const titre=document.getElementById('rue-title')?.textContent?.trim()||nom;
    const desc=document.getElementById('rue-desc')?.textContent?.trim()||'';
    infoTitle.textContent=titre;
    infoDesc.textContent=desc;
    infoDesc.hidden=!desc;
  }
  const observe = (node,fn) => node && new MutationObserver(fn).observe(node,{subtree:true,childList:true,characterData:true});
  [lieu,pa,argent,document.getElementById('rue-title'),document.getElementById('rue-desc')].forEach(n=>observe(n,contenu));
  new MutationObserver(traduire).observe(document.documentElement,{attributes:true,attributeFilter:['lang']});
  mq.addEventListener?.('change',()=>{if(!mq.matches){info.hidden=true;touches.forEach(b=>b.setAttribute('aria-pressed','false'));}});
  traduire();contenu();
})();
