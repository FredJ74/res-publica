'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const root=path.resolve(__dirname,'../..');
const c=vm.createContext({console});
vm.runInContext(fs.readFileSync(path.join(root,'data.js'),'utf8')+';this.W=WORLD;this.B=BUILDINGS;this.f=ordresDeclaresDeLaPiece;',c);
const local=c.W.soviet.qhs;
const ctx=local.buildingContext['qhs-prison'];
const expected=['entree_qhs','cellules_qhs','cachot_disciplinaire','bureau_chef','mirador'];
assert.deepEqual(Array.from(ctx.roomOrder),expected);
assert.equal(local.buildings[0],'qhs-prison');
assert.equal(ctx.roomOverrides.entree_qhs.name,'Entrée du camp');
assert.equal(ctx.roomOverrides.cellules_qhs.name,'Dortoir des prisonniers');
assert.ok(!ctx.roomsExclues.includes('cellules_qhs'),'La cellule de détention canonique doit rester accessible');
for(const old of ['salle_interrogatoire','promenoir','salle_commune_qhs'])
  assert.ok(ctx.roomsExclues.includes(old));
for(const id of expected){
  const room=c.B['qhs-prison'].rooms[id]||ctx.roomsExtra[id];
  assert.ok(room,'pièce '+id+' manquante');
  assert.equal(Array.from(c.f(room,ctx,id)).length,0,'pas d’ordres républicains ou anticipés en '+id);
  const filename=ctx.roomOverrides[id]?.imageUrl||room.imageUrl;
  assert.match(filename,/^images\/Sovarka\/Goulag\/Sovarka_goulag_[a-z_]+\.webp$/);
  const p=path.join(root,filename);
  assert.ok(fs.existsSync(p),'WebP manquant '+filename);
  const header=fs.readFileSync(p).subarray(0,12);
  assert.equal(header.toString('ascii',0,4),'RIFF');
  assert.equal(header.toString('ascii',8,12),'WEBP');
}
for(const e of ['republic','narco','khalija']){
  const qhs=c.W[e].qhs;
  assert.ok(!qhs.buildingContext?.['qhs-prison'],'Aucun contexte goulag dans '+e);
}
for(let i=1;i<=10;i++){
  assert.ok(fs.existsSync(path.join(root,'images/Sovarka/Goulag',`Sovarka_goulag_toundra_${String(i).padStart(2,'0')}.webp`)),'Toundra inchangée');
}
const src=fs.readdirSync(path.join(root,'images/Sovarka/Goulag'));
assert.equal(src.filter(x=>x.endsWith('.png')).length,0,'Aucun PNG ne doit subsister après conversion');
console.log('Goulag : cinq pièces WebP, entrée en premier, dortoir carcéral, aucun ordre, autres empires intacts : OK');
