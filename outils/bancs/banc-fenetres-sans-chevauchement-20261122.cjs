'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {avecJeu,page,R}=require('./mobile-navigateur.cjs');
const fs=require('node:fs'),path=require('node:path'),acorn=require('../e2e/node_modules/acorn');
const src=fs.readFileSync(path.join(R,'plateau-multijoueur.js'),'utf8');
const fonctions=acorn.parse(src,{ecmaVersion:'latest'}).body.filter(n=>n.type==='FunctionDeclaration'&&['toggleChatPiece','ouvrirConversationAvec'].includes(n.id.name)).map(n=>src.slice(n.start,n.end));
const journal=[...fs.readFileSync(path.join(R,'plateau.html'),'utf8').matchAll(/<script[^>]*>([\s\S]*?)<\/script>/g)].map(m=>m[1]).find(x=>x.includes('async function toggleJournalStore()'));
const fn=acorn.parse(journal,{ecmaVersion:'latest'}).body.find(n=>n.type==='FunctionDeclaration'&&n.id.name==='toggleJournalStore');
fonctions.push(journal.slice(fn.start,fn.end));
for(const largeur of [320,390,1280])test(`fenêtres sans chevauchement à ${largeur}px, saisies et commandes conservées`,async()=>avecJeu(async(b,o)=>{
 const p=await page(b,o,largeur,900,false,{texteMinimum:true});
 await p.addScriptTag({content:fonctions.join('\n')});
 await p.evaluate(()=>{
  window.appels=0;window.paiements=0;window.fetch=()=>{appels++;throw Error('RPC interdit');};
  window._chatInterval=null;window._chatMasqueMoi=false;window._chatAliasMoi=null;window._conversationActuelle=null;
  window.state={char:{name:'Fixture'}};window.ouverturesChat=0;window.acquittementsJournal=0;
  window.ouvrirListeConversations=()=>{ouverturesChat++;};window.chatRafraichirAlias=async()=>{};
  window.getConversationId=(a,b)=>a+'__'+b;window.afficherVueConversation=()=>{};
  window.chargerJournalVentes=async()=>{acquittementsJournal++;return true;};
  const compose=document.querySelector('#modal-compose-mail');
  compose.querySelector('textarea').value='Brouillon préservé';
  compose.classList.add('open');
 });
 const visible=()=>p.locator('.modal-overlay.open:visible,dialog[open]:visible,#chat-piece-panel:visible,#journal-store:visible');
 await p.waitForTimeout(40);
 assert.equal(await visible().count(),1);
 // Les gestionnaires réels de fermeture restent en place ; aucun clic métier pour suspendre.
 await p.evaluate(()=>{
  const m=document.querySelector('#modal-postes');
  m.querySelector('.modal-close').onclick=()=>m.classList.remove('open');
  document.querySelector('#postes-body').innerHTML='<button id="commande-fixture" onclick="paiements++">Commande</button>';
  m.classList.add('open');
 });
 await p.waitForTimeout(40);
 assert.equal(await visible().count(),1);
 assert.equal(await p.locator('#modal-compose-mail').getAttribute('aria-hidden'),'true');
 assert.equal(await p.locator('#modal-compose-mail').evaluate(e=>e.inert),true);
 await p.locator('#commande-fixture').click();assert.equal(await p.evaluate(()=>paiements),1);
 // Une fenêtre dynamique, puis un dialogue natif d'information, se referment sans détruire le parent.
 for(let tour=0;tour<3;tour++){
  await p.evaluate(()=>{
   const m=document.createElement('div');m.id='dynamique-fixture';m.className='modal-overlay open';
   m.innerHTML='<div class="modal-box"><button class="modal-close" onclick="this.closest(\'.modal-overlay\').remove()">Fermer</button></div>';document.body.append(m);
  });
  await p.waitForTimeout(40);assert.equal(await visible().count(),1);
  await p.evaluate(()=>{document.querySelector('#dialog-fixture')?.remove();const d=document.createElement('dialog');d.id='dialog-fixture';d.innerHTML='<button onclick="this.closest(\'dialog\').close()">OK</button>';document.body.append(d);d.showModal();});
  await p.waitForTimeout(40);assert.equal(await visible().count(),1);
  await p.evaluate(()=>{const m=document.createElement('div');m.id='confirmation-anonyme-fixture';m.style.cssText='position:fixed;inset:0;display:flex';m.innerHTML='<button>Confirmation</button>';document.body.append(m);});
  await p.waitForTimeout(40);assert.equal(await p.locator('#confirmation-anonyme-fixture').isVisible(),false,'la modalité native reste prioritaire');
  await p.locator('#dialog-fixture button').click();
  await p.waitForTimeout(40);assert.equal(await p.locator('#confirmation-anonyme-fixture').isVisible(),true);
  await p.locator('#confirmation-anonyme-fixture').evaluate(e=>e.remove());
  await p.waitForTimeout(40);assert.equal(await visible().count(),1);
  await p.locator('#dynamique-fixture button').click();
  await p.waitForTimeout(40);assert.equal(await visible().count(),1);
  assert.equal(await p.locator('#modal-postes').isVisible(),true);
 }
 await p.locator('#modal-postes .modal-close').click();await p.waitForTimeout(40);
 assert.equal(await p.locator('#modal-compose-mail').isVisible(),true);
 assert.equal(await p.locator('#modal-compose-mail textarea').inputValue(),'Brouillon préservé');
 assert.equal(await p.locator('#modal-compose-mail').evaluate(e=>e.inert),false);
 assert.equal(await p.locator('#modal-compose-mail').getAttribute('aria-hidden'),null);
 for(const panneau of ['chat-piece-panel','journal-store']){
  await p.evaluate(id=>document.getElementById(id).style.display='flex',panneau);
  await p.waitForTimeout(40);assert.equal(await visible().count(),1);
  await p.evaluate(id=>document.getElementById(id).style.display='none',panneau);
  await p.waitForTimeout(40);assert.equal(await visible().count(),1);
 }
 // Même schéma que ouvrirConversationAvec : réassigner display=flex sur un chat
 // encore ouvert mais en attente doit le ramener devant, sans recharger son contenu.
 await p.evaluate(()=>{document.getElementById('chat-piece-panel').style.display='flex';});await p.waitForTimeout(40);
 await p.evaluate(()=>{document.getElementById('journal-store').style.display='flex';});await p.waitForTimeout(40);
 assert.equal(await p.locator('#journal-store').isVisible(),true);
 await p.evaluate(()=>ouvrirConversationAvec('Autre fixture'));await p.waitForTimeout(40);
 assert.equal(await p.locator('#chat-piece-panel').isVisible(),true,'réouverture d’une fenêtre pilotée par display');
 assert.equal(await visible().count(),1);
 await p.evaluate(()=>toggleJournalStore());await p.waitForTimeout(40);
 assert.equal(await p.locator('#journal-store').isVisible(),true,'reprendre le journal au lieu de le fermer');
 assert.equal(await p.evaluate(()=>acquittementsJournal),0,'aucun acquittement supplémentaire à la reprise');
 await p.evaluate(()=>toggleChatPiece());await p.waitForTimeout(40);
 assert.equal(await p.locator('#chat-piece-panel').isVisible(),true,'reprendre le chat au lieu de le fermer');
 assert.equal(await p.evaluate(()=>ouverturesChat),0,'aucune reconstruction supplémentaire du chat');
 await p.evaluate(()=>{document.getElementById('chat-piece-panel').style.display='none';});await p.waitForTimeout(40);
 assert.equal(await p.locator('#journal-store').isVisible(),true);
 await p.evaluate(()=>{document.getElementById('journal-store').style.display='none';});await p.waitForTimeout(40);
 await p.evaluate(()=>{document.querySelector('#modal-postes').classList.add('open');});await p.waitForTimeout(40);
 await p.evaluate(()=>{document.querySelector('#modal-compose-mail').classList.add('open');});await p.waitForTimeout(40);
 assert.equal(await p.locator('#modal-compose-mail').isVisible(),true);assert.equal(await visible().count(),1);
 assert.equal(await p.evaluate(()=>appels),0);assert.equal(await p.evaluate(()=>paiements),1);
 assert.equal(await p.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1),true);
}));
