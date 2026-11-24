// Mission « Purge », bloc C (Fred, 24/11/2026) : fenêtre du chantier simplifiée et lot 3 de Luthécia.
// Contrôles statiques (sources du dépôt). Les contrôles au navigateur sont dans banc-purge-c-chantier-navigateur-20261124.cjs,
// la lecture serveur dans banc-purge-c-chantier-pglite-20261124.cjs.
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const racine = path.resolve(__dirname, '../..');
const lire = f => fs.readFileSync(path.join(racine, f), 'utf8');

test('C.6 : le lot 3 de Luthécia s’appelle « Terrain à bâtir », plus aucun « Lot de la Châtaigneraie (… m²) »', () => {
  const data = lire('data.js');
  const debut = data.indexOf("'terrain-a-batir-3': {");
  assert.ok(debut > 0, 'entrée terrain-a-batir-3 absente');
  const bloc = data.slice(debut, data.indexOf("'caserne-militaire'", debut));
  assert.match(bloc, /desc: "Terrain à bâtir",/);
  assert.doesNotMatch(data, /Lot de la Châtaigneraie \(/);
  // Ancien libellé : aucun renvoi actif (quêtes, aide, i18n, bancs) ne doit encore le citer.
  for (const f of ['api/_aide-themes.js', 'plateau-terrains-plan.js', 'plateau-chantier-vue.js', 'plateau-pnj.js']) {
    if (fs.existsSync(path.join(racine, f))) assert.doesNotMatch(lire(f), /Lot de la Châtaigneraie/, f);
  }
});

test('C.3 : plus aucun renvoi vers l’ancien onglet « Stock de matériaux » dans les textes affichés', () => {
  const js = lire('plateau-chantier-vue.js');
  const textes = js.slice(js.indexOf('const TXT4 = {'), js.indexOf('const t4 ='));
  assert.doesNotMatch(textes.replace(/o_stock: '[^']*'/, ''), /onglet « Stock de matériaux »|onglet « Main-d’œuvre »|onglet « Gestion »/);
  assert.match(textes, /onglet « Participer », « Vendre mes matériaux au chantier »/);
});
