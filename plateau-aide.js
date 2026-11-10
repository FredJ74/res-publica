// Première page de l'onglet Aide : conversation hors roleplay.
// Les guides d'origine restent accessibles depuis leurs onglets.
// Aucun HTML IA : affichage textContent seulement, aucune donnée joueur modifiée.
(function (global) {
  'use strict';
  const textes = {
    fr:{nav:'Aide',subtitle:'Human Gambit — Aide du joueur',tab:'Poser une question',heading:'Besoin d’un coup de main ?',intro:'Tu galères ? Tu ne sais pas trop quoi faire ? Poses moi les questions que tu veux, j’essayerai de te répondre au mieux.',placeholder:'Écris ta question ici…',send:'Envoyer',pa:'Je ne comprends pas les PA',but:'Qu’est-ce que je dois faire dans le jeu ?',thinking:'Je réfléchis à ta question…',offline:'Je ne peux pas répondre pour le moment. Tu peux toujours consulter les guides dans les onglets.',login:'Connecte-toi pour discuter avec l’aide du jeu.',label:'Votre question',disclaimer:'Conseils hors-jeu : aucune action n’est exécutée sur ton personnage.'},
    en:{nav:'Help',subtitle:'Human Gambit — Player help',tab:'Ask a question',heading:'Need a hand?',intro:'Feeling lost? Not sure what to do? Ask me anything and I’ll do my best to help.',placeholder:'Type your question…',send:'Send',pa:'I don’t understand action points',but:'What should I do in the game?',thinking:'Thinking…',offline:'Help is unavailable right now. The written guides are still here.',login:'Sign in to ask a question.',label:'Your question',disclaimer:'Out-of-character advice: this cannot perform in-game actions.'},
    es:{nav:'Ayuda',subtitle:'Human Gambit — Ayuda',tab:'Preguntar',heading:'¿Necesitas ayuda?',intro:'¿Estás perdido? ¿No sabes qué hacer? Pregúntame lo que quieras; intentaré ayudarte.',placeholder:'Escribe tu pregunta…',send:'Enviar',pa:'No entiendo los puntos de acción',but:'¿Qué debería hacer en el juego?',thinking:'Estoy pensando…',offline:'La ayuda no está disponible. Puedes consultar las guías.',login:'Inicia sesión para preguntar.',label:'Tu pregunta',disclaimer:'Ayuda fuera de personaje: no realiza acciones del juego.'},
    zh:{nav:'幫助',subtitle:'Human Gambit — 玩家幫助',tab:'提問',heading:'需要幫忙嗎？',intro:'不知道該做什麼嗎？你可以問我任何問題，我會盡力幫忙。',placeholder:'輸入問題…',send:'送出',pa:'我不懂行動點數',but:'在遊戲中我該做什麼？',thinking:'正在思考…',offline:'幫助暫時無法使用，仍可閱讀指南。',login:'請先登入再提問。',label:'你的問題',disclaimer:'這是遊戲外的協助，不會執行遊戲操作。'},
    ru:{nav:'Помощь',subtitle:'Human Gambit — Помощь игроку',tab:'Задать вопрос',heading:'Нужна помощь?',intro:'Не знаешь, что делать? Спрашивай о чём угодно, постараюсь помочь.',placeholder:'Твой вопрос…',send:'Отправить',pa:'Я не понимаю очки действий',but:'Что мне делать в игре?',thinking:'Думаю…',offline:'Помощь временно недоступна. Можно прочитать руководства.',login:'Войди в игру, чтобы задать вопрос.',label:'Твой вопрос',disclaimer:'Советы вне роли: они не выполняют действия в игре.'},
    ko:{nav:'도움말',subtitle:'Human Gambit — 플레이어 도움말',tab:'질문하기',heading:'도움이 필요하신가요?',intro:'무엇을 해야 할지 모르겠나요? 무엇이든 물어보세요. 최선을 다해 답할게요.',placeholder:'질문 입력…',send:'보내기',pa:'행동 포인트를 모르겠어요',but:'게임에서 무엇을 해야 하나요?',thinking:'생각 중…',offline:'현재 도움을 받을 수 없습니다. 안내문은 계속 이용할 수 있습니다.',login:'질문하려면 로그인하세요.',label:'질문',disclaimer:'게임 외 도움말이며 캐릭터에게 어떤 행동도 실행하지 않습니다.'},
    ar:{nav:'المساعدة',subtitle:'Human Gambit — مساعدة اللاعب',tab:'اطرح سؤالاً',heading:'هل تحتاج إلى مساعدة؟',intro:'لا تعرف ماذا تفعل؟ اسألني ما تشاء وسأحاول مساعدتك.',placeholder:'اكتب سؤالك…',send:'إرسال',pa:'لا أفهم نقاط الحركة',but:'ماذا علي أن أفعل في اللعبة؟',thinking:'أفكر في سؤالك…',offline:'المساعدة غير متاحة الآن. يمكنك قراءة الأدلة.',login:'سجل الدخول لطرح سؤال.',label:'سؤالك',disclaimer:'هذه نصائح خارج اللعبة ولا تنفذ أي إجراء على شخصيتك.'},
    pt:{nav:'Ajuda',subtitle:'Human Gambit — Ajuda ao jogador',tab:'Perguntar',heading:'Precisa de ajuda?',intro:'Está perdido? Não sabe o que fazer? Pergunte o que quiser e vou tentar ajudar.',placeholder:'Escreva sua pergunta…',send:'Enviar',pa:'Não entendo os pontos de ação',but:'O que devo fazer no jogo?',thinking:'Estou pensando…',offline:'Ajuda indisponível no momento. Você ainda pode ler os guias.',login:'Entre para fazer uma pergunta.',label:'Sua pergunta',disclaimer:'Conselhos fora do jogo: nenhuma ação é executada.'},
    de:{nav:'Hilfe',subtitle:'Human Gambit — Spielerhilfe',tab:'Frage stellen',heading:'Brauchst du Hilfe?',intro:'Du weißt nicht, was du tun sollst? Frag mich alles und ich versuche zu helfen.',placeholder:'Deine Frage…',send:'Senden',pa:'Ich verstehe die Aktionspunkte nicht',but:'Was soll ich im Spiel tun?',thinking:'Ich überlege…',offline:'Hilfe ist gerade nicht verfügbar. Die Anleitungen bleiben zugänglich.',login:'Melde dich an, um eine Frage zu stellen.',label:'Deine Frage',disclaimer:'Hilfe außerhalb des Rollenspiels: Es werden keine Spielaktionen ausgeführt.'}
  };
  let messages = [], draft = '', busy = false, error = '';
  let currentRequest = 0;
  function language() {
    const raw=String(global.RPPlateauI18n?.language?.() || global.i18next?.language || 'fr').toLowerCase();
    const lng=raw.slice(0,2); return Object.hasOwn(textes,lng)?lng:'fr';
  }
  const t=()=>textes[language()];
  function element(tag,className,text) {
    const node=document.createElement(tag);
    if(className) node.className=className;
    if(text!==undefined) node.textContent=text;
    return node;
  }
  function updateLabels(){
    const words=t();
    document.querySelectorAll('[data-aide-ui]').forEach(node=>{
      const key=node.getAttribute('data-aide-ui');
      if(words[key])node.textContent=words[key];
    });
  }
  function active(){
    const tab=document.querySelector('.rules-tab[data-section="aide"]');
    return !!tab?.classList.contains('active');
  }
  function afficher(){
    updateLabels();
    const target=document.getElementById('rules-content');
    if(!target)return;
    document.querySelectorAll('.rules-tab').forEach(tab=>tab.classList.toggle('active',tab.dataset.section==='aide'));
    target.setAttribute('dir',language()==='ar'?'rtl':'ltr');
    target.textContent='';
    const words=t();
    const layout=element('section','aide-jeu');
    layout.append(element('h2','aide-jeu-titre',words.heading),element('p','aide-jeu-intro',words.intro));
    const feed=element('div','aide-jeu-messages');feed.setAttribute('role','log');feed.setAttribute('aria-live','polite');
    messages.forEach(m=>{
      const item=element('p','aide-jeu-message aide-jeu-'+m.role,m.content);
      feed.append(item);
    });
    if(busy)feed.append(element('p','aide-jeu-attente',words.thinking));
    layout.append(feed);
    if(!messages.length&&!busy){
      const suggestions=element('div','aide-jeu-suggestions');
      for(const key of ['pa','but']){
        const b=element('button','aide-jeu-proposition',words[key]);b.type='button';
        b.addEventListener('click',()=>envoyer(words[key]));
        suggestions.append(b);
      }
      layout.append(suggestions);
    }
    const form=element('form','aide-jeu-form');
    const label=element('label','aide-jeu-label',words.label);label.htmlFor='aide-jeu-question';
    const field=element('textarea','aide-jeu-question');field.id='aide-jeu-question';
    field.rows=2;field.maxLength=1000;field.placeholder=words.placeholder;field.value=draft;field.disabled=busy;
    field.addEventListener('input',()=>{draft=field.value});
    field.addEventListener('keydown',event=>{if(event.key==='Enter'&&!event.shiftKey){event.preventDefault();form.requestSubmit()}});
    const button=element('button','aide-jeu-envoi',words.send);button.type='submit';button.disabled=busy;
    form.append(label,field,button);
    form.addEventListener('submit',ev=>{ev.preventDefault();envoyer(field.value)});
    layout.append(form);
    if(error){const e=element('p','aide-jeu-erreur',error);e.setAttribute('role','alert');layout.append(e)}
    layout.append(element('p','aide-jeu-disclaimer',words.disclaimer));
    target.append(layout);
    feed.scrollTop=feed.scrollHeight;
  }
  async function envoyer(texte){
    const question=String(texte||'').trim().slice(0,1000);
    if(!question||busy)return;
    const historique=messages.slice(-6).map(m=>({role:m.role,content:m.content.slice(0,1400)}));
    messages.push({role:'user',content:question});
    draft='';busy=true;error='';
    const numero=++currentRequest;
    if(active())afficher();
    try{
      if(typeof global.rpAuthAssurerSession==='function') await global.rpAuthAssurerSession();
      const jeton=typeof global.rpAuthJeton==='function'?global.rpAuthJeton():null;
      if(!jeton)throw new Error(t().login);
      const response=await fetch('/api/aide',{
        method:'POST',
        headers:{'Content-Type':'application/json','Authorization':'Bearer '+jeton},
        body:JSON.stringify({message:question,historique,lang:language()})
      });
      const data=await response.json().catch(()=>({}));
      if(!response.ok||typeof data.reponse!=='string')throw new Error(response.status===401?t().login:t().offline);
      if(numero===currentRequest)messages.push({role:'assistant',content:data.reponse.slice(0,1800)});
    }catch(e){if(numero===currentRequest)error=e?.message===t().login?t().login:t().offline}
    finally{if(numero===currentRequest){busy=false;if(active())afficher()}}
  }
  // Aucun stockage du dialogue dans localStorage, la fiche du joueur ou Supabase.
  global.RPAideJeu=Object.freeze({render:afficher,updateLabels});
  // Traduire le bouton de navigation dès le chargement, avant même l'ouverture.
  updateLabels();
  if(global.i18next?.on)global.i18next.on('languageChanged',()=>{updateLabels();if(active())afficher()});
})(window);
