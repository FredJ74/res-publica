/* Vue de présences mobile — projection de la liste réellement rendue par le jeu.
   Aucun chargement de personnes alternatif, aucun ordre ni profil inventé. */
(() => {
  'use strict';
  const rue = document.getElementById('vue-rue');
  const source = document.getElementById('persons-list-rue');
  const ambiance = document.getElementById('rue-ambiance');
  const onglets = document.getElementById('hg-explore-primary');
  if (!rue || !source || !ambiance || !onglets) return;
  const langues = {
    fr:['personne ici','personnes ici',"Personne ici pour l’instant"],
    en:['person here','people here','Nobody here for now'],
    es:['persona aquí','personas aquí','No hay nadie aquí por ahora'],
    ru:['человек здесь','человек здесь','Пока здесь никого нет'],
    de:['Person hier','Personen hier','Im Moment ist niemand hier'],
    ko:['명 있음','명 있음','지금은 아무도 없습니다'],
    ar:['شخص هنا','أشخاص هنا','لا أحد هنا حالياً'],
    'pt-BR':['pessoa aqui','pessoas aqui','Ninguém aqui por enquanto'],
    'zh-TW':['人在這裡','人在這裡','目前沒有人在這裡']
  };
  const carte = document.createElement('section');
  carte.id='hg-presences-mobiles';
  carte.setAttribute('aria-label','Personnes présentes');
  const total=document.createElement('strong');total.className='hg-presences-total';
  const rail=document.createElement('div');rail.className='hg-presences-rail';
  rail.setAttribute('role','group');
  carte.append(total,rail);
  ambiance.after(carte);
  const versCode=()=>{const lang=document.documentElement.lang||'fr';return langues[lang]?lang:langues[lang.split('-')[0]]?lang.split('-')[0]:'fr'};
  function render(){
    const [singulier,pluriel,vide]=langues[versCode()];
    const ancienDefilement=rail.scrollLeft;
    const focusNom=document.activeElement?.closest?.('.hg-presence-personne')?.getAttribute('aria-label')||null;
    rail.replaceChildren();
    // La liste source est filtrée par les règles existantes (masquage et droits).
    // On n'ajoute ni caméra, ni présence virtuelle, ni le PJ lui-même.
    const personnes=[...source.querySelectorAll('.person-card')].filter(el =>
      !el.querySelector('.person-name span')?.textContent?.includes('[SIM]') &&
      !el.textContent.includes('(Vous)') &&
      !el.closest('[hidden], [aria-hidden="true"]') &&
      !el.classList.contains('hg-personne-cachee')
    );
    personnes.forEach(origin=>{
      const nom=origin.querySelector('.person-name')?.textContent?.trim();
      if(!nom) return;
      const button=document.createElement('button');
      button.type='button';button.className='hg-presence-personne';
      button.setAttribute('aria-label',nom);button.title=nom;
      const portrait=document.createElement('span');portrait.className='hg-presence-portrait';
      const avatar=origin.querySelector('.person-avatar');
      if(avatar){
        const image=avatar.querySelector('img');
        if(image){
          const img=document.createElement('img');
          img.src=image.currentSrc||image.getAttribute('src')||'';
          img.alt='';img.loading='lazy';img.decoding='async';
          img.style.objectPosition=image.style.objectPosition||'center';
          portrait.append(img);
        } else {
          const icon=avatar.querySelector('i');
          if(icon){const i=document.createElement('i');i.className=icon.className;portrait.append(i);}
        }
      }
      const label=document.createElement('span');label.className='hg-presence-nom';label.textContent=nom;
      button.append(portrait,label);
      // Délègue à la carte existante : la fenêtre PNJ/PJ fournit ses vrais gestes.
      button.addEventListener('click',()=>{if(origin.isConnected)origin.click();});
      rail.append(button);
    });
    const nombre=rail.children.length;
    total.textContent=nombre ? nombre+' '+(nombre===1?singulier:pluriel):vide;
    rail.scrollLeft=ancienDefilement;
    if(focusNom){
      const suivant=[...rail.querySelectorAll('.hg-presence-personne')].find(b=>b.getAttribute('aria-label')===focusNom);
      suivant?.focus({preventScroll:true});
    }
    if(!nombre){
      total.textContent=vide;
      const empty=document.createElement('span');empty.className='hg-presences-vide';empty.textContent=vide;rail.append(empty);
    }
  }
  let planned=false;
  const observer=new MutationObserver(()=>{
    if(planned)return;planned=true;
    requestAnimationFrame(()=>{planned=false;render()});
  });
  observer.observe(source,{childList:true,subtree:true,characterData:true});
  new MutationObserver(render).observe(document.documentElement,{attributes:true,attributeFilter:['lang']});
  render();
})();
