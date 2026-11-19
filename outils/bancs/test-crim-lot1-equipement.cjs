'use strict';
// Criminalité, lot 1 : équipement et dissimulation (GAME-DESIGN-CRIMINALITE.md §§ 1 et 5).
// Trois niveaux, sans se faire passer l'un pour l'autre :
//  1. formules du document recalculées ici et comparées aux valeurs RENDUES PAR LA PRODUCTION lors de l'essai annulé du 19/11
//     (crim_cacher_taux_interne, crim_fouiller_taux_interne, crim_prix_interne : relevé recopié ci-dessous) ;
//  2. lecture de la migration (fragments attendus : bornes, échec critique, RLS, raccords) ;
//  3. module d'écran chargé dans une machine virtuelle (lieux de la boutique, boutons, aucun jet côté écran).
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const racine = path.join(__dirname, '../..');
const sql = fs.readFileSync(path.join(racine, 'migrations/20261119130000_crim_lot1_equipement_dissimulation.sql'), 'utf8');
const js = fs.readFileSync(path.join(racine, 'plateau-criminalite.js'), 'utf8');

// Formules du document (§ 1).
const cacher = (dis, ninja) => Math.min(98, 70 + 5 * Math.floor(Math.max(0, dis) / 20) + (ninja ? 15 : 0));
const fouiller = (per, dis, ninja, force) => Math.max(10, Math.min(90, 40 + 2 * per - Math.floor(Math.max(0, dis) / 10) - (ninja ? 15 : 0) + (force ? 20 : 0)));
const critique = (jet) => jet > 98;

// Relevé de l'essai en production (transaction annulée, 19/11/2026).
const RELEVE = {
  cacher: [[0, false, 70], [50, false, 80], [95, false, 90], [100, false, 95], [95, true, 98]],
  fouiller: [[10, 95, false, false, 51], [10, 95, true, false, 36], [10, 95, false, true, 71], [0, 100, true, false, 15], [30, 0, false, true, 90]],
  prix: { gilet_soviet: 60, gilet_republic: 380, tenue_ninja_narco: 240, kit_crochetage_soviet: 15 }
};

test('Se cacher : 70 % + 5 par tranche de 20 de DIS, +15 ninja, plafond 98 (formule = relevé serveur)', () => {
  for (const [dis, ninja, attendu] of RELEVE.cacher) assert.equal(cacher(dis, ninja), attendu, `DIS ${dis} ninja ${ninja}`);
  assert.equal(cacher(100, false), 95);
  assert.equal(cacher(200, true), 98);
});

test('Se cacher : échec critique = deux derniers points du jet, même au plafond', () => {
  assert.ok(critique(99) && critique(100) && !critique(98));
  // Au plafond de 98, tout échec (99-100) est critique.
  for (let jet = 1; jet <= 100; jet++) if (jet > cacher(100, true)) assert.ok(critique(jet));
  assert.match(sql, /v_critique := v_roll > 100 - public\.crim_param_interne\('cacher_critique_points', 2\)/);
  assert.match(sql, /v_ok := v_roll <= v_taux AND NOT v_critique/);
  assert.match(sql, /moral = greatest\(0, coalesce\(moral, 50\) - public\.crim_param_interne\('echec_critique_moral', 15\)/);
});

test('Fouiller : 40 + 2×PER − DIS/10 − 15 ninja + 20 force de l’ordre, bornes 10-90 (formule = relevé serveur)', () => {
  for (const [per, dis, ninja, force, attendu] of RELEVE.fouiller) assert.equal(fouiller(per, dis, ninja, force), attendu);
  assert.equal(fouiller(0, 100, true, false) >= 10, true);
  assert.match(sql, /'fouiller_min', 10\), \('fouiller_max', 90\), \('fouiller_pa', 1\)/);
  assert.match(sql, /\^\(commissaire\|policier\|agent_securite\|maitre_chien\)/);
});

test('Prix Républia / Sovarka ; les autres empires reprennent Républia', () => {
  assert.equal(RELEVE.prix.gilet_soviet, 60);
  assert.equal(RELEVE.prix.gilet_republic, 380);
  assert.equal(RELEVE.prix.tenue_ninja_narco, 240);
  for (const f of ["('prix_tenue_ninja_republic', 240), ('prix_tenue_ninja_soviet', 30)", "('prix_masque_carnaval_republic', 50), ('prix_masque_carnaval_soviet', 8)",
    "('prix_kit_crochetage_republic', 80), ('prix_kit_crochetage_soviet', 15)", "('prix_pied_de_biche_republic', 40), ('prix_pied_de_biche_soviet', 8)",
    "('prix_gilet_republic', 380), ('prix_gilet_soviet', 60)", "('kit_usages', 5)"]) assert.ok(sql.includes(f), f);
});

test('Objets : habillement civil (et militaire pour la tenue), quincaillerie tracée, gilet revêtable', () => {
  assert.match(sql, /'tenue_ninja'.*'famille', 'habillement', 'sousTypes', jsonb_build_array\('civil', 'militaire'\)/);
  assert.match(sql, /'masque_carnaval'.*'revetable', 'masque'[\s\S]*?'sousTypes', jsonb_build_array\('civil'\)/);
  assert.match(sql, /IF p_cle IN \('kit_crochetage', 'pied_de_biche'\) THEN\s+INSERT INTO public\.crim_traces_achat/);
  assert.match(sql, /\('armurerie-novomirsk',\s+'soviet',\s+'capitale', 'armurerie',\s+'magasin',\s+ARRAY\['gilet'/);
  assert.match(sql, /\('chasse-peche-starovka','soviet',\s+'ville_a',\s+'armurerie',\s+'magasin',\s+ARRAY\['gilet'/);
});

test('Port : marque porte_par, un seul objet par catégorie, retiré = sans effet, gilet compté seulement revêtu', () => {
  assert.match(sql, /coalesce\(p_item ->> 'porte_par' = p_nom, false\)/);
  assert.match(sql, /v_inv := public\.crim_inventaire_devetir_interne\(d\.inventory, a, v_cat\)/);
  assert.match(sql, /WHERE public\.crim_objet_categorie_interne\(i\) = 'gilet' AND public\.crim_porte_ligne_interne\(i, p_nom\) \/\* crim_gilet_revetu_v1 \*\//);
});

test('Cachette : fin à la sortie de la pièce, conservée après une tentative (empoisonnement), vêtements rendus à l’hôpital et en détention', () => {
  assert.match(sql, /IS DISTINCT FROM \(OLD\.country, OLD\.current_city, OLD\.current_building, OLD\.current_room\) THEN\s+DELETE FROM public\.caches_pj/);
  assert.match(sql, /crim_cachette_conservee_v1/);
  assert.match(sql, /IF \(v_detenu_new AND NOT v_detenu_old\) OR v_hosp_new OR v_qhs_new THEN/);
  assert.match(sql, /crim_evenement_interne\(NEW\.name, 'demasque'/);
});

test('Présents : caché absent, masqué numéroté sans nom ni portrait, RLS de presences', () => {
  assert.match(sql, /FROM pr WHERE NOT cache/);
  assert.match(sql, /'name', 'Individu masqué n°' \|\| numero/);
  assert.match(sql, /jsonb_agg\(g - 'photoUrl'\)/);
  assert.match(sql, /USING \(name = public\.mon_personnage\(\) OR public\.crim_presence_publique_interne\(name\)\)/);
});

test('Écran : aucun jet ni calcul d’effet, boutique aux bons lieux, boutons Revêtir / Retirer', () => {
  // Le seul Math.random toléré fabrique un identifiant de requête de secours (uuid).
  assert.equal((js.match(/Math\.random/g) || []).length, 1);
  assert.match(js, /'xxxxxxxx-xxxx-4xxx-8xxx-xxxxxxxxxxxx'\.replace\(\/x\/g, \(\) => Math\.floor\(Math\.random\(\)/);
  const ctx = { console, window: {}, setTimeout() {}, setInterval() {} };
  ctx.globalThis = ctx; ctx.window = ctx;
  vm.createContext(ctx);
  vm.runInContext('var state = { country: "soviet", char: { name: "Arnie" }, inventory: [] };', ctx);
  vm.runInContext(js, ctx);
  const C = ctx.RPCriminalite;
  assert.equal(C.ordresBoutiqueDiscretion('armurerie', 'magasin', 'capitale').length, 1);
  assert.equal(C.ordresBoutiqueDiscretion('marche', 'marche_ext', 'ville_b').length, 1);
  assert.equal(C.ordresBoutiqueDiscretion('banque-nationale', 'accueil', 'capitale').length, 0);
  assert.equal(C.ordresBoutiqueDiscretion('armurerie', 'magasin', 'capitale')[0].fn, 'boutique_discretion');
  assert.ok(C.objetRevetable({ revetable: 'masque' }) && C.objetRevetable({ produitMilitaire: 'gilet_pare_balles' })
    && C.objetRevetable({ type: 'protection', name: 'Gilet pare-balles' }) && !C.objetRevetable({ type: 'outil', name: 'Kit' }));
  assert.match(ctx.boutonRevetir({ revetable: 'masque', name: 'Masque' }, 2, ''), /crimRevetir\(2\)/);
  assert.match(ctx.boutonRevetir({ revetable: 'masque', name: 'Masque', porte_par: 'Arnie' }, 2, ''), /crimRetirer\(2\)/);
  assert.equal(ctx.boutonRevetir({ type: 'outil' }, 0, ''), '');
  assert.equal(C.texte('unmaskTitle'), 'Bas les masques !');
  // La table serveur et la copie d'affichage nomment les mêmes lieux.
  for (const [pays, ville, bat, piece] of C.LIEUX_BOUTIQUE) assert.ok(new RegExp("'" + pays + "',\\s+'" + ville + "',\\s+'" + bat + "',\\s+'" + piece + "'").test(sql), bat + '/' + piece);
});
