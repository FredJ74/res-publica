// Chromium reel, transport fictif. Aucune identite ni transaction de production.
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {chromium}=require('../e2e/node_modules/playwright');const root=path.resolve(__dirname,'../..');
test('journal existant : dix ventes, une alerte, acquittement groupe, historique, aucune horloge',async()=>{
 const executablePath=process.env.CHROMIUM_BIN||['/usr/bin/chromium','/usr/bin/chromium-browser','/usr/bin/google-chrome'].find(fs.existsSync);assert.ok(executablePath);
 const b=await chromium.launch({executablePath,args:['--no-sandbox'],headless:true});
 try{const p=await b.newPage();await p.setContent('<div id="journal"></div><span id="journal-badge" style="display:none"></span>');
 await p.addScriptTag({content:`window.state={char:{name:'Proprio'}};window.uid='uid-fixture';window.rpAuthUid=()=>uid;window.rpAuthSessionIdentifiant=()=> 'session';window.rpRealitesEnregistrer=(n,f)=>window.lecteur=f;window.compteur=0;window.alertes=0;window.lues=false;window.signalerEvenementJournal=()=>{alertes++;document.getElementById('journal-badge').style.display='block';};window.showToast=()=>{};window.formaterHorodatageJournal=x=>x;
 window.sbRpcVerdict=async(n,a)=>{compteur++;if(a.p_acquitter)lues=true;return {ok:true,nonLues:lues?0:10,evenements:Array.from({length:10},(_,i)=>({id:'vente-'+i,ts:'2026-10-22',acheteur:'Arnie',enseigne:'Slava <img src=x onerror=alert(1)>',article:'Chocolat chaud',quantite:1,montant:20}))};};`});
 await p.addScriptTag({path:path.join(root,'plateau-journal-ventes.js')});
 assert.equal(await p.evaluate(()=>compteur),0,'aucune lecture lors du chargement du module');
 await p.evaluate(()=>initialiserJournalVentes());await p.waitForFunction(()=>document.querySelectorAll('[data-vente-journal]').length===10);
 assert.equal(await p.evaluate(()=>alertes),1);assert.equal(await p.locator('#journal img').count(),0,'donnees echappees');assert.match(await p.locator('#journal').innerText(),/Arnie.*20 FR/);
 const confirme=await p.evaluate(()=>chargerJournalVentes(true));assert.equal(confirme,true,'acquittement confirme par le serveur');assert.equal(await p.evaluate(()=>lues),true);assert.equal(await p.locator('[data-vente-journal]').count(),10,'acquittement ne supprime pas historique');
 const refuse=await p.evaluate(async()=>{const ancien=sbRpcVerdict;window.sbRpcVerdict=async()=>{throw Error('indisponible')};const resultat=await chargerJournalVentes(true);window.sbRpcVerdict=ancien;return resultat;});
 assert.equal(refuse,false,'une panne reseau ne confirme jamais le badge');
 assert.match(fs.readFileSync(path.join(root,'plateau.html'),'utf8'),/if \\(confirme && badge\\) badge\\.style\\.display/,'le badge depend du resultat du serveur');
 const avant=await p.evaluate(()=>compteur);await p.waitForTimeout(150);assert.equal(await p.evaluate(()=>compteur),avant,'navigateur inactif sans interrogation');
 await p.evaluate(()=>{document.getElementById('journal').innerHTML='';initialiserJournalVentes();});assert.equal(await p.locator('[data-vente-journal]').count(),10,'rendu restaure sans nouvelle copie sauvegardee');
 await p.evaluate(()=>{window.sbRpcVerdict=()=>new Promise(r=>window.finir=r);window.attente=chargerJournalVentes(false);uid='autre-uid';state.char.name='Autre';document.getElementById('journal').innerHTML='';finir({ok:true,nonLues:1,evenements:[{id:'interdit'}]});});await p.evaluate(()=>attente);assert.equal(await p.locator('[data-vente-journal]').count(),0,'reponse ancienne ignoree');
 }finally{await b.close();}
});
