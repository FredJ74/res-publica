#!/usr/bin/env node
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const root=path.resolve(__dirname,'../..');
const street=fs.readFileSync(path.join(root,'plateau-rue-centrale.js'),'utf8');
const sql=fs.readFileSync(path.join(root,'migrations/20261115181000_starovka_raffinerie_position_corrective.sql'),'utf8');
function get(id){
 const start=street.indexOf("    '"+id+"': {");
 assert.ok(start>=0,id);
 const end=street.indexOf("\n    '",start+8);
 return street.slice(start,end<0?undefined:end);
}
const p=get('starovka-rue-petrole-ferme');
const t=get('starovka-rue-terrains');
const r=get('starovka-rue-raffinerie');
const l=get('starovka-rue-logements-collectifs');
assert.match(p,/droite: 'starovka-rue-terrains'/);
assert.match(p,/toutDroit: 'starovka-maisons-ferme'/);
assert.match(p,/arriere: 'starovka-rue-locaux-a-louer'/);
assert.match(t,/gauche: 'starovka-rue-petrole-ferme'/);
assert.match(t,/droite: 'starovka-rue-raffinerie'/);
assert.match(t,/buildingId: 'terrain-a-batir-3'/);
assert.match(r,/gauche: 'starovka-rue-terrains'/);
assert.match(r,/droite: 'starovka-rue-logements-collectifs'/);
assert.match(r,/buildingId: 'usine-principale'/);
assert.match(r,/Starovka_rue_raffinerie.webp/);
assert.match(l,/gauche: 'starovka-rue-raffinerie'/);
assert.match(l,/droite: 'starovka-rue-stade'/);
assert.match(l,/arriere: 'starovka-rue-restaurant-boutique'/);
for(const id of ['starovka-rue-petrole-ferme','starovka-rue-terrains','starovka-rue-raffinerie','starovka-rue-logements-collectifs'])assert.ok(sql.includes(id),id);
const filepath=path.join(root,'images/Sovarka/Starovka/Starovka_rue_raffinerie.webp');
assert.ok(fs.existsSync(filepath));
const bytes=fs.readFileSync(filepath);
assert.equal(bytes.toString('ascii',0,4),'RIFF');
assert.equal(bytes.toString('ascii',8,16),'WEBPVP8 ');
assert.ok(!fs.existsSync(path.join(root,'images/Sovarka/Starovka/Raffinerie enneigée et route industrielle.png')));
console.log('Starovka : pétrole ↔ terrains ↔ raffinerie ↔ logements, sans bifurcation, entrée usine intacte.');
