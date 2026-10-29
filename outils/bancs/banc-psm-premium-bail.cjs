// Les ordres dynamiques Premium doivent être recalculés après le chargement du bail,
// pour tout local louable des trois villes, sans spécialiser Port-Sainte-Marie.
'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const loc=fs.readFileSync(path.join(__dirname,'../../plateau-justice-economie.js'),'utf8');
const commerce=fs.readFileSync(path.join(__dirname,'../../plateau-commerce-pj.js'),'utf8');
const start=loc.indexOf('async function chargerLocations()');
const end=loc.indexOf('\n}',start)+2;
assert.ok(start>=0&&end>start);
const charge=loc.slice(start,end);
assert.ok(charge.indexOf('state.locationsActives = locations;')<charge.indexOf('renderRoomActions(room, batiment, piece)'), 'rafraichissement apres retour serveur');
assert.ok(charge.includes('BUILDINGS[batiment]?.rooms?.[piece]'), 'piece effectivement affichee');
assert.ok(charge.includes('room.locationData'), 'limite aux locaux disposant de baux');
assert.ok(!charge.includes("state.currentCity === 'ville_a'"), 'aucune exception liee a la ville');
assert.ok(commerce.includes("fn: 'commerce_personnaliser'"),'bouton Premium du socle');
assert.ok(commerce.includes('if (moi && titulaire === moi)'), 'option reservee au titulaire');
assert.ok(commerce.includes('commercePjOuvrirAtelier()'), 'atelier commun');
console.log('OK - Option Commerce Premium recalculee apres bail pour les locaux de toutes les villes');
