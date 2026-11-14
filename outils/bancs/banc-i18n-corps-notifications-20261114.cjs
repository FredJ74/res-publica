'use strict';
// Corps fixes des notifications (showToast) en neuf langues — catalogue i18n/toast-bodies-resources.js (#871).
// Lancer : node --test outils/bancs/banc-i18n-corps-notifications-20261114.cjs
// Partie navigateur : CHROMIUM_PATH=/chemin/vers/chromium (sautée si playwright ou le binaire manque).
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const root=path.resolve(__dirname,'../..'),read=f=>fs.readFileSync(path.join(root,f),'utf8');
const L=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
const catalogueSrc=read('i18n/toast-bodies-resources.js');
const rows=JSON.parse(catalogueSrc.match(/\/\*ROWS\*\/([\s\S]*?)\/\*FIN\*\//)[1]);
const coreSrc=read('plateau-core.js');
function fn(s,name){const a=s.indexOf('function '+name+'(');assert.ok(a>=0,name);return s.slice(a,s.indexOf('\n}',a)+2)}
const showToastSrc=fn(coreSrc,'showToast');

// Corps littéraux passés à showToast dans les sources du plateau (même règle que l'extraction du lot).
const lit=`('(?:[^'\\\\\\n]|\\\\.)*'|"(?:[^"\\\\\\n]|\\\\.)*")`;
const pat=new RegExp(`showToast\\(\\s*${lit}\\s*,\\s*${lit}\\s*[,)]`,'g');
const unesc=s=>s.replace(/\\(['"\\])/g,'$1').replace(/\\n/g,'\n');
function corpsSources(){const out=new Set();for(const f of fs.readdirSync(root).filter(f=>/^(plateau|forum).*\.js$/.test(f)))for(const m of read(f).matchAll(pat))out.add(unesc(m[2].slice(1,-1)));return out}

function sandbox(locale='fr',enabled=true){
 const nodes={'result-toast':{className:'',style:{}},'toast-result':{textContent:''},'toast-sub':{textContent:'',dataset:{},childElementCount:0}};
 const ctx={console,RP_I18N_GAME_ENABLED:enabled,RP_I18N_RESOURCES:Object.fromEntries(L.map(l=>[l,{translation:{}}])),
  document:{getElementById:id=>nodes[id]||null},setTimeout:()=>0,clearTimeout(){},incidents:[],current:locale};
 ctx.window=ctx;vm.createContext(ctx);
 vm.runInContext(read('i18n/i18next.min.js'),ctx);
 ctx.i18next.init({lng:locale,fallbackLng:false,resources:ctx.RP_I18N_RESOURCES,interpolation:{escapeValue:false}});
 ctx.RPPlateauI18n={language:()=>ctx.RP_I18N_GAME_ENABLED===true?ctx.current:'fr'};
 vm.runInContext(catalogueSrc,ctx,{filename:'toast-bodies'});
 vm.runInContext('function noterIncidentSession(k,r){incidents.push(r)}\n'+showToastSrc,ctx,{filename:'showToast'});
 return {ctx,nodes,set(l){ctx.current=l;for(const cb of ctx.RP_I18N_CHANGE_CALLBACKS||[])cb(l)}};
}

test('catalogue : neuf colonnes remplies, différentes du français, nombres et sigles conservés',()=>{
 assert.ok(rows.length>=174,'au moins le lot 1');
 const vus=new Set();
 for(const r of rows){
  assert.equal(r.length,9,r[0]);assert.ok(!vus.has(r[0]),'doublon '+r[0]);vus.add(r[0]);
  const nombres=s=>(s.replace(/(\d)[\s\u202f,.](?=\d{3}\b)/g,'$1').match(/\d+/g)||[]).sort().join(',');
  for(let i=1;i<9;i++){
   assert.ok(typeof r[i]==='string'&&r[i].trim(),L[i]+' vide : '+r[0]);
   // Identité admise seulement pour une variation de jauge seule (« +5 DIS. », « +2 Moral. » en es/pt-BR/de).
   if(!/^([+\-−]?\d+ (DIS|INF|POP|IP|Moral)\s*)+\.?$/.test(r[0]))assert.notEqual(r[i],r[0],L[i]+' identique au français : '+r[0]);
   assert.equal(nombres(r[i]),nombres(r[0]),L[i]+' nombres : '+r[0]);
   for(const s of r[0].match(/\b(FR|PSK|INF|DIS|IP|POP|F5)\b/g)||[])assert.match(r[i],new RegExp('\\b'+s+'\\b'),L[i]+' sigle '+s+' : '+r[0]);
   assert.doesNotMatch(r[i],/\{\{|\}\}|toastBodies\./,L[i]+' marqueur technique : '+r[0]);
   for(const nom of ['Sophie Stiquay','Jérémy','Républia','Helvetia'])if(r[0].includes(nom))assert.ok(r[i].includes(nom),L[i]+' nom propre '+nom);
  }
 }
});

test('chaque phrase du catalogue existe telle quelle dans les sources du plateau (aucune entrée inventée)',()=>{
 // Corps passés directement à showToast, ou via ternaire / || / table de motifs indexée (extraction AST du lot 6).
 const sources=corpsSources();
 const texte=fs.readdirSync(root).filter(f=>/^(plateau|forum).*\.js$/.test(f)).map(read).join('\n');
 const present=fr=>sources.has(fr)||[fr,fr.replace(/'/g,"\\'"),fr.replace(/"/g,'\\"')].some(v=>texte.includes("'"+v+"'")||texte.includes('"'+v+'"')||texte.includes('`'+v+'`'));
 assert.deepEqual(rows.map(r=>r[0]).filter(fr=>!present(fr)),[]);
});

test('aucun recouvrement avec les catalogues déjà raccordés (pas de double traduction ni de markToast contrarié)',()=>{
 const ctx={console:{log(){},warn(){}},document:{getElementById:()=>null,querySelectorAll:()=>[],addEventListener(){},documentElement:{}},navigator:{language:'fr'},localStorage:{getItem:()=>null,setItem(){}},location:{search:''},addEventListener(){}};
 ctx.window=ctx;vm.createContext(ctx);vm.runInContext(read('i18n/i18next.min.js'),ctx);
 const html=read('plateau.html');
 for(const f of [...html.matchAll(/src="(i18n\/[^"?]+)/g)].map(m=>m[1]).filter(f=>!/i18next|plateau-init|plateau-bridge|ordres\.js|texte-joueur|beta-language|toast-bodies/.test(f)))
  vm.runInContext(read(f),ctx,{filename:f});
 const fr=new Set();(function walk(o){for(const v of Object.values(o||{}))typeof v==='string'?fr.add(v):v&&typeof v==='object'&&walk(v)})(ctx.RP_I18N_RESOURCES.fr.translation);
 assert.deepEqual(rows.map(r=>r[0]).filter(x=>fr.has(x)),[]);
});

test('showToast : français intact, neuf langues traduites, phrase inconnue ou dynamique laissée telle quelle',()=>{
 const fr=rows[0][0];
 for(const [i,l] of L.entries()){
  const s=sandbox(l);
  s.ctx.showToast('Déplacement non confirmé',fr,false);
  assert.equal(s.nodes['toast-sub'].textContent,rows[0][i],l);
  assert.equal(s.nodes['toast-sub'].dataset.rpFr,fr);
  assert.deepEqual(s.ctx.incidents,['Déplacement non confirmé'],'incident signalé avec le titre original');
  s.ctx.showToast('Titre','Phrase dynamique 12 FR, inconnue du catalogue.',true);
  assert.equal(s.nodes['toast-sub'].textContent,'Phrase dynamique 12 FR, inconnue du catalogue.');
  s.ctx.showToast('Titre','',true);assert.equal(s.nodes['toast-sub'].textContent,'');
  s.ctx.showToast('Titre',undefined,true);assert.equal(s.nodes['toast-sub'].textContent,undefined);
 }
});

test('bêta fermée (RP_I18N_GAME_ENABLED absent) : tout reste en français',()=>{
 const s=sandbox('de',false);
 for(const r of rows.slice(0,40)){s.ctx.showToast('Titre',r[0],false);assert.equal(s.nodes['toast-sub'].textContent,r[0])}
});

test('repli : traduction absente du moteur → français, jamais la clé technique',()=>{
 const s=sandbox('en');
 const key=s.ctx.RPToastBodyI18n.key(rows[1][0]).split('.')[1];
 delete s.ctx.RP_I18N_RESOURCES.en.translation.toastBodies[key];
 s.ctx.showToast('Titre',rows[1][0],false);
 assert.equal(s.nodes['toast-sub'].textContent,rows[1][0]);
});

test('changement de langue pendant l’affichage : corps repeint, balisage markToast respecté',()=>{
 const s=sandbox('fr');
 s.ctx.showToast('Titre',rows[5][0],false);assert.equal(s.nodes['toast-sub'].textContent,rows[5][0]);
 s.set('ko');assert.equal(s.nodes['toast-sub'].textContent,rows[5][5]);
 s.set('ar');assert.equal(s.nodes['toast-sub'].textContent,rows[5][6]);
 s.set('fr');assert.equal(s.nodes['toast-sub'].textContent,rows[5][0]);
 s.nodes['toast-sub'].childElementCount=1;s.nodes['toast-sub'].textContent='balisé';s.set('en');
 assert.equal(s.nodes['toast-sub'].textContent,'balisé','un corps balisé par un autre catalogue n’est pas touché');
});

test('plateau.html : catalogue chargé après les titres et avant l’initialisation',()=>{
 const html=read('plateau.html');
 const a=html.indexOf('i18n/toast-resources.js'),b=html.indexOf('i18n/toast-bodies-resources.js'),c=html.indexOf('i18n/plateau-init.js');
 assert.ok(a>0&&b>a&&c>b,'ordre de chargement');
 assert.match(html,/plateau-core\.js\?v=corps-toasts-20261114-/);
});

test('navigateur : neuf langues, 320/390/1280, aucun débordement, saisie conservée au changement de langue',async t=>{
 let chromium;try{({chromium}=require('playwright'))}catch(_){return t.skip('playwright absent')}
 const exe=process.env.CHROMIUM_PATH||'/usr/bin/chromium';if(!fs.existsSync(exe))return t.skip('Chromium absent : '+exe);
 const plus=rows.map((r,i)=>[i,Math.max(...r.map(x=>x.length))]).sort((a,b)=>b[1]-a[1]).slice(0,6).map(x=>x[0]);
 const browser=await chromium.launch({headless:true,executablePath:exe,args:['--no-sandbox']});
 try{for(const width of [320,390,1280]){
  const page=await browser.newPage({viewport:{width,height:780}}),errors=[];page.on('pageerror',e=>errors.push(String(e)));
  await page.setContent(`<!doctype html><html><head><style>${read('style.css')}</style></head><body><input id="saisie" value=""><div id="result-toast"><div class="toast-result" id="toast-result"></div><div class="toast-sub" id="toast-sub"></div></div></body></html>`);
  await page.addScriptTag({content:read('i18n/i18next.min.js')});
  await page.evaluate(()=>{window.RP_I18N_GAME_ENABLED=true;window.noterIncidentSession=()=>{}});
  for(const f of ['i18n/resources.js','i18n/plateau-resources.js'])await page.addScriptTag({content:read(f)});
  await page.evaluate(()=>{window.RPPlateauI18n={language:()=>i18next.language||'fr'};if(!i18next.isInitialized)i18next.init({lng:'fr',resources:window.RP_I18N_RESOURCES,interpolation:{escapeValue:false}})});
  for(const f of ['i18n/toast-resources.js','i18n/toast-bodies-resources.js'])await page.addScriptTag({content:read(f)});
  await page.addScriptTag({content:showToastSrc+'\nwindow.showToast=showToast;'});
  await page.fill('#saisie','brouillon conservé 42');
  for(const [li,l] of L.entries())for(const i of plus){
   const r=await page.evaluate(async([l,fr])=>{await i18next.changeLanguage(l);for(const cb of window.RP_I18N_CHANGE_CALLBACKS||[])cb(l);
    showToast('Déplacement non confirmé',fr,false);const t=document.getElementById('result-toast'),s=document.getElementById('toast-sub'),b=t.getBoundingClientRect();
    return {txt:s.textContent,over:s.scrollWidth>s.clientWidth+1||t.scrollWidth>t.clientWidth+1,left:b.left,right:b.right,vw:innerWidth}},[l,rows[i][0]]);
   assert.equal(r.txt,rows[i][li],`${width} ${l} ${i}`);
   assert.equal(r.over,false,`débordement ${width} ${l} ${i}`);
   assert.ok(r.left>=-1&&r.right<=r.vw+1,`hors écran ${width} ${l} ${i} (${r.left}..${r.right}/${r.vw})`);
  }
  assert.equal(await page.inputValue('#saisie'),'brouillon conservé 42');
  assert.deepEqual(errors,[]);await page.close();
 }}finally{await browser.close()}
});
