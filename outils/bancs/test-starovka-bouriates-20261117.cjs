'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

(async () => {
  const root = path.resolve(__dirname, '../..');
  const source = fs.readFileSync(path.join(root, 'api/_pnj-culture-bouriate.js'), 'utf8');
  const mod = await import('data:text/javascript;base64,' + Buffer.from(source).toString('base64'));
  const p = {nom:'Dolgor Tsybikova',identite:'Une habitante de Starovka',caractere:'Hospitalière'};
  const scene = {ville:'Starovka',personnes:['Dolgor Tsybikova']};
  const oui = mod.consigneBouriateStarovka(p,scene);
  assert.match(oui,/fier et heureux/);
  assert.match(oui,/progrès, emploi/);
  assert.match(oui,/bien commun/);
  assert.match(oui,/tempérament/);
  assert.equal(mod.consigneBouriateStarovka(p,{ville:'Krasnov',personnes:[p.nom]}),'');
  assert.equal(mod.consigneBouriateStarovka(p,{ville:'Starovka',personnes:['Un autre personnage']}),'');
  assert.equal(mod.consigneBouriateStarovka({nom:'Une visiteuse',caractere:'une Bouriate'},null),oui);
  assert.equal(mod.consigneBouriateStarovka({nom:'Stepan Kouznetsov',caractere:'kolkhozien'},null),'');
  const dialogue = fs.readFileSync(path.join(root,'api/_pnj-profils.js'),'utf8');
  const toast = fs.readFileSync(path.join(root,'api/_reaction-habitant.js'),'utf8');
  assert.match(dialogue,/import \{ consigneBouriateStarovka \} from '\.\/_pnj-culture-bouriate\.js'/);
  assert.match(dialogue,/\.\.\.\(consigneBouriateStarovka\(p, scene\)/);
  assert.match(toast,/geste\.habitant === 'Dolgor Tsybikova' \? '\\n' \+ CONSIGNE_BOURIATE_STAROVKA/);
  assert.match(toast,/import \{ CONSIGNE_BOURIATE_STAROVKA \} from '\.\/_pnj-culture-bouriate\.js'/);
  console.log('Starovka : 12 vérifications culture bouriate et intégration serveur réussies');
})().catch(e => {console.error(e);process.exitCode=1;});
