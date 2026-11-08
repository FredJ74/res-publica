// POUVOIR EN SOVARKA (07/11/2026, décisions de Fred, GAME-DESIGN-NOVOMIRSK.md).
// Soviet Suprême : sièges répartis à la semaine à la gloire des partis, députés désignés par
// les chefs de parti. Le serveur décide tout (sovarka_soviet_etat, sovarka_depute_designer) ;
// l'écran n'affiche que ses réponses.

const SOVIET_MOTIFS = {
  pas_chef_de_parti: 'Seul le chef d’un parti de Sovarka désigne les députés de son parti.',
  pas_sur_place: 'Les députés se désignent depuis « Mon parti », dans la salle des partis d’une mairie.',
  aucun_siege: 'Votre parti n’a obtenu aucun siège à la dernière semaine à la gloire.',
  sieges_pourvus: 'Tous les sièges de votre parti sont déjà pourvus.',
  hors_parti: 'Seuls les membres de votre parti peuvent siéger en son nom.',
  deja_depute: 'Cette personne est déjà député.',
  pas_depute_du_parti: 'Cette personne ne siège pas pour votre parti.',
  personnage_introuvable: 'Personnage introuvable.',
  acteur_non_authentifie: 'Votre session doit être rétablie.'
};
let sovietDesignationEnCours = false;

function sovEchapper(s) {
  if (typeof escapeHtmlText === 'function') return escapeHtmlText(s);
  return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

async function ouvrirSovietSupreme() {
  const v = await sbRpcVerdict('sovarka_soviet_etat', {}).catch(() => null);
  if (!v || v.ok !== true) {
    showToast('Soviet Suprême', SOVIET_MOTIFS[v?.raison] || 'Le serveur n’a pas répondu.', false);
    return;
  }
  const scores = Array.isArray(v.scores) ? v.scores : [];
  const sieges = v.sieges || {};
  const deputes = v.deputes || {};
  let html = '<p>Les 9 sièges du Soviet Suprême sont répartis entre les partis à la proportionnelle de leurs ' +
    'partisans, lors de la semaine à la gloire des partis. Chaque chef de parti désigne ensuite ses députés.</p>';
  if (!scores.length) {
    html += vehSection('Législature', '<p class="cpj-note">Aucune semaine à la gloire n’a encore été proclamée.</p>');
  } else {
    let corps = v.vainqueur ? '<p>Parti vainqueur : <strong>' + sovEchapper(v.vainqueur) + '</strong></p>' : '';
    scores.forEach(s => {
      const noms = Array.isArray(deputes[s.partiId]) ? deputes[s.partiId] : [];
      corps += '<p style="margin:.35rem 0"><strong>' + sovEchapper(s.nom) + '</strong> — ' +
        (sieges[s.partiId] || 0) + ' siège(s) · ' + (s.adherentsPJ || 0) + ' adhérent(s), ' +
        (s.partisansPNJ || 0) + ' partisan(s)' +
        (noms.length ? '<br><span class="cpj-note">Députés : ' + noms.map(sovEchapper).join(', ') + '</span>' : '') + '</p>';
    });
    html += vehSection('Législature en cours', corps);
  }
  if (v.chef && v.monParti) {
    const miens = Array.isArray(deputes[v.monParti]) ? deputes[v.monParti] : [];
    const nb = sieges[v.monParti] || 0;
    let corps = '<p>' + miens.length + ' / ' + nb + ' siège(s) pourvu(s).</p>';
    (Array.isArray(v.membres) ? v.membres : []).forEach(nom => {
      const siege = miens.indexOf(nom) >= 0;
      const js = 'designerDeputeSoviet(' + JSON.stringify(nom).replace(/"/g, '&quot;') + ',' + siege + ')';
      corps += '<div style="margin:.3rem 0">' + sovEchapper(nom) + (siege ? ' — <em>député</em>' : '') +
        vehBouton(siege ? 'Retirer le siège' : 'Désigner député', js, !siege) + '</div>';
    });
    html += vehSection('Désigner les députés de votre parti', corps);
  }
  vehModal('Soviet Suprême', html);
}

async function designerDeputeSoviet(nom, retirer) {
  if (sovietDesignationEnCours) return;
  sovietDesignationEnCours = true;
  try {
    const v = await sbRpcVerdict('sovarka_depute_designer', { p_nom: nom, p_retirer: !!retirer }).catch(() => null);
    if (!v || v.ok !== true) {
      showToast('Soviet Suprême', SOVIET_MOTIFS[v?.raison] || 'Le serveur n’a pas confirmé.', false);
      return;
    }
    showToast('Soviet Suprême', retirer ? nom + ' ne siège plus.' : nom + ' siège désormais au Soviet Suprême.', true);
    await ouvrirSovietSupreme();
  } finally { sovietDesignationEnCours = false; }
}

// REPAS PRESIDENTIEL (étape 6, Fred 07/11/2026) : un repas gratuit par jour dans les appartements
// du Palais du Parti, avec un invité présent s'il le souhaite ; effets du dîner d'affaires. Le
// serveur (sovarka_repas_presidentiel) vérifie le président, le lieu, l'invité et le jour.
const REPAS_PRES_MOTIFS = {
  reserve_president: 'Réservé au Président de la République de Sovarka.',
  pas_sur_place: 'Le repas se prend dans les appartements présidentiels.',
  deja_pris_aujourdhui: 'Le repas présidentiel a déjà été servi aujourd’hui.',
  invite_absent: 'Votre invité doit se trouver avec vous dans les appartements.',
  invite_invalide: 'Choisissez un autre invité.',
  acteur_non_authentifie: 'Votre session doit être rétablie.'
};
let repasPresidentielEnCours = false;

async function ouvrirRepasPresidentiel() {
  const presents = (typeof sbGetPresencesInRoom === 'function')
    ? await sbGetPresencesInRoom(state.country, state.currentCity, state.currentBuilding, state.currentRoom).catch(() => [])
    : [];
  const moi = state.char?.name || '';
  const noms = Array.from(new Set((presents || []).map(p => p.name || p.nom).filter(n => n && n !== moi)));
  let corps = '<p>Un repas offert par jour : +10 Santé, +2 Moral, +5 INF et +3 PA au prochain Dormir, ' +
    'pour vous et pour votre invité.</p><select id="repas-pres-invite" class="cpj-champ"><option value="">Seul</option>' +
    noms.map(n => '<option value="' + sovEchapper(n) + '">' + sovEchapper(n) + '</option>').join('') + '</select><br>' +
    vehBouton('Faire servir le repas', 'servirRepasPresidentiel()', true);
  vehModal('Appartements présidentiels', vehSection('Repas du Président', corps));
}

async function servirRepasPresidentiel() {
  if (repasPresidentielEnCours) return;
  repasPresidentielEnCours = true;
  const invite = document.getElementById('repas-pres-invite')?.value || null;
  const cle = 'hg-repas-pres:' + (state.char?.name || '') + ':' + new Date().toISOString().slice(0, 10);
  try {
    let requete = sessionStorage.getItem(cle);
    if (!requete) { requete = crypto.randomUUID(); sessionStorage.setItem(cle, requete); }
    const v = await sbRpcVerdict('sovarka_repas_presidentiel', { p_requete: requete, p_invite: invite }).catch(() => null);
    if (v && !v.transport && v.ok !== true) sessionStorage.removeItem(cle);
    if (!v || v.ok !== true) {
      showToast('Repas présidentiel', REPAS_PRES_MOTIFS[v?.raison] || 'Le serveur n’a pas confirmé le repas.', false);
      return;
    }
    if (typeof v.hp === 'number') state.hp = v.hp;
    if (typeof v.moral === 'number') state.moral = v.moral;
    if (v.inf != null && typeof adopterJaugeServeur === 'function') adopterJaugeServeur('inf', v.inf);
    if (typeof updateHeader === 'function') updateHeader();
    if (typeof updateUI === 'function') updateUI();
    document.getElementById('modal-postes')?.classList.remove('open');
    showToast('Repas présidentiel', v.invite ? 'Servi pour vous et ' + v.invite + '.' : 'Servi.', true);
  } finally { repasPresidentielEnCours = false; }
}

// ============================================================================================
// MINISTÈRES DE SOVARKA (décisions de Fred du 08/11/2026, GAME-DESIGN-NOVOMIRSK.md) : lois des
// partis tranchées par le Président du Conseil, séance du jeudi, manifestations de soutien,
// fiscalité 10/10/10, saisine du juge, sondages, fuite, conscription, autocritique publique.
// Tout est décidé par sovarka_pouvoir_commande / sovarka_pouvoir_lire ; l'écran recopie.
// ============================================================================================
const SOV_POUVOIR_MOTIFS = {
  reserve_a_sovarka: 'Réservé aux citoyens de Sovarka.',
  reserve_chef_de_parti: 'Réservé au chef d’un parti de Sovarka.',
  salle_des_partis_requise: 'Rendez-vous dans la salle des partis d’une mairie.',
  type_invalide: 'Type de loi inconnu.', champs_requis: 'Remplissez le titre et le texte.',
  texte_trop_long: 'Texte trop long.', titre_trop_long: 'Titre trop long (120 caractères au plus).',
  loi_cible_introuvable: 'Loi à abroger introuvable.', categorie_invalide: 'Catégorie d’interdiction inconnue.',
  reserve_president_du_conseil: 'Réservé au Président du Conseil du Peuple.',
  bureau_du_president_du_conseil_requis: 'Rendez-vous dans votre bureau du Palais du Gouvernement.',
  projet_introuvable: 'Ce projet n’est plus en examen.',
  reserve_depute: 'Réservé aux députés du Soviet Suprême.', seance_le_jeudi: 'La séance a lieu le jeudi.',
  salle_du_conseil_requise: 'Rendez-vous dans la Salle du Conseil du Peuple.',
  emargement_requis: 'Émargez d’abord.', choix_invalide: 'Choix invalide.',
  hors_ordre_du_jour: 'Cette loi n’est pas à l’ordre du jour.', deja_vote: 'Vous vous êtes déjà prononcé.',
  aucun_parti_au_pouvoir: 'Aucun parti n’est au pouvoir : rien à soutenir.',
  a_la_mairie: 'La manifestation part de la mairie : organisez-la depuis la salle des partis.', pas_chef: 'Seul le meneur du groupe organise.',
  deja_aujourdhui: 'Une manifestation a déjà eu lieu dans cette ville aujourd’hui.',
  groupe_insuffisant: 'Il faut au moins 10 manifestants présents avec vous.',
  poste_requis: 'Réservé au titulaire du poste.', pas_sur_place: 'Rendez-vous sur place.',
  sujet_invalide: 'Sujet du sondage : 3 à 200 caractères.', sondage_introuvable: 'Sondage introuvable.',
  deja_decide: 'Ce sondage a déjà été traité.', valeurs_requises: 'Indiquez les chiffres à publier.',
  publication_refusee: 'La publication a été refusée.',
  reserve_ministre_justice: 'Réservé au ministre de la Justice prolétarienne.',
  motif_invalide: 'Motif : 3 à 300 caractères.', local_non_exploite: 'Ce commerce n’est exploité par personne.',
  saisine_deja_en_cours: 'Le juge est déjà saisi pour ce commerce.', saisine_introuvable: 'Saisine introuvable.',
  saisine_requise: 'Le juge ne peut retirer un droit que sur saisine du ministre.',
  reserve_juge: 'Réservé au juge de la ville.', pas_au_tribunal: 'Rendez-vous au tribunal.',
  reserve_ministre_defense: 'Réservé au ministre de la Défense de la Patrie.',
  deja_active: 'La conscription est déjà en vigueur.', pas_active: 'Aucune conscription en vigueur.',
  pas_convoque: 'Vous n’êtes pas convoqué.', pas_a_la_caserne: 'Présentez-vous à la caserne.',
  pas_ministre: 'Cette personne n’est pas ministre.', deja_cette_semaine: 'Déjà fait cette semaine pour ce ministre.',
  pa_insuffisants: 'Pas assez de points d’action.', fonds_insuffisants: 'Fonds insuffisants.',
  portee_reservee_sovarka: 'Taxe propre à Sovarka.', pas_de_taxe_locale_en_sovarka: 'Pas de taxe locale en Sovarka.',
  cible_invalide: 'Choisissez un autre citoyen.', deja_surveille: 'Cette personne est déjà sous surveillance.',
  limite_surveillances: 'Trois surveillances sont déjà en cours.', caisse_insuffisante: 'La caisse du ministère ne couvre pas les 150 PSK.',
  acteur_non_authentifie: 'Votre session doit être rétablie.'
};
const sovPMotif = v => SOV_POUVOIR_MOTIFS[v?.raison] || (v ? 'Refusé par le serveur.' : 'Réponse du serveur non reçue.');
const sovJsArg = s => JSON.stringify(String(s == null ? '' : s)).replace(/"/g, '&quot;');
let sovPouvoirEnCours = false;

async function sovPouvoirLire() {
  const v = await sbRpcVerdict('sovarka_pouvoir_lire', {}).catch(() => null);
  if (!v || v.ok !== true) { showToast('Sovarka', sovPMotif(v), false); return null; }
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
async function ouvrirSovarkaDeposerLoi() {
  const l = await sovPouvoirLire(); if (!l) return;
  if (!l.chef_parti) { vehModal('Déposer un projet de loi', '<p>' + SOV_POUVOIR_MOTIFS.reserve_chef_de_parti + '</p>'); return; }
  const cats = (typeof rafraichirAssembleeCategories === 'function') ? (await rafraichirAssembleeCategories()) || {} : {};
  const enVigueur = (l.lois || []).filter(x => x.statut === 'adoptee');
  let html = '<p class="cpj-note">Votre parti dépose le projet (1 PA). Le Président du Conseil du Peuple le tranche seul ; '
    + 'accepté, il est promulgué aussitôt, puis les députés l’approuvent le jeudi.</p>'
    + '<select id="sov-loi-type" class="cpj-champ" style="width:100%;margin:.3rem 0">'
    + '<option value="rp">Loi déclarative</option>'
    + (Object.keys(cats).length ? '<option value="mecanique">Loi d’interdiction</option>' : '')
    + (enVigueur.length ? '<option value="abrogation">Abrogation d’une loi</option>' : '') + '</select>'
    + '<input id="sov-loi-titre" class="cpj-champ" maxlength="120" placeholder="Titre" style="width:100%;margin:.3rem 0">'
    + (Object.keys(cats).length ? '<select id="sov-loi-cat" class="cpj-champ" style="width:100%;margin:.3rem 0">'
       + Object.keys(cats).map(k => '<option value="' + sovEchapper(k) + '">Interdiction : ' + sovEchapper(cats[k].label) + '</option>').join('') + '</select>' : '')
    + (enVigueur.length ? '<select id="sov-loi-cible" class="cpj-champ" style="width:100%;margin:.3rem 0">'
       + enVigueur.map(x => '<option value="' + sovEchapper(x.id) + '">À abroger : ' + sovEchapper(x.titre) + '</option>').join('') + '</select>' : '')
    + '<textarea id="sov-loi-texte" class="cpj-champ" rows="6" maxlength="20000" placeholder="Texte de la loi" style="width:100%;margin:.3rem 0"></textarea>'
    + vehBouton('Déposer (1 PA)', 'sovarkaDeposerLoi()', true);
  vehModal('Déposer un projet de loi', html);
}
function sovarkaDeposerLoi() {
  const type = document.getElementById('sov-loi-type')?.value || 'rp';
  const params = { type, titre: (document.getElementById('sov-loi-titre')?.value || '').trim(),
                   texte: (document.getElementById('sov-loi-texte')?.value || '').trim() };
  if (type === 'mecanique') params.categorie = document.getElementById('sov-loi-cat')?.value || '';
  if (type === 'abrogation') params.loi_cible = document.getElementById('sov-loi-cible')?.value || '';
  sovPouvoirActe('loi_deposer', params, 'Projet de loi', v => '« ' + v.titre + ' » attend la décision du Président du Conseil du Peuple.',
    () => document.getElementById('modal-postes')?.classList.remove('open'));
}

// ---------------------------------------------------------------- Lois : le Président du Conseil tranche
async function ouvrirSovarkaLoisExamen() {
  const l = await sovPouvoirLire(); if (!l) return;
  if (!l.pm) { vehModal('Projets de loi', '<p>' + SOV_POUVOIR_MOTIFS.reserve_president_du_conseil + '</p>'); return; }
  const examen = (l.lois || []).filter(x => x.statut === 'examen');
  const html = '<p class="cpj-note">Vous tranchez seul, sans réunir vos ministres. Une loi acceptée est promulguée '
    + 'aussitôt ; les députés l’approuveront jeudi.</p>'
    + (examen.length ? examen.map(x => vehSection(sovEchapper(x.titre),
        '<p class="cpj-note">Parti : ' + sovEchapper(x.parti_nom || '—') + ' · ' + sovEchapper(x.auteur) + '</p>'
        + '<p style="white-space:pre-wrap">' + sovEchapper(x.texte) + '</p>'
        + vehBouton('Promulguer', 'sovarkaTrancherLoi(' + sovJsArg(x.id) + ',true)', true)
        + vehBouton('Refuser', 'sovarkaTrancherLoi(' + sovJsArg(x.id) + ',false)', false))).join('')
      : '<p>Aucun projet en attente.</p>');
  vehModal('Projets de loi à trancher', html);
}
function sovarkaTrancherLoi(id, accepter) {
  sovPouvoirActe('loi_trancher', { loi: id, accepter }, accepter ? 'Loi promulguée' : 'Projet refusé',
    v => accepter ? '« ' + v.titre + ' » s’applique dès maintenant.' : '« ' + v.titre + ' » est refusé.', ouvrirSovarkaLoisExamen);
}

// ---------------------------------------------------------------- Séance du jeudi (députés)
async function ouvrirSovarkaSeance() {
  const l = await sovPouvoirLire(); if (!l) return;
  let html = '<p class="cpj-note">Les députés sont convoqués chaque jeudi. Ils approuvent les lois déjà promulguées, '
    + 'ou s’abstiennent : l’abstention est signalée à la cellule de surveillance et coûte 5 POP à leur parti. '
    + 'Un député absent perd son indemnité (250 PSK par jour) pour toute la semaine.</p>';
  if (l.indemnite_suspendue_jusqu_au) html += '<p class="cpj-note">Votre indemnité est suspendue jusqu’au ' + sovEchapper(l.indemnite_suspendue_jusqu_au) + ' inclus.</p>';
  const odj = l.ordre_du_jour || [];
  if (l.depute && l.jeudi && !l.emarge) html += vehBouton('Émarger', "sovPouvoirActe('seance_emarger',{},'Séance','Présence enregistrée.',ouvrirSovarkaSeance)", true);
  html += vehSection(l.jeudi ? 'Ordre du jour' : 'Ordre du jour de la séance du ' + sovEchapper(l.jeudi_seance),
    odj.length ? odj.map(o => '<div style="margin:.4rem 0"><strong>' + sovEchapper(o.titre) + '</strong>'
      + ' <span class="cpj-note">(' + sovEchapper(o.parti_nom || '—') + ' · ' + o.approbations + ' approbation(s), ' + o.abstentions + ' abstention(s))</span>'
      + (o.mon_choix ? ' — <em>' + (o.mon_choix === 'APPROUVE' ? 'approuvée' : 'abstention') + '</em>'
        : (l.depute && l.jeudi && l.emarge ? '<br>' + vehBouton('Approuver', 'sovarkaApprouver(' + sovJsArg(o.id) + ",'APPROUVE')", true)
          + vehBouton('S’abstenir (−5 POP au parti)', 'sovarkaApprouver(' + sovJsArg(o.id) + ",'ABSTENTION')", false) : ''))
      + '</div>').join('') : '<p>Aucune loi promulguée cette semaine.</p>');
  const vigueur = (l.lois || []).filter(x => x.statut === 'adoptee');
  html += vehSection('Lois en vigueur', vigueur.length ? vigueur.map(x => '<div>• ' + sovEchapper(x.titre) + '</div>').join('') : '<p>Aucune.</p>');
  vehModal('Séance du Conseil du Peuple', html);
}
function sovarkaApprouver(id, choix) {
  sovPouvoirActe('loi_approuver', { loi: id, choix }, 'Séance',
    v => v.choix === 'APPROUVE' ? 'Approbation enregistrée.' : 'Abstention enregistrée et signalée. Votre parti perd 5 POP.', ouvrirSovarkaSeance);
}

// ---------------------------------------------------------------- Manifestation de soutien (chef de parti)
function sovarkaManifSoutien() {
  sovPouvoirActe('manif_soutien', {}, 'Manifestation de soutien',
    v => v.participants + ' manifestants : +' + v.participants + ' POP au parti au pouvoir.',
    () => document.getElementById('modal-postes')?.classList.remove('open'));
}

// ---------------------------------------------------------------- Économie collective : trois taux
async function ouvrirFiscaliteSovarka(pa, cost) {
  const l = await sovPouvoirLire(); if (!l) return;
  if (!(l.postes || []).includes('min_fin')) { vehModal('Fiscalité', '<p>Réservé au ministre de l’Économie collective.</p>'); return; }
  const b = (typeof chargerBudgetNational === 'function') ? (await chargerBudgetNational('soviet')) || {} : {};
  const curseur = (id, libelle, taux, portee) => vehSection(libelle,
    '<input id="' + id + '" type="range" min="0" max="40" value="' + taux + '" oninput="document.getElementById(\'' + id + '-v\').textContent=this.value+\' %\'" style="width:100%">'
    + '<div id="' + id + '-v" style="text-align:center">' + taux + ' %</div>'
    + vehBouton('Appliquer', "sovarkaFixerTaux('" + portee + "','" + id + "'," + (pa || 0) + ',' + (cost || 0) + ')', true));
  vehModal('Fiscalité de Sovarka',
    '<p class="cpj-note">Les mairies vivent des loyers ; l’État prélève sur les ventes, sur la main-d’œuvre et sur les recettes des mairies.</p>'
    + curseur('sov-taux-ventes', 'Impôt sur les ventes', b.tauxNational ?? 10, 'national')
    + curseur('sov-taux-mo', 'Impôt sur la main-d’œuvre', b.tauxMainOeuvre ?? 10, 'main_oeuvre')
    + curseur('sov-taux-muni', 'Impôt sur les recettes municipales', b.tauxMunicipal ?? 10, 'municipal'));
}
async function sovarkaFixerTaux(portee, id, pa, cost) {
  if (typeof fixerTauxImposition !== 'function') return;
  const r = await fixerTauxImposition(portee, id, pa, cost);
  if (r) showToast('Taux fixé', 'Nouveau taux : ' + r.taux + ' %.', true);
}

// ---------------------------------------------------------------- Justice prolétarienne : saisir le juge
async function ouvrirSovarkaSaisirJuge() {
  const l = await sovPouvoirLire(); if (!l) return;
  if (!(l.postes || []).includes('min_just')) { vehModal('Saisir le juge', '<p>' + SOV_POUVOIR_MOTIFS.reserve_ministre_justice + '</p>'); return; }
  const d = (typeof sovLire === 'function') ? await sovLire() : null;
  const exploites = (d?.locaux || []).filter(x => x.exploitant);
  const enCours = new Set((l.saisines || []).filter(s => s.statut === 'en_attente').map(s => s.ville + '|' + s.batiment + '|' + s.piece));
  let html = '<p class="cpj-note">Vous seul saisissez le juge (1 PA). Un juge PNJ vous donne toujours raison : le droit revient '
    + 'aussitôt à l’État. Un juge PJ décide librement.</p>'
    + '<input class="cpj-champ" id="sov-saisine-motif" maxlength="300" placeholder="Motif" style="width:100%">';
  html += exploites.length ? exploites.map(x => vehSection(sovEchapper(x.label) + ' (' + sovEchapper(sovVille(x.ville)) + ')',
    '<p>Exploitant : ' + sovEchapper(x.exploitant) + '</p>' + (enCours.has(x.ville + '|' + x.batiment + '|' + x.piece)
      ? '<p class="cpj-note">Juge déjà saisi.</p>'
      : vehBouton('Saisir le juge (1 PA)', 'sovarkaSaisirJuge(' + sovJsArg(x.ville) + ',' + sovJsArg(x.batiment) + ',' + sovJsArg(x.piece) + ')', true)))).join('')
    : '<p>Aucun commerce exploité.</p>';
  const passees = (l.saisines || []).slice(0, 8);
  if (passees.length) html += vehSection('Saisines', passees.map(s => '<div>' + sovEchapper(s.exploitant || '?') + ' — '
    + ({ en_attente: 'en attente du juge', retire: 'droit retiré', rejete: 'rejetée' }[s.statut] || s.statut) + '</div>').join(''));
  vehModal('Saisir le juge', html);
}
function sovarkaSaisirJuge(ville, batiment, piece) {
  const motif = (document.getElementById('sov-saisine-motif')?.value || '').trim();
  sovPouvoirActe('saisir_juge', { ville, batiment, piece, motif }, 'Saisine',
    v => v.decision === 'retire' ? 'Le juge vous donne raison : le droit revient à l’État.' : 'Le juge ' + v.juge + ' est saisi.', ouvrirSovarkaSaisirJuge);
}

// ---------------------------------------------------------------- Vérité officielle : sondages et fuite
function ouvrirSovarkaSondage() {
  vehModal('Commanditer un sondage', '<p class="cpj-note">Le sondage mesure la popularité réelle des partis. Vous seul recevez '
    + 'les vrais chiffres, puis vous le publiez, l’enterrez ou le publiez faussé. Les vrais chiffres restent aux Archives.</p>'
    + '<input class="cpj-champ" id="sov-sondage-sujet" maxlength="200" placeholder="Sujet du sondage" style="width:100%">'
    + vehBouton('Commander (1 PA)', 'sovarkaSondageCommander()', true));
}
function sovarkaSondageCommander() {
  const sujet = (document.getElementById('sov-sondage-sujet')?.value || '').trim();
  sovPouvoirActe('sondage_commander', { sujet }, 'Sondage', v => 'Résultats reçus. +' + v.gain_inf + ' INF.', ouvrirSovarkaSondages);
}
async function ouvrirSovarkaSondages() {
  const l = await sovPouvoirLire(); if (!l) return;
  const attente = (l.sondages || []).filter(s => s.statut === 'en_attente');
  const html = attente.length ? attente.map(s => vehSection(sovEchapper(s.sujet),
      (s.reels || []).map(r => '<div>' + sovEchapper(r.nom) + ' : ' + r.pop + ' % — publier '
        + '<input class="cpj-champ" type="number" min="0" max="100" style="width:4.5rem" id="sov-fx-' + s.id + '-' + sovEchapper(r.parti) + '" value="' + r.pop + '"> %</div>').join('')
      + vehBouton('Publier tel quel', 'sovarkaSondageDecider(' + s.id + ",'publier')", true)
      + vehBouton('Publier les chiffres modifiés', 'sovarkaSondageDecider(' + s.id + ",'fausser')", false)
      + vehBouton('Enterrer', 'sovarkaSondageDecider(' + s.id + ",'enterrer')", false))).join('')
    : '<p>Aucun sondage en attente.</p>';
  vehModal('Sondages', '<p class="cpj-note">Un sondage faussé peut être démasqué par une fuite : le ministre perd alors 10 POP.</p>' + html);
}
async function sovarkaSondageDecider(id, choix) {
  const params = { sondage: id, choix };
  if (choix === 'fausser') {
    const l = await sovPouvoirLire(); if (!l) return;
    const s = (l.sondages || []).find(x => x.id === id); if (!s) return;
    params.valeurs = {};
    (s.reels || []).forEach(r => { params.valeurs[r.parti] = Number(document.getElementById('sov-fx-' + id + '-' + r.parti)?.value); });
  }
  sovPouvoirActe('sondage_decider', params, 'Sondage',
    v => ({ publie: 'Sondage publié.', fausse: 'Sondage publié avec vos chiffres.', enterre: 'Sondage enterré.' }[v.statut]), ouvrirSovarkaSondages);
}
// Deux pièces compromettantes aux Archives (Fred, 08/11/2026) : le dernier sondage truqué, ou le
// registre secret de la cellule Balatov (signalements des 30 derniers jours).
function sovarkaFuite() {
  vehModal('Produire une fuite', '<p class="cpj-note">Acte illégal : il laisse une trace. Que cherchez-vous dans les archives ?</p>'
    + vehBouton('Un sondage truqué', "document.getElementById('modal-postes')?.classList.remove('open');sovarkaFuiteProduire('sondage')", true)
    + vehBouton('Le registre de la cellule Balatov', "document.getElementById('modal-postes')?.classList.remove('open');sovarkaFuiteProduire('signalements')", false));
}
function sovarkaFuiteProduire(objet) {
  sovPouvoirActe('fuite', { objet }, 'Produire une fuite',
    v => v.objet === 'signalements'
      ? (v.trouve ? 'Le registre des signalements est publié au forum national.' : 'Aucun signalement récent dans le registre.')
      : (v.trouve ? 'Les vrais chiffres d’un sondage truqué sont publiés. Le ministre ' + v.ministre + ' perd 10 POP.'
                  : 'Rien de compromettant dans les archives aujourd’hui.'));
}

// ---------------------------------------------------------------- Registre des signalements (cellule Balatov)
// Lisible par le Président du Conseil et le ministre de la Sécurité du Peuple (Fred, 08/11/2026) ;
// aucun effet automatique, les PJ en font ce qu'ils veulent.
async function ouvrirSovarkaSignalements() {
  const l = await sovPouvoirLire(); if (!l) return;
  if (!Array.isArray(l.signalements)) { vehModal('Registre des signalements', '<p>Réservé au Président du Conseil du Peuple et au ministre de la Sécurité du Peuple.</p>'); return; }
  const motifs = { abstention: 'abstention' };
  vehModal('Registre des signalements', '<p class="cpj-note">Cellule de validation et surveillance des partis — Capitaine Igor Balatov. '
    + 'Ce registre ne déclenche rien de lui-même : à vous d’en faire usage.</p>'
    + (l.signalements.length ? l.signalements.map(g => '<div style="margin:.3rem 0">'
        + new Date(g.ts).toLocaleDateString('fr-FR') + ' — <b>' + sovEchapper(g.cible) + '</b>'
        + (g.parti_nom ? ' (' + sovEchapper(g.parti_nom) + ')' : '') + ' : ' + sovEchapper(motifs[g.motif] || g.motif)
        + (g.loi ? ' sur « ' + sovEchapper(g.loi) + ' »' : '') + '</div>').join('')
      : '<p>Aucun signalement.</p>'));
}

// ---------------------------------------------------------------- Défense de la Patrie : conscription
async function ouvrirSovarkaConscription() {
  const l = await sovPouvoirLire(); if (!l) return;
  if (!(l.postes || []).includes('min_def')) { vehModal('Conscription', '<p>' + SOV_POUVOIR_MOTIFS.reserve_ministre_defense + '</p>'); return; }
  const active = !!l.conscription?.active;
  vehModal('Conscription', '<p class="cpj-note">La conscription appelle les citoyens de Sovarka sans poste. Chacun a 48 heures pour se '
    + 'présenter à la caserne, sinon il est réfractaire et recherché. Le service dure jusqu’à ce que vous la leviez.</p>'
    + '<p>' + (active ? 'Conscription en vigueur.' : 'Aucune conscription en vigueur.') + '</p>'
    + (active ? vehBouton('Lever la conscription', "sovPouvoirActe('conscription_lever',{},'Conscription',v=>v.liberes+' conscrit(s) libéré(s).',ouvrirSovarkaConscription)", true)
              : vehBouton('Décréter la conscription', "sovPouvoirActe('conscription_declencher',{},'Conscription',v=>v.appeles+' citoyen(s) appelé(s).',ouvrirSovarkaConscription)", true)));
}
function sovarkaConscritPresenter() {
  sovPouvoirActe('conscrit_presenter', {}, 'Conscription', 'Vous vous êtes présenté : votre incorporation est enregistrée à la caserne.');
}

// ---------------------------------------------------------------- Autocritique publique (Président du Conseil)
async function ouvrirSovarkaAutocritique() {
  const l = await sovPouvoirLire(); if (!l) return;
  if (!l.pm) { vehModal('Autocritique publique', '<p>' + SOV_POUVOIR_MOTIFS.reserve_president_du_conseil + '</p>'); return; }
  const m = l.ministres || [];
  vehModal('Autocritique publique', '<p class="cpj-note">Vous contraignez un ministre à une autocritique publiée dans la presse (1 PA) : '
    + 'il perd 5 POP et garde son poste, vous gagnez 2 POP. Une fois par ministre et par semaine.</p>'
    + (m.length ? m.map(x => '<div style="margin:.3rem 0">' + sovEchapper(x.nom) + ' — ' + sovEchapper(typeof intitulePoste === 'function' ? intitulePoste(x.poste, 'soviet') : x.poste) + ' '
        + (x.autocritique_faite ? '<span class="cpj-note">(déjà cette semaine)</span>'
           : vehBouton('Exiger une autocritique', "sovPouvoirActe('autocritique',{ministre:" + sovJsArg(x.nom) + "},'Autocritique publique',v=>v.ministre+' fait son autocritique dans la presse.',ouvrirSovarkaAutocritique)", true))
        + '</div>').join('') : '<p>Aucun ministre en exercice.</p>'));
}

// ---------------------------------------------------------------- Sécurité du Peuple : surveillance d'un citoyen
// Décisions de Fred (08/11/2026) : 4 jours, 2 PA, 150 PSK sur la caisse du ministère ; rapport garanti chaque
// matin (déplacements et PJ croisés) ; découverte possible (perception, intelligence, sécurité de la ville) ;
// toute cible ; trois au plus. Tout est décidé par sovarka_surveillance_commande / _lire ; l'écran recopie.
function sovLieuSurveillance(e) {
  if (e.hors_territoire) return 'Hors du territoire';
  const ville = (typeof villeNom === 'function' && villeNom('soviet', e.ville)) || e.ville || '?';
  if (!e.batiment || String(e.batiment).startsWith('rue')) return ville + ', dans la rue';
  const ctx = (typeof WORLD !== 'undefined' && WORLD.soviet?.[e.ville]?.buildingContext?.[e.batiment]) || null;
  const def = (typeof BUILDINGS !== 'undefined' && BUILDINGS[e.batiment]) || null;
  const bat = ctx?.name || def?.name || e.batiment;
  const piece = ctx?.rooms?.[e.piece]?.name || def?.rooms?.[e.piece]?.name || '';
  return ville + ', ' + bat + (piece && piece !== bat ? ' — ' + piece : '');
}
async function ouvrirSovarkaSurveillance() {
  const l = await sbRpcVerdict('sovarka_surveillance_lire', {}).catch(() => null);
  if (!l || l.ok !== true) { vehModal('Placer sous surveillance', '<p>' + sovPMotif(l) + '</p>'); return; }
  const toutes = l.surveillances || [];
  const actives = toutes.filter(x => x.statut === 'active');
  const enCours = new Set(actives.map(x => x.cible));
  const max = l.max || 3;
  const heure = t => new Date(t).toLocaleString('fr-FR', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' });
  const rapport = r => '<div style="margin:.3rem 0 .6rem .6rem">' + ((r.deplacements || []).length
      ? r.deplacements.map(e => '<div>' + heure(e.debut) + ' — ' + sovEchapper(sovLieuSurveillance(e))
          + ((e.croises || []).length ? ' <span class="cpj-note">— en présence de ' + e.croises.map(sovEchapper).join(', ') + '</span>' : '') + '</div>').join('')
      : '<div class="cpj-note">Aucun déplacement enregistré.</div>') + '</div>';
  const libres = (l.cibles || []).filter(n => !enCours.has(n));
  vehModal('Placer sous surveillance', '<p class="cpj-note">Un citoyen suivi pendant 4 jours : chaque matin, un rapport de tous ses déplacements '
    + 'et des personnes croisées. 2 PA, 150 PSK prélevés sur la caisse du ministère (solde : ' + Math.floor(l.caisse || 0) + ' PSK). '
    + 'La cible peut s’en rendre compte, sans savoir qui la surveille. Trois surveillances au plus.</p>'
    + (actives.length < max && libres.length
      ? '<div style="display:flex;gap:.5rem;align-items:center;margin:.5rem 0"><select id="sov-surv-cible" class="cpj-champ">'
        + libres.map(n => '<option value="' + sovEchapper(n) + '">' + sovEchapper(n) + '</option>').join('') + '</select>'
        + vehBouton('Surveiller', "sovarkaSurveiller(document.getElementById('sov-surv-cible').value)", true) + '</div>'
      : '<p>' + (actives.length >= max ? SOV_POUVOIR_MOTIFS.limite_surveillances : 'Aucune cible disponible.') + '</p>')
    + toutes.map(x => '<div style="margin-top:.6rem"><b>' + sovEchapper(x.cible) + '</b> — '
        + (x.statut === 'active' ? 'en cours, ' + x.rapports_restants + ' rapport(s) à venir' : 'terminée')
        + (x.rapports || []).map(r => '<div class="cpj-note">Rapport du ' + new Date(r.jour).toLocaleDateString('fr-FR') + '</div>' + rapport(r)).join('')
        + '</div>').join(''));
}
async function sovarkaSurveiller(cible) {
  if (sovPouvoirEnCours || !cible) return;
  sovPouvoirEnCours = true;
  let v = null;
  try {
    v = await sbRpcVerdict('sovarka_surveillance_commande', { p_requete: crypto.randomUUID(), p_cible: cible }).catch(() => null);
    if (!v || v.ok !== true) { showToast('Surveillance', sovPMotif(v), false); return; }
    if (typeof appliquerPaiementServeur === 'function') appliquerPaiementServeur({ pa: v.pa, liquide: v.liquide, arg: v.arg });
    if (typeof updateHeader === 'function') updateHeader();
    showToast('Surveillance', v.cible + ' est placé sous surveillance pour 4 jours. Premier rapport demain matin.', true);
  } finally { sovPouvoirEnCours = false; }
  if (v && v.ok === true) ouvrirSovarkaSurveillance();
}
