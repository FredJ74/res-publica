/* Information transparente sur la beta partiellement traduite.
 * Ne change aucune préférence, droit, action ni réponse serveur.
 * Chargé après resources.js et avant l'initialisation i18next sur les deux pages.
 */
(function(global){
  'use strict';
  const resources=global.RP_I18N_RESOURCES;
  if(!resources)return;
  const notices={
  "fr": "Traduction en cours : certaines parties du jeu restent en français. Elles demeurent entièrement jouables pendant cette bêta.",
  "en": "Translation in progress: some parts of the game are still in French. You can still play them during this beta.",
  "es": "Traducción en curso: algunas partes del juego siguen en francés. Puedes seguir jugando en ellas durante esta beta.",
  "zh-TW": "翻譯仍在進行中：遊戲部分內容仍以法文顯示。在本次測試期間，這些內容仍可正常遊玩。",
  "ru": "Перевод ещё продолжается: некоторые части игры пока остаются на французском языке. Они доступны для игры во время бета-тестирования.",
  "ko": "번역이 진행 중입니다. 게임의 일부 콘텐츠는 아직 프랑스어로 표시되지만, 베타 기간에도 정상적으로 플레이할 수 있습니다.",
  "ar": "الترجمة ما زالت قيد العمل: بعض أجزاء اللعبة لا تزال بالفرنسية، لكنها قابلة للعب خلال هذه النسخة التجريبية.",
  "pt-BR": "A tradução ainda está em andamento: algumas partes do jogo continuam em francês, mas você pode jogá-las normalmente durante esta versão beta.",
  "de": "Die Übersetzung läuft noch: Einige Teile des Spiels sind weiterhin auf Französisch. Sie bleiben während dieser Beta vollständig spielbar."
};
  for(const [locale,notice] of Object.entries(notices)){
    const entry=resources[locale]?.translation;
    if(entry)entry.betaLanguage={notice};
  }
})(window);
