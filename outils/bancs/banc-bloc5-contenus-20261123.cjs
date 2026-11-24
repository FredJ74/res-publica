// Bloc 5 (Fred, 23/11/2026, GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md, points 35 et 36) :
//  - 35 : la carte postale de Krasnov en vente montre « Краснов, столица медведя » ; la carte de Starovka (triptyque
//         « Привет из Старовки! ») est vendue au magasin du kolkhoze, au client comme au serveur (migration) ;
//  - 36 : l'inventaire affiche des noms propres au lieu des clés brutes (laitages, cereales, medicaments, produits_exotiques…),
//         les 18 icônes de « icones-inventaire » ; l'icône d'une carte postale est sa propre illustration.
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const R = path.resolve(__dirname, '../..');
const lire = f => fs.readFileSync(path.join(R, f), 'utf8');
const estWebp = f => { const b = fs.readFileSync(path.join(R, f)); return b.toString('ascii', 0, 4) === 'RIFF' && b.toString('ascii', 8, 12) === 'WEBP'; };

const CARTE_KRASNOV = 'images/Sovarka/Krasnov/krasnov-carte-postale-capitale-ours.webp';
const CARTE_STAROVKA = 'images/Sovarka/Starovka/starovka-carte-postale-hivernale.webp';
const ICONES = ['alcool', 'bocal-graisse-ours', 'bouteille-eau', 'carburant', 'cereales', 'dent-ours', 'extrait-casier-judiciaire',
  'extrait-domiciliation', 'groupe-electrogene', 'laitages', 'medicaments', 'oeufs', 'petrole', 'poisson', 'produits-exotiques',
  'revolver-38', 'tracts', 'viande'];

test('35 : cartes postales de Krasnov et de Starovka, au client et dans la migration', () => {
  for (const f of [CARTE_KRASNOV, CARTE_STAROVKA]) assert.ok(estWebp(f), f);
  const cat = lire('plateau-actions-illegales-rumeurs.js');
  const bloc = id => cat.slice(cat.indexOf('  ' + id + ': {'), cat.indexOf('\n  },', cat.indexOf('  ' + id + ': {')));
  assert.match(bloc('carte_krasnov_place_ours'), new RegExp("image: '" + CARTE_KRASNOV + "'"));
  assert.match(bloc('carte_krasnov_place_ours'), /pluie d\\'automne/);
  const s = bloc('carte_starovka_hiver');
  assert.match(s, new RegExp("image: '" + CARTE_STAROVKA + "'"));
  assert.match(s, /familleProduitMarche: 'carte_postale'/);
  assert.match(s, /buildingsAutorises: \['magasin-kolkhoze-starovka'\]/);
  assert.match(s, /villesAutorisees: \['ville_a'\]/);
  const sql = lire('migrations/20261123210000_bloc5_cartes_postales_sovarka.sql');
  assert.match(sql, new RegExp("SET image = '" + CARTE_KRASNOV + "'"));
  assert.match(sql, /\('carte_starovka_hiver','kolkhoze','Carte postale — Salut de Starovka'/);
  assert.match(sql, /WHERE cle = 'magasin-kolkhoze-starovka@soviet\.ville_a'/);
  assert.match(sql, /WHERE id = 'tabac-presse-soviet-ville_a-magasin-kolkhoze-starovka'/);
  assert.doesNotMatch(sql, /personnages_donnees/, 'les cartes possédées ne sont pas réécrites');
  // Légende donnée par Fred le 24/11/2026 (mission « Purge », point H.8 ; banc-ghe-h8-legendes-cartes-20261124.cjs).
  assert.match(lire('plateau-personnage.js'), /legende_carte_starovka_hiver: 'Starovka — ici, la chaleur est dans les cœurs\.',/);
});

function charger() {
  const src = lire('plateau-personnage.js');
  const debut = src.indexOf('const IMAGES_OBJETS_PAR_IDENTITE');
  const fin = src.indexOf('\n}', src.indexOf('function imageUrlObjet(item) {')) + 2;
  const ctx = vm.createContext({});
  vm.runInContext(`var RESSOURCES_ECONOMIE = ${JSON.stringify({ laitages: { label: 'Laitages' }, cereales: { label: 'Céréales & légumes' },
    medicaments: { label: 'Médicaments' }, produits_exotiques: { label: 'Produits exotiques' }, metal: { label: 'Métal' } })};
    var PRODUITS_MARCHE = ${JSON.stringify({ carte_krasnov_place_ours: { familleProduitMarche: 'carte_postale', image: CARTE_KRASNOV } })};`, ctx);
  vm.runInContext(src.slice(debut, fin), ctx);
  return ctx;
}

test('36 : noms propres des matières, icônes, illustration des cartes postales', () => {
  for (const i of ICONES) assert.ok(estWebp('images/icones-inventaire/icone-' + i + '.webp'), i);
  assert.equal(fs.readdirSync(path.join(R, 'images/icones-inventaire')).filter(f => f.endsWith('.webp')).length, 18);
  const c = charger();
  for (const [cle, nom] of [['laitages', 'Laitages'], ['cereales', 'Céréales & légumes'], ['medicaments', 'Médicaments'],
    ['produits_exotiques', 'Produits exotiques'], ['metal', 'Métal'], ['bouteille_eau', 'Bouteille d’eau']])
    assert.equal(c.nomObjetAffiche({ name: cle, stackKey: cle }), nom);
  assert.equal(c.nomObjetAffiche({ name: 'Revolver .38' }), 'Revolver .38');
  const icone = it => c.imageUrlObjet(it);
  assert.equal(icone({ name: 'laitages', stackKey: 'laitages' }), 'images/icones-inventaire/icone-laitages.webp');
  assert.equal(icone({ name: 'Viande', stackKey: 'viande' }), 'images/icones-inventaire/icone-viande.webp');
  assert.equal(icone({ name: "Bocal de graisse d'ours", type: 'graisse', graisse: 'graisse_ours' }), 'images/icones-inventaire/icone-bocal-graisse-ours.webp');
  assert.equal(icone({ name: 'Revolver .38', type: 'arme' }), 'images/icones-inventaire/icone-revolver-38.webp');
  assert.equal(icone({ name: 'Tracts POUR Arnie', type: 'tract' }), 'images/icones-inventaire/icone-tracts.webp');
  assert.equal(icone({ name: 'Extrait de casier judiciaire — Arnie', type: 'document_officiel' }), 'images/icones-inventaire/icone-extrait-casier-judiciaire.webp');
  assert.equal(icone({ name: 'Extrait de domiciliation — S.E.V.', type: 'document_officiel' }), 'images/icones-inventaire/icone-extrait-domiciliation.webp');
  assert.equal(icone({ name: 'Groupe électrogène', type: 'groupe_electrogene' }), 'images/icones-inventaire/icone-groupe-electrogene.webp');
  // Une image posée par le serveur reste prioritaire ; une carte postale montre l'illustration de son modèle.
  assert.equal(icone({ name: 'Cornet', imageUrl: 'images/port-sainte-marie-marche-friture.webp' }), 'images/port-sainte-marie-marche-friture.webp');
  assert.equal(icone({ name: 'Carte', modele: 'carte_krasnov_place_ours', imageUrl: 'images/Sovarka/Krasnov/Krasnov_place_ours.webp' }), CARTE_KRASNOV);
  // Les deux rendus d'inventaire passent par le nom affiché.
  assert.equal((lire('plateau-personnage.js').match(/nomObjetAffiche\(\{ \.\.\.item, name: typeof herosObjetTexte/g) || []).length, 2);
  assert.match(lire('plateau-divers.js'), /nomObjetAffiche\(\{ \.\.\.item, name:/);
});
