import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
const root=path.resolve(import.meta.dirname,'../..');
const data=fs.readFileSync(path.join(root,'data.js'),'utf8');
const nav=fs.readFileSync(path.join(root,'plateau-navigation.js'),'utf8');
const sql=fs.readFileSync(path.join(root,'migrations/20261115195000_starovka_raffinerie_ordre_salles.sql'),'utf8');
const context=vm.createContext({});
vm.runInContext(data+";globalThis.__raff={local:WORLD.soviet.ville_a.buildingContext['usine-principale'],common:BUILDINGS['usine-principale']};",context);
const {local,common}=context.__raff;
const ordre=['salle_ventes_raffinerie','interieur_raffinerie','direction_usine'];
test('Starovka : les trois salles sont ordonnées ventes, usine, direction',()=>{
 assert.deepEqual([...local.roomOrder],ordre);
 const begin=nav.indexOf('function piecesOrdonneesBatiment(');
 const end=nav.indexOf('\nfunction enterBuilding(',begin);
 assert.ok(begin>0&&end>begin,'fonction commune d\'ordre non trouvée');
 vm.runInContext(nav.slice(begin,end)+";globalThis.__ordonner=piecesOrdonneesBatiment;",context);
 const actual=context.__ordonner(common,local).map(([name])=>name);
 assert.deepEqual(actual,ordre);
});
test('client : même ordre pour entrée, onglets et serveur',()=>{
 assert.ok(nav.includes('piecesOrdonneesBatiment(b,ctx).map(([id])=>id).find'));
 assert.ok(nav.includes('const roomsBrutes = piecesOrdonneesBatiment(b,ctxForTabs)'));
 assert.ok(nav.includes('enterRoom(buildingId, rooms[0][0], null)'));
 assert.ok(sql.includes(JSON.stringify(ordre)));
});
test('aucun changement du gabarit des autres villes',()=>{
 const original=Object.keys(common.rooms);
 assert.equal(original[0],'direction_usine');
 assert.deepEqual(context.__ordonner(common,null).map(([n])=>n),original);
 assert.deepEqual(context.__ordonner(common,{roomsExtra:{annexe:{}}}).map(([n])=>n),[...original,'annexe']);
});
