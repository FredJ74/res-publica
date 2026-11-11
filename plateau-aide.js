/* Première page de la rubrique Aide. Aucun texte du fournisseur traité comme HTML. */
(function(){
'use strict';
const l={
fr:{intro:'Tu galères ? Tu ne sais pas trop quoi faire ? Pose-moi les questions que tu veux, j’essaierai de te répondre au mieux.',caption:'Aide hors-jeu : tu peux parler des règles, des PA ou de tes envies dans Human Gambit.',placeholder:'Écris ta question…',send:'Envoyer',pending:'Je réfléchis à ta question…',error:'L’aide ne répond pas pour le moment. Tu peux consulter les autres rubriques.',pa:'Je ne comprends pas le système de PA',but:'Qu’est-ce que je dois faire dans le jeu ?',status:'Réponse de l’aide',empty:'Écris une question pour commencer.'},
en:{intro:'Struggling? Not sure what to do? Ask me anything and I’ll do my best to help.',caption:'Out-of-character help about game rules, action points, and your plans.',placeholder:'Type your question…',send:'Send',pending:'Thinking…',error:'Help is unavailable right now. The written guides are still here.',pa:'How do action points work?',but:'What should I do in the game?',status:'Help reply',empty:'Ask a question to begin.'},
es:{intro:'¿Te cuesta avanzar? ¿No sabes qué hacer? Pregúntame lo que quieras; intentaré ayudarte.',caption:'Ayuda fuera de personaje sobre las reglas, los puntos de acción y tus ideas.',placeholder:'Escribe tu pregunta…',send:'Enviar',pending:'Pensando…',error:'La ayuda no está disponible. Puedes consultar las guías.',pa:'¿Cómo funcionan los puntos de acción?',but:'¿Qué debo hacer en el juego?',status:'Respuesta de ayuda',empty:'Haz una pregunta para empezar.'},
de:{intro:'Kommst du nicht weiter? Weißt du nicht, was du tun sollst? Frag mich, ich helfe dir gern.',caption:'Hilfe außerhalb des Rollenspiels zu Regeln, Aktionspunkten und deinen Plänen.',placeholder:'Deine Frage…',send:'Senden',pending:'Ich überlege…',error:'Die Hilfe ist nicht verfügbar. Die schriftlichen Anleitungen bleiben zugänglich.',pa:'Wie funktionieren Aktionspunkte?',but:'Was soll ich im Spiel tun?',status:'Hilfeantwort',empty:'Stell deine erste Frage.'},
ru:{intro:'Не знаешь, что делать? Задавай любые вопросы — постараюсь помочь.',caption:'Внеигровая помощь с правилами, очками действий и выбором своего пути.',placeholder:'Задай вопрос…',send:'Отправить',pending:'Думаю…',error:'Помощь временно недоступна. Открой другие разделы справки.',pa:'Как работают очки действий?',but:'Чем мне заняться в игре?',status:'Ответ помощника',empty:'Задай вопрос, чтобы начать.'},
ko:{intro:'어떻게 해야 할지 모르겠나요? 무엇이든 물어보세요. 최대한 도와드릴게요.',caption:'게임 밖에서 규칙, 행동력과 플레이 목표를 알려드리는 도움말입니다.',placeholder:'질문을 입력하세요…',send:'보내기',pending:'답변을 생각하고 있어요…',error:'지금은 도움말을 사용할 수 없습니다. 다른 안내 항목을 확인하세요.',pa:'행동력(PA)이 무엇인가요?',but:'게임에서 무엇을 해야 하나요?',status:'도움말 답변',empty:'질문을 입력해 시작하세요.'},
ar:{intro:'هل تواجه صعوبة؟ لا تعرف ماذا تفعل؟ اسألني ما تشاء وسأحاول مساعدتك.',caption:'مساعدة خارج تقمص الأدوار حول القواعد ونقاط العمل وطريقك في اللعبة.',placeholder:'اكتب سؤالك…',send:'إرسال',pending:'أفكر في الإجابة…',error:'المساعدة غير متاحة الآن. يمكنك قراءة الأقسام المكتوبة.',pa:'كيف تعمل نقاط العمل؟',but:'ماذا أفعل في اللعبة؟',status:'رد المساعدة',empty:'اطرح سؤالاً للبدء.'},
pt:{intro:'Está com dificuldade? Não sabe o que fazer? Pode perguntar o que quiser. Vou tentar ajudar!',caption:'Ajuda fora do personagem: regras, pontos de ação e seus planos.',placeholder:'Digite sua pergunta…',send:'Enviar',pending:'Pensando…',error:'A ajuda está indisponível. Consulte as seções escritas.',pa:'Como funcionam os pontos de ação?',but:'O que devo fazer no jogo?',status:'Resposta da ajuda',empty:'Faça sua primeira pergunta.'},
zh:{intro:'遇到困難了嗎？不知道該做什麼？儘管問我，我會盡力幫你。',caption:'角色扮演之外的遊戲說明：規則、行動點數與個人目標。',placeholder:'輸入問題…',send:'傳送',pending:'正在思考…',error:'說明服務暫時無法使用，請查看其他教學頁面。',pa:'行動點數（PA）怎麼運作？',but:'我在遊戲裡應該做什麼？',status:'說明回覆',empty:'先問一個問題吧。'}
};
let messages=[];
let sending=false;
let requestSeq=0;
function lang(){return String(window.RPPlateauI18n?.language?.()||window.i18next?.language||'fr').toLowerCase().slice(0,2);}
function t(){return l[lang()]||l.fr;}
function addLine(parent,role,content){
 const div=document.createElement('div');
 div.className='hg-aide-line '+(role==='user'?'hg-aide-user':'hg-aide-guide');
 div.textContent=content;
 parent.appendChild(div);
}
function view(){
 const el=document.getElementById('rules-content');if(!el)return;
 const brouillon=document.getElementById('hg-aide-input')?.value||'';
 el.replaceChildren();
 if(lang()==='ar')el.setAttribute('dir','rtl');else el.removeAttribute('dir');
 const box=document.createElement('div');box.className='hg-aide';
 const intro=document.createElement('p');intro.className='hg-aide-intro';intro.textContent=t().intro;box.appendChild(intro);
 const caption=document.createElement('p');caption.className='hg-aide-caption';caption.textContent=t().caption;box.appendChild(caption);
 const log=document.createElement('div');log.className='hg-aide-log';log.id='hg-aide-log';log.setAttribute('role','log');log.setAttribute('aria-live','polite');
 for(const msg of messages)addLine(log,msg.role,msg.content);
 box.appendChild(log);
 const examples=document.createElement('div');examples.className='hg-aide-examples';
 for(const key of ['pa','but']){const b=document.createElement('button');b.type='button';b.className='hg-aide-example';b.textContent=t()[key];b.disabled=sending;b.addEventListener('click',()=>{const field=document.getElementById('hg-aide-input');if(field){field.value=t()[key];field.focus();}});examples.appendChild(b);}
 box.appendChild(examples);
 const form=document.createElement('form');form.className='hg-aide-form';form.id='hg-aide-form';
 const input=document.createElement('textarea');input.id='hg-aide-input';input.rows=3;input.maxLength=1000;input.value=brouillon;input.required=true;input.placeholder=t().placeholder;input.setAttribute('aria-label',t().placeholder);input.disabled=sending;
 const button=document.createElement('button');button.type='submit';button.className='hg-aide-send';button.textContent=t().send;button.disabled=sending;
 const status=document.createElement('div');status.id='hg-aide-status';status.className='hg-aide-status';status.setAttribute('role','status');
 form.append(input,button);form.addEventListener('submit',submit);box.append(form,status);el.appendChild(box);
 log.scrollTop=log.scrollHeight;
}
async function submit(event){
 event.preventDefault();
 if(sending)return;
 const input=document.getElementById('hg-aide-input');const message=input?.value.trim();
 if(!message||message.length>1000)return;
 const history=messages.slice(-6).map(m=>({role:m.role,content:m.content.slice(0,1500)}));
 messages.push({role:'user',content:message});
 input.value='';
 sending=true;const seq=++requestSeq;
 view();
 const status=document.getElementById('hg-aide-status');if(status)status.textContent=t().pending;
 try{
   if(typeof rpAuthAssurerSession==='function')await rpAuthAssurerSession().catch(()=>null);
   const token=typeof rpAuthJeton==='function'?rpAuthJeton():null;
   if(!token)throw Error('auth');
   const response=await fetch('/api/aide',{method:'POST',headers:{'Content-Type':'application/json','Authorization':'Bearer '+token},body:JSON.stringify({message,lang:lang(),historique:history})});
   if(!response.ok)throw Error('http '+response.status);
   const data=await response.json();
   if(typeof data.reponse!=='string'||!data.reponse.trim())throw Error('empty');
   messages.push({role:'assistant',content:data.reponse.slice(0,4500)});
 }catch(e){messages.push({role:'assistant',content:t().error});}
 finally{if(seq===requestSeq){sending=false;if(document.getElementById('rules-content')&&document.getElementById('vue-rules')?.classList.contains('active')){view();document.getElementById('hg-aide-input')?.focus();}}}
}
window.RPAideHRP=Object.freeze({render:view});
})();
