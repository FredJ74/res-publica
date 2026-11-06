import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {fileURLToPath} from 'node:url';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const ctx=vm.createContext({console});
vm.runInContext(fs.readFileSync(path.join(root,'data.js'),'utf8')+';this.world=WORLD;this.buildings=BUILDINGS;',ctx);
const nov=ctx.world.soviet.capitale.buildingContext['office-notarial'].roomOverrides;
const files={
  bureau_successions:'Novomirsk_notaire_successions.webp',
  bureau_contrats:'Novomirsk_notaire_cessions_entreprises.webp'
};
test('Novomirsk raccorde deux pièces notariales existantes aux illustrations dédiées',()=>{
  for(const [room,file] of Object.entries(files)){
    assert.ok(ctx.buildings['office-notarial'].rooms[room],'pièce absente du socle : '+room);
    assert.equal(nov[room].imageUrl,'images/Sovarka/Novomirsk/'+file);
    assert.ok(fs.statSync(path.join(root,nov[room].imageUrl)).size>100000,'WebP non chargé : '+file);
  }
});
test('les ordres du notaire, les autres villes et leurs images restent inchangés',()=>{
  assert.ok(nov.bureau_contrats.orders.some(o=>o.fn==='sovarka_cession'));
  assert.ok(nov.bureau_contrats.orders.some(o=>o.fn==='sovarka_signer_attribution'));
  const lut=ctx.world.republic.capitale.buildingContext['office-notarial'].roomOverrides;
  assert.equal(lut.bureau_successions.imageUrl,'images/bureau-successions-luthecia.webp');
  assert.equal(lut.bureau_contrats.imageUrl,'images/bureau-contrats-luthecia.webp');
});
