const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),acorn=require('../vercel/node_modules/acorn');
const s=fs.readFileSync(path.resolve(__dirname,'../../plateau-core.js'),'utf8'),f=acorn.parse(s,{ecmaVersion:'latest'}).body.find(n=>n.type==='FunctionDeclaration'&&n.id.name==='restaurerPositionApresChargement');
function bac(){const t=[],r=[];const c=vm.createContext({state:{char:{name:'Fixture'},country:'republic',currentCity:'capitale',currentBuilding:'a',currentRoom:'r'},BUILDINGS:{a:{rooms:{r:{}}}},window:{},console,rpAuthUid:()=> 'uid-fixture',setTimeout:fn=>t.push(fn),representerPositionServeur:(...p)=>r.push(p)});vm.runInContext(s.slice(f.start,f.end),c);c.restaurerPositionApresChargement({currentBuilding:'a',currentRoom:'r'});return{c,t,r};}
test('restauration inchangée : représentation unique sans commande',()=>{const b=bac();b.t[0]();assert.equal(b.r.length,1);assert.deepEqual(b.r[0],['a','r']);});
test('restauration différée : aucun rendu pour un autre personnage',()=>{const b=bac();b.c.state.char={name:'Autre'};b.t[0]();assert.equal(b.r.length,0);});
test('restauration différée : aucun retour en arrière après nouveau déplacement',()=>{const b=bac();b.c.state.currentRoom='autre-piece';b.t[0]();assert.equal(b.r.length,0);});

// #579 : exécuter la vraie minuterie d'initialisation, puis le rendu de position différé.
const navigation=fs.readFileSync(path.resolve(__dirname,'../../plateau-navigation.js'),'utf8');
const arbreCore=acorn.parse(s,{ecmaVersion:'latest'}),minuteries=[];
function parcourir(n){if(!n||typeof n!=='object')return;if(n.type==='CallExpression'&&n.callee?.name==='setTimeout'&&n.arguments[1]?.value===300){const fn=n.arguments[0];if(fn&&s.slice(fn.start,fn.end).includes('forceRenderCity('))minuteries.push(fn);}for(const v of Object.values(n))if(v&&typeof v==='object')Array.isArray(v)?v.forEach(parcourir):parcourir(v);}
parcourir(arbreCore);assert.equal(minuteries.length,1,'une seule minuterie commune de rendu de ville');
const renduVille=acorn.parse(navigation,{ecmaVersion:'latest'}).body.find(n=>n.type==='FunctionDeclaration'&&n.id.name==='forceRenderCity');
function avecVille(){const b=bac();b.c.WORLD={republic:{capitale:{name:'Fixture',isCapitale:true}}};b.c.COUNTRIES={republic:{n:'Fixture'}};b.c.document={querySelectorAll:()=>[],getElementById:()=>({textContent:''})};b.c.rues=0;b.c.showVueRue=()=>{b.c.rues++;b.c.state.currentBuilding=null;b.c.state.currentRoom=null;};b.c.renderMinimap=b.c.updateLocationDisplay=b.c.updateUI=()=>{};vm.runInContext(navigation.slice(renduVille.start,renduVille.end),b.c);return b;}
function minuterie(b){vm.runInContext('('+s.slice(minuteries[0].start,minuteries[0].end)+')()',b.c);}
test('reprise #579 : minuterie commune garde le bâtiment confirmé puis restaure la pièce',()=>{const b=avecVille();minuterie(b);assert.equal(b.c.state.currentBuilding,'a');assert.equal(b.c.rues,0);b.t[0]();assert.equal(b.r.length,1);assert.deepEqual(b.r[0],['a','r']);});
test('contre-épreuve #579 : sans garderBatiment le rendu de rue annule la restauration',()=>{const b=avecVille();b.c.forceRenderCity('capitale');assert.equal(b.c.rues,1);b.t[0]();assert.equal(b.r.length,0);assert.equal(b.c.state.currentBuilding,null);});
test('reprise #579 : déjà dans la rue, la minuterie commune continue à rendre la rue',()=>{const b=avecVille();b.c.state.currentBuilding=null;b.c.state.currentRoom=null;minuterie(b);assert.equal(b.c.rues,1);b.t[0]();assert.equal(b.r.length,0);});
