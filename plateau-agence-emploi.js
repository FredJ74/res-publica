// =====================================================================
// PLATEAU-AGENCE-EMPLOI.JS — LE COMPTOIR D'EMBAUCHE D'UNE AGENCE
// 5 octobre 2026
// =====================================================================
//
// CE FICHIER NE CONNAIT AUCUNE AGENCE. Pas de « Grobras » ici, nulle part :
// l'identifiant de l'employeur et le metier sont DECLARES DANS L'ORDRE de
// data.js, et tout le reste -- le nom de la maison, les candidats, les prix,
// les quotas, les caracteristiques -- vient du serveur. C'est la contrainte
// posee par Fred : « Demain, une agence creee par un joueur devra pouvoir
// reutiliser exactement le meme socle de recrutement sans modification
// d'architecture. »
//
// Pour ouvrir un comptoir ailleurs, il suffit donc d'un ordre portant
// `employeur` et `metier`, plus les lignes de catalogue en base. Aucune ligne
// de JavaScript a ecrire.
//
// MODELE : plateau-escorts-agence.js, dont ce fichier est la generalisation.
// Memes principes, et pour les memes raisons :
//   * les identites vivent en base, le navigateur n'en invente aucune ;
//   * le serveur decide seul -- on ne lui transmet qu'un candidat_id ;
//   * un empire sans casting est un etat valide, pas une panne.
//
// UNE DIFFERENCE DE FOND AVEC LES ESCORTES, ET ELLE EST VOULUE : le navigateur
// ne transmet NI PRIX NI PA. employeur_embaucher(candidat_id) lit le tarif au
// referentiel serveur et le revalide contre le miroir des ordres. C'est la
// correction de la confusion « cout d'embauche / cout journalier » : un seul
// nombre circulait pour deux notions, il n'en circule plus aucun.

// Le catalogue d'une agence ne change pas en cours de partie. On le relit une
// fois par employeur, et on l'oublie au changement d'empire -- le casting en
// depend, et un employeur n'existe jamais hors de son pays.
let RP_AGENCES_EMPLOI = {};
let RP_AGENCES_EMPLOI_PAYS = null;

function agenceEmploiOublier() { RP_AGENCES_EMPLOI = {}; RP_AGENCES_EMPLOI_PAYS = null; }

async function agenceEmploiCatalogue(employeurId, forcerRelecture) {
  if (RP_AGENCES_EMPLOI_PAYS !== state.country) agenceEmploiOublier();
  if (!forcerRelecture && RP_AGENCES_EMPLOI[employeurId]) return RP_AGENCES_EMPLOI[employeurId];
  if (typeof sbEmployeurCandidats !== 'function') return null;
  const r = await sbEmployeurCandidats(employeurId).catch(function () { return null; });
  if (!r || r.ok !== true) return null;
  RP_AGENCES_EMPLOI_PAYS = state.country;
  RP_AGENCES_EMPLOI[employeurId] = r;
  return r;
}

// ---------------------------------------------------------------------------
// L'ORDRE DIT QUI RECRUTE, ET POUR QUEL METIER
// ---------------------------------------------------------------------------
// Meme procede que doRecruterInformateurPNJ, qui relit son propre ordre dans la
// piece pour en connaitre le cout : c'est l'ordre qui porte sa declaration, pas
// le routeur. Ici il porte deux champs de plus, `employeur` et `metier`, et
// c'est tout ce qui rattache ce comptoir generique a une maison precise.
function agenceEmploiOrdreCourant(fn) {
  const room = BUILDINGS[state.currentBuilding]?.rooms?.[state.currentRoom];
  const ordre = room?.orders?.find(function (o) { return o.fn === fn; });
  if (!ordre || !ordre.employeur || !ordre.metier) return null;
  return ordre;
}

// ---------------------------------------------------------------------------
// LE COMPTOIR
// ---------------------------------------------------------------------------
async function agenceEmploiOuvrir(fn) {
  const titre  = document.getElementById('postes-modal-title');
  const corps  = document.getElementById('postes-body');
  const modale = document.getElementById('modal-postes');
  if (!titre || !corps || !modale) return;

  const ech = (t) => (typeof escapeHtmlText === 'function')
    ? escapeHtmlText(String(t == null ? '' : t)) : String(t == null ? '' : t);

  const ordre = agenceEmploiOrdreCourant(fn);
  if (!ordre) {
    if (typeof showToast === 'function') {
      showToast('Indisponible', 'Ce comptoir n\'est pas déclaré ici.', false);
    }
    return;
  }

  titre.textContent = 'Recrutement';
  corps.innerHTML = '<div style="padding:1.2rem;color:#8a8060;font-family:Crimson Pro,serif">Un instant…</div>';
  modale.classList.add('open');

  const cat = await agenceEmploiCatalogue(ordre.employeur, true);
  if (!cat) {
    corps.innerHTML = '<div style="padding:1.2rem;color:#8a8060;font-family:Crimson Pro,serif">'
      + 'L\'agence ne répond pas pour le moment.</div>';
    return;
  }

  titre.textContent = cat.employeur || 'Recrutement';
  corps.innerHTML = agenceEmploiRendu(cat, ordre, ech);
}

// Le rendu est separe de l'ouverture pour pouvoir etre rejoue apres une
// embauche, sans refaire tourner la modale ni relire deux fois le catalogue.
function agenceEmploiRendu(cat, ordre, ech) {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const metier = (cat.metiers || []).find(function (m) { return m.metier === ordre.metier; });
  const gens = (cat.candidats || []).filter(function (c) { return c.metier === ordre.metier; });

  // UN METIER SANS CANDIDAT EST UN ETAT VALIDE : l'agence n'a simplement
  // personne a presenter aujourd'hui, et on ne va pas lui inventer quelqu'un.
  if (!metier || gens.length === 0) {
    return '<div style="padding:1.2rem;color:#8a8060;font-family:Crimson Pro,serif;line-height:1.6">'
      + 'L\'agence n\'a personne à vous présenter pour ce poste.</div>';
  }
  if (metier.recrutable !== true) {
    return '<div style="padding:1.2rem;color:#8a8060;font-family:Crimson Pro,serif;line-height:1.6">'
      + 'Ce poste n\'est pas ouvert au recrutement.</div>';
  }

  const av = (typeof PNJ_AVATAR !== 'undefined')
    ? (PNJ_AVATAR[ordre.metier] || PNJ_AVATAR.default) : { icon: 'ti-user', color: '#6a6060' };
  const placesMetier = Math.max(0, (metier.quota || 1) - (metier.employes || 0));
  const placesTotal  = Math.max(0, (cat.plafond_employes || 10) - (cat.employes_actuels || 0));

  let h = '<div style="padding:1rem 1.1rem">';

  // CE QUE COUTE L'EMBAUCHE, ET CE QU'ELLE NE COUTE PAS. Les deux notions sont
  // annoncees SEPAREMENT, parce qu'elles sont desormais separees partout
  // ailleurs. Dire « puis 0 par jour » serait exact mais sonnerait comme un
  // oubli : on dit ce qui est vrai, qu'aucun salaire n'est encore prelevé.
  h += '<div style="font-size:.8rem;color:#c0b090;font-family:Crimson Pro,serif;line-height:1.7;'
    +  'border-left:2px solid #3a2a10;padding-left:.7rem;margin-bottom:.9rem">'
    +  '<div><strong style="color:#C9A84C">' + ech(metier.libelle || ordre.metier) + '</strong></div>'
    +  '<div>Frais d\'embauche : <strong>' + (metier.cout_embauche || 0) + ' ' + ech(cur) + '</strong>'
    +  ' · ' + (metier.pa || 0) + ' PA</div>'
    +  '<div style="color:#9a8a68">'
    +  (metier.cout_jour > 0
         ? 'Puis ' + metier.cout_jour + ' ' + ech(cur) + ' par jour.'
         : 'Aucun salaire journalier à ce stade.')
    +  '</div>'
    +  '<div style="color:#9a8a68">PER ' + ech(metier.caracteristiques?.PER ?? '?')
    +  ' · VOL ' + ech(metier.caracteristiques?.VOL ?? '?') + '</div>'
    +  '</div>';

  h += '<div style="display:flex;flex-direction:column;gap:.45rem">';
  gens.forEach(function (c) {
    const pris = c.deja_employe === true;
    const cliquable = !pris && placesMetier > 0 && placesTotal > 0;
    h += '<div' + (cliquable
          ? ' onclick="agenceEmploiEmbaucher(\'' + c.candidat_id + '\',\'' + ordre.fn + '\')"'
            + ' style="cursor:pointer;'
          : ' style="cursor:default;opacity:' + (pris ? '.55' : '.75') + ';')
      +  'display:flex;align-items:center;gap:.6rem;padding:.5rem .6rem;'
      +  'border:1px solid ' + (pris ? '#6a5a20' : '#2a2010') + ';background:#0d0b05">';

    // AUCUN PORTRAIT N'EST INVENTE. Le catalogue peut en fournir un ; quand il
    // n'y en a pas, c'est l'icone du metier -- choix valide au lot narratif,
    // et de toute facon un visage faux vaut moins qu'un symbole juste.
    h += c.vignette
      ? '<img src="' + c.vignette + '" alt="" loading="lazy" style="width:38px;height:38px;'
        + 'border-radius:50%;object-fit:cover;object-position:' + (c.cadrage || '50% 15%')
        + ';border:1px solid #3a2a10;flex-shrink:0"/>'
      : '<div style="width:38px;height:38px;border-radius:50%;background:#1a1208;display:flex;'
        + 'align-items:center;justify-content:center;border:1px solid #2a1a08;flex-shrink:0">'
        + '<i class="ti ' + av.icon + '" style="font-size:1rem;color:' + av.color + '"></i></div>';

    h += '<div style="flex:1;min-width:0">'
      +  '<div style="font-family:Playfair Display,serif;font-size:.9rem;color:#E8C97A">'
      +  ech(c.nom) + '</div>'
      +  (c.accroche
          ? '<div style="font-size:.72rem;color:#9a8a68;font-family:Crimson Pro,serif;'
            + 'font-style:italic;line-height:1.5">' + ech(c.accroche) + '</div>'
          : '')
      +  '</div>';

    h += '<div style="font-size:.7rem;font-family:Crimson Pro,serif;flex-shrink:0;'
      +  'color:' + (pris ? '#8a8060' : (cliquable ? '#6a8a6a' : '#6a6050')) + '">'
      +  (pris ? 'à votre service' : (cliquable ? 'disponible' : '—'))
      +  '</div>';

    h += '</div>';
  });
  h += '</div>';

  // LES DEUX LIMITES SONT ANNONCEES AVANT LE CLIC, jamais decouvertes par un
  // refus du serveur. Le quota du metier et le plafond commun sont distincts :
  // l'un peut bloquer sans l'autre, et le joueur doit savoir lequel.
  h += '<div style="margin-top:.9rem;font-size:.72rem;color:#6a5030;'
    +  'font-family:Crimson Pro,serif;line-height:1.6">';
  h += placesMetier > 0
    ? '<div>' + placesMetier + ' poste(s) de ce type encore ouvert(s) sur '
      + (metier.quota || 1) + '.</div>'
    : '<div>Vous employez déjà ' + (metier.quota || 1)
      + ' personne(s) à ce poste : c\'est le maximum.</div>';
  h += placesTotal > 0
    ? '<div>' + placesTotal + ' place(s) restante(s) parmi vos '
      + (cat.plafond_employes || 10) + ' employés.</div>'
    : '<div>Vous employez déjà ' + (cat.plafond_employes || 10)
      + ' personnes : il faudra en libérer une.</div>';
  h += '</div>';

  h += '</div>';
  return h;
}

// ---------------------------------------------------------------------------
// EMBAUCHER
// ---------------------------------------------------------------------------
// LE SERVEUR DECIDE, ET LUI SEUL. Le navigateur ne transmet qu'une identite --
// ni metier, ni nom, ni genre, ni PA, ni prix. En cas de refus, rien n'a bouge :
// ni argent, ni PA, ni employe.
async function agenceEmploiEmbaucher(candidatId, fn) {
  if (typeof sbEmployeurEmbaucher !== 'function') {
    showToast('Indisponible', 'L\'agence ne répond pas.', false); return;
  }
  if (!state.char?.name) {
    showToast('Action impossible', 'Votre personnage n\'est pas chargé.', false); return;
  }

  const r = await sbEmployeurEmbaucher(candidatId).catch(function () { return null; });
  if (!r) { showToast('Action impossible', 'L\'agence ne répond pas.', false); return; }
  if (r.ok !== true) {
    const motifs = {
      acteur_non_authentifie: 'Votre personnage n\'est pas identifié.',
      candidat_inconnu:       'L\'agence ne connaît personne de ce nom.',
      employeur_inconnu:      'Cette agence n\'existe pas ici.',
      employeur_hors_pays:    'Cette agence n\'opère pas dans votre empire.',
      metier_non_recrutable:  'Ce poste n\'est pas ouvert au recrutement.',
      plafond_employes:       'Vous employez déjà ' + (r.plafond || 10) + ' personnes.',
      quota_metier_atteint:   'Vous employez déjà ' + (r.quota || 1)
                              + ' personne(s) à ce poste : c\'est le maximum.',
      deja_employe:           (r.nom || 'Cette personne') + ' travaille déjà pour vous.',
      ordre_non_declare:      'Le tarif de ce recrutement n\'est pas déclaré.',
      paiement_refuse:        'Fonds ou PA insuffisants.'
    };
    showToast('Refusé', motifs[r.raison] || 'L\'agence a décliné.', false);
    return;
  }

  const cur = COUNTRIES[state.country]?.cur || 'FR';
  if (typeof appliquerPaiementServeur === 'function') appliquerPaiementServeur(r.paiement);

  // L'ETAT CLIENT N'EST QU'UNE PROJECTION de ce que le serveur vient d'ecrire.
  //
  // `cout` EST LE COUT JOURNALIER, ET RIEN D'AUTRE. C'est payerEmployes() qui
  // le preleve a chaque reveil : y mettre les frais d'embauche ferait payer 500
  // FR par nuit pour un agent dont le salaire est nul. C'etait exactement le
  // defaut signale par Fred, present depuis l'origine dans
  // doRecruterInformateurPNJ et corrige au meme commit. On lit donc cout_jour,
  // comme le font deja les escortes.
  const nomPnj = r.nom;
  if (!state.employes) state.employes = [];
  state.employes.push({
    nom: nomPnj, pnjId: r.pnj_id, candidatId: r.candidat_id,
    job: r.metier, role: r.role_libelle, genre: r.genre,
    photoUrl: r.portrait || null, photoPos: r.cadrage || '50% 15%',
    cout: r.cout_jour,
    inGroupe: true,
    buildingId: state.currentBuilding,
    roomId: state.currentRoom,
    city: state.currentCity,
    depuis: state.day || 1,
    stats: r.caracteristiques || {}
  });

  if (typeof sauvegarderPersonnageImmediat === 'function') sauvegarderPersonnageImmediat();
  if (typeof updateUI === 'function') updateUI();

  // LES DEUX MONTANTS SONT ANNONCES SEPAREMENT. Le joueur doit pouvoir lire
  // dans le message ce qu'il vient de payer et ce qu'il paiera demain -- c'est
  // la seule facon qu'il ne confonde pas les deux, lui non plus.
  const suite = (r.cout_jour > 0)
    ? ' Puis ' + r.cout_jour + ' ' + cur + ' par jour.'
    : ' Aucun salaire journalier à ce stade.';
  showToast(nomPnj + ' entre à votre service',
            '-' + r.cout_embauche + ' ' + cur + ' de frais d\'embauche.' + suite, true, true);
  if (typeof addJournalEntry === 'function') {
    addJournalEntry('Embauche : ' + nomPnj + ' (' + (r.role_libelle || r.metier) + ') rejoint le groupe. -'
      + r.cout_embauche + ' ' + cur + ' de frais d\'embauche.' + suite, 'event-good');
  }

  // AUCUNE ECRITURE DANS room.persons : c'est la strategie de l'informateur, la
  // seule qui n'ait pas produit de carte dupliquee. `inGroupe: true` suffit a
  // le faire apparaitre dans « Dans votre groupe ».
  const room = BUILDINGS[state.currentBuilding]?.rooms?.[state.currentRoom];
  if (room && typeof renderPersonsList === 'function') renderPersonsList(room.persons);

  // Le comptoir reste ouvert et se rafraichit : le candidat embauche passe en
  // « a votre service » et les compteurs de places diminuent. On relit le
  // catalogue au serveur plutot que de deduire l'etat nouveau cote navigateur.
  const ordre = fn ? agenceEmploiOrdreCourant(fn) : null;
  if (ordre) {
    const cat = await agenceEmploiCatalogue(ordre.employeur, true);
    const corps = document.getElementById('postes-body');
    if (cat && corps) {
      const ech = (t) => (typeof escapeHtmlText === 'function')
        ? escapeHtmlText(String(t == null ? '' : t)) : String(t == null ? '' : t);
      corps.innerHTML = agenceEmploiRendu(cat, ordre, ech);
    }
  }
}
