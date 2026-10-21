// Lecture des déclarations existantes : aucune superficie ni aucun prix reconstitué.
const fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const acorn=require('../vercel/node_modules/acorn');
const racine=path.resolve(__dirname,'../..'),lire=f=>fs.readFileSync(path.join(racine,f),'utf8');
const c=vm.createContext({window:{},state:{country:'republic'},console});
for(const f of ['data.js','plateau-immobilier.js','plateau-construction-parcours.js'])vm.runInContext(lire(f),c);
const s=lire('plateau-pnj.js'),n=acorn.parse(s,{ecmaVersion:'latest'}).body.find(n=>n.type==='VariableDeclaration'&&n.declarations.some(d=>d.id.name==='SURFACE_TERRAINS'));
if(!n)throw Error('referentiel_surfaces_absent');vm.runInContext(s.slice(n.start,n.end),c);
const resultats=vm.runInContext(`Object.entries(WORLD.republic).flatMap(([ville,v])=>v.buildings.filter(id=>id.startsWith('terrain-a-batir')).map(id=>({pays:'republic',ville,id,...constructionReferenceTerrain(id,{})})))`,c);
const absents=resultats.filter(r=>r.surface===null||r.prix===null);
process.stdout.write(JSON.stringify({portee:'Declarations du depot, pas les valeurs persistantes Supabase',parcelles:resultats,donneesManquantes:absents,pret:absents.length===0},null,2)+'\n');
if(absents.length)process.exitCode=1;
