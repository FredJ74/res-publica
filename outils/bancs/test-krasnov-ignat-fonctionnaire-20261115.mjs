import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {fileURLToPath} from 'node:url';
import {profilsPersonnalites} from '../../api/_pnj-personnalites.js';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const data=fs.readFileSync(path.join(root,'data.js'),'utf8');
const personality=fs.readFileSync(path.join(root,'api/_pnj-personnalites.js'),'utf8');
const reaction=fs.readFileSync(path.join(root,'api/_reaction-habitant.js'),'utf8');

test('Ignat : son identité et son lieu sont conservés dans la maison au coin de la rue',()=>{
  const ctx=vm.createContext({console,state:{country:'soviet',currentCity:'ville_b'}});
  vm.runInContext(data,ctx);
  const got=vm.runInContext(`({
    maison:BUILDINGS['maison-krasnov-terrains'].rooms.piece_maison,
    imagesAVenir:BUILDINGS['maison-krasnov-terrains'].imagesAVenir,
    visible:WORLD.soviet.ville_b.buildings.includes('maison-krasnov-terrains'),
    reference:BUILDINGS['maison-krasnov-terrains'].rooms.piece_maison.orders.map(o=>o.fn)
  })`,ctx);
  assert.equal(got.visible,true);
  assert.equal(got.maison.imageUrl,'images/Sovarka/Krasnov/Krasnov_maison_ignat_interieur.webp');
  assert.equal(got.imagesAVenir,false);
  assert.equal(got.maison.persons[0].name,'Ignat Lykov (PNJ)');
  assert.equal(got.maison.persons[0].role,'Fonctionnaire à la retraite');
  assert.equal(got.maison.persons[0].profilId,'ignat_lykov');
  assert.equal(got.maison.persons[0].photoUrl,'images/Sovarka/Krasnov/Ignat.webp');
  assert.deepEqual(Array.from(got.reference),['maison_habitant','trinquer_habitant','dormir_chambre']);
});

test('DeepSeek : personnalité identifiée, conviction pédagogique et refus d’expulser l’invité',()=>{
  assert.match(personality,/'ignat_lykov'\s*:\s*\{/);
  const profil=profilsPersonnalites().ignat_lykov;
  assert.ok(profil,'Profil DeepSeek introuvable');
  assert.equal(profil.nom,'Ignat Lykov');
  assert.equal(profil.maxTokens,520);
  assert.match(profil.caractere,/NE LE CHASSE JAMAIS/);
  assert.match(personality,/Fonctionnaire à la retraite/);
  assert.match(personality,/NE LE CHASSE JAMAIS/);
  assert.match(personality,/ne le dénonce pas/);
  assert.match(personality,/éducation, protection collective/);
  assert.match(personality,/Tu ne fabriques ni statistiques/);
  assert.match(reaction,/'Ignat Lykov'\s*:/);
  assert.match(reaction,/ne le chasse pas, ne le menace pas/);
  assert.doesNotMatch(reaction,/'Ignat Lykov'\s*:\s*["']Tu es Ignat Lykov, vieux trappeur/);
});

test('i18n : nouveau rôle et description d’Ignat traduits dans les neuf langues',()=>{
  const description=fs.readFileSync(path.join(root,'i18n/sovarka-descriptions-resources.js'),'utf8');
  const roles=fs.readFileSync(path.join(root,'i18n/sovarka-roles-resources.js'),'utf8');
  assert.ok(description.includes('Affiches collectivistes, photographie de la moisson'));
  assert.ok(roles.includes('"Fonctionnaire à la retraite"'));
  assert.ok(roles.includes('"Retired civil servant"'));
});

test('Images Ignat : WebP avec perte présents et originaux retirés',()=>{
  for (const name of ['Ignat.webp','Krasnov_maison_ignat_interieur.webp']) {
    const p=path.join(root,'images/Sovarka/Krasnov',name);
    const buffer=fs.readFileSync(p);
    assert.equal(buffer.toString('ascii',0,4),'RIFF',name);
    assert.equal(buffer.toString('ascii',8,12),'WEBP',name);
    assert.equal(buffer.toString('ascii',12,16),'VP8 ',name);
    assert.ok(buffer.length>50000,name);
  }
  const originals=fs.readdirSync(path.join(root,'images')).join('|').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();
  assert.ok(!originals.includes('salon sovietique nostalgique'));
  assert.ok(!originals.includes('portrait d un homme age au badge sovietique'));
});
