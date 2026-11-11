/* Conseiller HRP de Human Gambit : panneau de l'onglet Aide.
 * Aucun effet sur les mécaniques, pas de stockage persistant des questions.
 */
(function(global){
'use strict';
const traductions = {
 fr:{titre:'Besoin d’un coup de main ?',intro:'Tu galères ? Tu ne sais pas trop quoi faire ? Pose-moi les questions que tu veux, j’essaierai de te répondre au mieux.',goal:'Qu’est-ce que je dois faire dans le jeu ?',pa:'Je ne comprends pas le système de PA',input:'Écris ta question ici…',send:'Envoyer',thinking:'Je cherche la meilleure réponse…',retry:'La réponse n’a pas pu être chargée. Réessaie ou consulte les rubriques ci-dessus.',offline:'Connecte-toi pour poser une question.',hint:'Conseiller hors rôleplay (HRP) · aucune action sur ton personnage',heading:'Poser une question'},
 en:{titre:'Need a hand?',intro:"Struggling? Not sure what to do? Ask me anything about the game, and I’ll do my best to help.",goal:'What should I do in the game?',pa:"I don’t understand action points (AP)",input:'Type your question…',send:'Send',thinking:'Finding an answer…',retry:'Could not load the reply. Try again or use the guide tabs.',offline:'Sign in to ask a question.',hint:'Out-of-character guide · does not change your character',heading:'Ask a question'},
 es:{titre:'¿Necesitas ayuda?',intro:'¿Te cuesta orientarte? ¿No sabes qué hacer? Pregúntame lo que quieras e intentaré ayudarte.',goal:'¿Qué debo hacer en el juego?',pa:'No entiendo los puntos de acción',input:'Escribe tu pregunta…',send:'Enviar',thinking:'Buscando una respuesta…',retry:'No se pudo cargar la respuesta. Inténtalo de nuevo.',offline:'Inicia sesión para preguntar.',hint:'Guía fuera de personaje · no modifica tu personaje',heading:'Haz una pregunta'},
 'zh-TW':{titre:'需要幫忙嗎？',intro:'不知道該做什麼嗎？儘管提問，我會盡力協助。',goal:'我在遊戲中應該做什麼？',pa:'我不懂行動點數',input:'輸入你的問題…',send:'送出',thinking:'正在尋找答案…',retry:'無法取得回覆，請再試一次。',offline:'請登入後提問。',hint:'角色扮演外的遊戲指南 · 不會改變角色狀態',heading:'提出問題'},
 ru:{titre:'Нужна помощь?',intro:'Не знаешь, что делать? Задавай любые вопросы об игре, постараюсь помочь.',goal:'Что мне делать в игре?',pa:'Я не понимаю очки действий',input:'Напиши свой вопрос…',send:'Отправить',thinking:'Ищу ответ…',retry:'Не удалось получить ответ. Попробуй ещё раз.',offline:'Войди в аккаунт, чтобы спросить.',hint:'Помощь вне роли · не меняет персонажа',heading:'Задать вопрос'},
 ko:{titre:'도움이 필요해?',intro:'무엇을 해야 할지 모르겠어? 궁금한 건 뭐든 물어봐. 최대한 도와줄게.',goal:'게임에서 무엇을 해야 하나요?',pa:'행동력(PA)을 모르겠어요',input:'질문을 입력하세요…',send:'보내기',thinking:'답변을 찾고 있어요…',retry:'답변을 불러오지 못했습니다. 다시 시도하세요.',offline:'로그인한 뒤 질문해 주세요.',hint:'역할극 외 게임 도움말 · 캐릭터 상태는 변경되지 않음',heading:'질문하기'},
 ar:{titre:'هل تحتاج إلى مساعدة؟',intro:'هل تشعر بالحيرة ولا تعرف ماذا تفعل؟ اسألني ما تشاء وسأحاول مساعدتك.',goal:'ماذا عليّ أن أفعل في اللعبة؟',pa:'لا أفهم نقاط العمل',input:'اكتب سؤالك هنا…',send:'إرسال',thinking:'أبحث عن إجابة…',retry:'تعذر تحميل الإجابة. حاول مجددًا.',offline:'سجّل الدخول لطرح سؤال.',hint:'دليل خارج تقمص الأدوار · لا يغيّر شخصيتك',heading:'اطرح سؤالاً'},
 'pt-BR':{titre:'Precisa de ajuda?',intro:'Está perdido? Não sabe o que fazer? Pergunte o que quiser, vou tentar ajudar.',goal:'O que devo fazer no jogo?',pa:'Não entendo os pontos de ação',input:'Digite sua pergunta…',send:'Enviar',thinking:'Buscando uma resposta…',retry:'Não foi possível carregar a resposta. Tente novamente.',offline:'Entre na sua conta para perguntar.',hint:'Ajuda fora do personagem · sem alterar seu personagem',heading:'Faça uma pergunta'},
 de:{titre:'Brauchst du Hilfe?',intro:'Kommst du nicht weiter? Weißt du nicht, was du tun sollst? Frag mich, ich helfe dir gern.',goal:'Was soll ich im Spiel tun?',pa:'Ich verstehe die Aktionspunkte nicht',input:'Schreib deine Frage…',send:'Senden',thinking:'Ich suche eine Antwort…',retry:'Antwort nicht verfügbar. Versuch es erneut.',offline:'Melde dich an, um eine Frage zu stellen.',hint:'Hilfe außerhalb des Rollenspiels · keine Änderung deiner Figur',heading:'Stell eine Frage'}
};
const escape=s=>String(s).replace(/[&<>"']/g,k=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[k]));
let historique=[],attente=false,ouvert=false;
function langue(){const code=global.RPPlateauI18n?.language?.()||global.i18next?.language||'fr';return traductions[code]?code:'fr'}
function texte(){return traductions[langue()]}
function ajouter(role,content){
 const zone=document.getElementById('aide-hrp-fil');if(!zone)return;
 const el=document.createElement('p');el.className='aide-hrp-bulle aide-hrp-'+role;el.textContent=content;
 zone.appendChild(el);zone.scrollTop=zone.scrollHeight;
}
function initialiser(){
 const zone=document.getElementById('rules-content');if(!zone)return;
 ouvert=true;const t=texte();
 zone.setAttribute('dir',langue()==='ar'?'rtl':'ltr');
 zone.innerHTML='<section class="aide-hrp"><div class="aide-hrp-entete"><h2>'+escape(t.titre)+'</h2><p>'+escape(t.intro)+'</p><small>'+escape(t.hint)+'</small></div><div id="aide-hrp-fil" role="log" aria-live="polite" aria-label="'+escape(t.heading)+'"></div><div class="aide-hrp-suggestions"><button type="button" data-question="goal">'+escape(t.goal)+'</button><button type="button" data-question="pa">'+escape(t.pa)+'</button></div><form id="aide-hrp-form"><label class="aide-hrp-label" for="aide-hrp-question">'+escape(t.heading)+'</label><textarea id="aide-hrp-question" maxlength="1000" rows="2" placeholder="'+escape(t.input)+'" required></textarea><button id="aide-hrp-envoyer" type="submit">'+escape(t.send)+'</button></form><p id="aide-hrp-statut" role="status"></p></section>';
 const fil=zone.querySelector('#aide-hrp-fil');for(const m of historique){const el=document.createElement('p');el.className='aide-hrp-bulle aide-hrp-'+m.role;el.textContent=m.content;fil.appendChild(el)}
 zone.querySelectorAll('[data-question]').forEach(b=>b.addEventListener('click',()=>envoyer(t[b.dataset.question])));
 zone.querySelector('#aide-hrp-form').addEventListener('submit',e=>{e.preventDefault();const value=zone.querySelector('#aide-hrp-question').value;envoyer(value)});
 const field=zone.querySelector('#aide-hrp-question');field.addEventListener('keydown',e=>{if(e.key==='Enter'&&!e.shiftKey){e.preventDefault();envoyer(field.value)}});
}
async function envoyer(message){
 const question=String(message||'').trim().slice(0,1000);
 if(!question||attente)return;
 const zone=document.getElementById('aide-hrp-question'),button=document.getElementById('aide-hrp-envoyer'),status=document.getElementById('aide-hrp-statut');
 if(!zone||!button||!status)return;
 const t=texte();
 let jeton=null;
 if(typeof global.rpAuthAssurerSession==='function')await global.rpAuthAssurerSession().catch(()=>null);
 jeton=typeof global.rpAuthJeton==='function'?global.rpAuthJeton():null;
 if(!jeton){status.textContent=t.offline;return}
 const precedent=historique.slice(-6);
 historique.push({role:'user',content:question});ajouter('user',question);
 zone.value='';attente=true;button.disabled=true;status.textContent=t.thinking;
 try {
   const rep=await fetch('/api/aide',{method:'POST',headers:{'Content-Type':'application/json','Authorization':'Bearer '+jeton},body:JSON.stringify({message:question,historique:precedent,lang:langue()})});
   if(!rep.ok)throw Error('HTTP '+rep.status);
   const result=await rep.json();
   if(typeof result.reponse!=='string'||!result.reponse.trim())throw Error('empty');
   historique.push({role:'assistant',content:result.reponse.slice(0,4000)});
   if(document.getElementById('aide-hrp-fil'))ajouter('assistant',result.reponse.slice(0,4000));
   const statutActuel=document.getElementById('aide-hrp-statut');
   if(statutActuel)statutActuel.textContent='';
 }catch(e){
   historique.pop();
   const statutActuel=document.getElementById('aide-hrp-statut');
   const saisieActuelle=document.getElementById('aide-hrp-question');
   if(statutActuel)statutActuel.textContent=texte().retry;
   if(saisieActuelle)saisieActuelle.value=question;
 }
 finally{
   attente=false;
   const boutonActuel=document.getElementById('aide-hrp-envoyer');
   if(boutonActuel)boutonActuel.disabled=false;
 }
}
// Changement de langue à chaud : préserver les échanges et un brouillon en cours.
if(global.i18next?.on)global.i18next.on('languageChanged',()=>{
  const panel=document.getElementById('aide-hrp-form');
  if(!panel)return;
  const draft=document.getElementById('aide-hrp-question')?.value||'';
  initialiser();
  const nouveau=document.getElementById('aide-hrp-question');
  if(nouveau)nouveau.value=draft;
  const send=document.getElementById('aide-hrp-envoyer');
  if(send)send.disabled=attente;
});
global.renderAideHrp=initialiser;
})(window);
