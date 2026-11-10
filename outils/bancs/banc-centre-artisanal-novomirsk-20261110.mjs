// Images locales du centre artisanal de Novomirsk : aucun bail ou ordre nouveau.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const racine = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const lire = p => fs.readFileSync(path.join(racine, p), 'utf8');
const ctx = vm.createContext({});
vm.runInContext(lire('data.js'), ctx);
const monde = vm.runInContext('WORLD', ctx);
const batiment = monde.soviet.capitale.buildingContext['centre-artisanal'];
const rooms = {
  travees: 'accueil',
  echoppe_facade: 'grand atelier',
  atelier_milieu: 'moyen local',
  reserve_arriere: 'petit local'
};
test('Novomirsk : accueil et trois locaux WebP réellement présents et décodables', () => {
  assert.equal(Object.keys(batiment.roomOverrides).length, 4);
  for (const [piece, identifiant] of Object.entries(rooms)) {
    const url = 'images/Sovarka/Novomirsk/Novomirsk_centre artisanal_' + identifiant + '.webp';
    assert.equal(batiment.roomOverrides[piece].imageUrl, url);
    assert.ok(fs.existsSync(path.join(racine, url)), 'WebP absent : ' + url);
    assert.equal(fs.existsSync(path.join(racine, url.replace(/\.webp$/, '.png'))), false);
    const contenu = fs.readFileSync(path.join(racine, url));
    assert.equal(contenu.toString('ascii', 0, 4), 'RIFF');
    assert.equal(contenu.toString('ascii', 8, 12), 'WEBP');
    assert.ok(contenu.length > 100000 && contenu.length < 1000000);
  }
});
test('Pas de nouvelle pièce ou de bail : les trois identifiants du socle demeurent', () => {
  assert.ok(monde.soviet.capitale.buildings.includes('centre-artisanal'));
  for (const id of ['echoppe_facade', 'atelier_milieu', 'reserve_arriere']) {
    assert.ok(vm.runInContext('BUILDINGS["centre-artisanal"].rooms', ctx)[id]);
  }
});
test('Aucun image locale de Novomirsk propagée à Republia ni aux autres villes', () => {
  const nouveau = 'Novomirsk_centre artisanal_';
  for (const [pays, villes] of Object.entries(monde)) {
    for (const [ville, villeData] of Object.entries(villes)) {
      if (pays === 'soviet' && ville === 'capitale') continue;
      const c = villeData?.buildingContext?.['centre-artisanal'];
      assert.ok(!JSON.stringify(c || {}).includes(nouveau), pays + '/' + ville);
    }
  }
});
test('Le navigateur recharge le catalogue des salles et conserve les scripts existants', () => {
  const html = lire('plateau.html');
  assert.match(html, /data\.js\?v=[^"]*artisanal-novomirsk-20261110/);
});
