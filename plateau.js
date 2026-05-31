/* ===========================
   RES PUBLICA — PLATEAU.JS
   =========================== */

let state = {
  pa:18, arg:4250, inf:25, pop:30, dis:85, hp:92, moral:78,
  day:1, hour:8, currentBuilding:null, char:null
};

/* ---- Init ---- */
window.addEventListener('DOMContentLoaded', () => {
  loadCharacter();
  updateUI();
  startClock();
});

function loadCharacter(){
  try {
    const saved = localStorage.getItem('respublica_char');
    if(saved){
      const char = JSON.parse(saved);
      state.char = char;
      state.arg = char.arg || 4250;
      state.inf = char.resources?.inf || 25;
      state.pop = char.resources?.pop || 30;
      state.dis = char.resources?.dis || 85;
      // Update UI with char info
      document.getElementById('char-name-display').textContent = char.name || 'Mon Personnage';
      const ar = ARCHETYPES.find(x=>x.id===char.archetype);
      const ca = CAREERS.find(x=>x.id===char.career);
      document.getElementById('char-role-display').textContent =
        `${ar?.name||'?'} - ${ca?.name||'?'}`;
      document.getElementById('char-fullname-left').textContent = char.name || 'Mon Personnage';
      const co = COUNTRIES[char.country];
      document.getElementById('char-arch-left').textContent =
        `${ar?.name||'?'} - ${co?.n||'?'}`;
      // Photo
      if(char.photoUrl){
        const photoEl = document.getElementById('char-photo-left');
        photoEl.innerHTML = `<img src="${char.photoUrl}" alt="Photo"/>`;
        const avatarEl = document.querySelector('.char-avatar');
        if(avatarEl) avatarEl.innerHTML = `<img src="${char.photoUrl}" alt="Photo"/>`;
      }
      // Stats mini grid
      const grid = document.getElementById('stat-mini-grid');
      if(grid && char.stats){
        grid.innerHTML = STAT_DEFS.map(({k,n})=>`
          <div class="stat-mini">
            <div class="stat-mini-name">${k}</div>
            <div class="stat-mini-val">${char.stats[k]||8}</div>
          </div>`).join('');
      }
      // Currency display
      if(co){
        document.getElementById('r-arg').textContent =
          state.arg.toLocaleString('fr-FR') + ' ' + co.cur;
      }
    }
  } catch(e) { console.warn('Erreur chargement personnage', e); }
}

/* ---- Clock ---- */
function startClock(){
  updateClock();
  setInterval(()=>{
    // Avance le temps toutes les 5 minutes reelles = 1 heure fictive
  }, 300000);
}
function updateClock(){
  const h = String(state.hour).padStart(2,'0');
  document.getElementById('game-time').textContent = `Jour ${state.day} - ${h}h00`;
}

/* ---- Map navigation ---- */
function switchCity(el, city){
  document.querySelectorAll('.map-tab').forEach(t=>t.classList.remove('active'));
  el.classList.add('active');
  const names = {
    capitale:'Luthecia, Capitale de Republia',
    'ville-a':'Port-Sainte-Marie, Region Ouest',
    'ville-b':'Montrouge, Region Nord'
  };
  document.getElementById('city-label').textContent = names[city] || city;
  // Reset active building
  document.querySelectorAll('.bld-group').forEach(g=>g.classList.remove('active'));
  state.currentBuilding = null;
  document.getElementById('action-context').textContent = 'SELECTIONNEZ UN BATIMENT SUR LA MAP POUR AGIR';
  document.getElementById('actions-row').innerHTML =
    '<div style="font-size:.78rem;color:#3a3020;font-style:italic;padding:.3rem">Cliquez sur un batiment pour voir les actions disponibles.</div>';
  document.getElementById('persons-list').innerHTML =
    '<div style="padding:.8rem;font-size:.75rem;color:#4a4030;font-style:italic;text-align:center">Selectionnez un batiment.</div>';
  document.getElementById('loc-name').textContent = 'Selectionnez un batiment';
  document.getElementById('loc-sub').textContent = '';
}

/* ---- Building modal ---- */
function openBuilding(id){
  const b = BUILDINGS[id];
  if(!b) return;
  // Update active building on map
  document.querySelectorAll('.bld-group').forEach(g=>g.classList.remove('active'));
  const bldEl = document.getElementById('bld-'+id);
  if(bldEl) bldEl.classList.add('active');
  state.currentBuilding = id;
  // Update left panel
  document.getElementById('loc-name').textContent = 'Capitale - ' + b.name;
  document.getElementById('loc-sub').textContent =
    b.cat + ' - ' + (b.persons?.length||0) + ' personne'+(b.persons?.length!==1?'s':'')+' presente'+(b.persons?.length!==1?'s':'');
  // Update action bar
  document.getElementById('action-context').textContent =
    'LIEU ACTUEL : ' + b.name.toUpperCase() + ' - ' + b.cat;
  updateActionBar(id);
  // Update persons list
  updatePersonsList(b.persons||[]);
  // Open modal
  document.getElementById('modal-title').textContent = b.name;
  document.getElementById('modal-body').innerHTML = buildModalBody(b);
  document.getElementById('modal').classList.add('open');
}

function buildModalBody(b){
  let html = `<div class="modal-desc">${b.desc}</div>`;
  if(b.locked){
    html += `<div style="text-align:center;padding:1rem;color:#5a3a30;border:1px solid #2a1a10;background:#0f0805;font-style:italic;font-size:.85rem">Acces restreint. Une invitation est necessaire pour entrer dans ce cercle.</div>`;
  }
  if(b.persons && b.persons.length > 0){
    const relCol = r => r==='ally'?'#4a8a4a':r==='enemy'?'#8a3a2a':'#6a6040';
    const relTxt = r => r==='ally'?'Allie':r==='enemy'?'Hostile':'Neutre';
    html += `<div class="modal-section-title">Personnes presentes</div>
      <div class="modal-persons">
        ${b.persons.map(p=>`
          <div class="modal-person">
            <div class="person-avatar"><i class="ti ti-user" style="font-size:.9rem"></i></div>
            <div>
              <div class="modal-person-name">${p.name}</div>
              <div class="modal-person-role">${p.role} - <span style="color:${relCol(p.rel)}">${relTxt(p.rel)}</span></div>
            </div>
          </div>`).join('')}
      </div>`;
  }
  html += `<div class="modal-section-title">Services disponibles</div>
    <div class="modal-services">
      ${b.services.map(s=>{
        if(b.locked && s.fn !== 'introduction_loge') return '';
        return`<div class="svc-btn" onclick="doOrderFromModal('${s.fn}','${s.name}')">
          <div>
            <div class="svc-name">${s.name}</div>
            <div class="svc-cost">${s.cost}</div>
          </div>
          <span class="svc-type ${s.type}">${s.type==='legal'?'LEGAL':s.type==='grey'?'GRIS':'ILLEGAL'}</span>
        </div>`;
      }).join('')}
    </div>`;
  return html;
}

function updateActionBar(buildingId){
  const b = BUILDINGS[buildingId];
  if(!b) return;
  const actions = b.actions || [];
  const deplBtn = `<button class="action-btn" style="border-color:#1a2a3a;color:#4a6a8a"
    onclick="closeModal();doOrder('deplacer',1,'Deplacement','Vous quittez ce lieu.')">
    <i class="ti ti-map-pin" style="font-size:.85rem"></i> Se deplacer <span class="pa-cost">1 PA</span>
  </button>`;
  document.getElementById('actions-row').innerHTML =
    actions.map(a=>`
      <button class="action-btn ${a.type}"
        onclick="closeModal();doOrder('${a.fn}',${a.pa},'${a.label}','Action executee.')">
        <i class="ti ${a.icon}" style="font-size:.85rem"></i> ${a.label}
        <span class="pa-cost">${a.pa} PA</span>
      </button>`).join('') + deplBtn;
}

function updatePersonsList(persons){
  const relCol = r => r==='ally'?'#4a8a4a':r==='enemy'?'#8a3a2a':'#6a6040';
  const relTxt = r => r==='ally'?'Allie':r==='enemy'?'Hostile':'Neutre';
  document.getElementById('persons-list').innerHTML = persons.length === 0
    ? '<div style="padding:.8rem;font-size:.75rem;color:#4a4030;font-style:italic;text-align:center">Aucune personne presente</div>'
    : persons.map(p=>`
        <div class="person-card">
          <div class="person-avatar"><i class="ti ti-user" style="font-size:.8rem"></i></div>
          <div>
            <div class="person-name">${p.name}</div>
            <div class="person-role">${p.role}</div>
            <div class="person-rel" style="color:${relCol(p.rel)};font-size:.6rem">
              <i class="ti ti-circle" style="font-size:.6rem"></i> ${relTxt(p.rel)}
            </div>
          </div>
        </div>`).join('');
}

function closeModal(){
  document.getElementById('modal').classList.remove('open');
}
document.getElementById('modal').addEventListener('click', function(e){
  if(e.target === this) closeModal();
});

/* ---- Orders ---- */
function doOrderFromModal(fn, name){
  closeModal();
  doOrder(fn, 2, name, 'Ordre transmis.');
}

function doOrder(fn, pa, name, defaultMsg){
  if(state.pa < pa){
    showToast('PA insuffisants', `Il vous manque ${pa-state.pa} PA pour cet ordre.`, false);
    return;
  }
  state.pa = Math.max(0, state.pa - pa);
  const roll = Math.floor(Math.random()*100)+1;
  let resultType, resultLabel;
  if(roll >= 85)     { resultType='crit';      resultLabel='Succes critique ! ('+roll+')'; }
  else if(roll >= 60){ resultType='success';   resultLabel='Succes ('+roll+')'; }
  else if(roll >= 40){ resultType='partial';   resultLabel='Succes partiel ('+roll+')'; }
  else if(roll >= 20){ resultType='fail';      resultLabel='Echec ('+roll+')'; }
  else               { resultType='crit-fail'; resultLabel='Echec critique ! ('+roll+')'; }

  const msg = getOrderMsg(fn, resultType, name);
  applyOrderEffects(fn, resultType);
  updateUI();

  const isGood = ['crit','success','partial'].includes(resultType);
  showToast(resultLabel, msg, isGood, resultType==='crit');
  addJournalEntry(name + ' - ' + resultLabel + '. ' + msg,
    resultType==='crit'||resultType==='success' ? 'event-good' :
    resultType==='crit-fail' ? 'event-bad' : '');
}

function getOrderMsg(fn, type, name){
  const msgs = {
    crit: {
      manger:'Repas excellent. +3 Moral, +5 Sante.',
      rencontrer:'Rencontre exceptionnelle. Nouveau contact ajoute au reseau.',
      diner:'Diner memorable. Relation fortement renforcee.',
      ecouter:'Information cle captee. Ajoutee a vos dossiers.',
      rumeur:'La rumeur se propage comme une trainee de poudre.',
      postuler:'Votre candidature est remarquee et retenue immediatement.',
      voter:'Votre vote est determinant. +3 Influence.',
      interview:'Interview triomphale. +15 Popularite.',
      soins:'Guerison complete et rapide. +30 Sante.',
      investir:'Investissement tres rentable. +20% de rendement.'
    },
    success: {
      manger:'Bon repas. Sante maintenue.',
      rencontrer:'Bonne rencontre. Contact potentiel.',
      diner:'Diner agreable. Relation amelioree.',
      ecouter:'Quelques informations utiles glanees.',
      rumeur:'La rumeur circule dans le lieu.',
      postuler:'Candidature deposee. Reponse attendue.',
      voter:'Vote enregistre.',
      interview:'Interview correcte. +5 Popularite.',
      soins:'+20 Sante.',
      investir:'Investissement realise.'
    },
    partial: {
      default:'L\'ordre s\'execute partiellement. Effet reduit.'
    },
    fail: {
      default:'L\'ordre echoue. Ressources perdues.'
    },
    'crit-fail': {
      rumeur:'La rumeur se retourne contre vous ! -10 Popularite.',
      rencontrer:'La rencontre tourne mal. Vous vous etes fait un ennemi.',
      corrompre_juge:'Le juge refuse ! Procedure ouverte contre vous.',
      corrompre_police:'Le policier vous denonce ! Risque d\'arrestation.',
      corrompre_journaliste:'Le journaliste publie l\'info que vous vouliez cacher !'
    }
  };
  return msgs[type]?.[fn] || msgs[type]?.default || `${name} - ${type}.`;
}

function applyOrderEffects(fn, resultType){
  const ef = ORDER_EFFECTS[fn] || {};
  const mult = resultType==='crit' ? 2 : resultType==='success' ? 1 :
               resultType==='partial' ? 0.5 : resultType==='fail' ? 0 : -1;

  // Special crit-fail overrides
  if(resultType==='crit-fail'){
    if(fn==='rumeur') { state.pop = Math.max(0, state.pop-10); updateUI(); return; }
    if(fn==='corrompre_juge') { state.dis = Math.max(0, state.dis-30); updateUI(); return; }
    if(fn==='corrompre_police') { state.dis = Math.max(0, state.dis-25); updateUI(); return; }
  }

  Object.entries(ef).forEach(([k,v])=>{
    if(v && state[k] !== undefined){
      const newVal = state[k] + Math.round(v * (k==='arg' ? (mult===0?0:1) : mult));
      state[k] = Math.max(0, Math.min(k==='arg' ? 9999999 : 100, newVal));
    }
  });
}

/* ---- UI Update ---- */
function updateUI(){
  const cur = state.char ? (COUNTRIES[state.char.country]?.cur || 'FR') : 'FR';
  document.getElementById('r-pa').textContent  = state.pa;
  document.getElementById('b-pa').style.width  = (state.pa/24*100)+'%';
  document.getElementById('r-arg').textContent = state.arg.toLocaleString('fr-FR')+' '+cur;
  document.getElementById('r-inf').textContent = state.inf;
  document.getElementById('b-inf').style.width = state.inf+'%';
  document.getElementById('r-pop').textContent = state.pop;
  document.getElementById('b-pop').style.width = state.pop+'%';
  document.getElementById('r-dis').textContent = state.dis;
  document.getElementById('b-dis').style.width = state.dis+'%';
  document.getElementById('r-hp').textContent  = state.hp;
  document.getElementById('b-hp').style.width  = state.hp+'%';
  document.getElementById('r-moral').textContent = state.moral;
  document.getElementById('b-moral').style.width  = state.moral+'%';
}

/* ---- Toast ---- */
function showToast(result, msg, success, isCrit){
  const t = document.getElementById('result-toast');
  const r = document.getElementById('toast-result');
  const s = document.getElementById('toast-sub');
  t.className = isCrit ? 'toast-crit' : success ? 'toast-success' : 'toast-fail';
  r.textContent = result;
  s.textContent = msg;
  t.style.display = 'block';
  clearTimeout(window._toastTimer);
  window._toastTimer = setTimeout(()=>{ t.style.display='none'; }, 3500);
}

/* ---- Journal ---- */
function addJournalEntry(text, cls){
  const j = document.getElementById('journal');
  const h = String(state.hour).padStart(2,'0');
  const div = document.createElement('div');
  div.className = 'journal-entry';
  div.innerHTML = `<span class="journal-time">Jour ${state.day} - ${h}h00</span>
    <span class="journal-text ${cls||''}">${text}</span>`;
  j.insertBefore(div, j.firstChild);
}
