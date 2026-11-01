'use strict';
// Saisie de la prime de signature à l'offre de transfert (Claude, 01/11/2026).
// Règle : GAME-DESIGN-FOOTBALL.md (prix au club de départ, prime facultative au joueur, payés par
// le club qui recrute). Vraies fonctions de plateau-organisations-quetes.js, dépendances simulées.
// Aucun réseau. CONTRE=<ref git> : rejoue contre une version sans champ de prime (doit échouer).
const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),{execFileSync}=require('node:child_process');
const acorn=require('../e2e/node_modules/acorn');
const root=path.resolve(__dirname,'../..'),ref=process.env.CONTRE;
const src=ref?execFileSync('git',['show',ref+':plateau-organisations-quetes.js'],{cwd:root,encoding:'utf8'}):fs.readFileSync(path.join(root,'plateau-organisations-quetes.js'),'utf8');
const noms=['doProposerTransfert','confirmerPropositionTransfert','doGererOffresTransfert','repondreOffreTransfert'];
const code=acorn.parse(src,{ecmaVersion:'latest'}).body.filter(n=>n.type==='FunctionDeclaration'&&noms.includes(n.id.name)).map(n=>src.slice(n.start,n.end)).join('\n');

function monde(saisies){
 const el={};const get=id=>(el[id]=el[id]||{value:saisies[id]??'',innerHTML:'',textContent:'',classList:{add(){},remove(){}}});
 const c={console,state:{char:{name:'Pres'}},offres:[],mails:[],toasts:[],debits:0,journal:[],
  document:{getElementById:get},
  getClubLocal:()=>({id:'arr'}),getClub:id=>({nom:id==='arr'?'Arrivée FC':'Départ FC'}),
  chargerPresidentClub:async id=>({president:id==='arr'?'Pres':'Vendeur'}),
  sbGetJoueurClub:async()=>({licence_sportive:{clubId:'dep'}}),
  deduireCoutOrdre:async()=>{c.debits++;return {ok:true};},signalerRefusCout(){},
  sbCreerTransfert:async d=>{c.offres.push(JSON.parse(JSON.stringify(d)));return 'transfert-1';},
  sbSendMail:async(de,a,sujet,corps)=>{c.mails.push({a,sujet,corps});},
  showToast:(t,m,ok)=>c.toasts.push({t,m,ok}),addJournalEntry:(t)=>c.journal.push(t),formatDateHeureJeu:()=>'',
  sbGetTransfertsClubVente:async()=>c.offres.map((o,i)=>({id:'t'+i,...o})),
  sbGet:async()=>[{data:{...c.offres[0]}}],sbMajTransfert:async()=>true,el};
 vm.createContext(c);vm.runInContext(code,c);return c;
}

test('le formulaire d offre propose la prime de signature',async()=>{
 const c=monde({});await c.doProposerTransfert(2,0);
 assert.match(c.el['postes-body'].innerHTML,/id="transfert-prime"/);
 assert.match(c.el['postes-body'].innerHTML,/Prime de signature au joueur/);
});

test('prime saisie : enregistrée dans l offre et annoncée au président vendeur',async()=>{
 const c=monde({'transfert-joueur':'Buteur','transfert-prix':'5000','transfert-prime':'800'});
 await c.confirmerPropositionTransfert('arr',2,0);
 assert.equal(c.offres.length,1);assert.equal(c.offres[0].prixClub,5000);assert.equal(c.offres[0].prixJoueur,800);
 assert.match(c.mails[0].corps,/prime de signature de 800 FR au joueur/);
 await c.doGererOffresTransfert();
 assert.match(c.el['postes-body'].innerHTML,/prime de signature au joueur : 800 FR/);
});

test('prime absente : 0, offre inchangée pour le reste',async()=>{
 const c=monde({'transfert-joueur':'Buteur','transfert-prix':'5000','transfert-prime':''});
 await c.confirmerPropositionTransfert('arr',2,0);
 assert.equal(c.offres[0].prixJoueur,0);assert.doesNotMatch(c.mails[0].corps,/prime/);
});

for(const mauvaise of ['-5','12.5','abc'])test('prime invalide ('+mauvaise+') : refus nommé avant tout débit ni offre',async()=>{
 const c=monde({'transfert-joueur':'Buteur','transfert-prix':'5000','transfert-prime':mauvaise});
 await c.confirmerPropositionTransfert('arr',2,0);
 assert.equal(c.debits,0);assert.equal(c.offres.length,0);assert.equal(c.toasts.at(-1).t,'Prime invalide');
});

test('accord des clubs : le joueur est informé de la prime',async()=>{
 const c=monde({'transfert-joueur':'Buteur','transfert-prix':'5000','transfert-prime':'800'});
 await c.confirmerPropositionTransfert('arr',2,0);c.mails.length=0;
 await c.repondreOffreTransfert('t0','accepte');
 assert.equal(c.mails[0].a,'Buteur');assert.match(c.mails[0].corps,/prime de signature de 800 FR pour vous/);
});
