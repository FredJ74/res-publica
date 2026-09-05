// plateau-logements-montrouge.js
// Logements sociaux de Montrouge (18 aout 2026).
//
// Reutilise l'architecture de location existante (isLocationRoom / locationData /
// state.locationsActives / getLocationPourRoom / sbSaveLocation / payerLocations, toutes
// INCHANGEES par ce fichier) pour les 4 rooms de 'logements-montrouge' (data.js), marquees
// locationData.logementSocial:true. Deux regles specifiques a ces logements, absentes des
// locations commerciales :
//   1. L'attribution n'est JAMAIS en self-service (pas d'ordre 'louer_local' sur ces rooms) --
//      un resident depose une demande, l'adjoint au maire de Montrouge attribue explicitement.
//      Voir attribuerLogementSocial(), volontairement distincte de confirmerLocation() (qui
//      suppose state.char comme locataire automatique).
//   2. Le bail et le lieu de sommeil sont independants : le loyer est du a chaque
//      payerLocations() (INCHANGEE), quel que soit le lieu ou Dormir est passe. Seuls des
//      bonus MORAL/SANTE (getBonusLogementSocialDormir, appele depuis doDormir) dependent du
//      lieu reel de sommeil -- jamais le prelevement du loyer.
//
// Emplacement des 2 ordres administratifs (decision game design, corrige le 18 aout 2026) :
// TOUS DEUX dans la room existante 'bureau_maire_adjoint' du batiment 'mairie', jamais dans
// 'logements-montrouge' (qui reste un batiment purement spatial : hall + 4 appartements, sans
// guichet). Voir data.js, WORLD.republic.ville_b.buildingContext['mairie'].roomOverrides.
// bureau_maire_adjoint.orders -- et l'extension apportee a renderRoomActions()
// (plateau-politique.js) pour que roomOverrides puisse porter des ordres propres a une ville,
// sur une room precise d'un batiment autrement partage entre plusieurs villes.

const LOGEMENTS_SOCIAUX_MONTROUGE_BUILDING = 'logements-montrouge';
const LOGEMENTS_SOCIAUX_MONTROUGE_VILLE = 'ville_b';
const LOGEMENTS_SOCIAUX_MONTROUGE_PAYS = 'republic';

// Derive la liste des rooms "logement social" depuis la definition reelle du batiment
// (jamais une liste figee en dur) : une room ajoutee plus tard (V2) devient automatiquement
// visible ici sans toucher a cette fonction, conformement a l'exigence d'evolutivite.
function getRoomsLogementsSociauxMontrouge() {
  const b = (typeof BUILDINGS !== 'undefined') ? BUILDINGS[LOGEMENTS_SOCIAUX_MONTROUGE_BUILDING] : null;
  if (!b) return [];
  return Object.entries(b.rooms || {})
    .filter(([, room]) => room.locationData?.logementSocial === true)
    .map(([roomId, room]) => ({ roomId, room }));
}

function estResidentOfficielMontrouge() {
  return state.domicile?.country === LOGEMENTS_SOCIAUX_MONTROUGE_PAYS &&
    state.domicile?.city === LOGEMENTS_SOCIAUX_MONTROUGE_VILLE;
}

// =====================
// DEMANDE (resident -> file d'attente persistante)
// =====================

function demanderLogementSocial(pa, cost) {
  if (!estResidentOfficielMontrouge()) {
    showToast('Résidence requise', "Seul un résident officiel de Montrouge (domicile officiel) peut demander un logement social ici.", false);
    return;
  }

  document.getElementById('postes-modal-title').textContent = 'Demande de logement social';
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:1rem">' +
    '<div style="font-size:.8rem;color:#8a8060;margin-bottom:.8rem">Votre demande sera examinée par l\'adjoint au maire de Montrouge. Vous pouvez indiquer une préférence, sans garantie.</div>' +
    '<div style="display:flex;flex-direction:column;gap:.4rem">' +
    '<button onclick="confirmerDemandeLogementSocial(\'petit\',' + pa + ',' + cost + ')" style="padding:.6rem;border:1px solid #2a2010;background:transparent;color:#c0b090;cursor:pointer;font-size:.82rem;text-align:left">Petit appartement</button>' +
    '<button onclick="confirmerDemandeLogementSocial(\'grand\',' + pa + ',' + cost + ')" style="padding:.6rem;border:1px solid #2a2010;background:transparent;color:#c0b090;cursor:pointer;font-size:.82rem;text-align:left">Grand appartement</button>' +
    '<button onclick="confirmerDemandeLogementSocial(\'\',' + pa + ',' + cost + ')" style="padding:.6rem;border:1px solid #2a2010;background:transparent;color:#8a8060;cursor:pointer;font-size:.82rem;text-align:left">Peu importe</button>' +
    '</div></div>';
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerDemandeLogementSocial(typeSouhaite, pa, cost) {
  if (!estResidentOfficielMontrouge()) {
    showToast('Résidence requise', "Seul un résident officiel de Montrouge peut déposer cette demande.", false);
    return;
  }
  const demandeur = state.char?.name;
  if (!demandeur) return;

  if (typeof sbGetDemandeLogementEnAttente === 'function') {
    const existante = await sbGetDemandeLogementEnAttente(LOGEMENTS_SOCIAUX_MONTROUGE_PAYS, LOGEMENTS_SOCIAUX_MONTROUGE_VILLE, demandeur).catch(() => null);
    if (existante) {
      showToast('Demande déjà en attente', 'Vous avez déjà une demande de logement social en cours de traitement.', false);
      document.getElementById('modal-postes')?.classList.remove('open');
      return;
    }
  }

  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { signalerRefusCout(r); return; }

  let deposee = false;
  if (typeof sbDeposerDemandeLogement === 'function') {
    const id = await sbDeposerDemandeLogement(LOGEMENTS_SOCIAUX_MONTROUGE_PAYS, LOGEMENTS_SOCIAUX_MONTROUGE_VILLE, demandeur, typeSouhaite || null).catch(() => null);
    deposee = !!id;
  }

  document.getElementById('modal-postes')?.classList.remove('open');

  if (!deposee) {
    showToast('Demande non enregistrée', "La persistance des demandes n'est pas encore disponible (migration en attente).", false);
    return;
  }

  showToast('Demande déposée', "Votre demande de logement social a été transmise à l'adjoint au maire.", true, true);
  addJournalEntry('Demande de logement social déposée à Montrouge.', 'event-good');

  if (typeof getTitulaireActuel === 'function') {
    const adjoint = await getTitulaireActuel('maire_adjoint', LOGEMENTS_SOCIAUX_MONTROUGE_VILLE, LOGEMENTS_SOCIAUX_MONTROUGE_PAYS).catch(() => null);
    if (adjoint?.estPJ && typeof sbSendMail === 'function') {
      const time = typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : '';
      await sbSendMail('Services municipaux', adjoint.nom, 'Demande de logement social',
        demandeur + ' demande un logement social à Montrouge. Rendez-vous à votre bureau (Hôtel de Ville) pour examiner les demandes.', time).catch(() => {});
    }
  }
}

// =====================
// GESTION DU BAIL (locataire) — reutilise ouvrirModalGererLocal() sans le modifier
// =====================

function gererLogementSocial() {
  const buildingId = state.currentBuilding;
  const roomId = state.currentRoom;
  const location = typeof getLocationPourRoom === 'function' ? getLocationPourRoom(buildingId, roomId) : null;

  if (!location) {
    showToast('Logement non attribué', "Ce logement social n'est pas encore attribué. Déposez une demande au bureau de l'adjoint au maire (Hôtel de Ville).", false);
    return;
  }
  if (location.locataire !== state.char?.name) {
    showToast('Non locataire', "Vous n'êtes pas le locataire de cet appartement.", false);
    return;
  }
  ouvrirModalGererLocal();
}

// =====================
// ATTRIBUTION (adjoint au maire) — fonction dediee, distincte de confirmerLocation()
// =====================

async function traiterDemandesLogementSocial(pa, cost) {
  if (state.poste?.id !== 'maire_adjoint') {
    showToast('Réservé au maire adjoint', '', false);
    return;
  }

  document.getElementById('postes-modal-title').textContent = 'Demandes de logement social';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  // Rafraichissement volontairement frais (jamais le cache eventuellement perime de
  // state.locationsActives) avant de decider quels logements sont reellement libres --
  // meme logique que doTraiterDemandesPermis, qui re-fetch aussi a chaque ouverture.
  if (typeof chargerLocations === 'function') await chargerLocations().catch(() => {});

  const rooms = getRoomsLogementsSociauxMontrouge();
  const occupation = rooms.map(({ roomId, room }) => {
    const loc = typeof getLocationPourRoom === 'function'
      ? getLocationPourRoom(LOGEMENTS_SOCIAUX_MONTROUGE_BUILDING, roomId, LOGEMENTS_SOCIAUX_MONTROUGE_VILLE) : null;
    return { roomId, label: room.locationData?.label || roomId, type: room.locationData?.type || '', libre: !loc, locataire: loc?.locataire || null };
  });

  let demandes = [];
  if (typeof sbGetDemandesLogementEnAttente === 'function') {
    demandes = await sbGetDemandesLogementEnAttente(LOGEMENTS_SOCIAUX_MONTROUGE_PAYS, LOGEMENTS_SOCIAUX_MONTROUGE_VILLE).catch(() => []);
  }

  let html = '<div style="padding:1rem">';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.1em;color:#8a6a20;margin-bottom:.4rem">ÉTAT DU PARC</div>';
  html += '<div style="display:flex;flex-direction:column;gap:.3rem;margin-bottom:1rem">';
  occupation.forEach(o => {
    html += '<div style="font-size:.78rem;color:' + (o.libre ? '#4a8a4a' : '#8a8060') + '">' + o.label + ' — ' + (o.libre ? 'Libre' : ('Occupé par ' + o.locataire)) + '</div>';
  });
  html += '</div>';

  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.1em;color:#8a6a20;margin-bottom:.4rem">DEMANDES EN ATTENTE</div>';
  if (!demandes || demandes.length === 0) {
    html += '<div style="font-size:.8rem;color:#5a5040;font-style:italic">Aucune demande en attente.</div>';
  } else {
    const libres = occupation.filter(o => o.libre);
    demandes.forEach(d => {
      html += '<div style="border:1px solid #2a2010;padding:.6rem;margin-bottom:.6rem">';
      html += '<div style="font-size:.8rem;color:#c0b090">' + d.demandeur + (d.type_souhaite ? ' — préférence : ' + d.type_souhaite : '') + '</div>';
      if (libres.length === 0) {
        html += '<div style="font-size:.72rem;color:#6a5a30;margin-top:.3rem;font-style:italic">Aucun logement libre actuellement.</div>';
      } else {
        html += '<div style="display:flex;flex-wrap:wrap;gap:.3rem;margin-top:.4rem">';
        libres.forEach(o => {
          html += '<button onclick="attribuerLogementSocial(\'' + d.id + '\',\'' + d.demandeur.replace(/'/g, "\\'") + '\',\'' + o.roomId + '\',' + pa + ',' + cost + ')" style="padding:.35rem .6rem;border:1px solid #4a8a4a;background:transparent;color:#6ab858;cursor:pointer;font-size:.72rem">Attribuer ' + o.label + '</button>';
        });
        html += '</div>';
      }
      html += '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

async function attribuerLogementSocial(demandeId, demandeurName, roomId, pa, cost) {
  if (state.poste?.id !== 'maire_adjoint') { showToast('Réservé au maire adjoint', '', false); return; }

  // Re-verification stricte au moment de l'attribution (garde anti-course, deux adjoints
  // pourraient traiter la meme liste presque simultanement).
  const dejaLoue = typeof getLocationPourRoom === 'function'
    ? getLocationPourRoom(LOGEMENTS_SOCIAUX_MONTROUGE_BUILDING, roomId, LOGEMENTS_SOCIAUX_MONTROUGE_VILLE) : null;
  if (dejaLoue) {
    showToast('Déjà attribué', 'Ce logement vient d\'être attribué entre-temps.', false);
    traiterDemandesLogementSocial(pa, cost);
    return;
  }

  const room = BUILDINGS[LOGEMENTS_SOCIAUX_MONTROUGE_BUILDING]?.rooms?.[roomId];
  const loc = room?.locationData;
  if (!loc?.logementSocial) return; // garde-fou : jamais utilisable sur une room non prevue pour ca

  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { signalerRefusCout(r); return; }

  const autorite = state.char?.name || 'Adjoint au maire';
  const entree = {
    buildingId: LOGEMENTS_SOCIAUX_MONTROUGE_BUILDING,
    roomId,
    localLabel: loc.label,
    batimentLabel: BUILDINGS[LOGEMENTS_SOCIAUX_MONTROUGE_BUILDING]?.shortName || LOGEMENTS_SOCIAUX_MONTROUGE_BUILDING,
    prix: loc.prix,
    bonusPOP: 0, bonusINF: 0, bonusDIS: 0,
    orgaId: '',
    locataire: demandeurName,
    country: LOGEMENTS_SOCIAUX_MONTROUGE_PAYS,
    city: LOGEMENTS_SOCIAUX_MONTROUGE_VILLE,
    depuis: state.day || 1,
    visible: true,
    // Champs specifiques logement social : logementSocial pilote payerLocations() (aucune
    // difference de traitement — la fonction ne les lit pas) mais surtout
    // getBonusLogementSocialDormir() (doDormir) et le controle de resiliation automatique
    // (changerDomicile). bonusMoralSommeil/bonusSanteSommeil copies depuis la definition
    // statique de la room pour etre lisibles directement sur l'entree de bail.
    logementSocial: true,
    bonusMoralSommeil: loc.bonusMoralSommeil || 0,
    bonusSanteSommeil: loc.bonusSanteSommeil || 0
  };

  if (!state.locationsActives) state.locationsActives = [];
  state.locationsActives.push(entree);
  if (typeof sbSaveLocation === 'function') await sbSaveLocation(entree).catch(() => {});

  if (typeof sbMarquerDemandeLogementTraitee === 'function') {
    await sbMarquerDemandeLogementTraitee(demandeId, roomId).catch(() => {});
  }
  if (typeof sbEnregistrerAttributionLogement === 'function') {
    await sbEnregistrerAttributionLogement(LOGEMENTS_SOCIAUX_MONTROUGE_PAYS, LOGEMENTS_SOCIAUX_MONTROUGE_VILLE, roomId, demandeurName, autorite).catch(() => {});
  }

  const cur = COUNTRIES[LOGEMENTS_SOCIAUX_MONTROUGE_PAYS]?.cur || 'FR';
  showToast('Logement attribué', loc.label + ' attribué à ' + demandeurName + '.', true, true);
  addJournalEntry('Logement social attribué : ' + loc.label + ' à ' + demandeurName + '.', 'event-good');

  if (typeof sbSendMail === 'function') {
    const time = typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : '';
    await sbSendMail('Services municipaux', demandeurName, 'Logement social attribué',
      'Un logement social vous a été attribué à Montrouge : ' + loc.label + '. Loyer : ' + loc.prix + ' ' + cur + ' par échéance, prélevé quel que soit le lieu où vous dormez. Rendez-vous sur place pour le consulter.', time).catch(() => {});
  }

  traiterDemandesLogementSocial(pa, cost);
}

// =====================
// BONUS DE SOMMEIL — appele depuis doDormir() (plateau-personnage.js), lecture seule
// =====================

// Le bail (loyer) et le lieu de sommeil sont INDEPENDANTS : cette fonction ne joue aucun role
// dans payerLocations() (inchangee), seulement dans le calcul MORAL/SANTE de doDormir(). Un
// bail actif dormi ailleurs ne renvoie aucun bonus ici (mais le loyer reste du normalement,
// via payerLocations()) ; dormir dans le logement d'un tiers ne renvoie rien non plus (le
// locataire doit correspondre a state.char?.name).
function getBonusLogementSocialDormir() {
  if (!state.currentBuilding || !state.currentRoom) return { moral: 0, sante: 0 };
  if (typeof getLocationPourRoom !== 'function') return { moral: 0, sante: 0 };
  const loc = getLocationPourRoom(state.currentBuilding, state.currentRoom);
  if (!loc || !loc.logementSocial) return { moral: 0, sante: 0 };
  if (loc.locataire !== state.char?.name) return { moral: 0, sante: 0 };
  return { moral: loc.bonusMoralSommeil || 0, sante: loc.bonusSanteSommeil || 0 };
}

// =====================
// RESILIATION AUTOMATIQUE AU DEPART DE MONTROUGE — appelee depuis changerDomicile()
// (plateau-politique.js), sur le bail de logement social UNIQUEMENT (jamais les locations
// commerciales, qui ne portent pas logementSocial:true).
// =====================

function resilierLogementSocialSiDepartMontrouge(ancienDomicile, nouveauCountry, nouveauCity) {
  const quittaitMontrouge = ancienDomicile?.country === LOGEMENTS_SOCIAUX_MONTROUGE_PAYS && ancienDomicile?.city === LOGEMENTS_SOCIAUX_MONTROUGE_VILLE;
  const resteAMontrouge = nouveauCountry === LOGEMENTS_SOCIAUX_MONTROUGE_PAYS && nouveauCity === LOGEMENTS_SOCIAUX_MONTROUGE_VILLE;
  if (!quittaitMontrouge || resteAMontrouge) return;

  const idx = (state.locationsActives || []).findIndex(l =>
    l.locataire === state.char?.name && l.buildingId === LOGEMENTS_SOCIAUX_MONTROUGE_BUILDING && l.logementSocial === true);
  if (idx < 0) return;

  const bail = state.locationsActives[idx];
  state.locationsActives.splice(idx, 1);
  if (typeof sbSupprimerLocation === 'function') {
    sbSupprimerLocation(bail.buildingId, bail.roomId, bail.city).catch(() => {});
  }
  addJournalEntry('Départ de Montrouge : bail du logement social résilié automatiquement (' + bail.localLabel + ').', 'event-info');
}
