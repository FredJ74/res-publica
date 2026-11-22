// REGROUPEMENT DES ORDRES DANS LES PIÈCES (Fred, 22/11/2026, soir ; GAME-DESIGN-INTERFACE-ACCUEIL-20261122.md, partie C,
// points 18 à 21). Présentation seulement : aucun ordre, aucun coût, aucune garde, aucune RPC ne change. Chaque ordre
// regroupé garde SON bouton d'origine, calculé par renderRoomActions (plateau-politique.js) avec ses gardes, son grisage,
// son infobulle et son appel doOrder(fn…) : la fenêtre du groupe ne fait que le remonter, avec une phrase d'explication.
//
//   18. Accueil des mairies (tous pays) : « Élections » (calendrier électoral, organigramme) et « Guichet » (démarches
//       administratives, une phrase chacune). « Héros du Travail » reste à part.
//   19. Salle des partis : « Les partis » (partis constitués et demande d'adhésion ; « Créer un parti » pour qui n'a pas de
//       parti ; « Mon parti » et « Extrait d'enregistrement » pour un membre) et « Dénonciations » (poster, registre).
//   20. Bureau du syndicat : « Le syndicat » (consulter pour tous ; adhérer pour un non-membre ; quitter et déclencher une
//       élection pour un membre) et « Fonctions du chef du syndicat ».
//   21. Bureau de chaque fonction : un seul bouton « Fonctions de [poste] » regroupe les ordres réservés au poste, rangés
//       par thème. Visible par tous : le titulaire agit ; les autres lisent, en lecture seule, une phrase par pouvoir et
//       la mention « Réservé au [poste] ». Le bureau du maire y range aussi « Dossiers commerciaux » (ordre non réservé :
//       son bouton reste actif pour tous, le serveur décide comme avant).
// Jamais regroupés : les ordres du goulag (sovarka_goulag_*, goulag_*), la caserne et le greffe (déjà rangés en menus),
// les rédactions de La Tribune et les terrains (rangements propres dans renderRoomActions).
(function (global) {
'use strict';

const esc = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const etat = () => (typeof state !== 'undefined' && state) ? state : {};
const goulag = fn => /^(sovarka_goulag_|goulag_)/.test(String(fn || ''));

// Textes (français de référence ; clés pour Codex listées dans RELAIS.md).
const TXT = {
  elections: 'Élections',
  electionsIntro: 'Les élections de la ville et du pays, et qui occupe quel poste.',
  guichet: 'Guichet',
  guichetIntro: 'Les démarches administratives de la mairie.',
  partis: 'Les partis',
  partisIntro: 'Les partis de Sovarka : les consulter, demander à adhérer, fonder le vôtre.',
  denonciations: 'Dénonciations',
  denonciationsIntro: 'La boîte aux lettres des partis.',
  syndicat: 'Le syndicat',
  syndicatIntro: 'Le syndicat, ses membres et ses élections.',
  chefSyndicat: 'Fonctions du chef du syndicat',
  fonctionsDe: 'Fonctions {de}{poste}',
  reserveA: 'Réservé {a}{poste}.',
  lectureSeule: 'Vous n’occupez pas ce poste : voici ce qu’il permet. Seul le titulaire peut agir.',
  autres: 'Autres pouvoirs',
  fermer: 'Fermer',
  rien: 'Rien à faire ici pour le moment.'
};
const t = (k, v) => String(TXT[k] || k).replace(/\{(\w+)\}/g, (_, x) => (v && v[x] != null ? v[x] : ''));

// Phrases d'explication propres au regroupement (sinon : première phrase de la description de l'ordre).
const PHRASES = {
  calendrier_elections: 'Les élections en cours et à venir : dates, candidatures et scrutins.',
  consulter_organigramme_mairie: 'Qui occupe quel poste, dans la ville et dans le pays.',
  etat_civil: 'Actes officiels, naturalisation, domicile, mariage.',
  objet_trouve: 'Récupérer un objet perdu, déposé au service des objets trouvés.',
  sovarka_demander_local: 'Demander à la mairie un local pour ouvrir un commerce ; le maire examine les dossiers.',
  souscrire_bon_etat: 'Prêter à l’État pour 7 jours contre un Bon d’État, au rendement fixé à la souscription.',
  sovarka_partis: 'La liste des partis, leur chef et leur siège ; demander à adhérer (2 PA, le chef accepte ou refuse).',
  sovarka_parti_fonder: 'Fonder votre parti, dont le siège sera dans cette ville (2 PA et 15 PSK).',
  sovarka_mon_parti: 'Membres, demandes d’adhésion, droit d’entrée, successeur ; quitter le parti.',
  sovarka_extrait_parti: 'Un extrait officiel daté du parti (réservé au chef : 1 PA et 7 PSK).',
  parti_denoncer: 'Glisser une dénonciation anonyme dans la boîte d’un parti (1 PA).',
  parti_boite_registre: 'Lire les dénonciations reçues par votre parti (chef et camarades désignés).',
  consulter_syndicat_etat: 'Le chef, l’effectif et les membres du syndicat.',
  consulter_organigramme_syndicat: 'Le chef et les membres du syndicat.',
  se_syndiquer_etat: 'Adhérer au syndicat (cotisation unique).',
  se_syndiquer: 'Adhérer au syndicat.',
  quitter_syndicat_etat: 'Rendre votre carte du syndicat.',
  declencher_election_syndicat_etat: 'Élire le chef du syndicat : 3 jours de candidatures, puis 3 jours de vote.',
  declencher_election_syndicat: 'Élire le chef du syndicat : 3 jours de candidatures, puis 3 jours de vote.',
  sovarka_dossiers_commerciaux: 'Les demandes de commerce de la ville : attribuer un local ou refuser.'
};

// Titres des postes (Républia) ; un pays qui a ses propres intitulés (INTITULES_POSTES_PAR_PAYS, data.js) les impose.
const POSTES = {
  president: 'président', pm: 'Premier ministre', min_int: 'ministre de l’Intérieur', min_fin: 'ministre des Finances',
  min_just: 'ministre de la Justice', min_def: 'ministre de la Défense', min_info: 'ministre de l’Information',
  min_ae: 'ministre des Affaires étrangères', maire: 'maire', maire_adjoint: 'maire adjoint', commissaire: 'commissaire',
  juge: 'juge', procureur: 'procureur', ambassadeur_local: 'ambassadeur', directeur_entrepot: 'directeur de l’entrepôt',
  directeur_pharma: 'directeur de l’usine', directeur_tabac_alcools: 'directeur du pôle', directeur_raffinerie: 'directeur de l’usine',
  chef_douanes: 'chef des douanes', capitaine_port: 'commandant du port', chef_syndicat: 'chef du syndicat'
};
function titrePoste(poste) {
  const pays = etat().country;
  const propre = typeof INTITULES_POSTES_PAR_PAYS !== 'undefined' && INTITULES_POSTES_PAR_PAYS[pays] && INTITULES_POSTES_PAR_PAYS[pays][poste];
  const brut = propre || POSTES[poste] || poste;
  return brut.charAt(0).toLowerCase() + brut.slice(1);
}
const voyelle = s => /^[aeiouyhâàéèêîïôûAEIOUYHÉ]/.test(s);
function fonctionsDe(poste) {
  const p = titrePoste(poste);
  return poste === 'chef_syndicat' ? t('chefSyndicat') : t('fonctionsDe', { de: voyelle(p) ? 'de l’' : 'du ', poste: p });
}
function reserveA(poste) { const p = titrePoste(poste); return t('reserveA', { a: voyelle(p) ? 'à l’' : 'au ', poste: p }); }

// Thèmes des « Fonctions de [poste] ». Un ordre réservé absent de ces listes va dans « Autres pouvoirs » : un ordre ajouté
// plus tard n'est jamais perdu.
const THEMES = {
  president: [['Gouvernement et nominations', ['gestion_premier_ministre', 'postes_par_decret']],
    ['Pouvoirs de l’État', ['pouvoirs_exceptionnels', 'effort_national', 'gracier']], ['Parole publique', ['adresse_a_la_nation']]],
  pm: [['Gouvernement', ['nommer_ministre_pm', 'revoquer_ministre_pm', 'declencher_vote_confiance', 'sovarka_autocritique']],
    ['Lois et grâces', ['sovarka_lois_examen', 'sovarka_graces']], ['Surveillance', ['sovarka_signalements']]],
  min_int: [['Ordre public', ['gestion_manifestations', 'sovarka_manifs_gerer', 'gerer_couvre_feu']],
    ['Renseignement et surveillance', ['interieur_dossiers', 'renseignement_militaire', 'sovarka_habilitations', 'sovarka_signalements', 'sovarka_surveiller']],
    ['Nationalité', ['demandes_naturalisation']], ['Budget et services', ['gerer_chef_douanes', 'gerer_budget_interieur', 'subvention_min_int']],
    ['Lois', ['lois_votees_an']]],
  min_fin: [['Fiscalité et budget', ['pilotage_fiscal_budgetaire', 'bne_caisse_prelever', 'subvention']],
    ['Industrie et entreprises', ['gestion_industrielle_portuaire', 'preempter_entreprise']]],
  min_just: [['Enquêtes et affaires', ['ouvrir_enquete', 'sovarka_registre_plaintes', 'sovarka_saisir_juge']],
    ['Grâces et détention', ['proposer_grace', 'gestion_qhs']], ['Juges et budget', ['gerer_juges', 'gerer_budget_justice']]],
  min_def: [['Armée', ['mobilisation_nationale', 'sovarka_conscription', 'gestion_caserne', 'garde_republicaine']],
    ['Renseignement', ['renseignement_militaire', 'sovarka_ecoutes']], ['Paix', ['activer_cessez_le_feu']]],
  min_info: [['Communication', ['propagande_etat', 'dementi']], ['Presse et sondages', ['censurer_media', 'commanditer_sondage', 'sovarka_sondages']]],
  min_ae: [['Diplomatie', ['proposer_treve', 'diplomatie_bilaterale', 'gerer_ambassades']]],
  commissaire: [['Plaintes', ['dossiers_plaintes', 'sovarka_registre_plaintes']],
    ['Enquêtes', ['mener_enquete', 'organiser_filature', 'organiser_chasse_homme']],
    ['Effectifs et interventions', ['gerer_effectifs_police', 'recruter_policier', 'recruter_policier_cynophile', 'mobiliser_police']]],
  juge: [['Audiences et jugements', ['audience_juge', 'rendre_sentence']],
    ['Actes et saisines', ['acte_officiel_juge', 'sovarka_retirer_droit', 'sovarka_ordres_ministre']], ['Vie du tribunal', ['sovarka_offrir_cafe']]],
  procureur: [['Parquet', ['parquet']]],
  maire: [['Finances de la ville', ['fixer_impots_locaux', 'repartition_budget_local', 'subvention_proposer']],
    ['Sécurité', ['campagne_securite']], ['Nominations', ['nominations_municipales']], ['Commerces', ['sovarka_dossiers_commerciaux']]],
  maire_adjoint: [['Urbanisme', ['traiter_demandes_permis', 'consulter_dossiers_urbanisme']], ['Logement social', ['traiter_demandes_logement_social']],
    ['Administration', ['acte_officiel_mairie', 'regulation_production', 'financer_communal']]],
  ambassadeur_local: [['Diplomatie', ['relations_bilaterales', 'organiser_reception_diplomatique', 'financer_oeuvre_culturelle', 'demander_transfert_detenu']]],
  directeur_entrepot: [['Entrepôt', ['tableau_bord_entrepot', 'fixer_prix_achat_entrepot']]],
  directeur_pharma: [['Production et ventes', ['fixer_prix_vente_directe', 'fixer_repartition_production']], ['Caisse', ['virement_usine_ministere']]],
  directeur_tabac_alcools: [['Production et ventes', ['fixer_prix_vente_directe', 'fixer_repartition_production']], ['Caisse', ['virement_usine_ministere']]],
  directeur_raffinerie: [['Production et ventes', ['fixer_prix_vente_directe', 'fixer_repartition_production']], ['Caisse', ['virement_usine_ministere']]],
  chef_douanes: [['Effectifs', ['recruter_douanier', 'recruter_douanier_cynophile', 'gerer_effectifs_douane']], ['Contrôles', ['controler_caisse_douane']]],
  capitaine_port: [['Logistique', ['gerer_logistique_port']]],
  chef_syndicat: [['Mobilisation', ['manifestation_soutien_president', 'organiser_manifestation_syndicat', 'blocus_portuaire']]]
};
// Ordres non réservés rangés dans les fonctions d'un poste (point 21 : « Dossiers commerciaux » chez le maire).
const ATTACHES = { maire: ['sovarka_dossiers_commerciaux'] };

// Bureaux des fonctions : pièces où les ordres réservés sont regroupés par poste.
const BUREAUX = new Set(['bureau_president', 'bureau_min_int', 'bureau_min_fin', 'bureau_min_just', 'bureau_min_def', 'bureau_min_info',
  'bureau_min_ae', 'bureau_commissaire', 'bureau_magistrats', 'bureau_maire', 'bureau_maire_local', 'bureau_maire_adjoint',
  'bureau_al_khalija', 'bureau_sovarka', 'bureau_el_estado', 'bureau_direction', 'direction_usine', 'douanes', 'administration_portuaire',
  'bureau_syndicat_national', 'bureau_syndical_dockers']);
function estBureau(buildingId, roomId) {
  if (buildingId === 'palais-gouvernement' && roomId === 'bureaux') return true;   // bureau du Premier ministre
  return BUREAUX.has(roomId);
}

// Poste auquel un ordre est réservé dans cette pièce (null : ordre ouvert à tous).
function posteReserve(o, principal) {
  if (!o) return null;
  if (o.requiresChefSyndicatEtat || o.requiresChefSyndicatDockers) return 'chef_syndicat';
  const rp = o.requiresPost;
  if (typeof rp === 'string' && rp) return rp;
  if (Array.isArray(rp) && rp.length) return rp.includes(principal) ? principal : rp[0];
  return null;
}

// ─────────────────────────────────────────────────────────────────────────────────────────────────────────────────
// HABILITATION : POINT UNIQUE. « Le joueur est-il titulaire de ce poste, ici ? »
// Ce module ne recalcule JAMAIS l'habilitation. Il lit le verdict que la règle existante du plateau a déjà rendu pour
// les ordres réservés de la pièce : le grisage de renderRoomActions (requiresPost : needsPost, pays du mandat inclus via
// paysMandatPourOrdre ; chef du syndicat : requiresChefSyndicatEtat / requiresChefSyndicatDockers). Un ordre réservé
// rendu sans la classe « blocked » = le joueur peut agir = il est titulaire.
// Fusion avec le lot « postes par pays » (postes_attribues filtré par pays) : la correction faite dans la règle du
// plateau s'applique ici d'elle-même ; si ce lot expose une fonction d'habilitation, c'est la seule ligne à changer.
// ─────────────────────────────────────────────────────────────────────────────────────────────────────────────────
let verdicts = {};
function estTitulaireFonction(poste) {
  return verdicts[poste] === true;
}
const htmlBloque = html => /class="action-btn[^"]*\bblocked\b/.test(String(html || ''));

// Groupes « liste » (points 18 à 20) : membres affichés dans l'ordre, avec visibilité selon l'appartenance.
const membre = (fn, visible) => ({ fn, visible });
function groupesListe(buildingId, roomId) {
  if ((buildingId === 'mairie-capitale' && roomId === 'hall_mairie') || (buildingId === 'mairie' && roomId === 'accueil_mairie')) {
    return [
      { id: 'elections', titre: t('elections'), icone: 'ti-calendar-event', intro: t('electionsIntro'),
        membres: [membre('calendrier_elections'), membre('consulter_organigramme_mairie')] },
      { id: 'guichet', titre: t('guichet'), icone: 'ti-building-community', intro: t('guichetIntro'),
        membres: [membre('etat_civil'), membre('objet_trouve'), membre('sovarka_demander_local'), membre('souscrire_bon_etat'),
          membre('acte_officiel'), membre('demander_logement_social')] }
    ];
  }
  if (roomId === 'salle_partis') {
    return [
      { id: 'partis', titre: t('partis'), icone: 'ti-flag', intro: t('partisIntro'), charger: chargerParti,
        membres: [membre('sovarka_partis'), membre('sovarka_parti_fonder', c => !c || !c.membre),
          membre('sovarka_mon_parti', c => !c || c.membre), membre('sovarka_extrait_parti', c => !c || c.membre)] },
      { id: 'denonciations', titre: t('denonciations'), icone: 'ti-mail-opened', intro: t('denonciationsIntro'),
        membres: [membre('parti_denoncer'), membre('parti_boite_registre')] }
    ];
  }
  if (roomId === 'bureau_syndicat_national') {
    return [{ id: 'syndicat', titre: t('syndicat'), icone: 'ti-users-group', intro: t('syndicatIntro'), charger: chargerSyndicatNational,
      membres: [membre('consulter_syndicat_etat'), membre('se_syndiquer_etat', c => !c || !c.membre),
        membre('quitter_syndicat_etat', c => !c || c.membre), membre('declencher_election_syndicat_etat', c => !c || c.membre)] }];
  }
  if (roomId === 'bureau_syndical_dockers') {
    return [{ id: 'syndicat', titre: t('syndicat'), icone: 'ti-users-group', intro: t('syndicatIntro'), charger: chargerSyndicatDockers,
      membres: [membre('consulter_organigramme_syndicat'), membre('se_syndiquer', c => !c || !c.membre),
        membre('declencher_election_syndicat', c => !c || c.membre)] }];
  }
  return [];
}
// Appartenance : lue au serveur ou dans le cache des organisations à l'ouverture de la fenêtre. Inconnue (lecture en
// échec) : tous les volets restent visibles et le serveur tranche, comme avant.
async function chargerParti() {
  if (typeof partiCharger !== 'function') return null;
  const v = await partiCharger();
  return v ? { membre: !!v.mon_parti } : null;
}
const nomMoi = () => etat().char && etat().char.name;
const estDans = o => !!(o && Array.isArray(o.membres) && o.membres.some(m => (m && (m.nom || m)) === nomMoi()));
async function chargerSyndicatNational() {
  let o = typeof getSyndicatEtat === 'function' ? getSyndicatEtat() : null;
  if (!o && typeof chargerOrganisations === 'function') { try { await chargerOrganisations(); } catch (_) { /* repli : tout visible */ } o = typeof getSyndicatEtat === 'function' ? getSyndicatEtat() : null; }
  return o ? { membre: estDans(o) } : null;
}
async function chargerSyndicatDockers() {
  const o = typeof getSyndicatDockersPSM === 'function' ? getSyndicatDockersPSM() : null;
  return o ? { membre: estDans(o) } : null;
}

// ─────────────────────────────────────────────────────────────────────────────────────────────────────────────────
// Regroupement d'une pièce. entrees : [{ o, html }] dans l'ordre d'affichage (o = l'ordre déclaré, html = son bouton
// rendu). Rend la nouvelle liste de boutons, ou null quand rien n'est regroupé (la pièce reste exactement comme avant).
// ─────────────────────────────────────────────────────────────────────────────────────────────────────────────────
let groupes = [];
function regrouperOrdresPiece(entrees, buildingId, roomId) {
  groupes = []; verdicts = {};
  if (!Array.isArray(entrees) || !entrees.length) return null;
  const s = etat();
  const parFn = new Map(entrees.map(e => [e.o && e.o.fn, e]));
  const pris = new Map();   // fn → index du groupe
  // Points 18 à 20.
  groupesListe(buildingId, roomId).forEach(g => {
    const presents = g.membres.filter(m => parFn.has(m.fn) && !goulag(m.fn));
    if (!presents.length) return;
    const index = groupes.length;
    groupes.push({ type: 'liste', titre: g.titre, icone: g.icone, intro: g.intro, charger: g.charger, membres: presents.map(m => ({ visible: m.visible, entree: parFn.get(m.fn) })),
      cle: [s.country, s.currentCity, buildingId, roomId].join('|') });
    presents.forEach(m => pris.set(m.fn, index));
  });
  // Point 21 : un bouton par poste dans le bureau d'une fonction.
  if (estBureau(buildingId, roomId)) {
    const compte = {};
    entrees.forEach(e => { const p = e.o && typeof e.o.requiresPost === 'string' ? e.o.requiresPost : null; if (p) compte[p] = (compte[p] || 0) + 1; });
    const principal = Object.keys(compte).sort((a, b) => compte[b] - compte[a])[0] || null;
    const parPoste = new Map();
    entrees.forEach(e => {
      const fn = e.o && e.o.fn;
      if (!fn || pris.has(fn) || goulag(fn)) return;
      const p = posteReserve(e.o, principal);
      if (!p) return;
      if (!parPoste.has(p)) parPoste.set(p, []);
      parPoste.get(p).push(e);
      // Habilitation lue sur le bouton rendu par la règle existante (voir estTitulaireFonction).
      if (!htmlBloque(e.html)) verdicts[p] = true; else if (verdicts[p] !== true) verdicts[p] = false;
    });
    parPoste.forEach((liste, poste) => {
      (ATTACHES[poste] || []).forEach(fn => { const e = parFn.get(fn); if (e && !pris.has(fn) && !liste.includes(e)) liste.push(e); });
      const index = groupes.length;
      groupes.push({ type: 'fonctions', poste, titre: fonctionsDe(poste), icone: 'ti-briefcase', membres: liste.map(e => ({ entree: e, reserve: !!posteReserve(e.o, principal) })),
        cle: [s.country, s.currentCity, buildingId, roomId].join('|') });
      liste.forEach(e => pris.set(e.o.fn, index));
    });
  }
  if (!groupes.length) return null;
  // Chaque groupe prend la place de son premier membre ; les autres ordres gardent leur place.
  const emis = new Set(), sortie = [];
  entrees.forEach(e => {
    const fn = e.o && e.o.fn;
    if (!pris.has(fn)) { sortie.push(e.html); return; }
    const i = pris.get(fn);
    if (emis.has(i)) return;
    emis.add(i);
    const g = groupes[i];
    sortie.push('<button type="button" class="action-btn legal" data-regroupe="' + i + '" onclick="ouvrirOrdresRegroupes(' + i + ')" title="' + esc(g.titre) + '">' +
      '<i class="ti ' + g.icone + '" style="font-size:.82rem"></i> ' + esc(g.titre) + ' <span class="pa-cost">▾</span></button>');
  });
  return sortie;
}

// Première phrase de la description, sans la mention « Réservé au… » (ajoutée à part).
function phrase(o) {
  if (PHRASES[o.fn]) return PHRASES[o.fn];
  let d = String(o.desc || '').trim().replace(/^R[ée]serv[ée]e?s? (?:au|aux|à|a) [^.:]*[.:]\s*/i, '');
  const m = d.match(/^(.+?[.!?])(\s|$)/);
  d = m ? m[1] : d;
  return d ? d.charAt(0).toUpperCase() + d.slice(1) : '';
}
const ligne = contenu => '<div class="hg-regroupe-ligne" style="padding:.7rem;border:1px solid #5b4825;border-radius:8px">' + contenu + '</div>';
const libelle = o => (typeof deviseDansTexte === 'function' && typeof COUNTRIES !== 'undefined')
  ? deviseDansTexte(o.label, (COUNTRIES[etat().country] || {}).cur || 'FR') : o.label;

let ouvertureEnCours = 0;
async function ouvrirOrdresRegroupes(index) {
  const g = groupes[index];
  const s = etat();
  if (!g || g.cle !== [s.country, s.currentCity, s.currentBuilding, s.currentRoom].join('|')) return;
  const titre = document.getElementById('postes-modal-title'), corps = document.getElementById('postes-body'), modal = document.getElementById('modal-postes');
  if (!titre || !corps || !modal) return;
  const jeton = ++ouvertureEnCours;
  let html = '';
  if (g.type === 'liste') {
    let ctx = null;
    if (typeof g.charger === 'function') { try { ctx = await g.charger(); } catch (_) { ctx = null; } }
    if (jeton !== ouvertureEnCours) return;
    const visibles = g.membres.filter(m => !m.visible || m.visible(ctx));
    html += '<p class="cpj-note">' + esc(g.intro) + '</p>';
    html += visibles.map(m => ligne('<p style="margin:0 0 .45rem">' + esc(phrase(m.entree.o)) + '</p>' + m.entree.html)).join('') || '<p>' + t('rien') + '</p>';
  } else {
    const titulaire = estTitulaireFonction(g.poste);
    if (!titulaire) html += '<p class="cpj-note">' + esc(t('lectureSeule')) + '</p>';
    const themes = (THEMES[g.poste] || []).map(([nom, fns]) => ({ nom, fns }));
    const places = new Set();
    const sections = themes.map(th => ({ nom: th.nom, membres: g.membres.filter(m => th.fns.includes(m.entree.o.fn) && !places.has(m.entree.o.fn) && places.add(m.entree.o.fn)) }));
    const reste = g.membres.filter(m => !places.has(m.entree.o.fn));
    if (reste.length) sections.push({ nom: t('autres'), membres: reste });
    html += sections.filter(x => x.membres.length).map(x => '<div class="cpj-titre" style="margin-top:.6rem">' + esc(x.nom) + '</div>' +
      '<div style="display:grid;gap:.6rem">' + x.membres.map(m => {
        const o = m.entree.o;
        if (titulaire || !m.reserve) return ligne('<p style="margin:0 0 .45rem">' + esc(phrase(o)) + '</p>' + m.entree.html);
        return ligne('<strong>' + esc(libelle(o)) + '</strong><p style="margin:.3rem 0">' + esc(phrase(o)) + '</p>' +
          '<p class="cpj-note hg-reserve" style="margin:0">' + esc(reserveA(g.poste)) + '</p>');
      }).join('') + '</div>').join('');
  }
  titre.textContent = g.titre;
  corps.innerHTML = '<div class="hg-regroupe" style="display:grid;gap:.6rem;padding:1rem;max-height:68vh;overflow-y:auto">' + html +
    '<div style="margin-top:.4rem"><button type="button" class="cpj-touche" onclick="document.getElementById(\'modal-postes\').classList.remove(\'open\')">' + esc(t('fermer')) + '</button></div></div>';
  modal.classList.add('open');
  global.RPOrderI18n?.bindVisibleLabels?.(corps);
  global.RPOrderI18n?.refreshVisibleLabels?.(corps, global.i18next, global.RPPlateauI18n?.language?.() || 'fr');
}

Object.assign(global, {
  RPOrdresRegroupes: { textes: TXT, phrases: PHRASES, themes: THEMES, groupes: () => groupes, estBureau, posteReserve, titrePoste },
  regrouperOrdresPiece, ouvrirOrdresRegroupes, estTitulaireFonction
});
})(typeof window !== 'undefined' ? window : globalThis);
