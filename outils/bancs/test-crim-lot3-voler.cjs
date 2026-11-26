'use strict';
// Criminalité, lot 3 : vol sur une personne (GAME-DESIGN-CRIMINALITE.md §§ 6, 7, 15).
// Trois niveaux, sans se faire passer l'un pour l'autre :
//  1. formules du document recalculées ici et comparées aux valeurs RENDUES PAR LA PRODUCTION lors de l'essai annulé du 19/11
//     (crim_voler_taux_interne, crim_voler_remarque_interne, crim_voler_part_interne, crim_voler_montant_interne,
//     crim_vol_categorie_interne, crime_voler réel sous JWT d'Arnie contre Jean Jaaj avec jets imposés) : relevé recopié ci-dessous ;
//  2. lecture de la migration (bornes, paramètres, résolution commune, raccords) ;
//  3. module d'écran chargé dans une machine virtuelle (aucun calcul, cible masquée par jeton, trois butins).
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const racine = path.join(__dirname, '../..');
const sql = fs.readFileSync(path.join(racine, 'migrations/20261119190000_crim_lot3_voler.sql'), 'utf8');
const js = fs.readFileSync(path.join(racine, 'plateau-criminalite.js'), 'utf8');
const ill = fs.readFileSync(path.join(racine, 'plateau-actions-illegales-rumeurs.js'), 'utf8');
const surv = fs.readFileSync(path.join(racine, 'plateau-surveillance.js'), 'utf8');

// Formules du document (§ 7).
const borne = (v, a, b) => Math.max(a, Math.min(b, v));
const BASES = { argent: 55, hasard: 45, precis: 25 };
const taux = (butin, dis, per, carriere) => Math.round(BASES[butin] + Math.trunc((dis - 50) / 3) - 3 * (per - 8)
  + (['criminal_c', 'intel', 'escort'].includes(carriere) ? 15 : 0));
const remarque = (per, dis) => borne(Math.round(50 + 3 * Math.max(0, per - 8) - Math.max(0, Math.trunc((dis - 50) / 3))), 10, 90);
const part = (tirage, dis, per, criminel) => borne(Math.round(tirage + Math.trunc((dis - 50) / 10) - (per - 8) + (criminel ? 5 : 0)), 10, 30);
const montant = (liquide, p) => Math.min(2000, Math.floor(Math.max(0, liquide) * p / 100));
const perGroupe = (pers) => pers.length < 2 ? pers[0] : pers.reduce((s, v) => s + v, 0) / pers.length + pers.length - 1;
const combat = (per, garde, cache) => borne(10 + 2 * Math.max(0, per - 10) + (garde ? 15 : 0) - (cache ? 10 : 0), 2, 40);
const detection = (mode) => Math.max(5, 30 - (/cache/.test(mode) ? 20 : 0) - (/masque/.test(mode) ? 10 : 0));
const designation = (mode, nom) => /masque/.test(mode) ? 'Un individu masqué' : mode === 'cache' ? 'Quelqu\'un' : nom;

// Relevé de l'essai en production (transaction annulée, 19/11/2026).
const RELEVE = {
  taux: [['argent', 95, 7, 'officer', 73], ['hasard', 50, 8, 'criminal_c', 60], ['precis', 20, 12, 'intel', 18], ['argent', 49, 8, 'escort', 70]],
  remarque: [[8, 50, 50], [20, 50, 86], [30, 50, 90], [8, 100, 34], [4, 20, 50]],
  part: [[20, 95, 7, false, 25], [10, 20, 12, false, 10], [30, 100, 4, true, 30], [15, 50, 8, true, 20]],
  montant: [[20267, 25, 2000], [1107, 13, 143], [0, 30, 0]],
  categories: [
    [{ type: 'arme', name: 'Revolver' }, 'arme'], [{ type: 'cle_serrure' }, 'cle'], [{ type: 'serrure_cle' }, 'autre'],
    [{ type: 'graisse', stackKey: 'graisse_ours', stackable: true }, 'graisse'], [{ stackKey: 'medicaments', stackable: true }, 'medicament'],
    [{ stackKey: 'viande', stackable: true }, 'nourriture'], [{ type: 'vetement', generique_id: 'masque_carnaval' }, 'vetement'],
    [{ generique_id: 'masque_carnaval', porte_par: 'X' }, null], [{ type: 'document_officiel' }, null], [{ calepinEnigme1: true }, null],
    [{ type: 'arme', origineMilitaire: true }, null], [{ stackKey: 'metal', stackable: true }, 'autre'], [{ type: 'soin' }, 'medicament'],
    [{ stackKey: 'kolkhoze_graisse_renne', familleProduitMarche: 'aliment', stackable: true }, 'graisse']],
  messages: ["Quelqu'un vous a dérobé 340 FR.", 'Un individu masqué a tenté de vous voler.', 'Arnie vous a dérobé votre Revolver.'],
  peines: { vol_republic: 1, vol_soviet: 1 },
  per_groupe_jean_seul: 7,
  // crime_voler réel : Arnie (DIS 95, officier, Sovarka) vole Jean Jaaj (PER 7, 20 267 en liquide), jets imposés.
  scenarios: {
    argent_reussi: { taux: 73, issue: 'reussite', identifie: true, peine_jours: 1, taux_detection: 30, perte_victime: 2000, description: '2000 PSK', pa_apres: 28 },
    hasard_critique: { taux: 63, reussite_critique: true, remarque: false, detecte: false, taux_detection: null, livre: true,
      differe: "En vous réveillant, vous constatez qu'on vous a dérobé 1 × metal. Impossible de dire quand, ni qui.", reveil_livres: 1 },
    precis_type_absent: { issue: 'echec', sans_risque: true, raison_echec: 'type_absent', pa_payes: 3 },
    type_invalide: 'type_invalide',
    precis_echec_non_remarque: { taux: 43, issue: 'echec', remarque: false, identifie: false, remarque_echec: 35 },
    echec_remarque_decouvert: { issue: 'echec', remarque: true, identifie: true, peine_jours: 1, taux_combat: 10 },
    echec_critique: { jet: 99.9, issue: 'echec', echec_critique: true, identifie: true, moral: 45 },
    combat: { issue: 'combat', taux_combat: 10, bataille: true, phase: 'choix' },
    ancien: 'ordre_remplace',
    dissuasion: 0
  }
};

test('Réussite : 55 / 45 / 25, +1 par 3 DIS > 50 (−1 en dessous), −3 par PER > 8 (+3 en dessous), +15 criminelle / renseignement / escort', () => {
  for (const [b, dis, per, car, attendu] of RELEVE.taux) assert.equal(taux(b, dis, per, car), attendu, `${b} ${dis} ${per} ${car}`);
  assert.match(sql, /\('vol_base_argent', 55\), \('vol_base_hasard', 45\), \('vol_base_precis', 25\), \('vol_min', 5\), \('vol_max', 85\)/);
  assert.match(sql, /p_carriere IN \('criminal_c', 'intel', 'escort'\)/);
  // Bornes 5-85 appliquées par la résolution commune, après la dissuasion #135 (une seule fois).
  assert.equal(borne(taux('argent', 100, 2, 'criminal_c') - 0, 5, 85), 85);
  assert.equal(borne(taux('precis', 0, 20, 'officer'), 5, 85), 5);
  assert.match(sql, /'taux', v_taux, 'min', public\.crim_param_interne\('vol_min', 5\), 'max', public\.crim_param_interne\('vol_max', 85\)/);
  assert.doesNotMatch(sql, /securite_malus_lieu_interne|crime_detecter_interne/);
  // Être caché ne change pas la réussite : aucune lecture de la cachette dans le taux du vol.
  const fTaux = sql.slice(sql.indexOf('FUNCTION public.crim_voler_taux_interne'), sql.indexOf('FUNCTION public.crim_voler_remarque_interne'));
  assert.doesNotMatch(fTaux, /cache/);
});

test('PER de groupe (règle #135 : moyenne + effectif − 1) ; seul : sa PER', () => {
  assert.equal(perGroupe([7]), 7);
  assert.equal(perGroupe([10, 8]), 10);
  assert.equal(perGroupe([12, 9, 6]), 11);
  assert.equal(RELEVE.per_groupe_jean_seul, 7);
  assert.match(sql, /RETURN round\(v_moy \+ v_n - 1, 2\);/);
  assert.match(sql, /'remarque_echec', public\.crim_voler_remarque_interne\(v_per, v_dis\)/);
});

test('Butin : 10-30 % du liquide, ±DIS/10, −PER, +5 carrière criminelle, plafond 2 000 ; jamais la banque', () => {
  for (const [t, dis, per, crim, attendu] of RELEVE.part) assert.equal(part(t, dis, per, crim), attendu);
  for (const [l, p, attendu] of RELEVE.montant) assert.equal(montant(l, p), attendu);
  assert.match(sql, /\('vol_part_min', 10\), \('vol_part_max', 30\), \('vol_part_carriere', 5\), \('vol_plafond', 2000\)/);
  assert.match(sql, /crim_voler_part_interne\(\(10 \+ floor\(random\(\) \* 21\)\)::numeric/);   // tirage 10-30
  assert.match(sql, /argent_debiter_interne\(f\.cible, v_m, 'liquide'\)/);                      // liquide seulement
  assert.equal(RELEVE.scenarios.argent_reussi.perte_victime, 2000);
});

test('Objets volables : non porté, ni document, ni quête, ni dotation ; une unité par pile ; aucun → échec sans risque', () => {
  const cat = (it) => RELEVE.categories.find(([o]) => JSON.stringify(o) === JSON.stringify(it))[1];
  assert.equal(cat({ generique_id: 'masque_carnaval', porte_par: 'X' }), null);
  assert.equal(cat({ type: 'document_officiel' }), null);
  assert.equal(cat({ type: 'arme', origineMilitaire: true }), null);
  assert.equal(cat({ type: 'serrure_cle' }), 'autre');            // une serrure n'est pas une clé
  for (const t of ['arme', 'cle', 'medicament', 'nourriture', 'vetement', 'graisse']) assert.ok(RELEVE.categories.some(([, c]) => c === t), t);
  assert.match(sql, /IF v_pile AND v_q > 1 THEN\s+UPDATE public\.personnages_donnees SET inventory = jsonb_set\(inventory, ARRAY\[v_pos::text, 'qty'\], to_jsonb\(v_q - 1\)\)/);
  assert.match(sql, /'raison_echec', CASE WHEN p_butin = 'precis' THEN 'type_absent' ELSE 'rien_a_voler' END/);
  const s = RELEVE.scenarios.precis_type_absent;
  assert.equal(s.sans_risque, true);
  assert.equal(s.pa_payes, 3);
  assert.equal(RELEVE.scenarios.type_invalide, 'type_invalide');
});

test('Coûts 2 / 2 / 3 PA (ordres_couts voler 2 et 3)', () => {
  assert.match(sql, /v_pa := CASE WHEN p_butin = 'precis' THEN 3 ELSE 2 END;/);
  assert.match(sql, /INSERT INTO public\.ordres_couts \(fn, pa, cost\) VALUES \('voler', 3, 0\)/);
  assert.match(js, /precis: \{ fn: 'voler', label: 'Voler un objet précis', pa: 3, cost: 0 \}/);
  assert.equal(RELEVE.scenarios.argent_reussi.pa_apres, 28);
});

test('Réussite : la victime apprend le vol, auteur selon le mode ; détection 30 −20 caché −10 masqué min 5', () => {
  assert.equal(RELEVE.messages[0], designation('cache', 'Arnie') + ' vous a dérobé 340 FR.');
  assert.equal(RELEVE.messages[1], designation('cache_masque', 'Arnie') + ' a tenté de vous voler.');
  assert.equal(RELEVE.messages[2], 'Arnie vous a dérobé votre Revolver.');
  assert.deepEqual(['decouvert', 'cache', 'masque', 'cache_masque'].map(detection), [30, 10, 20, 5]);
  assert.equal(RELEVE.scenarios.argent_reussi.taux_detection, 30);
  assert.match(sql, /'msg_reussite', '\{Auteur\} vous a dérobé '/);
  assert.match(sql, /'msg_echec', '\{Auteur\} a tenté de vous voler\.'/);
  assert.match(sql, /\('vol_detection', 30\)/);
});

test('Réussite critique (5 % des réussites) : découverte au prochain réveil, sans lien ni détection', () => {
  const s = RELEVE.scenarios.hasard_critique;
  assert.equal(s.reussite_critique, true);
  assert.equal(s.remarque, false);
  assert.equal(s.detecte, false);
  assert.equal(s.reveil_livres, 1);
  assert.match(s.differe, /^En vous réveillant, vous constatez qu'on vous a dérobé .*Impossible de dire quand, ni qui\.$/);
  assert.match(sql, /'critique_reussite_part', public\.crim_param_interne\('vol_critique_reussite_part', 5\), 'critique_sans_detection', true/);
  assert.match(sql, /PERFORM public\.crim_vols_reveil_interne\(p_acteur\); \/\* crim_vol_reveil_v1 \*\//);
});

test('Échecs : remarqué 50 +3/PER > 8 −1/3 DIS > 50 (10-90) ; critique 2 % des échecs ; combat 10 % (formule de la neutralisation)', () => {
  for (const [per, dis, attendu] of RELEVE.remarque) assert.equal(remarque(per, dis), attendu, `${per} ${dis}`);
  const s = RELEVE.scenarios;
  assert.equal(s.precis_echec_non_remarque.remarque_echec, remarque(7, 95));
  assert.equal(s.precis_echec_non_remarque.identifie, false);
  assert.equal(s.echec_remarque_decouvert.identifie, true);     // visage découvert remarqué = identifié
  assert.equal(s.echec_critique.echec_critique, true);
  assert.equal(s.echec_critique.moral, 45);                     // −15
  assert.equal(s.echec_remarque_decouvert.taux_combat, combat(7, false, false));
  assert.equal(s.combat.issue, 'combat');
  assert.equal(s.combat.bataille, true);
  assert.match(sql, /'combat', true, 'per_victime', \(ci ->> 'per'\)::numeric/);
  assert.match(sql, /r := public\.crim_combat_ouvrir_interne\(a, r, ci, 'mains', p_requete\);/);
  // Une seule ouverture de combat : Neutraliser est raccordé sur la même brique ; combat gagné = butin livré.
  assert.match(sql, /r := public\.crim_combat_ouvrir_interne\(a, r, ci, p_mode, p_requete\); \/\* crim_combat_commun_v1 \*\//);
  assert.match(sql, /IF f\.acte = 'voler' THEN PERFORM public\.crim_voler_livrer_interne\(f\.id\); END IF; \/\* crim_vol_combat_v1 \*\//);
});

test('Peine : voleur pris = 1 jour d’office (Républia, paramètre par empire)', () => {
  assert.equal(RELEVE.peines.vol_republic, 1);
  assert.equal(RELEVE.peines.vol_soviet, 1);
  assert.match(sql, /\('peine_jours_vol_republic', 1\)/);
  assert.match(sql, /'acte_peine_reussite', 'vol', 'acte_peine_echec', 'vol', 'type_recherche', 'delit_mineur'/);
  for (const k of ['argent_reussi', 'echec_remarque_decouvert']) assert.equal(RELEVE.scenarios[k].peine_jours, 1, k);
});

test('Une seule fonction de vol : l’ancienne route répond « ordre_remplace »', () => {
  assert.equal(RELEVE.scenarios.ancien, 'ordre_remplace');
  assert.match(sql, /'ok', false, 'raison', 'ordre_remplace'/);
  assert.equal((sql.match(/crim_resoudre_interne\('voler'/g) || []).length, 1);
  assert.match(sql, /'crime_voler\(text,text,text,uuid\)', 'crime_voler\(text,text,boolean,integer,integer\)'/);
  // Jets imposés : console d'administration seulement (jamais un joueur).
  assert.match(sql, /'jets', CASE WHEN session_user = 'postgres' THEN/);
});

test('Écran : aucun calcul ; fiche → module ; menu « Fouiller ou voler » ; cible masquée par jeton ; trois butins', () => {
  assert.equal((js.match(/Math\.random/g) || []).length, 1);
  assert.doesNotMatch(ill, /jetBase|BONUS_CARRIERE_VOL\[|sbRpc\('crime_voler'/);
  assert.match(ill, /function ouvrirModalVolerChoix\(encodedCible\) \{\s+if \(typeof crimOuvrirVoler === 'function'\) crimOuvrirVoler\(encodedCible\);/);
  // Lot de Krasnov, point 9 (22/11/2026) : « Voler quelqu'un » sort des actions de pièce (il reste dans la fenêtre de rencontre).
  assert.doesNotMatch(surv, /crimVolerChoisirCible/);
  const appels = [];
  const ctx = { console, setTimeout() {}, setInterval() {}, showToast() {},
    sbRpc: async (fn, p) => { appels.push([fn, p]); return { ok: true, issue: 'reussite', description: '340 FR', livre: true, inventory: [] }; } };
  ctx.globalThis = ctx; ctx.window = ctx;
  const el = () => ({ textContent: '', innerHTML: '', classList: { add() {}, remove() {} } });
  ctx.document = { getElementById: el, readyState: 'loading', addEventListener() {} };
  vm.createContext(ctx);
  vm.runInContext('var state = { country: "republic", char: { name: "Arnie" }, inventory: [] };', ctx);
  vm.runInContext(js, ctx);
  // Fred, 20/11/2026 : les documents deviennent volables et nommables.
  assert.deepEqual(Array.from(ctx.RPCriminalite.TYPES_VOL), ['arme', 'cle', 'medicament', 'nourriture', 'vetement', 'graisse', 'document']);
  const jeton = '0e1f2a3b-4c5d-4e6f-8a9b-0c1d2e3f4a5b';
  const enc = encodeURIComponent(JSON.stringify({ name: 'Individu masqué n°1', isPJ: true, masque: true, jeton }));
  return ctx.crimVolerConfirmer(enc, 'precis', 'arme').then(() => ctx.crimVolerConfirmer(enc, 'argent')).then(() => {
    assert.equal(appels.length, 2);
    assert.equal(appels[0][0], 'crime_voler');
    assert.equal(appels[0][1].p_cible, jeton);
    assert.equal(appels[0][1].p_butin, 'precis');
    assert.equal(appels[0][1].p_type, 'arme');
    assert.equal(appels[1][1].p_type, null);
    assert.match(appels[0][1].p_requete, /^[0-9a-f-]{36}$/);
  });
});

test('Fiche de rencontre : « Voler » n\'apparaît qu\'après confirmation de la cible (26/11/2026, Anne Tibiotique)', () => {
  const pnj = fs.readFileSync(path.join(__dirname, '../../plateau-pnj.js'), 'utf8');
  // Plus de bouton Voler inconditionnel dans la fiche : une place vide, remplie par le verdict de présence.
  assert.doesNotMatch(pnj, /ouvrirModalVolerChoix\(\\'' \+ encCible/);
  assert.match(pnj, /actionBtns \+= '<span id="voler-cible-pnj"><\/span>';/);
  // Les deux chemins qui affichent « Neutraliser » (joueur, PNJ confirmé) affichent aussi « Voler », avec la même cible.
  assert.match(pnj, /zonePj\.replaceChildren\(b\);afficherVolerCible\(pnj\);return true;/);
  assert.match(pnj, /zone\.replaceChildren\(bouton\);afficherVolerCible\(cible\);return true;/);
  // Les refus (« ne peut pas être ciblée ici », présence non confirmée) ne l'affichent pas.
  for (const m of pnj.matchAll(/textContent='[^']*';return false;/g)) assert.doesNotMatch(m[0], /afficherVolerCible/);
});
