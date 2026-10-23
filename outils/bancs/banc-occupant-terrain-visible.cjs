const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm');
const s=fs.readFileSync('plateau-multijoueur.js','utf8');
const a=s.indexOf('function renderPersonsList('),b=s.indexOf('// Cache partagé des photos',a);
function afficher(occupant,options={}){
 const el={innerHTML:''};
 const c={state:{country:'republic',currentBuilding:'terrain-a-batir-1',currentRoom:options.lot?'lot_dyn_a':'terrain'},ARCHETYPES:[],PNJ_AVATAR:{default:{},citoyen:{}},COUNTRIES:{republic:{}},RP_STATUTS_JUDICIAIRES:{},localStorage:{getItem:()=>null},sessionStorage:{getItem:()=>occupant===null?null:JSON.stringify(occupant)},document:{getElementById:()=>el},appliquerRemplacantCodetenu:x=>x,filtrerPnjPostesPourvus:x=>x,getSimulesPresents:()=>[],getGroupeHtmlPourPiece:()=>'',chargerVraisJoueursPresents(){},encodePnjSafe:()=>'',marqueurMutinHtml:()=>'',marqueursJudiciairesHtml:()=>'',estPieceDynamiqueLot:()=>!!options.lot};
 vm.createContext(c);vm.runInContext(s.slice(a,b),c);
 c.renderPersonsList(options.personnes||[],options.cible);
 return {html:el.innerHTML,rafraichir:()=>{c.renderPersonsList([]);return el.innerHTML;}};
}
const cadavre={name:'Individu non identifié (PNJ)',job:'default',role:'Cadavre mystérieux',terrainPnjId:'cadavre'};
test('cadavre affiche des le rendu et conserve au rafraichissement',()=>{
 const r=afficher(cadavre);assert.match(r.html,/Individu non identifié/);assert.match(r.rafraichir(),/ouvrirCadavreListe/);
});
test('squatteur affiche une seule fois si deja fourni par la navigation',()=>{
 const p={name:'Les Gars du Bas (PNJ)',job:'citoyen',role:'Squatteurs',terrainPnjId:'squatter_cool'};
 assert.equal((afficher(p,{personnes:[p]}).html.match(/Les Gars du Bas/g)||[]).length,1);
 assert.match(afficher(p).html,/Les Gars du Bas/);
});
test('aucun intrus sur terrain vide ou dans les locaux livres',()=>{
 assert.doesNotMatch(afficher(null).html,/Individu non identifié/);
 assert.doesNotMatch(afficher(cadavre,{lot:true}).html,/Individu non identifié/);
});
