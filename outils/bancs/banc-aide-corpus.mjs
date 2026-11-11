// Corpus unique et vrais handler/wrapper, réseau auth/IA simulé explicitement.
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import chat from '../../api/chat.js';
import {AIDE_THEMES,AIDE_REFERENCES,contexteAideQuestion} from '../../api/_aide-themes.js';
const questions=JSON.parse(readFileSync(new URL('fixtures/aide-corpus-neuf-langues.json',import.meta.url)));
const themes=['sommeil','emploi','commerce','inventaire','organisations','forums'];
const lire=f=>readFileSync(new URL('../../'+f,import.meta.url),'utf8');
test('six compléments tracés et même corpus pour les neuf langues, sans nouveau barème',()=>{
 assert.equal(Object.keys(AIDE_THEMES).length,16);
 for(const t of themes){assert.ok(AIDE_REFERENCES[t].length);assert.ok(AIDE_THEMES[t]);assert.doesNotMatch(AIDE_THEMES[t],/\d|FR\b|PSK\b|€|%/);for(const r of AIDE_REFERENCES[t])assert.ok(lire(r.fichier).includes(r.ancre),t+' : '+r.fichier+' / '+r.ancre)}
 assert.match(AIDE_THEMES.emploi,/ne distribue pas les postes politiques/);
 assert.match(AIDE_THEMES.commerce,/simple client ne devient pas producteur/);
 assert.match(AIDE_THEMES.forums,/ville où se trouve actuellement/);
 assert.match(AIDE_THEMES.forums,/réservés aux membres ou chefs/);
 assert.match(AIDE_THEMES.inventaire,/ne peut ni déposer ni récupérer/);
});
for(const[lang,q]of Object.entries(questions)){
 test('pertinence des six domaines : '+lang,()=>{
  for(const theme of themes)assert.ok(contexteAideQuestion(q[theme]).includes(AIDE_THEMES[theme]),theme+' : '+q[theme]);
  const suivi=contexteAideQuestion(q.suivi,[{role:'user',content:q.commerce},{role:'assistant',content:'UNE RÉPONSE EN FRANÇAIS SUR LA POLITIQUE'}]);assert.ok(suivi.includes(AIDE_THEMES.commerce));assert.ok(!suivi.includes(AIDE_THEMES.politique));
 });
 test('question économique précise et suivi par routeur réel : '+lang,async()=>{
  const original=global.fetch,cle=process.env.DEEPSEEK_API_KEY;const calls=[];process.env.DEEPSEEK_API_KEY='fixture-locale-pas-un-secret';
  global.fetch=async(url,opts)=>{
   calls.push({url:String(url),opts});if(String(url).endsWith('/auth/v1/user'))return new Response(JSON.stringify({id:'fixture-isolee'}));
   assert.equal(String(url),'https://api.deepseek.com/chat/completions');return new Response(JSON.stringify({choices:[{message:{content:'Réponse de fixture, pas une sortie IA réelle.'},finish_reason:'stop'}]}));
  };
  try{
   for(const[message,historique]of [[q.commerce,[]],[q.suivi,[{role:'user',content:q.commerce},{role:'assistant',content:'Ancienne réponse en français.'}]]]){
    const r={headers:{},setHeader(k,v){this.headers[k]=v},status(c){this.code=c;return this},json(x){this.body=x;return this}};
    await chat({method:'POST',headers:{authorization:'Bearer fixture-isolee'},query:{mode:'aide'},body:{lang,message,historique}},r);
    assert.equal(r.code,200);const payload=JSON.parse(calls.at(-1).opts.body),prompt=payload.messages[0].content;
    assert.ok(prompt.includes('('+lang+')'));assert.ok(prompt.includes(AIDE_THEMES.commerce));assert.match(prompt,/question de règle/);assert.match(prompt,/aucun pouvoir d'agir/);assert.match(prompt,/aucune quête principale obligatoire/);assert.equal(payload.max_tokens,500);assert.deepEqual(payload.messages.slice(1),[...historique,{role:'user',content:message}]);
   }
   assert.equal(calls.length,4);assert.ok(calls[0].url.endsWith('/auth/v1/user'));assert.ok(calls[2].url.endsWith('/auth/v1/user'));
  }finally{global.fetch=original;if(cle===undefined)delete process.env.DEEPSEEK_API_KEY;else process.env.DEEPSEEK_API_KEY=cle}
 });
}
test('question spécifique actuelle ne se perd pas derrière les thèmes généraux historiques',()=>{
 const r=contexteAideQuestion(questions.ar.inventaire,[{role:'user',content:'politique justice sport'},{role:'assistant',content:'politique justice sport'}]);assert.ok(r.includes(AIDE_THEMES.inventaire));assert.equal(Object.values(AIDE_THEMES).filter(v=>r.includes(v)).length,4);
});
