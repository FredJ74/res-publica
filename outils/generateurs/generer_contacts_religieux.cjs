// Référentiel des services de contact déjà visibles ; aucune identité ou règle nouvelle.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const root=path.resolve(__dirname,'../..'),c=vm.createContext({window:{},console});vm.runInContext(fs.readFileSync(path.join(root,'data.js'),'utf8'),c);
const lignes=vm.runInContext(`Object.entries(WORLD.republic).flatMap(([ville,v])=>(v.buildings||[]).filter(id=>['tabernacle-impots','notre-dame-mer','eglise-montrouge'].includes(id)).flatMap(batiment=>Object.entries(BUILDINGS[batiment].rooms||{}).flatMap(([piece,r])=>(r.persons||[]).filter(p=>['grand_pretre','pretre','clerc'].includes(p.job)).map(p=>({pays:'republic',ville,batiment,piece,nom:p.name.replace(/ \\(PNJ\\)$/,''),fonction:p.job}))))).sort((a,b)=>JSON.stringify(a).localeCompare(JSON.stringify(b)))`,c);
const cles=new Set();for(const r of lignes){const k=JSON.stringify([r.pays,r.ville,r.batiment,r.piece,r.nom]);if(cles.has(k))throw Error('religieux_duplique');cles.add(k);}
process.stdout.write(JSON.stringify(lignes,null,2)+'\n');
