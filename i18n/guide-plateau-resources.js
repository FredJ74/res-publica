/* Extension du guide : plateau de jeu en huit langues, FR demeure dans REGLES.
 * Présentation seule, aucun contrat métier. Non activé publiquement.
 */
(function(global){
 'use strict';
 const resources=global.RP_I18N_RESOURCES;
 if(!resources)return;
 const entries={
  "en": {
    "titre": "The game board",
    "contenu": "ACTION POINTS (AP) — You have 24 AP per day. Each order consumes AP according to its complexity. Some orders cost no AP. In test mode, AP are unlimited.\n\nRESOURCES:\n• Influence (INF) — Your political weight\n• Popularity (POP) — Your standing with the public\n• Discretion (DIS) — Your ability to avoid detection\n• Health — Your physical condition (0 = hospitalisation)\n• Morale — Your psychological resilience\n\nORDERS — Each action is resolved by a dice roll (1–100). Your attributes influence the chance of success. Outcomes include critical success, success, partial success, failure and critical failure.\n\nWAGES — You only receive your daily wage after using the “Sleep” order (once per day)."
  },
  "es": {
    "titre": "El tablero de juego",
    "contenu": "PUNTOS DE ACCIÓN (PA) — Dispones de 24 PA al día. Cada orden consume PA según su complejidad. Algunas órdenes no consumen PA. En el modo de prueba, los PA son ilimitados.\n\nRECURSOS:\n• Influencia (INF) — Tu peso político\n• Popularidad (POP) — Tu apoyo entre el público\n• Discreción (DIS) — Tu capacidad para evitar que te detecten\n• Salud — Tu estado físico (0 = hospitalización)\n• Moral — Tu resistencia psicológica\n\nÓRDENES — Cada acción se resuelve con una tirada de dados (1–100). La probabilidad de éxito depende de tus atributos. Los resultados posibles incluyen éxito crítico, éxito, éxito parcial, fallo y fallo crítico.\n\nSALARIO — Solo recibes tu salario diario al ejecutar la orden «Dormir» (una vez al día)."
  },
  "zh-TW": {
    "titre": "遊戲地圖",
    "contenu": "行動點數（PA）— 每天有 24 點 PA。每項指令依複雜度消耗不同點數，有些指令免費。在測試模式中，PA 不受限制。\n\n角色資源：\n• 影響力（INF）— 你的政治影響程度\n• 聲望（POP）— 民眾對你的支持度\n• 隱密（DIS）— 避免被發現的能力\n• 健康 — 身體狀態（0 = 住院）\n• 士氣 — 心理承受能力\n\n指令 — 每項行動以擲骰（1–100）決定結果，成功率取決於角色屬性。可能結果包括大成功、成功、部分成功、失敗和大失敗。\n\n薪資 — 每日只能在執行「睡覺」指令後領取當日薪資（每天一次）。"
  },
  "ru": {
    "titre": "Игровое поле",
    "contenu": "ОЧКИ ДЕЙСТВИЙ (PA) — Каждый день у вас 24 PA. Приказы тратят разное количество очков в зависимости от сложности. Некоторые не требуют PA. В тестовом режиме число PA не ограничено.\n\nПОКАЗАТЕЛИ:\n• Влияние (INF) — Ваш политический вес\n• Популярность (POP) — Поддержка среди населения\n• Скрытность (DIS) — Способность избегать обнаружения\n• Здоровье — Физическое состояние (0 = госпитализация)\n• Мораль — Психологическая устойчивость\n\nПРИКАЗЫ — Каждое действие разрешается броском кубика (1–100). Шанс успеха зависит от характеристик. Возможны критический успех, успех, частичный успех, неудача и критическая неудача.\n\nЗАРПЛАТА — Ежедневная зарплата выплачивается только после приказа «Спать» (один раз в день)."
  },
  "ko": {
    "titre": "게임판",
    "contenu": "행동력(PA) — 하루에 24 PA가 주어집니다. 명령마다 난이도에 따라 PA를 소비하며, PA를 쓰지 않는 명령도 있습니다. 테스트 모드에서는 PA가 무제한입니다.\n\n자원 및 상태:\n• 영향력(INF) — 정치적 영향력\n• 인기(POP) — 대중의 지지도\n• 은밀성(DIS) — 발각되지 않는 능력\n• 건강 — 신체 상태(0 = 입원)\n• 사기 — 정신적 회복력\n\n명령 — 각 행동은 주사위 판정(1–100)으로 결정됩니다. 성공 확률은 캐릭터 능력치에 따라 달라집니다. 결과는 대성공, 성공, 부분 성공, 실패, 대실패로 나뉩니다.\n\n급여 — 하루에 한 번 「잠자기」 명령을 실행해야 그날의 급여를 받습니다."
  },
  "ar": {
    "titre": "لوحة اللعبة",
    "contenu": "نقاط العمل (PA) — لديك 24 نقطة عمل يوميًا. يستهلك كل أمر عددًا من النقاط بحسب تعقيده، وبعض الأوامر لا يستهلك شيئًا. في وضع الاختبار، نقاط العمل غير محدودة.\n\nالمؤشرات:\n• النفوذ (INF) — وزنك السياسي\n• الشعبية (POP) — مدى تأييد الجمهور لك\n• التخفي (DIS) — قدرتك على تجنب اكتشافك\n• الصحة — حالتك الجسدية (0 = دخول المستشفى)\n• المعنويات — قدرتك على التحمل النفسي\n\nالأوامر — تُحسم كل عملية برمية نرد (1–100)، وتتأثر فرصة النجاح بخصائص شخصيتك. النتائج المحتملة: نجاح حاسم، نجاح، نجاح جزئي، إخفاق، إخفاق حاسم.\n\nالراتب — لا تتلقى راتبك اليومي إلا عند تنفيذ أمر «النوم» (مرة واحدة يوميًا)."
  },
  "pt-BR": {
    "titre": "O tabuleiro do jogo",
    "contenu": "PONTOS DE AÇÃO (PA) — Você dispõe de 24 PA por dia. Cada ordem consome PA de acordo com sua complexidade. Algumas não custam PA. No modo de teste, os PA são ilimitados.\n\nINDICADORES:\n• Influência (INF) — Seu peso político\n• Popularidade (POP) — Seu apoio entre o público\n• Discrição (DIS) — Sua capacidade de evitar ser detectado\n• Saúde — Sua condição física (0 = hospitalização)\n• Moral — Sua resistência psicológica\n\nORDENS — Cada ação é resolvida por uma jogada de dados (1–100). A chance de sucesso depende dos seus atributos. Os resultados possíveis são sucesso crítico, sucesso, sucesso parcial, falha e falha crítica.\n\nSALÁRIO — Você só recebe o salário diário ao executar a ordem “Dormir” (uma vez por dia)."
  },
  "de": {
    "titre": "Das Spielbrett",
    "contenu": "AKTIONSPUNKTE (PA) — Pro Tag stehen dir 24 PA zur Verfügung. Befehle kosten je nach Aufwand unterschiedlich viele PA. Manche sind kostenlos. Im Testmodus sind PA unbegrenzt.\n\nWERTE:\n• Einfluss (INF) — Dein politisches Gewicht\n• Beliebtheit (POP) — Dein Ansehen in der Öffentlichkeit\n• Diskretion (DIS) — Deine Fähigkeit, unentdeckt zu bleiben\n• Gesundheit — Deine körperliche Verfassung (0 = Krankenhaus)\n• Moral — Deine psychische Widerstandskraft\n\nBEFEHLE — Jede Aktion wird durch einen Würfelwurf (1–100) entschieden. Deine Attribute bestimmen die Erfolgschance. Mögliche Ergebnisse: kritischer Erfolg, Erfolg, Teilerfolg, Misserfolg, kritischer Misserfolg.\n\nGEHALT — Dein tägliches Gehalt erhältst du nur nach dem Befehl „Schlafen“ (einmal pro Tag)."
  }
};
 for(const [locale,section] of Object.entries(entries)){
  const guide=resources[locale]?.translation?.guide;
  if(guide&&!Object.hasOwn(guide,'plateau')) guide.plateau=section;
 }
})(window);
