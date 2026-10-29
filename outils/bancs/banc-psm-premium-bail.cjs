// PSM : les ordres dynamiques du commerce sont recalcules apres lecture du bail.
'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const loc=fs.readFileSync(path.join(__dirname,'../../plateau-justice-economie.js'),'utf8');
const commerce=fs.readFileSync(path.join(__dirname,'../../plateau-commerce-pj.js'),'utf8');
const start=loc.indexOf('async function chargerLocations()');
const end=loc.indexOf('\n}',start)+2;
assert.ok(start>=0&&end>start);
const charge=loc.slice(start,end);
assert.ok(charge.indexOf('state.locationsActives = locations;')<charge.indexOf('renderRoomActions(room, batiment, piece)'), 'raffraichissement apres serveur');
for(const id of ['vitrine_principale','boutique_milieu','arriere_boutique','cave_reserve'])
  assert.ok(charge.includes("'"+id+"'"),'boutique '+id);
assert.ok(charge.includes("state.currentCity === 'ville_a'"),'PSM uniquement');
assert.ok(commerce.includes("fn: 'commerce_personnaliser'"),'bouton Premium du socle');
assert.ok(commerce.includes("if (moi && titulaire === moi)"),'option reservee au titulaire');
assert.ok(commerce.includes("commercePjOuvrirAtelier()"),'atelier commun');
console.log('OK - Option Commerce Premium recalculée après bail sur quatre boutiques PSM');
