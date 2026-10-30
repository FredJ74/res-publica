const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm');
const s=fs.readFileSync('plateau-multijoueur.js','utf8');
const p=fs.readFileSync('plateau-pnj.js','utf8');
const pa=p.indexOf('function profilOccupationTerrain('),pb=p.indexOf('function terrainOrdreDisponible',pa);
const a=s.indexOf('function renderPersonsList('),b=s.indexOf('// Cache partagé des photos',a);
function afficher(occupant,options={}){
 const el={innerHTML:''};
 const c={state:{country:'republic',currentBuilding:'terrain-a-batir-1',currentRoom:options.lot?'lot_dyn_a':'terrain'},getTerrainState:()=>options.etat || {pnj:occupant?.terrainPnjId,pnjData:occupant?{...occupant,id:occupant.terrainPnjId,name:occupant.name.replace(' (PNJ)','')}:null},TERRAIN_PNJ_PROFILES:{republic:[{id:'cadavre',name:'Cadavre courant',job:'default',role:'Cadavre'},{id:'squatter_cool',name:'Squatteurs courants',job:'citoyen',role:'Squatteurs'}]},ARCHETYPES:[],PNJ_AVATAR:{default:{},citoyen:{}},COUNTRIES:{republic:{}},RP_STATUTS_JUDICIAIRES:{},localStorage:{getItem:()=>null},sessionStorage:{getItem:()=>occupant===null?null:JSON.stringify(occupant)},document:{getElementById:()=>el},appliquerRemplacantCodetenu:x=>x,filtrerPnjPostesPourvus:x=>x,getSimulesPresents:()=>[],getGroupeHtmlPourPiece:()=>'',chargerVraisJoueursPresents(){},encodePnjSafe:()=>'',marqueurMutinHtml:()=>'',marqueursJudiciairesHtml:()=>'',estPieceDynamiqueLot:()=>!!options.lot};
 vm.createContext(c);vm.runInContext(p.slice(pa,pb)+s.slice(a,b),c);
 c.renderPersonsList(options.personnes||[],options.cible);
 return {html:el.innerHTML,rafraichir:()=>{c.renderPersonsList([]);return el.innerHTML;}};
}
const cadavre={name:'Individu non identifié (PNJ)',job:'default',role:'Cadavre mystérieux',terrainPnjId:'cadavre'};
test('cadavre affiche des le rendu et conserve au rafraichissement',()=>{
 const r=afficher(cadavre);assert.match(r.html,/Individu non identifié/);assert.match(r.rafraichir(),/ouvrirCadavreListe/);
});
test('squatteur affiche une seule fois si deja fourni par la navigation',()=>{
 const p={name:'Les Gars du Bas (PNJ)',job:'citoyen',role:'Squatteurs',terrainPnjId:'squatter_cool'};
 assert.equal((afficher(p,{personnes:[p]}).html.match(/squatteurs \(PNJ\)/g)||[]).length,1);
 assert.match(afficher(p).html,/squatteurs \(PNJ\)/);assert.doesNotMatch(afficher(p).html,/Les Gars du Bas/);
});
test('aucun intrus sur terrain vide ou dans les locaux livres',()=>{
 assert.doesNotMatch(afficher(null).html,/Individu non identifié/);
 assert.doesNotMatch(afficher(cadavre,{lot:true}).html,/Individu non identifié/);
});

test('ancien cadavre en cache mais squatteurs courants : seules les cartes courantes',()=>{
 const r=afficher(cadavre,{personnes:[cadavre],etat:{pnj:'squatter_cool',pnjData:{id:'cadavre',name:'Ancien cadavre'}}});
 assert.doesNotMatch(r.html,/Individu non identifié|Ancien cadavre|ouvrirCadavreListe/);
 assert.match(r.html,/squatteurs \(PNJ\)/);assert.doesNotMatch(r.html,/Squatteurs courants/);
});
test('ancien profil squatteur mais cadavre courant : aucune carte de squat',()=>{
 const p={name:'Ancien squat (PNJ)',job:'citoyen',terrainPnjId:'squatter_cool'};
 const r=afficher(p,{personnes:[p],etat:{pnj:'cadavre',pnjData:{id:'squatter_cool',name:'Ancien squat'}}});
 assert.doesNotMatch(r.html,/Ancien squat/);assert.match(r.html,/Cadavre courant|ouvrirCadavreListe/);
});
test('cache de visite ignore lorsque le terrain est vide',()=>{
 assert.doesNotMatch(afficher(cadavre,{personnes:[cadavre],etat:{pnj:null}}).html,/Individu non identifié|ouvrirCadavreListe/);
});
