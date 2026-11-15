import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {fileURLToPath} from 'node:url';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const scenes=[
  ['Krasnov_maison_kouzma_interieur.webp','maison-krasnov-eglise'],
  ['Krasnov_eglise_sainte_moisson_interieur.webp','kolkhoze-spirituel']
];

test('Krasnov : deux images WebP avec perte disponibles, PNG des décors supprimés et portraits préservés',()=>{
  const dir=path.join(root,'images/Sovarka/Krasnov');
  for (const [name] of scenes) {
    const p=path.join(dir,name);
    const bytes=fs.readFileSync(p);
    assert.equal(bytes.toString('ascii',0,4),'RIFF',name);
    assert.equal(bytes.toString('ascii',8,12),'WEBP',name);
    assert.equal(bytes.toString('ascii',12,16),'VP8 ',name+' doit etre avec perte');
    assert.ok(bytes.length>50000,name);
  }
  const src=fs.readdirSync(path.join(root,'images'));
  const norm=s=>s.normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();
  assert.ok(!src.some(n=>norm(n).includes('interieur chaleureux d')&&norm(n).endsWith('.png')));
  assert.ok(!src.some(n=>norm(n).includes('interieur orthodoxe dore')&&norm(n).endsWith('.png')));
  for (const name of ['Kouzma.webp','Praskovia.webp']) {
    const bytes=fs.readFileSync(path.join(dir,name));
    assert.equal(bytes.toString('ascii',0,4),'RIFF',name);
    assert.equal(bytes.toString('ascii',8,12),'WEBP',name);
    assert.equal(bytes.toString('ascii',12,16),'VP8 ',name+' doit être avec perte');
    assert.ok(bytes.length>30000,name);
  }
  assert.ok(!src.some(n=>norm(n).includes('portrait chaleureux d')&&norm(n).endsWith('.png')));
  assert.ok(!src.some(n=>norm(n).includes('portrait tendre en foulard')&&norm(n).endsWith('.png')));
});
test('Krasnov : maison Kouzma et salle de l eglise raccordees, autres villes preservees',()=>{
  const ctx=vm.createContext({console,state:{country:'soviet',currentCity:'ville_b'}});
  vm.runInContext(fs.readFileSync(path.join(root,'data.js'),'utf8'),ctx);
  const got=vm.runInContext(`({
    maison:BUILDINGS['maison-krasnov-eglise'].rooms.piece_maison.imageUrl,
    maisonProvisoire:BUILDINGS['maison-krasnov-eglise'].imagesAVenir,
    eglise:WORLD.soviet.ville_b.buildingContext['kolkhoze-spirituel'].roomOverrides.grange_sainte.imageUrl,
    egliseDon:WORLD.soviet.ville_b.buildingContext['kolkhoze-spirituel'].roomOverrides.grange_sainte.orders[0].fn,
    autreEglise:WORLD.soviet.capitale.buildingContext['kolkhoze-spirituel']?.roomOverrides?.grange_sainte?.imageUrl,
    praskovia:BUILDINGS['maison-krasnov-bleue'].rooms.piece_maison.imageUrl
  })`,ctx);
  assert.equal(got.maison,'images/Sovarka/Krasnov/Krasnov_maison_kouzma_interieur.webp');
  assert.equal(got.maisonProvisoire,false);
  assert.equal(got.eglise,'images/Sovarka/Krasnov/Krasnov_eglise_sainte_moisson_interieur.webp');
  assert.equal(got.egliseDon,'faire_don');
  assert.notEqual(got.autreEglise,got.eglise);
  assert.equal(got.praskovia,'images/Sovarka/Krasnov/Krasnov_maison_bleue_interieur.webp');
});
