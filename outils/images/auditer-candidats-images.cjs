// Expressions de chemins réellement utilisées : candidats des chantiers, forêt et toundra.
// Aucun DOM, transport ni RPC ; les candidats facultatifs ne sont pas des images choisies.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const acorn=require('../vercel/node_modules/acorn');
const R=path.resolve(__dirname,'../..'),lire=f=>fs.readFileSync(path.join(R,f),'utf8');
function declaration(f,nom){const s=lire(f),n=acorn.parse(s,{ecmaVersion:'latest'}).body.find(n=>n.type==='VariableDeclaration'&&n.declarations.some(d=>d.id.name===nom));if(!n)throw Error(nom);return s.slice(n.start,n.end);}
function inventorier(){
 const c=vm.createContext({state:{country:'republic',currentCity:'capitale'}}),references=[];
 const decl=acorn.parse(declaration('plateau-justice-economie.js','NIVEAUX_CONSTRUCTION'),{ecmaVersion:'latest'}).body[0].declarations[0].init;
 // Lire seulement les littéraux imageUrl : coutTotalConstruction ne doit pas être exécutée.
 c.NIVEAUX_CONSTRUCTION=Object.fromEntries(decl.properties.map(p=>[p.key.name||p.key.value,{imageUrl:p.value.properties.find(p=>(p.key.name||p.key.value)==='imageUrl').value.value}]));
 vm.runInContext(lire('plateau-chantier-vue.js'),c);
 for(const pays of ['republic','soviet'])for(const ville of ['capitale','ville_a','ville_b'])for(const type of ['hangar','commerce_standard','commerce_premium','logement','building']){
  c.state.country=pays;c.state.currentCity=ville;
  for(const progression of [0,1,4,7,null]){
   const t=progression===null?{niveau_construction:type}:{chantier:{niveau:type,progressionJours:progression,dureeJours:9}};
   c.temoin=t;const urls=JSON.parse(vm.runInContext('JSON.stringify(RPChantierVue.candidatsImage(temoin))',c));
   references.push({systeme:'chantier',pays,ville,type,progression,candidats:urls,existants:urls.filter(u=>fs.existsSync(path.join(R,u)))});
  }
 }
 c.window=c;c.document={addEventListener(){}};
 vm.runInContext(lire('plateau-goulag-toundra.js'),c);
 for(const destination of ['starovka','krasnov'])for(let n=0;n<(destination==='starovka'?7:10);n++){
  c.temoin={destination,progressions:n};references.push({systeme:'toundra',destination,jour:n+1,url:vm.runInContext('goulagToundraImageEtape(temoin)',c)});
 }
 vm.runInContext(declaration('plateau-sovarka-provinces.js','PROV_FORET_IMAGES'),c);
 for(const[f,nom]of Object.entries(JSON.parse(vm.runInContext('JSON.stringify(PROV_FORET_IMAGES)',c))))references.push({systeme:'foret',rencontre:f,url:'images/Sovarka/Krasnov/'+nom});
 return references;
}
if(require.main===module){const r=inventorier();if(process.argv[2])fs.writeFileSync(process.argv[2],JSON.stringify(r,null,2)+'\n');console.log(JSON.stringify({situations:r.length,candidatsFacultatifsAbsents:[...new Set(r.flatMap(x=>x.candidats||[]))].filter(u=>!fs.existsSync(path.join(R,u))),imagesObligatoiresAbsentes:r.filter(x=>x.url&&!fs.existsSync(path.join(R,x.url)))}));}
module.exports={inventorier};
