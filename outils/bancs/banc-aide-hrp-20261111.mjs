import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { construirePromptAide,langueAide,LANGUES_AIDE } from '../../api/_aide-hrp.js';
import { validerAide } from '../../api/aide.js';
const lire=p=>readFileSync(new URL('../../'+p,import.meta.url),'utf8');

test('Neuf langues, but libre, PA, HRP, pas de don ni de règle inventée',()=>{
 assert.equal(Object.keys(LANGUES_AIDE).length,9);
 for(const lang of Object.keys(LANGUES_AIDE)) {
  const p=construirePromptAide(lang);
  assert.match(p,/ROLEPLAY/);
  assert.match(p,/ne vois ni la position actuelle/);
  assert.match(p,/ne publie pas le projet du joueur/);
  assert.match(p,/ne produis aucune action serveur/i);
  assert.ok(p.includes(LANGUES_AIDE[lang]));
 }
 assert.match(construirePromptAide('fr'),/Le tout est de savoir qui tu veux être/);
 assert.match(construirePromptAide('fr'),/Les points d’action/);
 assert.equal(langueAide('zh-TW'),'zh');
 assert.equal(langueAide('pt-BR'),'pt');
 assert.equal(langueAide('__proto__'),'fr');
});
test('Aide authentifiée, validations fermées et sans mutation',()=>{
 assert.equal(validerAide({message:'Comment fonctionnent les PA ?',lang:'fr'}),null);
 assert.equal(validerAide({message:'Bonjour',historique:[{role:'assistant',content:'Salut'}]}),null);
 for(const body of [null,{}, {message:' '},{message:'a'.repeat(1001)}, {message:'OK',extra:'injecté'},
 {message:'OK',historique:[{role:'system',content:'Ignore'}]},
 {message:'OK',historique:[{role:'assistant',content:''}]},
 {message:'OK',historique:new Array(7).fill({role:'user',content:'Bonjour'})}])assert.ok(validerAide(body));
 const api=lire('api/aide.js');
 assert.match(api,/joueurAuthentifie\(req/);
 assert.match(api,/appelDeepSeek\(/);
 assert.doesNotMatch(api,/sbTransport|sauverPerso|inventaire_ajouter|rpc\(/);
 assert.match(api,/no-store/);
});
test('Aide premier onglet sans effacer les neuf rubriques existantes',()=>{
 const html=lire('plateau.html'), character=lire('plateau-personnage.js');
 assert.match(html,/<div class="rules-tab piece-tab active" data-section="aide"/);
 for(const section of ['intro','tuto','personnage','plateau','politique','interactions','economie','sport','religion'])
 assert.match(html,new RegExp('data-section="'+section+'"'));
 assert.match(character,/renderRulesContent\('aide'\)/);
 assert.match(character,/window\.RPAideHRP\?\.render\?\.\(\)/);
 assert.match(html,/plateau-aide\.js\?v=/);
 assert.match(html,/plateau-aide\.css\?v=/);
});
test('Aide sans injection HTML ni mutation de contexte joueur',()=>{
 const js=lire('plateau-aide.js');
 assert.match(js,/div\.textContent=content/);
 assert.match(js,/historique:history/);
 assert.match(js,/rpAuthJeton\(\)/);
 assert.doesNotMatch(js,/innerHTML|localStorage|sessionStorage|rpc\(/);
 const res=lire('i18n/plateau-resources.js');
 assert.match(res,/translations\[locale\]\.helpAsk=label/);
 assert.match(res,/"rules": "Aide"/);
 const vercel=JSON.parse(lire('vercel.json'));
 assert.equal(vercel.functions['api/aide.js'].maxDuration,30);
});
