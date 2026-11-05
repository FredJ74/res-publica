// =====================================================================
// PLATEAU-VEHICULES.JS — VEHICULES PERSONNELS, GARAGE, STATION-SERVICE
// 5 novembre 2026 — decisions de Fred : GAME-DESIGN-VEHICULES.md
// =====================================================================
//
// L'ECRAN DEMANDE ET AFFICHE, LE SERVEUR DECIDE. Achat, plein, chargement, trajet, tirage
// de la panne, depannage, revision : tout passe par la porte unique `vehicule_acte`
// (cle de requete : un double clic ou un renvoi ne paie jamais deux fois) et la lecture
// `vehicules_lire`. Aucun prix, aucune position, aucun stock n'est calcule ici.
//
// Ordres d'ecran (gratuits, ils ouvrent une fenetre) : garage_vehicules, garage_reviser,
// station_carburant, mes_vehicules (aussi depuis la fiche, « Mes véhicules »).
'use strict';

const VEH_MODELES = Object.freeze({
  'voiture':             { label: 'Voiture',    icon: 'ti-car',       places: 4, chargement: 150, reservoir: 18 },
  'deux-roues':          { label: 'Deux-roues', icon: 'ti-motorbike', places: 2, chargement: 50,  reservoir: 12 },
  'vehicule-utilitaire': { label: 'Utilitaire', icon: 'ti-truck',     places: 3, chargement: 500, reservoir: 25 }
});
const VEH_GARAGE_MATIERES = Object.freeze({ metal: 'Métal', textile: 'Textile', derives_petrochimiques: 'Dérivés pétrochimiques' });

const vehEchappe = v => String(v == null ? '' : v).replace(/[&<>"']/g, c =>
  ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const vehNombre = v => Number(v || 0).toLocaleString('fr-FR', { maximumFractionDigits: 0 });
const vehMonnaie = () => (typeof COUNTRIES !== 'undefined' && COUNTRIES[state.country]?.cur) || 'FR';
const vehVille = (pays, ville) => (typeof villeNom === 'function' && villeNom(pays, ville)) || ville;
let VEH_LECTURE = null;
let vehActeEnCours = false;

const VEH_MOTIFS = Object.freeze({
  pas_sur_place: 'Vous devez être sur place.',
  inventaire_plein: 'Votre inventaire est plein.',
  stock_insuffisant: 'Plus de stock disponible.',
  fonds_insuffisants: 'Fonds insuffisants.',
  produit_non_propose: 'Ce produit n’est pas proposé ici.',
  vehicule_hors_de_portee: 'Le véhicule n’est pas dans cette ville, ou vous n’en avez pas la clé.',
  reservoir_plein: 'Le réservoir ne peut pas en contenir autant.',
  bidons_insuffisants: 'Vous n’avez pas assez de bidons de carburant.',
  chargement_plein: 'Le chargement du véhicule est plein.',
  cle_du_vehicule: 'On n’enferme pas la clé dans le véhicule.',
  objet_absent: 'Cet objet n’est plus là.',
  objet_protege: 'Cet objet ne peut pas être déposé.',
  quantite_insuffisante: 'Quantité insuffisante.',
  quantite_invalide: 'Quantité invalide.',
  vehicule_en_panne: 'Le véhicule est en panne : appelez un dépanneur.',
  pas_de_route: 'Aucune route ne relie ces deux villes.',
  arrivee_non_referencee: 'Destination inconnue.',
  revision_requise: 'Le véhicule ne démarre plus : il doit passer en révision au garage.',
  chef_de_groupe_requis: 'Seul le chef du groupe peut conduire le groupe.',
  groupe_incomplet: 'Tout le groupe doit être présent.',
  groupe_disperse: 'Le groupe doit être réuni au même endroit.',
  trop_d_occupants: 'Trop d’occupants pour ce véhicule.',
  membre_pnj_indisponible: 'Un membre du groupe n’est pas disponible.',
  inventaire_surcharge: 'Un occupant porte plus de 100 unités sur lui.',
  pa_insuffisants: 'Chaque occupant doit disposer d’au moins 1 PA.',
  carburant_insuffisant: 'Pas assez de carburant pour ce trajet.',
  garage_non_propose: 'Ce garage n’est pas proposé pour ce dépannage.',
  garage_sans_pieces: 'Le garage n’a plus de pièces (dérivés pétrochimiques) pour une révision.',
  deja_revise: 'Le véhicule vient d’être révisé.',
  pas_en_panne: 'Le véhicule n’est pas en panne.',
  station_introuvable: 'Station-service introuvable.',
  garage_introuvable: 'Garage introuvable.'
});
const vehMotif = v => VEH_MOTIFS[v?.raison] || (v?.transport ? 'Réponse du serveur non reçue : réessayez, le même reçu sera utilisé.' : 'Refusé par le serveur.');

function vehModal(titre, html) {
  const t = document.getElementById('postes-modal-title');
  const b = document.getElementById('postes-body');
  const m = document.getElementById('modal-postes');
  if (!t || !b || !m) return;
  t.textContent = titre;
  b.innerHTML = '<div class="cpj-dialogue" style="padding:1rem">' + html + '</div>';
  m.classList.add('open');
}
const vehSection = (titre, corps) =>
  '<section style="border:1px solid #394656;border-radius:8px;padding:.8rem;margin-bottom:.7rem">' +
  (titre ? '<strong style="color:#e5c477">' + titre + '</strong>' : '') + corps + '</section>';
const vehBouton = (libelle, js, primaire) =>
  '<button class="cpj-touche' + (primaire ? ' cpj-primaire' : '') + '" style="margin:.4rem .4rem 0 0" onclick="' + js + '">' + libelle + '</button>';
const vehChamp = (id, valeur, max) =>
  '<input id="' + id + '" class="cpj-champ" type="number" min="1" ' + (max ? 'max="' + max + '" ' : '') +
  'value="' + valeur + '" style="width:5rem;margin-right:.3rem">';
const vehLireChamp = id => Math.floor(Number(document.getElementById(id)?.value || 0));

async function vehLire() {
  const v = await sbRpcVerdict('vehicules_lire', {}).catch(() => null);
  if (!v || v.ok !== true) { showToast('Véhicules', 'Lecture impossible auprès du serveur.', false); return null; }
  VEH_LECTURE = v;
  return v;
}

// Un acte : cle de requete stable par geste (sessionStorage), oubliee apres une reponse du
// serveur, conservee apres une panne de transport (le renvoi rejoue, il ne repaie pas).
async function vehActe(action, parametres, geste) {
  if (vehActeEnCours) return null;
  vehActeEnCours = true;
  const cle = 'hg-vehicule:' + (state.char?.name || '') + ':' + action + ':' + geste;
  try {
    let requete = sessionStorage.getItem(cle);
    if (!requete) { requete = crypto.randomUUID(); sessionStorage.setItem(cle, requete); }
    const v = await sbRpcVerdict('vehicule_acte', { p_requete: requete, p_action: action, p_parametres: parametres }).catch(() => null);
    if (v && !v.transport) sessionStorage.removeItem(cle);
    if (v && v.ok === true) {
      if (Array.isArray(v.inventory) && typeof sbAdopterInventaireServeur === 'function') sbAdopterInventaireServeur(v);
      if (typeof appliquerPaiementServeur === 'function') appliquerPaiementServeur({ pa: v.pa, liquide: v.liquide, arg: v.arg });
      if (typeof renderInventory === 'function') renderInventory();
      if (typeof updateHeader === 'function') updateHeader();
    }
    return v;
  } finally { vehActeEnCours = false; }
}

// ---------- GARAGE ----------
async function ouvrirGarageVehicules() {
  const l = await vehLire(); if (!l) return;
  const ici = l.ici;
  if (!ici || ici.type !== 'garage') { showToast('Garage', 'Présentez-vous au comptoir d’un garage.', false); return; }
  const cur = vehMonnaie();
  let html = '<p class="cpj-note">Chaque véhicule est vendu avec sa clé. Qui détient une clé peut le conduire ; ' +
    'faites des doubles chez le quincaillier. Un trajet entre deux villes reliées par la route coûte 1 PA à chaque occupant.</p>';
  for (const [id, m] of Object.entries(VEH_MODELES)) {
    const stock = Number(ici.stock?.[id] || 0), prix = ici.prix?.[id];
    html += vehSection('<i class="ti ' + m.icon + '"></i> ' + m.label,
      '<div>' + m.places + ' places · ' + m.chargement + ' unités de chargement · réservoir de ' + m.reservoir + '</div>' +
      '<div class="cpj-note">En stock : ' + vehNombre(stock) + (prix != null ? ' · ' + vehNombre(prix) + ' ' + cur : '') + '</div>' +
      (stock > 0 && prix != null ? vehBouton('Acheter — ' + vehNombre(prix) + ' ' + cur, "vehAcheter('" + id + "')", true) : ''));
  }
  html += vehSection('Vendre des matières au garage',
    '<div class="cpj-note">Le garage rachète les matières de ses véhicules et les pièces de ses révisions.</div>' +
    Object.entries(VEH_GARAGE_MATIERES).map(([k, lab]) =>
      '<div style="margin-top:.4rem">' + lab + ' : ' + vehChamp('veh-mat-' + k, 10) +
      vehBouton('Vendre', "vehVendreMatiere('" + ici.id + "','" + k + "')") + '</div>').join(''));
  vehModal('Garage — véhicules', html);
}

async function vehAcheter(modele) {
  const m = VEH_MODELES[modele]; if (!m) return;
  const v = await vehActe('acheter', { entreprise: VEH_LECTURE?.ici?.id, modele }, modele);
  if (!v || v.ok !== true) { showToast('Achat refusé', vehMotif(v), false); return; }
  showToast('Véhicule acheté', m.label + ' n° ' + v.numero + ' — la clé est dans votre inventaire.', true);
  if (typeof addJournalEntry === 'function') addJournalEntry('Achat : ' + m.label + ' n° ' + v.numero, 'event-info');
  await ouvrirGarageVehicules();
}

async function vehVendreMatiere(entreprise, matiere) {
  const q = vehLireChamp('veh-mat-' + matiere);
  if (q < 1 || typeof commerceApporterMatiere !== 'function') return;
  const r = await commerceApporterMatiere(entreprise, matiere, q, 'vente');
  if (!r || r.ok !== true) { showToast('Vente refusée', VEH_MOTIFS[r?.raison] || 'Refusée par le serveur.', false); return; }
  showToast('Matières vendues', vehNombre(r.qte) + ' × ' + matiere + ' pour ' + vehNombre(r.total) + ' ' + vehMonnaie() + '.', true);
}

async function ouvrirGarageRevision() {
  const l = await vehLire(); if (!l) return;
  if (!l.ici || l.ici.type !== 'garage') { showToast('Garage', 'Présentez-vous au comptoir d’un garage.', false); return; }
  const cur = vehMonnaie();
  const prix = l.ici.proprietaire === 'PNJ' || !l.ici.prix?.revision_vehicule ? 500 : l.ici.prix.revision_vehicule;
  let html = '<p class="cpj-note">Une révision tous les 10 trajets. Au-delà, le risque de panne grimpe ; au 15e trajet, ' +
    'le véhicule ne démarre plus. Révision : ' + vehNombre(prix) + ' ' + cur + '.</p>';
  const ici = l.vehicules.filter(x => x.sur_place);
  if (!ici.length) html += '<p>Aucun de vos véhicules n’est dans cette ville.</p>';
  for (const x of ici) {
    html += vehSection(vehEchappe(x.label) + ' n° ' + vehEchappe(x.numero),
      '<div>' + x.trajets + ' trajet(s) depuis la dernière révision' + (x.statut === 'en_panne' ? ' · <b>en panne</b>' : '') + '</div>' +
      (x.trajets > 0 && x.statut !== 'en_panne' ? vehBouton('Faire réviser — ' + vehNombre(prix) + ' ' + cur, "vehReviser('" + x.id + "')", true) : ''));
  }
  vehModal('Garage — révision', html);
}

async function vehReviser(id) {
  const v = await vehActe('reviser', { vehicule: id, entreprise: VEH_LECTURE?.ici?.id }, id);
  if (!v || v.ok !== true) { showToast('Révision refusée', vehMotif(v), false); return; }
  showToast('Révision faite', 'Le compteur de trajets repart à zéro (' + vehNombre(v.prix) + ' ' + vehMonnaie() + ').', true);
  await ouvrirGarageRevision();
}

// ---------- STATION-SERVICE ----------
async function ouvrirStationCarburant() {
  const l = await vehLire(); if (!l) return;
  const ici = l.ici;
  if (!ici || ici.type !== 'station-service') { showToast('Station-service', 'Présentez-vous à la boutique de la station.', false); return; }
  const cur = vehMonnaie(), prix = ici.prix?.bidon_carburant, stock = Number(ici.stock?.bidon_carburant || 0);
  let html = '<p class="cpj-note">1 bidon = 1 unité de carburant. Vous portez jusqu’à 100 unités sur vous ; ' +
    'versez les bidons dans le réservoir depuis « Mes véhicules ».</p>';
  html += vehSection('Bidons de carburant',
    '<div class="cpj-note">En stock : ' + vehNombre(stock) + (prix != null ? ' · ' + vehNombre(prix) + ' ' + cur + ' le bidon' : '') + '</div>' +
    (stock > 0 && prix != null ? '<div style="margin-top:.4rem">' + vehChamp('veh-bidons', 10, 100) +
      vehBouton('Acheter', 'vehAcheterBidons()', true) + '</div>' : ''));
  html += vehSection('Approvisionner la station',
    '<div class="cpj-note">La station rachète le carburant de la raffinerie ; dix unités font dix bidons.</div>' +
    '<div style="margin-top:.4rem">Carburant : ' + vehChamp('veh-mat-carburant', 10) +
    vehBouton('Vendre', "vehVendreMatiere('" + ici.id + "','carburant')") + '</div>' +
    vehBouton('Conditionner 10 bidons', "vehConditionner('" + ici.id + "')"));
  vehModal('Station-service', html);
}

async function vehAcheterBidons() {
  const q = vehLireChamp('veh-bidons'); if (q < 1) return;
  const v = await vehActe('carburant', { entreprise: VEH_LECTURE?.ici?.id, qte: q }, 'bidons-' + q);
  if (!v || v.ok !== true) { showToast('Achat refusé', vehMotif(v), false); return; }
  showToast('Bidons achetés', vehNombre(v.qte) + ' bidon(s) pour ' + vehNombre(v.total) + ' ' + vehMonnaie() + '.', true);
  await ouvrirStationCarburant();
}

async function vehConditionner(entreprise) {
  if (typeof commerceProduire !== 'function') return;
  const r = await commerceProduire(entreprise, 'bidon_carburant');
  if (!r || r.ok !== true) {
    const m = { matieres_insuffisantes: 'La station n’a pas assez de carburant en réserve.', stock_plein: 'Le stock de bidons est plein.' };
    showToast('Conditionnement refusé', m[r?.raison] || 'Refusé par le serveur.', false); return;
  }
  showToast('Bidons conditionnés', vehNombre(r.portions) + ' bidons mis en rayon.', true);
  await ouvrirStationCarburant();
}

// ---------- MES VEHICULES ----------
async function ouvrirMesVehicules() {
  const l = await vehLire(); if (!l) return;
  const cur = vehMonnaie();
  if (!l.vehicules.length) { vehModal('Mes véhicules', '<p>Vous ne détenez la clé d’aucun véhicule.</p>'); return; }
  const enPanne = l.vehicules.find(x => x.statut === 'en_panne' && x.sur_place);
  if (enPanne) { afficherPanneVehicule(enPanne.id, enPanne.panne); return; }
  const bidons = (state.inventory || []).filter(o => o && o.stackKey === 'carburant').reduce((s, o) => s + Number(o.qty || 1), 0);
  let html = '';
  for (const x of l.vehicules) {
    let corps = '<div>' + x.places + ' places · ' + vehEchappe(vehVille(x.pays, x.ville)) +
      (x.proprietaire === state.char?.name ? '' : ' · propriétaire : ' + vehEchappe(x.proprietaire)) + '</div>' +
      '<div>Carburant : ' + x.carburant + ' / ' + x.reservoir + ' · un trajet en consomme ' + x.consommation + '</div>' +
      '<div>Chargement : ' + vehNombre(x.unites) + ' / ' + x.chargement + ' · ' + x.trajets + ' trajet(s) depuis la révision</div>';
    if (!x.sur_place) { html += vehSection(vehEchappe(x.label) + ' n° ' + vehEchappe(x.numero), corps + '<div class="cpj-note">Ailleurs : rejoignez sa ville pour vous en servir.</div>'); continue; }
    // Plein
    const place = x.reservoir - x.carburant;
    if (place > 0) corps += '<div style="margin-top:.5rem">Verser des bidons (' + bidons + ' sur vous) : ' +
      vehChamp('veh-plein-' + x.id, Math.min(place, bidons) || 1, place) + vehBouton('Faire le plein', "vehPlein('" + x.id + "')") + '</div>';
    // Conduire
    const routes = Array.isArray(x.routes) ? x.routes : [];
    corps += '<div style="margin-top:.5rem">' + (routes.length
      ? routes.map(v => vehBouton('<i class="ti ti-steering-wheel"></i> Conduire vers ' + vehEchappe(vehVille(x.pays, v)) + ' (1 PA)', "vehConduire('" + x.id + "','" + v + "')", true)).join('')
      : '<span class="cpj-note">Aucune route depuis cette ville.</span>') + '</div>';
    // Cargaison
    corps += '<div style="margin-top:.6rem"><b>Cargaison</b>' + (x.cargaison.length ? x.cargaison.map((o, i) =>
      '<div>' + vehEchappe(o.name || o.type || 'objet') + (o.qty ? ' × ' + o.qty : '') + ' ' +
      vehChamp('veh-dech-' + x.id + '-' + i, o.qty || 1, o.qty || 1) + vehBouton('Reprendre', "vehDecharger('" + x.id + "'," + i + ")") + '</div>').join('')
      : ' <span class="cpj-note">vide</span>') + '</div>';
    const inv = (state.inventory || []).map((o, i) => [o, i]).filter(([o]) => o);
    if (inv.length) corps += '<div style="margin-top:.4rem">Charger : <select id="veh-charge-' + x.id + '" class="cpj-champ">' +
      inv.map(([o, i]) => '<option value="' + i + '">' + vehEchappe(o.name || o.type || 'objet') + (o.qty ? ' × ' + o.qty : '') + '</option>').join('') +
      '</select> ' + vehChamp('veh-charge-q-' + x.id, 1) + vehBouton('Charger', "vehCharger('" + x.id + "')") + '</div>';
    html += vehSection(vehEchappe(x.label) + ' n° ' + vehEchappe(x.numero), corps);
  }
  html += '<p class="cpj-note">Révisions et dépannages : au garage. Prix en ' + cur + '.</p>';
  vehModal('Mes véhicules', html);
}

async function vehPlein(id) {
  const q = vehLireChamp('veh-plein-' + id); if (q < 1) return;
  const v = await vehActe('plein', { vehicule: id, qte: q }, id + '-' + q);
  if (!v || v.ok !== true) { showToast('Plein refusé', vehMotif(v), false); return; }
  showToast('Plein fait', 'Réservoir : ' + v.carburant + ' / ' + v.reservoir + '.', true);
  await ouvrirMesVehicules();
}

async function vehCharger(id) {
  const i = Number(document.getElementById('veh-charge-' + id)?.value);
  const o = (state.inventory || [])[i]; if (!o) return;
  const q = Math.max(1, vehLireChamp('veh-charge-q-' + id));
  const v = await vehActe('charger', { vehicule: id, index: i, qte: q,
    signature: { name: o.name || '', type: o.type || '', stackKey: o.stackKey || '' } }, id + '-' + i + '-' + q + '-' + (o.name || ''));
  if (!v || v.ok !== true) { showToast('Chargement refusé', vehMotif(v), false); return; }
  showToast('Chargé', 'L’objet est dans le véhicule.', true);
  await ouvrirMesVehicules();
}

async function vehDecharger(id, pos) {
  const x = VEH_LECTURE?.vehicules?.find(y => y.id === id); const o = x?.cargaison?.[pos]; if (!o) return;
  const q = Math.max(1, vehLireChamp('veh-dech-' + id + '-' + pos));
  const v = await vehActe('decharger', { vehicule: id, position: pos, qte: q, signature: { name: o.name || '' } }, id + '-' + pos + '-' + q);
  if (!v || v.ok !== true) { showToast('Déchargement refusé', vehMotif(v), false); return; }
  showToast('Repris', 'L’objet est dans votre inventaire.', true);
  await ouvrirMesVehicules();
}

async function vehConduire(id, ville) {
  if (typeof avertirZeroPa === 'function' && Number(state.pa) === 1 && state._zeroPaConfirme !== 'conduire_vehicule') {
    avertirZeroPa(() => { state._zeroPaConfirme = 'conduire_vehicule'; vehConduire(id, ville); }, 'Conduire');
    return;
  }
  state._zeroPaConfirme = null;
  const c = typeof contexteNavigationRue === 'function' ? contexteNavigationRue() : null;
  const v = await vehActe('trajet', { vehicule: id, ville }, id + '-' + (state.currentCity || '') + '-' + ville);
  if (!v || v.ok !== true) { showToast('Trajet impossible', vehMotif(v), false); return; }
  if (v.panne) { afficherPanneVehicule(id, { depart: v.depart, destination: v.destination, garages: v.garages }); return; }
  await vehAdopterPosition(c, 'Trajet en véhicule → ' + vehVille(v.pays, v.ville),
    String(v.occupants || 1) + ' occupant(s), ' + v.consommation + ' unités de carburant.');
}

// La position est relue depuis la fiche officielle, jamais fabriquee a partir de la reponse.
async function vehAdopterPosition(c, journal, detail) {
  document.getElementById('modal-postes')?.classList.remove('open');
  const frais = await sbLoadPersonnage(state.char?.name).catch(() => null);
  if (!frais || (c && c.uid && frais.userId !== c.uid)) { showToast('Trajet enregistré', 'La position doit encore être relue.', false); return; }
  if (typeof appliquerPaiementServeur === 'function') appliquerPaiementServeur({ pa: frais.pa, liquide: frais.liquide, arg: frais.arg });
  afficherPositionNavigationConfirmee(frais);
  if (typeof addJournalEntry === 'function') addJournalEntry(journal, 'event-info');
  showToast('Arrivée', detail, true);
}

// ---------- PANNE ----------
function afficherPanneVehicule(id, panne) {
  const cur = vehMonnaie(), p = panne || {};
  const garages = Array.isArray(p.garages) ? p.garages : [];
  const pays = state.country;
  let html = '<div style="text-align:center;font-size:3rem;color:#d98a5a"><i class="ti ti-car-crash"></i></div>' +
    '<p style="text-align:center;font-size:1.15rem;color:#e5c477"><b>Vous êtes en panne !</b></p>' +
    '<p>Vous n’avez d’autre choix que d’appeler un dépanneur.</p>' +
    '<p class="cpj-note">Sur la route de ' + vehEchappe(vehVille(pays, p.depart)) + ' à ' + vehEchappe(vehVille(pays, p.destination)) + '.</p>';
  if (!garages.length) html += '<p>Aucun garage dans le pays ne peut vous dépanner pour l’instant.</p>';
  else {
    html += '<p>' + (garages.length > 1 ? 'Les garages les plus proches sont :' : 'Le garage le plus proche est :') + '</p>';
    html += garages.map(g => vehBouton(vehEchappe(g.nom) + ' — ' + vehEchappe(vehVille(pays, g.ville)) + ' (' + vehNombre(g.prix) + ' ' + cur + ')',
      "vehDepanner('" + id + "','" + g.id + "')", true)).join('');
  }
  html += '<p class="cpj-note" style="margin-top:.8rem">Le dépannage ne remplace pas la révision : il faudra encore la payer avant de repartir. Ça fait réfléchir, non ?</p>';
  vehModal('En panne', html);
}

async function vehDepanner(id, garage) {
  const c = typeof contexteNavigationRue === 'function' ? contexteNavigationRue() : null;
  const v = await vehActe('depanner', { vehicule: id, garage }, id + '-' + garage);
  if (!v || v.ok !== true) { showToast('Dépannage refusé', vehMotif(v), false); return; }
  await vehAdopterPosition(c, 'Dépannage → ' + vehVille(state.country, v.ville),
    'Dépanneuse : ' + vehNombre(v.garage?.prix) + ' ' + vehMonnaie() + '. Pensez à la révision avant de repartir.');
}
