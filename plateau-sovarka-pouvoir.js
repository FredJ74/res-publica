// POUVOIR EN SOVARKA (07/11/2026, décisions de Fred, GAME-DESIGN-NOVOMIRSK.md).
// Soviet Suprême : sièges répartis à la semaine à la gloire des partis, députés désignés par
// les chefs de parti. Le serveur décide tout (sovarka_soviet_etat, sovarka_depute_designer) ;
// l'écran n'affiche que ses réponses.

// Textes d'affichage : catalogue i18n/sovarka-pouvoir-resources.js (français de référence et de repli).
const powT = (k, v) => (typeof texteSovPouvoir === 'function' ? texteSovPouvoir(k, v) : k);
const powModal = (titre, html, rouvrir) => (typeof sovModal === 'function') ? sovModal(titre, html, rouvrir) : vehModal(titre, html);
// Motif d'un refus : clé du catalogue sous un préfixe (sm_, rm_, mu_, pm_) ; la session perdue est commune.
const powMotif = (prefixe, raisons, raison) => raison === 'acteur_non_authentifie' ? powT('session')
  : raisons.includes(raison) ? powT(prefixe + raison) : null;
const SOVIET_RAISONS = ['pas_chef_de_parti', 'pas_sur_place', 'aucun_siege', 'sieges_pourvus', 'hors_parti', 'deja_depute',
  'pas_depute_du_parti', 'personnage_introuvable'];
let sovietDernier = null;
let sovietDesignationEnCours = false;

function sovEchapper(s) {
  if (typeof escapeHtmlText === 'function') return escapeHtmlText(s);
  return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

async function ouvrirSovietSupreme(cache) {
  const v = (cache === true && sovietDernier) || await sbRpcVerdict('sovarka_soviet_etat', {}).catch(() => null);
  if (!v || v.ok !== true) {
    showToast(powT('tSoviet'), powMotif('sm_', SOVIET_RAISONS, v?.raison) || powT('noServer'), false);
    return;
  }
  sovietDernier = v;
  const scores = Array.isArray(v.scores) ? v.scores : [];
  const sieges = v.sieges || {};
  const deputes = v.deputes || {};
  let html = '<p>' + powT('sovietIntro') + '</p>';
  if (!scores.length) {
    html += vehSection(powT('secLegislature'), '<p class="cpj-note">' + powT('noGlory') + '</p>');
  } else {
    let corps = v.vainqueur ? '<p>' + powT('winner', { nom: sovEchapper(v.vainqueur) }) + '</p>' : '';
    scores.forEach(s => {
      const noms = Array.isArray(deputes[s.partiId]) ? deputes[s.partiId] : [];
      corps += '<p style="margin:.35rem 0"><strong>' + sovEchapper(s.nom) + '</strong>' +
        powT('seatsLine', { sieges: sieges[s.partiId] || 0, adherents: s.adherentsPJ || 0, partisans: s.partisansPNJ || 0 }) +
        (noms.length ? '<br><span class="cpj-note">' + powT('deputies', { noms: noms.map(sovEchapper).join(', ') }) + '</span>' : '') + '</p>';
    });
    html += vehSection(powT('secCurrent'), corps);
  }
  if (v.chef && v.monParti) {
    const miens = Array.isArray(deputes[v.monParti]) ? deputes[v.monParti] : [];
    const nb = sieges[v.monParti] || 0;
    let corps = '<p>' + powT('filled', { n: miens.length, total: nb }) + '</p>';
    (Array.isArray(v.membres) ? v.membres : []).forEach(nom => {
      const siege = miens.indexOf(nom) >= 0;
      const js = 'designerDeputeSoviet(' + JSON.stringify(nom).replace(/"/g, '&quot;') + ',' + siege + ')';
      corps += '<div style="margin:.3rem 0">' + sovEchapper(nom) + (siege ? ' — <em>' + powT('deputy') + '</em>' : '') +
        vehBouton(siege ? powT('removeSeat') : powT('makeDeputy'), js, !siege) + '</div>';
    });
    html += vehSection(powT('secDesignate'), corps);
  }
  powModal(powT('tSoviet'), html, ouvrirSovietSupreme);
}

async function designerDeputeSoviet(nom, retirer) {
  if (sovietDesignationEnCours) return;
  sovietDesignationEnCours = true;
  try {
    const v = await sbRpcVerdict('sovarka_depute_designer', { p_nom: nom, p_retirer: !!retirer }).catch(() => null);
    if (!v || v.ok !== true) {
      showToast(powT('tSoviet'), powMotif('sm_', SOVIET_RAISONS, v?.raison) || powT('notConfirmed'), false);
      return;
    }
    showToast(powT('tSoviet'), retirer ? powT('noLongerSits', { nom }) : powT('nowSits', { nom }), true);
    await ouvrirSovietSupreme();
  } finally { sovietDesignationEnCours = false; }
}

// REPAS PRESIDENTIEL (Fred, 07/11 puis 08/11/2026) : un repas par jour dans la salle de restaurant
// du Palais présidentiel ; gratuit pour le président, chaque invité présent coûte 60 PSK à la
// caisse présidentielle ; effets du dîner d'affaires pour chacun. Le serveur
// (sovarka_repas_presidentiel) vérifie le président, le lieu, les invités, la caisse et le jour.
const REPAS_PRES_RAISONS = ['reserve_president', 'pas_sur_place', 'deja_pris_aujourdhui', 'invite_absent', 'invite_invalide'];
let repasPresidentielEnCours = false;

let repasPresidentielPresents = null;
async function ouvrirRepasPresidentiel(cache) {
  const presents = (cache === true && repasPresidentielPresents) || ((typeof sbGetPresencesInRoom === 'function')
    ? await sbGetPresencesInRoom(state.country, state.currentCity, state.currentBuilding, state.currentRoom).catch(() => [])
    : []);
  repasPresidentielPresents = presents;
  const coches = cache === true ? Array.from(document.querySelectorAll('.repas-pres-invite:checked')).map(c => c.value) : [];
  const moi = state.char?.name || '';
  const noms = Array.from(new Set((presents || []).map(p => p.name || p.nom).filter(n => n && n !== moi)));
  let corps = '<p>' + powT('mealIntro') + '</p>' +
    (noms.length
      ? noms.map(n => '<label class="cpj-note" style="display:block"><input type="checkbox" class="repas-pres-invite" value="' +
          sovEchapper(n) + '"> ' + sovEchapper(n) + '</label>').join('')
      : '<p class="cpj-note">' + powT('alone') + '</p>') +
    '<br>' + vehBouton(powT('serveMeal'), 'servirRepasPresidentiel()', true);
  powModal(powT('titleRestaurant'), vehSection(powT('secMeal'), corps), ouvrirRepasPresidentiel);
  document.querySelectorAll('.repas-pres-invite').forEach(c => { if (coches.includes(c.value)) c.checked = true; });
}

async function servirRepasPresidentiel() {
  if (repasPresidentielEnCours) return;
  repasPresidentielEnCours = true;
  const invites = Array.from(document.querySelectorAll('.repas-pres-invite:checked')).map(c => c.value);
  const cle = 'hg-repas-pres:' + (state.char?.name || '') + ':' + new Date().toISOString().slice(0, 10);
  try {
    let requete = sessionStorage.getItem(cle);
    if (!requete) { requete = crypto.randomUUID(); sessionStorage.setItem(cle, requete); }
    const v = await sbRpcVerdict('sovarka_repas_presidentiel', { p_requete: requete, p_invites: invites }).catch(() => null);
    if (v && !v.transport && v.ok !== true) sessionStorage.removeItem(cle);
    if (!v || v.ok !== true) {
      const motif = v?.raison === 'caisse_insuffisante'
        ? powT('cashLow', { solde: v.solde, n: v.invites_possibles })
        : powMotif('rm_', REPAS_PRES_RAISONS, v?.raison);
      showToast(powT('tMeal'), motif || powT('mealNotConfirmed'), false);
      return;
    }
    if (typeof v.hp === 'number') state.hp = v.hp;
    if (typeof v.moral === 'number') state.moral = v.moral;
    if (v.inf != null && typeof adopterJaugeServeur === 'function') adopterJaugeServeur('inf', v.inf);
    if (typeof updateHeader === 'function') updateHeader();
    if (typeof updateUI === 'function') updateUI();
    document.getElementById('modal-postes')?.classList.remove('open');
    const liste = Array.isArray(v.invites) ? v.invites : [];
    showToast(powT('tMeal'), liste.length
      ? powT('servedFor', { noms: liste.join(', '), cout: v.cout }) : powT('served'), true);
  } finally { repasPresidentielEnCours = false; }
}

// BILLET DU MUSEE PRESIDENTIEL (Fred, 08/11/2026) : 8 PSK au hall, versés à la caisse présidentielle ;
// le billet ouvre le musée toute la journée (garde serveur à l'entrée de la pièce).
let billetMuseePresEnCours = false;
async function acheterBilletMuseePresidentiel() {
  if (billetMuseePresEnCours) return;
  billetMuseePresEnCours = true;
  try {
    const v = await sbRpcVerdict('sovarka_musee_billet', {}).catch(() => null);
    if (!v || v.ok !== true) {
      showToast(powT('tMuseum'), powMotif('mu_', ['pas_sur_place', 'fonds_insuffisants'], v?.raison) || powT('ticketNotConfirmed'), false);
      return;
    }
    if (typeof appliquerPaiementServeur === 'function' && (v.pa != null || v.liquide != null))
      appliquerPaiementServeur({ pa: v.pa, liquide: v.liquide, arg: v.arg });
    if (typeof updateUI === 'function') updateUI();
    showToast(powT('tMuseum'), v.deja ? powT('ticketAlready') : powT('ticketOk'), true);
  } finally { billetMuseePresEnCours = false; }
}

// ============================================================================================
// MINISTÈRES DE SOVARKA (décisions de Fred du 08/11/2026, GAME-DESIGN-NOVOMIRSK.md) : lois des
// partis tranchées par le Président du Conseil, séance du jeudi, manifestations de soutien,
// fiscalité 10/10/10, saisine du juge, sondages, fuite, conscription, autocritique publique.
// Tout est décidé par sovarka_pouvoir_commande / sovarka_pouvoir_lire ; l'écran recopie.
// ============================================================================================
const SOV_POUVOIR_RAISONS = ['reserve_a_sovarka', 'reserve_chef_de_parti', 'salle_des_partis_requise', 'type_invalide', 'champs_requis',
  'texte_trop_long', 'titre_trop_long', 'loi_cible_introuvable', 'categorie_invalide', 'reserve_president_du_conseil',
  'bureau_du_president_du_conseil_requis', 'projet_introuvable', 'reserve_depute', 'seance_le_jeudi', 'salle_du_conseil_requise',
  'emargement_requis', 'choix_invalide', 'hors_ordre_du_jour', 'deja_vote', 'aucun_parti_au_pouvoir', 'a_la_mairie', 'pas_chef',
  'deja_aujourdhui', 'groupe_insuffisant', 'poste_requis', 'pas_sur_place', 'sujet_invalide', 'sondage_introuvable', 'deja_decide',
  'valeurs_requises', 'publication_refusee', 'reserve_ministre_justice', 'motif_invalide', 'local_non_exploite', 'saisine_deja_en_cours',
  'saisine_introuvable', 'saisine_requise', 'reserve_juge', 'pas_au_tribunal', 'reserve_ministre_defense', 'deja_active', 'pas_active',
  'pas_convoque', 'pas_a_la_caserne', 'pas_ministre', 'deja_cette_semaine', 'pa_insuffisants', 'fonds_insuffisants',
  'portee_reservee_sovarka', 'pas_de_taxe_locale_en_sovarka', 'cible_invalide', 'deja_surveille', 'limite_surveillances',
  'caisse_insuffisante'];
const sovPMotif = v => powMotif('pm_', SOV_POUVOIR_RAISONS, v?.raison) || powT(v ? 'refused' : 'noReply');
let sovPouvoirDernier = null;
const sovJsArg = s => JSON.stringify(String(s == null ? '' : s)).replace(/"/g, '&quot;');
let sovPouvoirEnCours = false;

async function sovPouvoirLire(cache) {
  if (cache === true && sovPouvoirDernier) return sovPouvoirDernier;
  const v = await sbRpcVerdict('sovarka_pouvoir_lire', {}).catch(() => null);
  if (!v || v.ok !== true) { showToast('Sovarka', sovPMotif(v), false); return null; }
  sovPouvoirDernier = v;
  return v;
}

async function sovPouvoirActe(action, params, titre, succes, rouvrir) {
  if (sovPouvoirEnCours) return null;
  sovPouvoirEnCours = true;
  try {
    const v = await sbRpcVerdict('sovarka_pouvoir_commande',
      { p_requete: crypto.randomUUID(), p_action: action, p_params: params || {} }).catch(() => null);
    if (!v || v.ok !== true) { showToast(titre, sovPMotif(v), false); return null; }
    if (typeof appliquerPaiementServeur === 'function' && (v.pa !== undefined || v.liquide !== undefined))
      appliquerPaiementServeur({ pa: v.pa, liquide: v.liquide, arg: v.arg });
    if (typeof adopterJaugeServeur === 'function' && typeof v.pop === 'number') adopterJaugeServeur('pop', v.pop);
    if (Array.isArray(v.recherche) && typeof state !== 'undefined') state.recherche = v.recherche;
    if (typeof updateHeader === 'function') updateHeader();
    if (succes) showToast(titre, typeof succes === 'function' ? succes(v) : succes, true);
    if (typeof rouvrir === 'function') rouvrir(v);
    return v;
  } finally { sovPouvoirEnCours = false; }
}

// ---------------------------------------------------------------- Lois : dépôt (chef de parti)
async function ouvrirSovarkaDeposerLoi(cache) {
  const l = await sovPouvoirLire(cache); if (!l) return;
  if (!l.chef_parti) { powModal(powT('titleDeposit'), '<p>' + powT('pm_reserve_chef_de_parti') + '</p>', ouvrirSovarkaDeposerLoi); return; }
  const cats = (typeof rafraichirAssembleeCategories === 'function') ? (await rafraichirAssembleeCategories()) || {} : {};
  const enVigueur = (l.lois || []).filter(x => x.statut === 'adoptee');
  let html = '<p class="cpj-note">' + powT('depositIntro') + '</p>'
    + '<select id="sov-loi-type" class="cpj-champ" style="width:100%;margin:.3rem 0">'
    + '<option value="rp">' + powT('lawRp') + '</option>'
    + (Object.keys(cats).length ? '<option value="mecanique">' + powT('lawBan') + '</option>' : '')
    + (enVigueur.length ? '<option value="abrogation">' + powT('lawRepeal') + '</option>' : '') + '</select>'
    + '<input id="sov-loi-titre" class="cpj-champ" maxlength="120" placeholder="' + sovEchapper(powT('titlePh')) + '" style="width:100%;margin:.3rem 0">'
    + (Object.keys(cats).length ? '<select id="sov-loi-cat" class="cpj-champ" style="width:100%;margin:.3rem 0">'
       + Object.keys(cats).map(k => '<option value="' + sovEchapper(k) + '">' + powT('banOpt', { label: sovEchapper(cats[k].label) }) + '</option>').join('') + '</select>' : '')
    + (enVigueur.length ? '<select id="sov-loi-cible" class="cpj-champ" style="width:100%;margin:.3rem 0">'
       + enVigueur.map(x => '<option value="' + sovEchapper(x.id) + '">' + powT('repealOpt', { titre: sovEchapper(x.titre) }) + '</option>').join('') + '</select>' : '')
    + '<textarea id="sov-loi-texte" class="cpj-champ" rows="6" maxlength="20000" placeholder="' + sovEchapper(powT('textPh')) + '" style="width:100%;margin:.3rem 0"></textarea>'
    + vehBouton(powT('deposit'), 'sovarkaDeposerLoi()', true);
  powModal(powT('titleDeposit'), html, ouvrirSovarkaDeposerLoi);
}
function sovarkaDeposerLoi() {
  const type = document.getElementById('sov-loi-type')?.value || 'rp';
  const params = { type, titre: (document.getElementById('sov-loi-titre')?.value || '').trim(),
                   texte: (document.getElementById('sov-loi-texte')?.value || '').trim() };
  if (type === 'mecanique') params.categorie = document.getElementById('sov-loi-cat')?.value || '';
  if (type === 'abrogation') params.loi_cible = document.getElementById('sov-loi-cible')?.value || '';
  sovPouvoirActe('loi_deposer', params, powT('tBill'), v => powT('billWaits', { titre: v.titre }),
    () => document.getElementById('modal-postes')?.classList.remove('open'));
}

// ---------------------------------------------------------------- Lois : le Président du Conseil tranche
async function ouvrirSovarkaLoisExamen(cache) {
  const l = await sovPouvoirLire(cache); if (!l) return;
  if (!l.pm) { powModal(powT('titleBills'), '<p>' + powT('pm_reserve_president_du_conseil') + '</p>', ouvrirSovarkaLoisExamen); return; }
  const examen = (l.lois || []).filter(x => x.statut === 'examen');
  const html = '<p class="cpj-note">' + powT('examIntro') + '</p>'
    + (examen.length ? examen.map(x => vehSection(sovEchapper(x.titre),
        '<p class="cpj-note">' + powT('partyLine', { parti: sovEchapper(x.parti_nom || '—'), auteur: sovEchapper(x.auteur) }) + '</p>'
        + '<p style="white-space:pre-wrap">' + sovEchapper(x.texte) + '</p>'
        + vehBouton(powT('promulgate'), 'sovarkaTrancherLoi(' + sovJsArg(x.id) + ',true)', true)
        + vehBouton(powT('refuse'), 'sovarkaTrancherLoi(' + sovJsArg(x.id) + ',false)', false))).join('')
      : '<p>' + powT('noBill') + '</p>');
  powModal(powT('titleBillsDecide'), html, ouvrirSovarkaLoisExamen);
}
function sovarkaTrancherLoi(id, accepter) {
  sovPouvoirActe('loi_trancher', { loi: id, accepter }, accepter ? powT('tPromulgated') : powT('tRefusedBill'),
    v => accepter ? powT('appliesNow', { titre: v.titre }) : powT('isRefused', { titre: v.titre }), ouvrirSovarkaLoisExamen);
}

// ---------------------------------------------------------------- Séance du jeudi (députés)
async function ouvrirSovarkaSeance(cache) {
  const l = await sovPouvoirLire(cache); if (!l) return;
  let html = '<p class="cpj-note">' + powT('sessionIntro') + '</p>';
  if (l.indemnite_suspendue_jusqu_au) html += '<p class="cpj-note">' + powT('suspended', { date: sovEchapper(l.indemnite_suspendue_jusqu_au) }) + '</p>';
  const odj = l.ordre_du_jour || [];
  if (l.depute && l.jeudi && !l.emarge) html += vehBouton(powT('signIn'), 'sovarkaEmarger()', true);
  html += vehSection(l.jeudi ? powT('agenda') : powT('agendaOf', { date: sovEchapper(l.jeudi_seance) }),
    odj.length ? odj.map(o => '<div style="margin:.4rem 0"><strong>' + sovEchapper(o.titre) + '</strong>'
      + ' <span class="cpj-note">' + powT('votes', { parti: sovEchapper(o.parti_nom || '—'), a: o.approbations, b: o.abstentions }) + '</span>'
      + (o.mon_choix ? ' — <em>' + (o.mon_choix === 'APPROUVE' ? powT('approvedChoice') : powT('abstentionChoice')) + '</em>'
        : (l.depute && l.jeudi && l.emarge ? '<br>' + vehBouton(powT('approve'), 'sovarkaApprouver(' + sovJsArg(o.id) + ",'APPROUVE')", true)
          + vehBouton(powT('abstain'), 'sovarkaApprouver(' + sovJsArg(o.id) + ",'ABSTENTION')", false) : ''))
      + '</div>').join('') : '<p>' + powT('noLaw') + '</p>');
  const vigueur = (l.lois || []).filter(x => x.statut === 'adoptee');
  html += vehSection(powT('inForce'), vigueur.length ? vigueur.map(x => '<div>• ' + sovEchapper(x.titre) + '</div>').join('') : '<p>' + powT('none') + '</p>');
  powModal(powT('titleSitting'), html, ouvrirSovarkaSeance);
}
function sovarkaEmarger() {
  return sovPouvoirActe('seance_emarger', {}, powT('tSitting'), powT('presence'), ouvrirSovarkaSeance);
}
function sovarkaApprouver(id, choix) {
  sovPouvoirActe('loi_approuver', { loi: id, choix }, powT('tSitting'),
    v => v.choix === 'APPROUVE' ? powT('approvalOk') : powT('abstentionOk'), ouvrirSovarkaSeance);
}

// ---------------------------------------------------------------- Manifestation de soutien (chef de parti)
function sovarkaManifSoutien() {
  sovPouvoirActe('manif_soutien', {}, powT('tRally'),
    v => powT('rallyOk', { n: v.participants }),
    () => document.getElementById('modal-postes')?.classList.remove('open'));
}

// ---------------------------------------------------------------- Économie collective : trois taux
async function ouvrirFiscaliteSovarka(pa, cost) {
  const l = await sovPouvoirLire(); if (!l) return;
  if (!(l.postes || []).includes('min_fin')) { vehModal(powT('tTax'), '<p>' + powT('taxReserved') + '</p>'); return; }
  const b = (typeof chargerBudgetNational === 'function') ? (await chargerBudgetNational('soviet')) || {} : {};
  const curseur = (id, libelle, taux, portee) => vehSection(libelle,
    '<input id="' + id + '" type="range" min="0" max="40" value="' + taux + '" oninput="document.getElementById(\'' + id + '-v\').textContent=this.value+\' %\'" style="width:100%">'
    + '<div id="' + id + '-v" style="text-align:center">' + taux + ' %</div>'
    + vehBouton(powT('apply'), "sovarkaFixerTaux('" + portee + "','" + id + "'," + (pa || 0) + ',' + (cost || 0) + ')', true));
  vehModal(powT('titleTax'),
    '<p class="cpj-note">' + powT('taxIntro') + '</p>'
    + curseur('sov-taux-ventes', powT('taxSales'), b.tauxNational ?? 10, 'national')
    + curseur('sov-taux-mo', powT('taxLabour'), b.tauxMainOeuvre ?? 10, 'main_oeuvre')
    + curseur('sov-taux-muni', powT('taxMunicipal'), b.tauxMunicipal ?? 10, 'municipal'));
}
async function sovarkaFixerTaux(portee, id, pa, cost) {
  if (typeof fixerTauxImposition !== 'function') return;
  const r = await fixerTauxImposition(portee, id, pa, cost);
  if (r) showToast(powT('tRateSet'), powT('newRate', { taux: r.taux }), true);
}

// ---------------------------------------------------------------- Justice prolétarienne : saisir le juge
async function ouvrirSovarkaSaisirJuge(cache) {
  const l = await sovPouvoirLire(cache); if (!l) return;
  if (!(l.postes || []).includes('min_just')) { powModal(powT('titleRefer'), '<p>' + powT('pm_reserve_ministre_justice') + '</p>', ouvrirSovarkaSaisirJuge); return; }
  const d = (typeof sovLire === 'function') ? await sovLire(cache) : null;
  const exploites = (d?.locaux || []).filter(x => x.exploitant);
  const enCours = new Set((l.saisines || []).filter(s => s.statut === 'en_attente').map(s => s.ville + '|' + s.batiment + '|' + s.piece));
  let html = '<p class="cpj-note">' + powT('referIntro') + '</p>'
    + '<input class="cpj-champ" id="sov-saisine-motif" maxlength="300" placeholder="' + sovEchapper(powT('reasonPh')) + '" style="width:100%">';
  html += exploites.length ? exploites.map(x => vehSection(sovEchapper(x.label) + ' (' + sovEchapper(sovVille(x.ville)) + ')',
    '<p>' + powT('operator', { nom: sovEchapper(x.exploitant) }) + '</p>' + (enCours.has(x.ville + '|' + x.batiment + '|' + x.piece)
      ? '<p class="cpj-note">' + powT('alreadyReferred') + '</p>'
      : vehBouton(powT('referBtn'), 'sovarkaSaisirJuge(' + sovJsArg(x.ville) + ',' + sovJsArg(x.batiment) + ',' + sovJsArg(x.piece) + ')', true)))).join('')
    : '<p>' + powT('noShop') + '</p>';
  const passees = (l.saisines || []).slice(0, 8);
  if (passees.length) html += vehSection(powT('secReferrals'), passees.map(s => '<div>' + sovEchapper(s.exploitant || '?') + ' — '
    + (['en_attente', 'retire', 'rejete'].includes(s.statut) ? powT('sa_' + s.statut) : s.statut) + '</div>').join(''));
  powModal(powT('titleRefer'), html, ouvrirSovarkaSaisirJuge);
}
function sovarkaSaisirJuge(ville, batiment, piece) {
  const motif = (document.getElementById('sov-saisine-motif')?.value || '').trim();
  sovPouvoirActe('saisir_juge', { ville, batiment, piece, motif }, powT('tReferral'),
    v => v.decision === 'retire' ? powT('judgeAgrees') : powT('judgeSeized', { juge: v.juge }), ouvrirSovarkaSaisirJuge);
}

// ---------------------------------------------------------------- Vérité officielle : sondages et fuite
function ouvrirSovarkaSondage() {
  powModal(powT('titlePoll'), '<p class="cpj-note">' + powT('pollIntro') + '</p>'
    + '<input class="cpj-champ" id="sov-sondage-sujet" maxlength="200" placeholder="' + sovEchapper(powT('pollPh')) + '" style="width:100%">'
    + vehBouton(powT('orderPoll'), 'sovarkaSondageCommander()', true), ouvrirSovarkaSondage);
}
function sovarkaSondageCommander() {
  const sujet = (document.getElementById('sov-sondage-sujet')?.value || '').trim();
  sovPouvoirActe('sondage_commander', { sujet }, powT('tPoll'), v => powT('pollReceived', { inf: v.gain_inf }), ouvrirSovarkaSondages);
}
async function ouvrirSovarkaSondages(cache) {
  const l = await sovPouvoirLire(cache); if (!l) return;
  const attente = (l.sondages || []).filter(s => s.statut === 'en_attente');
  const html = attente.length ? attente.map(s => vehSection(sovEchapper(s.sujet),
      (s.reels || []).map(r => '<div>' + powT('publishLine', { nom: sovEchapper(r.nom), pop: r.pop }) + ' '
        + '<input class="cpj-champ" type="number" min="0" max="100" style="width:4.5rem" id="sov-fx-' + s.id + '-' + sovEchapper(r.parti) + '" value="' + r.pop + '"> %</div>').join('')
      + vehBouton(powT('publishAsIs'), 'sovarkaSondageDecider(' + s.id + ",'publier')", true)
      + vehBouton(powT('publishModified'), 'sovarkaSondageDecider(' + s.id + ",'fausser')", false)
      + vehBouton(powT('bury'), 'sovarkaSondageDecider(' + s.id + ",'enterrer')", false))).join('')
    : '<p>' + powT('noPoll') + '</p>';
  powModal(powT('titlePolls'), '<p class="cpj-note">' + powT('pollWarn') + '</p>' + html, ouvrirSovarkaSondages);
}
async function sovarkaSondageDecider(id, choix) {
  const params = { sondage: id, choix };
  if (choix === 'fausser') {
    const l = await sovPouvoirLire(); if (!l) return;
    const s = (l.sondages || []).find(x => x.id === id); if (!s) return;
    params.valeurs = {};
    (s.reels || []).forEach(r => { params.valeurs[r.parti] = Number(document.getElementById('sov-fx-' + id + '-' + r.parti)?.value); });
  }
  sovPouvoirActe('sondage_decider', params, powT('tPoll'),
    v => (['publie', 'fausse', 'enterre'].includes(v.statut) ? powT('po_' + v.statut) : undefined), ouvrirSovarkaSondages);
}
// Deux pièces compromettantes aux Archives (Fred, 08/11/2026) : le dernier sondage truqué, ou le
// registre secret de la cellule Balatov (signalements des 30 derniers jours).
function sovarkaFuite() {
  powModal(powT('titleLeak'), '<p class="cpj-note">' + powT('leakIntro') + '</p>'
    + vehBouton(powT('leakPoll'), "document.getElementById('modal-postes')?.classList.remove('open');sovarkaFuiteProduire('sondage')", true)
    + vehBouton(powT('leakRegister'), "document.getElementById('modal-postes')?.classList.remove('open');sovarkaFuiteProduire('signalements')", false), sovarkaFuite);
}
function sovarkaFuiteProduire(objet) {
  sovPouvoirActe('fuite', { objet }, powT('titleLeak'),
    v => v.objet === 'signalements'
      ? (v.trouve ? powT('leakRegOk') : powT('leakRegNone'))
      : (v.trouve ? powT('leakPollOk', { ministre: v.ministre }) : powT('leakPollNone')));
}

// ---------------------------------------------------------------- Registre des signalements (cellule Balatov)
// Lisible par le Président du Conseil et le ministre de la Sécurité du Peuple (Fred, 08/11/2026) ;
// aucun effet automatique, les PJ en font ce qu'ils veulent.
async function ouvrirSovarkaSignalements(cache) {
  const l = await sovPouvoirLire(cache); if (!l) return;
  if (!Array.isArray(l.signalements)) { powModal(powT('titleReports'), '<p>' + powT('reportsReserved') + '</p>', ouvrirSovarkaSignalements); return; }
  const motifs = { abstention: powT('mo_abstention') };
  powModal(powT('titleReports'), '<p class="cpj-note">' + powT('reportsIntro') + '</p>'
    + (l.signalements.length ? l.signalements.map(g => '<div style="margin:.3rem 0">'
        + new Date(g.ts).toLocaleDateString('fr-FR') + ' — <b>' + sovEchapper(g.cible) + '</b>'
        + (g.parti_nom ? ' (' + sovEchapper(g.parti_nom) + ')' : '') + ' : ' + sovEchapper(motifs[g.motif] || g.motif)
        + (g.loi ? powT('onLaw', { loi: sovEchapper(g.loi) }) : '') + '</div>').join('')
      : '<p>' + powT('noReport') + '</p>'), ouvrirSovarkaSignalements);
}

// ---------------------------------------------------------------- Défense de la Patrie : conscription
async function ouvrirSovarkaConscription(cache) {
  const l = await sovPouvoirLire(cache); if (!l) return;
  if (!(l.postes || []).includes('min_def')) { powModal(powT('titleConscription'), '<p>' + powT('pm_reserve_ministre_defense') + '</p>', ouvrirSovarkaConscription); return; }
  const active = !!l.conscription?.active;
  powModal(powT('titleConscription'), '<p class="cpj-note">' + powT('conscIntro') + '</p>'
    + '<p>' + (active ? powT('conscActive') : powT('conscNone')) + '</p>'
    + (active ? vehBouton(powT('lift'), 'sovarkaConscriptionLever()', true)
              : vehBouton(powT('decree'), 'sovarkaConscriptionDecreter()', true)), ouvrirSovarkaConscription);
}
function sovarkaConscriptionLever() {
  return sovPouvoirActe('conscription_lever', {}, powT('titleConscription'), v => powT('freed', { n: v.liberes }), ouvrirSovarkaConscription);
}
function sovarkaConscriptionDecreter() {
  return sovPouvoirActe('conscription_declencher', {}, powT('titleConscription'), v => powT('called', { n: v.appeles }), ouvrirSovarkaConscription);
}
function sovarkaConscritPresenter() {
  sovPouvoirActe('conscrit_presenter', {}, powT('titleConscription'), powT('reported'));
}

// ---------------------------------------------------------------- Autocritique publique (Président du Conseil)
async function ouvrirSovarkaAutocritique(cache) {
  const l = await sovPouvoirLire(cache); if (!l) return;
  if (!l.pm) { powModal(powT('titleSelfCrit'), '<p>' + powT('pm_reserve_president_du_conseil') + '</p>', ouvrirSovarkaAutocritique); return; }
  const m = l.ministres || [];
  powModal(powT('titleSelfCrit'), '<p class="cpj-note">' + powT('selfCritIntro') + '</p>'
    + (m.length ? m.map(x => '<div style="margin:.3rem 0">' + sovEchapper(x.nom) + ' — ' + sovEchapper(typeof intitulePoste === 'function' ? intitulePoste(x.poste, 'soviet') : x.poste) + ' '
        + (x.autocritique_faite ? '<span class="cpj-note">' + powT('alreadyWeek') + '</span>'
           : vehBouton(powT('demand'), 'sovarkaAutocritiqueExiger(' + sovJsArg(x.nom) + ')', true))
        + '</div>').join('') : '<p>' + powT('noMinister') + '</p>'), ouvrirSovarkaAutocritique);
}
function sovarkaAutocritiqueExiger(ministre) {
  return sovPouvoirActe('autocritique', { ministre }, powT('titleSelfCrit'), v => powT('selfCritOk', { ministre: v.ministre }), ouvrirSovarkaAutocritique);
}

// ---------------------------------------------------------------- Sécurité du Peuple : surveillance d'un citoyen
// Décisions de Fred (08/11/2026) : 4 jours, 2 PA, 150 PSK sur la caisse du ministère ; rapport garanti chaque
// matin (déplacements et PJ croisés) ; découverte possible (perception, intelligence, sécurité de la ville) ;
// toute cible ; trois au plus. Tout est décidé par sovarka_surveillance_commande / _lire ; l'écran recopie.
function sovLieuSurveillance(e) {
  if (e.hors_territoire) return powT('abroad');
  const ville = (typeof villeNom === 'function' && villeNom('soviet', e.ville)) || e.ville || '?';
  if (!e.batiment || String(e.batiment).startsWith('rue')) return powT('inStreet', { ville });
  const ctx = (typeof WORLD !== 'undefined' && WORLD.soviet?.[e.ville]?.buildingContext?.[e.batiment]) || null;
  const def = (typeof BUILDINGS !== 'undefined' && BUILDINGS[e.batiment]) || null;
  const bat = ctx?.name || def?.name || e.batiment;
  const piece = ctx?.rooms?.[e.piece]?.name || def?.rooms?.[e.piece]?.name || '';
  return ville + ', ' + bat + (piece && piece !== bat ? ' — ' + piece : '');
}
let sovSurveillanceDerniere = null;
async function ouvrirSovarkaSurveillance(cache) {
  const l = (cache === true && sovSurveillanceDerniere) || await sbRpcVerdict('sovarka_surveillance_lire', {}).catch(() => null);
  if (!l || l.ok !== true) { powModal(powT('titleSurv'), '<p>' + sovPMotif(l) + '</p>'); return; }
  sovSurveillanceDerniere = l;
  const toutes = l.surveillances || [];
  const actives = toutes.filter(x => x.statut === 'active');
  const enCours = new Set(actives.map(x => x.cible));
  const max = l.max || 3;
  const heure = t => new Date(t).toLocaleString('fr-FR', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' });
  const rapport = r => '<div style="margin:.3rem 0 .6rem .6rem">' + ((r.deplacements || []).length
      ? r.deplacements.map(e => '<div>' + heure(e.debut) + ' — ' + sovEchapper(sovLieuSurveillance(e))
          + ((e.croises || []).length ? ' <span class="cpj-note">' + powT('inPresence', { noms: e.croises.map(sovEchapper).join(', ') }).replace(/^ /, '') + '</span>' : '') + '</div>').join('')
      : '<div class="cpj-note">' + powT('noMove') + '</div>') + '</div>';
  const libres = (l.cibles || []).filter(n => !enCours.has(n));
  powModal(powT('titleSurv'), '<p class="cpj-note">' + powT('survIntro', { solde: Math.floor(l.caisse || 0) }) + '</p>'
    + (actives.length < max && libres.length
      ? '<div style="display:flex;gap:.5rem;align-items:center;margin:.5rem 0"><select id="sov-surv-cible" class="cpj-champ">'
        + libres.map(n => '<option value="' + sovEchapper(n) + '">' + sovEchapper(n) + '</option>').join('') + '</select>'
        + vehBouton(powT('watch'), "sovarkaSurveiller(document.getElementById('sov-surv-cible').value)", true) + '</div>'
      : '<p>' + (actives.length >= max ? powT('pm_limite_surveillances') : powT('noTarget')) + '</p>')
    + toutes.map(x => '<div style="margin-top:.6rem"><b>' + sovEchapper(x.cible) + '</b> — '
        + (x.statut === 'active' ? powT('ongoing', { n: x.rapports_restants }) : powT('ended'))
        + (x.rapports || []).map(r => '<div class="cpj-note">' + powT('reportOf', { date: new Date(r.jour).toLocaleDateString('fr-FR') }) + '</div>' + rapport(r)).join('')
        + '</div>').join(''), ouvrirSovarkaSurveillance);
}
async function sovarkaSurveiller(cible) {
  if (sovPouvoirEnCours || !cible) return;
  sovPouvoirEnCours = true;
  let v = null;
  try {
    v = await sbRpcVerdict('sovarka_surveillance_commande', { p_requete: crypto.randomUUID(), p_cible: cible }).catch(() => null);
    if (!v || v.ok !== true) { showToast(powT('tSurv'), sovPMotif(v), false); return; }
    if (typeof appliquerPaiementServeur === 'function') appliquerPaiementServeur({ pa: v.pa, liquide: v.liquide, arg: v.arg });
    if (typeof updateHeader === 'function') updateHeader();
    showToast(powT('tSurv'), powT('survOk', { cible: v.cible }), true);
  } finally { sovPouvoirEnCours = false; }
  if (v && v.ok === true) ouvrirSovarkaSurveillance();
}
