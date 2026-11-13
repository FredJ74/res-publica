/* Répertoire partagé et confidentialité du courrier : i18next existant, aucune donnée PJ. */
(function(global){
 'use strict';
 const texts={
  fr:{title:'Répertoire des Joueurs',empty:"Aucun joueur enregistre pour l'instant.",count:'{{values.n}} joueur(s)',home:' · Domicile : {{values.city}}',privacy:"Les mails entre joueurs peuvent être interceptés en jeu par les services d'écoute de Sovarka."},
  en:{title:'Player Directory',empty:'No players registered yet.',count:'{{values.n}} player(s)',home:' · Home: {{values.city}}',privacy:'Mail between players can be intercepted in-game by Sovarka’s listening services.'},
  es:{title:'Directorio de jugadores',empty:'Todavía no hay jugadores registrados.',count:'{{values.n}} jugador(es)',home:' · Domicilio: {{values.city}}',privacy:'Los mensajes entre jugadores pueden ser interceptados en el juego por los servicios de escucha de Sovarka.'},
  'zh-TW':{title:'玩家通訊錄',empty:'目前尚無玩家登記。',count:'{{values.n}} 名玩家',home:' · 住所：{{values.city}}',privacy:'玩家之間的郵件可能在遊戲中被 Sovarka 的監聽部門截獲。'},
  ru:{title:'Справочник игроков',empty:'Пока нет зарегистрированных игроков.',count:'{{values.n}} игрок(ов)',home:' · Место жительства: {{values.city}}',privacy:'Письма между игроками могут быть перехвачены в игре службами прослушивания Sovarka.'},
  ko:{title:'플레이어 명부',empty:'아직 등록된 플레이어가 없습니다.',count:'플레이어 {{values.n}}명',home:' · 거주지: {{values.city}}',privacy:'플레이어 간 우편은 게임 내에서 Sovarka의 감청 기관에 의해 가로채질 수 있습니다.'},
  ar:{title:'دليل اللاعبين',empty:'لا يوجد لاعبون مسجّلون حتى الآن.',count:'اللاعبون: {{values.n}}',home:' · محل الإقامة: {{values.city}}',privacy:'قد تعترض أجهزة التنصّت في Sovarka الرسائل بين اللاعبين داخل اللعبة.'},
  'pt-BR':{title:'Diretório de jogadores',empty:'Ainda não há jogadores registrados.',count:'{{values.n}} jogador(es)',home:' · Domicílio: {{values.city}}',privacy:'As mensagens entre jogadores podem ser interceptadas no jogo pelos serviços de escuta de Sovarka.'},
  de:{title:'Spielerverzeichnis',empty:'Noch keine Spieler registriert.',count:'{{values.n}} Spieler',home:' · Wohnort: {{values.city}}',privacy:'Nachrichten zwischen Spielern können im Spiel von den Abhördiensten von Sovarka abgefangen werden.'}
 };
 const mailMessages={
  missing:["Votre personnage n'est pas chargé : rechargez la page avant d'envoyer un message.",'Your character is not loaded: reload the page before sending a message.','Tu personaje no está cargado: recarga la página antes de enviar un mensaje.','角色尚未載入：請先重新載入頁面，再傳送訊息。','Ваш персонаж не загружен: обновите страницу, прежде чем отправлять сообщение.','캐릭터가 불러와지지 않았습니다. 메시지를 보내기 전에 페이지를 새로고침하세요.','لم تُحمَّل شخصيتك: أعد تحميل الصفحة قبل إرسال رسالة.','Seu personagem não foi carregado: recarregue a página antes de enviar uma mensagem.','Dein Charakter ist nicht geladen: Lade die Seite neu, bevor du eine Nachricht sendest.'],
  required:['Remplissez tous les champs.','Fill in all fields.','Rellena todos los campos.','請填寫所有欄位。','Заполните все поля.','모든 항목을 입력하세요.','املأ جميع الحقول.','Preencha todos os campos.','Fülle alle Felder aus.'],
  sent:['À {{values.to}} — "{{values.subject}}"','To {{values.to}} — "{{values.subject}}"','Para {{values.to}} — "{{values.subject}}"','收件人 {{values.to}} — 「{{values.subject}}」','Кому: {{values.to}} — «{{values.subject}}»','받는 사람 {{values.to}} — "{{values.subject}}"','إلى {{values.to}} — «{{values.subject}}»','Para {{values.to}} — "{{values.subject}}"','An {{values.to}} — „{{values.subject}}“']
 };
 const locales=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
 for(const [key,row]of Object.entries(mailMessages))for(const [i,lang]of locales.entries())texts[lang][key]=row[i];
 for(const [lang,labels]of Object.entries(texts))if(global.RP_I18N_RESOURCES?.[lang]?.translation)global.RP_I18N_RESOURCES[lang].translation.playerDirectory={...labels};
 // Son prochain textContent enlève ce span : aucune ancienne alerte ne revient sur une autre.
 function toast(key,fr,values){
  const node=global.document?.getElementById('toast-sub');if(!node||node.textContent!==fr)return;
  const span=global.document.createElement('span');span.textContent=fr;span.setAttribute('data-i18n',key);
  if(values)span.setAttribute('data-i18n-values',JSON.stringify(values));node.replaceChildren(span);global.RPI18nPlateau?.apply(node);
 }
 function direction(){
  const lang=global.RP_I18N_GAME_ENABLED===true?global.RPPlateauI18n?.language?.()||'fr':'fr';
  for(const node of global.document?.querySelectorAll?.('[data-player-directory]')||[])node.dir=lang==='ar'?'rtl':'ltr';
 }
 (global.RP_I18N_CHANGE_CALLBACKS=global.RP_I18N_CHANGE_CALLBACKS||[]).push(direction);
 global.RPPlayerDirectoryI18n=Object.freeze({direction,toast});
})(window);
