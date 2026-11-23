// Bancs navigateur communs : HTML réel, trafic extérieur refusé, ressources fermées même en échec.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),http=require('node:http'),zlib=require('node:zlib'),crypto=require('node:crypto');
const {chromium}=require('../e2e/node_modules/playwright');
const R=path.resolve(__dirname,'../..');
const reference=fs.readFileSync(path.join(__dirname,'fixtures/mobile-temoin-728010c8-human-gambit-20261122.json.gz'));
assert.equal(crypto.createHash('sha256').update(reference).digest('hex'),'0c402cd6e27f5c96e56fa0a32081ba5cd0c6a1458ba3ff0a4648e051ea9e4b30');
const temoin=JSON.parse(zlib.gunzipSync(reference));
assert.equal(temoin.commit,'728010c844597087e7c4063f72fabbcb2a746723');
const lecture=(f,ancien)=>ancien?Buffer.from(temoin.fichiers[f]):fs.readFileSync(path.join(R,f));
function preuve(nom,b){const d=process.env.HG_MOBILE_PREUVES;if(d){fs.mkdirSync(d,{recursive:true});fs.writeFileSync(path.join(d,nom),b);}}
async function avecJeu(f){
 const serveur=http.createServer((q,r)=>{let u=new URL(q.url,'http://localhost');let nom=u.pathname.slice(1),ancien=u.searchParams.has('ancien');
 try{let b=lecture(nom,ancien);if(nom==='plateau.html')b=Buffer.from(b.toString().replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi,''));r.setHeader('Content-Type',nom.endsWith('.css')?'text/css':nom.endsWith('.js')?'text/javascript':'text/html');r.end(b);}catch{r.writeHead(404);r.end();}});
 await new Promise(r=>serveur.listen(0,'127.0.0.1',r));const origine='http://127.0.0.1:'+serveur.address().port;
 let b;try{b=await chromium.launch({executablePath:process.env.HG_CHROMIUM||['/usr/bin/chromium','/usr/bin/google-chrome','/usr/bin/google-chrome-stable'].find(fs.existsSync),args:['--no-sandbox']});await f(b,origine);}finally{if(b)await b.close();serveur.closeAllConnections();await new Promise(r=>serveur.close(r));}
}
async function page(b,o,w,h,ancien=false,options={}) {
 const c=await b.newContext({viewport:{width:w,height:h},hasTouch:w<1024,...options.contexte});
 await c.route('**/*',r=>{
  const url=new URL(r.request().url());
  if(url.origin!==o)return r.abort();
  const nom=url.pathname.slice(1);
  if(options.fichiers&&Object.hasOwn(options.fichiers,nom))
   return r.fulfill({contentType:nom.endsWith('.css')?'text/css':'text/javascript',body:options.fichiers[nom]});
  return r.continue();
 });
 const p=await c.newPage();p.setDefaultTimeout(5000);
 await p.goto(o+'/plateau.html'+(ancien?'?ancien':''));
 if(ancien){await p.addStyleTag({content:lecture('style.css',true).toString()});await journalChatTemoin(p);}
 else {
  // Les bancs historiques isolent leurs rendus antérieurs au plancher de texte.
  // Le chargement conjoint est explicite dans les recettes d'intégration actuelles.
  if (options.texteMinimum) await p.addScriptTag({url:o+'/plateau-texte-minimum.js'});
  await p.addScriptTag({url:o+'/plateau-fenetres.js'});
  await p.addScriptTag(options.mobileSource?{content:options.mobileSource}:{url:o+'/plateau-mobile.js'});
 }
 await p.waitForTimeout(500);return p;
}

// Jauges Santé et Moral à côté des PA (Fred, 22/11/2026, GAME-DESIGN-SANTE-20261122.md, point 14) : changement voulu du
// panneau « Mon personnage », appliqué aussi au témoin (même bloc HTML que plateau.html, même bloc CSS que style.css) pour
// que la comparaison au pixel continue de porter sur tout le reste.
// Panneau de gauche refait (Fred, 23/11/2026, GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md, points 16 à 19) : deuxième
// ligne de jauges, Argent cliquable, plus de « Mes statistiques », Inventaire devenu une fenêtre. Le témoin reçoit les
// deux blocs courants (jauges → objectifs, puis titre Inventaire) à la place des siens.
const htmlCourant=fs.readFileSync(path.join(R,'plateau.html'),'utf8'),cssCourant=fs.readFileSync(path.join(R,'style.css'),'utf8');
const BLOC_JAUGES=htmlCourant.slice(htmlCourant.indexOf('<!-- Ligne 1 : PA, Santé, Moral -->'),htmlCourant.indexOf('<!-- LOCATION — masqué'));
const debutInv=htmlCourant.indexOf('<!-- INVENTAIRE (point 18)');
const BLOC_INVENTAIRE=htmlCourant.slice(debutInv,htmlCourant.indexOf('</div>',htmlCourant.indexOf('id="hg-panneau-inventaire"'))+6);
const CSS_JAUGES=cssCourant.slice(cssCourant.indexOf('/* SANTÉ ET MORAL, MÉDECIN, MONTRER UN OBJET'));
assert.ok(BLOC_JAUGES.includes('hg-jauge-sante')&&BLOC_JAUGES.includes('hg-jauge-influence')&&CSS_JAUGES.includes('.hg-jauge{'),'bloc des jauges introuvable');
assert.ok(debutInv>0&&BLOC_INVENTAIRE.includes('ouvrirFenetreInventaire()'),'bloc Inventaire introuvable');
async function jaugesSanteTemoin(p){
 await p.evaluate(([html,inv])=>{if(document.getElementById('hg-jauge-sante'))return;
  const rang=document.getElementById('r-pa').parentElement.parentElement,fin=document.getElementById('loc-city');
  while(rang.nextSibling&&rang.nextSibling!==fin)rang.nextSibling.remove();
  const t=document.createElement('template');t.innerHTML=html;rang.replaceWith(t.content);
  const panneau=document.getElementById('inventaire-panel'),titre=panneau&&panneau.previousElementSibling;
  if(panneau&&titre){const t2=document.createElement('template');t2.innerHTML=inv;titre.replaceWith(t2.content);panneau.remove();}
 },[BLOC_JAUGES,BLOC_INVENTAIRE]);
 await p.addStyleTag({content:CSS_JAUGES});
}

// Journal et chat (Fred, 23/11/2026, GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md, points 21 et 22) : changement voulu,
// appliqué au témoin comme les jauges : boutons ronds en bas à droite (l'un au-dessus de l'autre), journal sans « Rapports de
// combat » et avec sa croix en vrai bouton, panneaux qui laissent les boutons libres. Mêmes balises que plateau.html.
const JOURNAL_COURANT=htmlCourant.slice(htmlCourant.indexOf('<!-- JOURNAL FLOTTANT (store) -->'),htmlCourant.indexOf('<!-- MODAL PARLER PNJ -->'));
const ouverture=(html,debut)=>{const i=html.indexOf(debut);return html.slice(i,html.indexOf('>',i)+1);};
const CHAT_BOUTON=ouverture(htmlCourant,'<button id="hg-chat-toggle"'),CHAT_PANNEAU=ouverture(htmlCourant,'<div id="chat-piece-panel"');
const CSS_JOURNAL=cssCourant.slice(cssCourant.indexOf('/* JOURNAL ET CHAT (Fred, 23/11/2026'));
assert.ok(JOURNAL_COURANT.includes('journal-fermer')&&CHAT_BOUTON.includes('right:20px')&&CSS_JOURNAL.includes('.hg-journal-fermer'),'blocs journal et chat introuvables');
async function journalChatTemoin(p){
 await p.evaluate(([journal,bouton,panneau])=>{
  const copie=(el,html)=>{if(!el)return;const t=document.createElement('template');t.innerHTML=html;const n=t.content.firstElementChild;
   for(const a of [...el.attributes])el.removeAttribute(a.name);for(const a of [...n.attributes])el.setAttribute(a.name,a.value);};
  const store=document.getElementById('journal-store'),btn=document.getElementById('journal-open-btn');
  if(store&&btn){const t=document.createElement('template');t.innerHTML=journal;btn.replaceWith(...t.content.querySelectorAll('#journal-open-btn'));
   document.getElementById('journal-store').replaceWith(t.content.querySelector('#journal-store')||document.createElement('div'));}
  copie(document.querySelector('button[onclick="toggleChatPiece()"]'),bouton);copie(document.getElementById('chat-piece-panel'),panneau);
 },[JOURNAL_COURANT,CHAT_BOUTON+'</button>',CHAT_PANNEAU+'</div>']);
 await p.addStyleTag({content:CSS_JOURNAL});
}

module.exports={R,temoin,lecture,preuve,avecJeu,page,jaugesSanteTemoin,journalChatTemoin};
