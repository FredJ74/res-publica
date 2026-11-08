/* Guide politique : localisation informative, aucune logique électorale. */
(function(global){
 'use strict';
 const resources=global.RP_I18N_RESOURCES;
 if(!resources)return;
 const entries={
  "en": {
    "titre": "Political life",
    "contenu": "OFFICES AND MANDATES:\nPositions form a seven-level hierarchy. At the top are the President, Prime Minister and ministers; at the bottom are local elected officials and citizens.\n\nELECTIONS:\n• Mandates last 5–6 weeks.\n• Results are announced at midnight on Sunday.\n• Candidates may stand from the third week after the previous election.\n• Campaigning takes place in week four: player voting and leaflets distributed to NPCs.\n• First round: over 50% wins outright; otherwise the top two contest a second round.\n• For town halls and governorships, the second round is between candidates who won over 20%.\n• Deputies are elected in single-member constituencies in one round by plurality.\n\nAPPOINTING A MINISTER:\nOnly the President can appoint ministers. The candidate receives an appointment mail sent from the Presidential Palace office."
  },
  "es": {
    "titre": "Vida política",
    "contenu": "CARGOS Y MANDATOS:\nLos cargos forman una jerarquía de siete niveles. Arriba están el Presidente, el Primer Ministro y los ministros; abajo, representantes locales y ciudadanos.\n\nELECCIONES:\n• Los mandatos duran 5–6 semanas.\n• Los resultados se anuncian el domingo a medianoche.\n• Se puede presentar candidatura desde la tercera semana tras las últimas elecciones.\n• La campaña se desarrolla en la cuarta semana: voto de jugadores y reparto de panfletos a PNJ.\n• Primera vuelta: más del 50% gana directamente; si no, segunda vuelta entre los dos primeros.\n• En alcaldías y gobernaciones pasan a la segunda vuelta quienes superen el 20%.\n• Los diputados se eligen en circunscripciones uninominales, a una vuelta y por mayoría relativa.\n\nNOMBRAR A UN MINISTRO:\nSolo el Presidente nombra ministros; el candidato recibe un correo enviado desde el despacho del Palacio Presidencial."
  },
  "zh-TW": {
    "titre": "政治生活",
    "contenu": "職位與任期：\n職位分為七個層級。最上層是總統、總理及部長；下層是地方民選代表和一般公民。\n\n選舉：\n• 任期為 5–6 週。\n• 結果於星期日午夜公布。\n• 上次選舉後第三週起可登記參選。\n• 第四週為競選期：玩家投票，並向 NPC 發放傳單。\n• 第一輪得票超過 50% 即直接當選；否則由前兩名進行第二輪。\n• 市長與地方首長選舉：第一輪得票超過 20% 的候選人進入第二輪。\n• 議員：單一選區一輪投票，以相對多數決定當選者。\n\n任命部長：\n只有總統可以任命部長，任命通知由總統府辦公室寄送電子郵件給候選人。"
  },
  "ru": {
    "titre": "Политическая жизнь",
    "contenu": "ДОЛЖНОСТИ И МАНДАТЫ:\nДолжности образуют иерархию из семи уровней. Наверху — президент, премьер-министр и министры; внизу — местные избранники и граждане.\n\nВЫБОРЫ:\n• Мандат длится 5–6 недель.\n• Результаты объявляются в полночь в воскресенье.\n• Выдвижение возможно с третьей недели после предыдущих выборов.\n• Четвёртая неделя — агитация: голосование игроков и распространение листовок среди NPC.\n• Первый тур: более 50% — победа сразу; иначе во второй тур выходят двое лидеров.\n• Для мэрий и губернаторов во второй тур проходят кандидаты, получившие более 20%.\n• Депутаты избираются по одномандатным округам в один тур относительным большинством.\n\nНАЗНАЧЕНИЕ МИНИСТРА:\nНазначать министров может только президент. Кандидат получает письмо из кабинета президентского дворца."
  },
  "ko": {
    "titre": "정치 활동",
    "contenu": "직책과 임기:\n직책은 7단계 위계로 구성됩니다. 최상위에는 대통령, 총리, 장관이 있고 아래에는 지방 선출직과 시민이 있습니다.\n\n선거:\n• 임기는 5–6주입니다.\n• 결과는 일요일 자정에 발표됩니다.\n• 지난 선거 후 셋째 주부터 후보로 등록할 수 있습니다.\n• 넷째 주는 선거운동 기간으로, 플레이어 투표와 NPC 대상 전단 배포가 이루어집니다.\n• 1차 투표에서 50%를 초과하면 당선됩니다. 그렇지 않으면 상위 두 명이 결선에 진출합니다.\n• 시장·주지사 선거에서는 20%를 초과한 후보들이 결선에 진출합니다.\n• 국회의원은 단일 선거구에서 한 차례 투표하며 최다 득표자가 당선됩니다.\n\n장관 임명:\n장관은 대통령만 임명할 수 있습니다. 대통령궁 집무실에서 후보자에게 임명 편지를 보냅니다."
  },
  "ar": {
    "titre": "الحياة السياسية",
    "contenu": "المناصب والولايات:\nالمناصب مرتبة في هرم من سبعة مستويات. في القمة الرئيس ورئيس الوزراء والوزراء، وفي القاعدة المسؤولون المحليون المنتخبون والمواطنون.\n\nالانتخابات:\n• تستمر الولاية 5–6 أسابيع.\n• تُعلن النتائج عند منتصف ليل الأحد.\n• يمكن تقديم الترشيحات من الأسبوع الثالث بعد الانتخابات السابقة.\n• الأسبوع الرابع للحملة: تصويت اللاعبين وتوزيع منشورات على الشخصيات غير اللاعبة.\n• الجولة الأولى: من يتجاوز 50% يفوز مباشرة، وإلا يتنافس الأول والثاني في جولة ثانية.\n• في انتخابات البلديات والمحافظات، يدخل الجولة الثانية من تجاوزوا 20%.\n• النواب يُنتخبون في دوائر فردية بجولة واحدة وبالأغلبية النسبية.\n\nتعيين وزير:\nالرئيس وحده يعين الوزراء، ويرسل بريد التعيين إلى المرشح من مكتب القصر الرئاسي."
  },
  "pt-BR": {
    "titre": "Vida política",
    "contenu": "CARGOS E MANDATOS:\nOs cargos formam uma hierarquia de sete níveis. No topo estão o Presidente, o Primeiro-Ministro e os ministros; na base, representantes locais eleitos e cidadãos.\n\nELEIÇÕES:\n• Mandatos duram 5–6 semanas.\n• Resultados saem à meia-noite de domingo.\n• Candidaturas podem ser apresentadas a partir da terceira semana após as eleições anteriores.\n• A quarta semana é de campanha: votação de jogadores e distribuição de panfletos aos PNJs.\n• Primeiro turno: mais de 50% garante vitória; caso contrário, os dois primeiros disputam o segundo turno.\n• Nas eleições municipais e para governos regionais, disputam o segundo turno os candidatos com mais de 20%.\n• Deputados são eleitos em distritos uninominais, em um turno, por maioria relativa.\n\nNOMEAR UM MINISTRO:\nSó o Presidente pode nomear ministros. O candidato recebe um e-mail enviado pelo gabinete do Palácio Presidencial."
  },
  "de": {
    "titre": "Politisches Leben",
    "contenu": "ÄMTER UND MANDATE:\nDie Ämter bilden eine Hierarchie mit sieben Ebenen. Oben stehen Präsident, Premierminister und Minister; unten lokale Mandatsträger und Bürger.\n\nWAHLEN:\n• Mandate dauern 5–6 Wochen.\n• Die Ergebnisse werden sonntags um Mitternacht bekannt gegeben.\n• Kandidaturen sind ab der dritten Woche nach der letzten Wahl möglich.\n• Die vierte Woche ist Wahlkampf: Spieler stimmen ab, und Flugblätter werden an NPCs verteilt.\n• Erster Wahlgang: Über 50% bedeutet direkte Wahl, andernfalls treten die beiden Führenden im zweiten Wahlgang an.\n• Bei Bürgermeistern und Gouverneuren erreichen Kandidaten mit über 20% die zweite Runde.\n• Abgeordnete werden in Einerwahlkreisen in einem Wahlgang mit relativer Mehrheit gewählt.\n\nMINISTER ERNENNEN:\nNur der Präsident kann Minister ernennen. Die Ernennung erfolgt per E-Mail aus dem Büro des Präsidentenpalasts an den Kandidaten."
  }
};
 for(const [locale,section] of Object.entries(entries)){
  const guide=resources[locale]?.translation?.guide;
  if(guide&&!Object.hasOwn(guide,'politique'))guide.politique=section;
 }
})(window);
