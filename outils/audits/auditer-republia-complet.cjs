// Audit en lecture seule des déclarations effectivement fusionnées ; aucune RPC.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const acorn=require('../vercel/node_modules/acorn');
const ROOT=path.resolve(__dirname,'../..');
const lire=f=>fs.readFileSync(path.join(ROOT,f),'utf8');
function fonctions(f,noms){const s=lire(f);return acorn.parse(s,{ecmaVersion:'latest',sourceType:'script'}).body.filter(n=>n.type==='FunctionDeclaration'&&noms.includes(n.id.name)).map(n=>s.slice(n.start,n.end)).join('\n');}
function charger(){
 const c=vm.createContext({console,state:{country:'republic',currentCity:'capitale'}});
 for(const f of ['data.js','plateau-variantes-pieces.js','plateau-rue-centrale.js'])vm.runInContext(lire(f),c,{timeout:5000});
 vm.runInContext(fonctions('plateau-navigation.js',['getBuildingContext'])+'\n'+fonctions('plateau-multijoueur.js',['personnesNormalesDeLaPiece']),c);
 return JSON.parse(vm.runInContext(`JSON.stringify((()=>{const out={villes:[],rues:RUE_CENTRALE_NOEUDS.republic};
 for(const ville of ['capitale','ville_a','ville_b']){state.currentCity=ville;const cite=WORLD.republic[ville],v={id:ville,nom:cite.name,image:cite.imageUrl,batiments:[]};
 for(const id of cite.buildings){const b=BUILDINGS[id],ctx=getBuildingContext(id)||{},bat={id,nom:ctx.name||b?.name,context:ctx,pieces:[]};
 if(!b){bat.absent=true;v.batiments.push(bat);continue;}
 for(const [rid,r] of Object.entries({...b.rooms,...ctx.roomsExtra})){if(ctx.roomsExclues?.includes(rid))continue;const o=ctx.roomOverrides?.[rid]||{};
 const variante=PIECE_VARIANTES.republic?.[ville]?.[id]?.[rid];
 bat.pieces.push({id:rid,nom:o.name||r.name,desc:o.desc||ctx.desc||r.desc,image:o.imageUrl||ROOM_IMAGES_EMPIRE.republic?.[id]?.[rid]||r.imageUrl||null,
 imagesDeclarees:{gabarit:r.imageUrl||null,empire:ROOM_IMAGES_EMPIRE.republic?.[id]?.[rid]||null,locale:o.imageUrl||null},variantes:variante?.images||{},cachee:ctx.roomsMasquees?.includes(rid)||false,
 personnes:personnesNormalesDeLaPiece(id,rid),ordres:ordresDeclaresDeLaPiece(r,ctx,rid)});}
 v.batiments.push(bat);}out.villes.push(v);}return out;})())`,c));
}
function fichiers(d){return fs.readdirSync(d,{withFileTypes:true}).flatMap(e=>e.isDirectory()?fichiers(path.join(d,e.name)):[path.relative(ROOT,path.join(d,e.name)).split(path.sep).join('/')]);}
function verifierImage(url,ensemble){if(!url)return {statut:'sans_image'};if(/^https?:/.test(url))return {statut:/unsplash|placeholder|picsum/i.test(url)?'provisoire':'distante',url};
 let p;try{p=decodeURIComponent(url.split(/[?#]/)[0]).replace(/^\//,'');}catch(_){return {statut:'url_invalide',url};}if(ensemble.has(p))return {statut:'locale_presente',url:p};
 const variantes=[...ensemble].filter(x=>x.toLowerCase()===p.toLowerCase());return {statut:variantes.length?'casse_incorrecte':'fichier_absent',url:p,candidats:variantes};}
function analyser(){const data=charger(),images=fichiers(path.join(ROOT,'images')),set=new Set(images),anomalies=[],imagesReferences=[],npcs=[],ordres=[];
 const router=lire('plateau-router.js');
 function image(url,lieu,type){const v=verifierImage(url,set);imagesReferences.push({...lieu,type,...v});if(['fichier_absent','casse_incorrecte'].includes(v.statut))anomalies.push({gravite:'P2',code:'image_introuvable',...lieu,type,...v});return v;}
 for(const v of data.villes){image(v.image,{ville:v.id},'ville');for(const b of v.batiments){if(b.absent){anomalies.push({gravite:'P1',code:'batiment_absent',ville:v.id,batiment:b.id});continue;}
 for(const r of b.pieces){const lieu={ville:v.id,batiment:b.id,piece:r.id};image(r.image,lieu,'piece');for(const [etat,u]of Object.entries(r.variantes))image(u,{...lieu,etat},'variante');
 for(const [source,u]of Object.entries(r.imagesDeclarees))if(u&&u!==r.image)image(u,{...lieu,source},'repli_masque');
 const vus=new Set();for(const o of r.ordres){ordres.push({...lieu,...o,routeLitterale:router.includes("'"+o.fn+"'")||router.includes('"'+o.fn+'"')});if(vus.has(o.fn))anomalies.push({gravite:'P2',code:'ordre_duplique',...lieu,fn:o.fn});vus.add(o.fn);}
 const noms=new Set();for(const p of r.personnes){npcs.push({...lieu,...p});if(p.photoUrl)image(p.photoUrl,{...lieu,pnj:p.name},'portrait');if(noms.has(p.name))anomalies.push({gravite:'P2',code:'pnj_duplique_meme_piece',...lieu,pnj:p.name});noms.add(p.name);}
 }} }
 // Les quatre arrivées du carrefour PSM sont conservées et contrôlées séparément.
 const balayer=(x,loc)=>{if(!x||typeof x!=='object')return;for(const[k,v]of Object.entries(x)){if(typeof v==='string'&&(v.startsWith('images/')||/^https?:/.test(v)))image(v,{scene:loc+'.'+k},'rue');else if(v&&typeof v==='object')balayer(v,loc+'.'+k);}};balayer(data.rues,'republic');
 const referencesSource=new Set();for(const f of fs.readdirSync(ROOT).filter(f=>/\.(?:js|mjs|html|css)$/.test(f))){for(const m of lire(f).matchAll(/images\/[A-Za-z0-9_./À-ÿ%+ -]+\.(?:webp|png|jpg|jpeg|gif|svg)/g))referencesSource.add(decodeURIComponent(m[0]));}
 // "Non référencée en source" n'est PAS "inutilisée" : les chemins peuvent venir de SQL/DB.
 const nonReferencees=images.filter(x=>!referencesSource.has(x));
 return {source:'main audité, déclarations locales sans authentification ni requête de production',villes:data.villes,rues:data.rues,images:imagesReferences,pnj:npcs,ordres,anomalies,imagesSansReferenceLitteraleRacine:nonReferencees,
 compteurs:{villes:data.villes.length,batiments:data.villes.reduce((n,v)=>n+v.batiments.length,0),pieces:data.villes.reduce((n,v)=>n+v.batiments.reduce((n,b)=>n+b.pieces.length,0),0),pnjOccurrences:npcs.length,pnjNoms:new Set(npcs.map(p=>p.name)).size,ordresOccurrences:ordres.length,ordresUniques:new Set(ordres.map(o=>o.fn)).size,imagesOccurrences:imagesReferences.length,imagesDistinctes:new Set(imagesReferences.map(i=>i.url).filter(Boolean)).size,fichiersImages:images.length}};
}
if(require.main===module){const v=analyser();if(process.argv[2])fs.writeFileSync(process.argv[2],JSON.stringify(v,null,2)+'\n');console.log(JSON.stringify({compteurs:v.compteurs,anomalies:v.anomalies,provisoires:v.images.filter(i=>i.statut==='provisoire'&&i.type!=='repli_masque'),sansImage:v.images.filter(i=>i.statut==='sans_image')},null,2));}
module.exports={analyser,charger,verifierImage};
