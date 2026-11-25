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
function fn(s,name){const a=s.indexOf('function '+name+'(');assert.ok(a>=0,name);return s.slice(s.slice(a-6,a)==='async '?a-6:a,s.indexOf('\n}',a)+2)}
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
   if(!/^([+\-−]?\d+ (DIS|INF|POP|IP|ID|Moral)\s*)+\.?$/.test(r[0]))assert.notEqual(r[i],r[0],L[i]+' identique au français : '+r[0]);
   assert.equal(nombres(r[i]),nombres(r[0]),L[i]+' nombres : '+r[0]);
   for(const s of r[0].match(/\b(FR|PSK|INF|DIS|IP|POP|F5)\b/g)||[])assert.match(r[i],new RegExp('\\b'+s+'\\b'),L[i]+' sigle '+s+' : '+r[0]);
   assert.doesNotMatch(r[i],/\{\{|\}\}|toastBodies\./,L[i]+' marqueur technique : '+r[0]);
   for(const nom of ['Sophie Stiquay','Jérémy','Républia','Helvetia'])if(r[0].includes(nom))assert.ok(r[i].includes(nom),L[i]+' nom propre '+nom);
  }
 }
});

test('provenance des phrases actives et des phrases retirées documentées',()=>{
 // Corps passés directement à showToast, ou via ternaire / || / table de motifs indexée (extraction AST du lot 6).
 const sources=corpsSources();
 const texte=fs.readdirSync(root).filter(f=>/^(plateau|forum).*\.js$/.test(f)).map(read).join('\n');
 const present=fr=>sources.has(fr)||[fr,fr.replace(/'/g,"\\'"),fr.replace(/"/g,'\\"')].some(v=>texte.includes("'"+v+"'")||texte.includes('"'+v+'"')||texte.includes('`'+v+'`'));
 // Source supprimée par les correctifs de navigation : conserver sa provenance,
 // sans admettre d'autre phrase absente ni modifier le catalogue historique.
 const retire='Impossible de restaurer la position depuis le serveur.';
 const ancien=require('node:child_process').execFileSync('git',['show','e688472:plateau-rue-centrale.js'],{cwd:root,encoding:'utf8',maxBuffer:4e6});
 assert.ok(ancien.includes(retire));assert.equal(present(retire),false);
 // 16/11/2026 : la limite fixe de 2 récoltes par jour n'existe plus (régulation de la production).
 // 17/11/2026 : le +5 DIS du don au banquier PNJ est suspendu (failles de l'audit, la DIS ne monte plus à l'écran).
 // 18/11/2026 : le refus de vote vient désormais des motifs serveur (nationalite_requise, hors_de_son_pays, non_domicilie).
 // 18/11/2026 : contrôle « consommation sur place » retiré de la vente de matières aux commerces de joueurs (il lisait une variable inexistante).
 // 19/11/2026 (criminalité lot 5) : empoisonner, incendier, explosifs passent par plateau-criminalite.js (crime_* serveur, textes T.fr) ;
 // les anciens toasts (prérequis « Se cacher », recherché d'office, blessure progressive) n'existent plus.
 const CRIM_LOT5=['Vous devez être dans un bâtiment pour tenter ceci.','Le feu ne prend pas. Rien ne se passe.',"Vous n'avez pas d'explosifs dans votre inventaire. Procurez-vous en à l'armurerie.","Vous n'avez pas d'explosifs dans votre inventaire.",'Le dispositif vous explose entre les mains. Vous êtes blessé(e).','Vous devez d\'abord réussir l\'ordre "Se cacher" dans cette pièce.',"Vous n'avez pas d'objet poison dans votre inventaire. Procurez-vous en dans votre empire.",'Aucun PJ dans cette pièce.',"Vous n'avez pas d'objet poison dans votre inventaire.","L'empoisonnement n'a pas pu avoir lieu.",'Un témoin vous a vu(e). Vous êtes désormais recherché(e).',"L'empoisonnement a échoué. Objet perdu. Vous avez été identifié(e)."];
 // 20/11/2026 (criminalité lot 6) : la rébellion matée n'envoie plus au QHS (§ 14) ; son toast vient de plateau-criminalite.js (T.fr).
 const CRIM_LOT6=['Transfere au QHS. -25 PV, -15 DIS.'];
 // Audit des chances (mission du soir, 25/11/2026, bloc 1A) : la contrebande dit l'issue réelle, la visite passe par le serveur.
 const AUDIT_CHANCES=['La douane a repéré la manœuvre.',"Ce détenu n'est plus détenu au QHS."];
 // 20/11/2026 (criminalité lot 7) : corruption — doCorruption, l'accélération du permis, du rendez-vous notarial et du chantier
 // sont supprimées (« le temps ne s'achète pas ») ; le directeur et le gardien du QHS passent par plateau-criminalite.js (T.fr).
 const CRIM_LOT7=["Vous n'avez pas de rendez-vous en attente ici.",'Le navigateur ne peut pas conserver la référence de cet ordre.','Le service a ete obtenu. -5 DIS.',
  'La tentative de corruption a echoue.','Aucun paiement ne permet d’accélérer une construction dans les empires actuels.','Le fonctionnaire vous dénonce.',
  'Le fonctionnaire a fait remonter votre dossier. Instruction raccourcie.','Réponse incertaine. Relancez le même ordre : il ne sera pas payé deux fois.'];
 // 22/11/2026, étape H : le journaliste dépend désormais de la ville. Conserver les
 // traductions historiques sans prétendre que ces sept anciennes phrases sont actives.
 const INTERVIEW_ACCUEIL=[
  "Vous avez décliné l'interview de Jodie Moitout.",
  'Vous avez déjà décliné cette proposition — Jodie ne relance pas.',
  'Jodie a déjà publié votre portrait dans Presse & Médias.',
  'Merci de répondre à chacune des 5 questions.',
  "Jodie a rédigé votre portrait : rouvrez sa proposition (« Accepter l'interview ») pour le relire avant publication.",
  'Jodie a publié votre portrait dans Presse & Médias.',
  "Jodie n'arrive pas à rédiger."
 ];
 const avantInterview=require('node:child_process').execFileSync('git',['show','18aeb8e1:plateau-communication.js'],{cwd:root,encoding:'utf8',maxBuffer:4e6});
 for(const fr of INTERVIEW_ACCUEIL){
  assert.ok(avantInterview.includes(fr)||avantInterview.includes(fr.replace(/'/g,"\\'")),'provenance antérieure : '+fr);
  assert.equal(present(fr),false,'phrase retirée, non réactivée : '+fr);
 }
 // Étape K, 22/11 : les contrats d'informateurs sont remplacés par l'achat d'informations.
 // Vérifier chaque ancien texte dans le dernier main précédant cette refonte.
 // Santé (Fred, 22/11/2026, GAME-DESIGN-SANTE-20261122.md, point 15) : « PV » devient « Santé » dans les messages ; ces trois
 // corps ne sont plus affichés tels quels (nouvelles phrases françaises à traduire par Codex, RELAIS.md).
 const SANTE_PV=["Vos PV sont tombes a 0. Hospitalisation d'urgence.",'Vous vous échappez malgré tout. −30 DIS −15 PV.',
  'Vous avez tenu tete aux gardiens. +6 DIS, mais +1 jour de detention et -10 PV.'];
 const INFORMATEURS_REFONTE=[
  "Vous employez déjà un informateur. Renvoyez-le avant d'en recruter un autre.",
  'Vous ne pouvez avoir que 2 informateurs simultanément.',
  "Le congé n'a pas pu être enregistré.",
  'Vous avez déjà un informateur de ce niveau.',
  'Fonds insuffisants pour le premier jour de salaire.',
  "Ce niveau d'informateur ne se recrute pas ici.",
  "Vous n'avez pas d'informateur de ce niveau.",
  "Personne n'a donné suite."
 ];
 const avantInformateurs=['plateau-multijoueur.js','plateau-actions-illegales-rumeurs.js'].map(f=>require('node:child_process').execFileSync('git',['show','5a1c24e1:'+f],{cwd:root,encoding:'utf8',maxBuffer:4e6})).join('\n');
 for(const fr of INFORMATEURS_REFONTE){
  assert.ok(avantInformateurs.includes(fr)||avantInformateurs.includes(fr.replace(/'/g,"\\'")),'provenance informateurs : '+fr);
  assert.equal(present(fr),false,'ancienne phrase d’informateur non réactivée : '+fr);
 }
 // Tabac-presse (Fred, 22/11/2026, point 28) : la carte postale s'écrit et s'envoie par le serveur (carte_postale_envoyer) ; ces
 // quatre anciens contrôles du navigateur n'existent plus (motifs serveur). Provenance : plateau-personnage.js avant 825d6f89.
 const CARTE_POSTALE_SERVEUR=['Choisissez un joueur destinataire.','Vous ne pouvez pas vous envoyer une carte à vous-même.',
  "Écrivez un message avant d'envoyer.",'Le service de courrier est indisponible pour le moment.'];
 const avantCarte=require('node:child_process').execFileSync('git',['show','825d6f89^:plateau-personnage.js'],{cwd:root,encoding:'utf8',maxBuffer:8e6});
 for(const fr of CARTE_POSTALE_SERVEUR){
  assert.ok(avantCarte.includes(fr)||avantCarte.includes(fr.replace(/'/g,"\\'")),'provenance carte postale : '+fr);
  assert.equal(present(fr),false,'ancienne phrase de carte postale non réactivée : '+fr);
 }
 assert.deepEqual(rows.map(r=>r[0]).filter(fr=>!present(fr)),[retire,'Maximum 2 récoltes par jour.','+5 DIS.','Vous ne pouvez pas voter dans cet empire.','Cette prestation ne peut pas être vendue à emporter.',...CRIM_LOT5,...CRIM_LOT6,...CRIM_LOT7,...INTERVIEW_ACCUEIL,...INFORMATEURS_REFONTE,...SANTE_PV,...CARTE_POSTALE_SERVEUR,...AUDIT_CHANCES].filter(fr=>rows.some(r=>r[0]===fr)).sort((a,b)=>rows.findIndex(r=>r[0]===a)-rows.findIndex(r=>r[0]===b)));
});

test('aucun recouvrement avec les catalogues déjà raccordés (pas de double traduction ni de markToast contrarié)',()=>{
 const ctx={console:{log(){},warn(){}},document:{getElementById:()=>null,querySelectorAll:()=>[],addEventListener(){},documentElement:{}},navigator:{language:'fr'},localStorage:{getItem:()=>null,setItem(){}},location:{search:''},addEventListener(){}};
 ctx.window=ctx;vm.createContext(ctx);vm.runInContext(read('i18n/i18next.min.js'),ctx);
 const html=read('plateau.html');
 for(const f of [...html.matchAll(/src="(i18n\/[^"?]+)/g)].map(m=>m[1]).filter(f=>!/i18next|plateau-init|plateau-bridge|ordres\.js|texte-joueur|beta-language|toast-bodies/.test(f)))
  vm.runInContext(read(f),ctx,{filename:f});
 const fr=new Set();(function walk(o){for(const v of Object.values(o||{}))typeof v==='string'?fr.add(v):v&&typeof v==='object'&&walk(v)})(ctx.RP_I18N_RESOURCES.fr.translation);
 // Exception nommée (24/11/2026, fusion de #1132) : ces deux refus du Commerce PJ sont traduits par leurs propres clés
 // (commercepj.refus.bail_absent / pas_titulaire, i18n/commerce-pj-complements-20261119.js) avant l'affichage ; le corps de
 // notification français n'est donc jamais retraduit une seconde fois.
 const COMMUNS_COMMERCE_PJ=new Set(['Vous ne louez pas ce local.',"Ce bail n'est pas le vôtre."]);
 assert.deepEqual(rows.map(r=>r[0]).filter(x=>fr.has(x)&&!COMMUNS_COMMERCE_PJ.has(x)),[]);
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


test('contenu joueur : texte libre intact même identique à une phrase fixe, ordre/journal/PA inchangés',async()=>{
 const fr=rows.find(r=>r[0]!==r[1]&&r[0].includes(' '))[0];
 for(const l of L){
  const s=sandbox(l),ctx=s.ctx;ctx.state={pa:9,arg:500,progression:{etape:4}};ctx.journal=[];ctx.rpcCalls=[];
  s.nodes['texte-libre-input']={value:fr};s.nodes['modal-postes']={classList:{remove(){}}};
  ctx.addJournalEntry=(...args)=>ctx.journal.push(args);ctx.sbRpc=(...args)=>{ctx.rpcCalls.push(args);throw Error('RPC interdit');};
  vm.runInContext(fn(read('plateau-politique.js'),'executerOrdreTexte'),ctx);
  const before=JSON.stringify(ctx.state);await ctx.executerOrdreTexte('texte_fixture');
  assert.equal(s.nodes['toast-sub'].textContent,fr);assert.equal(s.nodes['toast-sub'].dir,'auto');assert.equal(s.nodes['toast-sub'].dataset.rpFr,'');
  assert.deepEqual(JSON.parse(JSON.stringify(ctx.journal)),[['texte_fixture : '+fr,'event-info']]);
  for(const next of L){s.set(next);assert.equal(s.nodes['toast-sub'].textContent,fr);assert.equal(s.nodes['texte-libre-input'].value,fr);}
  assert.equal(JSON.stringify(ctx.state),before);assert.equal(ctx.rpcCalls.length,0);
  // Une notification fixe suivante est de nouveau traduite normalement.
  s.set('en');ctx.showToast('Info',fr,true);assert.equal(s.nodes['toast-sub'].textContent,rows.find(r=>r[0]===fr)[1]);
 }
});


test('direction : arabe RTL, jauges LTR et balisage spécialisé conservé',()=>{
 const row=rows.find(r=>/^[A-Za-zÀ-ÿ]/.test(r[0])&&/[\u0600-\u06ff]/.test(r[6])&&r[0]!==r[6]);assert.ok(row);
 const s=sandbox('ar');s.ctx.showToast('Info',row[0],true);assert.equal(s.nodes['toast-sub'].dir,'rtl');
 s.set('de');assert.equal(s.nodes['toast-sub'].dir,'auto');
 assert.equal(s.ctx.RPToastBodyI18n.direction('+5 DIS.','+5 DIS.'),'ltr');
 s.set('ar');s.nodes['toast-sub'].childElementCount=1;s.nodes['toast-sub'].textContent='Balisage propre conservé';s.set('de');
 assert.equal(s.nodes['toast-sub'].textContent,'Balisage propre conservé');assert.equal(s.nodes['toast-sub'].dir,'auto');
});
