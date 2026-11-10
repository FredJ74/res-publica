// Diagnostic non déployé : comparaison visuelle du témoin bureau avec la refonte Aide.
const fs=require('node:fs'), path=require('node:path');
const {avecJeu,page,lecture}=require('../bancs/mobile-navigateur.cjs');
const dir='/tmp/hg-aide-visuel';
fs.mkdirSync(dir,{recursive:true});
(async()=>{
 await avecJeu(async(b,o)=>{
  const a=await page(b,o,1440,900,true),n=await page(b,o,1440,900);
  await a.locator('link[rel=stylesheet]').evaluateAll(es=>es.forEach(e=>e.remove()));
  await a.addStyleTag({content:lecture('style.css',true).toString()});
  await a.addStyleTag({content:lecture('rue-centrale.css',true).toString()});
  await a.waitForTimeout(400);
  // Neutraliser uniquement le libellé de navigation renommé, pas sa géométrie
  // ni les CSS de l'application : le reste doit rester pixel-perfect.
  async function normaliserTitre(p) {
    await p.evaluate(()=>{
      const bouton=document.querySelector('button[onclick="openRulesView()"]');
      if(!bouton)throw new Error('Bouton Aide/Règles introuvable');
      const label=bouton.querySelector('span');
      if(!label)throw new Error('Libellé introuvable');
      label.textContent='AIDE';
    });
  }
  await normaliserTitre(a);await normaliserTitre(n);
  await fs.promises.writeFile(path.join(dir,'avant.png'),await a.screenshot());
  await fs.promises.writeFile(path.join(dir,'apres.png'),await n.screenshot());
  function forumFixture(p){return p.evaluate(()=>{
    document.getElementById('forum-body').innerHTML='<div class="forum-layout"><div class="forum-sidebar">'+Array.from({length:15},(_,i)=>'<button>Rubrique '+i+'</button>').join('')+'</div><div class="forum-main" id="forum-main"><div class="forum-topics-header"><span>Sujet</span><span>Auteur</span><span>Dernier</span><span>Vues</span><span>Réponses</span></div><div class="forum-topic-row"><span>Sujet local</span><span>Auteur</span><span>Hier</span><span>10</span><span>2</span></div><div class="forum-post"><div class="forum-post-side">Auteur</div><div class="forum-post-main">Réponse</div></div></div></div>';
    document.getElementById('modal-forum').classList.add('open');
  })}
  await forumFixture(a);await forumFixture(n);
  await a.waitForTimeout(500);await n.waitForTimeout(500);
  await fs.promises.writeFile(path.join(dir,'forum-avant.png'),await a.screenshot());
  await fs.promises.writeFile(path.join(dir,'forum-apres.png'),await n.screenshot());
  console.log('Snapshots écrits dans '+dir);
 });
})().catch(e=>{console.error(e);process.exitCode=1});
