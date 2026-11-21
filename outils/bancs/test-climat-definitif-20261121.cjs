'use strict';
// Climat — version définitive des décisions de Fred du 21/11/2026 (GAME-DESIGN-CLIMAT-20261121.md, point 9).
// Le comportement réel a été essayé en production dans des transactions annulées : aucun chevauchement par pays après
// espacement, lieu protégé ouvert et stock identique, lieu non protégé fermé, remplissage gratuit à la fontaine.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root = path.resolve(__dirname, '../..');
const lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const sql = lire('migrations/20261121090000_climat_six_heures_pays_sacs_eau.sql');
const client = lire('plateau-climat.js');
const code = sql.replace(/^--.*$/gm, '');

test('déplacements libres pendant une crue : seul le refus d’entrer dans un lieu fermé subsiste', () => {
  const effets = lire('migrations/20261119100000_climat_effets.sql');
  assert.match(effets, /IF p_mode='piece' AND public\.climat_batiment_inonde_interne\(/);
  assert.ok(!/rue_position|navigation_rue_trajet|navigation_commander/.test(code), 'aucune entrave ajoutée aux déplacements');
});

test('gare jamais tirée (raccord conservé)', () => {
  assert.match(lire('migrations/20261121070000_climat_douze_heures_gare_accueil.sql'), /NOT public\.climat_lieu_est_gare_interne\(batiment\) \/\* climat_gare_jamais_v1 \*\//);
});

test('lieu protégé ouvert, stocks intacts ; lieu non protégé fermé (20 %)', () => {
  assert.match(code, /AND NOT public\.climat_lieu_protege_interne\(e, p_batiment\) \/\* climat_sacs_protegent_v1 \*\//);
  assert.match(code, /v_pct := CASE WHEN v_prot THEN 0 ELSE public\.aliments_param_interne\('crue_perte_pct', 20\) END;/);
  assert.match(code, /VALUES \('sacs_plafond', 1\)\nON CONFLICT \(cle\) DO UPDATE SET valeur = 1;/);
  assert.match(code, /zp\.evenement = e\.id OR \(zp\.evenement IS NULL AND e\.effets_le IS NULL\)/);
  // Le client ne marque que les lieux fermés et nomme les lieux protégés.
  assert.match(code, /'lieux', \(SELECT [^;]*WHERE NOT public\.climat_lieu_protege_interne\(e, l->>'batiment'\)\)/);
  assert.match(client, /lieux_proteges: 'Protégés par des sacs de sable, donc ouverts : \{lieux\}\.'/);
});

test('6 heures pour crue, orage, canicule, brouillard ; blizzard inchangé', () => {
  assert.match(code, /UPDATE public\.climat_parametres SET duree_heures = 6 WHERE type IN \('crue', 'orage', 'canicule', 'brouillard'\);/);
  assert.match(code, /SET fin = debut \+ interval '6 hours'\n WHERE type IN \('crue', 'orage', 'canicule', 'brouillard'\) AND fin_traitee_le IS NULL/);
  assert.ok(!/duree_heures = \d+ WHERE type IN \([^)]*blizzard/.test(code));
});

// Réplique JS de climat_espacer_interne (jours entiers, heure de Paris négligée) : la règle elle-même.
function espacer(episodes, preavisH = 48) {
  const tries = [...episodes].sort((a, b) => a.d0 - b.d0 || b.n - a.n || a.id - b.id);
  let borne = -Infinity;
  for (const e of tries) {
    if (!e.commence && borne > -Infinity) {
      const jourMin = Math.ceil(borne / 24) * 24;
      const delta = jourMin - e.d0;
      if (delta > 0) { e.d0 += delta; e.f1 += delta; e.reporte = true; }
    }
    borne = Math.max(borne, e.f1 + preavisH);
  }
  return tries;
}
test('un seul événement à la fois par pays, jamais deux alertes simultanées', () => {
  assert.match(code, /'reportes', public\.climat_espacer_interne\('republic'\) \+ public\.climat_espacer_interne\('soviet'\)/);
  assert.ok(code.indexOf("'reportes'") < code.indexOf("'alertes', public.climat_alertes_publier_interne()"), 'espacer avant de publier');
  assert.match(code, /v_borne := greatest\(v_borne, r\.f1 \+ make_interval\(hours => r\.preavis\)\);/);
  assert.match(code, /alerte_le = NULL/);
  // Cette nuit (22/11) : canicule propagée et brouillard à Luthécia le même jour → le brouillard attend.
  const h = j => j * 24;
  const res = espacer([
    { id: 7, d0: h(0), f1: h(5) + 6, n: 3 },          // canicule : 22/11, 25/11, 27/11
    { id: 25, d0: h(0), f1: h(0) + 6, n: 1 },         // brouillard Luthécia 22/11
    { id: 27, d0: h(2), f1: h(2) + 6, n: 1 },         // brouillard 24/11
    { id: 13, d0: h(6), f1: h(10) + 6, n: 3 },        // orage propagé
  ]);
  for (let i = 1; i < res.length; i++) {
    // Début de l'un ≥ fin du précédent + 48 h : l'alerte (48 h avant) ne paraît qu'après la fin du précédent.
    assert.ok(res[i].d0 - 48 >= res[i - 1].f1, `${res[i].id} après ${res[i - 1].id}`);
  }
  assert.deepEqual(res.map(e => e.id), [7, 25, 27, 13]);
  assert.equal(res[1].d0, h(8), 'brouillard reporté au 30/11 (fin canicule 27/11 6 h + 48 h → minuit suivant)');
  // Un épisode commencé ne bouge jamais.
  const fixe = espacer([{ id: 1, d0: 0, f1: 30, n: 2, commence: true }, { id: 2, d0: 10, f1: 16, n: 1, commence: true }]);
  assert.ok(!fixe.some(e => e.reporte));
});

test('consignes : textes de Fred, lieux de vente vérifiés, un seul texte serveur pour toutes les alertes', () => {
  for (const fragment of [
    'Pendant 6 heures, ordinateurs, box et caméras sont hors service : plus de surveillance, de trading à distance ni de piratage, ',
    'Pendant 6 heures, les commerces et entrepôts non protégés de la zone inondable sont fermés et perdent ',
    ' (1 PA, valables pour une crue). Les lieux protégés restent ouverts. La gare et tous les déplacements restent libres.',
    'Toute personne présente en ville perd 3 PA, et la nourriture portée sur soi devient insalubre. ',
    "'Remplissez-la gratuitement à ' || nom || '.'", "'En vente ' || v_vente || '.'",
    'pensez à engager un agent de sécurité dans une agence de sécurité',
    "de castor chez la poissonnière de Novomirsk, ou dans une pharmacie tenue par un joueur.",
  ]) assert.ok(sql.includes(fragment), fragment);
  // Corrections : pas de garagiste ni de « pharmacie » en Républia.
  assert.match(sql, /\('groupe_electrogene', 'republic', 'capitale', 'à l''Armurerie Martinon, à Luthécia'\)/);
  assert.match(sql, /\('groupe_electrogene', 'soviet', +'capitale', 'au Garage de Novomirsk'\)/);
  assert.match(sql, /\('sels_rehydratation', 'republic', 'ville_b', +'à l''entrepôt logistique de Montrouge'\)/);
  assert.match(sql, /employeur_id = 'grobras-securite' AND p_pays = 'republic' AND p_ville = 'capitale'/);
  // Presse et journal (climat_texte_alerte_interne), client (climat_etat → consigne) : même source.
  assert.match(code, /'\. ' \|\| coalesce\(public\.climat_consigne_interne\(e\.type, e\.pays, e\.ville\), ''\) \/\* climat_consignes_v1 \*\//);
  assert.match(code, /'consigne', public\.climat_consigne_interne\(e\.type, e\.pays, e\.ville\)\);/);
  assert.match(client, /return \[explic\('annonce_' \+ typeConnu\(ev\), \{ lieu \}\), lieuxFermes\(ev\), ev\.consigne \|\| ''\]/);
});

test('eau gratuite : point d’eau en configuration, 0 PA, bouteille identique', () => {
  assert.match(sql, /\('krasnov-fontaine-ours', 'soviet', 'ville_b', 'krasnov-place-ours', 'la fontaine de la statue de l''Ours, place de l''Ours'\)/);
  const fn = code.split('FUNCTION public.point_eau_remplir')[1].split('END $$;')[0];
  assert.ok(!/payer_ordre/.test(fn), 'aucun PA ni argent');
  assert.match(fn, /public\.climat_objet_interne\('bouteille_eau', 1\)/);
  assert.match(fn, /pe\.noeud = d\.current_street/);
  assert.match(fn, /d\.current_building IS NOT NULL/);
  assert.match(code, /GRANT EXECUTE ON FUNCTION public\.climat_points_eau_lister\(\), public\.point_eau_remplir\(uuid\) TO authenticated;/);
});

test('client : alerte pictogramme, fenêtre durée puis consigne, accueil, annonce reportée revue', () => {
  const ctx = { console, Date, setTimeout, setInterval: () => 0, clearInterval() {}, document: undefined };
  ctx.window = ctx; ctx.globalThis = ctx;
  vm.createContext(ctx);
  vm.runInContext(client, ctx);
  const R = ctx.RPClimat;
  for (const t of R.TYPES) {
    assert.match(R.pictogramme(t), /fill="#FFD200" stroke="#111"/, t);
    assert.equal(R.ALERTES.fr[t], 'Attention : ' + t);
  }
  assert.match(client, /const cleVu = \(id, debut\) =>/);
  assert.match(R.explic('accueil_intro', { evenement: 'crue' }), /Un événement climatique frappe la ville en ce moment \(crue\)/);
});
