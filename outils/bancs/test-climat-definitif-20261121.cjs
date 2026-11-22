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

test('sac de sable : 60 FR, 1 PA pour le poser', () => {
  assert.match(lire('migrations/20261119100000_climat_effets.sql'), /\('prix_sac_sable', 60\)/);
  assert.match(lire('migrations/20261119100000_climat_effets.sql'), /'poser_sacs_sable', 1, 0/);
  assert.match(lire('migrations/20261121130000_climat_horaire_cadence_catastrophe_sacs.sql'), /payer_ordre\(a, 'poser_sacs_sable', 1, 0\)/);
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
  // Lieux de vente : voir le banc « parades en vente dans chaque pays » (complément du 21/11).
  assert.match(sql, /employeur_id = 'grobras-securite' AND p_pays = 'republic' AND p_ville = 'capitale'/);
  // Presse et journal (climat_texte_alerte_interne), client (climat_etat → consigne) : même source.
  assert.match(code, /'\. ' \|\| coalesce\(public\.climat_consigne_interne\(e\.type, e\.pays, e\.ville\), ''\) \/\* climat_consignes_v1 \*\//);
  assert.match(code, /'consigne', public\.climat_consigne_interne\(e\.type, e\.pays, e\.ville\)\);/);
  assert.match(client, /return \[explic\('annonce_' \+ typeConnu\(ev\), \{ lieu, heure: heureDe\(ev\.debut\) \}\), lieuxFermes\(ev\), ev\.consigne \|\| ''\]/);
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

test('pluie de l’orage : transform seul, boucle d’une tuile exacte, réduite si demandé', () => {
  assert.match(client, /@keyframes climatPluieProche\{from\{transform:translate3d\(0,0,0\)\}to\{transform:translate3d\(0,160px,0\)\}\}/);
  assert.match(client, /background-size:120px 160px/);
  assert.match(client, /@keyframes climatPluieLointaine\{from\{transform:translate3d\(0,0,0\)\}to\{transform:translate3d\(0,120px,0\)\}\}/);
  assert.match(client, /background-size:80px 120px/);
  assert.match(client, /@media \(prefers-reduced-motion: reduce\)\{#climat-filtre,#climat-filtre::before,#climat-filtre::after,#climat-alerte,#climat-alerte \.climat-picto\{animation:none!important\}\}/);
  assert.ok(!/climatPluie \.4s|background-position:-20px 40px/.test(client), 'ancienne pluie saccadée retirée');
});

// Complément du 21/11 : « une consigne ne doit jamais renvoyer vers un lieu qui n'existe pas dans le pays ».
// Rejoue, à partir des migrations, la table des vendeurs réels et celle des lieux cités ; même contrôle que
// climat_parades_verifier_interne() (appelé aussi par la migration, qui échoue s'il trouve un problème).
test('parades en vente dans chaque pays : chaque lieu cité vend vraiment, chaque parade citée existe dans le pays', () => {
  const parades = lire('migrations/20261121110000_climat_parades_vente.sql');
  const effets = lire('migrations/20261119100000_climat_effets.sql');
  const vendeurs = new Set();
  const ajoute = (pays, ville, cle) => vendeurs.add(pays + '/' + ville + '/' + cle);
  // Boutiques climat (lot 5) + bidons dans les quincailleries de Républia + sels à Pharmanov.
  for (const m of effets.matchAll(/\('([\w-]+)', +'(\w+)', +'(\w+)', +'[\w-]+', +'\w+', +ARRAY\[([^\]]+)\]\)/g))
    for (const k of m[4].match(/'(\w+)'/g).map(x => x.slice(1, -1))) ajoute(m[2], m[3], k);
  assert.match(parades, /UPDATE public\.climat_boutiques SET cles = cles \|\| ARRAY\['bidon_carburant'\]\n WHERE id IN \('armurerie-luthecia', 'armurerie-montrouge'\)/);
  ajoute('republic', 'capitale', 'bidon_carburant'); ajoute('republic', 'ville_b', 'bidon_carburant');
  assert.match(parades, /\('usine-pharma-novomirsk', 'soviet', 'capitale', 'usine-pharmaceutique-luthecia', 'salle_ventes', ARRAY\['sels_rehydratation'\]\)/);
  ajoute('soviet', 'capitale', 'sels_rehydratation');
  // Points de vente des médicaments, station-service de Krasnov, fontaine de la place de l'Ours.
  for (const f of ['migrations/20261118060000_maladies_socle.sql', 'migrations/20261118061000_maladies_boissons_repartition.sql'])
    for (const m of lire(f).matchAll(/\('[\w-]+', +'(republic|soviet)', +'(\w+)', +'[\w-]+', +'\w+'/g)) ajoute(m[1], m[2], 'sels_rehydratation');
  assert.match(lire('migrations/20261105222000_vehicules_socle.sql'), /'type', 'station-service', 'country', 'soviet', 'city', 'ville_b'/);
  ajoute('soviet', 'ville_b', 'bidon_carburant');
  // Réponses de Fred du 21/11 : bidons aussi au garage de Novomirsk (groupe et carburant au même endroit).
  const sovarka = lire('migrations/20261121120000_climat_parades_sovarka.sql');
  assert.match(sovarka, /UPDATE public\.climat_boutiques SET cles = cles \|\| ARRAY\['bidon_carburant'\]\n WHERE id = 'garage-novomirsk'/);
  ajoute('soviet', 'capitale', 'bidon_carburant');
  ajoute('soviet', 'ville_b', 'bouteille_eau');
  // Lieux cités : ceux du matin (eau, sacs), groupe et sels remplacés par le complément.
  const cites = [];
  const matin = sql.split('INSERT INTO public.climat_lieux_vente')[1].split(';')[0];
  for (const m of matin.matchAll(/\('(\w+)', +'(\w+)', +'(\w+)', +'((?:[^']|'')+)'\)/g)) if (!['groupe_electrogene', 'sels_rehydratation'].includes(m[1])) cites.push(m.slice(1, 5));
  assert.match(parades, /DELETE FROM public\.climat_lieux_vente WHERE cle IN \('groupe_electrogene', 'sels_rehydratation'\);/);
  for (const m of parades.split('INSERT INTO public.climat_lieux_vente')[1].split(';')[0].matchAll(/\('(\w+)', +'(\w+)', +'(\w+)', +'((?:[^']|'')+)'\)/g)) cites.push(m.slice(1, 5));
  assert.ok(cites.length >= 9);
  for (const [cle, pays, ville, chez] of cites) assert.ok(vendeurs.has(pays + '/' + ville + '/' + cle), `${pays} : « ${chez} » ne vend pas ${cle}`);
  // Chaque parade des consignes des événements actifs du pays est en vente quelque part dans le pays.
  const types = { republic: ['crue', 'canicule', 'orage', 'brouillard'], soviet: ['orage', 'brouillard', 'blizzard'] };
  const paradesDe = { orage: ['groupe_electrogene', 'bidon_carburant'], crue: ['sac_de_sable'], canicule: ['bouteille_eau', 'sels_rehydratation'] };
  for (const [pays, ts] of Object.entries(types)) for (const t of ts) for (const cle of paradesDe[t] || [])
    assert.ok([...vendeurs].some(v => v.startsWith(pays + '/') && v.endsWith('/' + cle)), `${pays} : ${cle} (${t}) introuvable`);
  // Textes de Fred : quincaillerie de la ville, usine pharmaceutique ou pharmacie ; nom de la ville toujours présent.
  assert.match(parades, /'à la quincaillerie de Luthécia \(Armurerie Martinon\)'/);
  assert.match(parades, /'à l''usine pharmaceutique de Novomirsk \(Pharmanov\)'/);
  assert.match(parades, /\|\| ' ou ', ''\) \|\| 'dans une pharmacie\.' \/\* climat_parades_v1 \*\//);
  assert.match(parades, /IF EXISTS \(SELECT 1 FROM public\.climat_parades_verifier_interne\(\)\) THEN\n    RAISE EXCEPTION/);
  // Objets identiques à ceux des commerces existants.
  assert.match(parades, /WHEN 'bidon_carburant' THEN jsonb_build_object\('name', 'carburant', 'stackKey', 'carburant'/);
  assert.match(parades, /'stackKey', 'medicament_sels_rehydratation'/);
});

test('réponses de Fred : sels à moitié prix en Sovarka, groupe et bidons au même endroit, contrôle complété', () => {
  const m = lire('migrations/20261121120000_climat_parades_sovarka.sql');
  assert.match(m, /WHEN p_cle_maladie = 'coup_de_chaleur' AND p_pays = 'soviet'\n +THEN greatest\(1, round\(public\.pharmacie_prix_interne\(p_cle_maladie\) \/ 2\.0\)\)::integer/);
  // Partout où les sels se vendent en Sovarka : boutique climat (Pharmanov) et pharmacie d'État.
  for (const f of ['boutique_climat_acheter', 'boutique_climat_etat', 'pharmacie_acheter_interne', 'pharmacie_etat'])
    assert.ok(m.includes("pg_temp.rp_raccorder('public." + f), f);
  assert.match(m, /', en vente au même endroit'/);
  assert.match(m, /'bidons absents du lieu du groupe électrogène : '/);
  // Port-Sainte-Marie : toujours renvoyée aux quincailleries de Luthécia et de Montrouge (aucune ligne pour ville_a).
  const parades = lire('migrations/20261121110000_climat_parades_vente.sql');
  assert.ok(!/\('groupe_electrogene', 'republic', 'ville_a'/.test(parades + m));
  assert.match(m, /IF EXISTS \(SELECT 1 FROM public\.climat_parades_verifier_interne\(\)\) THEN/);
});
