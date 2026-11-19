'use strict';
// Criminalité, lot 7 : Corruption (GAME-DESIGN-CRIMINALITE.md § 12). Trois niveaux, sans se faire passer l'un pour l'autre :
//  1. règles du document recalculées ici et comparées aux valeurs RENDUES PAR LA PRODUCTION lors des essais annulés du 20/11
//     (migration appliquée, puis scénario en transaction annulée : Arnie détenu au QHS de Républia le temps de l'essai, jour 28,
//     fin de peine 34, CHA 16, ISN inconnu ; jets imposés par rp.crim_jets) : relevé recopié ci-dessous ;
//  2. lecture de la migration (règle commune, raccords, anciennes routes) ;
//  3. écran : data.js, routeur et module plateau-criminalite.js chargé dans une machine virtuelle (pop-ups cpj-*, aucun calcul).
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const racine = path.join(__dirname, '../..');
const lire = (f) => fs.readFileSync(path.join(racine, f), 'utf8');
const sql = lire('migrations/20261120050000_crim_lot7_corruption.sql');
const js = lire('plateau-criminalite.js');
const data = lire('data.js');
const routeur = lire('plateau-router.js');
const justice = lire('plateau-justice-economie.js');
const pnj = lire('plateau-pnj.js');
const politique = lire('plateau-politique.js');

// Règles du document.
const tauxQhs = (cha, isn = 30) => Math.max(5, Math.min(75, Math.round(30 + 2 * Math.max(0, cha - 8) - (isn - 45) / 3)));
const tauxDouanier = (dup, inf, zone) => 55 + Math.floor(dup / 10) + Math.floor(inf / 10) + (zone ? 20 : 0);
const seuilCritique = (taux, part = 2) => 100 - (100 - taux) * part / 100;   // jet ≥ seuil = échec critique
const remise = (reste) => Math.floor(reste / 2);

// Relevé des essais en production (transactions annulées, 20/11/2026).
const RELEVE = {
  lire: { detenu_qhs: true, reste: 6, gain_possible: 3, reduction_possible: true, peine_echec_jours: 1, bonus_evasion: 25 },
  dir_ok: { reussi: true, taux: 51, dissuasion: 0, gain: 3, jour_fin: 31, mode: 'decouvert', detecte: false, identifie: false, dis: 45,
            paie: { pa: 27, liquide: 18500 } },
  trace_rumeur: 1, dir_bis: 'directeur_deja_sollicite',
  gar_crit: { reussi: false, denonce: true, peine: 1, conf: 800, caisse: 'republic_qhs-prison', taux: 51 },
  jugement: [{ motif: 'Delit mineur', peine: '1 jour' }],
  gar_bis: 'une_tentative_par_jour', gar_evasion: true, gar_message: true, mail: 1, gar_protection: true, protege: true,
  lire2: { reste: 3, jour_fin: 31, directeur_tente: true, gardien_aujourdhui: true, evasion_active: true, protection_active: true },
  bonus1: 25, bonus2: 0,
  dir_ko: { reussi: false, denonce: false, jours: 1, fin: 32, conf: 1500, caisse: 'republic_qhs-prison' },
  old_dir: 'ordre_remplace', old_pv: 'ordre_supprime', old_police: 'ordre_supprime', permis: 'ordre_supprime', rdv: 'ordre_supprime',
  commune_crit: { denonce: true, peine: 1, identifie: true, detecte: false },
  commune_ok: { reussi: true, detecte: false, identifie: false, mode: 'decouvert' },
  douane_ok: { ok: true, reussi: true, taux: 77, repere: false }, passage: true,
  douane_ko: { reussi: false, conf: 300, denonce: false }, caisse_douane_delta: 300, douane_bis: 'une_tentative_par_jour',
  zone: true, zone2: false, raccords: 7, ordres_retires_restants: 0
};

test('Taux du directeur et du gardien : 30 + 2/CHA > 8 − (ISN − 45)/3, bornes 5-75 (production : 51 pour CHA 16, ISN par défaut 30)', () => {
  assert.equal(tauxQhs(16), 51);
  assert.equal(RELEVE.dir_ok.taux, tauxQhs(16));
  assert.equal(RELEVE.gar_crit.taux, tauxQhs(16));
  assert.equal(tauxQhs(8, 45), 30);
  assert.equal(tauxQhs(6, 45), 30, 'CHA sous 8 : pas de malus');
  assert.equal(tauxQhs(40, 0), 75, 'plafond 75');
  assert.equal(tauxQhs(8, 120), 5, 'plancher 5');
  assert.equal(RELEVE.dir_ok.dissuasion, 0, 'dissuasion #135 comptée une seule fois, dans la résolution commune');
});

test('Règle commune : réussite −5 DIS + rumeur sans détection ; échec critique 2 % des échecs = dénonciation, 1 j d’office', () => {
  assert.equal(RELEVE.dir_ok.dis, 45);              // 50 → 45
  assert.equal(RELEVE.trace_rumeur, 1);
  assert.equal(RELEVE.dir_ok.detecte, false);
  assert.equal(RELEVE.commune_ok.detecte, false);   // même avec un jet de détection imposé à 0
  assert.equal(RELEVE.commune_ok.mode, 'decouvert');
  assert.ok(99.99 >= seuilCritique(51) && 90 < seuilCritique(51));
  assert.equal(seuilCritique(51), 99.02);
  assert.deepEqual([RELEVE.gar_crit.denonce, RELEVE.gar_crit.peine], [true, 1]);
  assert.deepEqual(RELEVE.jugement, [{ motif: 'Delit mineur', peine: '1 jour' }]);
  assert.deepEqual([RELEVE.commune_crit.denonce, RELEVE.commune_crit.identifie, RELEVE.commune_crit.peine], [true, true, 1]);
  assert.equal(RELEVE.dir_ko.denonce, false, 'échec ordinaire : aucune suite pénale');
  assert.match(sql, /'mode', 'decouvert', 'combat', false, 'detection', false/);
  assert.match(sql, /'remarque_echec', 0, 'decouvert_identifie', false, 'critique_identifie', true/);
  assert.match(sql, /crime_trace_rumeur_interne\(p_auteur, 'corruption', NULL\)/);
  assert.doesNotMatch(sql, /criminal_c/, 'pas de bonus de carrière criminelle sur la corruption');
  assert.doesNotMatch(sql, /crime_detecter_interne/, 'pas de second compte de la dissuasion');
});

test('Directeur : peine restante divisée par deux une fois par détention ; échec +1 j (barème), 1 500 confisqués, plus de tentative', () => {
  assert.equal(remise(RELEVE.lire.reste), RELEVE.dir_ok.gain);
  assert.equal(RELEVE.dir_ok.jour_fin, 34 - 3);
  assert.deepEqual(RELEVE.dir_ok.paie, { pa: 27, liquide: 18500 });
  assert.equal(RELEVE.dir_bis, 'directeur_deja_sollicite');
  assert.deepEqual(RELEVE.dir_ko, { reussi: false, denonce: false, jours: RELEVE.lire.peine_echec_jours, fin: 32, conf: 1500, caisse: 'republic_qhs-prison' });
  assert.match(sql, /crim_peine_jours_interne\('corrompre_fonct', e ->> 'pays'\)/);
  assert.match(sql, /'_gouvernement-min_just'/, 'sinon caisse du ministère');
  assert.match(sql, /'peine_trop_courte'/);
});

test('Gardien : évasion +25 % (une tentative), message, objet, protection jusqu’au prochain Dormir ; une tentative par jour', () => {
  assert.equal(RELEVE.gar_bis, 'une_tentative_par_jour');
  assert.deepEqual([RELEVE.gar_evasion, RELEVE.gar_message, RELEVE.mail, RELEVE.gar_protection, RELEVE.protege], [true, true, 1, true, true]);
  assert.deepEqual([RELEVE.bonus1, RELEVE.bonus2], [25, 0]);
  assert.deepEqual([RELEVE.gar_crit.conf, RELEVE.gar_crit.caisse], [800, 'republic_qhs-prison']);
  assert.equal(RELEVE.lire2.evasion_active && RELEVE.lire2.protection_active, true);
  assert.match(sql, /crim_corruption_evasion_v1/);
  assert.match(sql, /least\(90, v_taux \+ v_bonus\)/);
  assert.match(sql, /crim_corruption_protection_v1[\s\S]*'detenu_protege'/);
  assert.match(sql, /crim_corruption_dormir_v1/);
  assert.match(sql, /inventaire_donner\(a, v_dest, p_index, p_signature, 1, NULL\)/);
  assert.match(sql, /'destinataire_detenu'/);
});

test('Douanier : +20 seulement en zone de transport, 300 FR aux douanes en cas d’échec, retenter le lendemain', () => {
  assert.equal(tauxDouanier(8, 0, true), 75);
  assert.equal(tauxDouanier(8, 0, false), 55);
  assert.equal(RELEVE.douane_ok.reussi, true);
  assert.equal(RELEVE.passage, true);
  assert.deepEqual([RELEVE.zone, RELEVE.zone2], [true, false]);
  assert.deepEqual([RELEVE.douane_ko.conf, RELEVE.caisse_douane_delta, RELEVE.douane_bis], [300, 300, 'une_tentative_par_jour']);
  assert.match(sql, /CASE WHEN public\.crim_zone_transport_interne\(m\.current_building\)/);
});

test('Journaliste, greffier, armurier : même règle commune, formules propres conservées', () => {
  assert.match(sql, /crim_corruption_presse_v1[\s\S]*'deja_tente'[\s\S]*crim_corrompre_pnj_interne\(p_joueur, 'corrompre_journaliste', v_taux/);
  assert.match(sql, /greffe_corruption_taux', 75\)[\s\S]*'corruption_refusee'/);
  assert.doesNotMatch(sql.split('crim_corruption_greffe_v1 */')[1] || '', /PERFORM public\.greffe_denoncer_corruption/);
  assert.match(sql, /'corrompre_armurier',public\.crim_param_interne\('armurier_corruption_taux',30\)/);
  assert.equal(RELEVE.raccords, 7);
  assert.match(justice, /v\.refuse === true[\s\S]*Le greffier refuse/);
});

test('Suppressions : anciennes RPC refusées proprement, plus aucun bouton à l’écran, tarifs retirés', () => {
  assert.deepEqual([RELEVE.old_dir, RELEVE.old_pv, RELEVE.old_police, RELEVE.permis, RELEVE.rdv],
    ['ordre_remplace', 'ordre_supprime', 'ordre_supprime', 'ordre_supprime', 'ordre_supprime']);
  assert.equal(RELEVE.ordres_retires_restants, 0);
  for (const fn of ['corrompre_chantier', 'corrompre_rdv_notaire', 'corrompre_fonctionnaire_permis', 'corrompre_police'])
    assert.doesNotMatch(data + routeur, new RegExp("fn\\s*(?:===|:)\\s*'" + fn + "'"), fn);
  assert.doesNotMatch(data, /Falsifier un proces-verbal/);
  assert.doesNotMatch(justice + pnj, /async function (doCorruption|doCorrompreFonctionnairePermis|doCorrompreChantier|doCorrompreRdvNotaire)\(/);
  assert.match(routeur, /crimOuvrirCorruptionQhs\(fn === 'corrompre_fonct' \? 'directeur' : 'gardien'\)/);
  const seed = lire('baseline/seeds/95_a-regenerer/ordres_couts.sql');
  assert.doesNotMatch(seed, /'corrompre_chantier'|'corrompre_rdv_notaire'|'corrompre_fonctionnaire_permis'|\('corrompre_fonct',3,500\)/);
  assert.match(seed, /\('corrompre_fonct',3,1500\)/);
  assert.match(politique, /'detenu_protege'/);
});

test('data.js : directeur et gardien dans la cellule du QHS, exclus du goulag', () => {
  const cellules = data.slice(data.indexOf('cellules_qhs: {\n        name: "Cellules"'), data.indexOf('salle_interrogatoire: {'));
  assert.match(cellules, /fn:'corrompre_fonct', +label:'Corrompre le directeur', +pa:3, cost:1500/);
  assert.match(cellules, /fn:'corrompre_gardien', +label:'Corrompre un gardien', +pa:2, cost:800/);
  assert.match(data, /excludeOrders:\['greve_faim','corrompre_gardien','corrompre_fonct','tentative_evasion'\]/);
});

test('Écran : pop-ups cpj-*, état lu du serveur, aucun taux affiché ni calculé', async () => {
  assert.doesNotMatch(js.slice(js.indexOf('// ── Corruption au QHS'), js.indexOf("// ── Événements d'écran")), /Math\.random|taux/);
  const appels = [];
  const toasts = [];
  const dom = { innerHTML: '', textContent: '', value: '', classList: { add() {}, remove() {} } };
  const choix = { value: 'message' };
  const champs = { 'crim-qhs-dest': { value: 'Angie Porcelana' }, 'crim-qhs-texte': { value: 'Bonjour' }, 'crim-qhs-objet': { value: '' } };
  const reponses = {
    crim_corruption_qhs_lire: { ok: true, detenu_qhs: true, directeur_tente: false, reduction_possible: true, gardien_aujourdhui: false,
      evasion_active: true, protection_active: false, bonus_evasion: 25, peine_echec_jours: 1 },
    crim_corrompre_directeur: { ok: true, reussi: true, gain: 3, jour_fin: 31, dis: 45 },
    crim_corrompre_gardien: { ok: true, reussi: false, denonce: true, peine_jours: 1, confisque: 800 }
  };
  const g = {
    document: { getElementById: (id) => champs[id] || dom, querySelector: () => choix, readyState: 'loading', addEventListener() {} },
    state: { country: 'republic', inventory: [{ name: 'Montre' }], char: { name: 'Moi' } },
    showToast: (t, b, ok) => toasts.push([t, b, ok]),
    sbRpc: async (fn, p) => { appels.push([fn, p]); return reponses[fn]; },
    crypto: { randomUUID: () => '00000000-0000-4000-8000-000000000000' }
  };
  g.window = g; g.globalThis = g;
  vm.runInNewContext(js.replace(/\(typeof window !== 'undefined' \? window : globalThis\);\s*$/, '(globalThis);'), g);
  await g.crimOuvrirCorruptionQhs('directeur');
  assert.match(dom.innerHTML, /cpj-dialogue[\s\S]*\+1 jour\(s\) de peine[\s\S]*class="cpj-touche cpj-primaire"[\s\S]*1500 FR au directeur \(3 PA\)/);
  await g.crimCorrompreDirecteur();
  assert.equal(JSON.stringify(appels.at(-1)), JSON.stringify(['crim_corrompre_directeur', { p_requete: '00000000-0000-4000-8000-000000000000' }]));
  assert.match(toasts.at(-1)[1], /réduite de 3 jour/);
  await g.crimOuvrirCorruptionQhs('gardien');
  assert.match(dom.innerHTML, /value="evasion" disabled[\s\S]*\(déjà obtenu\)[\s\S]*value="protection"[\s\S]*crim-qhs-dest[\s\S]*<option value="0">Montre/);
  await g.crimCorrompreGardien();
  const [fn, p] = appels.at(-1);
  assert.equal(fn, 'crim_corrompre_gardien');
  assert.deepEqual(JSON.parse(JSON.stringify(p)), { p_service: 'message', p_destinataire: 'Angie Porcelana', p_texte: 'Bonjour', p_index: null, p_signature: null,
    p_requete: '00000000-0000-4000-8000-000000000000' });
  assert.match(toasts.at(-1)[1], /confisqué[\s\S]*dénoncé\(e\)[\s\S]*1 jour/);
  reponses.crim_corruption_qhs_lire = { ok: true, detenu_qhs: false };
  await g.crimOuvrirCorruptionQhs('gardien');
  assert.match(dom.innerHTML, /Réservé aux détenus du quartier de haute sécurité/);
});
