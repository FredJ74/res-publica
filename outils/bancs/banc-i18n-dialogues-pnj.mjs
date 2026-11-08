import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { LANGUES, LANGUE_DEFAUT, construirePromptSysteme, filtrerReponseSquatteur,
  profilExiste, langueDialogueAutorisee } from '../../api/_pnj-profils.js';

// Contrat d'affichage uniquement : aucune requête IA, aucune lecture de profil PJ,
// aucun effet métier, aucun changement de personnalité ou d'identité.
const target={
 fr:'Reponds EXCLUSIVEMENT en francais.',
 en:'Reply EXCLUSIVELY in English.',
 es:'Responde EXCLUSIVAMENTE en español.',
 'zh-TW':'請只使用繁體中文（臺灣）回答，不要使用簡體中文。',
 ru:'Отвечай ИСКЛЮЧИТЕЛЬНО на русском языке.',
 ko:'반드시 한국어로만 답변하세요.',
 ar:'أجب باللغة العربية فقط دون استخدام لغة أخرى.',
 'pt-BR':'Responda EXCLUSIVAMENTE em português brasileiro.',
 de:'Antworte AUSSCHLIESSLICH auf Deutsch.'
};
test('PNJ : neuf locales exactes, aucune consigne anglaise parasite',()=>{
 assert.equal(Object.keys(target).length,9);
 assert.equal(Object.keys(LANGUES).length,9);
 assert.equal(LANGUE_DEFAUT,'en'); // Compatibilité des anciens appels sans locale
 for(const [locale,instruction] of Object.entries(target)){
  const prompt=construirePromptSysteme('la_bande_a_rotule',locale);
  assert.ok(prompt.includes(instruction),locale);
  const autre=construirePromptSysteme('la_bande_a_rotule','fr');
  assert.equal(prompt.replace(instruction,'LANGUE'),autre.replace(target.fr,'LANGUE'),
   locale+': seul le langage change, non le profil, le contexte ou les règles');
  if(locale!=='en')assert.ok(!prompt.includes(target.en),locale+': pas de fallback EN');
 }
});
test('répliques anti-HRP du squat : neuf langues, agressivité et personnalité conservées',()=>{
 const id='la_bande_a_rotule',neutre='les_gars_du_bas';
 assert.ok(profilExiste(id)&&profilExiste(neutre));
 for(const [locale] of Object.entries(target)){
  const agressif=filtrerReponseSquatteur(id,'Cliquez sur les boutons du jeu.',locale);
  const calme=filtrerReponseSquatteur(neutre,'Cliquez sur les boutons du jeu.',locale);
  assert.ok(agressif.trim()&&calme.trim(),locale);
  assert.notEqual(agressif,calme,locale);
  assert.doesNotMatch(agressif,/Cliquez|boutons du jeu|points d.action/i);
  assert.doesNotMatch(calme,/Cliquez|boutons du jeu|points d.action/i);
  assert.equal(filtrerReponseSquatteur(id,'Parle-moi de ton pays.',locale),
    'Parle-moi de ton pays.',locale+': réplique normale inchangée');
 }
});
test('les messages historiques français et anglais conservent leurs phrases',()=>{
 assert.equal(filtrerReponseSquatteur('la_bande_a_rotule','Bonjour !','fr'),
  "Tu cherches quoi, baltringue ? T'as intérêt à pas te foutre de nous.");
 assert.equal(filtrerReponseSquatteur('les_gars_du_bas','Cliquez sur les boutons.','en'),
  'What brings you to our patch of land?');
});

test('un accord ou départ inventé par un squatteur est neutralisé dans neuf langues',()=>{
 const reponses={
  fr:"J'accepte votre offre, nous partons.",
  en:'We accept your offer. We are leaving.',
  es:'Acepto tu oferta. Nos vamos del terreno.',
  'zh-TW':'我們接受你的提議，我們離開這片土地。',
  ru:'Мы согласны. Мы уходим с участка.',
  ko:'제안을 수락합니다. 우리는 떠나겠습니다.',
  ar:'نوافق على عرضك وسنغادر الأرض.',
  'pt-BR':'Aceitamos sua proposta. Vamos embora.',
  de:'Wir akzeptieren das Angebot. Wir verlassen das Gelände.'
 };
 for(const [locale,inventee] of Object.entries(reponses)){
  for(const profil of ['la_bande_a_rotule','les_gars_du_bas']){
   const sortie=filtrerReponseSquatteur(profil,inventee,locale);
   assert.notEqual(sortie,inventee,locale+': '+profil+' ne doit pas inventer de transaction');
   assert.ok(sortie?.trim(),locale+': repli vide');
  }
 }
});

test('drapeau serveur fermé : la requête PNJ ne peut pas activer de nouvelles langues',()=>{
 for(const locale of ['es','zh-TW','ru','ko','ar','pt-BR','de']){
  assert.equal(langueDialogueAutorisee(locale,false),'en',locale);
  assert.notEqual(langueDialogueAutorisee(locale,true),'en',locale);
 }
 assert.equal(langueDialogueAutorisee('fr',false),'fr');
 assert.equal(langueDialogueAutorisee('en',false),'en');
 assert.equal(langueDialogueAutorisee('inconnue',true),'en');
 assert.equal(langueDialogueAutorisee('ar',undefined),process.env.RP_I18N_GAME_ENABLED==='true'?'ar':'en');
});

test('le point HTTP chat réutilise la même langue autorisée pour le prompt et le filtre',()=>{
 const src=readFileSync(new URL('../../api/chat.js',import.meta.url),'utf8');
 assert.match(src,/const langueAutorisee = langueDialogueAutorisee\(req\.body\.lang\)/);
 assert.match(src,/req\.body\.profil, langueAutorisee, relation/);
 assert.match(src,/filtrerReponseSquatteur\(req\.body\.profil, r\.texte, langueAutorisee\)/);
});
