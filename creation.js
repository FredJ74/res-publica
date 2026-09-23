
// =====================
// RETROUVER MON PERSONNAGE
// =====================
// =====================================================================
// ME CONNECTER A MON COMPTE (Lot 2, 21 septembre 2026)
// =====================================================================
// Parcours inverse du Lot 1. Un joueur qui a securise son personnage doit pouvoir le retrouver
// depuis n'importe quel navigateur -- y compris un navigateur vierge, qui aura deja recu
// automatiquement une session ANONYME avant qu'il ne pense a se connecter.
//
// LA DIFFERENCE DE FOND AVEC « RETROUVER MON PERSONNAGE ». Celui-ci part d'un NOM, public, et
// doit donc interroger le serveur pour savoir si l'appelant a le droit d'y toucher. Ici on part
// d'un COMPTE : on s'authentifie, puis on DEMANDE au serveur quel personnage ce compte possede.
// Le joueur ne designe jamais de personnage. Aucune revendication par le nom n'est possible.
//
// LE PERSONNAGE N'EST JAMAIS DEPLACE. Rien n'ecrit personnages_donnees.user_id : on ne transfere
// pas la fiche vers la session anonyme courante, on ABANDONNE cette session au profit de celle
// qui possede deja la fiche.
function ouvrirConnexionCompte() {
  const panel = document.getElementById('connexion-panel');
  if (!panel) return;
  const ouvert = panel.style.display !== 'none';
  panel.style.display = ouvert ? 'none' : 'block';
  // Le panneau « Retrouver mon personnage » se referme : deux formulaires ouverts cote a cote
  // pretent a confusion, d'autant qu'ils repondent a la meme question par deux chemins.
  const autre = document.getElementById('retrouver-panel');
  if (autre && !ouvert) autre.style.display = 'none';
  if (!ouvert) document.getElementById('connexion-email')?.focus();
}

async function connecterAvecMotDePasse() {
  const msg = document.getElementById('connexion-msg');
  const email = (document.getElementById('connexion-email')?.value || '').trim();
  const mdp = document.getElementById('connexion-mdp')?.value || '';
  const dire = (texte, erreur) => { if (msg) { msg.textContent = texte; msg.style.color = erreur ? '#8a3a2a' : '#4a8a4a'; } };

  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) { dire('Cette adresse n\'est pas valide.', true); return; }
  if (!mdp) { dire('Saisissez votre mot de passe.', true); return; }
  if (typeof rpAuthSeConnecter !== 'function' || typeof sbRpc !== 'function') {
    dire('Service momentanément indisponible.', true); return;
  }

  const bouton = document.getElementById('connexion-valider');
  if (bouton) { bouton.disabled = true; bouton.style.opacity = '.5'; }
  dire('Connexion…', false);

  const r = await rpAuthSeConnecter(email, mdp).catch(() => null);
  if (!r || r.ok !== true) {
    // MESSAGE UNIFORME. Le serveur distingue « adresse inconnue » et « mot de passe faux » ;
    // le repeter permettrait de tester quelles adresses possedent un compte. On ne renvoie donc
    // qu'une seule formulation pour ces deux cas, et on ne montre jamais la reponse technique.
    const motifs = {
      validation_failed: 'Cette adresse n\'est pas valide.',
      over_request_rate_limit: 'Trop de tentatives. Réessayez dans un instant.'
    };
    dire((r && motifs[r.raison]) || 'Adresse ou mot de passe incorrect.', true);
    if (bouton) { bouton.disabled = false; bouton.style.opacity = '1'; }
    return;
  }

  // C'EST LE SERVEUR QUI NOMME LE PERSONNAGE, jamais le joueur. mon_personnage() est fondee sur
  // auth.uid() : elle ne peut rendre que la fiche du compte qui vient de s'authentifier.
  let nom = null;
  try {
    const rep = await sbRpc('mon_personnage', {});
    nom = (rep === null || rep === undefined) ? null : (Array.isArray(rep) ? rep[0] : rep);
    if (nom && typeof nom === 'object') nom = nom.mon_personnage ?? null;
  } catch (e) { nom = null; }

  if (!nom) {
    dire('Connexion réussie, mais ce compte ne porte aucun personnage. Vous pouvez en créer un.', true);
    if (bouton) { bouton.disabled = false; bouton.style.opacity = '1'; }
    return;
  }

  const sbState = await sbLoadPersonnage(nom).catch(() => null);
  if (!sbState) { dire('Personnage introuvable sur le serveur.', true);
                  if (bouton) { bouton.disabled = false; bouton.style.opacity = '1'; } return; }

  // Hydratation du cache local, a l'identique de chargerPersonnageParNom ci-dessous : meme
  // format, memes cles. On ecrase aussi la cle generique `respublica_char`, sans quoi
  // loadCharacter() retomberait dessus -- et afficherait le personnage d'AVANT la connexion --
  // quand ce navigateur n'a pas encore de cache au nom du proprietaire.
  const charData = {
    ...sbState.char,
    country: sbState.country,
    currentCity: sbState.currentCity,
    arg: sbState.arg,
    resources: { inf: sbState.inf, pop: sbState.pop, dis: sbState.dis }
  };
  try {
    localStorage.setItem('respublica_char_' + charData.name, JSON.stringify(charData));
    localStorage.setItem('respublica_char', JSON.stringify(charData));
    localStorage.setItem('respublica_last_char', charData.name);
    if (sbState.char?.photoUrl) {
      localStorage.setItem('respublica_photo_' + charData.name, sbState.char.photoUrl);
      localStorage.setItem('respublica_photo', sbState.char.photoUrl);
    }
  } catch (e) { console.warn('Cache local non ecrit (quota) :', e); }

  dire('Bienvenue, ' + charData.name + '. Chargement…', false);
  // REDIRECTION PLUTOT QUE RECHARGEMENT EN PLACE. loadCharacter() ne s'execute qu'au
  // DOMContentLoaded et porte toute la reconciliation -- position, journal, portillon
  // d'identite, interface. La rejouer a chaud demanderait de la reimplementer, sur un etat qui
  // appartient encore au personnage precedent. Entrer par la porte normale est plus sur, et le
  // joueur n'a rien a recharger lui-meme.
  setTimeout(() => { window.location.href = 'plateau.html'; }, 700);
}

// =====================================================================
// RETOUR DE CONFIRMATION D'ADRESSE (Lot 3b comptes PJ, 22 septembre 2026)
// =====================================================================
// Supabase renvoie le joueur sur la Site URL -- donc ICI -- apres le clic dans le courriel de
// confirmation, en deposant le resultat dans le FRAGMENT de l'URL (#access_token=...&type=... ou
// #error=...). Deux choses sont a faire, et une troisieme est deliberement NON faite.
//
// 1. EFFACER LE FRAGMENT IMMEDIATEMENT. Il contient un access_token et un refresh_token en clair.
//    Tant qu'ils restent dans la barre d'adresse, ils partent dans l'historique du navigateur,
//    dans un partage d'ecran, dans un copier-coller d'URL. On les retire de l'URL des la premiere
//    instruction utile, avec history.replaceState pour ne pas ajouter d'entree d'historique.
//
// 2. DIRE AU JOUEUR OU IL EN EST, et le mener au seul chemin qui marche : « Me connecter a mon
//    compte », le formulaire du Lot 2. Sans ce message il arriverait sur un accueil muet, en
//    croyant que le clic a echoue.
//
// 3. CE QU'ON NE FAIT PAS : adopter la session portee par le fragment. Ce point est mis en
//    attente d'arbitrage, et l'abstention est ici le choix SUR. Adopter cette session ecraserait
//    RP_AUTH_SESSION dans le localStorage de CET appareil. Si un autre joueur y a un personnage
//    ouvert sur un compte ANONYME -- appareil familial, tablette partagee --, son jeton anonyme
//    n'existe nulle part ailleurs : l'ecraser rend son personnage definitivement irrecuperable.
//    Le confort d'un joueur ne peut pas se payer de la perte seche du personnage d'un autre.
//    Se connecter avec l'adresse et le mot de passe qu'il vient justement de confirmer coute au
//    joueur dix secondes, et ne detruit rien.
function rpRetourConfirmation() {
  let frag = '';
  try { frag = (window.location.hash || '').replace(/^#/, ''); } catch (e) { return; }
  if (!frag) return;

  let p;
  try { p = new URLSearchParams(frag); } catch (e) { return; }
  const type   = p.get('type');
  const erreur = p.get('error_code') || p.get('error');
  const jeton  = p.get('access_token');
  // Fragment etranger au parcours Auth (ancre de page, etc.) : on n'y touche pas.
  if (!erreur && !jeton && !type) return;

  // Effacement du fragment AVANT tout affichage. replaceState ne recharge pas la page et ne
  // laisse pas l'URL porteuse de jetons dans l'historique.
  try {
    window.history.replaceState(null, '', window.location.pathname + window.location.search);
  } catch (e) { try { window.location.hash = ''; } catch (e2) {} }

  const zone = document.getElementById('retour-confirmation');
  if (!zone) return;

  const cadre = 'padding:.8rem .9rem;margin-bottom:.9rem;border-left:3px solid ';
  if (erreur) {
    // otp_expired, access_denied... On ne montre jamais le code technique.
    zone.innerHTML = '<div style="' + cadre + '#8a4a38;background:rgba(138,74,56,.12)">'
      + '<div style="font-weight:600;margin-bottom:.2rem">Ce lien de confirmation n\'est plus valable.</div>'
      + '<div style="font-size:.9rem;line-height:1.5">Il a expiré, ou une adresse plus récente l\'a remplacé. '
      + 'Rouvrez votre personnage sur l\'appareil où vous jouez et demandez un nouveau courriel.</div></div>';
    zone.style.display = 'block';
    return;
  }

  zone.innerHTML = '<div style="' + cadre + '#4a8a4a;background:rgba(74,138,74,.12)">'
    + '<div style="font-weight:600;margin-bottom:.2rem">Votre adresse e-mail est confirmée.</div>'
    + '<div style="font-size:.9rem;line-height:1.5">Votre personnage est désormais rattaché à votre compte. '
    + 'Connectez-vous ci-dessous avec cette adresse et votre mot de passe pour le retrouver, '
    + 'sur cet appareil ou sur n\'importe quel autre.</div></div>';
  zone.style.display = 'block';
  // ouvrirConnexionCompte est une BASCULE : l'appeler sur un panneau deja ouvert (arrivee avec
  // ?connexion=1) le refermerait. On ne l'appelle donc que s'il est ferme.
  const panel = document.getElementById('connexion-panel');
  if (panel && panel.style.display === 'none') ouvrirConnexionCompte();
}

// Ouverture directe depuis le bandeau de rupture d'identite du plateau, qui renvoie ici avec
// ?connexion=1 plutot que de dupliquer le formulaire. Le joueur arrive donc sur l'ecran deja
// deplie, sans avoir a chercher le bouton.
window.addEventListener('DOMContentLoaded', () => {
  try {
    if (new URLSearchParams(window.location.search).get('connexion') === '1') {
      ouvrirConnexionCompte();
    }
  } catch (e) {}
  try { rpRetourConfirmation(); } catch (e) {}
});

function retrouverPersonnage() {
  const panel = document.getElementById('retrouver-panel');
  panel.style.display = panel.style.display === 'none' ? 'block' : 'none';
}

async function chargerPersonnageParNom() {
  const nom = document.getElementById('retrouver-nom')?.value?.trim();
  const msg = document.getElementById('retrouver-msg');
  if (!nom) { msg.textContent = t('home.findCharacterEnterName'); return; }

  msg.style.color = '#8a8060';
  msg.textContent = t('home.findCharacterSearching');

  // Chercher dans Supabase
  if (typeof sbLoadPersonnage !== 'function') {
    msg.style.color = '#8a3a2a';
    msg.textContent = t('home.findCharacterUnavailable');
    return;
  }

  try {
    const sbState = await sbLoadPersonnage(nom);
    if (!sbState) {
      msg.style.color = '#8a3a2a';
      msg.textContent = t('home.findCharacterNotFound');
      return;
    }

    // CONTROLE DE PROPRIETE (chantier B, 14 septembre 2026).
    // « Retrouver mon personnage » n'exigeait qu'une chose : connaitre le nom -- lequel est
    // public, puisque sbListPersonnages() le diffuse a tout le monde. N'importe qui pouvait
    // donc prendre la main sur n'importe quel personnage. Desormais le serveur tranche : soit
    // ce personnage appartient deja a ce compte, soit il n'appartient a personne et lui est
    // rattache maintenant, soit il est a quelqu'un d'autre et l'acces est refuse.
    if (typeof rpAuthAssurerSession === 'function' && typeof rpAuthRattacherPersonnage === 'function') {
      const session = await rpAuthAssurerSession().catch(() => null);
      if (session) {
        const verdict = await rpAuthRattacherPersonnage(nom).catch(() => null);
        if (verdict && verdict.ok === false) {
          msg.style.color = '#8a3a2a';
          if (verdict.raison === 'personnage_deja_possede') {
            msg.textContent = 'Ce personnage appartient deja a un autre compte. '
              + 'Si c\'est le votre, reconnectez-vous depuis l\'appareil ou le compte d\'origine.';
          } else if (verdict.raison === 'compte_deja_pourvu') {
            msg.textContent = 'Ce navigateur possede deja le personnage « ' + (verdict.personnage || '') + ' ». '
              + 'Un compte ne peut porter qu\'un seul personnage.';
          } else if (/^http_/.test(verdict.raison || '')) {
            // PANNE DE LA VERIFICATION, PAS UN VERDICT DE PROPRIETE (incident du 15 septembre
            // 2026). La RPC rattacher_personnage n'avait jamais ete creee en base : PostgREST
            // repondait 404, auth.js traduisait en 'http_404' et le joueur lisait « Acces
            // refuse (http_404) » -- un message qui accusait le joueur d'un probleme de droits
            // alors que le serveur n'avait tout simplement pas repondu.
            // On continue de REFUSER : ceder ici rouvrirait la prise de controle de n'importe
            // quel personnage par la seule connaissance de son nom, qui est public. Mais on ne
            // fait plus passer une indisponibilite pour un refus d'acces.
            msg.textContent = 'Vérification de propriété momentanément indisponible ('
              + verdict.raison + '). Votre personnage est intact, réessayez dans un instant.';
          } else {
            msg.textContent = 'Acces refuse (' + (verdict.raison || 'inconnu') + ').';
          }
          return;
        }
      }
    }

    // Sauvegarder dans localStorage avec position complète
    const charData = {
      ...sbState.char,
      country: sbState.country,
      currentCity: sbState.currentCity,
      arg: sbState.arg,
      resources: { inf: sbState.inf, pop: sbState.pop, dis: sbState.dis }
    };
    try {
      localStorage.setItem('respublica_char_' + charData.name, JSON.stringify(charData));
      localStorage.setItem('respublica_char', JSON.stringify(charData));
    } catch (e) {
      console.warn('Cache local personnage non sauvegarde (quota depasse) :', e);
    }
    localStorage.setItem('respublica_last_char', charData.name);
    if (sbState.char?.photoUrl) {
      localStorage.setItem('respublica_photo_' + sbState.char.name, sbState.char.photoUrl);
      localStorage.setItem('respublica_photo', sbState.char.photoUrl);
    }

    msg.style.color = '#4a8a4a';
    msg.textContent = t('home.findCharacterFound', { name: nom });

    setTimeout(() => { window.location.href = 'plateau.html'; }, 1000);

  } catch(e) {
    msg.style.color = '#8a3a2a';
    msg.textContent = t('home.findCharacterConnectionError');
  }
}

/* ===========================
   RES PUBLICA — CREATION.JS
   =========================== */

// Accesseur defensif a i18next (Lot 2, i18n) : jamais un second moteur de traduction (i18next
// reste le seul), simplement un repli identique au style deja utilise partout dans ce code
// (typeof X === 'function') pour le cas, en pratique jamais observe vu l'ordre de chargement des
// scripts (index.html : i18next -> resources -> i18n-init -> data.js -> creation.js), ou
// i18next ne serait pas encore pret. Retombe sur la cle brute plutot que de planter l'ecran.
function t(key, opts) {
  return (typeof i18next !== 'undefined' && i18next.isInitialized) ? i18next.t(key, opts) : key;
}

let G = {
  country:null, origin:null, school:null, archetype:null, career:null,
  freeStats:{INT:0,CHA:0,VOL:0,PER:0,DUP:0,ENT:0}, freePts:30,
  photoUrl:null, name:'', bio:'', motto:''
};

/* ---- Navigation ---- */
// Ecran actuellement affiche (Lot 2 i18n) : suivi uniquement pour permettre le rafraichissement
// de l'ecran dynamique visible lors d'un changement de langue (voir
// rafraichirEcranCreationApresChangementLangue ci-dessous) -- n'affecte en rien la navigation
// normale, qui continue de fonctionner exactement comme avant.
let _currentScreenIndex=0;
function goTo(n){
  _currentScreenIndex=n;
  document.querySelectorAll('.screen').forEach(s=>s.classList.remove('active'));
  const ids=['intro','s1','s2','s3','s4','s5','s6','s7','s8','s9'];
  document.getElementById(ids[n]).classList.add('active');
  window.scrollTo(0,0);
  if(n===1) renderCountry();
  if(n===2) renderOrigin();
  if(n===3) renderSchool();
  if(n===4) renderArch();
  if(n===5) renderCareer();
  if(n===6) renderStatsUI();
  if(n===8) renderReview();
  if(n===9) renderSuccess();
  for(let i=1;i<=7;i++){
    const d=document.getElementById('dots'+i);
    if(d) d.innerHTML=Array.from({length:7},(_,j)=>
      `<div class="dot ${j<i-1?'dn':j===i-1?'act':''}"></div>`).join('');
  }
}

// Rafraichissement lors d'un changement de langue (Lot 2 i18n) : re-rend UNIQUEMENT l'ecran
// dynamique actuellement visible, en reutilisant exactement le meme aiguillage que goTo()
// ci-dessus -- jamais goTo() lui-meme (qui changerait d'ecran/reinitialiserait les dots). Les
// render*() appeles ici ne font que LIRE l'etat G existant et reecrire du HTML : aucune mutation
// de G, aucun tirage aleatoire, aucun appel a validateChar()/selCountry() etc. -- un choix deja
// fait, une statistique deja distribuee ou un champ deja saisi restent strictement inchanges.
// Expose sur window pour que i18n-init.js (generique, reutilisable sur d'autres pages) puisse
// l'appeler sans rien connaitre de la creation de personnage.
function rafraichirEcranCreationApresChangementLangue(){
  const n=_currentScreenIndex;
  if(n===1){
    renderCountry();
    // La modale de choix de ville est un ecran superpose, jamais re-rendu par goTo(1) lui-meme
    // (uniquement par selCountry()) -- si elle est ouverte au moment du changement de langue,
    // elle doit etre rafraichie aussi, sans quoi elle resterait dans l'ancienne langue.
    if(document.getElementById('modal-city')?.classList.contains('open')) renderCityChoice();
  }
  if(n===2) renderOrigin();
  if(n===3) renderSchool();
  if(n===4) renderArch();
  if(n===5) renderCareer();
  if(n===6) renderStatsUI();
  if(n===8) renderReview();
  if(n===9) renderSuccess();
}
window.RP_I18N_ON_LANGUAGE_CHANGE=rafraichirEcranCreationApresChangementLangue;

/* ---- Country ---- */
function renderCountry(){
  document.getElementById('country-grid').innerHTML=Object.entries(COUNTRIES).map(([id,d])=>{
    // d.n (nom propre : Republia, El Estado...) toujours lu tel quel depuis data.js, jamais
    // traduit (§3/§9 du chantier i18n) -- seuls tags/description passent par i18next, indexes
    // par l'id technique du pays, jamais par le nom affiche.
    const tags = t(`creation.countries.${id}.tags`, { returnObjects: true });
    const desc = t(`creation.countries.${id}.description`);
    return `
    <div class="cc ${G.country===id?'sel':''}" data-c="${id}" onclick="selCountry('${id}')">
      <div class="icon-c" style="border-color:${d.col};color:${d.col}">
        <i class="ti ${d.icon}" style="font-size:1.2rem"></i>
      </div>
      <div class="cname" style="color:${d.col}">${d.n}</div>
      <div style="margin-bottom:.6rem">
        ${(Array.isArray(tags)?tags:[]).map(tag=>`<span class="ctag" style="color:${d.col};border-color:${d.col}">${tag}</span>`).join('')}
      </div>
      <div class="cdesc">${desc}</div>
    </div>`;
  }).join('');
}
function selCountry(id){
  G.country=id;
  G.city=null;
  G.freeStats={INT:0,CHA:0,VOL:0,PER:0,DUP:0,ENT:0};
  G.freePts=30;
  renderCountry();
  renderCityChoice();
  document.getElementById('n1').disabled=true;
}

function renderCityChoice(){
  const modal = document.getElementById('modal-city');
  const grid = document.getElementById('city-grid');
  if (!G.country || !WORLD[G.country]) { modal.classList.remove('open'); return; }
  const villes = Object.entries(WORLD[G.country]).filter(([k,v]) => v && v.isCapitale !== undefined && !v.isSpecial);
  grid.innerHTML = villes.map(([key,v]) => {
    // v.name (nom propre : Luthecia, Montrouge...) jamais traduit -- seule la description passe
    // par i18next, indexee par pays + cle technique de ville (capitale/ville_a/ville_b).
    const desc = t(`creation.cities.${G.country}.${key}.description`);
    return `
    <div class="cc ${G.city===key?'sel':''}" onclick="selCity('${key}')" style="display:flex;gap:.9rem;align-items:center;text-align:left;padding:.8rem;cursor:pointer">
      ${v.imageUrl ? `<img src="${v.imageUrl}" style="width:110px;height:80px;object-fit:cover;border:1px solid #3a2a10;flex-shrink:0"/>` : ''}
      <div>
        <div class="cname">${v.name}${v.isCapitale ? ` <span style="font-size:.7rem;color:#8a8060">${t('creation.city.capitalBadge')}</span>` : ''}</div>
        <div class="cdesc">${desc || ''}</div>
      </div>
    </div>`;
  }).join('');
  modal.classList.add('open');
}

function selCity(key){
  G.city = key;
  document.getElementById('modal-city').classList.remove('open');
  document.getElementById('n1').disabled = !(G.country && G.city);
}

/* ---- Origin ---- */
function renderOrigin(){
  const cur=COUNTRIES[G.country]?.cur||'FR';
  document.getElementById('origin-grid').innerHTML=ORIGINS.map(o=>`
    <div class="oc ${G.origin===o.id?'sel':''}" onclick="selOrigin('${o.id}')">
      <div class="checkmark"><i class="ti ti-check"></i></div>
      <div class="oname"><i class="ti ${o.icon}" style="font-size:1rem;color:#8a6a20"></i> ${t('creation.origins.'+o.id+'.name')}</div>
      <div class="obonus">
        ${t('creation.common.capitalLabel')} : <strong>${o.arg.toLocaleString('fr-FR')} ${cur}</strong><br>
        ${Object.entries(o.bonuses).map(([k,v])=>`<strong>+${v} ${k}</strong>`).join('  ')}
        ${Object.entries(o.malus).map(([k,v])=>`<span style="color:#8a4020">${v} ${k}</span>`).join('  ')}
      </div>
      <div style="font-size:.72rem;color:#7a6040;margin-top:.3rem;font-style:italic">${t('creation.common.traitLabel')} : ${t('creation.origins.'+o.id+'.trait')}</div>
    </div>`).join('');
}
function selOrigin(id){
  G.origin=id;
  renderOrigin();
  document.getElementById('n2').disabled=false;
}

/* ---- School ---- */
function renderSchool(){
  const cur=COUNTRIES[G.country]?.cur||'FR';
  document.getElementById('school-grid').innerHTML=SCHOOLS.map(s=>`
    <div class="oc ${G.school===s.id?'sel':''}" onclick="selSchool('${s.id}')">
      <div class="checkmark"><i class="ti ti-check"></i></div>
      <div class="oname"><i class="ti ${s.icon}" style="font-size:1rem;color:#8a6a20"></i> ${t('creation.schools.'+s.id+'.name')}</div>
      <div class="obonus">
        ${s.argBonus?`<strong>+${s.argBonus.toLocaleString('fr-FR')} ${cur}</strong><br>`:''}
        ${Object.entries(s.bonuses).map(([k,v])=>`<strong>+${v} ${k}</strong>`).join('  ')}
        ${Object.entries(s.malus||{}).map(([k,v])=>`<span style="color:#8a4020">${v} ${k}</span>`).join('  ')}
      </div>
      <div class="oblock"><i class="ti ti-lock" style="font-size:.7rem;vertical-align:-1px"></i> ${t('creation.schools.'+s.id+'.blockLabel')}</div>
    </div>`).join('');
}
function selSchool(id){
  G.school=id;
  G.career=null;
  renderSchool();
  document.getElementById('n3').disabled=false;
}

/* ---- Archetype ---- */
function renderArch(){
  const cur=COUNTRIES[G.country]?.cur||'FR';
  document.getElementById('arch-grid').innerHTML=ARCHETYPES.map(a=>`
    <div class="oc ${G.archetype===a.id?'sel':''}" onclick="selArch('${a.id}')">
      <div class="checkmark"><i class="ti ti-check"></i></div>
      <div class="oname"><i class="ti ${a.icon}" style="font-size:1rem;color:#8a6a20"></i> ${t('creation.archetypes.'+a.id+'.name')}</div>
      <div class="odesc">${t('creation.archetypes.'+a.id+'.description')}</div>
      <div class="obonus">
        ${Object.entries(a.bonuses).map(([k,v])=>`<strong>+${v} ${k}</strong>`).join('  ')}
        ${Object.entries(a.malus).map(([k,v])=>`<span style="color:#8a4020">${v} ${k}</span>`).join('  ')}<br>
        ${t('creation.common.capitalLabel')} : <strong>+${a.argBonus.toLocaleString('fr-FR')} ${cur}</strong>
      </div>
    </div>`).join('');
}
function selArch(id){
  G.archetype=id;
  renderArch();
  document.getElementById('n4').disabled=false;
}

/* ---- Career ---- */
function isBlocked(c){
  if(!G.school) return false;
  return c.blocks.includes(G.school);
}
function renderCareer(){
  const cur=COUNTRIES[G.country]?.cur||'FR';
  document.getElementById('career-grid').innerHTML=CAREERS.map(c=>{
    const bl=isBlocked(c);
    return`<div class="oc ${G.career===c.id?'sel':''} ${bl?'locked':''}"
      onclick="${bl?'':` selCareer('${c.id}')`}"
      title="${bl?t('creation.career.locked'):''}">
      <div class="checkmark"><i class="ti ti-check"></i></div>
      <div class="oname"><i class="ti ${c.icon}" style="font-size:1rem;color:#8a6a20"></i> ${t('creation.careers.'+c.id+'.name')}</div>
      <div class="obonus">+${c.argBonus.toLocaleString('fr-FR')} ${cur} &middot; <strong>+1 ${c.statKey}</strong></div>
      <div class="odesc" style="margin-top:.3rem">${t('creation.careers.'+c.id+'.comp')}</div>
    </div>`;
  }).join('');
  const sc=SCHOOLS.find(x=>x.id===G.school);
  document.getElementById('career-info').textContent=
    sc?t('creation.career.info',{school:t('creation.schools.'+sc.id+'.name')}):'';
}
// Revalidation cote logique (bêta, faille corrigee) : isBlocked() ne protegeait jusqu'ici que
// l'affichage (onclick vide sur une carte bloquee) -- selCareer() elle-meme ne verifiait rien,
// donc appelable directement depuis la console (ex. selCareer('business') sans le bon niveau
// d'etudes) pour contourner le prerequis. Desormais revalidee ici, au meme titre que l'IHM.
function selCareer(id){
  const c=CAREERS.find(x=>x.id===id);
  if(!c || isBlocked(c)) return;
  G.career=id;
  renderCareer();
  document.getElementById('n5').disabled=false;
}

/* ---- Stats ---- */
function getBase(k){
  const co=COUNTRIES[G.country]?.bases||{INT:8,CHA:7,VOL:6,PER:7,DUP:7,ENT:7};
  const or=ORIGINS.find(x=>x.id===G.origin);
  const sc=SCHOOLS.find(x=>x.id===G.school);
  const ar=ARCHETYPES.find(x=>x.id===G.archetype);
  const ca=CAREERS.find(x=>x.id===G.career);
  let v=co[k]||8;
  if(or){v+=(or.bonuses[k]||0)+(or.malus[k]||0)}
  if(sc){v+=(sc.bonuses[k]||0)+(sc.malus[k]||0)}
  if(ar){v+=(ar.bonuses[k]||0)+(ar.malus[k]||0)}
  if(ca&&ca.statKey===k) v+=1;
  return Math.max(1,v);
}
function getBonus(k){
  const co=COUNTRIES[G.country]?.bases||{INT:8,CHA:7,VOL:6,PER:7,DUP:7,ENT:7};
  return getBase(k)-(co[k]||8);
}

function renderStatsUI(){
  document.getElementById('stats-wrap').innerHTML=STAT_DEFS.map(({k,i})=>{
    const base=getBase(k), free=G.freeStats[k]||0, eff=Math.min(20,base+free), bonus=getBonus(k);
    return`<div class="srow">
      <div>
        <div class="sname"><i class="ti ${i}" style="font-size:.9rem;vertical-align:-1px;margin-right:.3rem"></i>${t('creation.stats.'+k+'.name')}</div>
        <div class="sdesc">${t('creation.stats.'+k+'.description')}</div>
        <div class="sbar"><div class="sbarfill" style="width:${(eff/20)*100}%"></div></div>
      </div>
      <div class="sbonus">${bonus>0?`+${bonus} ${t('creation.common.bonusSuffix')}`:bonus<0?`${bonus} ${t('creation.common.malusSuffix')}`:''}</div>
      <div class="sadj">
        <button class="sbtn" onclick="adjStat('${k}',-1)" ${free<=0?'disabled':''}>-</button>
        <span class="sval">${eff}</span>
        <button class="sbtn" onclick="adjStat('${k}',1)" ${G.freePts<=0||base+free>=16?'disabled':''}>+</button>
      </div>
    </div>`;
  }).join('');
  document.getElementById('pts-left').textContent=G.freePts;
  // Reliquat (bêta) : avertissement clair mais NON bloquant -- aucun point n'est disabled sur
  // le bouton "Suivant" (id="n6", index.html), tout comme aujourd'hui. Le reliquat eventuel
  // est sauvegarde (char.freePtsRestants, validateChar) et reste distribuable plus tard depuis
  // la fiche de personnage (onglet Statistiques).
  const ptsWarn=document.getElementById('pts-warning');
  if(ptsWarn){
    if(G.freePts>0){
      ptsWarn.style.display='block';
      // Pluriel gere par i18next (_one/_other, cle "count") -- jamais la notation "(s)" figee
      // de l'ancien texte francais, qui ne peut pas se traduire proprement en anglais.
      ptsWarn.textContent=t('creation.steps.stats.warning',{count:G.freePts});
    } else {
      ptsWarn.style.display='none';
    }
  }
}
function adjStat(k,dir){
  const base=getBase(k), free=G.freeStats[k]||0;
  if(dir<0&&free<=0) return;
  if(dir>0&&base+free>=16) return;
  const cur=base+free, cost=dir>0?(cur>=12?2:1):(cur>12?2:1);
  if(dir>0&&G.freePts<cost) return;
  G.freeStats[k]=free+dir;
  G.freePts-=dir*cost;
  renderStatsUI();
}

/* ---- Identity ---- */
function handlePhoto(inp){
  const f=inp.files[0]; if(!f) return;
  const r=new FileReader();
  r.onload=e=>{
    G.photoUrl=e.target.result;
    document.getElementById('pprev').innerHTML=`<img src="${G.photoUrl}" class="pphoto" alt="Photo de profil"/>`;
  };
  r.readAsDataURL(f);
}
function chkId(){
  G.name=document.getElementById('cname').value.trim();
  G.bio=document.getElementById('cbio').value.trim();
  document.getElementById('n7').disabled=!G.name||!G.bio;
}

/* ---- Review ---- */
function palier(a){
  if(a<600)  return t('creation.review.wealthTier1');
  if(a<1500) return t('creation.review.wealthTier2');
  if(a<3500) return t('creation.review.wealthTier3');
  if(a<7000) return t('creation.review.wealthTier4');
  return t('creation.review.wealthTier5');
}

function totalArg(){
  const or=ORIGINS.find(x=>x.id===G.origin);
  const sc=SCHOOLS.find(x=>x.id===G.school);
  const ar=ARCHETYPES.find(x=>x.id===G.archetype);
  const ca=CAREERS.find(x=>x.id===G.career);
  return (or?.arg||0)+(sc?.argBonus||0)+(ar?.argBonus||0)+(ca?.argBonus||0);
}
function resources(){
  const ar=ARCHETYPES.find(x=>x.id===G.archetype);
  return{
    inf:Math.min(100,10+(ar?.infBonus||0)),
    pop:Math.min(100,10+(ar?.popBonus||0)),
    dis:Math.min(100,80+(ar?.disBonus||0))
  };
}

function renderReview(){
  G.name=document.getElementById('cname').value.trim();
  G.bio=document.getElementById('cbio').value.trim();
  G.motto=document.getElementById('cmotto').value.trim();
  const co=COUNTRIES[G.country];
  const or=ORIGINS.find(x=>x.id===G.origin);
  const sc=SCHOOLS.find(x=>x.id===G.school);
  const ar=ARCHETYPES.find(x=>x.id===G.archetype);
  const ca=CAREERS.find(x=>x.id===G.career);
  const eff={};
  STAT_DEFS.forEach(({k})=>{eff[k]=Math.min(20,getBase(k)+(G.freeStats[k]||0))});
  const arg=totalArg(), res=resources();
  const photo=G.photoUrl
    ?`<img src="${G.photoUrl}" class="rphoto" alt="Photo"/>`
    :`<div class="rphoto"><i class="ti ti-user" style="font-size:2rem"></i></div>`;
  const arName=ar?t('creation.archetypes.'+ar.id+'.name'):'';
  const maxInGame=t('creation.review.maxInGame');
  document.getElementById('rcard').innerHTML=`
    <div class="rhead">
      ${photo}
      <div class="rname playfair">${G.name}</div>
      <div class="rsub">${arName} &middot; ${co?.n||''}</div>
      ${G.motto?`<div style="font-style:italic;color:#5a5040;font-size:.82rem;margin-top:.5rem">"${G.motto}"</div>`:''}
      <div class="rbadge" style="color:${co?.col};border-color:${co?.col}">${co?.n} &middot; ${co?.cur}</div>
    </div>
    <div class="rsec">
      <div class="rsectitle">${t('creation.review.lifePath')}</div>
      <div class="rbadge-wrap">
        ${or?`<div class="rbadge-item"><i class="ti ${or.icon}" style="font-size:.85rem"></i> ${t('creation.origins.'+or.id+'.name')}</div>`:''}
        ${sc?`<div class="rbadge-item"><i class="ti ${sc.icon}" style="font-size:.85rem"></i> ${t('creation.schools.'+sc.id+'.name')}</div>`:''}
        ${ar?`<div class="rbadge-item"><i class="ti ${ar.icon}" style="font-size:.85rem"></i> ${arName}</div>`:''}
        ${ca?`<div class="rbadge-item"><i class="ti ${ca.icon}" style="font-size:.85rem"></i> ${t('creation.careers.'+ca.id+'.name')}</div>`:''}
      </div>
    </div>
    <div class="rsec">
      <div class="rsectitle">${t('creation.review.characteristics')}</div>
      <div class="rsgrid">
        ${STAT_DEFS.map(({k,i})=>`
          <div class="rsitem">
            <div class="rsiname"><i class="ti ${i}" style="font-size:.7rem"></i> ${t('creation.stats.'+k+'.name')}</div>
            <div class="rsival">${eff[k]}</div>
          </div>`).join('')}
      </div>
    </div>
    <div class="rsec">
      <div class="rsectitle">${t('creation.review.startingResources')}</div>
      <div class="resgrid">
        <div class="resitem"><div class="reslbl">${t('creation.review.money')}</div><div class="resval">${arg.toLocaleString('fr-FR')} ${co?.cur||'FR'}</div><div class="resmax">${t('creation.review.tier',{tier:palier(arg)})}</div></div>
        <div class="resitem"><div class="reslbl">${t('creation.review.influence')}</div><div class="resval">${res.inf} / 100</div><div class="resmax">${maxInGame}</div></div>
        <div class="resitem"><div class="reslbl">${t('creation.review.popularity')}</div><div class="resval">${res.pop} / 100</div><div class="resmax">${maxInGame}</div></div>
        <div class="resitem"><div class="reslbl">${t('creation.review.discretion')}</div><div class="resval">${res.dis} / 100</div><div class="resmax">${maxInGame}</div></div>
      </div>
    </div>
    <div class="rsec" style="border:none">
      <div class="rsectitle">${t('creation.review.biography')}</div>
      <div class="rbio">${G.bio}</div>
    </div>`;
}

// Verrou de creation, porte par le module et non par le DOM (23 septembre 2026). Une creation
// est une operation longue (envoi de la photo) et STRICTEMENT non repetable : deux appels
// concurrents produisent une ligne et une erreur, et c'est l'erreur que le joueur voit.
let CREATION_EN_COURS = false;

// =================================================================================================
// LE COMPTE AVANT LE PERSONNAGE (24 septembre 2026)
// =================================================================================================
// POURQUOI CE DETOUR PAR UNE SESSION ANONYME, alors que la consigne demande un compte authentifie
// d'emblee. Mesure faite sur notre instance, pas supposee : POST /signup avec adresse et mot de
// passe renvoie HTTP 200 mais AUCUN jeton -- ni access_token, ni refresh_token -- parce que
// mailer_autoconfirm vaut false ; et /token?grant_type=password repond alors email_not_confirmed.
// Creer le compte "proprement" d'abord rendrait donc la suite IMPOSSIBLE : sans session, le
// joueur ne peut rien ecrire, et il faudrait l'envoyer relever ses courriels avant meme d'avoir
// choisi son empire. C'est exactement le piege que le cahier des charges interdit.
//
// CE QUE FAIT LA VOIE RETENUE, verifiee au banc : on ouvre une session (instantanee, invisible),
// puis on POSE IMMEDIATEMENT l'adresse et le mot de passe sur CE MEME compte (PUT /user). Le
// user_id ne bouge pas -- verifie -- le mot de passe est deja enregistre, la session reste
// valide, et le personnage cree juste apres nait donc sous un identifiant definitif qui porte
// deja les identifiants du joueur. Seule la CONFIRMATION reste differee : c'est elle qui ouvre
// la connexion depuis un autre appareil, et c'est une politique Supabase, pas un choix de code.
//
// Autrement dit : le compte du joueur existe bien avant son personnage. L'anonymat n'est plus un
// etat dans lequel on le laisse -- c'est une amorce de quelques millisecondes.
let IDENTIFIANTS_EN_COURS = false;

function commencerCreation() {
  // Ce navigateur porte-t-il deja un compte a identifiants ? Alors ne redemandons pas ce que le
  // joueur a deja donne : il enchaine directement sur la creation du personnage.
  const dejaIdentifie = (typeof rpAuthEmail === 'function' && rpAuthEmail())
                     || (typeof rpAuthIdentiteMemorisee === 'function'
                         && rpAuthIdentiteMemorisee() && rpAuthIdentiteMemorisee().email);
  if (dejaIdentifie) { goTo(1); return; }
  ouvrirEcranIdentifiants();
}

function ouvrirEcranIdentifiants() {
  document.querySelectorAll('.screen').forEach(s => s.classList.remove('active'));
  const ecran = document.getElementById('sauth');
  if (!ecran) { goTo(1); return; }   // filet : jamais bloquer l'entree dans le jeu
  ecran.classList.add('active');
  window.scrollTo(0, 0);
  const msg = document.getElementById('auth-msg');
  if (msg) { msg.style.display = 'none'; msg.textContent = ''; }
}

function rpMessageIdentifiants(cle, secours) {
  const t = (typeof i18next !== 'undefined' && i18next.t) ? i18next.t(cle) : null;
  return (t && t !== cle) ? t : secours;
}

function afficherMessageIdentifiants(texte) {
  const zone = document.getElementById('auth-msg');
  if (!zone) return;
  zone.style.display = '';
  zone.style.cssText = 'display:block;margin:.2rem 0 .4rem;padding:.6rem .8rem;border:1px solid #8a3a2a;'
    + 'background:#2a1410;color:#e8b4a0;font-size:.85rem;line-height:1.45;border-radius:4px';
  zone.textContent = texte;
}

async function validerIdentifiants() {
  // MEME DISCIPLINE QUE LA CREATION DU PERSONNAGE : verrou logique d'abord, etat visible ensuite.
  // Poser une adresse est un aller-retour reseau ; sans verrou, deux clics rapides lancent deux
  // conversions concurrentes.
  if (IDENTIFIANTS_EN_COURS) {
    console.warn('[auth] second appel a validerIdentifiants() ignore : operation deja en cours.');
    return;
  }
  const email = (document.getElementById('auth-email')?.value || '').trim();
  const mdp = document.getElementById('auth-mdp')?.value || '';

  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
    afficherMessageIdentifiants(rpMessageIdentifiants('auth.errEmail',
      "Cette adresse e-mail ne semble pas valide. Vérifiez-la."));
    return;
  }
  if (mdp.length < 8) {
    afficherMessageIdentifiants(rpMessageIdentifiants('auth.errPassword',
      "Choisissez un mot de passe d'au moins huit caractères."));
    return;
  }

  IDENTIFIANTS_EN_COURS = true;
  const bouton = document.getElementById('auth-valider');
  const libelle = bouton ? bouton.textContent : null;
  if (bouton) {
    bouton.disabled = true;
    bouton.textContent = rpMessageIdentifiants('auth.working', 'Création du compte en cours...');
  }
  const rendreLaMain = function () {
    IDENTIFIANTS_EN_COURS = false;
    if (bouton) { bouton.disabled = false; if (libelle !== null) bouton.textContent = libelle; }
  };

  try {
    if (typeof rpAuthAssurerSession !== 'function' || typeof rpAuthSecuriserCompte !== 'function') {
      afficherMessageIdentifiants(rpMessageIdentifiants('auth.errUnavailable',
        "La création de compte est momentanément indisponible. Réessayez dans un instant."));
      rendreLaMain(); return;
    }
    const session = await rpAuthAssurerSession().catch(() => null);
    if (!session) {
      afficherMessageIdentifiants(rpMessageIdentifiants('auth.errSession',
        "Impossible d'ouvrir une session pour le moment. Vérifiez votre connexion et réessayez."));
      rendreLaMain(); return;
    }

    const r = await rpAuthSecuriserCompte(email, mdp).catch(() => null);
    if (!r || r.ok !== true) {
      const raison = (r && r.raison) || 'inconnue';
      // Une adresse deja prise est le seul cas ou le joueur doit changer quelque chose ; on le
      // dit clairement et on lui rappelle qu'il peut simplement se connecter.
      const dejaPrise = String(raison).indexOf('email_exists') !== -1
                     || String(raison).indexOf('already') !== -1
                     || String(raison).indexOf('registered') !== -1;
      afficherMessageIdentifiants(dejaPrise
        ? rpMessageIdentifiants('auth.errEmailTaken',
            "Cette adresse est déjà utilisée. Retournez à l'accueil et choisissez « Me connecter à mon compte ».")
        : rpMessageIdentifiants('auth.errGeneric',
            "Votre compte n'a pas pu être créé (" + raison + "). Réessayez dans un instant."));
      rendreLaMain(); return;
    }

    // Compte pret : user_id definitif, identifiants poses. Le personnage peut naitre.
    rendreLaMain();
    goTo(1);
  } catch (e) {
    afficherMessageIdentifiants(rpMessageIdentifiants('auth.errGeneric',
      "Votre compte n'a pas pu être créé. Réessayez dans un instant."));
    rendreLaMain();
  }
}

async function validateChar(){
  // CREATION NON DESTRUCTRICE (chantier B, 14 septembre 2026).
  // Jusqu'ici cette fonction ecrivait le personnage sans attendre le resultat, par un chemin
  // qui faisait un PATCH si le nom etait deja pris : saisir le nom d'un joueur existant
  // REMPLACAIT sa fiche entiere, silencieusement, et l'ecran de succes s'affichait quand meme.
  // Desormais : on ouvre d'abord la session (pour que la base rattache le personnage au
  // compte), on INSERE, ON ATTEND, et on ne quitte cet ecran qu'en cas de reussite.
  // VERROU LOGIQUE, INDEPENDANT DU DOM (23 septembre 2026). Le garde-fou ci-dessous ne suffit
  // pas a lui seul : si le bouton change un jour de classe, la protection retomberait en panne
  // exactement comme elle l'a fait ici. Ce drapeau, lui, ne depend d'aucun selecteur.
  if (CREATION_EN_COURS) {
    console.warn('[creation] second appel a validateChar() ignore : une creation est deja en cours.');
    return;
  }
  CREATION_EN_COURS = true;

  // LE SELECTEUR VISAIT UN ECRAN QUI N'EXISTE PAS (diagnostic du 23 septembre 2026).
  // Les ecrans de creation s'appellent s1..s9 -- il n'y a jamais eu de '#screen-8', ni de
  // '.btn-primary', ni de '#btn-valider-perso' dans index.html. querySelector renvoyait donc
  // null, et TOUT ce qui suit etait inerte : le bouton n'etait jamais desactive, ne disait
  // jamais que la creation etait en cours, et les erreurs s'affichaient en haut du <body>.
  // Pendant les ~26 secondes que dure l'envoi d'une photo de 3 Mo, rien ne bougeait a l'ecran :
  // un second clic etait non seulement possible, mais previsible. C'est ce second envoi qui
  // echouait sur le nom que le premier venait d'inscrire.
  const ecranCreation = document.getElementById('s8');
  const boutonValider = (ecranCreation && ecranCreation.querySelector('.nnext'))
                     || document.querySelector('#s8 .nnext');
  // Le libelle est pose par i18n : on le memorise pour le restaurer a l'identique, plutot que
  // d'ecrire un « Valider » en dur qui ecraserait la traduction.
  const libelleInitial = boutonValider ? boutonValider.textContent : null;
  const rendreLaMain = function () {
    CREATION_EN_COURS = false;
    if (boutonValider) {
      boutonValider.disabled = false;
      if (libelleInitial !== null) boutonValider.textContent = libelleInitial;
    }
  };
  const afficherErreurCreation = function (titre, message) {
    let zone = document.getElementById('creation-erreur');
    if (!zone) {
      zone = document.createElement('div');
      zone.id = 'creation-erreur';
      zone.style.cssText = 'margin:1rem 0;padding:.8rem 1rem;border:1px solid #8a3a2a;' +
        'background:#2a1410;color:#e8b4a0;font-size:.9rem;line-height:1.5;border-radius:4px';
      const hote = ecranCreation || document.body;
      hote.insertBefore(zone, hote.firstChild);
    }
    zone.innerHTML = '<strong>' + titre + '</strong><br>' + message;
    zone.scrollIntoView({ behavior: 'smooth', block: 'center' });
    // LA MAIN N'EST RENDUE QU'ICI : sur un echec reel, ou le joueur doit corriger et recommencer.
    rendreLaMain();
  };
  if (boutonValider) { boutonValider.disabled = true; boutonValider.textContent = 'Creation en cours...'; }

  // Sauvegarde du personnage en localStorage pour le plateau
  const char={
    country:G.country, origin:G.origin, school:G.school,
    archetype:G.archetype, career:G.career,
    stats:{}, freeStats:G.freeStats,
    freePtsRestants:G.freePts, // reliquat (bêta) : plus jamais obligatoire de tout depenser a la creation
    name:G.name, bio:G.bio, motto:G.motto,
    arg:totalArg(), resources:resources(),
    createdAt:new Date().toISOString(),
    currentCity:G.city || 'capitale',
    queteAccueil:{ etape:'non_commencee' }
  };
  STAT_DEFS.forEach(({k})=>{char.stats[k]=Math.min(20,getBase(k)+(G.freeStats[k]||0))});
  try{
    // Clé par nom (évite écrasement entre personnages)
    try {
      localStorage.setItem('respublica_char_' + char.name, JSON.stringify(char));
      // Clé générique = pointeur vers le dernier personnage actif
      localStorage.setItem('respublica_char', JSON.stringify(char));
      localStorage.setItem('respublica_last_char', char.name);
    } catch (e) {
      console.warn('Cache local personnage non sauvegarde (quota depasse) :', e);
    }
    // Photo sauvegardee separement car peut etre volumineuse
    if(G.photoUrl){
      try{
        localStorage.setItem('respublica_photo_' + char.name, G.photoUrl);
        localStorage.setItem('respublica_photo', G.photoUrl);
      }
      catch(e){ console.warn('Photo trop volumineuse pour localStorage'); }
    }
    // Sauvegarde Supabase
    if (typeof sbSavePersonnage === 'function') {
      // Lot 2 (chantier fiscalite/Helvetia) : repartition initiale 15%/85%, INCHANGEE dans sa
      // formule (deja la convention existante ici), mais la part de 85% n'est plus ecrite sur
      // l'ancien champ plat personnages.banque (legacy, plus source de verite) -- elle cree
      // desormais une vraie ligne comptes_bancaires (Banque nationale), juste apres que le
      // personnage lui-meme existe reellement en base (chainage .then, evite toute course avec
      // la contrainte de personnage referencee par comptes_bancaires.personnage).
      const soldeBanqueNationale = (char.arg || 0) - Math.floor((char.arg||0)*0.15);
      const tempState = {
        char, country: char.country, currentCity: G.city || 'capitale',
        arg: char.arg || 0, liquide: Math.floor((char.arg||0)*0.15),
        inf: char.resources?.inf || 25, pop: char.resources?.pop || 30,
        dis: char.resources?.dis || 85, hp: 100, pa: 10, moral: 75,
        poste: null, inventory: [], informateurs: [], day: 1, recherche: [],
        domicile: { country: char.country, city: G.city || 'capitale', depuis: 1 },
        organisations: [],
        objectifs_completes: [],
        votes_pnj: {},
      };
      // INSERT SEC, ATTENDU. La contrainte UNIQUE(name) est desormais l'autorite : si le nom
      // est pris, la base refuse et rien n'est ecrase.
      const creation = await sbCreerPersonnageInitial(tempState).catch(e => {
        console.error('Creation du personnage', e);
        return { ok: false, raison: 'erreur_reseau' };
      });

      if (!creation.ok) {
        // ===================================================================================
        // AVANT TOUT : CE COMPTE POSSEDE-T-IL DEJA UN PERSONNAGE ? (23 septembre 2026)
        // ===================================================================================
        // C'est la question qui manquait, et elle a coute son personnage a un joueur. Un echec
        // ici ne prouve PAS que rien n'a ete ecrit : quand deux envois partent en concurrence,
        // le second echoue precisement PARCE QUE le premier a reussi. Le nettoyage ci-dessous,
        // ecrit pour le cas « rien n'a ete ecrit », effacait alors les pointeurs d'un personnage
        // parfaitement valide -- et loadCharacter(), qui ne lit que le localStorage, ne pouvait
        // plus le retrouver.
        //
        // mon_personnage() tranche sans ambiguite : SECURITY DEFINER, elle resout uniquement par
        // auth.uid(). Elle ne peut donc jamais designer le personnage de quelqu'un d'autre.
        const personnageDuCompte = (typeof sbRpc === 'function')
          ? await sbRpc('mon_personnage').then(function (r) {
              const v = Array.isArray(r) ? r[0] : r;
              return (typeof v === 'string') ? v : (v && (v.mon_personnage || v.name)) || null;
            }).catch(function () { return null; })
          : null;

        if (personnageDuCompte === char.name) {
          // NOTRE PROPRE ENVOI CONCURRENT A REUSSI. Il n'y a rien a signaler au joueur : son
          // personnage existe, il porte le nom demande, et il lui appartient. On reecrit les
          // pointeurs (l'autre appel a pu les effacer) et on continue vers l'ecran de succes,
          // exactement comme si cet envoi-ci avait abouti.
          console.warn('[creation] envoi concurrent : le personnage « ' + char.name +
                       ' » a bien ete cree pour ce compte. Poursuite normale.');
          try {
            localStorage.setItem('respublica_char_' + char.name, JSON.stringify(char));
            localStorage.setItem('respublica_char', JSON.stringify(char));
            localStorage.setItem('respublica_last_char', char.name);
          } catch (e) {}
          goTo(9);
          return;
        }

        if (personnageDuCompte) {
          // Le compte porte deja un AUTRE personnage. On ne touche a aucun pointeur : ceux du
          // personnage reel doivent survivre. On corrige meme le pointeur si le cache ecrit plus
          // haut a ecrase le sien.
          try {
            localStorage.setItem('respublica_last_char', personnageDuCompte);
            localStorage.removeItem('respublica_char_' + char.name);
          } catch (e) {}
          afficherErreurCreation('Vous avez deja un personnage',
            'Ce compte possede deja « ' + personnageDuCompte + ' » : Republia n\'en autorise ' +
            'qu\'un seul par compte. Changer de nom n\'y changera rien.<br><br>' +
            '<em>Retournez a l\'accueil pour le reprendre.</em>');
          return;
        }

        // A partir d'ici, le serveur confirme qu'aucun personnage n'appartient a ce compte :
        // le nettoyage des pointeurs locaux est alors legitime, et seulement alors.
        // CORRECTIF DU 14 septembre 2026. Un seul message couvrait trois causes differentes :
        // un joueur dont le COMPTE avait disparu se voyait repondre « ce nom est deja porte »
        // pour n'importe quel nom, et etait renvoye vers « Retrouver mon personnage », qui ne
        // pouvait rien pour lui. Chaque cause a desormais son message et sa vraie sortie.
        if (creation.raison === 'nom_deja_pris') {
          afficherErreurCreation('Ce nom est deja porte',
            'Un personnage nomme « ' + char.name + ' » existe deja dans Republia. ' +
            'Choisissez un autre nom : revenez a l\'etape precedente pour le modifier.<br><br>' +
            '<em>Si ce personnage est le votre et que vous avez perdu l\'acces, utilisez ' +
            '« Retrouver mon personnage » depuis l\'accueil plutot que d\'en recreer un.</em>');
        } else if (creation.raison === 'compte_a_deja_un_personnage') {
          afficherErreurCreation('Vous avez deja un personnage',
            'Ce navigateur est deja lie a un personnage : Republia n\'en autorise qu\'un seul par ' +
            'compte. Changer de nom n\'y changera rien.<br><br>' +
            '<em>Retournez a l\'accueil pour le reprendre. Pour en creer un autre, il faut ' +
            'd\'abord detruire celui que vous possedez, depuis sa fiche.</em>');
        } else if (creation.raison === 'session_perimee') {
          afficherErreurCreation('Session expiree',
            'La session de ce navigateur n\'est plus reconnue par le serveur. Rechargez la page : ' +
            'une nouvelle session sera ouverte et la creation fonctionnera.<br><br>' +
            '<em>Aucun nom n\'est en cause — inutile d\'en changer.</em>');
        } else {
          afficherErreurCreation('Creation impossible',
            'Votre personnage n\'a pas pu etre enregistre (' + (creation.raison || 'erreur inconnue') + '). ' +
            'Verifiez votre connexion et reessayez ; rien n\'a ete perdu.');
        }
        // On NE quitte PAS cet ecran : le joueur corrige et revalide.
        // Le cache local a ete ecrit plus haut, avant l'aller-retour reseau : on le retire
        // entierement, sinon loadCharacter() retrouverait au prochain chargement un personnage
        // qui n'existe pas en base -- ou pire, celui d'un autre joueur portant ce nom.
        try {
          localStorage.removeItem('respublica_char_' + char.name);
          localStorage.removeItem('respublica_last_char');
          localStorage.removeItem('respublica_char');
        } catch (e) {}
        return;
      }

      if (typeof sbCreerCompteBancaire === 'function') {
        await sbCreerCompteBancaire({
          id: 'nationale_' + char.name,
          personnage: char.name,
          pays: char.country,
          banque: 'nationale',
          solde: soldeBanqueNationale
        }).catch(e => console.error('Échec de la création du compte Banque nationale pour ' + char.name + ' — le personnage existe mais sans compte bancaire initial, à corriger manuellement.', e));
      }

      // Ville de naissance (17 aout 2026, mini-lot etat-civil) : ecriture separee, une seule
      // fois, dans une table dediee (etat_civil_naissances) -- jamais dans 'personnages', qui
      // est resauvegardee integralement a chaque action ulterieure du joueur et casserait toutes
      // les sauvegardes si une colonne y manquait avant que la migration ne soit appliquee.
      if (typeof sbEnregistrerNaissance === 'function') {
        sbEnregistrerNaissance(char.name, char.country, G.city || 'capitale').catch(e => console.warn('Naissance non enregistree', e));
      }
    }
  }
  catch(e){ console.warn('localStorage non disponible'); }
  goTo(9);
}

function renderSuccess(){
  const co=COUNTRIES[G.country];
  document.getElementById('sctext').textContent=
    t('creation.success.text',{name:G.name,country:co?.n||t('creation.success.fallbackCountry')});
}

// Init
goTo(0);
