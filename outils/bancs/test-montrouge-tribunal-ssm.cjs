// Régression : l'accès au tribunal reste sur une scène dédiée après le marché.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../..');
const rue = fs.readFileSync(path.join(root, 'plateau-rue-centrale.js'), 'utf8');
const data = fs.readFileSync(path.join(root, 'data.js'), 'utf8');
test('image et aller-retour de la rue du tribunal de Montrouge', () => {
  const image = path.join(root, 'images/montrouge/montrouge-rue-tribunal-ssm.webp');
  assert.ok(fs.existsSync(image), 'illustration de la rue absente');
  const marche = rue.slice(rue.indexOf("'montrouge-vue-13':"), rue.indexOf("'montrouge-tribunal-ssm':"));
  assert.match(marche, /arriere: 'montrouge-tribunal-ssm'/);
  const scene = rue.slice(rue.indexOf("'montrouge-tribunal-ssm':"), rue.indexOf('// NOVOMIRSK'));
  assert.match(scene, /image: 'images\/montrouge\/montrouge-rue-tribunal-ssm\.png'/);
  assert.match(scene, /arriere: 'montrouge-vue-13'/);
  assert.doesNotMatch(scene, /toutDroit:|gauche:|droite:/);
  for (const id of ['tribunal-local', 'services-sociaux-montrouge', 'parking-tribunal-montrouge']) {
    assert.match(scene, new RegExp("buildingId: '" + id + "'"));
  }
});
test('SSM et parking restent visitables ; seul le SSM obtient ses nouveaux ordres', () => {
  for (const id of ['services-sociaux-montrouge','parking-tribunal-montrouge']) {
    const start = data.indexOf("  '" + id + "': {");
    assert.ok(start >= 0, 'batiment absent ' + id);
    const block = data.slice(start, data.indexOf("\n  },", start) + 5);
    assert.match(block, /rooms:\s*\{\s*accueil:/);
    if (id === 'parking-tribunal-montrouge') assert.match(block, /orders: \[\]/);
    else { assert.match(block, /fn:'ssm_demander_rendezvous'/); assert.match(block, /fn:'demander_logement_social'/); }
  }
});

test('parking : WebP authentique et deux PNJ raccordés, sans nouvel ordre', () => {
  const image = path.join(root,'images/montrouge/montrouge-parking.webp');
  assert.ok(fs.existsSync(image),'image parking WebP absente');
  assert.equal(fs.readFileSync(image).toString('ascii',8,12),'WEBP','format réel non WebP');
  const start=data.indexOf("  'parking-tribunal-montrouge': {");
  const end=data.indexOf("\n  },",start);
  assert.ok(start>=0&&end>start);
  const block=data.slice(start,end);
  assert.ok(block.includes("imageUrl: 'images/montrouge/montrouge-parking.webp'"));
  assert.match(block,/name:'Jean Tarte'.*job:'agent_securite'/);
  assert.match(block,/name:'Basile Decoq'.*job:'criminel'/);
  assert.ok(block.includes('orders: []'));
  for (const [nom,fichier] of [['Jean Tarte','jean-tarte.webp'],['Basile Decoq','basile-decoq.webp']]) {
    const photo=path.join(root,'images/personnages',fichier);
    assert.ok(fs.existsSync(photo),'portrait manquant : '+fichier);
    assert.equal(fs.readFileSync(photo).toString('ascii',8,12),'WEBP','portrait non WebP : '+fichier);
    const ligne=block.split('\n').find(l=>l.includes("name:'"+nom+"'"));
    assert.ok(ligne,'personnage absent : '+nom);
    assert.ok(ligne.includes("photoUrl:'images/personnages/"+fichier+"'"),'portrait non raccordé : '+nom);
  }
  const profiles=fs.readFileSync(path.join(root,'api/_pnj-personnalites.js'),'utf8');
  assert.match(profiles,/'jean_tarte':\s*\{ nom: "Jean Tarte"/);
  assert.match(profiles,/'basile_decoq':\s*\{ nom: "Basile Decoq"/);
});
