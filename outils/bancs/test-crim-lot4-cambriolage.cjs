'use strict';
// Criminalité, lot 4 : cambriolage (GAME-DESIGN-CRIMINALITE.md §§ 6, 8, 15 ; GAME-DESIGN-SERRURES.md).
// Trois niveaux, sans se faire passer l'un pour l'autre :
//  1. formules du document recalculées ici et comparées aux valeurs RENDUES PAR LA PRODUCTION lors des essais annulés du 19/11
//     (crim_crocheter, crim_forcer_porte, crim_cambrioler, voler_materiel, objet_abandonne_ramasser réels sous JWT d'Angie Porcelana,
//     serrure posée par Arnie sur son local, jets imposés) : relevé recopié ci-dessous ;
//  2. lecture de la migration (paramètres, résolution commune, raccords, droits) ;
//  3. module d'écran chargé dans une machine virtuelle (aucun calcul, boutons sur la porte, menu du cambriolage).
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const racine = path.join(__dirname, '../..');
const sql = fs.readFileSync(path.join(racine, 'migrations/20261119220000_crim_lot4_cambriolage.sql'), 'utf8');
const js = fs.readFileSync(path.join(racine, 'plateau-criminalite.js'), 'utf8');
const equip = fs.readFileSync(path.join(racine, 'plateau-equipements.js'), 'utf8');
const nav = fs.readFileSync(path.join(racine, 'plateau-navigation.js'), 'utf8');
const surv = fs.readFileSync(path.join(racine, 'plateau-surveillance.js'), 'utf8');
const info = fs.readFileSync(path.join(racine, 'plateau-informatique.js'), 'utf8');

// Formules du document (§ 8).
const borne = (v, a, b) => Math.max(a, Math.min(b, v));
const crocheter = (dis, carriere) => 30 + Math.max(0, Math.trunc((dis - 50) / 2)) + (carriere === 'criminal_c' ? 15 : 0);
const forcer = (force, pied, carriere) => 40 + 3 * Math.max(0, force - 8) + (pied ? 25 : 0) + (carriere === 'criminal_c' ? 10 : 0);
const stockQte = (pile, part) => pile <= 0 ? 0 : Math.min(Math.floor(pile), Math.max(1, Math.floor(pile * part / 100)));
const caisse = (c, part) => Math.min(3000, Math.floor(Math.max(0, c) * part / 100));
const detection = (base, mode) => Math.max(5, base - (/cache/.test(mode) ? 20 : 0) - (/masque/.test(mode) ? 10 : 0));
const modeEffraction = (mode) => ({ cache: 'decouvert', cache_masque: 'masque' })[mode] || mode;

// Relevé des essais en production (transactions annulées, 19/11/2026).
const RELEVE = {
  // crocheter(95,intel), (60,criminal_c), (40,x), (51,x), forcer(12,pied,criminal_c), (5,mains,x), stock(10,15), (2,10), (100,20),
  // caisse(844,30), (50000,30), mode effraction cache / cache_masque / masque, détection 60 masqué, 30 caché masqué, peine effraction Sovarka.
  formules: [52, 50, 30, 30, 87, 40, 1, 1, 20, 253, 3000, 'decouvert', 'masque', 'masque', 50, 5, 1],
  crochetage: {
    echec: { jet: 60, taux: 52, issue: 'echec', kit_usages_restants: 1, kit_detruit: false, identifie: false, trace: false },
    reussite: { jet: 0, taux: 52, issue: 'reussite', kit_usages_restants: 0, kit_detruit: true, detecte: false, taux_detection: null,
      passage_crocheteur: false, ferme_pour_jean: true, serrure: { statut: 'posee', fermee: true } },
    reussite_kit_2_usages: { kit_usages_restants: 1, kit_detruit: false, pa_apres: 37 },
    critique: { jet: 99.99, echec_critique: true, kit_detruit: true, moral: 60, identifie: false,
      mail: "Tentative de crochetage : Un crochet brisé est resté coincé dans la serrure n° 1CC01C de votre local (boutique_milieu, centre-commercial) : quelqu'un a tenté de la crocheter. La serrure a tenu." },
    sans_kit: 'kit_requis'
  },
  effraction: {
    echec: { jet: 99, taux: 40, issue: 'echec', identifie: false },
    reussite: { taux: 40, issue: 'reussite', detecte: true, identifie: true, peine_jours: 1, taux_detection: 60, serrure: { statut: 'detruite', motif: 'effraction' } },
    pied_de_biche: { taux: 65, pied: true, identifie: false, taux_detection: 60,
      mail: 'Effraction : Votre porte a été forcée : votre local (boutique_milieu, centre-commercial). La serrure n° 85CDDF est détruite.' },
    affaires: [['crocheter', 'Arnie', 'echec', false, false], ['crocheter', 'Arnie', 'reussite', false, false], ['crocheter', 'Arnie', 'echec', true, true],
      ['forcer_porte', 'Arnie', 'echec', false, true], ['forcer_porte', 'Arnie', 'reussite', true, true]]
  },
  interieur: {
    lire: { stock: [{ produit: 'test_produit', label: 'test produit' }], caisse: true, materiel: 1 },
    temoin_apres_effraction: null,
    stock_lieu_vide: { lieu_vide: true, issue: 'reussite', description: '1 × test produit', taux_detection: 30, identifie: false, stock_apres: 9 },
    caisse_lieu_vide: { lieu_vide: true, description: '109 FR dans la caisse', identifie: true, peine_jours: 1, caisse_apres: '735.00', gain: 109 },
    materiel_ancienne_route: { lieu_vide: true, taux: 100, livre: true, reussi: true, repere: false, description: 'Box essai', eq_reste: 0 },
    ramasser: { ok: 'true', affaire: { cible: 'Arnie', issue: 'reussite', detecte: false },
      constat: 'En repassant, vous constatez que « Vase essai », que vous aviez déposé ici (boutique_milieu), a disparu. Vous pouvez porter plainte pour vol.' },
    temoin_jean: { nom: 'Jean Jaaj', taux: 71, issue: 'echec', remarque: true, identifie: true, peine_jours: 1, taux_combat: 10,
      mail: 'Tentative de vol : Angie Porcelana a tenté de dérober 1 × test produit sous vos yeux.' },
    constats_au_passage: 3, constats_au_point_de_caisse: 3,
    comptoir: { nom: "l'employé(e) au comptoir", per: 8, profil_combat: false, pnj_id: 'comptoir:armurerie-republic-capitale' }
  }
};

test('Crocheter : 30 % + 1 par tranche de 2 de DIS au-dessus de 50, +15 carrière criminelle, bornes 5-80 (dissuasion comprise)', () => {
  const f = RELEVE.formules;
  assert.equal(crocheter(95, 'intel'), f[0]);
  assert.equal(crocheter(60, 'criminal_c'), f[1]);
  assert.equal(crocheter(40, 'x'), f[2]);
  assert.equal(crocheter(51, 'x'), f[3]);
  assert.equal(borne(crocheter(100, 'criminal_c'), 5, 80), 70);
  assert.equal(borne(crocheter(100, 'criminal_c') - 40, 5, 80), 30);
  assert.match(sql, /\('crochetage_base', 30\), \('crochetage_min', 5\), \('crochetage_max', 80\), \('crochetage_carriere', 15\)/);
  assert.match(sql, /'taux', v_taux, 'min', public\.crim_param_interne\('crochetage_min', 5\), 'max', public\.crim_param_interne\('crochetage_max', 80\)/);
  assert.equal(RELEVE.crochetage.reussite.taux, crocheter(95, 'intel'));
});

test('Forcer : 40 % + 3 par point de FOR au-dessus de 8, +25 pied-de-biche, +10 carrière criminelle, bornes 10-95', () => {
  const f = RELEVE.formules;
  assert.equal(forcer(12, true, 'criminal_c'), f[4]);
  assert.equal(forcer(5, false, 'x'), f[5]);
  assert.equal(forcer(8, true, 'intel'), RELEVE.effraction.pied_de_biche.taux);
  assert.equal(borne(forcer(30, true, 'criminal_c'), 10, 95), 95);
  assert.match(sql, /\('effraction_base', 40\), \('effraction_min', 10\), \('effraction_max', 95\), \('effraction_carriere', 10\)/);
  assert.match(sql, /\('effraction_for_pivot', 8\), \('effraction_for_pas', 3\), \('effraction_pied_de_biche', 25\), \('effraction_detection', 60\)/);
});

test('Kit : 5 usages, un de moins par réussite, détruit à zéro ou cassé à l’échec critique ; rien à l’échec ordinaire', () => {
  const c = RELEVE.crochetage;
  assert.equal(c.echec.kit_usages_restants, 1); assert.equal(c.echec.kit_detruit, false);
  assert.equal(c.reussite.kit_detruit, true);
  assert.equal(c.reussite_kit_2_usages.kit_usages_restants, 1);
  assert.equal(c.critique.kit_detruit, true);
  assert.equal(c.sans_kit, 'kit_requis');
  assert.match(sql, /\('kit_usages', 5\)/);
  assert.match(sql, /v_reste := v_usages - 1;\s+IF v_reste <= 0 THEN/);
  assert.match(sql, /payer_ordre\(a, 'crocheter', 3, 0\)/);
  assert.equal(c.reussite_kit_2_usages.pa_apres, 40 - 3);
});

test('Crochetage réussi : sans trace, serrure intacte et refermée, passage personnel du crocheteur', () => {
  const c = RELEVE.crochetage.reussite;
  assert.equal(c.detecte, false); assert.equal(c.taux_detection, null);
  assert.deepEqual(c.serrure, { statut: 'posee', fermee: true });
  assert.equal(c.passage_crocheteur, false);   // serrure_porte_fermee_interne : ouverte pour lui
  assert.equal(c.ferme_pour_jean, true);       // fermée pour les autres
  assert.match(sql, /'critique_identifie', false, 'critique_moral', false, 'combat', false, 'detection', false/);
  assert.match(sql, /crim_passage_valide_interne\(p_nom, v_id\); \/\* crim_passage_v1 \*\//);
  // Échec critique : trace sans nom pour le propriétaire, pas de moral perdu (raccord crim_critique_moral_v1).
  assert.equal(RELEVE.crochetage.critique.moral, 60);
  assert.equal(RELEVE.crochetage.critique.identifie, false);
  assert.doesNotMatch(RELEVE.crochetage.critique.mail, /Angie/);
  assert.match(sql, /IF v_crit_e AND coalesce\(\(p ->> 'critique_moral'\)::boolean, true\) \/\* crim_critique_moral_v1 \*\/ THEN/);
});

test('Effraction : serrure détruite (jamais récupérable), propriétaire prévenu ; détection 60, −10 masqué, caché ne compte pas', () => {
  const e = RELEVE.effraction;
  assert.deepEqual(e.reussite.serrure, { statut: 'detruite', motif: 'effraction' });
  assert.equal(e.reussite.taux_detection, 60);
  assert.equal(RELEVE.formules[11], modeEffraction('cache'));
  assert.equal(RELEVE.formules[12], modeEffraction('cache_masque'));
  assert.equal(RELEVE.formules[14], detection(60, modeEffraction('masque')));
  assert.equal(detection(60, modeEffraction('cache')), 60);
  assert.match(e.pied_de_biche.mail, /^Effraction : Votre porte a été forcée/);
  assert.doesNotMatch(e.pied_de_biche.mail, /Angie/);
  assert.match(sql, /'msg_echec', 'Quelqu''un a tenté de forcer votre porte : '/);
  assert.match(sql, /statut = 'detruite', fermee = false, detruite_le = now\(\), motif_destruction = 'effraction'/);
  assert.match(sql, /'critique_echec_part', 0, 'combat', false, 'remarque_echec', 100, 'decouvert_identifie', false/);
  // Affaires au nom du propriétaire : [acte, cible, issue, trace, remarque].
  assert.deepEqual(e.affaires.map(a => a[1]), ['Arnie', 'Arnie', 'Arnie', 'Arnie', 'Arnie']);
  assert.deepEqual(e.affaires[2], ['crocheter', 'Arnie', 'echec', true, true]);
});

test('Intérieur, lieu vide : pas de jet de réussite, détection par vol 30 (−20 caché, −10 masqué, min 5)', () => {
  const i = RELEVE.interieur;
  assert.equal(i.stock_lieu_vide.lieu_vide, true);
  assert.equal(i.stock_lieu_vide.taux_detection, detection(30, 'decouvert'));
  assert.equal(RELEVE.formules[15], detection(30, 'cache_masque'));
  assert.equal(i.materiel_ancienne_route.taux, 100);
  assert.match(sql, /'reussite_auto', true, 'detection_base', public\.crim_param_interne\('cambriolage_detection', 30\)/);
  assert.equal(i.temoin_apres_effraction, null); // un commerce forcé n'a pas d'employé au comptoir
});

test('Stock 10-20 % de la pile (au moins une unité) ; caisse 10-30 % plafonnée à 3 000 ; une pile par ordre, 2 PA', () => {
  assert.equal(stockQte(10, 15), RELEVE.formules[6]);
  assert.equal(stockQte(2, 10), RELEVE.formules[7]);
  assert.equal(stockQte(100, 20), RELEVE.formules[8]);
  assert.equal(caisse(844, 30), RELEVE.formules[9]);
  assert.equal(caisse(50000, 30), RELEVE.formules[10]);
  assert.equal(caisse(844, 13), RELEVE.interieur.caisse_lieu_vide.gain);
  assert.equal(10 - 1, RELEVE.interieur.stock_lieu_vide.stock_apres);
  assert.match(sql, /\('cambriolage_stock_min', 10\), \('cambriolage_stock_max', 20\)/);
  assert.match(sql, /\('cambriolage_caisse_min', 10\), \('cambriolage_caisse_max', 30\), \('cambriolage_caisse_plafond', 3000\)/);
  assert.match(sql, /payer_ordre\(a, 'cambrioler', 2, 0\)/);
});

test('Matériel installé : 2 PA, sans jet ; ancienne route voler_materiel redirigée ; crime_voler_materiaux (chantier) intact', () => {
  const m = RELEVE.interieur.materiel_ancienne_route;
  assert.equal(m.reussi, true); assert.equal(m.repere, false); assert.equal(m.eq_reste, 0);
  assert.match(sql, /FUNCTION public\.voler_materiel\(p_id uuid\)[\s\S]*crim_cambrioler_interne\(public\.mon_personnage\(\), 'materiel'/);
  assert.doesNotMatch(sql, /FUNCTION public\.crime_voler_materiaux/);
  assert.match(sql, /e\.generique_id = 'armoire_souvenirs' THEN RETURN jsonb_build_object\('ok', false, 'raison', 'equipement_introuvable'\)/);
});

test('Objets déposés : se ramassent (pas un vol), affaire au nom du propriétaire, constat avec plainte possible', () => {
  const r = RELEVE.interieur.ramasser;
  assert.equal(r.ok, 'true');
  assert.deepEqual(r.affaire, { cible: 'Arnie', issue: 'reussite', detecte: false });
  assert.match(r.constat, /Vous pouvez porter plainte pour vol\.$/);
  assert.match(sql, /PERFORM public\.crim_ramasser_constater_interne\(v_moi, v_objet\); \/\* crim_ramasser_v1 \*\//);
  assert.match(sql, /crim_resoudre_interne\('ramasser', p_nom, NULL, jsonb_build_object\('reussite_auto', true, 'detection', false/);
});

test('Constat au prochain passage du propriétaire ou à son prochain point de caisse', () => {
  assert.equal(RELEVE.interieur.constats_au_passage, 3);
  assert.equal(RELEVE.interieur.constats_au_point_de_caisse, 3);
  assert.match(sql, /\/\* crim_constat_passage_v1 \*\//);
  assert.equal((sql.match(/\/\* crim_constat_caisse_v1 \*\//g) || []).length, 2);
});

test('Personnes présentes : règles du vol sur une personne (lot 3) — réussite, remarqué, combat ; employé au comptoir', () => {
  const t = RELEVE.interieur.temoin_jean;
  assert.equal(t.nom, 'Jean Jaaj');
  assert.equal(t.issue, 'echec'); assert.equal(t.remarque, true); assert.equal(t.identifie, true); assert.equal(t.peine_jours, 1);
  assert.equal(t.taux_combat, 10);
  assert.match(t.mail, /^Tentative de vol : Angie Porcelana a tenté de dérober/);
  assert.match(sql, /crim_voler_taux_interne\(CASE WHEN p_cible = 'caisse' THEN 'argent' ELSE 'hasard' END, v_dis, v_per, m\.career\)/);
  assert.match(sql, /'remarque_echec', public\.crim_voler_remarque_interne\(v_per, v_dis\)/);
  assert.match(sql, /r := public\.crim_combat_ouvrir_interne\(a, r, t, 'mains', p_requete\)/);
  assert.match(sql, /IF f\.acte = 'cambrioler' THEN PERFORM public\.crim_cambrioler_livrer_interne\(f\.id\); END IF; \/\* crim_cambriolage_combat_v1 \*\//);
  assert.equal(RELEVE.interieur.comptoir.profil_combat, false);
});

test('Dissuasion #135 et peines : résolution commune, barème par empire (effraction 1 j, vol 1 j ; autres empires = Républia)', () => {
  assert.doesNotMatch(sql, /securite_malus_lieu_interne|crime_detecter_interne/);
  assert.match(sql, /\('peine_jours_effraction_republic', 1\)/);
  assert.equal(RELEVE.formules[16], 1);
  assert.equal(RELEVE.effraction.reussite.peine_jours, 1);
  assert.match(sql, /'acte_peine_reussite', 'effraction', 'acte_peine_echec', 'effraction', 'type_recherche', 'delit_mineur'/);
  assert.match(sql, /'acte_peine_reussite', 'vol', 'acte_peine_echec', 'vol', 'type_recherche', 'delit_mineur'/);
});

test('Droits : RPC aux joueurs authentifiés, briques internes fermées ; ordres_couts (crocheter 3, forcer_porte 2, cambrioler 2)', () => {
  for (const f of ['crim_crocheter(text,text,uuid)', 'crim_forcer_porte(text,text,uuid)', 'crim_cambriolage_lire()', 'crim_cambrioler(text,text,uuid)', 'voler_materiel(uuid)'])
    assert.ok(sql.includes("'" + f + "'"), f);
  assert.match(sql, /'crim_cambrioler_interne\(text,text,text,uuid\)'/);
  assert.match(sql, /VALUES \('crocheter', 3, 0\), \('forcer_porte', 2, 0\), \('cambrioler', 2, 0\)/);
  const seed = fs.readFileSync(path.join(racine, 'baseline/seeds/95_a-regenerer/ordres_couts.sql'), 'utf8');
  for (const l of ["('crocheter',3,0)", "('forcer_porte',2,0)", "('cambrioler',2,0)"]) assert.ok(seed.includes(l), l);
});

test('Écran : boutons sur la porte fermée, aucun calcul, entrée par la navigation ordinaire', () => {
  assert.doesNotMatch(js, /Math\.random\(\)\s*\*\s*100|taux\s*=\s*\d/);
  assert.match(equip, /function serrurePopupFermee\(genre, batiment, piece\)/);
  assert.match(equip, /crimBoutonsPorte\(batiment, genre === 'batiment' \? null : piece\)/);
  assert.match(nav, /serrurePopupFermee\('batiment', buildingId\)/);
  assert.match(nav, /serrurePopupFermee\(r\.batiment\?'batiment':'local',buildingId,r\.batiment\?null:roomId\)/);
  // Lot de Krasnov, point 9 (22/11/2026) : « Emporter ce qu'il y a ici » est remplacé par « Désinstaller du matériel ».
  assert.doesNotMatch(surv, /crimOuvrirCambriolage/);
  assert.match(surv, /desinstaller_materiel/);
  assert.match(info, /if \(typeof crimOuvrirCambriolage === 'function'\) return crimOuvrirCambriolage\(\);/);

  const appels = [];
  const toasts = [];
  const dom = { innerHTML: '', textContent: '', classList: { add() {}, remove() {} } };
  const g = {
    document: { getElementById: () => dom, readyState: 'loading', addEventListener() {} },
    state: { country: 'republic', inventory: [] },
    showToast: (t, b, ok) => toasts.push([t, b, ok]),
    sbRpc: async (fn, p) => { appels.push([fn, p]); return reponses[fn]; },
    crypto: { randomUUID: () => '00000000-0000-4000-8000-000000000000' },
    entres: [], enterRoom(b, r) { g.entres.push([b, r]); }, passages: [], serruresPassageAccorde(b, r, d) { g.passages.push([b, r, d]); }
  };
  const reponses = {
    crim_crocheter: { ok: true, issue: 'reussite', reussi: true, kit_detruit: false, kit_usages_restants: 3, entrer: { batiment: 'centre-commercial', piece: 'boutique_milieu' } },
    crim_cambriolage_lire: { ok: true, materiel: [{ id: 'x', nom: 'Box' }], stock: [], caisse: true }
  };
  g.window = g; g.globalThis = g;
  vm.runInNewContext(js.replace(/\(typeof window !== 'undefined' \? window : globalThis\);\s*$/, '(globalThis);'), g);
  const html = g.crimBoutonsPorte('centre-commercial', 'boutique_milieu');
  assert.match(html, /Crocheter — 3 PA/);
  assert.match(html, /Forcer la porte — 2 PA/);
  assert.match(html, /class="cpj-touche"/);
  return (async () => {
    await g.crimPorteAgir('crocheter', 'centre-commercial', 'boutique_milieu');
    assert.deepEqual(JSON.parse(JSON.stringify(appels[0])), ['crim_crocheter', { p_batiment: 'centre-commercial', p_piece: 'boutique_milieu', p_requete: '00000000-0000-4000-8000-000000000000' }]);
    // Fred, 20/11/2026 : la porte crochetée reste ouverte pour tous (plus de passage personnel) : le cache la retire des portes fermées.
    assert.deepEqual(JSON.parse(JSON.stringify(g.passages[0])), ['centre-commercial', 'boutique_milieu', true]);
    assert.deepEqual(JSON.parse(JSON.stringify(g.entres[0])), ['centre-commercial', 'boutique_milieu']);
    assert.match(toasts[0][1], /servira encore 3 fois/);
    await g.crimOuvrirCambriolage();
    assert.match(dom.innerHTML, /Matériel installé[\s\S]*Box[\s\S]*Caisse du commerce/);
    assert.doesNotMatch(dom.innerHTML, /\d+ FR/);
    assert.deepEqual(JSON.parse(JSON.stringify(g.RPCriminalite.ORDRES_CAMBRIOLAGE.crocheter)), { fn: 'crocheter', label: 'Crocheter une serrure', pa: 3, cost: 0 });
  })();
});
