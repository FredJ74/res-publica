'use strict';
// Criminalité, lot 10 : envoi au QHS (GAME-DESIGN-CRIMINALITE.md § 16).
// Trois niveaux, sans se faire passer l'un pour l'autre :
//  1. relevé des valeurs RENDUES PAR LA PRODUCTION lors de l'essai annulé du 20/11/2026 (Arnie fait Ministre de la Justice de
//     Républia, Vince Kubrick Premier ministre et de nationalité sovarkienne domicilié en Républia, Angie Porcelana domiciliée en
//     Sovarka, détentions d'essai de Bartesto Chevara et de Ben ; tout annulé par RAISE EXCEPTION), recopié ci-dessous et
//     confronté aux règles recalculées ici ;
//  2. lecture de la migration (table, fonctions, raccords qui retirent tout envoi automatique hors Sovarka) ;
//  3. écran : plateau-criminalite.js chargé dans une machine virtuelle (affichage seul, cpj-*, aucun calcul ni Math.random),
//     boutons des courriers (forum.js), textes du juge et de la subtilisation militaire.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const racine = path.join(__dirname, '../..');
const lire = (f) => fs.readFileSync(path.join(racine, f), 'utf8');
const sql = lire('migrations/20261120110000_crim_lot10_qhs.sql');
const js = lire('plateau-criminalite.js');
const forum = lire('forum.js');
const justice = lire('plateau-justice-economie.js');
const rumeurs = lire('plateau-actions-illegales-rumeurs.js');
const politique = lire('plateau-politique.js');

// Règles du § 16, recalculées.
const trunc = Math.trunc;
const partOui = (sec, mor, pop) => Math.min(90, Math.max(10, 50 + trunc((50 - sec) / 2) + trunc((50 - mor) / 4) - trunc((pop - 50) / 2)));
const pnjOui = (part) => Math.round(part * 10 / 100);
const depouiller = (pjOui, pjNon, sec, mor, pop) => {
  const part = partOui(sec, mor, pop), o = pnjOui(part);
  const oui = pjOui + o, non = pjNon + (10 - o);
  return { part_oui_pnj: part, pnj_oui: o, pnj_non: 10 - o, oui, non, resultat: oui > non ? 'oui' : 'non' };
};
const penalite = (gouv, decideur, facteur) => gouv.map((nom) => ({ nom, perte: (nom === decideur ? 10 : 5) * facteur }));

// Relevé de l'essai en production (transaction annulée, 20/11/2026).
const RELEVE = {
  decideur: { nom: 'Arnie', role: 'min_just' }, gouv: ['Angie Porcelana', 'Arnie', 'Jean Jaaj', 'Vince Kubrick'],
  indices: { securite: 30, moral: 50 }, bornes: [90, 10, 80, 50, 50], voix: [6, 1, 9, 5], militaire_jours: 2,
  A_lire: { dec: true, role: 'min_just', n_detenus: 1 },
  A: { ok: true, qhs: true, meme_det: true, ville: 'qhs',
       membres: [{ nom: 'Angie Porcelana', perte: 5 }, { nom: 'Arnie', perte: 10 }, { nom: 'Jean Jaaj', perte: 5 }, { nom: 'Vince Kubrick', perte: 5 }],
       pops: { Arnie: 40, 'Jean Jaaj': 45, 'Vince Kubrick': 45, 'Angie Porcelana': 45, 'Moustafa Kheimal': 50 },
       rumeur: { cible: 'Arnie', auteur: 'Anonyme', popPerdu: 10, contenu: 'Le Ministre de la Justice aurait fait envoyer Bartesto Chevara au QHS sans consulter personne.' } },
  sortie: { emp: null, flag: { enQHS: false, paLimite1Jour: false }, pos: 'capitale/centre-multinodal-luthecia', registre: 'libere', sortait_du_qhs: true, retour_ville: 'capitale' },
  B_ouvre: { ok: true, electeurs: 6 }, B_mails: 6, B_votes: [null, 'non_domicilie', null, 'deja_vote', null], B_decider_pendant: 'referendum_en_cours',
  B: { statut: 'envoye', decision: 'referendum_oui', pen: null,
       dep: { pj_oui: 2, pj_non: 1, part_oui_pnj: 80, pnj_oui: 8, pnj_non: 2, oui: 10, non: 3, resultat: 'oui', pop_detenu: 10 } },
  B_qhs: true, B_pops: { Arnie: 50, 'Jean Jaaj': 50, 'Vince Kubrick': 50, 'Angie Porcelana': 50, 'Moustafa Kheimal': 50 },
  C_statut: 'referendum_non', C_dep: { pj_oui: 1, pj_non: 2, part_oui_pnj: 40, pnj_oui: 4, pnj_non: 6, oui: 5, non: 8, resultat: 'non', pop_detenu: 90 },
  C: { ok: true, statut: 'refuse/respecter', qhs: false },
  D: { ok: true, qhs: true, rumeur: 20,
       avant: { Arnie: 50, 'Jean Jaaj': 50, 'Vince Kubrick': 50, 'Angie Porcelana': 50, 'Moustafa Kheimal': 50 },
       apres: { Arnie: 30, 'Jean Jaaj': 40, 'Vince Kubrick': 40, 'Angie Porcelana': 40, 'Moustafa Kheimal': 50 } },
  E: { statut: 'referendum_non', dep: { pj_oui: 1, pj_non: 1, part_oui_pnj: 50, pnj_oui: 5, pnj_non: 5, oui: 6, non: 6, resultat: 'non', pop_detenu: 70 } },
  E_qhs: false,
  F_arnie: 'reserve_decideur', F_decideur: { nom: 'Vince Kubrick', role: 'pm' },
  F: { ok: true, membres: [{ nom: 'Angie Porcelana', perte: 5 }, { nom: 'Jean Jaaj', perte: 5 }, { nom: 'Vince Kubrick', perte: 10 }],
       pops: { Arnie: 50, 'Jean Jaaj': 45, 'Vince Kubrick': 40, 'Angie Porcelana': 45, 'Moustafa Kheimal': 50 },
       rumeur: 'Le Premier ministre aurait fait envoyer Bartesto Chevara au QHS sans consulter personne.' },
  G_attente: 'en_attente', G_mail_pm: 1, G_passe: 'refuse/refus_automatique', G_creation: 'refuse/refus_automatique', G_mail_juge: 1,
  H_decider: 'sovarka_goulag', H_creer: null, H_calc_sov: { min: 30, max: 30, impose: true }, H_calc_rep: { min: 1, max: 2, impose: false, prop: true },
  H_juge_rep: { ok: true, qhs: false }, H_juge_sov: { ok: true, qhs: true },
  poseurs: ['arrestation_flagrant_interne', 'crim_qhs_transferer_interne', 'detention_ouvrir_soi', 'detention_prolonger_interne', 'detention_transferer_qhs']
};

test('Bloc PNJ : formule, troncature et bornes 10-90 ; 10 voix arrondies au plus proche', () => {
  assert.deepEqual(RELEVE.bornes, [partOui(0, 0, 0), partOui(100, 100, 100), partOui(30, 50, 10), partOui(30, 50, 70), partOui(49, 47, 51)]);
  assert.equal(partOui(0, 0, 0), 90); assert.equal(partOui(100, 100, 100), 10);
  assert.deepEqual(RELEVE.voix, [pnjOui(55), pnjOui(10), pnjOui(90), pnjOui(54)]);
  assert.match(sql, /50 \+ trunc\(\(50 - coalesce\(p_securite, 50\)\) \/ 2\) \+ trunc\(\(50 - coalesce\(p_moral, 50\)\) \/ 4\)\s*- trunc\(\(coalesce\(p_pop, 50\) - 50\) \/ 2\)/);
  assert.match(sql, /'qhs_pnj_part_min', 10\), \('qhs_pnj_part_max', 90\)/);
  // Indices du pays : ligne nationale, sinon moyenne des villes (Républia : ISN 30, moral 50 sur ses trois villes).
  assert.deepEqual(RELEVE.indices, { securite: 30, moral: 50 });
  assert.match(sql, /i\.id = p_pays \|\| '_national'[\s\S]*JOIN public\.villes w ON w\.pays = p_pays/);
});

test('Envoi direct : même détention (reste de la peine), −10 au Ministre, −5 par membre, rumeur sur le modèle de la torture', () => {
  assert.deepEqual(RELEVE.decideur, { nom: 'Arnie', role: 'min_just' });
  assert.deepEqual(RELEVE.A_lire, { dec: true, role: 'min_just', n_detenus: 1 });
  assert.equal(RELEVE.A.ok, true); assert.equal(RELEVE.A.qhs, true); assert.equal(RELEVE.A.meme_det, true, 'aucune nouvelle peine');
  assert.equal(RELEVE.A.ville, 'qhs');
  assert.deepEqual(RELEVE.A.membres, penalite(RELEVE.gouv, 'Arnie', 1));
  for (const m of RELEVE.A.membres) assert.equal(RELEVE.A.pops[m.nom], 50 - m.perte);
  assert.equal(RELEVE.A.pops['Moustafa Kheimal'], 50, 'le Président ne fait pas partie du gouvernement');
  assert.equal(RELEVE.A.rumeur.popPerdu, 10); assert.equal(RELEVE.A.rumeur.auteur, 'Anonyme'); assert.equal(RELEVE.A.rumeur.cible, 'Arnie');
  assert.match(sql, /INSERT INTO public\.rumeurs_actives \(id, resolu, data\)[\s\S]*'popPerdu', v_m/);
});

test('Sortie à la fin de la peine : libre, drapeau QHS levé, registre libéré, retour à la ville de la détention', () => {
  assert.equal(RELEVE.sortie.emp, null);
  assert.deepEqual(RELEVE.sortie.flag, { enQHS: false, paLimite1Jour: false });
  assert.equal(RELEVE.sortie.registre, 'libere');
  assert.equal(RELEVE.sortie.sortait_du_qhs, true);
  assert.equal(RELEVE.sortie.pos, 'capitale/centre-multinodal-luthecia');
  assert.match(sql, /jsonb_build_object\('retourVille', v_det\.city\)/);
});

test('Référendum gagné : électeurs domiciliés (étranger domicilié inclus, expatrié exclu), une voix, envoi sans pénalité', () => {
  assert.equal(RELEVE.B_ouvre.electeurs, 6); assert.equal(RELEVE.B_mails, 6, 'un courrier par domicilié');
  assert.deepEqual(RELEVE.B_votes, [null, 'non_domicilie', null, 'deja_vote', null]);
  assert.equal(RELEVE.B_decider_pendant, 'referendum_en_cours');
  const d = RELEVE.B.dep;
  assert.deepEqual({ ...depouiller(d.pj_oui, d.pj_non, 30, 50, d.pop_detenu) }, { part_oui_pnj: 80, pnj_oui: 8, pnj_non: 2, oui: 10, non: 3, resultat: 'oui' });
  assert.equal(RELEVE.B.statut, 'envoye'); assert.equal(RELEVE.B.decision, 'referendum_oui'); assert.equal(RELEVE.B.pen, null);
  assert.equal(RELEVE.B_qhs, true);
  for (const v of Object.values(RELEVE.B_pops)) assert.equal(v, 50, 'aucune pénalité');
  assert.match(sql, /WHERE user_id IS NOT NULL AND domicile ->> 'country' = d\.pays/);
  assert.match(sql, /make_interval\(hours => public\.crim_param_interne\('qhs_referendum_heures', 24\)/);
});

test('Référendum perdu puis respecté : le détenu reste en cellule ordinaire, aucune pénalité', () => {
  const d = RELEVE.C_dep;
  const r = depouiller(d.pj_oui, d.pj_non, 30, 50, d.pop_detenu);
  assert.equal(r.part_oui_pnj, 40); assert.equal(r.oui, 5); assert.equal(r.non, 8); assert.equal(r.resultat, 'non');
  assert.equal(RELEVE.C_statut, 'referendum_non');
  assert.equal(RELEVE.C.statut, 'refuse/respecter'); assert.equal(RELEVE.C.qhs, false);
});

test('Référendum perdu puis passé outre : pénalité doublée (−20 au Ministre, −10 par membre), rumeur de 20', () => {
  assert.equal(RELEVE.D.qhs, true);
  for (const m of penalite(RELEVE.gouv, 'Arnie', 2)) assert.equal(RELEVE.D.apres[m.nom], RELEVE.D.avant[m.nom] - m.perte);
  assert.equal(RELEVE.D.apres['Moustafa Kheimal'], 50);
  assert.equal(RELEVE.D.rumeur, 20);
  assert.match(sql, /crim_qhs_penaliser_interne\(v_pays, v_dec, 2, d\.detenu\)/);
});

test('Égalité : le non l’emporte', () => {
  const d = RELEVE.E.dep;
  const r = depouiller(d.pj_oui, d.pj_non, 30, 50, d.pop_detenu);
  assert.equal(r.oui, r.non); assert.equal(r.resultat, 'non');
  assert.equal(RELEVE.E.statut, 'referendum_non'); assert.equal(RELEVE.E_qhs, false);
  assert.match(sql, /CASE WHEN v_oui > v_non THEN 'oui' ELSE 'non' END/);
});

test('Suppléance : Ministre vacant ou PNJ → le Premier ministre décide (−10 pour lui), le Ministre sortant n’a plus la main', () => {
  assert.equal(RELEVE.F_arnie, 'reserve_decideur');
  assert.deepEqual(RELEVE.F_decideur, { nom: 'Vince Kubrick', role: 'pm' });
  assert.deepEqual(RELEVE.F.membres, penalite(['Angie Porcelana', 'Jean Jaaj', 'Vince Kubrick'], 'Vince Kubrick', 1));
  assert.equal(RELEVE.F.pops.Arnie, 50);
  assert.match(RELEVE.F.rumeur, /^Le Premier ministre aurait fait envoyer/);
  assert.match(sql, /'min_just'\);\s*IF v IS NOT NULL THEN RETURN jsonb_build_object\('nom', v, 'role', 'min_just'\); END IF;\s*v := public\.crim_qhs_titulaire_interne\(p_pays, 'pm'\)/);
  assert.match(sql, /WHERE p\.user_id IS NOT NULL AND p\.poste ->> 'id' = p_poste/, 'un PNJ (sans fiche jouée) ne décide pas');
});

test('Sans Premier ministre : refus automatique, à la création comme pour une demande en attente', () => {
  assert.equal(RELEVE.G_attente, 'en_attente'); assert.equal(RELEVE.G_mail_pm, 1, 'courrier au décideur avec le bouton');
  assert.equal(RELEVE.G_passe, 'refuse/refus_automatique');
  assert.equal(RELEVE.G_creation, 'refuse/refus_automatique'); assert.equal(RELEVE.G_mail_juge, 1);
});

test('Sovarka : ni pénalité ni référendum ; règles d’envoi existantes inchangées (juge QHS 30 jours)', () => {
  assert.equal(RELEVE.H_decider, 'sovarka_goulag'); assert.equal(RELEVE.H_creer, null);
  assert.deepEqual(RELEVE.H_calc_sov, { min: 30, max: 30, impose: true });
  assert.deepEqual(RELEVE.H_juge_sov, { ok: true, qhs: true });
});

test('Plus aucun envoi automatique hors Sovarka', () => {
  // Le juge propose : prison au barème (±50 %), demande au Ministre, plus de QHS posé.
  assert.deepEqual(RELEVE.H_calc_rep, { min: 1, max: 2, impose: false, prop: true });
  assert.deepEqual(RELEVE.H_juge_rep, { ok: true, qhs: false });
  assert.match(sql, /crim_qhs_proposition_v1 \*\/\s*PERFORM public\.crim_qhs_demande_creer_interne\(v_pays, v_a ->> 'cible', 'juge'/);
  // Toutes les fonctions qui posent encore le QHS sont gardées (Sovarka seulement) ou passent par la décision.
  assert.deepEqual(RELEVE.poseurs, ['arrestation_flagrant_interne', 'crim_qhs_transferer_interne', 'detention_ouvrir_soi', 'detention_prolonger_interne', 'detention_transferer_qhs']);
  for (const m of ['crim_qhs_juge_v1', 'crim_qhs_soi_v1', 'crim_qhs_soi_v2', 'crim_qhs_transfert_v1', 'crim_qhs_militaire_v1', 'crim_qhs_regime_v1', 'crim_qhs_regime_v2',
    'crim_qhs_libelle_v1', 'crim_qhs_libelle_appel_v1']) assert.ok(sql.includes("'" + m + "'"), m);
  assert.match(sql, /RETURN jsonb_build_object\('ok',false,'raison','qhs_decision_ministre'\)/, 'durée libre de 1 jour à 10 ans retirée');
  assert.equal(RELEVE.militaire_jours, 2, 'subtilisation militaire : détention ordinaire au barème');
  assert.match(sql, /CASE WHEN v_pj\.country = 'soviet' THEN 3 ELSE public\.crim_peine_jours_interne\('vol_materiel_militaire', v_pj\.country\) END,\s*v_pj\.country = 'soviet'/);
});

test('Lot 7 préservé : qhs_pouvoir et la corruption du QHS ne sont pas touchés', () => {
  assert.doesNotMatch(sql, /qhs_pouvoir|crim_corruption/);
});

test('Écran : envois au QHS et vote affichés depuis la réponse du serveur, sans calcul', () => {
  assert.doesNotMatch(js.slice(js.indexOf('let qhsLu'), js.indexOf('async function crimOuvrirCorruptionQhs')), /Math\.random|partOui|trunc/);
  const dom = { innerHTML: '', textContent: '', classList: { add() {}, remove() {} } };
  const toasts = []; const appels = [];
  let reponse = null;
  const g = {
    document: { getElementById: () => dom, readyState: 'loading', addEventListener() {} },
    state: { country: 'republic', char: { name: 'Arnie' } },
    showToast: (t, b, ok) => toasts.push([t, b, ok]), adopterJaugeServeur: (k, v) => { g.state[k] = v; }, updateUI() {},
    sbRpc: async (fn, p) => { appels.push([fn, p]); return typeof reponse === 'function' ? reponse(fn, p) : reponse; }
  };
  g.window = g; g.globalThis = g;
  vm.runInNewContext(js.replace(/\(typeof window !== 'undefined' \? window : globalThis\);\s*$/, '(globalThis);'), g);
  return (async () => {
    reponse = { ok: true, decideur: true, role: 'pm', penalite_gouvernement: 5, penalite_ministre: 10,
      demandes: [{ id: 7, detenu: 'Ben', origine: 'juge', juge: 'Mme Juge', statut: 'en_attente' },
                 { id: 8, detenu: 'Zoé', origine: 'ministre', statut: 'referendum_non', depouillement: { oui: 5, non: 8 } }],
      detenus: [{ nom: 'Ben', demande: 7 }, { nom: 'Bartesto', raison: 'Vol', jour_fin: 70, demande: null }], referendums: [{ id: 9, detenu: 'Max', cloture: '2026-11-21T10:00:00Z', a_vote: false }] };
    await g.crimOuvrirEnvoisQhs();
    assert.match(dom.innerHTML, /cpj-dialogue[\s\S]*n’est pas tenu par un joueur[\s\S]*Proposé par le juge Mme Juge/);
    assert.match(dom.innerHTML, /−10 POP pour vous, −5 par membre du gouvernement/);
    assert.match(dom.innerHTML, /Référendum perdu : 5 oui, 8 non[\s\S]*−20 POP pour vous, −10 par membre/);
    assert.match(dom.innerHTML, /Bartesto[\s\S]*fin de peine au jour 70/);
    assert.match(dom.innerHTML, /crimVoterReferendumQhs\(9,'oui'\)/);
    assert.equal((dom.innerHTML.match(/<strong>Ben<\/strong>/g) || []).length, 1, 'un détenu déjà proposé n’apparaît qu’une fois');
    reponse = { ok: true, id: 7, detenu: 'Ben', pop: 40, penalite: {} };
    await g.crimQhsDecider('d', 0, 'valider');
    assert.equal(JSON.stringify(appels.at(-1)), JSON.stringify(['crim_qhs_decider', { p_demande: 7, p_detenu: null, p_reponse: 'valider' }]));
    assert.equal(g.state.pop, 40); assert.match(toasts.at(-1)[1], /Ben est transféré\(e\) au QHS[\s\S]*40/);
    reponse = (fn) => (fn === 'crim_qhs_lire' ? { ok: true, decideur: true, role: 'min_just', penalite_gouvernement: 5, penalite_ministre: 10, demandes: [], detenus: [{ nom: 'Bartesto', demande: null }], referendums: [] }
      : { ok: true, id: 12, detenu: 'Bartesto', resultat: { electeurs: 6 } });
    await g.crimOuvrirEnvoisQhs();
    await g.crimQhsDecider('t', 0, 'referendum');
    assert.equal(JSON.stringify(appels.at(-1)), JSON.stringify(['crim_qhs_decider', { p_demande: null, p_detenu: 'Bartesto', p_reponse: 'referendum' }]));
    assert.match(toasts.at(-1)[1], /6 personne\(s\) domiciliée\(s\)/);
    reponse = { ok: false, raison: 'non_domicilie' };
    await g.crimVoterReferendumQhs('9', 'oui');
    assert.equal(JSON.stringify(appels.at(-1)), JSON.stringify(['crim_qhs_voter', { p_demande: 9, p_choix: 'oui' }]));
    assert.match(toasts.at(-1)[1], /domiciliées dans le pays votent/);
    reponse = { ok: true, decideur: false, referendums: [] };
    await g.crimOuvrirEnvoisQhs();
    assert.match(dom.innerHTML, /Réservé au Ministre de la Justice, ou au Premier ministre qui le supplée/);
  })();
});

test('Courriers, juge, Gestion du QHS et subtilisation : textes et boutons branchés sur le serveur', () => {
  assert.match(forum, /qhs_decider: +\{ fn:'crimOuvrirEnvoisQhs', n:1/);
  assert.match(forum, /qhs_oui: +\{ fn:'crimVoterReferendumQhs', n:1, apres:\['oui'\]/);
  assert.match(forum, /qhs_non: +\{ fn:'crimVoterReferendumQhs', n:1, apres:\['non'\]/);
  assert.match(sql, /\[\[act:qhs_oui\|' \|\| p_id \|\| '\]\]\[\[act:qhs_non\|' \|\| p_id \|\| '\]\]/);
  assert.match(justice, /prolongerDetentionActive\(affaire\.cible, motifsQhs, state\.country === 'soviet'\)/);
  assert.match(justice, /envoi au QHS proposé au Ministre de la Justice/);
  assert.match(politique, /onclick="crimOuvrirEnvoisQhs\(\)"/);
  assert.match(rumeurs, /if \(arr\.qhs === true\) \{\s*await placerAuQHS\(verdict\.arrestation\);/);
  assert.match(rumeurs, /adopterArrestationServeur\(arr\)/);
});
