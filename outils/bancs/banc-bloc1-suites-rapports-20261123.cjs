// Bloc 1 de la mission « Novomirsk, PNJ, interface et suites des rapports » (Fred, 23/11/2026,
// GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md, points 2 à 13). Chaque décision est vérifiée à la source (document de
// game design) ET dans le code, pour qu'elle ne revienne pas.
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const R = path.resolve(__dirname, '..', '..');
const lire = f => fs.readFileSync(path.join(R, f), 'utf8');
const MIG = lire('migrations/20261123200000_bloc1_paiements_tarifs_usines.sql');
function extraire(src, debut) {
  const i = src.indexOf(debut); if (i < 0) throw new Error(debut + ' introuvable');
  let j = src.indexOf('{', i), prof = 0;
  for (; j < src.length; j++) { if (src[j] === '{') prof++; else if (src[j] === '}' && --prof === 0) break; }
  return src.slice(i, j + 1);
}

test('point 2 : onglet Organisations, toutes les organisations du joueur avec leur pays ; message accentué et propre à Sovarka', () => {
  const src = lire('plateau-organisations-quetes.js');
  const f = extraire(src, 'function renderOngletOrgas()');
  assert.doesNotMatch(f, /getMesOrgasPays\(\)/, 'plus de filtre sur le pays où se trouve le PJ');
  assert.match(f, /\(state\.organisations \|\| \[\]\)\.filter/);
  assert.match(f, /hg-orga-pays/);
  assert.match(f, /Vous n\\'appartenez à aucune organisation\./);
  assert.match(f, /En Sovarka, demandez d\\'abord un local à la mairie/);
  assert.doesNotMatch(f, /appartenez a aucune|creez votre organisation depuis "Gerer/);
  // Exécution : Arnie en Sovarka voit le S.E.V. de Républia.
  const ctx = { state: { country: 'soviet', char: { name: 'Arnie' }, organisations: [
    { id: 'sev', nom: 'S.E.V.', type: 'x', country_origine: 'republic', chef: 'Arnie', membres: [{ nom: 'Arnie', grade: 'Confédéral' }] },
    { id: 'autre', nom: 'Autre', type: 'x', country_origine: 'soviet', chef: 'Z', membres: [{ nom: 'Z' }] }] },
    COUNTRIES: { republic: { n: 'Republia', cur: 'FR' }, soviet: { n: 'Sovarka', cur: 'PSK' } }, TYPES_ORGANISATIONS: {},
    escapeHtmlText: s => s, orgaCreationTypeHtml: () => '', commercePjEchapper: s => s };
  vm.createContext(ctx); vm.runInContext(f + '\nthis.rendu = renderOngletOrgas();', ctx);
  assert.match(ctx.rendu, /S\.E\.V\./); assert.match(ctx.rendu, /Républia/); assert.match(ctx.rendu, /FR/);
  assert.doesNotMatch(ctx.rendu, /Autre/, 'seulement les organisations dont il est membre');
});

test('point 3 : fiche Identité, pays du personnage (nationalité) et accents des postes', () => {
  const src = lire('plateau-personnage.js');
  assert.match(src, /const paysPJ = state\.nationalite \|\| char\?\.nationalite \|\| ligneAnnuaire\?\.nationalite \|\| state\.country;/);
  assert.match(lire('plateau-core.js'), /function nomPaysAffiche\(c\)[\s\S]{0,80}republic: 'Républia'/);
  const data = lire('data.js');
  for (const l of ["label: 'Ministre de la Défense'", "label: \"Ministre de l'Intérieur\"", "label: 'Ministre des Affaires Étrangères'"]) assert.ok(data.includes(l), l);
  assert.ok(!data.includes("label: 'Ministre de la Defense'"));
});

test('point 4 : présentation mobile, plus de sous-titre « RES PUBLICA », Santé et Moral toujours visibles', () => {
  assert.doesNotMatch(lire('plateau-mobile-prototype.css'), /content:'RES PUBLICA'/);
  const html = lire('plateau.html');
  assert.match(html, /<span id="hg-identite-sante"><small>Santé<\/small>/);
  assert.match(html, /<span id="hg-identite-moral"><small>Moral<\/small>/);
  assert.match(lire('plateau-mobile-identite-20261117.js'), /dst\[key\]\.hidden=false;/);
});

test('point 5 : taxi du QHS masqué en Sovarka tant que le goulag est verrouillé (écran et serveur)', () => {
  const data = lire('data.js');
  assert.match(data, /roomOverrides: \{ hall_gare: \{ excludeOrders: \['taxi_caserne'\], masquerSiGoulagFerme: \['taxi_qhs'\] \} \}/);
  const f = extraire(data, 'function ordresDeclaresDeLaPiece(');
  const piece = { orders: [{ fn: 'prendre_train' }, { fn: 'taxi_caserne' }, { fn: 'taxi_qhs' }] };
  const ctxSov = { roomOverrides: { hall_gare: { excludeOrders: ['taxi_caserne'], masquerSiGoulagFerme: ['taxi_qhs'] } } };
  for (const [ouvert, attendu] of [[undefined, ['prendre_train']], [false, ['prendre_train']], [true, ['prendre_train', 'taxi_qhs']]]) {
    const ctx = { window: ouvert === undefined ? {} : { goulagOuvert: () => ouvert } };
    vm.createContext(ctx); vm.runInContext(f + '\nthis.r = ordresDeclaresDeLaPiece(' + JSON.stringify(piece) + ',' + JSON.stringify(ctxSov) + ',"hall_gare").map(o => o.fn);', ctx);
    assert.deepEqual(JSON.parse(JSON.stringify(ctx.r)), attendu, 'goulag ouvert = ' + ouvert);
  }
  assert.match(MIG, /IF p_mode = 'taxi_qhs' AND p\.country = 'soviet' AND NOT coalesce\(public\.sovarka_goulag_ouvert\(\), false\) THEN RETURN jsonb_build_object\('ok',false,'raison','goulag_ferme'\)/);
  assert.doesNotMatch(MIG, /UPDATE public\.sovarka_goulag|INSERT INTO public\.sovarka_goulag|sovarka_goulag_configuration/, 'le goulag n’est pas touché');
});

test('point 6 : paiements en liquide ; seules les deux taxes automatiques gardent « liquide, puis banque »', () => {
  const liquide = ['boutique_climat_acheter', 'boutique_discretion_acheter', 'contrebande_poissonniere_interne', 'furet_acheter', 'graisse_acheter',
    'pharmacie_bandelettes_acheter', 'pnj_debaucher', 'poissonniere_poisson_interne', 'sovarka_parti_commande', 'football_pari_engager',
    'football_pari_playoff_engager', 'marche_krasnov_valider', 'sovarka_bon_etat_souscrire', 'terrain_squatteurs_don', 'argent_mouvement_serveur'];
  for (const f of liquide) assert.ok(MIG.includes(f), f);
  assert.doesNotMatch(MIG, /'public\.(taxe_fonciere_prelever|cotisation_renouveler)/, 'exceptions : prélèvements automatiques');
  const doc = lire('GAME-DESIGN-SANTE-20261122.md');
  assert.match(doc, /Tous les paiements du jeu se font en liquide\.\*\* Seuls les \*\*prélèvements automatiques\*\* \(`taxe_fonciere_prelever`, `cotisation_renouveler`\)/);
});

test('point 7 : le reversement de l’excédent des entrepôts tourne à minuit', () => {
  assert.match(lire('api/cron-minuit.js'), /tacheQuotidienne\('entrepots_reverser_excedent', async \(\) => \(await sbRpc\('entrepots_reverser_excedent', \{\}, HEADERS_SERVICE\)\)/);
});

test('point 8 : dotation initiale de plantes des usines, une seule fois, quantité réglable par le MJ', () => {
  assert.match(MIG, /\('usine_plantes_dotation_initiale', 2000, 'usines'/);
  assert.match(MIG, /IF v_usine \? 'dotationPlantesInitiale' THEN CONTINUE; END IF;/);
  assert.match(MIG, /FOREACH p IN ARRAY ARRAY\['republic', 'soviet'\]/);
});

test('point 9 : les PNJ des usines ne sont pas payés (seuls ceux des chantiers consomment la caisse) — à la source', () => {
  assert.match(lire('GAME-DESIGN-SANTE-20261122.md'), /\*\*Les PNJ des usines ne sont pas payés\*\* : seuls les PNJ des chantiers de construction consomment l'argent de la caisse\./);
  const usines = lire('migrations/20261123110000_medicaments_usines_antidote.sql');
  const pnj = usines.slice(usines.indexOf('CREATE OR REPLACE FUNCTION public.medicaments_pnj_produire_interne'));
  const corps = pnj.slice(0, pnj.indexOf('$function$;'));
  assert.doesNotMatch(corps, /salaire|caisse/, 'la production de nuit des PNJ ne paie aucun salaire');
});

test('point 10 : « Inspecter la pièce » s’ouvre à 0 PA ; chaque option affiche son tarif', () => {
  const src = lire('plateau-surveillance.js');
  const f = extraire(src, 'function ordresFouillerVoler(');
  assert.match(f, /\{ \.\.\.OUVERTURE_INSPECTION, fn: 'inspecter_piece', label: pieceTxt\('inspecter'\),/);
  assert.match(f, /const OUVERTURE_INSPECTION = \{ pa: 0, cost: 0,/);
  assert.match(src, /const TARIF_FOUILLE = \{ fn: 'inspecter_piece', label: 'Fouiller les lieux', pa: 1, cost: 0 \};/);
  assert.match(lire('baseline/seeds/95_a-regenerer/ordres_couts.sql'), /\('inspecter_piece',1,0\)/);
  assert.doesNotMatch(lire('baseline/seeds/95_a-regenerer/ordres_couts.sql'), /\('inspecter_piece',0,0\)/);
  for (const b of ["fouillerBouton: 'Fouiller (1 PA)'", "desinstallerBouton: 'Désinstaller (2 PA)'", "volerBouton: 'Voler (2 PA)'"]) assert.ok(src.includes(b), b);
  assert.doesNotMatch(src, /pieceTxt\('inspecterRue'\) \+ ' <span style="opacity:\.7">\(1 PA\)<\/span>/);
  assert.match(lire('GAME-DESIGN-INTERFACE-ACCUEIL-20261122.md'), /ouvrir la fenêtre coûte \*\*0 PA\*\*/);
});

test('point 11 : « Voler » proposé en face du matériel d’autrui, même chez soi (colocataire) — à la source', () => {
  assert.match(lire('GAME-DESIGN-CRIMINALITE.md'), /« Voler » reste proposé en face du matériel d'autrui, \*\*même chez soi\*\* : le matériel d'un colocataire ne lui appartient pas, c'est un vol avec sa trace\./);
  const src = lire('plateau-surveillance.js');
  const volable = src.match(/const pieceVolable = m => [^\n]+/)[0];
  assert.doesNotMatch(volable, /chez_soi/, 'chez soi ne retire pas « Voler »');
  assert.match(MIG + lire('migrations/20261123130000_ordres_regroupes.sql'), /'volable', e\.generique_id <> 'armoire_souvenirs' AND NOT public\.equipement_a_moi_interne\(e\.proprietaire, a\)/);
});

test('point 12 : rébellion 1 PA et répression 1 PA (Républia et Sovarka), écran et serveur', () => {
  const data = lire('data.js');
  assert.equal((data.match(/\{fn:'se_rebeller', +label:'Se rebeller', +pa:1, cost:0,/g) || []).length, 2);
  assert.doesNotMatch(data, /fn:'se_rebeller'[^}]*pa:2/);
  const gouv = lire('plateau-gouvernement.js');
  assert.match(gouv, /\{ label: 'Réprimer une manifestation', pa: 1,/); assert.match(gouv, /ouvrirReprimerManif\(1,0\)/);
  assert.match(lire('plateau-sovarka-pouvoir.js'), /vehBouton\('Réprimer \(1 PA\)'/);
  for (const fn of ['se_rebeller', 'reprimer_manif', 'sovarka_manif_reprimer']) assert.match(MIG, new RegExp("UPDATE public\\.ordres_couts SET pa = 1 WHERE fn = '" + fn + "'"));
  assert.match(MIG, /payer_ordre\(v_moi, 'reprimer_manif', 1, 0\)/);
  assert.match(MIG, /payer_ordre_interne\(a, 'sovarka_manif_reprimer', 1, 0\)/);
});

test('point 13 : la ligne desinstaller_materiel quitte ordres_couts ; aucun bouton de pièce ne la rappelle', () => {
  assert.match(MIG, /DELETE FROM public\.ordres_couts WHERE fn = 'desinstaller_materiel';/);
  assert.doesNotMatch(lire('data.js'), /fn:\s*'desinstaller_materiel'/);
  assert.doesNotMatch(lire('baseline/seeds/95_a-regenerer/ordres_couts.sql'), /'desinstaller_materiel'/);
});

test('bloc 0 : décisions consignées à la source', () => {
  const doc = lire('GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md');
  for (let n = 1; n <= 47; n++) assert.match(doc, new RegExp('^' + n + '\\. ', 'm'), 'point ' + n);
  assert.match(lire('RELAIS.md'), /Correctif `window\.state` \(Claude, 23\/11\/2026, commit `f40e7413`\)/);
});
