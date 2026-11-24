'use strict';
// Contrôle du parcours « Personnes présentes » à Novomirsk (portrait strict).
// Ne modifie ni le monde, ni les profils, ni la base.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
const lire=p=>fs.readFileSync(path.join(root,p),'utf8');
const ctx={console,window:{}};ctx.window=ctx;vm.createContext(ctx);
vm.runInContext(lire('data.js')+';globalThis.__WORLD=WORLD;globalThis.__BUILDINGS=BUILDINGS;',ctx);
const monde=ctx.__WORLD,batiments=ctx.__BUILDINGS;
const ville=monde.soviet.capitale;
const audit=JSON.parse(lire('outils/audits/portraits/portraits-a-produire-20261124.json'));
const attendus=audit.portraits_a_produire;
const normaliser=s=>String(s||'').normalize('NFKC').trim();
const groupes=new Map();
const ajouter=(b,p,personne,imagePiece)=>{
  if (!personne||!personne.name)return;
  const key=[b,p,normaliser(personne.name)].join('|');
  const photo=String(personne.photoUrl||'').split('?')[0];
  const relative=photo.replace(/^https:\/\/raw\.githubusercontent\.com\/FredJ74\/res-publica\/main\//,'');
  const estLieu=photo && [imagePiece,relative].some(x=>x&&x===imagePiece);
  const valable=!!relative&&relative.startsWith('images/')&&fs.existsSync(path.join(root,relative))&&!estLieu;
  const attente=attendus.some(a=>a.batiment===b&&a.piece===p&&normaliser(a.nom)===normaliser(personne.name));
  const ligne={batiment:b,piece:p,nom:personne.name,role:personne.role||'',photo:relative||null,source:imagePiece||null,portrait_existant:valable,a_produire:attente};
  groupes.set(key,ligne);
};
for(const b of ville.buildings||[]){
  const template=batiments[b];if(!template)continue;
  const loc=(ville.buildingContext||{})[b]||{};
  const pieces={...(template.rooms||{}),...(loc.roomsExtra||{})};
  const premiere=Object.keys(template.rooms||{})[0];
  for(const [p,source] of Object.entries(pieces)){
    const extra=(loc.roomsExtra||{})[p]||{}, override=(loc.roomOverrides||{})[p]||{};
    const liste=override.personsVides ? [] : Array.isArray(override.persons) ? override.persons :
      (p===premiere && Array.isArray(loc.persons)&&loc.persons.length) ? loc.persons :
      Array.isArray(extra.persons) ? extra.persons : (source.persons||[]);
    const image=override.imageUrl||extra.imageUrl||source.imageUrl||loc.imageUrl||'';
    for(const personne of liste)ajouter(b,p,personne,image);
  }
}
const presents=[...groupes.values()];
const orphelins=presents.filter(x=>!x.portrait_existant&&!x.a_produire);
const listesNul=attendus.filter(a=>a.pays!=='Republia'&&a.pays!=='Sovarka'&&a.source==='audit 23/11'&&!presents.some(x=>x.nom===a.nom&&x.piece===a.piece&&x.batiment===a.batiment));
const guides=[
 ['guide_zinaida_otcheredova','images/Sovarka/Novomirsk/guide-zinaida-otcheredova-portrait.webp'],
 ['guide_firmin_badaud','images/Republia/Luthecia/guide-firmin-badaud-portrait.webp'],
 ['guide_yvonne_bigorneau','images/Republia/Port-Sainte-Marie/guide-yvonne-bigorneau-portrait.webp'],
 ['guide_lucien_boulon','images/Republia/Montrouge/guide-lucien-boulon-portrait.webp'],
 ['guide_bair_namsaraev','images/Sovarka/Starovka/guide-bair-namsaraev-portrait.webp'],
 ['guide_fiodor_medvedkine','images/Sovarka/Krasnov/guide-fiodor-medvedkine-portrait.webp']
];
for(const [id,chemin] of guides){
  let trouve=null;
  for(const pays of ['republic','soviet'])for(const villeId of ['capitale','ville_a','ville_b']){
    const v=monde[pays][villeId];
    for(const b of new Set([...(v.buildings||[]),...Object.keys(v.buildingContext||{})])){
      const building=batiments[b],local=(v.buildingContext||{})[b]||{};
      const rooms={...(building?.rooms||{}),...(local.roomsExtra||{})};
      const first=Object.keys(building?.rooms||{})[0];
      for(const [roomId,room] of Object.entries(rooms)){
        const override=(local.roomOverrides||{})[roomId]||{};
        const personnes=[...(override.persons||[]),...(local.persons||[]),...(room.persons||[])];
        const p=personnes.find(v=>v.profilId===id);
        if(p)trouve=p;
      }
    }
  }
  assert.ok(trouve,'Guide introuvable: '+id);
  assert.equal(trouve.photoUrl,chemin,'Guide encore illustré par une image de lieu: '+id);
  const existe=fs.existsSync(path.join(root,chemin));
  assert.ok(existe||attendus.some(a=>a.fichier===chemin),'Guide sans fichier et absent de la liste: '+id);
}
const sortie={date:'2026-11-24',total_visible:presents.length,avec_portrait:presents.filter(x=>x.portrait_existant).length,a_produire:presents.filter(x=>!x.portrait_existant&&x.a_produire).length,orphelins,entrees_obsoletes:listesNul,apparitions:presents};
if(process.env.PORTRAITS_AUDIT_OUT) fs.writeFileSync(path.resolve(process.env.PORTRAITS_AUDIT_OUT),JSON.stringify(sortie,null,2)+'\n');
console.log('Novomirsk:',sortie.total_visible,'visibles,',sortie.avec_portrait,'portraits,',sortie.a_produire,'à produire');
if(orphelins.length)console.error('PNJ sans portrait ni fiche à produire:',JSON.stringify(orphelins,null,2));
assert.equal(orphelins.length,0,'Inventaire incomplet : compléter la liste avant fusion');
console.log('Six guides : chemins de portrait dédiés, scènes entières non utilisées.');
