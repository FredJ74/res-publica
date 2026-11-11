// Test de l'interface HRP réelle dans Chromium : aucun serveur de jeu, aucune transaction.
const test=require('node:test');
const assert=require('node:assert/strict');
const {avecJeu,page}=require('./mobile-navigateur.cjs');
test('Aide : première page visible et sans débordement en mobile et en bureau',async()=>avecJeu(async(b,o)=>{
 for(const [width,height] of [[375,667],[393,852],[1440,900]]){
  const p=await page(b,o,width,height);
  await p.evaluate(()=>{
    document.querySelectorAll('.vue').forEach(v=>v.classList.remove('active'));
    document.getElementById('vue-rules').classList.add('active');
    window.renderAideHrp();
  });
  assert.ok(await p.locator('#aide-hrp-form').isVisible());
  assert.match(await p.locator('.aide-hrp-entete').innerText(),/Tu galères/);
  assert.equal(await p.locator('#aide-hrp-question').getAttribute('maxlength'),'1000');
  assert.ok(await p.locator('.aide-hrp').evaluate(e=>e.scrollWidth<=e.clientWidth+2),width+'px');
  assert.equal(await p.locator('.aide-hrp-suggestions button').count(),2);
  await p.close();
 }
}));
test('Aide : une question produit une seule requête authentifiée et une réponse sans HTML actif',async()=>avecJeu(async(b,o)=>{
 const p=await page(b,o,375,667);
 await p.evaluate(()=>{
   document.querySelectorAll('.vue').forEach(v=>v.classList.remove('active'));
   document.getElementById('vue-rules').classList.add('active');
   window.renderAideHrp();
   window.rpAuthAssurerSession=async()=>null;
   window.rpAuthJeton=()=> 'jeton-de-test';
   window.appelsAide=[];
   window.fetch=async(url,options)=>{
     window.appelsAide.push({url,method:options.method,body:JSON.parse(options.body),token:options.headers.Authorization});
     return {ok:true,json:async()=>({reponse:'Voilà <script>dangereux</script> une réponse HRP.'})};
   };
 });
 await p.locator('#aide-hrp-question').fill('Pourquoi explorer la ville ?');
 await p.locator('#aide-hrp-envoyer').click();
 await p.locator('.aide-hrp-assistant').waitFor();
 const calls=await p.evaluate(()=>window.appelsAide);
 assert.equal(calls.length,1);
 assert.equal(calls[0].url,'/api/aide');
 assert.equal(calls[0].token,'Bearer jeton-de-test');
 assert.equal(calls[0].body.message,'Pourquoi explorer la ville ?');
 assert.equal(await p.locator('#aide-hrp-fil script').count(),0);
 assert.match(await p.locator('.aide-hrp-assistant').innerText(),/<script>dangereux<\/script>/);
 await p.close();
}));
