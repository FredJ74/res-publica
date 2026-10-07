// =====================
// PLATEAU-MULTIJOUEUR.JS
// Personnes presentes, groupe, employes PNJ, recrutement, escort
// =====================

// =====================
// PERSONS LIST
// =====================
const CODETENUS_CATALOGUE = [
  { nom: 'Tristan Cabane', photoUrl: 'images/commissariat-tristan-cabane.webp' },
  { nom: 'Edgard Havu',    photoUrl: 'images/commissariat-edgard-havu.webp' },
  { nom: 'Simona Venture', photoUrl: 'images/commissariat-simona-venture.webp' },
  { nom: 'Kevin Diesel',   photoUrl: 'images/commissariat-kevin-diesel.webp' }
];

function appliquerRemplacantCodetenu(persons) {
  if (!state.codetenuRemplacant || !state.currentBuilding || !state.currentRoom) return persons;
  return persons.map(p => {
    if (p.job !== 'codetenu') return p;
    const cle = state.currentBuilding + '_' + state.currentRoom;
    const remp = state.codetenuRemplacant[cle];
    if (!remp) return p;
    return { ...p, name: remp.name, role: remp.role, photoUrl: remp.photoUrl || p.photoUrl, photoPos: remp.photoPos || p.photoPos };
  });
}

function ouvrirRecrutementCodetenu(nomCodetenu) {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const tarifJour = 100;

  document.getElementById('modal-pnj').classList.remove('open');
  document.getElementById('postes-modal-title').textContent = 'Codetenu - ' + nomCodetenu;
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.8rem 1rem">' +
    '<div style="font-size:.78rem;color:#a09060;font-style:italic;margin-bottom:.7rem;border-left:2px solid #3a2a10;padding-left:.6rem">' +
      '"On se serre les coudes ici. ' + tarifJour + ' ' + cur + '/jour, et je reste avec toi."' +
    '</div>' +
    '<div style="font-size:.75rem;color:#6a5030;margin-bottom:.8rem">Il rejoint votre groupe. Vous serez debite(e) de <strong style="color:#C9A84C">' + tarifJour + ' ' + cur + '</strong> a chaque reveil.</div>' +
    '<div style="display:flex;gap:.5rem">' +
      '<button onclick="confirmerRecrutementCodetenu(\'' + nomCodetenu.replace(/'/g,'') + '\',' + tarifJour + ')" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.4rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">Recruter</button>' +
      '<button onclick="document.getElementById(\'modal-postes\').classList.remove(\'open\')" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.4rem;border:1px solid #2a2010;background:transparent;color:#6a5030;cursor:pointer">Decliner</button>' +
    '</div></div>';
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerRecrutementCodetenu(nomCodetenu, tarif) {
  document.getElementById('modal-postes').classList.remove('open');
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  if ((state.employes || []).some(e => e.job === 'codetenu')) {
    showToast('Deja recrute', 'Vous avez deja un codetenu dans votre groupe.', false);
    return;
  }
  if ((state.employes || []).length >= MAX_EMPLOYES) {
    showToast('Limite atteinte', 'Maximum ' + MAX_EMPLOYES + ' employes.', false);
    return;
  }
  if (state.arg < tarif) {
    showToast('Fonds insuffisants', tarif + ' ' + cur + ' requis pour la premiere journee.', false);
    return;
  }
  state.arg -= tarif;

  const statsCodetenu = {
    FOR: Math.floor(Math.random() * 5) + 8,
    DUP: Math.floor(Math.random() * 5) + 8
  };

  const infoActuel = CODETENUS_CATALOGUE.find(c => c.nom === nomCodetenu) || CODETENUS_CATALOGUE[0];

  if (!state.employes) state.employes = [];
  state.employes.push({
    nom: nomCodetenu, role: 'Codetenu', job: 'codetenu',
    photoUrl: infoActuel.photoUrl, photoPos: '50% 15%',
    cout: tarif, inGroupe: true,
    buildingId: state.currentBuilding,
    roomId: state.currentRoom,
    city: state.currentCity,
    depuis: state.day || 1,
    stats: statsCodetenu
  });
  updateUI();
  if (typeof renderEmployesPanel === 'function') renderEmployesPanel();

  const restants = CODETENUS_CATALOGUE.filter(c => c.nom !== nomCodetenu);
  const autre = restants[Math.floor(Math.random() * restants.length)] || CODETENUS_CATALOGUE[0];
  if (!state.codetenuRemplacant) state.codetenuRemplacant = {};
  const cleSlot = state.currentBuilding + '_' + state.currentRoom;
  state.codetenuRemplacant[cleSlot] = {
    name: autre.nom + ' (PNJ)',
    role: 'Detenu',
    job: 'codetenu',
    rel: 'neutral',
    photoUrl: autre.photoUrl,
    photoPos: '50% 15%'
  };

  if (typeof renderPersonsList === 'function' && typeof BUILDINGS !== 'undefined') {
    const room = BUILDINGS[state.currentBuilding]?.rooms?.[state.currentRoom];
    if (room?.persons) renderPersonsList(room.persons);
  }

  showToast('Codetenu recrute !', nomCodetenu + ' rejoint votre groupe. -' + tarif + ' ' + cur + '/reveil.', true, true);
  addJournalEntry('Recrutement codetenu : ' + nomCodetenu + '. -' + tarif + ' ' + cur + '/reveil.', 'event-info');
}

// LA SUBSTITUTION ALEATOIRE A ETE SUPPRIMEE LE 1er OCTOBRE 2026.
// Embaucher une escort en faisait apparaitre une autre, prenom tire dans une
// liste et portrait tire dans une autre -- un etat qui ne survivait meme pas a un
// rechargement de page, puisqu'il n'etait persiste nulle part. Le bar de Luthecia
// ne poste plus personne : il offre un acces a l'agence, dont les sept identites
// vivent en base. Voir plateau-escorts-agence.js.

const POSTES_UNIQUES_A_MASQUER = ['president','pm','maire','min_int','min_fin','min_just','min_def','min_info','min_ae','directeur_pharma','directeur_tabac_alcools','directeur_raffinerie','directeur_entrepot','chef_douanes'];
// Note : commissaire/juge/commandant sont volontairement exclus -- ces PNJ restent affiches
// en permanence pour l'ambiance du plateau, puisqu'aucune prerogative de jeu n'est encore
// codee sur ces postes (a construire plus tard). Chef des Douanes AJOUTE a la liste (24 aout
// 2026) car il a, des ce lot, de vraies prerogatives operationnelles (recruter_douanier/
// gerer_effectifs_douane) -- Pascal Paguevite doit donc disparaitre de l'affichage des lors
// qu'un vrai titulaire (PJ ou PNJ via la cascade) est enregistre, comme les ministres.

// resteApresPourvoi (22 septembre 2026). Un PNJ peut porter le `job` d'un poste SANS etre
// interchangeable avec son titulaire : Martial Bouterin est le referent militaire permanent du
// ministere de la Defense, et doit rester dans le bureau quand un joueur devient ministre --
// comme aide de camp, jamais comme ministre. C'etait deja l'intention du code
// (ajusterAttacheMinisteriel, plateau-navigation.js, le renomme « Attaché ministériel »), mais ce
// filtre le supprimait AVANT l'affichage : le renommage etait du code mort.
//
// Le drapeau est DECLARATIF et porte par le PNJ lui-meme dans data.js : aucun nom en dur ici,
// aucune liste parallele, et le comportement vaut pour tout futur ministre.
function filtrerPnjPostesPourvus(persons) {
  const cache = window._titulairesPostes || {};
  return persons.filter(p => {
    if (!p.job || !POSTES_UNIQUES_A_MASQUER.includes(p.job)) return true;
    if (!p.name || !p.name.includes('(PNJ)')) return true;
    if (p.resteApresPourvoi === true) return true;
    const titulaire = cache[p.job + '_' + state.currentCity] || cache[p.job];
    return !titulaire;
  });
}

async function rafraichirTitulairesPostesElectifs() {
  if (typeof sbListPersonnages !== 'function') return;
  try {
    const joueurs = await sbListPersonnages() || [];
    const cache = {};
    joueurs.forEach(j => {
      let poste = j.poste;
      if (typeof poste === 'string') { try { poste = JSON.parse(poste); } catch(e) { poste = null; } }
      if (!poste || !poste.id) return;
      const cle = poste.city ? (poste.id + '_' + poste.city) : poste.id;
      cache[cle] = j.name;
    });
    window._titulairesPostes = cache;
  } catch(e) {}
}

// MUTINERIE — IDENTIFICATION VISUELLE (23 septembre 2026).
// Un mutin doit etre reconnaissable immediatement, partout ou son identite s'affiche dans le
// monde. Le point d'injection est donc renderPersonsList, seul composeur des cartes de personnes
// presentes : un seul endroit a enrichir, aucune interface de renseignement artificielle.
//
// RP_MUTINS ne porte QUE des noms, jamais une position : un cache perime ne peut donc pas
// faire apparaitre quelqu'un au mauvais endroit -- ce n'est pas la famille de bug des agents
// poses. Il est relu a chaque entree de piece, en meme temps que le reste de la presence.
let RP_MUTINS = [];

function estMutin(nom) {
  return !!nom && RP_MUTINS.indexOf(nom) !== -1;
}

function marqueurMutinHtml(nom) {
  return estMutin(nom)
    ? '<div style="font-family:Bebas Neue,sans-serif;font-size:.74rem;letter-spacing:.12em;color:#cc4444">MUTIN</div>'
    : '';
}

async function rafraichirMutins() {
  if (typeof sbMutineriesMembres !== 'function') return RP_MUTINS;
  const membres = await sbMutineriesMembres().catch(() => null);
  RP_MUTINS = Array.isArray(membres)
    ? membres.filter(m => m && m.statut === 'actif').map(m => m.personnage)
    : [];
  return RP_MUTINS;
}

// Fiche d'information d'un detachement, pour qui n'en est pas le chef. Strictement en lecture :
// ce que la carte affiche deja, et rien de plus -- ni effectif detaille, ni compagnie, ni section,
// et surtout aucune action. Un joueur qui croise des soldats en faction voit des soldats en
// faction, pas un PNJ a recruter.
function ouvrirInfoDetachement(nomEncode, roleEncode) {
  const nom = decodeURIComponent(nomEncode || '');
  const role = decodeURIComponent(roleEncode || '');
  const ech = (t) => (typeof escapeHtmlText === 'function') ? escapeHtmlText(t) : t;
  document.getElementById('postes-modal-title').textContent = 'Détachement militaire';
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:1rem">' +
    '<div style="font-size:.9rem;color:#e0d5b8;margin-bottom:.3rem">' + ech(nom) + '</div>' +
    '<div style="font-size:.8rem;color:#8ac05a;margin-bottom:.8rem">' + ech(role) + '</div>' +
    '<div style="font-size:.78rem;color:#8a8060;font-style:italic;line-height:1.6">' +
      'Ces hommes sont en service. Seul l\'officier qui commande leur section peut leur donner des ordres.' +
    '</div></div>';
  document.getElementById('modal-postes').classList.add('open');
}

function renderPersonsList(persons, targetId) {
  targetId = targetId || 'persons-list';
  persons = [...(persons || [])]; // mutable copy
  persons = appliquerRemplacantCodetenu(persons);
  persons = filtrerPnjPostesPourvus(persons);
  // Assemblee nationale (chantier du 10 septembre 2026) : les neuf deputes PNJ sont injectes ici
  // plutot que declares en dur dans data.js, parce que leur ROLE change selon l'occupation reelle
  // des sieges (depute si le siege est libre, assistant parlementaire s'il est tenu par un PJ) --
  // ce qu'une liste statique ne peut pas exprimer. No-op hors de l'hemicycle.
  if (typeof appliquerDeputesAssemblee === 'function') persons = appliquerDeputesAssemblee(persons);
  const relCol = r => r === 'ally' ? '#4a8a4a' : r === 'enemy' ? '#8a3a2a' : '#6a6040';
  const relTxt = r => r === 'ally' ? 'Allie' : r === 'enemy' ? 'Hostile' : 'Neutre';

  const char = state.char;
  const ar = ARCHETYPES.find(x => x.id === char?.archetype);

  // Carte du PJ lui-meme — cliquable pour ouvrir la fiche personnage centrale
  const savedPhoto = localStorage.getItem('respublica_photo_' + (state.char?.name || 'default')) || localStorage.getItem('respublica_photo');
  const photoUrl = savedPhoto || char?.photoUrl;
  const photoHtml = photoUrl
    ? '<img src="' + photoUrl + '" alt="Vous" style="width:100%;height:100%;object-fit:cover;border-radius:50%"/>'
    : '<i class="ti ti-user" style="font-size:.75rem;color:#C9A84C"></i>';

  const selfCard = char ? '<div class="person-card" style="border-left:2px solid #C9A84C;cursor:pointer" onclick="openSelfView()" title="Cliquer pour dormir, inventaire, fiche">' +
    '<div class="person-avatar" style="border-color:#C9A84C">' + photoHtml + '</div>' +
    '<div>' +
    '<div class="person-name" style="color:#C9A84C">' + char.name + ' <span style="font-size:.8rem;color:#6a5a20">(Vous)</span></div>' +
    marqueurMutinHtml(char.name) +
    (state.recherche?.length > 0 ? '<div style="font-size:.82rem;color:#cc2020;font-family:Bebas Neue,sans-serif;letter-spacing:.1em;animation:blink 1s infinite">⚠ RECHERCHÉ</div>' : '') +
    '<div class="person-role">' + (state.poste?.name || ar?.name || 'Citoyen') + '</div>' +
    '</div></div>' : '';

  // UNE SEULE FABRIQUE DE CARTE, deux usages (29 septembre 2026). La meme fonction sert aux
  // presences autonomes et aux accompagnants : seule leur PLACE dans la liste differe, jamais
  // leur apparence ni leur comportement au clic. Extraire ce corps du .map() est ce qui permet
  // de composer la hierarchie sans dupliquer une ligne de rendu.
  const carteDePersonne = (p) => {
    const av = PNJ_AVATAR[p.job] || PNJ_AVATAR.default;
    const empireCol = COUNTRIES[state.country]?.col || '#C9A84C';
    const avatarHtml = p.photoUrl
      ? '<div class="person-avatar" style="overflow:hidden;border-color:' + (av.color || empireCol) + '">' +
        '<img src="' + p.photoUrl + '" style="width:100%;height:100%;object-fit:cover;object-position:' + (p.photoPos || '50% 15%') + '"/>' +
        '</div>'
      : '<div class="person-avatar"><i class="ti ' + av.icon + '" style="font-size:.75rem;color:' + (av.color || '#8a8060') + '"></i></div>';

    // Cadavre : onclick spécial via data-attributes
    if (p.terrainPnjId === 'cadavre') {
      return '<div class="person-card" onclick="ouvrirCadavreListe(this)" ' +
        'data-photo="' + (p.photoUrl || '') + '" ' +
        'data-pos="' + (p.photoPos || '50% 40%') + '" ' +
        'data-role="' + (p.role || 'Cadavre') + '" ' +
        'data-trait="' + (p.trait || '').replace(/"/g, '&quot;') + '">' +
        avatarHtml +
        '<div>' +
        '<div class="person-name">' + p.name + '</div>' +
        '<div class="person-role">' + p.role + '</div>' +
        '<div class="person-rel" style="color:#8a3a2a;font-size:.78rem">⚠ Décédé</div>' +
        '</div></div>';
    }

    // DETACHEMENT MILITAIRE : PAS UN PNJ (23 septembre 2026). Cette carte agrege plusieurs
    // soldats en une ligne. Envoyee a openPnjModal comme les autres, elle etait lue comme un PNJ
    // recrutable de l'archetype civil « militaire » (data.js) : le Lieutenant se voyait proposer
    // de RECRUTER ses propres soldats a 500 FR/jour, avec les 10 places du groupe de compagnons
    // et les caracteristiques d'un militaire generique. On intercepte donc AVANT l'onclick
    // generique, exactement comme le fait deja le cadavre juste au-dessus.
    //
    // Le chef de la section est renvoye vers sa vraie mecanique ; tout autre joueur n'obtient
    // qu'une fiche d'information. Ce n'est pas la securite -- les RPC militaires revalident
    // l'autorite -- c'est la coherence de l'interface.
    if (p.detachement === true) {
      const estSonChef = state.poste?.id === 'lieutenant' && p.lieutenantNom
                      && p.lieutenantNom === state.char?.name;
      // Les deux libelles contiennent des guillemets doubles (« Soldats section "X" ») : ils sont
      // encodes avant d'entrer dans l'attribut onclick, sinon ils le fermeraient prematurement.
      const action = estSonChef ? 'doGererDetachement()'
        : "ouvrirInfoDetachement('" + encodeURIComponent(p.name) + "','" + encodeURIComponent(p.role) + "')";
      const ech = (t) => (typeof escapeHtmlText === 'function') ? escapeHtmlText(t) : t;
      return '<div class="person-card" style="border-left:2px solid #6a8a4a;cursor:pointer" onclick="' + action + '">' +
        avatarHtml +
        '<div>' +
        '<div class="person-name">' + ech(p.name) + '</div>' +
        '<div class="person-role">' + ech(p.role) + '</div>' +
        '<div class="person-rel" style="color:#8ac05a;font-size:.78rem">' +
          (estSonChef ? 'Votre section — cliquez pour la gérer' : 'Détachement militaire') + '</div>' +
        '</div></div>';
    }

    const pData = encodePnjSafe(p);
    return '<div class="person-card" onclick="openPnjModal(this.dataset.enc)" data-enc="' + pData + '">' +
      avatarHtml +
      '<div>' +
      '<div class="person-name">' + p.name + '</div>' +
      marqueurMutinHtml(p.name) +
      '<div class="person-role">' + p.role + '</div>' +
      '<div class="person-rel" style="color:' + relCol(p.rel) + ';font-size:.78rem">' + relTxt(p.rel) + '</div>' +
      '</div></div>';
  };

  // PRESENCE AUTONOME ou ACCOMPAGNANTE : le tri se fait sur une propriete portee par la donnee
  // elle-meme, jamais sur une liste de familles ecrite ici. Une mecanique qui declarera demain
  // un accompagnant sera rattachee sans qu'une ligne de ce fichier change.
  const accompagnants = persons.filter(p => p && p.estAccompagnement === true);
  const autonomes     = persons.filter(p => !p || p.estAccompagnement !== true);
  const personCards   = autonomes.map(carteDePersonne).join('');

  // Ajouter PNJ terrain si on est sur un terrain
  // (ce bloc etait ecrit DEUX FOIS a l'identique ; le doublon est retire le 29 septembre 2026.
  //  Il etait sans effet -- le garde par nom dedoublonnait -- mais restait du code mort.)
  if (state.currentBuilding?.startsWith('terrain-a-batir')) {
    const stored = sessionStorage.getItem('terrain_pnj_' + state.currentBuilding);
    if (stored) {
      try {
        const pnjTerrain = JSON.parse(stored);
        if (pnjTerrain.name && !persons.find(p => p.name === pnjTerrain.name)) {
          persons = [...persons, pnjTerrain];
        }
      } catch(e) {}
    }
  }
  const simules = getSimulesPresents();
  const simuleCards = simules.map(p => {
    const enc = encodePnjSafe({...p, isPJ: true});
    return '<div class="person-card" onclick="openPnjModal(this.dataset.enc)" data-enc="' + enc + '" style="border-left:2px solid #4a6aaa">' +
      '<div class="person-avatar" style="border-color:#4a6aaa"><i class="ti ti-user-circle" style="font-size:.75rem;color:#4a6aaa"></i></div>' +
      '<div><div class="person-name" style="color:#8aaad0">' + p.name + ' <span style="font-size:.8rem;color:#3a5a8a">[SIM]</span></div>' +
      '<div class="person-role">' + p.role + '</div>' +
      '<div style="font-size:.8rem;color:#3a5a8a">INF:' + p.resources.inf + ' POP:' + p.resources.pop + '</div>' +
      '</div></div>';
  }).join('');

  // Ajouter les employés du groupe présents dans cette pièce
  const groupeHtml = getGroupeHtmlPourPiece(state.currentBuilding, state.currentRoom);

  // UN GROUPE APPARTIENT A SON CHEF (29 septembre 2026).
  //
  // Jusqu'ici tout arrivait au meme niveau : le joueur, ses employes, ses agents portes, et --
  // perdue au milieu des PNJ du lieu -- la carte de sa section de 24 soldats. Rien ne disait a
  // l'oeil que ces gens l'accompagnent. La regle est desormais explicite : une presence est
  // AUTONOME (elle se tient la) ou ACCOMPAGNANTE (elle suit quelqu'un), et une accompagnante
  // s'affiche en retrait sous son chef.
  //
  // Le tri se fait sur une propriete portee par la donnee, `estAccompagnement`, pas sur une
  // liste de familles ecrite ici : une mecanique qui declarera demain un accompagnant sera
  // rattachee sans qu'une ligne de ce fichier change. C'est la seule facon d'eviter le « si
  // soldats alors ceci, si employes alors cela » que nous refusons.
  const moiNom = state.char?.name || null;
  // Accompagnants du JOUEUR COURANT : ils rejoignent son propre bloc, sous sa carte. Un
  // accompagnant sans chef nomme est rattache au joueur par defaut -- c'est le seul chef que
  // cette liste connaisse avec certitude.
  const miensHtml = accompagnants
    .filter(p => !p.leader || (moiNom && p.leader === moiNom))
    .map(carteDePersonne).join('');
  // Accompagnants d'un AUTRE chef. La carte de ce chef n'existe pas encore : elle est posee
  // plus tard par chargerVraisJoueursPresents, apres deux allers-retours reseau. On ne peut
  // donc pas la rattacher ici -- mais on ne va pas non plus l'abandonner au milieu des
  // presences autonomes.
  //
  // On fait les deux : on la DEPOSE a plat, dans un conteneur qui porte le nom de son chef,
  // ET on la memorise par chef. Quand la carte du chef arrivera, elle reprendra ce contenu et
  // retirera le conteneur : le groupe est DEPLACE, jamais duplique. Si ce second rendu
  // n'arrive jamais -- reseau coupe --, le conteneur reste et rien n'est perdu.
  const parLeader = {};
  accompagnants.filter(p => p.leader && moiNom && p.leader !== moiNom)
    .forEach(p => { (parLeader[p.leader] = parLeader[p.leader] || []).push(p); });
  RP_ACCOMPAGNANTS_AUTRES = {};
  const autresAccompagnantsHtml = Object.keys(parLeader).map(nom => {
    const html = parLeader[nom].map(carteDePersonne).join('');
    RP_ACCOMPAGNANTS_AUTRES[nom] = html;
    return '<div class="presence-groupe" data-accompagnant-de="' + attrHtml(nom) + '">' + html + '</div>';
  }).join('');

  const monGroupeHtml = (groupeHtml + miensHtml)
    ? '<div class="presence-groupe">' + groupeHtml + miensHtml + '</div>' : '';

  const finalContent = selfCard + monGroupeHtml + autresAccompagnantsHtml + simuleCards + personCards;
  document.getElementById(targetId).innerHTML = finalContent ||
    '<div class="person-empty">Personne d\'autre ici</div>';

  // Charger les VRAIS joueurs présents dans cette pièce (Supabase) — async, ajouté après coup
  chargerVraisJoueursPresents();
  // Charger les objets abandonnés visibles dans cette pièce — affichés à la suite des personnes
  if (typeof chargerObjetsAbandonnesDansPiece === 'function') chargerObjetsAbandonnesDansPiece();
}

// Cache partagé des photos de profil (nom -> photo_url), réutilisé pour la présence, le forum et les mails
window._cachePhotosJoueurs = window._cachePhotosJoueurs || {};
window._cachePhotosJoueursTimestamp = window._cachePhotosJoueursTimestamp || 0;
async function rafraichirCachePhotosJoueurs() {
  const maintenant = Date.now();
  // Rafraichir au maximum toutes les 60 secondes pour éviter de spammer Supabase
  if (maintenant - window._cachePhotosJoueursTimestamp < 60000 && Object.keys(window._cachePhotosJoueurs).length > 0) {
    return window._cachePhotosJoueurs;
  }
  if (typeof sbListPersonnages === 'function') {
    try {
      const joueurs = await sbListPersonnages() || [];
      const cache = {};
      joueurs.forEach(j => { if (j.photo_url) cache[j.name] = j.photo_url; });
      window._cachePhotosJoueurs = cache;
      window._cachePhotosJoueursTimestamp = maintenant;
    } catch(e) {}
  }
  return window._cachePhotosJoueurs;
}

// Retourne le HTML d'avatar (vraie photo si connue, sinon icone par defaut)
function getAvatarHtmlPourNom(nom, taille, bordColor) {
  const t = taille || 32;
  const c = bordColor || '#C9A84C';
  // Photo joueur reelle en priorite, sinon photo PNJ connue (PNJ_PHOTOS, plateau-core.js --
  // correctif du 21 aout 2026 pour Jodie Moitout) avant de retomber sur l'icone generique.
  const photo = window._cachePhotosJoueurs?.[nom] || (typeof PNJ_PHOTOS !== 'undefined' && PNJ_PHOTOS[nom]);
  if (photo) {
    return '<div style="width:' + t + 'px;height:' + t + 'px;border-radius:50%;overflow:hidden;border:1px solid ' + c + ';flex-shrink:0"><img src="' + photo + '" style="width:100%;height:100%;object-fit:cover"/></div>';
  }
  return '<div style="width:' + t + 'px;height:' + t + 'px;border-radius:50%;background:#1a1508;border:1px solid ' + c + ';display:flex;align-items:center;justify-content:center;flex-shrink:0"><i class="ti ti-user" style="font-size:' + (t*0.45) + 'px;color:' + c + '"></i></div>';
}

// ACCOMPAGNANTS DES AUTRES JOUEURS, EN ATTENTE DE LEUR CHEF (29 septembre 2026).
// Rempli par renderPersonsList, consomme par chargerVraisJoueursPresents. C'est un relais entre
// deux rendus decales, pas une source de verite : la position reste resolue par le serveur, et
// cette table est reecrite entierement a chaque composition de liste.
let RP_ACCOMPAGNANTS_AUTRES = {};

// Echappement pour une valeur d'ATTRIBUT HTML. escapeHtmlText suffit pour du texte, mais un nom
// place dans un attribut doit aussi voir ses guillemets neutralises, sinon il le referme.
function attrHtml(v) {
  return String(v == null ? '' : v)
    .replace(/&/g, '&amp;').replace(/"/g, '&quot;')
    .replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

// Affiche les autres PJ réellement présents dans la pièce courante (rafraîchi périodiquement)
async function chargerVraisJoueursPresents(buildingIdParam, roomIdParam, targetId) {
  if (typeof sbGetPresencesInRoom !== 'function') return;
  const buildingId = buildingIdParam !== undefined ? buildingIdParam : state.currentBuilding;
  const roomId = roomIdParam !== undefined ? roomIdParam : state.currentRoom;
  targetId = targetId || 'persons-list';
  const moi = state.char?.name;
  try {
    const presents = await sbGetPresencesInRoom(state.country, state.currentCity, buildingId, roomId);
    // Si on a change de piece/scene entre temps (pour la rue, on verifie le noeud actuel)
    if (buildingId === 'rue-centrale') {
      if (typeof rueCentraleNoeudActuel !== 'undefined' && rueCentraleNoeudActuel !== roomId) return;
    } else if (state.currentBuilding !== buildingId || state.currentRoom !== roomId) {
      return;
    }
    const autres = presents.filter(p => p.name !== moi);

    // Recuperer les photos depuis l'annuaire des personnages (presences n'a pas de photo)
    const photosParNom = await rafraichirCachePhotosJoueurs();

    // Mettre en cache pour getCurrentRoomPersons() (utilisé par assassinat, dons, etc.)
    window._vraisJoueursPresents = autres.map(p => ({
      name: p.name, role: 'Joueur', rel: 'neutral', isPJ: true, job: null,
      photoUrl: photosParNom[p.name] || null
    }));

    const empireCol = COUNTRIES[state.country]?.col || '#C9A84C';
    const cartePlayer = (p) => {
      const enc = encodePnjSafe(p);
      const avatarHtml = p.photoUrl
        ? '<div class="person-avatar" style="overflow:hidden;border-color:' + empireCol + '"><img src="' + p.photoUrl + '" style="width:100%;height:100%;object-fit:cover"/></div>'
        : '<div class="person-avatar" style="border-color:' + empireCol + '"><i class="ti ti-user" style="font-size:.75rem;color:' + empireCol + '"></i></div>';
      return '<div class="person-card vrai-joueur-card" onclick="openPnjModal(\'' + enc + '\')" style="border-left:2px solid ' + empireCol + '" title="Interagir">' +
      avatarHtml +
      '<div><div class="person-name" style="color:#f0ead6">' + p.name + ' <span style="font-size:.8rem;color:' + empireCol + '">[JOUEUR]</span></div>' +
      '<div class="person-role">Présent ici</div></div></div>';
    };

    // PNJ voyageant avec les autres joueurs presents (escorts, employes recrutes) --
    // simple affichage, non interactifs, pour rendre visible ce qui ne l'etait pas.
    // RATTACHES A LEUR CHEF depuis le 29 septembre 2026 : ils etaient jusqu'ici entasses a la
    // suite de TOUTES les cartes joueur, si bien qu'avec deux joueurs accompagnes on ne savait
    // plus qui menait qui. Ils sont desormais groupes par porteur, comme le groupe du joueur
    // courant l'est sous sa propre carte.
    const pnjParPorteur = {};
    const pnjDesAutres = [];
    autres.forEach(p => {
      (p.groupe_pnj || []).forEach(pnjInfo => {
        pnjParPorteur[p.name] = pnjParPorteur[p.name] || [];
        pnjParPorteur[p.name].push(pnjDesAutres.length);
        pnjDesAutres.push({ nom: pnjInfo.nom, role: (pnjInfo.role || 'PNJ') + ' de ' + p.name, photoUrl: pnjInfo.photoUrl || null, job: pnjInfo.job || 'default', proprietaire: p.name });
      });
    });
    window._pnjDesAutresJoueurs = pnjDesAutres;
    const carteMembreAutre = (idx) => {
      const p = pnjDesAutres[idx];
      const avatarHtmlAutre = p.photoUrl
        ? '<div class="person-avatar" style="overflow:hidden;border-color:#6a5a30"><img src="' + p.photoUrl + '" style="width:100%;height:100%;object-fit:cover"></div>'
        : '<div class="person-avatar" style="border-color:#6a5a30"><i class="ti ti-user" style="font-size:.75rem;color:#6a5a30"></i></div>';
      return '<div class="person-card autre-groupe-card" onclick="ouvrirFichePnjAutreJoueur(' + idx + ')" style="border-left:2px solid #6a5a30" title="Fiche du PNJ">' +
        avatarHtmlAutre +
        '<div><div class="person-name" style="color:#c0b090">' + p.nom + '</div>' +
        '<div class="person-role">' + p.role + '</div></div></div>';
    };

    // CHAQUE JOUEUR EMPORTE SON GROUPE. Meme regle que pour le joueur courant : la carte du
    // chef, puis ses accompagnants en retrait sous elle. Les deux sources se rejoignent ici --
    // les PNJ publies dans sa ligne de presence, et les accompagnants deposes a plat par
    // renderPersonsList en attendant que cette carte existe.
    const html = window._vraisJoueursPresents.map(p => {
      const membres = (pnjParPorteur[p.name] || []).map(carteMembreAutre).join('');
      const enAttente = RP_ACCOMPAGNANTS_AUTRES[p.name] || '';
      const bloc = (membres + enAttente)
        ? '<div class="presence-groupe">' + membres + enAttente + '</div>' : '';
      return '<div class="bloc-joueur-autre">' + cartePlayer(p) + bloc + '</div>';
    }).join('');

    // Retirer les anciennes cartes joueur avant d'inserer les nouvelles (evite les doublons au rafraichissement)
    const list0 = document.getElementById(targetId);
    if (list0) {
      list0.querySelectorAll('.bloc-joueur-autre').forEach(el => el.remove());
      list0.querySelectorAll('.vrai-joueur-card').forEach(el => el.remove());
      list0.querySelectorAll('.autre-groupe-card').forEach(el => el.remove());
      // Le groupe depose a plat par renderPersonsList est REPRIS, pas duplique : on retire son
      // conteneur des lors que la carte de son chef est sur le point d'etre posee. Celui dont le
      // chef n'est pas la reste en place -- on ne cache jamais un groupe.
      Object.keys(RP_ACCOMPAGNANTS_AUTRES).forEach(nom => {
        if (!window._vraisJoueursPresents.some(j => j.name === nom)) return;
        const orphelin = list0.querySelector('[data-accompagnant-de="' + attrHtml(nom) + '"]');
        if (orphelin) orphelin.remove();
      });
    }

    const htmlTotal = html;
    if (htmlTotal) {
      const list = document.getElementById(targetId);
      const empty = list.querySelector('.person-empty');
      if (empty) empty.remove();
      list.insertAdjacentHTML('beforeend', htmlTotal);
    }
  } catch(e) { console.warn('chargerVraisJoueursPresents error', e); }
}

// =====================
// AGENTS ETRANGERS SOUS COUVERTURE (19 septembre 2026)
// =====================
// Un agent de renseignement etranger depose dans cette piece s'y affiche comme
// n'importe quel passant -- et RIEN de plus.
//
// CE QUE LE NAVIGATEUR RECOIT. La RPC agents_renseignement_ici() ne renvoie
// qu'une colonne : nom_couverture. Elle n'accepte AUCUN parametre : le serveur
// relit la position de l'appelant en base, de sorte qu'on ne peut pas balayer
// la carte a la recherche d'agents. Ni le vrai nom, ni le role, ni l'empire
// proprietaire, ni l'identifiant de cellule ne quittent jamais le serveur --
// ils vivent dans des tables en RLS sans aucune policy.
//
// L'objet construit ici est donc volontairement PAUVRE : c'est lui qui part
// dans data-enc via encodePnjSafe, et tout champ qu'on y ajouterait serait
// lisible a l'inspecteur. On n'y met que ce qu'un passant voit.
async function chargerAgentsSousCouverture(targetId) {
  try {
    targetId = targetId || 'persons-list';
    const list = document.getElementById(targetId);
    if (!list) return;
    list.querySelectorAll('.agent-couverture-card').forEach(el => el.remove());
    if (typeof sbRpc !== 'function') return;
    const rows = await sbRpc('agents_renseignement_ici', {}).catch(() => null);
    if (!Array.isArray(rows) || rows.length === 0) return;

    const html = rows.map(r => {
      const nom = r && r.nom_couverture ? String(r.nom_couverture) : null;
      if (!nom) return '';
      // Strictement la couverture. Aucun identifiant, aucun attribut cache.
      const enc = encodePnjSafe({ name: nom, role: 'De passage', rel: 'neutral', job: 'default' });
      return '<div class="person-card agent-couverture-card" onclick="openPnjModal(\'' + enc + '\')" title="Interagir">' +
        '<div class="person-avatar"><i class="ti ti-user" style="font-size:.75rem"></i></div>' +
        '<div><div class="person-name">' + escapeHtmlText(nom) + '</div>' +
        '<div class="person-role">De passage</div></div></div>';
    }).join('');
    if (!html) return;
    const empty = list.querySelector('.person-empty');
    if (empty) empty.remove();
    list.insertAdjacentHTML('beforeend', html);
  } catch (e) { /* un agent qui ne s'affiche pas ne doit jamais casser la piece */ }
}

// =====================
// AGENTS QUE L'ON CONVOIE (21 septembre 2026)
// =====================
// LE DEPOT SE FAIT LA OU L'ON EST, DONC LE BOUTON VIT ICI. Le panneau du ministre
// (« Mes cellules ») n'est atteignable que depuis son ministere, et sa RPC ne rend
// que les cellules de l'empire OU IL SE TROUVE : une fois a l'etranger, il n'y a
// plus d'ecran pour deposer. agents_de_mon_groupe() existait deja pour ca et n'avait
// aucun appelant -- elle ne demande rien d'autre que « qui suis-je », relit la base
// et ne rend QUE les agents dont je suis le chef courant.
//
// CE QUI EST AFFICHE N'EST PAS UN SECRET : ce sont mes propres agents, et le serveur
// ne renvoie ni leur vrai nom ni leur cellule -- seulement la couverture, le role et
// l'identifiant dont le bouton a besoin.
async function chargerAgentsConvoyes(targetId) {
  try {
    targetId = targetId || 'persons-list';
    const list = document.getElementById(targetId);
    if (!list) return;
    list.querySelectorAll('.agent-convoye-card').forEach(el => el.remove());
    if (typeof sbRpc !== 'function') return;
    const r = await sbRpc('agents_de_mon_groupe', {}).catch(() => null);
    const res = Array.isArray(r) ? r[0] : r;
    if (!res || res.ok !== true) return;
    const agents = (res.agents || []).filter(a => a && a.id && a.statut === 'actif');
    window._agentsConvoyes = agents;
    if (!agents.length) return;

    const html = agents.map((a, i) =>
      '<div class="person-card agent-convoye-card" style="border-left:2px solid #8a6a20">' +
      '<div class="person-avatar"><i class="ti ti-user-shield" style="font-size:.75rem"></i></div>' +
      '<div style="flex:1"><div class="person-name">' + escapeHtmlText(String(a.couverture || 'Agent')) + '</div>' +
      '<div class="person-role">Sous votre conduite · ' + escapeHtmlText(String(a.role || '')) + '</div>' +
      '<button onclick="deposerAgentConvoye(' + i + ')" style="margin-top:.25rem;padding:.2rem .5rem;border:1px solid #6a8a20;background:transparent;color:#9ac04c;cursor:pointer;font-family:Bebas Neue,sans-serif;font-size:.66rem;letter-spacing:.08em">Déposer ici</button>' +
      '</div></div>').join('');
    const empty = list.querySelector('.person-empty');
    if (empty) empty.remove();
    list.insertAdjacentHTML('beforeend', html);
  } catch (e) { /* jamais bloquant pour la piece */ }
}

// Le refus vient du serveur et il est rendu tel quel : c'est lui qui sait si la
// piece convient, si la couverture tient dans cet empire, et si l'agent est encore
// disponible.
async function deposerAgentConvoye(idx) {
  const a = (window._agentsConvoyes || [])[idx];
  if (!a || typeof sbRpc !== 'function') return;
  const r = await sbRpc('agent_deposer', { p_agent_id: a.id }).catch(() => null);
  const res = Array.isArray(r) ? r[0] : r;
  if (!res || res.ok !== true) {
    const attendu = res?.attendu ? ((typeof COUNTRIES !== 'undefined' && COUNTRIES[res.attendu]?.n) || res.attendu) : null;
    const messages = {
      position_indefinie:             'On ne dépose pas un agent en pleine rue : entrez dans un lieu.',
      pas_mon_agent:                  'Vous ne convoyez pas cet agent.',
      agent_indisponible:             'Cet agent n\'est plus disponible.',
      pas_dans_le_pays_de_couverture: 'Sa couverture ne tient que dans l\'empire visé' + (attendu ? ' (' + attendu + ')' : '') + '.'
    };
    showToast('Dépôt impossible', messages[res?.raison] || ('Refus du serveur (' + (res?.raison || 'indisponible') + ').'), false);
    return;
  }
  showToast('Agent en place', escapeHtmlText(String(a.couverture || 'L\'agent')) + ' reste ici et commence à recueillir des informations.', true, true);
  if (typeof addJournalEntry === 'function') addJournalEntry('Un agent de renseignement a été déposé sur place.', 'event-info');
  await chargerAgentsConvoyes();
  if (typeof chargerAgentsSousCouverture === 'function') await chargerAgentsSousCouverture();
}

function ouvrirFichePnjAutreJoueur(idx) {
  const p = (window._pnjDesAutresJoueurs || [])[idx];
  if (!p) return;
  window._pnjAutreJoueurCourant = p;
  document.getElementById('pnj-modal-title').textContent = p.nom;
  const avatarEl = document.getElementById('pnj-avatar-container');
  if (avatarEl) {
    avatarEl.innerHTML = p.photoUrl
      ? '<img src="' + p.photoUrl + '" style="width:100%;height:100%;object-fit:cover;border-radius:50%"/>'
      : '<i class="ti ti-user" style="font-size:2rem"></i>';
  }
  const roleEl = document.getElementById('pnj-role-display');
  if (roleEl) roleEl.textContent = p.role;
  const traitEl = document.getElementById('pnj-trait-display');
  if (traitEl) traitEl.textContent = '';
  const speech = document.getElementById('pnj-speech');
  if (speech) speech.textContent = "Employe(e) de " + (p.proprietaire || 'quelqu\'un') + '.';
  const actionsEl = document.getElementById('pnj-actions');
  if (actionsEl) {
    actionsEl.innerHTML =
      '<button class="pnj-action-btn" onclick="contacterPnjAutreJoueur()"><i class="ti ti-message-circle" style="font-size:.85rem"></i> Contacter</button>' +
      '<button class="pnj-action-btn" style="color:#cc8844;border-color:#4a2a10" onclick="tentativeDebauchage(\'' + p.nom.replace(/'/g,'') + '\')"><i class="ti ti-user-question" style="font-size:.85rem"></i> Tenter de débaucher</button>';
  }
  document.getElementById('modal-pnj').classList.add('open');
}

async function contacterPnjAutreJoueur() {
  const p = window._pnjAutreJoueurCourant;
  if (!p) return;
  const speech = document.getElementById('pnj-speech');
  if (speech) speech.innerHTML = '<div class="pnj-loading"><span class="spin"></span> En train de repondre...</div>';
  const co = COUNTRIES[state.country];
  const prompt = 'Tu joues ' + p.nom + ', ' + (p.role || 'un personnage') + ' au service de ' + (p.proprietaire || 'quelqu\'un') + ', dans Res Publica (jeu politique parodique, empire ' + (co?.n || '') + '). Un autre personnage t\'aborde brievement. Reponds en 1-2 phrases, dans ton personnage, avec une pointe de loyaute envers ton employeur actuel mais sans etre hostile. Texte brut uniquement.';
  try {
    const r = await rpRedaction('pnj_autre_joueur', prompt);
    if (speech) speech.textContent = (r.texte || '').trim() || ('Bonjour. Je suis au service de ' + (p.proprietaire||'') + '.');
  } catch(e) {
    if (speech) speech.textContent = 'Bonjour. Je suis au service de ' + (p.proprietaire||'') + '.';
  }
}

// =====================================================================================
// AGENTS DE RENSEIGNEMENT DANS LE GROUPE (22 septembre 2026)
// =====================================================================================
// UN SEUL MODELE MENTAL : « ce PNJ est avec moi, ou je le laisse ici ». Les agents ne sont
// plus un second groupe invisible pilote par des boutons a part -- ils entrent dans le
// groupe general, au meme titre qu'une escorte ou un employe.
//
// POURQUOI UN CACHE ET PAS state.employes. L'appartenance d'un agent a un groupe vit cote
// SERVEUR (agents_renseignement.leader_courant), et c'est indispensable : un agent change
// de porteur entre deux PJ, ce que state.employes -- colonne privee de chaque fiche -- ne
// peut pas exprimer. On ne duplique donc pas cet etat : on le RELIT, et getMonGroupePNJ()
// se contente de le refleter. Une seule verite, cote serveur.
//
// CE QUE CE CACHE CONTIENT : uniquement l'identite de COUVERTURE. La RPC
// agents_couverture_de_mon_groupe ne rend ni vrai nom, ni role de renseignement, ni
// cellule -- elle est appelee par n'importe quel porteur, y compris un PJ qui ignore
// totalement ce qu'il transporte.
let RP_AGENTS_PORTES = [];
// Agents POSES dans la piece courante. Meme nature que RP_AGENTS_PORTES : un reflet du
// serveur, jamais un etat local. Deux listes parce qu'il y a deux situations physiques
// distinctes, pas deux systemes : un agent est porte OU pose, jamais les deux.
let RP_AGENTS_ICI = [];

async function rafraichirAgentsPortes() {
  if (typeof sbRpc !== 'function') return RP_AGENTS_PORTES;
  const r = await sbRpc('agents_couverture_de_mon_groupe', {}).catch(() => null);
  const res = Array.isArray(r) ? r[0] : r;
  RP_AGENTS_PORTES = (res && res.ok === true && Array.isArray(res.agents)) ? res.agents : [];
  return RP_AGENTS_PORTES;
}

// POURQUOI agents_couverture_ici() ET PLUS chargerAgentsSousCouverture() (22 septembre 2026).
// Les deux affichaient les agents poses, mais par deux chemins concurrents, et j'avais garde
// le plus pauvre. agents_renseignement_ici() ne rend QUE le nom de couverture -- ni
// identifiant, ni portrait --, d'ou deux defauts constates en jeu : l'agent pose perdait son
// portrait, et aucune reprise n'etait possible faute d'identifiant. Pire, cette fonction
// inserait ses cartes dans le DOM APRES un aller-retour reseau (insertAdjacentHTML), donc
// apres le rendu : au retour dans une piece, renderPersonsList() les effacait, et seul un
// rechargement complet les faisait reapparaitre.
// agents_couverture_ici() rend id + nom + portrait, et l'on passe par room.persons, que
// renderPersonsList lit deja. Une seule source, plus aucune ecriture DOM concurrente.
// OUBLIER LES AGENTS POSES DE LA PIECE QU'ON VIENT DE QUITTER (22 septembre 2026).
// RP_AGENTS_ICI n'etait ecrit qu'a un seul endroit -- rafraichirAgentsIci(), joignable
// uniquement depuis rafraichirPresenceAgents(), elle-meme appelee a l'ENTREE d'une piece.
// Aucune sortie ne la vidait : en quittant le batiment, la liste survivait, et tout rendu
// ulterieur -- la rue comprise -- reaffichait l'agent laisse derriere soi. L'agent n'avait
// pourtant pas bouge d'un pouce cote serveur : c'etait une presence fantome, purement cliente.
function viderAgentsIci() {
  RP_AGENTS_ICI = [];
}

async function rafraichirAgentsIci() {
  if (typeof sbRpc !== 'function') return RP_AGENTS_ICI;
  const r = await sbRpc('agents_couverture_ici', {}).catch(() => null);
  const res = Array.isArray(r) ? r[0] : r;
  RP_AGENTS_ICI = (res && res.ok === true && Array.isArray(res.agents)) ? res.agents : [];
  return RP_AGENTS_ICI;
}

// REPRENDRE UN AGENT LAISSE SUR PLACE. Primitive serveur existante (agent_prendre), qui
// verifie elle-meme la co-presence complete et l'autorite -- on ne re-implemente aucune regle.
async function reprendreAgentIci(agentId) {
  const r = typeof sbRpc === 'function' ? await sbRpc('agent_prendre', { p_agent_id: agentId }).catch(() => null) : null;
  const res = Array.isArray(r) ? r[0] : r;
  if (!res || res.ok !== true) {
    const motifs = {
      pas_au_meme_endroit: 'Il faut se trouver exactement là où vous l\'avez laissée.',
      deja_en_groupe:      'Quelqu\'un l\'accompagne déjà.',
      pas_mon_empire:      'Vous n\'avez pas autorité sur cette personne.',
      cellule_inactive:    'Cette mission est terminée.'
    };
    showToast('Impossible', (res && motifs[res.raison]) || 'Le serveur a refusé.', false);
    return;
  }
  await rafraichirAgentsPortes();
  showToast('Reprise en charge', 'Vous pouvez repartir ensemble.', true);
  if (typeof renderEmployesPanel === 'function') renderEmployesPanel();
  rafraichirPresenceAgents();
}

// LE CHEMIN DU PORTRAIT NE TRAHIT RIEN. Il est bati sur le ROLE TECHNIQUE (garde,
// traducteur, conseiller, coordinateur), jamais sur le vrai nom : un joueur qui transporte
// l'equipe sans rien savoir d'elle ne peut donc rien apprendre en lisant l'URL de l'image
// dans les outils de son navigateur. Il est calcule cote serveur, pour qu'aucune table de
// correspondance ne circule dans le navigateur.
// Les 16 fichiers (4 roles x 4 apparences) ne sont pas encore decoupes dans le depot : tant
// qu'ils manquent, le navigateur echoue silencieusement sur l'image et l'avatar generique du
// job prend le relais, comme pour tout PNJ sans photo. Rien a retirer quand ils arriveront.
function getMonGroupePNJ() {
  const liste = [];
  (state.escortActive || []).forEach(e => liste.push({ nom: e.nom, role: 'Escort', photoUrl: e.photoUrl || null, job: 'escort' }));
  // DOUBLON D'AFFICHAGE (26 septembre 2026). Une escort recrutee vit a la fois dans
  // state.escortActive et dans state.employes (avec job 'escort') : elle etait poussee deux fois
  // dans presences.groupe_pnj, donc affichee en DEUX cartes chez les autres joueurs.
  // On ne retient ici que les employes deja absents de la liste, par nom -- ce qui couvre aussi
  // l'escort debauchee, qui n'existe au contraire que dans escortActive.
  const dejaListes = new Set(liste.map(x => x.nom));
  (state.employes || []).filter(e => e.inGroupe && !dejaListes.has(e.nom))
    .forEach(e => liste.push({ nom: e.nom, role: e.role || 'Employe', photoUrl: e.photoUrl || null, job: e.job || 'default' }));
  // Sous leur seule identite de couverture, y compris pour le ministre : son ecran
  // « Suivre une operation » est le seul endroit ou les vrais noms apparaissent.
  RP_AGENTS_PORTES.forEach(a => liste.push({
    nom: a.nom, role: 'Connaissance', job: 'agent_renseignement',
    photoUrl: a.portrait || null, agentId: a.id
  }));
  return liste;
}

// « Laisser ici » pour un agent : c'est l'action generale du groupe, branchee sur la
// primitive serveur qui enregistre pays + ville + batiment + piece et retire le porteur.
// Le rattachement a l'operation n'est pas touche, et l'agent continue a collecter depuis
// cet endroit.
async function laisserAgentEnPlace(agentId) {
  const r = typeof sbRpc === 'function' ? await sbRpc('agent_deposer', { p_agent_id: agentId }).catch(() => null) : null;
  const res = Array.isArray(r) ? r[0] : r;
  if (!res || res.ok !== true) {
    showToast('Impossible', 'Cette personne ne peut pas rester ici pour le moment.', false);
    return;
  }
  await rafraichirAgentsPortes();
  showToast('Reste sur place', 'Cette personne reste dans cette pièce.', false);
  if (typeof renderEmployesPanel === 'function') renderEmployesPanel();
  if (typeof rafraichirPresenceAgents === 'function') rafraichirPresenceAgents();
}

// « Confier a un autre joueur ». Aucune acceptation n'est demandee : c'est la regle generale
// du jeu pour tous les PNJ. Le destinataire pourra simplement le laisser sur place s'il n'en
// veut pas. Il ne recoit strictement aucune information sur ce qu'il transporte.
async function confierAgentA(agentId, destinataire) {
  const r = typeof sbRpc === 'function'
    ? await sbRpc('agent_transferer', { p_agent_id: agentId, p_destinataire: destinataire }).catch(() => null) : null;
  const res = Array.isArray(r) ? r[0] : r;
  if (!res || res.ok !== true) {
    const motifs = {
      pas_au_meme_endroit: 'Cette personne doit se trouver dans la même pièce que vous.',
      destinataire_introuvable: 'Ce joueur est introuvable.',
      destinataire_est_moi: 'Vous l\'accompagnez déjà.',
      pas_mon_agent: 'Cette personne ne vous accompagne pas.'
    };
    showToast('Impossible', (res && motifs[res.raison]) || 'Le serveur a refusé.', false);
    return;
  }
  await rafraichirAgentsPortes();
  showToast('Transfert effectué', destinataire + ' prend le relais.', true);
  if (typeof renderEmployesPanel === 'function') renderEmployesPanel();
  rafraichirPresenceAgents();
}


// ROXANNE VELOURS — Recrutement escort
// =====================
// LES DEUX FONCTIONS D'EMBAUCHE HISTORIQUES ONT ETE SUPPRIMEES LE 1er OCTOBRE 2026.
//
// `ouvrirRecrutementEscort` et `confirmerRecrutementEscort` engageaient une escort
// par un NOM LIBRE et un genre, puis fabriquaient sa remplacante : un prenom tire
// dans poolParEmpireEtGenre, un portrait tire dans PHOTOS_ESCORT, assembles au
// hasard et sans lien l'un avec l'autre. Les deux viviers disparaissent avec elles.
//
// ON SUPPRIME PLUTOT QUE DE DEBRANCHER. Un second chemin d'embauche laisse vivant
// aurait fini par etre repris, avec son quota d'une escort par genre et ses
// identites jetables. La porte est fermee des deux cotes : ici, et au serveur, ou
// `escort` est sorti de employe_metiers_recrutables().
//
// Le chemin actuel : escortsAgenceRecruter(escort_id) dans plateau-escorts-agence.js,
// qui appelle la RPC escort_recruter -- laquelle resout l'empire, le tarif et le
// plafond elle-meme.

async function confirmerRenvoyerEscort(nomEscort) {
  document.getElementById('modal-pnj')?.classList.remove('open');
  if (!state.escortActive) state.escortActive = [];
  // LIBERATION AU SOCLE D'ABORD. L'escort est un PNJ du socle depuis le 27 septembre 2026 : la
  // retirer des structures clientes sans le dire au serveur laisserait un PNJ actif appartenant a
  // un joueur qui ne le voit plus -- et le quota le lui reprocherait au recrutement suivant.
  // best-effort : un echec de transport ne doit pas bloquer le renvoi cote joueur, mais il est
  // trace, car c'est exactement le cas ou les deux cotes divergeraient.
  const ref = state.escortActive.find(e => e.nom === nomEscort)
           || (state.employes || []).find(e => e.nom === nomEscort);
  if (ref?.pnjId && typeof sbEmployeLiberer === 'function') {
    const r = await sbEmployeLiberer(ref.pnjId, 'renvoi').catch(() => null);
    if (!r || r.ok !== true) console.warn('[escort] liberation socle non confirmee', ref.pnjId, r);
  }
  state.escortActive = state.escortActive.filter(e => e.nom !== nomEscort);
  if (state.employes) state.employes = state.employes.filter(e => e.nom !== nomEscort);
  if (state.group?.members) state.group.members = state.group.members.filter(n => n !== nomEscort);
  updateUI();
  if (typeof renderEmployesPanel === 'function') renderEmployesPanel();
  showToast('Escort renvoyee', nomEscort + ' ne fait plus partie de votre groupe.', true);
  addJournalEntry(nomEscort + ' a ete renvoyee.', 'event-info');
}


function payerEscorts() {
  if (!state.escortActive?.length) return;
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const toRemove = [];

  state.escortActive.forEach((escort, i) => {
    if (state.arg >= escort.tarif) {
      state.arg -= escort.tarif;
      addJournalEntry('Escort ' + escort.nom + ' payée. -' + escort.tarif + ' ' + cur + '.', 'event-info');
    } else {
      // Non-paiement — esclandre
      toRemove.push(i);
      state.pop = Math.max(0, (state.pop||0) - 20);
      state.dis = Math.max(0, (state.dis||50) - 15);
      addMailNotification('Tribunal', 'Plainte déposée par ' + escort.nom,
        escort.nom + ' a déposé une plainte pour non-paiement de services. -20 POP -15 DIS. La presse a été informée.');
      addExternalEvent('📰 SCANDALE : ' + (state.char?.name||'Anonyme') + ' accusé(e) de non-paiement par ' + escort.nom + ' !');
      addJournalEntry('Non-paiement escort. Plainte + article presse. -20 POP -15 DIS.', 'event-bad');
      // DEPART PRONONCE AU SOCLE (27 septembre 2026). Les consequences ci-dessus sont INCHANGEES --
      // -20 POP, -15 DIS, mail Tribunal, scandale diffuse : c'est le comportement historique et il
      // reste tel quel. Seul s'ajoute le fait de dire au serveur que ce PNJ n'est plus employe,
      // sans quoi le socle garderait une escort active appartenant a un joueur qui l'a perdue.
      // Volontairement sans await : cette fonction est appelee dans la sequence du reveil, et
      // l'effet local ne doit pas attendre le reseau.
      if (escort.pnjId && typeof sbEmployeLiberer === 'function') {
        sbEmployeLiberer(escort.pnjId, 'impaye').catch(() => {});
      }
      // Retirer du groupe
      if (state.group?.members) {
        state.group.members = state.group.members.filter(m => m !== escort.nom);
      }
    }
  });

  // RETRAIT SYMETRIQUE (26 septembre 2026). Une escort vit dans TROIS structures a la fois
  // (escortActive, employes, group.members). Le non-paiement ne la retirait que des deux
  // premieres : elle restait dans state.employes, donc toujours affichee comme accompagnante
  // dans « Personnes presentes » alors qu'elle venait de porter plainte et de partir.
  // Seuls confirmerRenvoyerEscort et licencierPnj nettoyaient les trois ; on le fait ici aussi.
  const partantes = toRemove.map(i => state.escortActive[i]?.nom).filter(Boolean);
  toRemove.reverse().forEach(i => state.escortActive.splice(i, 1));
  if (partantes.length && Array.isArray(state.employes)) {
    state.employes = state.employes.filter(e => !(e.job === 'escort' && partantes.includes(e.nom)));
  }
}



// =====================
// V31 — SYSTÈME DE GROUPE & EMPLOYÉS PNJ
// =====================

const MAX_EMPLOYES = 10;

function getEmployes() {
  if (!state.employes) state.employes = [];
  return state.employes;
}

const INFORMATEURS_CATALOGUE = [
  { nom: 'Momo Fouine',       genre: 'H', photoUrl: 'images/informateur-h-1-corpulent.webp' },
  { nom: 'Bernard Filature',  genre: 'H', photoUrl: 'images/informateur-h-2-lunettes.webp' },
  { nom: 'Gaspard Renseigne', genre: 'H', photoUrl: 'images/informateur-h-3-jeune-casquette.webp' },
  { nom: 'Lucienne Indic',    genre: 'F', photoUrl: 'images/informateur-f-2-agee.webp' },
  { nom: 'Rita Tuyau',        genre: 'F', photoUrl: 'images/informateur-f-3-brune.webp' },
  { nom: 'Nadège Oreille',    genre: 'F', photoUrl: 'images/informateur-f-1-la-poste.webp' }
];

async function doRecruterInformateurPNJ(pa) {
  if (!state.employes) state.employes = [];
  if (state.employes.some(e => e.job === 'informateur')) {
    showToast('Déjà en poste', 'Vous employez déjà un informateur. Renvoyez-le avant d\'en recruter un autre.', false);
    return;
  }
  const room = BUILDINGS[state.currentBuilding]?.rooms?.[state.currentRoom];
  const ordre = room?.orders?.find(o => o.fn === 'recruter_informateur_pnj');
  const cout = ordre?.cost || 150;
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  const infoChoisi = INFORMATEURS_CATALOGUE[Math.floor(Math.random() * INFORMATEURS_CATALOGUE.length)];
  const nomPnj = infoChoisi.nom + ' (PNJ)';

  // ===========================================================================
  // RECRUTEMENT AU SOCLE (27 septembre 2026)
  // ===========================================================================
  // Le paiement passait par deduireCoutOrdre puis le PNJ etait cree ici, en deux temps : un echec
  // apres le debit laissait le joueur paye sans informateur. employe_recruter fait les deux dans
  // UNE transaction, et continue de passer par payer_ordre -- le cout 1 PA / 150 FR reste donc
  // revalide contre le miroir de data.js, comme avant.
  //
  // LE PER N'EST PLUS TIRE ENTRE 12 ET 18. Le profil fixe du metier informateur vaut
  // INT 10 / CHA 10 / VOL 8 / PER 15 / DUP 12 / ENT 8, et il est COMPLET : les cinq autres
  // caracteristiques existent desormais aussi, alors que seule PER etait renseignee avant. Elles
  // entrent donc a leur tour dans les moyennes de groupe -- c'est la consequence assumee d'un
  // profil complet, pas un effet de bord.
  //
  // Le NOM reste tire au sort dans le catalogue : un nom n'est pas une caracteristique.
  if (!state.char?.name) {
    showToast('Action impossible', 'Votre personnage n\'est pas chargé.', false);
    return;
  }
  const resEmp = (typeof sbEmployeRecruter === 'function')
    ? await sbEmployeRecruter('informateur', nomPnj, infoChoisi.genre,
                              'recruter_informateur_pnj', pa, cout) : null;
  if (!resEmp || resEmp.ok !== true) {
    const motifs = {
      quota_metier_atteint: 'Vous employez déjà un informateur. Renvoyez-le avant d\'en recruter un autre.',
      plafond_employes: 'Vous employez déjà trop de monde.',
      paiement_refuse: cout + ' ' + cur + ' et ' + pa + ' PA requis.',
      acteur_non_authentifie: 'Votre personnage n\'est pas identifié.'
    };
    showToast('Recrutement impossible',
      motifs[resEmp && resEmp.raison] || 'Personne n\'a donné suite.', false);
    return;
  }
  if (typeof appliquerPaiementServeur === 'function') appliquerPaiementServeur(resEmp.paiement);
  const carInfo = resEmp.caracteristiques || {};
  const perInformateur = carInfo.PER;

  // ===========================================================================
  // FRAIS D'EMBAUCHE ET SALAIRE JOURNALIER SONT DEUX CHOSES (5 octobre 2026)
  // ===========================================================================
  // `cout` ci-dessus est le prix de L'ORDRE : ce qu'on paie une fois, a
  // l'embauche. `coutJour` est le SALAIRE, que payerEmployes() preleve a chaque
  // reveil. Ce bloc poussait `cout` dans state.employes[].cout, donc le prix
  // d'embauche etait preleve chaque nuit.
  //
  // LE DEFAUT ETAIT INVISIBLE, et c'est pourquoi il a survecu : l'informateur
  // vaut 150 FR a l'embauche ET 150 FR par jour, les deux nombres sont egaux,
  // le resultat etait juste par coincidence. Il devenait faux des le premier
  // metier aux deux tarifs differents -- un agent de securite a 500 FR
  // d'embauche et 0 FR de salaire se serait fait prelever 500 FR par nuit, puis
  // aurait quitte le groupe faute de paiement.
  //
  // On lit donc cout_jour, que la RPC rend deja, exactement comme le font les
  // escortes depuis le 1er octobre (escortsAgenceRecruter : `cout: r.cout_jour`).
  // Pour l'informateur le comportement est RIGOUREUSEMENT identique : 150 = 150.
  const coutJour = (typeof resEmp.cout_jour === 'number') ? resEmp.cout_jour : cout;

  state.employes.push({
    nom: nomPnj, pnjId: resEmp.pnj_id, role: 'Informateur', job: 'informateur',
    genre: infoChoisi.genre, photoUrl: infoChoisi.photoUrl, photoPos: '50% 15%',
    cout: coutJour, inGroupe: true,
    buildingId: state.currentBuilding,
    roomId: state.currentRoom,
    city: state.currentCity,
    depuis: state.day || 1,
    stats: carInfo
  });

  updateUI();
  // Message de confirmation enrichi (correctif visibilite de l'effet, 22 aout 2026) : rappelle
  // explicitement les 5 elements demandes (nom, PER, adhesion au groupe, salaire, effet reel) --
  // l'effet mecanique (moyenne de PER du groupe) etait deja correct mais jamais rappele au
  // joueur au moment ou il compte le plus, juste apres le recrutement.
  // Les deux montants sont annonces separement, et chacun avec le bon nom : le
  // premier est un frais d'embauche, le second un salaire.
  showToast('Informateur recruté !', nomPnj + ' (PER ' + perInformateur + ') rejoint votre groupe. -' + cout + ' ' + cur + ' à l\'embauche, puis ' + coutJour + ' ' + cur + '/jour. Sa PER s\'ajoute à celle du groupe pour les recherches, enquêtes et localisations.', true, true);
  addJournalEntry('Recrutement d\'un informateur : ' + nomPnj + ' (PER ' + perInformateur + ') rejoint le groupe, ' + coutJour + ' ' + cur + '/jour. Sa PER renforce le groupe pour les recherches, enquêtes et localisations.', 'event-good');

  // Pas d'ecriture dans room.persons (objet BUILDINGS global, partage par tous les
  // joueurs) : l'informateur a deja ete ajoute a state.employes avec inGroupe:true
  // ci-dessus, ce qui suffit a le faire apparaitre via la carte "Dans votre groupe"
  // (getGroupeHtmlPourPiece, lue directement par renderPersonsList). Ecrire aussi ici
  // produisait une deuxieme carte "Allie" permanente et dupliquee pour ce meme PNJ.
  if (room && typeof renderPersonsList === 'function') renderPersonsList(room.persons);
}

function isEmploye(nomPnj) {
  return getEmployes().some(e => e.nom === nomPnj);
}

function isInGroupe(nomPnj) {
  return getEmployes().some(e => e.nom === nomPnj && e.inGroupe);
}

// =====================
// RECRUTER UN PNJ
// =====================
function ouvrirModalRecrutPnj(encodedPnj) {
  let pnj;
  try { pnj = JSON.parse(decodeURIComponent(encodedPnj)); } catch(e) { return; }

  const nomCourt = pnj.name.replace(' (PNJ)', '');
  if (isEmploye(nomCourt)) {
    showToast('Déjà employé', nomCourt + ' travaille déjà pour vous.', false);
    return;
  }
  if (getEmployes().length >= MAX_EMPLOYES) {
    showToast('Limite atteinte', 'Vous ne pouvez pas recruter plus de ' + MAX_EMPLOYES + ' PNJ simultanément.', false);
    return;
  }

  const stats = getPnjStats(pnj);
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const cout = pnj.job === 'escort' ? 500 : (stats.recrutCout || 150);

  document.getElementById('postes-modal-title').textContent = 'Recruter — ' + nomCourt;
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.8rem 1rem">' +
    '<div style="font-size:.78rem;color:#a09060;font-style:italic;margin-bottom:.7rem;border-left:2px solid #3a2a10;padding-left:.6rem">' +
      (pnj.trait || 'Un PNJ disponible pour vos missions.') +
    '</div>' +
    '<div style="display:grid;grid-template-columns:repeat(4,1fr);gap:.3rem;margin-bottom:.7rem">' +
      '<div style="text-align:center;background:#0a0805;border:1px solid #1a1208;padding:.4rem"><div style="font-size:.78rem;color:#9a8a68">FOR</div><div style="font-size:.85rem;color:#C9A84C;font-family:Bebas Neue">' + stats.FOR + '</div></div>' +
      '<div style="text-align:center;background:#0a0805;border:1px solid #1a1208;padding:.4rem"><div style="font-size:.78rem;color:#9a8a68">CHA</div><div style="font-size:.85rem;color:#C9A84C;font-family:Bebas Neue">' + stats.CHA + '</div></div>' +
      '<div style="text-align:center;background:#0a0805;border:1px solid #1a1208;padding:.4rem"><div style="font-size:.78rem;color:#9a8a68">DUP</div><div style="font-size:.85rem;color:#C9A84C;font-family:Bebas Neue">' + stats.DUP + '</div></div>' +
      '<div style="text-align:center;background:#0a0805;border:1px solid #1a1208;padding:.4rem"><div style="font-size:.78rem;color:#9a8a68">LOY</div><div style="font-size:.85rem;color:#C9A84C;font-family:Bebas Neue">' + stats.loyaute + '</div></div>' +
    '</div>' +
    '<div style="font-size:.72rem;color:#6a5030;margin-bottom:.7rem">Coût : <strong style="color:#C9A84C">' + cout + ' ' + cur + '/jour</strong> · ' + (MAX_EMPLOYES - getEmployes().length) + ' place(s) restante(s)</div>' +
    '<button onclick="confirmerRecrutPnj(\'' + encodePnjSafe(pnj) + '\',' + cout + ')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.4rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">Recruter</button>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerRecrutPnj(encodedPnj, cout) {
  document.getElementById('modal-postes').classList.remove('open');
  showToast('Temporairement indisponible', 'Le recrutement de PNJ comme employé est en cours de refonte.', false);
  return;
  // Code ci-dessous desactive temporairement (duplication de PNJ en cours de refonte)
  let pnj;
  try { pnj = JSON.parse(decodeURIComponent(encodedPnj)); } catch(e) { return; }

  const nomCourt = pnj.name.replace(' (PNJ)', '');
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  document.getElementById('modal-postes').classList.remove('open');

  if (state.arg < cout) {
    showToast('Fonds insuffisants', cout + ' ' + cur + ' requis.', false);
    return;
  }
  if (getEmployes().length >= MAX_EMPLOYES) {
    showToast('Limite atteinte', 'Maximum ' + MAX_EMPLOYES + ' PNJ.', false);
    return;
  }

  state.arg -= cout;

  const stats = getPnjStats(pnj);
  const employe = {
    nom: nomCourt,
    nomComplet: pnj.name,
    role: pnj.role || '',
    job: pnj.job || 'default',
    photoUrl: pnj.photoUrl || '',
    photoPos: pnj.photoPos || '50% 15%',
    stats,
    cout,
    inGroupe: true,
    buildingId: state.currentBuilding,
    roomId: state.currentRoom,
    city: state.currentCity,
    depuis: state.day || 1,
  };

  state.employes.push(employe);
  updateUI();
  renderEmployesPanel();
  // Afficher immédiatement dans la pièce actuelle
  if (state.currentBuilding && state.currentRoom) {
    const room = BUILDINGS[state.currentBuilding]?.rooms?.[state.currentRoom];
    const world = WORLD[state.country];
    const city = world?.[state.currentCity];
    const ctx = city?.buildingContext?.[state.currentBuilding];
    const displayPersons = (ctx?.persons?.length > 0) ? ctx.persons : (room?.persons || []);
    renderPersonsList(displayPersons);
  }

  showToast(nomCourt + ' recruté(e) !', '-' + cout + ' ' + cur + '/jour. Il/elle rejoint votre groupe.', true);
  addJournalEntry('Recrutement : ' + nomCourt + ' (' + (pnj.role||'PNJ') + '). -' + cout + ' ' + cur + '/jour.', 'event-good');

  // Remplaçant générique pour le PNJ recruté
  if (typeof genererPnjRemplacant === 'function') {
    genererPnjRemplacant(pnj, employe);
  }

  // Trace enquête
  if (!state.tracesEnquete) state.tracesEnquete = [];
  state.tracesEnquete.push({
    type: 'recrutement_pnj',
    desc: (state.char?.name||'Anonyme') + ' a recruté ' + nomCourt + '.',
    jour: state.day || 1,
    expireJour: (state.day || 1) + 10
  });
}

// =====================
// PAIEMENT DES EMPLOYÉS AU RÉVEIL
// =====================
function payerEmployes() {
  const employes = getEmployes();
  if (employes.length === 0) return;
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const toFire = [];

  employes.forEach((emp, i) => {
    // DOUBLE FACTURATION DES ESCORTS (26 septembre 2026).
    // Une escort recrutee est poussee a la fois dans state.escortActive (avec `tarif`) et dans
    // state.employes (avec `cout: tarif`) -- cf. escortsAgenceRecruter. Or payerEscorts() et
    // payerEmployes() sont appelees coup sur coup au reveil : la meme escort etait payee DEUX FOIS,
    // et le journal affichait deux lignes pour un seul service.
    // payerEscorts() reste le payeur de reference : c'est elle qui porte les consequences propres
    // au metier (plainte au tribunal, -20 POP, -15 DIS, article de presse) que payerEmployes()
    // n'a pas. On saute donc les escorts ici, sans toucher a l'alignement des index de toFire.
    if (emp.job === 'escort') return;
    if (state.arg >= emp.cout) {
      state.arg -= emp.cout;
      addJournalEntry('Salaire ' + emp.nom + '. -' + emp.cout + ' ' + cur + '.', 'event-info');
    } else {
      toFire.push(i);
      addMailNotification('Ressources Humaines', emp.nom + ' a quitté votre service',
        emp.nom + ' n\'a pas été payé(e). Il/elle quitte votre groupe immédiatement.');
      addJournalEntry(emp.nom + ' non payé(e). Départ.', 'event-bad');
      showToast('Départ de ' + emp.nom, 'Fonds insuffisants. -1 employé.', false);
      // Depart prononce au socle, meme raison que pour l'escort. Effets historiques inchanges.
      if (emp.pnjId && typeof sbEmployeLiberer === 'function') {
        sbEmployeLiberer(emp.pnjId, 'impaye').catch(() => {});
      }
    }
  });

  toFire.reverse().forEach(i => state.employes.splice(i, 1));
}

// =====================
// LAISSER UN PNJ EN PLACE / RÉCUPÉRER
// =====================
function laisserPnjEnPlace(nomPnj) {
  const emp = getEmployes().find(e => e.nom === nomPnj);
  if (!emp) return;
  emp.inGroupe = false;
  emp.buildingId = state.currentBuilding;
  emp.roomId = state.currentRoom;
  emp.city = state.currentCity;

  // Compter combien de PNJ sont déjà laissés dans cette pièce
  const memeEndroit = getEmployes().filter(e =>
    !e.inGroupe && e.buildingId === state.currentBuilding && e.roomId === state.currentRoom && e.nom !== nomPnj
  );
  const msgGroupe = memeEndroit.length > 0
    ? ' Il/elle rejoint ' + memeEndroit.map(e => e.nom).join(', ') + ' sur place.'
    : ' Il/elle reste seul(e) dans cette pièce.';

  updateUI();
  renderEmployesPanel();
  // Rafraîchir la liste des personnes
  if (state.currentBuilding && state.currentRoom) {
    const room = BUILDINGS[state.currentBuilding]?.rooms?.[state.currentRoom];
    const ctx = WORLD[state.country]?.[state.currentCity]?.buildingContext?.[state.currentBuilding];
    renderPersonsList((ctx?.persons?.length > 0) ? ctx.persons : (room?.persons || []));
  }
  showToast(nomPnj + ' laissé(e) ici', 'Vous pouvez le/la récupérer à tout moment.' + msgGroupe, false);
}

function recupererPnjDansGroupe(nomPnj) {
  const emp = getEmployes().find(e => e.nom === nomPnj);
  if (!emp) return;
  // Vérifier que le PJ est dans la même pièce
  if (emp.buildingId !== state.currentBuilding || emp.roomId !== state.currentRoom) {
    showToast('Absent(e)', nomPnj + ' n\'est pas dans cette pièce.', false);
    return;
  }
  emp.inGroupe = true;
  updateUI();
  renderEmployesPanel();
  showToast(nomPnj + ' rejoint le groupe !', '', true);

  // Quete d'accueil : la premiere fois qu'un joueur recupere un employe via ce systeme,
  // on explique comment s'en separer plus tard (icone X dans Mes Employes).
  if (nomPnj === 'Jérémy' && typeof queteAccueilExpliquerLicenciement === 'function') {
    queteAccueilExpliquerLicenciement();
  }
}

async function licencierPnj(nomPnj) {
  const idx = state.employes?.findIndex(e => e.nom === nomPnj);
  if (idx === undefined || idx === null || idx < 0) return;
  const emp = state.employes[idx];
  // Meme raison que pour le renvoi d'une escort : le PNJ vit au socle, son depart doit y etre
  // prononce. `employe_liberer` le marque disparu et le delie -- jamais une suppression, que la
  // garde refuserait sur un PNJ actif.
  if (emp?.pnjId && typeof sbEmployeLiberer === 'function') {
    const r = await sbEmployeLiberer(emp.pnjId, 'licenciement').catch(() => null);
    if (!r || r.ok !== true) console.warn('[employe] liberation socle non confirmee', emp.pnjId, r);
  }
  state.employes.splice(idx, 1);

  // Retirer une eventuelle entree fantome dans la piece d'origine (anciens recrutements
  // avant correctif, ou PNJ non inGroupe rattaches a une piece precise).
  const roomOrigine = BUILDINGS[emp.buildingId]?.rooms?.[emp.roomId];
  if (roomOrigine?.persons) {
    const pIdx = roomOrigine.persons.findIndex(p => p.name === nomPnj);
    if (pIdx >= 0) roomOrigine.persons.splice(pIdx, 1);
  }

  updateUI();
  renderEmployesPanel();
  // Rafraichir la liste "personnes presentes" de la piece COURANTE : un employe inGroupe
  // apparait "Dans votre groupe" dans n'importe quelle piece, pas seulement celle ou il
  // a ete recrute — il faut donc toujours rafraichir ici, sans quoi la carte reste
  // affichee jusqu'a un rafraichissement complet de la page.
  if (state.escortActive) state.escortActive = state.escortActive.filter(e => e.nom !== nomPnj);
  if (state.group?.members) state.group.members = state.group.members.filter(n => n !== nomPnj);

  const roomCourante = BUILDINGS[state.currentBuilding]?.rooms?.[state.currentRoom];
  if (roomCourante && typeof renderPersonsList === 'function') {
    renderPersonsList(roomCourante.persons || []);
  }
  showToast(nomPnj + ' licencié(e)', 'Il/elle retourne à ses activités.', false);
  addJournalEntry('Licenciement : ' + nomPnj + '.', 'event-info');
}

// =====================
// DÉBAUCHAGE PAR UN AUTRE PJ
// =====================
function tentativeDebauchage(nomPnj) {
  const p = window._pnjAutreJoueurCourant;
  if (!p || p.nom !== nomPnj) return;
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  document.getElementById('postes-modal-title').textContent = 'Débaucher ' + nomPnj;
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.8rem 1rem">' +
    '<div style="font-size:.78rem;color:#a09060;font-style:italic;margin-bottom:.7rem">Actuellement au service de ' + (p.proprietaire || 'quelqu\'un') + '. Le résultat dépend de sa loyauté, de vos statistiques, et du pot-de-vin proposé.</div>' +
    '<div style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.1em;color:#8a6a20;margin-bottom:.3rem">POT-DE-VIN (' + cur + ')</div>' +
    '<input id="debauche-montant" type="number" min="100" step="100" placeholder="Ex: 500" style="width:100%;padding:.4rem .6rem;background:#0a0a07;border:1px solid #3a2a10;color:#f0ead6;font-family:Crimson Pro,serif;font-size:.9rem;box-sizing:border-box;margin-bottom:.7rem"/>' +
    '<button onclick="confirmerDebauchage()" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.75rem;padding:.4rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">Tenter le débauchage</button>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerDebauchage() {
  document.getElementById('modal-postes').classList.remove('open');
  const p = window._pnjAutreJoueurCourant;
  if (!p) return;
  const montant = parseInt(document.getElementById('debauche-montant')?.value || 0);
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  if (!montant || montant < 100) { showToast('Montant insuffisant', 'Minimum 100 ' + cur + '.', false); return; }
  if (getFondsDisponiblesOrdinaires() < montant) { showToast('Fonds insuffisants', montant + ' ' + cur + ' requis.', false); return; }

  const loyaute = PNJ_STATS_PAR_JOB[p.job]?.loyaute ?? 40;
  const dup = getStatEffective('DUP');
  const bonusMontant = Math.min(30, Math.floor(montant / 100));
  let taux = Math.round((100 - loyaute) / 2 + dup + bonusMontant);
  taux = Math.max(5, Math.min(85, taux));
  const roll = Math.floor(Math.random() * 100) + 1;

  const debit = await debiterFondsOrdinaires(montant);
  if (!debit.ok) { showToast('Fonds insuffisants', montant + ' ' + cur + ' requis.', false); return; }

  if (roll > taux) {
    updateUI();
    addJournalEntry('Tentative de débauchage de ' + p.nom + ' ratée (' + taux + '% de chances). -' + montant + ' ' + cur + '.', 'event-bad');
    showToast('Débauchage échoué', p.nom + ' est resté(e) fidèle à ' + (p.proprietaire || 'son employeur') + '.', false);
    document.getElementById('modal-pnj')?.classList.remove('open');
    return;
  }

  // DUPLICATION DE PNJ CORRIGEE (17 septembre 2026, audit des frontieres d'autorite).
  // Avant : un sbGet puis un sbUpdate DIRECTS sur la fiche de l'ancien employeur, dans un
  // try/catch et un .catch(() => {}) decoratifs. Depuis la fermeture RLS, un joueur ne peut plus
  // ecrire la fiche d'un autre et sbUpdate rend null sans lever : le retrait echouait TOUJOURS,
  // pendant que l'ajout chez le debaucheur (sa propre fiche) reussissait. Le PNJ restait donc
  // employe des DEUX joueurs, et le toast annoncait quand meme la reussite.
  // Desormais : le retrait est fait par le serveur, sous verrou. Tant qu'il n'est pas confirme,
  // le PNJ n'est PAS ajoute ici -- pas de second exemplaire, jamais.
  const retrait = (typeof sbPnjEmployeDebaucher === 'function')
    ? await sbPnjEmployeDebaucher(p.proprietaire, p.nom, p.job) : null;
  if (!retrait || retrait.ok !== true) {
    // Remboursement ATTESTE : on designe le debit, le serveur rend ce qu'il a preleve (§6.1).
    if (typeof rembourserFondsOrdinaires === 'function') {
      await rembourserFondsOrdinaires(debit.debitId, 'remboursement_debauchage', montant);
    } else if (typeof crediterFondsOrdinaires === 'function') crediterFondsOrdinaires(montant);
    updateUI();
    showToast('Débauchage impossible', 'Le transfert n\'a pas pu être enregistré. Votre argent vous est rendu.', false);
    document.getElementById('modal-pnj')?.classList.remove('open');
    return;
  }
  if (retrait.deja_parti) {
    if (typeof rembourserFondsOrdinaires === 'function') {
      await rembourserFondsOrdinaires(debit.debitId, 'remboursement_debauchage', montant);
    } else if (typeof crediterFondsOrdinaires === 'function') crediterFondsOrdinaires(montant);
    updateUI();
    showToast('Trop tard', p.nom + ' ne travaille déjà plus pour ' + (p.proprietaire || 'cet employeur') + '.', false);
    document.getElementById('modal-pnj')?.classList.remove('open');
    return;
  }

  if (p.job === 'escort') {
    if (!state.escortActive) state.escortActive = [];
    state.escortActive.push({ nom: p.nom, tarif: 800, depuis: state.day || 1, genre: 'F', palier: 0, photoUrl: p.photoUrl || null });
  } else {
    if (!state.employes) state.employes = [];
    state.employes.push({
      nom: p.nom, role: (p.role || '').split(' de ')[0] || 'Employe', job: p.job || 'default',
      photoUrl: p.photoUrl || '', photoPos: '50% 15%', inGroupe: true,
      buildingId: state.currentBuilding, roomId: state.currentRoom, city: state.currentCity, depuis: state.day || 1
    });
  }

  updateUI();
  if (typeof renderEmployesPanel === 'function') renderEmployesPanel();
  if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
  document.getElementById('modal-pnj')?.classList.remove('open');
  addJournalEntry('Débauchage réussi ! ' + p.nom + ' rejoint votre service (' + taux + '% de chances). -' + montant + ' ' + cur + '.', 'event-good');
  showToast('Débauchage réussi !', p.nom + ' rejoint désormais votre service.', true, true);
  if (typeof envoyerNotificationVraiJoueur === 'function') {
    envoyerNotificationVraiJoueur(p.proprietaire, 'Débauchage', (state.char?.name || 'Quelqu\'un') + ' a débauché ' + p.nom + ' de votre service.').catch(() => {});
  }
}

// =====================
// AFFICHAGE PANEL EMPLOYÉS
// =====================
function renderEmployesPanel() {
  const el = document.getElementById('employes-list');
  if (!el) return;
  const employes = getEmployes();
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  const panel = document.getElementById('employes-panel');
  // Les agents de renseignement portes s'affichent DANS CE MEME PANNEAU, sous leur identite
  // de couverture : pour le joueur, ce sont des accompagnants comme les autres. Le ministre
  // ne dispose ici d'aucune information de plus qu'un transporteur quelconque.
  const htmlAgents = (RP_AGENTS_PORTES || []).map(a => {
    const id = String(a.id).replace(/'/g, '');
    const avatar = a.portrait
      ? '<img src="' + a.portrait + '" style="width:28px;height:28px;border-radius:50%;object-fit:cover;border:1px solid #C9A84C;flex-shrink:0"/>'
      : '<div style="width:28px;height:28px;border-radius:50%;background:#1a1208;display:flex;align-items:center;justify-content:center;border:1px solid #C9A84C;flex-shrink:0"><i class="ti ti-user" style="font-size:.7rem;color:#8a6a20"></i></div>';
    return '<div style="display:flex;align-items:center;gap:.4rem;padding:.3rem 0;border-bottom:1px solid #1a1208">' + avatar +
      '<div style="flex:1;min-width:0">' +
        '<div style="font-size:.72rem;color:#c0b090;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">' + escapeHtmlText(a.nom) + '</div>' +
        '<div style="font-size:.8rem;color:#9a8a68">🟢 En groupe</div>' +
      '</div>' +
      '<div style="display:flex;gap:.2rem">' +
        '<button onclick="laisserAgentEnPlace(\'' + id + '\')" title="Laisser dans cette piece" style="background:none;border:1px solid #2a3a2a;color:#4a7a4a;cursor:pointer;padding:.15rem .3rem;font-size:.8rem">📍</button>' +
        '<button onclick="ouvrirConfierAgent(\'' + id + '\')" title="Confier a un joueur present" style="background:none;border:1px solid #3a2a10;color:#8a6a20;cursor:pointer;padding:.15rem .3rem;font-size:.8rem">👤</button>' +
      '</div></div>';
  }).join('');

  if (employes.length === 0 && !htmlAgents) {
    el.innerHTML = '<div style="font-size:.72rem;color:#9a8a68;font-style:italic;padding:.3rem 0">Aucun employé</div>';
    return;
  }
  if (employes.length === 0) { el.innerHTML = htmlAgents; if (panel) panel.style.display = 'block'; return; }
  // Ouvrir le panel automatiquement si employés présents
  if (panel && panel.style.display === 'none') {
    panel.style.display = 'block';
    const chev = document.getElementById('emp-chevron');
    if (chev) chev.style.transform = 'rotate(90deg)';
  }

  el.innerHTML = employes.map(emp => {
    const avatar = emp.photoUrl
      ? '<img src="' + emp.photoUrl + '" style="width:28px;height:28px;border-radius:50%;object-fit:cover;object-position:' + (emp.photoPos||'50% 15%') + ';border:1px solid ' + (emp.inGroupe ? '#C9A84C' : '#3a2a10') + ';flex-shrink:0"/>'
      : '<div style="width:28px;height:28px;border-radius:50%;background:#1a1208;display:flex;align-items:center;justify-content:center;border:1px solid ' + (emp.inGroupe ? '#C9A84C' : '#2a1a08') + ';flex-shrink:0"><i class="ti ti-user" style="font-size:.7rem;color:#8a6a20"></i></div>';

    return '<div style="display:flex;align-items:center;gap:.4rem;padding:.3rem 0;border-bottom:1px solid #1a1208">' +
      avatar +
      '<div style="flex:1;min-width:0">' +
        '<div style="font-size:.72rem;color:#c0b090;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">' + emp.nom + '</div>' +
        '<div style="font-size:.8rem;color:#9a8a68">' + (emp.inGroupe ? '🟢 En groupe' : '📍 En faction') + ' · ' + emp.cout + ' ' + cur + '/j</div>' +
      '</div>' +
      '<div style="display:flex;gap:.2rem">' +
        (emp.inGroupe
          ? '<button onclick="laisserPnjEnPlace(\'' + emp.nom.replace(/'/g,'') + '\')" title="Laisser dans cette piece — sort du groupe mais reste votre employe" style="background:none;border:1px solid #2a3a2a;color:#4a7a4a;cursor:pointer;padding:.15rem .3rem;font-size:.8rem">📍</button>'
          : '<button onclick="recupererPnjDansGroupe(\'' + emp.nom.replace(/'/g,'') + '\')" title="Faire rejoindre votre groupe" style="background:none;border:1px solid #3a2a10;color:#8a6a20;cursor:pointer;padding:.15rem .3rem;font-size:.8rem">🔄</button>'
        ) +
        '<button onclick="ouvrirDonnerEmploye(\'' + emp.nom.replace(/'/g,'') + '\')" title="Donner un objet a porter (plafond 100 unites au total)" style="background:none;border:1px solid #2a3a3a;color:#4a7a7a;cursor:pointer;padding:.15rem .3rem;font-size:.8rem">📦</button>' +
        '<button onclick="ouvrirReprendreEmploye(\'' + emp.nom.replace(/'/g,'') + '\')" title="Reprendre ce que porte cet employe" style="background:none;border:1px solid #3a3a2a;color:#7a7a4a;cursor:pointer;padding:.15rem .3rem;font-size:.8rem">↩️</button>' +
        '<button onclick="licencierPnj(\'' + emp.nom.replace(/'/g,'') + '\')" title="Renvoyer cet employe — arret du contrat et du salaire. Ce qu\'il porte est perdu." style="background:none;border:1px solid #3a1a1a;color:#6a3a2a;cursor:pointer;padding:.15rem .3rem;font-size:.8rem">✕</button>' +
      '</div>' +
    '</div>';
  }).join('') + htmlAgents;
}

// Confier un accompagnant a un autre joueur PRESENT. La liste vient de la presence
// multijoueur deja affichee dans la piece -- aucun annuaire nouveau, et le serveur revalide
// de toute facon la co-presence.
async function ouvrirConfierAgent(agentId) {
  let presents = [];
  if (typeof sbGetPresencesInRoom === 'function' && state.currentBuilding && state.currentRoom) {
    try {
      const tous = await sbGetPresencesInRoom(state.country, state.currentCity, state.currentBuilding, state.currentRoom);
      presents = (tous || []).map(p => p.name).filter(n => n && n !== state.char?.name);
    } catch (e) {}
  }
  document.getElementById('postes-modal-title').textContent = 'Confier un accompagnant';
  const id = String(agentId).replace(/'/g, '');
  let html = '<div style="padding:1rem">';
  if (presents.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucun autre joueur n\'est présent dans cette pièce.</div>';
  } else {
    html += '<div style="font-size:.82rem;color:#c0b090;margin-bottom:.7rem">Cette personne accompagnera le joueur choisi. '
         +  'Il n\'a rien à accepter, et pourra la laisser où il voudra.</div>';
    presents.forEach(n => {
      html += '<button onclick="confierAgentA(\'' + id + '\',\'' + String(n).replace(/'/g, '') + '\');document.getElementById(\'modal-postes\').classList.remove(\'open\')" '
           +  'style="display:block;width:100%;text-align:left;padding:.5rem .7rem;margin-bottom:.3rem;border:1px solid #2a2010;background:#0f0d05;color:#c0b090;cursor:pointer;font-family:Crimson Pro,serif;font-size:.85rem">'
           +  escapeHtmlText(n) + '</button>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

// =====================
// DONNER / REPRENDRE UN OBJET A UN EMPLOYE — chaque employe peut porter jusqu'a 100 unites
// (meme plafond que le joueur), plafond fixe pour tous les PNJ pour l'instant (voir Fred,
// 7 aout 2026 : differenciation par PNJ a construire plus tard si besoin). Ce qu'un employe
// porte est definitivement perdu s'il est licencie ou part faute de paiement.
// =====================
const PLAFOND_CHARGE_EMPLOYE = 100;

function getTotalChargeEmploye(emp) {
  return Object.values(emp.charge || {}).reduce((s, q) => s + q, 0);
}

function ouvrirDonnerEmploye(nomEmploye) {
  const emp = (state.employes || []).find(e => e.nom === nomEmploye);
  if (!emp) return;
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const chargeActuelle = getTotalChargeEmploye(emp);
  const placeRestante = Math.max(0, PLAFOND_CHARGE_EMPLOYE - chargeActuelle);

  if ((state.inventory || []).length === 0) {
    showToast('Inventaire vide', "Vous n'avez rien à donner.", false);
    return;
  }

  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.85rem;color:#8a8060;margin-bottom:.8rem">' + emp.nom + ' porte déjà ' + chargeActuelle + '/' + PLAFOND_CHARGE_EMPLOYE + ' unités. Place restante : ' + placeRestante + '.</div>';
  html += '<div style="display:flex;flex-direction:column;gap:.4rem">';
  state.inventory.forEach((item, idx) => {
    const qte = item.qty || 1;
    html += '<div style="display:flex;justify-content:space-between;align-items:center;padding:.5rem;border:1px solid #2a2010;background:#0f0d05">';
    html += '<span style="font-size:.85rem;color:#c0b090"><i class="ti ' + (item.icon||'ti-package') + '" style="margin-right:.3rem"></i>' + item.name + (qte > 1 ? ' (×' + qte + ')' : '') + '</span>';
    if (item.stackable && qte > 1) {
      html += '<div style="display:flex;gap:.3rem;align-items:center"><input type="number" min="1" max="' + Math.min(qte, placeRestante) + '" id="donner-emp-qty-' + idx + '" value="1" style="width:60px;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.2rem" /><button class="pnj-action-btn" onclick="confirmerDonnerEmploye(\'' + nomEmploye + '\',' + idx + ')" style="padding:.3rem .6rem">Donner</button></div>';
    } else {
      html += '<button class="pnj-action-btn" onclick="confirmerDonnerEmploye(\'' + nomEmploye + '\',' + idx + ')" style="padding:.3rem .6rem">Donner</button>';
    }
    html += '</div>';
  });
  html += '</div></div>';

  document.getElementById('postes-modal-title').textContent = 'Donner à ' + emp.nom;
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerDonnerEmploye(nomEmploye, idx) {
  const emp = (state.employes || []).find(e => e.nom === nomEmploye);
  const item = state.inventory[idx];
  if (!emp || !item) return;

  // TROU DE PROTECTION COMBLE (chantier C, 14 septembre 2026). Les quatre autres sorties
  // d'inventaire refusaient le colis secret ; celle-ci ne verifiait rien, et permettait donc de
  // s'en separer malgre tout -- rendant la quete criminelle impossible a terminer.
  // Garde CLIENT et non serveur, faute de mieux : la charge d'un employe vit dans state.employes,
  // un blob encore entierement cote navigateur. Cette sortie ne pourra passer par l'entonnoir
  // serveur que lorsque les employes y seront eux-memes -- voir le rapport, familles restantes.
  if (typeof colisSecretProtege === 'function' && colisSecretProtege(item)) {
    showToast('Impossible', 'Ce colis est indispensable à votre mission en cours. Remettez-le à son destinataire avant de vous en séparer.', false);
    return;
  }

  const chargeActuelle = getTotalChargeEmploye(emp);
  const placeRestante = Math.max(0, PLAFOND_CHARGE_EMPLOYE - chargeActuelle);
  if (placeRestante <= 0) {
    showToast('Charge maximale', emp.nom + ' ne peut plus rien porter de plus.', false);
    return;
  }

  if (!emp.charge) emp.charge = {};

  if (item.stackable && item.stackKey) {
    const qteVoulue = parseInt(document.getElementById('donner-emp-qty-' + idx)?.value || item.qty || 1);
    const qteReelle = Math.min(qteVoulue, item.qty || 1, placeRestante);
    if (qteReelle <= 0) return;

    emp.charge[item.stackKey] = (emp.charge[item.stackKey] || 0) + qteReelle;
    item.qty = (item.qty || 1) - qteReelle;
    if (item.qty <= 0) state.inventory.splice(idx, 1);
  } else {
    // Objet unique : cle basee sur le nom, compte pour 1 unite de charge
    const cle = '_unique_' + item.name;
    if (!emp.chargeUnique) emp.chargeUnique = [];
    emp.chargeUnique.push(item);
    emp.charge[cle] = (emp.charge[cle] || 0) + 1;
    state.inventory.splice(idx, 1);
  }

  renderInventory();
  document.getElementById('modal-postes')?.classList.remove('open');
  showToast('Objet confié', emp.nom + ' porte maintenant "' + item.name + '".', true);
  addJournalEntry('Vous avez confié "' + item.name + '" à ' + emp.nom + '.', 'event-info');
}

function ouvrirReprendreEmploye(nomEmploye) {
  const emp = (state.employes || []).find(e => e.nom === nomEmploye);
  if (!emp || !emp.charge || Object.keys(emp.charge).length === 0) {
    showToast('Rien à reprendre', emp?.nom + ' ne porte rien pour l\'instant.', false);
    return;
  }

  let html = '<div style="padding:1rem"><div style="display:flex;flex-direction:column;gap:.4rem">';
  Object.entries(emp.charge).forEach(([cle, qte]) => {
    if (qte <= 0) return;
    const estUnique = cle.startsWith('_unique_');
    const label = estUnique ? cle.replace('_unique_', '') : (RESSOURCES_ECONOMIE[cle]?.label || cle);
    html += '<div style="display:flex;justify-content:space-between;align-items:center;padding:.5rem;border:1px solid #2a2010;background:#0f0d05">';
    html += '<span style="font-size:.85rem;color:#c0b090">' + label + (qte > 1 ? ' (×' + qte + ')' : '') + '</span>';
    if (!estUnique && qte > 1) {
      html += '<div style="display:flex;gap:.3rem;align-items:center"><input type="number" min="1" max="' + qte + '" id="reprendre-emp-qty-' + cle + '" value="' + qte + '" style="width:60px;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.2rem" /><button class="pnj-action-btn" onclick="confirmerReprendreEmploye(\'' + nomEmploye + '\',\'' + cle + '\')" style="padding:.3rem .6rem">Reprendre</button></div>';
    } else {
      html += '<button class="pnj-action-btn" onclick="confirmerReprendreEmploye(\'' + nomEmploye + '\',\'' + cle + '\')" style="padding:.3rem .6rem">Reprendre</button>';
    }
    html += '</div>';
  });
  html += '</div></div>';

  document.getElementById('postes-modal-title').textContent = 'Reprendre à ' + emp.nom;
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerReprendreEmploye(nomEmploye, cle) {
  const emp = (state.employes || []).find(e => e.nom === nomEmploye);
  if (!emp || !emp.charge || !emp.charge[cle]) return;

  const estUnique = cle.startsWith('_unique_');

  if (estUnique) {
    const item = (emp.chargeUnique || []).find(i => ('_unique_' + i.name) === cle);
    if (!item) return;
    const qteAjoutee = addToInventory(item);
    if (qteAjoutee > 0) {
      emp.chargeUnique = emp.chargeUnique.filter(i => i !== item);
      delete emp.charge[cle];
    }
  } else {
    const qteVoulue = parseInt(document.getElementById('reprendre-emp-qty-' + cle)?.value || emp.charge[cle]);
    const res = RESSOURCES_ECONOMIE[cle];
    const qteAjoutee = addToInventory({ name: res?.label || cle, icon: res?.icon, stackable: true, stackKey: cle, qty: Math.min(qteVoulue, emp.charge[cle]) });
    if (qteAjoutee > 0) {
      emp.charge[cle] -= qteAjoutee;
      if (emp.charge[cle] <= 0) delete emp.charge[cle];
    }
  }

  document.getElementById('modal-postes')?.classList.remove('open');
  showToast('Objet récupéré', 'Repris à ' + emp.nom + '.', true);
  addJournalEntry('Vous avez repris ce que portait ' + emp.nom + '.', 'event-info');
}

// =====================
// DÉPLACEMENT — PNJ en groupe suivent le PJ
// =====================
function deplacerGroupeAvecPj(buildingId, roomId, cityId) {
  const employes = getEmployes();
  employes.forEach(emp => {
    if (emp.inGroupe) {
      emp.buildingId = buildingId;
      emp.roomId = roomId;
      emp.city = cityId || state.currentCity;
    }
  });
}

// =====================
// AFFICHAGE GROUPE DANS LA PIÈCE
// =====================
function getGroupeHtmlPourPiece(buildingId, roomId) {
  const employes = getEmployes();
  // Les employés inGroupe sont TOUJOURS avec le PJ, peu importe la pièce
  const iciGroupe = employes.filter(e => e.inGroupe);
  const iciFaction = employes.filter(e => !e.inGroupe && e.buildingId === buildingId && e.roomId === roomId);

  // AGENTS DE RENSEIGNEMENT PORTES (correctif du 22 septembre 2026). C'est ICI que la chaine
  // se rompait : cette fonction est le SEUL point qui injecte les accompagnants dans la liste
  // « personnes presentes » (renderPersonsList compose selfCard + groupeHtml + ...), et elle
  // ne lisait que getEmployes(). Les agents etaient donc bien dans le groupe cote serveur
  // (leader_courant), bien renvoyes par agents_couverture_de_mon_groupe(), bien presents dans
  // getMonGroupePNJ() -- mais getMonGroupePNJ() n'alimente que la presence multijoueur
  // diffusee aux AUTRES joueurs. Leur porteur, lui, ne les voyait nulle part.
  //
  // Ils sont toujours avec le PJ, comme un employe inGroupe : aucune condition de piece.
  // Un agent POSE n'apparait jamais ici -- agents_couverture_ici() ne rend que ceux dont
  // leader_courant est nul, et ils rejoignent room.persons. Jamais les deux a la fois.
  const agents = RP_AGENTS_PORTES || [];
  const poses  = RP_AGENTS_ICI || [];

  if (iciGroupe.length === 0 && iciFaction.length === 0 && agents.length === 0 && poses.length === 0) return '';

  // Agents LAISSES dans cette piece. Meme carte, meme identite de couverture, meme portrait
  // que lorsqu'ils accompagnent -- seule l'action change : reprendre au lieu de laisser.
  //
  // LE BOUTON N'APPARAIT QU'AU MINISTRE DE LA DEFENSE. Un joueur ordinaire qui croise l'un
  // d'eux voit une simple connaissance de passage : lui proposer « reprendre » reviendrait a
  // lui apprendre que ce n'est pas un PNJ comme un autre. Le serveur revalide de toute facon
  // l'autorite dans agent_prendre -- cette condition est du confort, jamais la securite.
  const peutReprendre = (state.poste?.id === 'min_def');
  const htmlAgentsPoses = poses.map(a => {
    const id = String(a.id).replace(/'/g, '');
    const av = a.portrait
      ? '<div class="person-avatar" style="overflow:hidden;border-color:#8a6a20">' +
        '<img src="' + a.portrait + '" style="width:100%;height:100%;object-fit:cover;object-position:50% 15%"/></div>'
      : '<div class="person-avatar" style="border-color:#8a6a20"><i class="ti ti-user" style="font-size:.75rem;color:#8a6a20"></i></div>';
    const encPose = encodePnjSafe({
      name: a.nom, role: 'Connaissance de passage', job: 'agent_renseignement',
      photoUrl: a.portrait || null, photoPos: '50% 15%', rel: 'neutral'
    });
    return '<div class="person-card" style="border-left:2px solid #8a6a20;cursor:pointer" ' +
      'onclick="openPnjModal(this.dataset.enc)" data-enc="' + encPose + '">' + av +
      '<div style="flex:1;min-width:0">' +
        '<div class="person-name" style="color:#a09060">' + escapeHtmlText(a.nom) + '</div>' +
        '<div class="person-role">Connaissance de passage</div>' +
        '<div style="font-size:.78rem;color:#4a4030">📍 Sur place</div>' +
      '</div>' +
      (peutReprendre
        ? '<div style="display:flex;align-items:center">' +
          '<button onclick="event.stopPropagation();reprendreAgentIci(\'' + id + '\')" title="Reprendre avec vous" ' +
          'style="background:none;border:1px solid #3a2a10;color:#8a6a20;cursor:pointer;padding:.15rem .3rem;font-size:.8rem">🔄</button>' +
          '</div>'
        : '') +
    '</div>';
  }).join('');

  const htmlAgentsPiece = agents.map(a => {
    const id = String(a.id).replace(/'/g, '');
    // Identite de COUVERTURE uniquement, pour tout le monde -- le ministre compris. Son
    // ecran « Suivre une operation » reste le seul a nommer les agents pour de vrai.
    const av = a.portrait
      ? '<div class="person-avatar" style="overflow:hidden;border-color:#C9A84C">' +
        '<img src="' + a.portrait + '" style="width:100%;height:100%;object-fit:cover;object-position:50% 15%"/></div>'
      : '<div class="person-avatar" style="border-color:#C9A84C"><i class="ti ti-user" style="font-size:.75rem;color:#8a6a20"></i></div>';
    // FICHE PNJ NORMALE (correctif du 22 septembre 2026). Cette carte n'avait aucun onclick :
    // un agent etait le seul present de la piece sur lequel cliquer ne faisait rien. On
    // reutilise openPnjModal comme pour tout autre PNJ -- aucune fiche parallele.
    //
    // L'OBJET ENCODE NE PORTE QUE LA COUVERTURE : nom de couverture, portrait de couverture,
    // role generique « Connaissance ». Ni vrai nom, ni role de renseignement, ni identifiant
    // d'agent, ni cellule, ni pays observe -- l'encodage part dans le DOM, lisible par
    // n'importe qui. La fiche n'affichera donc rien d'autre : openPnjModal lit name, role,
    // photoUrl, et cherche un trait dans PNJ_PERSONALITIES, ou les noms de couverture ne
    // figurent pas (verifie). Le ministre garde ses informations dans « Suivre une operation ».
    const encAgent = encodePnjSafe({
      name: a.nom, role: 'Connaissance', job: 'agent_renseignement',
      photoUrl: a.portrait || null, photoPos: '50% 15%', rel: 'neutral'
    });
    return '<div class="person-card" style="border-left:2px solid #C9A84C;cursor:pointer" ' +
      'onclick="openPnjModal(this.dataset.enc)" data-enc="' + encAgent + '">' + av +
      '<div style="flex:1;min-width:0">' +
        '<div class="person-name" style="color:#C9A84C">' + escapeHtmlText(a.nom) + '</div>' +
        '<div class="person-role">Connaissance</div>' +
        '<div style="font-size:.78rem;color:#4a6a20">🟢 Dans votre groupe</div>' +
      '</div>' +
      '<div style="display:flex;gap:.25rem;align-items:center">' +
        '<button onclick="event.stopPropagation();laisserAgentEnPlace(\'' + id + '\')" title="Laisser dans cette pièce" ' +
        'style="background:none;border:1px solid #2a3a2a;color:#4a7a4a;cursor:pointer;padding:.15rem .3rem;font-size:.8rem">📍</button>' +
        '<button onclick="event.stopPropagation();ouvrirConfierAgent(\'' + id + '\')" title="Confier à un joueur présent" ' +
        'style="background:none;border:1px solid #3a2a10;color:#8a6a20;cursor:pointer;padding:.15rem .3rem;font-size:.8rem">👤</button>' +
      '</div>' +
    '</div>';
  }).join('');

  const renderEmpCard = (emp, inGroupe) => {
    const borderCol = inGroupe ? '#C9A84C' : '#3a2a10';
    const avatarHtml = emp.photoUrl
      ? '<div class="person-avatar" style="overflow:hidden;border-color:' + borderCol + '">' +
        '<img src="' + emp.photoUrl + '" style="width:100%;height:100%;object-fit:cover;object-position:' + (emp.photoPos||'50% 15%') + '"/>' +
        '</div>'
      : '<div class="person-avatar" style="border-color:' + borderCol + '"><i class="ti ti-user" style="font-size:.75rem;color:#8a6a20"></i></div>';

    const encEmp = encodePnjSafe({ name: emp.nomComplet || emp.nom + ' (PNJ)', role: emp.role, job: emp.job, photoUrl: emp.photoUrl, photoPos: emp.photoPos, rel: 'ally' });
    return '<div class="person-card" style="border-left:2px solid ' + borderCol + ';cursor:pointer" onclick="openPnjModal(\'' + encEmp + '\')">' +
      avatarHtml +
      '<div>' +
        '<div class="person-name" style="color:' + (inGroupe ? '#C9A84C' : '#a09060') + '">' + emp.nom + '</div>' +
        '<div class="person-role">' + (emp.role || 'Employé') + '</div>' +
        '<div style="font-size:.78rem;color:' + (inGroupe ? '#4a6a20' : '#4a4030') + '">' + (inGroupe ? '🟢 Dans votre groupe' : '📍 En faction ici') + '</div>' +
      '</div>' +
    '</div>';
  };

  let html = htmlAgentsPiece + htmlAgentsPoses;
  if (iciGroupe.length > 0) {
    html += iciGroupe.map(e => renderEmpCard(e, true)).join('');
  }
  if (iciFaction.length > 0) {
    html += iciFaction.map(e => renderEmpCard(e, false)).join('');
  }
  return html;
}

// Re-rendu de la liste « personnes presentes » de la piece courante. Les accompagnants
// arrivent par une reponse serveur asynchrone : sans ce rappel, la liste reste celle
// dessinee avant la reponse, et les agents n'apparaissent qu'au changement de piece.
// LES PERSONNES « NORMALES » D'UNE PIECE — REGLE UNIQUE (22 septembre 2026).
// Trois sources, dans cet ordre de priorite, telles qu'elles etaient deja ecrites dans
// enterRoom : un roomOverride propre a la ville, puis le contexte de batiment mais SEULEMENT
// pour la premiere piece, puis les PNJ statiques de la piece. Cette expression etait recopiee
// en version simplifiee dans rafraichirPresenceAgents(), qui ignorait roomOverride et la
// condition isFirstRoom : les deux chemins auraient rendu des listes differentes dans une
// piece secondaire d'un batiment dote d'un contexte de ville. Une seule definition desormais.
function personnesNormalesDeLaPiece(buildingId, roomId) {
  const b = (typeof BUILDINGS !== 'undefined') ? BUILDINGS[buildingId] : null;
  const ctxRoomsExtra = (typeof getBuildingContext === 'function') ? getBuildingContext(buildingId)?.roomsExtra : null;
  const room = b?.rooms?.[roomId] || ctxRoomsExtra?.[roomId];
  const ctx = (typeof getBuildingContext === 'function') ? getBuildingContext(buildingId) : null;
  const isFirstRoom = Object.keys(b?.rooms || {})[0] === roomId;
  const roomOverride = ctx?.roomOverrides?.[roomId];
  if (roomOverride?.persons?.length > 0) return roomOverride.persons;
  if (isFirstRoom && ctx?.persons?.length > 0) return ctx.persons;
  return room?.persons || [];
}

// Relit les agents POSES dans la piece courante, puis redessine la liste des presents. Les
// deux situations passent par getGroupeHtmlPourPiece : portes (RP_AGENTS_PORTES) et poses
// ici (RP_AGENTS_ICI). Un agent est dans l'une ou dans l'autre, jamais dans les deux --
// agents_couverture_ici() ne rend que ceux dont leader_courant est nul.
//
// Le rendu se fait APRES la reponse serveur, en une seule ecriture : c'est ce qui corrige la
// disparition des agents poses au retour dans une piece. L'ancien chemin inserait ses cartes
// dans le DOM apres coup, et le rendu suivant les effacait.
// LE DETACHEMENT MILITAIRE EST RELU ICI AUSSI (23 septembre 2026). Ce rendu ne connaissait que
// les personnes normales : il effacait donc la ligne des soldats deposes, posee par enterRoom
// quelques dizaines de millisecondes plus tot. Comme il survient apres une ecriture serveur et
// deux RPC, il arrivait toujours en dernier -- les soldats disparaissaient a chaque entree de
// piece alors qu'ils etaient correctement poses en base.
//
// Les deux lectures partent ENSEMBLE : le detachement n'ajoute pas un aller-retour en serie.
// Aucun cache n'est introduit -- carteDetachementPiece relit l'etat serveur a chaque appel, si
// bien qu'un detachement recupere ou deplace cesse de lui-meme d'etre affiche.
//
// C'est une architecture DISTINCTE de celle des agents de renseignement : les soldats vivent dans
// le blob de la compagnie et n'ont aucune variable de module, la ou RP_AGENTS_ICI en est une. Rien
// ici ne touche a leur cycle de vie.
async function rafraichirPresenceAgents() {
  if (typeof renderPersonsList !== 'function' || !state.currentBuilding || !state.currentRoom) return;
  const bat = state.currentBuilding, piece = state.currentRoom, ville = state.currentCity;
  const [, detachement] = await Promise.all([
    rafraichirAgentsIci(),
    (typeof carteDetachementPiece === 'function')
      ? carteDetachementPiece(state.country || 'republic', ville, bat, piece).catch(() => null)
      : Promise.resolve(null),
    // Liste des mutins, relue ici pour que le marqueur « MUTIN » soit a jour au meme rendu.
    rafraichirMutins().catch(() => null)
  ]);
  // Le joueur a pu changer de piece pendant l'aller-retour : on ne redessine alors rien.
  if (state.currentBuilding !== bat || state.currentRoom !== piece || state.currentCity !== ville) return;
  const normales = personnesNormalesDeLaPiece(bat, piece);
  renderPersonsList(detachement ? [...normales, detachement] : normales);
}

// =====================
// BONUS COMBAT avec PNJ
// =====================
function calculerBonusCombatGroupe() {
  const employes = getEmployes().filter(e => e.inGroupe);
  const bonus = { for: 0, hp: 0, pop: 0, inf: 0, dis: 0, moral: 0, arg: 0 };
  employes.forEach(emp => {
    const cb = emp.stats?.combatBonus || {};
    Object.keys(cb).forEach(k => { if (bonus[k] !== undefined) bonus[k] += cb[k]; });
  });
  return bonus;
}

// LE VIVIER DE REMPLACANTS GENERIQUES A ETE SUPPRIME LE 1er OCTOBRE 2026.
//
// `PNJ_NOMS_REMPLACEMENT` et `genererPnjRemplacant` fabriquaient un PNJ de
// substitution quand on recrutait quelqu'un du decor : quatre noms par metier et
// par empire, tires au hasard. Ils etaient DEJA MORTS -- leur seule lectrice,
// `confirmerRecrutPnj`, n'avait plus d'appelant depuis le 16 juillet 2026, et
// `ouvrirModalRecrutPnj` non plus.
//
// On les retire plutot que de les laisser dormir : c'est de ce vivier que venaient
// les quatre prenoms d'escorts de Republia qu'on a longtemps pris pour un casting
// -- alors qu'aucun n'a jamais designe quelqu'un.






// =====================
// SYSTEME DE GROUPE + ARMURERIE (complement)
// =====================

// =====================
// SYSTEME DE GROUPE
// =====================
function rejoindrePJ(encodedPnj) {
  let pnj;
  try { pnj = JSON.parse(decodeURIComponent(encodedPnj)); } catch(e) { return; }
  const myName = state.char && state.char.name ? state.char.name : 'Joueur';
  if (!state.group) {
    state.group = { leader: pnj.name, members: [pnj.name, myName] };
  } else {
    if (!state.group.members.includes(myName)) state.group.members.push(myName);
  }
  if (state.employees && state.employees.length > 0) {
    state.employees.forEach(function(e) {
      if (!state.group.members.includes(e.name)) state.group.members.push(e.name);
    });
  }
  closePnjModal();
  showToast('Groupe rejoint !', 'Vous avez rejoint le groupe de ' + pnj.name + '. Il est le leader.', true);
  addJournalEntry('Vous avez rejoint le groupe de ' + pnj.name + '.', 'event-info');
}

function quitterGroupe() {
  const myName = state.char && state.char.name ? state.char.name : 'Joueur';
  if (!state.group) return;
  state.group.members = state.group.members.filter(function(m) { return m !== myName; });
  if (state.group.members.length <= 1) state.group = null;
  closePnjModal();
  showToast('Groupe quitte', 'Vous avez quitte le groupe.', false);
  addJournalEntry('Vous avez quitte le groupe.', '');
}

// Jeremy (quete d'accueil) rejoint le groupe via le meme systeme que les PNJ employes
// (state.employes + inGroupe), qui gere deja l'affichage dans chaque piece et le suivi
// automatique du joueur (voir getGroupeHtmlPourPiece / deplacerGroupeAvecPj). Pas besoin
// de la mecanique state.group (reservee a rejoindre un AUTRE joueur) : ici, le joueur est
// naturellement aux commandes, comme pour n'importe quel PNJ recrute.
// Restreinte aux etapes actives de la quete pour eviter tout detournement hors contexte.
function rejoindreJeremy() {
  if (typeof state === 'undefined' || !state.char) return;
  const etapesJeremyActif = ['jeremy_presentation', 'jeremy_groupe'];
  if (!state.char.queteAccueil || etapesJeremyActif.indexOf(state.char.queteAccueil.etape) === -1) {
    if (typeof showToast === 'function') showToast('Indisponible', "Jérémy n'est plus disponible.", false);
    return;
  }
  if (!state.employes) state.employes = [];
  if (!state.employes.some(function(e) { return e.nom === 'Jérémy'; })) {
    state.employes.push({
      nom: 'Jérémy',
      nomComplet: 'Jérémy (PNJ)',
      role: 'Stagiaire pistonné - Hôtel de Ville',
      job: 'stagiaire',
      photoUrl: (typeof QUETE_ACCUEIL_IMAGES !== 'undefined' && QUETE_ACCUEIL_IMAGES.jeremy) || null,
      photoPos: '50% 20%',
      inGroupe: true,
      cout: 0, // Stagiaire non remunere : jamais licencie par payerEmployes() (sinon comparaison a
               // emp.cout=undefined echoue systematiquement et le vire des le premier "Dormir").
      buildingId: state.currentBuilding,
      roomId: state.currentRoom
    });
  }
  if (typeof updateUI === 'function') updateUI();
  if (typeof renderEmployesPanel === 'function') renderEmployesPanel();
  // Rafraichit aussi la liste "Personnes presentes" de la piece actuelle, pour que Jeremy
  // y apparaisse immediatement a cote du joueur (effet de groupe visible), sans attendre
  // un changement de piece. updateUI() seul ne suffit pas : cette liste a son propre appel.
  const roomActuelleJeremy = (typeof BUILDINGS !== 'undefined') ? BUILDINGS[state.currentBuilding]?.rooms?.[state.currentRoom] : null;
  if (roomActuelleJeremy && typeof renderPersonsList === 'function') {
    renderPersonsList(roomActuelleJeremy.persons || []);
  }
  showToast('Jérémy vous accompagne', 'Il vous suit desormais dans vos deplacements.', true);
}

// Jeremy quitte le groupe a la fin de la quete d'accueil (separation, avec ou sans reprise
// possible plus tard par mail). Symetrique de rejoindreJeremy().
function quitterJeremy() {
  if (typeof state === 'undefined' || !state.employes) return;
  state.employes = state.employes.filter(function(e) { return e.nom !== 'Jérémy'; });
  if (typeof updateUI === 'function') updateUI();
  if (typeof renderEmployesPanel === 'function') renderEmployesPanel();
  const roomActuelleJeremy = (typeof BUILDINGS !== 'undefined') ? BUILDINGS[state.currentBuilding]?.rooms?.[state.currentRoom] : null;
  if (roomActuelleJeremy && typeof renderPersonsList === 'function') {
    renderPersonsList(roomActuelleJeremy.persons || []);
  }
}

function getGroupSize() {
  // Fix 9 aout 2026 : lisait state.employees (jamais rempli nulle part, typo au pluriel)
  // au lieu de state.employes - le bonus de taille de groupe (organiser_blocus, etc.) ne
  // comptait donc quasiment jamais les employes recrutes, seulement le joueur seul.
  // Le correctif du 9 aout n'a traite QUE la branche sans state.group. Des qu'une escort etait
  // recrutee (ou que le joueur rejoignait un autre PJ), state.group existait et la fonction
  // renvoyait la seule longueur de group.members : les employes accompagnants disparaissaient du
  // compte, et le bonus de blocus BAISSAIT en recrutant. Les deux structures decrivent deux choses
  // differentes -- group.members = les PJ/PNJ rejoints, employes inGroupe = les accompagnants --
  // et la taille du groupe est leur union, le joueur compte une seule fois. (26 septembre 2026)
  const noms = new Set();
  if (state.char?.name) noms.add(state.char.name);
  (state.employes || []).forEach(e => { if (e.inGroupe && e.nom) noms.add(e.nom); });
  (state.group?.members || []).forEach(n => { if (n) noms.add(n); });
  return Math.max(1, noms.size);
}

function isGroupLeader() {
  if (!state.group) return true;
  return state.group.leader === (state.char && state.char.name ? state.char.name : 'Joueur');
}

// =====================
// ARMURERIE
// =====================
// Note : l'ancien systeme d'achat d'arme generique et de consultation du registre
// (doAcheterArme, doConsulterRegistre) a ete remplace par le triptyque d'armes par empire
// et le registre Supabase partage, dans plateau-actions-illegales-rumeurs.js.


// =====================
// CHAT EN PIECE (fenetre persistante, messages ephemeres)
// =====================
let _chatInterval = null;
let _chatDernierMessage = null;
let _chatDestinataire = null; // null = salon commun de la piece

// =====================
// MESSAGERIE PERSISTANTE — remplace l'ancien chat lie a une piece physique.
// Une conversation existe independamment du lieu : soit privee (2 personnes, id = noms
// tries), soit un salon nomme (rejoignable/quittable librement, comme convenu avec Fred).
// =====================

let _conversationActuelle = null; // { id, type: 'prive'|'salon', label }
let _chatNotifInterval = null;

function toggleChatPiece() {
  const panel = document.getElementById('chat-piece-panel');
  if (!panel) return;
  const ouvert = panel.style.display !== 'none';
  if (ouvert) {
    panel.style.display = 'none';
    if (_chatInterval) { clearInterval(_chatInterval); _chatInterval = null; }
  } else {
    panel.style.display = 'flex';
    ouvrirListeConversations();
  }
}

// Ouvre directement une conversation privee avec quelqu'un (appele depuis le bouton
// "Parler" de la fenetre PNJ/joueur), sans passer par la liste.
function ouvrirConversationAvec(nom) {
  const panel = document.getElementById('chat-piece-panel');
  if (panel) panel.style.display = 'flex';
  _conversationActuelle = { id: getConversationId(state.char?.name, nom), type: 'prive', label: nom };
  afficherVueConversation();
}

async function ouvrirListeConversations() {
  const moi = state.char?.name;
  document.getElementById('chat-piece-body').innerHTML = '<div style="padding:1rem;color:#8a8060;font-style:italic;font-size:.75rem">Chargement...</div>';

  let conversationsPrivees = [];
  let salons = [];
  try {
    if (typeof sbGet === 'function') {
      const tousMessages = await sbGet('messages_chat', `order=created_at.desc&limit=300`);
      const idsVus = new Set();
      (tousMessages || []).forEach(m => {
        if (!m.salon && m.conversation_id.split('__').includes(moi) && !idsVus.has(m.conversation_id)) {
          idsVus.add(m.conversation_id);
          const autre = m.conversation_id.split('__').find(n => n !== moi);
          conversationsPrivees.push({ id: m.conversation_id, label: autre });
        }
      });
    }
    if (typeof sbGetMesSalons === 'function') {
      salons = await sbGetMesSalons(moi);
    }
  } catch(e) { console.warn('ouvrirListeConversations error', e); }

  let html = '<div style="padding:.5rem .6rem;display:flex;flex-direction:column;gap:.3rem;overflow-y:auto;flex:1">';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.85rem;letter-spacing:.1em;color:#8a6a20;margin-top:.2rem">CONVERSATIONS</div>';
  if (conversationsPrivees.length === 0 && salons.length === 0) {
    html += '<div style="font-size:.72rem;color:#6a5a30;font-style:italic">Aucune conversation pour le moment.</div>';
  }
  conversationsPrivees.forEach(c => {
    html += '<div onclick="ouvrirConversationAvec(\'' + c.label.replace(/'/g,"\\'") + '\')" style="padding:.4rem .6rem;background:#121005;border:1px solid #2a2010;cursor:pointer;font-size:.78rem;color:#e0d8c0">🔒 ' + c.label + '</div>';
  });
  salons.forEach(s => {
    html += '<div onclick="ouvrirSalonChat(\'' + s.id + '\',\'' + s.nom.replace(/'/g,"\\'") + '\')" style="padding:.4rem .6rem;background:#121005;border:1px solid #2a2010;cursor:pointer;font-size:.78rem;color:#e0d8c0">💬 ' + s.nom + '</div>';
  });
  html += '<button onclick="ouvrirCreerSalonPrompt()" style="margin-top:.4rem;font-family:Bebas Neue,sans-serif;font-size:.68rem;letter-spacing:.08em;padding:.35rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">+ Créer un salon</button>';
  html += '</div>';
  document.getElementById('chat-piece-body').innerHTML = html;
}

function ouvrirCreerSalonPrompt() {
  const nom = prompt('Nom du salon à créer :');
  if (!nom || !nom.trim()) return;
  creerEtOuvrirSalon(nom.trim());
}

async function creerEtOuvrirSalon(nom) {
  if (typeof sbCreerSalon !== 'function') return;
  const id = await sbCreerSalon(nom, state.char?.name).catch(() => null);
  if (id) ouvrirSalonChat(id, nom);
}

function ouvrirSalonChat(salonId, nom) {
  _conversationActuelle = { id: salonId, type: 'salon', label: nom };
  afficherVueConversation();
}

function retourListeConversations() {
  if (_chatInterval) { clearInterval(_chatInterval); _chatInterval = null; }
  _conversationActuelle = null;
  ouvrirListeConversations();
}

function afficherVueConversation() {
  if (!_conversationActuelle) return;
  const estSalon = _conversationActuelle.type === 'salon';
  let html = '<div style="display:flex;justify-content:space-between;align-items:center;padding:.4rem .6rem;border-bottom:1px solid #2a2010">';
  html += '<span style="font-size:.72rem;color:#8a8060;cursor:pointer" onclick="retourListeConversations()">← Conversations</span>';
  html += '<span style="font-size:.78rem;color:#C9A84C">' + (estSalon ? '💬 ' : '🔒 ') + _conversationActuelle.label + '</span>';
  html += estSalon ? '<span style="font-size:.85rem;color:#aa5050;cursor:pointer" onclick="quitterSalonActuelChat()">Quitter</span>' : '<span></span>';
  html += '</div>';
  html += '<div id="chat-messages-zone" style="flex:1;overflow-y:auto;padding:.4rem .6rem"></div>';
  html += '<div style="display:flex;gap:.4rem;padding:.5rem .6rem;border-top:1px solid #2a2010">' +
    '<input id="chat-message-input" type="text" placeholder="Votre message..." onkeydown="if(event.key===\'Enter\')envoyerMessageConversation()" style="flex:1;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:1rem;outline:none">' +
    '<button onclick="envoyerMessageConversation()" style="background:transparent;border:1px solid #8a6a20;color:#C9A84C;padding:.4rem .6rem;cursor:pointer;font-size:.78rem">→</button></div>';
  document.getElementById('chat-piece-body').innerHTML = html;

  _chatDernierMessage = null;
  rafraichirConversationActuelle(true);
  _chatInterval = setInterval(() => rafraichirConversationActuelle(false), 4000);
}

async function quitterSalonActuelChat() {
  if (!_conversationActuelle || _conversationActuelle.type !== 'salon') return;
  if (typeof sbQuitterSalon === 'function') {
    await sbQuitterSalon(_conversationActuelle.id, state.char?.name).catch(() => {});
  }
  retourListeConversations();
}

async function rafraichirConversationActuelle(reset) {
  if (!_conversationActuelle || typeof sbGetMessagesConversation !== 'function') return;
  try {
    const messages = await sbGetMessagesConversation(_conversationActuelle.id, reset ? null : _chatDernierMessage);
    const moi = state.char?.name;
    const zone = document.getElementById('chat-messages-zone');
    if (!zone) return;
    if (!messages || messages.length === 0) {
      if (reset && zone.children.length === 0) zone.innerHTML = '<div style="font-size:.72rem;color:#6a5a30;font-style:italic">Aucun message pour le moment.</div>';
      return;
    }
    if (reset) zone.innerHTML = '';
    messages.forEach(m => {
      const estMoi = m.auteur === moi;
      const heureMsg = m.created_at ? new Date(m.created_at).toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' }) : '';
      zone.insertAdjacentHTML('beforeend',
        '<div style="margin-bottom:.4rem;text-align:' + (estMoi ? 'right' : 'left') + '">' +
        '<div style="display:inline-block;max-width:80%;padding:.35rem .6rem;border-radius:8px;background:#0f0d05;border:1px solid #2a2010">' +
        '<div style="font-size:.9rem;color:#a08850">' + m.auteur + ' <span style="font-size:.72rem;color:#6a5a30">' + heureMsg + '</span></div>' +
        '<div style="font-size:1rem;color:#e0d8c0">' + m.message + '</div>' +
        '</div></div>'
      );
    });
    zone.scrollTop = zone.scrollHeight;
    _chatDernierMessage = messages[messages.length - 1].created_at;
    if (typeof sbMarquerConversationLue === 'function') sbMarquerConversationLue(_conversationActuelle.id, moi).catch(() => {});
    verifierNotificationChat();
  } catch(e) { console.warn('rafraichirConversationActuelle error', e); }
}

async function envoyerMessageConversation() {
  const input = document.getElementById('chat-message-input');
  const texte = input?.value?.trim();
  if (!texte || !_conversationActuelle) return;
  input.value = '';
  if (typeof sbEnvoyerMessageChat === 'function') {
    await sbEnvoyerMessageChat(_conversationActuelle.id, state.char?.name || 'Anonyme', texte, _conversationActuelle.type === 'salon').catch(() => {});
  }
  rafraichirConversationActuelle(false);
}

// Point clignotant persistant sur le bouton chat flottant, verifie regulierement
// (survit a une deconnexion : le message reste marque non-lu tant qu'on n'a pas ouvert
// la conversation, meme si l'auteur est reparti ou hors ligne entre temps).
let _dernierEtatNonLuChat = false;
async function verifierNotificationChat() {
  if (typeof sbAMessagesNonLus !== 'function' || !state.char?.name) return;
  try {
    const nonLu = await sbAMessagesNonLus(state.char.name);
    const badge = document.getElementById('chat-notif-badge');
    if (badge) badge.style.display = nonLu ? 'block' : 'none';

    if (nonLu && !_dernierEtatNonLuChat) {
      const panel = document.getElementById('chat-piece-panel');
      if (panel && panel.style.display !== 'flex') {
        panel.style.display = 'flex';
        if (typeof ouvrirListeConversations === 'function') ouvrirListeConversations();
      }
    }
    _dernierEtatNonLuChat = nonLu;
  } catch(e) {}
}

function demarrerPollingNotificationChat() {
  if (_chatNotifInterval) return;
  verifierNotificationChat();
  _chatNotifInterval = setInterval(verifierNotificationChat, 15000);
}

// =====================================================================
// POPUP GENERIQUE « GROUPE PNJ » (26 septembre 2026)
// =====================================================================
// Elle est GENERIQUE : elle affiche le groupe de PNJ que le joueur mene, quelle que soit la
// famille (soldat, employe, agent, policier, douanier, militant). Elle lit le socle par
// pnj_membres_ici, qui resout la presence par position effective -- un PNJ qui suit son chef
// n'a pas de position propre, il est la ou est son chef.
//
// CE QUI EST OUVERT ET CE QUI NE L'EST PAS (mis a jour le 27 septembre 2026).
//   OUVERT  : DONNER / RETIRER de l'argent et des objets. Le socle fait autorite sur ces axes.
//   FERME   : faire quitter le groupe ou transferer UN soldat DESIGNE.
//
// ATTENTION AU CONTRESENS. Depuis la bascule d'autorite, la position, le leader et les PA des
// soldats font autorite au socle, et compagnies_militaires n'en est plus qu'une projection. On
// pourrait donc croire que l'action individuelle est desormais possible. ELLE NE L'EST PAS, et la
// raison a change de nature : ce n'est plus un etat de migration, c'est une REGLE DE JEU. Un soldat
// appartient a une section ; on ne l'extrait pas un par un de son groupe. La table
// pnj_mouvement_individuel porte cette regle (soldat = false), et pnj_prendre, pnj_quitter_groupe
// et pnj_transferer la font respecter cote serveur. La popup renvoie donc vers l'ordre militaire,
// qui opere par NOMBRE (militaire_deposer_soldats / militaire_recuperer_soldats, p_nb integer).
// Ne pas « corriger » ce refus en croyant lever un vestige de migration : il n'en est pas un.

let RP_GROUPE_COURANT = [];

function pnjGroupeLibelleFamille(f) {
  return ({ soldat: 'Soldat', employe: 'Employé', agent: 'Agent',
            policier: 'Policier', douanier: 'Douanier', militant: 'Militant' })[f] || 'PNJ';
}

// Entrainement militaire : donnee METIER, lue a part et jamais remontee dans le socle.
async function pnjGroupeMetierSoldats(pays) {
  const compagnies = await sbGetCompagnies(pays).catch(() => []);
  const parMatricule = {};
  (compagnies || []).forEach(c => {
    (c.sections || []).forEach(s => (s.soldats || []).forEach(sol => {
      if (sol && sol.matricule) parMatricule[sol.matricule] = {
        formation: sol.formation || {}, arme: sol.arme || null,
        // Les accessoires ne sont PLUS lus ici : ils ont ete migres dans pnj_possessions et y
        // sont maintenus par le miroir. pnj_possessions est desormais la source UNIQUE des
        // possessions d'un PNJ, toutes familles confondues.
        section: s.id, lieutenant: s.lieutenantNom || null
      };
    }));
  });
  return parMatricule;
}

function pnjGroupeNiveauEntrainement(formation) {
  const f = formation || {};
  const total = (f.combat_rapproche || 0) + (f.tir || 0)
              + (f.reconnaissance || 0) + (f.secourisme || 0);
  if (total === 0) return 'Aucun entraînement';
  const axes = [];
  if (f.combat_rapproche) axes.push('corps à corps ' + f.combat_rapproche);
  if (f.tir) axes.push('tir ' + f.tir);
  if (f.reconnaissance) axes.push('reconnaissance ' + f.reconnaissance);
  if (f.secourisme) axes.push('secourisme ' + f.secourisme);
  return axes.join(' · ');
}

async function ouvrirGroupePnj() {
  const ech = (t) => (typeof escapeHtmlText === 'function') ? escapeHtmlText(String(t ?? '')) : String(t ?? '');
  const pays = state.country || 'republic';
  const titre = document.getElementById('postes-modal-title');
  const corps = document.getElementById('postes-body');
  if (titre) titre.textContent = 'Groupe PNJ';
  if (corps) corps.innerHTML = '<div style="padding:1rem;color:#8a8060;font-size:.85rem">Lecture du groupe…</div>';
  document.getElementById('modal-postes').classList.add('open');

  const res = await sbPnjMembresIci(pays, state.currentCity, state.currentBuilding, state.currentRoom)
                    .catch(() => null);
  if (res === null || res === undefined) {
    corps.innerHTML = '<div style="padding:1rem;color:#cc4444;font-size:.85rem">'
      + 'Lecture du groupe impossible — l\'appel au serveur n\'a pas abouti. Réessayez.</div>';
    return;
  }
  if (res.refus) {
    corps.innerHTML = '<div style="padding:1rem;color:#cc4444;font-size:.85rem">'
      + 'Refusé par le serveur : ' + ech(MOTIFS_REFUS_GROUPE_PNJ[res.refus] || res.refus) + '</div>';
    return;
  }
  // C'est le SERVEUR qui decide desormais de ce que je vois : il marque `mien` les PNJ que je
  // mene ou que j'administre, et ne livre des autres qu'une presence nue. Le filtre client qui
  // se trouvait ici n'etait pas une securite -- la primitive rendait les 96 soldats a qui la
  // demandait. On ne garde donc que les miens, mais sans plus rien filtrer d'important.
  const miens = (res.membres || []).filter(m => m.mien === true);
  RP_GROUPE_COURANT = miens;

  if (miens.length === 0) {
    corps.innerHTML = '<div style="padding:1rem;font-size:.85rem;color:#8a8060;font-style:italic">'
      + 'Aucun PNJ ne vous accompagne ici.</div>';
    return;
  }

  const metier = miens.some(m => m.famille === 'soldat')
    ? await pnjGroupeMetierSoldats(pays) : {};

  let html = '<div style="padding:1rem">';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.12em;'
       +  'color:#C9A84C;margin-bottom:.2rem">GROUPE PNJ — ' + ech(state.char?.name || '') + '</div>';
  html += '<div style="font-size:.74rem;color:#6a6050;font-style:italic;margin-bottom:.8rem">'
       +  miens.length + ' PNJ vous accompagnent. Leur position est celle du leader : ils vous '
       +  'suivent sans ordre et sans frais.</div>';

  miens.forEach((m, i) => {
    const met = metier[m.nom] || null;
    html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.55rem .7rem;margin-bottom:.45rem">';
    html += '<div style="display:flex;justify-content:space-between;align-items:baseline;gap:.5rem">'
         +  '<span style="font-size:.84rem;color:#e0d5b8">' + ech(pnjGroupeLibelleFamille(m.famille))
         +  ' ' + ech(m.nom) + '</span>'
         +  '<span style="font-size:.7rem;color:#8a8060">' + (m.pa ?? '?') + ' PA</span></div>';
    if (met) {
      html += '<div style="font-size:.72rem;color:#8a9a6a;margin-top:.15rem">'
           +  ech(pnjGroupeNiveauEntrainement(met.formation)) + '</div>';
    }
    html += '<div style="font-size:.72rem;color:#8a8060;margin-top:.15rem">'
         +  'Bourse : ' + ech(m.liquide ?? 0) + ' · '
         +  '<span id="grp-poss-' + i + '">possessions : …</span></div>';
    html += '<div style="display:flex;gap:.35rem;margin-top:.45rem;flex-wrap:wrap">'
         +  '<button onclick="ouvrirGroupePnjDonner(' + i + ')" style="padding:.25rem .55rem;'
         +  'border:1px solid #4a6a3a;background:transparent;color:#8ac05a;cursor:pointer;'
         +  'font-family:Bebas Neue,sans-serif;font-size:.68rem;letter-spacing:.06em">DONNER</button>'
         +  '<button onclick="ouvrirGroupePnjRetirer(' + i + ')" style="padding:.25rem .55rem;'
         +  'border:1px solid #6a5a2a;background:transparent;color:#C9A84C;cursor:pointer;'
         +  'font-family:Bebas Neue,sans-serif;font-size:.68rem;letter-spacing:.06em">RETIRER</button>'
         +  '<button onclick="ouvrirGroupePnjConduite(' + i + ')" style="padding:.25rem .55rem;'
         +  'border:1px solid #3a3a4a;background:transparent;color:#8a8aa0;cursor:pointer;'
         +  'font-family:Bebas Neue,sans-serif;font-size:.68rem;letter-spacing:.06em">CONDUITE</button>';
    // RATION et BIVOUAC sont des ordres MILITAIRES, pas des verbes du socle : ils n'apparaissent
    // donc que pour un soldat. Le client n'envoie que l'identifiant du PNJ -- ni compagnie, ni
    // section, ni leader : le serveur les resout, et c'est lui qui refuse un reserviste ou une
    // unite qui n'est pas la votre.
    if (m.famille === 'soldat') {
      html += '<button onclick="ordonnerGroupePnj(' + i + ',\'ration\')" style="padding:.25rem .55rem;'
           +  'border:1px solid #6a4a2a;background:transparent;color:#c08a4a;cursor:pointer;'
           +  'font-family:Bebas Neue,sans-serif;font-size:.68rem;letter-spacing:.06em">RATION</button>'
           +  '<button onclick="ordonnerGroupePnj(' + i + ',\'bivouac\')" style="padding:.25rem .55rem;'
           +  'border:1px solid #4a5a6a;background:transparent;color:#7aa0c0;cursor:pointer;'
           +  'font-family:Bebas Neue,sans-serif;font-size:.68rem;letter-spacing:.06em">BIVOUAC</button>';
    }
    html += '</div>';
    html += '</div>';
  });
  html += '</div>';
  corps.innerHTML = html;

  // Les possessions sont chargees apres coup : la liste s'affiche sans attendre.
  // UNE SEULE SOURCE (26 septembre 2026) : pnj_possessions. Les accessoires militaires y ont
  // ete migres objet complet, et le miroir les y maintient tant que le blob reste autoritaire.
  // L'addition de deux sources qui existait ici est donc supprimee : deux sources tenues pour
  // equivalentes finissent toujours par divergier.
  // Les objets du jeu nomment leur libelle tantot `nom` (inventaire des joueurs) tantot `name`
  // (equipement militaire) : on accepte les deux a l'affichage, sans rien reecrire en base.
  miens.forEach((m, i) => {
    sbPnjPossessions(m.id).then(liste => {
      const el = document.getElementById('grp-poss-' + i);
      if (!el) return;
      // null = lecture impossible ou autorite refusee (chantier 5) ; [] = ce PNJ ne porte rien.
      if (liste === null) { el.textContent = 'possessions : illisibles pour le moment'; return; }
      const noms = liste.map(o => (o.objet?.nom || o.objet?.name || '?'));
      el.textContent = 'possessions : ' + (noms.length === 0 ? 'aucune' : noms.join(', '));
    }).catch(() => {});
  });
}

// ---- DONNER : du PJ vers le PNJ. Le serveur dit ce que le PJ possede ; le client ne devine
// rien et ne peut donc pas proposer un objet inexistant. L'objet part par son INDEX.
async function ouvrirGroupePnjDonner(i) {
  const ech = (t) => (typeof escapeHtmlText === 'function') ? escapeHtmlText(String(t ?? '')) : String(t ?? '');
  const m = RP_GROUPE_COURANT[i];
  if (!m) return;
  const corps = document.getElementById('postes-body');
  corps.innerHTML = '<div style="padding:1rem;color:#8a8060;font-size:.85rem">Lecture de votre inventaire…</div>';
  const inv = await sbPnjMonInventaire().catch(() => null);
  if (!inv || inv.ok !== true) {
    corps.innerHTML = '<div style="padding:1rem;color:#cc4444;font-size:.85rem">'
      + 'Lecture de votre inventaire impossible — l\'appel n\'a pas abouti.'
      + '</div><div style="padding:0 1rem 1rem"><button onclick="ouvrirGroupePnj()" '
      + 'style="padding:.3rem .7rem;border:1px solid #6a5a2a;background:transparent;color:#C9A84C;'
      + 'cursor:pointer;font-size:.75rem">Retour</button></div>';
    return;
  }
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.85rem;color:#e0d5b8;margin-bottom:.1rem">Donner à '
       +  ech(m.nom) + '</div>';
  html += '<div style="font-size:.74rem;color:#6a6050;margin-bottom:.7rem">Vous avez '
       +  ech(inv.liquide ?? 0) + ' en liquide.</div>';
  html += '<div style="display:flex;gap:.35rem;align-items:center;margin-bottom:.8rem">'
       +  '<input id="grp-don-montant" type="number" min="1" step="1" placeholder="montant" '
       +  'style="width:100px;padding:.3rem;background:#0a0906;border:1px solid #2a2010;color:#e0d5b8">'
       +  '<button onclick="confirmerGroupePnjDonnerArgent(' + i + ')" style="padding:.3rem .7rem;'
       +  'border:1px solid #4a6a3a;background:transparent;color:#8ac05a;cursor:pointer;'
       +  'font-size:.75rem">Donner cet argent</button></div>';
  const objets = inv.inventaire || [];
  if (objets.length === 0) {
    html += '<div style="font-size:.76rem;color:#8a8060;font-style:italic">Vous ne portez aucun objet.</div>';
  } else {
    html += '<div style="font-size:.74rem;color:#8a8060;margin-bottom:.3rem">Vos objets :</div>';
    objets.forEach(o => {
      html += '<div style="display:flex;justify-content:space-between;align-items:center;gap:.5rem;'
           +  'border-top:1px solid #1a1810;padding:.3rem 0">'
           +  '<span style="font-size:.78rem;color:#a09060">' + ech(o.objet?.nom || o.objet?.name || '?')
           +  (o.objet?.quantite ? ' ×' + ech(o.objet.quantite) : '') + '</span>'
           +  '<button onclick="confirmerGroupePnjDonnerObjet(' + i + ',' + o.index + ')" '
           +  'style="padding:.2rem .5rem;border:1px solid #4a6a3a;background:transparent;'
           +  'color:#8ac05a;cursor:pointer;font-size:.7rem">Donner</button></div>';
    });
  }
  html += '<div style="margin-top:.9rem"><button onclick="ouvrirGroupePnj()" '
       +  'style="padding:.3rem .7rem;border:1px solid #6a5a2a;background:transparent;'
       +  'color:#C9A84C;cursor:pointer;font-size:.75rem">Retour au groupe</button></div></div>';
  corps.innerHTML = html;
}

async function confirmerGroupePnjDonnerArgent(i) {
  const m = RP_GROUPE_COURANT[i]; if (!m) return;
  const v = parseInt(document.getElementById('grp-don-montant')?.value, 10);
  if (!Number.isFinite(v) || v <= 0) { showToast('Montant invalide', 'Indiquez un montant positif.', false); return; }
  const r = await sbPnjArgentTransferer(m.id, v, 'donner').catch(() => null);
  signalerResultatGroupePnj(r, 'Argent remis', v + ' remis à ' + m.nom + '.');
  await ouvrirGroupePnj();
}
async function confirmerGroupePnjDonnerObjet(i, index) {
  const m = RP_GROUPE_COURANT[i]; if (!m) return;
  const r = await sbPnjObjetTransferer(m.id, index, 'donner').catch(() => null);
  signalerResultatGroupePnj(r, 'Objet remis', (r?.objet?.nom || 'Objet') + ' remis à ' + m.nom + '.');
  await ouvrirGroupePnj();
}

// ---- RETIRER : du PNJ vers le PJ.
async function ouvrirGroupePnjRetirer(i) {
  const ech = (t) => (typeof escapeHtmlText === 'function') ? escapeHtmlText(String(t ?? '')) : String(t ?? '');
  const m = RP_GROUPE_COURANT[i]; if (!m) return;
  const corps = document.getElementById('postes-body');
  corps.innerHTML = '<div style="padding:1rem;color:#8a8060;font-size:.85rem">Lecture de ses possessions…</div>';
  const p = await sbPnjPossessionsEtBourse(m.id).catch(() => null);
  if (!p || p.ok !== true) {
    corps.innerHTML = '<div style="padding:1rem;color:#cc4444;font-size:.85rem">'
      + 'Lecture impossible — ' + ech(p?.raison || 'l\'appel n\'a pas abouti') + '.'
      + '</div><div style="padding:0 1rem 1rem"><button onclick="ouvrirGroupePnj()" '
      + 'style="padding:.3rem .7rem;border:1px solid #6a5a2a;background:transparent;color:#C9A84C;'
      + 'cursor:pointer;font-size:.75rem">Retour</button></div>';
    return;
  }
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.85rem;color:#e0d5b8;margin-bottom:.1rem">Retirer à ' + ech(m.nom) + '</div>';
  html += '<div style="font-size:.74rem;color:#6a6050;margin-bottom:.7rem">Il porte '
       +  ech(p.liquide ?? 0) + ' en liquide.</div>';
  html += '<div style="display:flex;gap:.35rem;align-items:center;margin-bottom:.8rem">'
       +  '<input id="grp-ret-montant" type="number" min="1" step="1" placeholder="montant" '
       +  'style="width:100px;padding:.3rem;background:#0a0906;border:1px solid #2a2010;color:#e0d5b8">'
       +  '<button onclick="confirmerGroupePnjRetirerArgent(' + i + ')" style="padding:.3rem .7rem;'
       +  'border:1px solid #6a5a2a;background:transparent;color:#C9A84C;cursor:pointer;'
       +  'font-size:.75rem">Retirer cet argent</button></div>';
  const objets = p.possessions || [];
  if (objets.length === 0) {
    html += '<div style="font-size:.76rem;color:#8a8060;font-style:italic">Il ne porte aucun objet.</div>';
  } else {
    // Un objet dont `cessible` est faux est le MIROIR d'une possession que le métier détient
    // encore : le reprendre le dupliquerait, et le serveur le refuse. On n'offre donc pas le
    // bouton, et on dit pourquoi -- plutôt que de laisser le joueur buter sur un refus.
    // Le client ne DÉCIDE rien ici : il reflète ce que le serveur a déjà tranché.
    objets.forEach(o => {
      html += '<div style="display:flex;justify-content:space-between;align-items:center;gap:.5rem;'
           +  'border-top:1px solid #1a1810;padding:.3rem 0">'
           +  '<span style="font-size:.78rem;color:#a09060">' + ech(o.objet?.nom || o.objet?.name || '?')
           +  (o.objet?.quantite ? ' ×' + ech(o.objet.quantite) : '') + '</span>';
      if (o.cessible === false) {
        html += '<span style="font-size:.68rem;color:#6a6050;font-style:italic;text-align:right;'
             +  'max-width:11rem">Équipement militaire : se reprend par l\'ordre de section.</span>';
      } else {
        html += '<button onclick="confirmerGroupePnjRetirerObjet(' + i + ',' + o.index + ')" '
             +  'style="padding:.2rem .5rem;border:1px solid #6a5a2a;background:transparent;'
             +  'color:#C9A84C;cursor:pointer;font-size:.7rem">Retirer</button>';
      }
      html += '</div>';
    });
  }
  html += '<div style="margin-top:.9rem"><button onclick="ouvrirGroupePnj()" '
       +  'style="padding:.3rem .7rem;border:1px solid #6a5a2a;background:transparent;'
       +  'color:#C9A84C;cursor:pointer;font-size:.75rem">Retour au groupe</button></div></div>';
  corps.innerHTML = html;
}

async function confirmerGroupePnjRetirerArgent(i) {
  const m = RP_GROUPE_COURANT[i]; if (!m) return;
  const v = parseInt(document.getElementById('grp-ret-montant')?.value, 10);
  if (!Number.isFinite(v) || v <= 0) { showToast('Montant invalide', 'Indiquez un montant positif.', false); return; }
  const r = await sbPnjArgentTransferer(m.id, v, 'retirer').catch(() => null);
  signalerResultatGroupePnj(r, 'Argent récupéré', v + ' récupéré sur ' + m.nom + '.');
  await ouvrirGroupePnj();
}
// ---- ORDRES MILITAIRES INDIVIDUELS. Le serveur applique EXACTEMENT les mêmes règles que
// l'ordre de section -- c'est le même code, avec un filtre de bénéficiaires -- donc la ration
// propre du soldat passe avant celle du chef, une tente abrite 12 PNJ, le refus est global et
// rien n'est consommé partiellement. Le client ne recalcule aucune de ces règles : il affiche
// ce que le serveur répond.
async function ordonnerGroupePnj(i, action) {
  const m = RP_GROUPE_COURANT[i]; if (!m) return;
  const r = await sbMilitaireOrdrePnj(m.id, action).catch(() => null);
  if (signalerResultatGroupePnj(r, action === 'ration' ? 'Ration distribuée' : 'Bivouac monté',
        action === 'ration'
          ? (m.nom + ' a mangé' + (r?.rations_propres > 0 ? ' sa propre ration' : '') + ' : +1 PA.')
          : (m.nom + ' a bivouaqué : +1 PA.'))) {
    await ouvrirGroupePnj();
  }
}

async function confirmerGroupePnjRetirerObjet(i, index) {
  const m = RP_GROUPE_COURANT[i]; if (!m) return;
  const r = await sbPnjObjetTransferer(m.id, index, 'retirer').catch(() => null);
  signalerResultatGroupePnj(r, 'Objet récupéré', (r?.objet?.nom || 'Objet') + ' récupéré sur ' + m.nom + '.');
  await ouvrirGroupePnj();
}

// Les refus du serveur sont NOMMES, jamais collapses en un message invente -- et un appel qui
// n'aboutit pas se distingue d'un refus metier.
const MOTIFS_REFUS_GROUPE_PNJ = {
  acteur_non_authentifie: 'Votre personnage n\'est pas reconnu par le serveur.',
  autorite_insuffisante: 'Vous n\'avez pas autorité sur ce PNJ.',
  objet_non_cessible: 'Cet équipement appartient au matériel militaire : il se reprend par '
    + 'l\'ordre de section, pas à la main.',
  fonds_insuffisants: 'Fonds insuffisants.',
  montant_invalide: 'Montant invalide.',
  index_invalide: 'Cet objet n\'existe plus.',
  introuvable: 'PNJ introuvable.',
  sens_invalide: 'Sens de transfert invalide.',
  // Ce refus couvre désormais deux situations : le destinataire d'un transfert absent, et le PNJ
  // lui-même absent (consulter, donner, retirer exigent la co-présence physique). Le libellé ne
  // doit donc plus désigner le seul destinataire.
  pas_co_presents: 'Il faut être physiquement au même endroit pour cela.',
  destinataire_introuvable: 'Destinataire introuvable.',
  soldat_axe_blob_autoritaire: 'Action individuelle indisponible pour les soldats : '
    + 'le modèle militaire opère par nombre. Passez par l\'ordre de section.',
  // Refus des ordres militaires individuels (ration / bivouac).
  action_invalide: 'Ordre inconnu.',
  aucun_soldat_concerne: 'Rien à faire : il est déjà au maximum de PA, ou il a déjà été servi '
    + 'aujourd\'hui.',
  rations_insuffisantes: 'Pas assez de rations de combat — ni sur lui, ni sur vous.',
  tentes_insuffisantes: 'Pas assez de tentes. Une tente abrite 13 personnes, le leader compris '
    + '— donc 12 PNJ au maximum.',
  radio_manquante: 'Commander à distance exige une radio de chaque côté.',
  soldat_en_reserve: 'Un réserviste ne dépend d\'aucune section : aucun ordre de section ne peut '
    + 'le viser.',
  pnj_introuvable: 'PNJ introuvable.',
  pas_un_soldat: 'Nourrir et abriter sont des ordres militaires : ce PNJ n\'est pas un soldat.',
  pnj_inactif: 'Ce PNJ n\'est plus en service.',
  compagnie_introuvable: 'Compagnie introuvable.',
  section_introuvable: 'Section introuvable.'
};
function signalerResultatGroupePnj(r, titreOk, messageOk) {
  if (r === null || r === undefined) {
    showToast('Action impossible', 'L\'appel au serveur n\'a pas abouti. Réessayez.', false);
    return false;
  }
  if (r.ok !== true) {
    showToast('Refusé', MOTIFS_REFUS_GROUPE_PNJ[r.raison] || ('Refus du serveur : ' + (r.raison || '?')), false);
    return false;
  }
  showToast(titreOk, messageOk, true);
  return true;
}

// ---- CONDUITE : quitter le groupe / rejoindre un leader.
// Pour un SOLDAT en phase miroir, l'action individuelle n'est pas exprimable : les RPC
// militaires (militaire_deposer_soldats, militaire_recuperer_soldats) prennent un NOMBRE, pas
// un soldat designe. On le dit, et on renvoie vers l'ordre de section. Ce n'est pas une
// limitation du socle -- la primitive generique existe et fonctionne -- c'est le modele
// militaire qui reste l'autorite pendant cette phase.
async function ouvrirGroupePnjConduite(i) {
  const ech = (t) => (typeof escapeHtmlText === 'function') ? escapeHtmlText(String(t ?? '')) : String(t ?? '');
  const m = RP_GROUPE_COURANT[i]; if (!m) return;
  const corps = document.getElementById('postes-body');
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.85rem;color:#e0d5b8;margin-bottom:.7rem">Conduite de '
       +  ech(m.nom) + '</div>';
  if (m.famille === 'soldat') {
    html += '<div style="border:1px solid #2a2010;background:#0b0a06;padding:.6rem .8rem;'
         +  'font-size:.76rem;color:#8a8060;line-height:1.55">'
         +  'Les mouvements de soldats passent encore par les ordres de section, qui opèrent '
         +  '<em>par nombre</em> et non soldat par soldat. Utilisez « Gérer la section » pour '
         +  'laisser sur place ou reprendre des hommes.<br><br>'
         +  'L\'action individuelle — faire quitter le groupe à ce soldat précis, ou le confier '
         +  'à un autre chef présent — arrivera avec la bascule finale du moteur.</div>';
  } else {
    html += '<div style="display:flex;flex-direction:column;gap:.4rem">'
         +  '<button onclick="confirmerGroupePnjQuitter(' + i + ')" style="padding:.35rem .7rem;'
         +  'border:1px solid #6a4a2a;background:transparent;color:#c08a5a;cursor:pointer;'
         +  'text-align:left;font-size:.78rem">Le faire quitter le groupe — il reste ici</button>'
         +  '</div>';
    html += '<div id="grp-leaders" style="margin-top:.7rem;font-size:.74rem;color:#8a8060">'
         +  'Leaders présents : lecture…</div>';
  }
  html += '<div style="margin-top:.9rem"><button onclick="ouvrirGroupePnj()" '
       +  'style="padding:.3rem .7rem;border:1px solid #6a5a2a;background:transparent;'
       +  'color:#C9A84C;cursor:pointer;font-size:.75rem">Retour au groupe</button></div></div>';
  corps.innerHTML = html;

  if (m.famille !== 'soldat') {
    // Le menu de destination ne contient que des leaders REELLEMENT presents dans la piece.
    const autres = await leadersPresentsDansPiece(state.country || 'republic', state.currentCity,
      state.currentBuilding, state.currentRoom).catch(() => []);
    const el = document.getElementById('grp-leaders');
    if (!el) return;
    const cibles = (autres || []).filter(n => n && n !== state.char?.name);
    if (cibles.length === 0) {
      el.textContent = 'Aucun autre leader présent dans cette pièce.';
      return;
    }
    el.innerHTML = 'Confier à un leader présent :<div style="display:flex;gap:.3rem;flex-wrap:wrap;margin-top:.3rem">'
      + cibles.map(n => '<button onclick="confirmerGroupePnjTransferer(' + i + ',\''
          + encodeURIComponent(n) + '\')" style="padding:.25rem .55rem;border:1px solid #3a3a4a;'
          + 'background:transparent;color:#8a8aa0;cursor:pointer;font-size:.72rem">'
          + ech(n) + '</button>').join('') + '</div>';
  }
}

async function confirmerGroupePnjQuitter(i) {
  const m = RP_GROUPE_COURANT[i]; if (!m) return;
  const r = await sbPnjQuitterGroupe([m.id]).catch(() => null);
  signalerResultatGroupePnj(r, 'Détaché', m.nom + ' quitte votre groupe et reste ici.');
  await ouvrirGroupePnj();
}
async function confirmerGroupePnjTransferer(i, destEncode) {
  const m = RP_GROUPE_COURANT[i]; if (!m) return;
  const dest = decodeURIComponent(destEncode || '');
  const r = await sbPnjTransferer([m.id], dest, false).catch(() => null);
  signalerResultatGroupePnj(r, 'Confié', m.nom + ' suit désormais ' + dest + '.');
  await ouvrirGroupePnj();
}
