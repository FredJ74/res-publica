/* Tableau des organisations : textes fixes uniquement, moteur commun. */
(function(global){
 'use strict';
 const locales=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
 const rows=[
  [
    "title",
    "Tableau des organisations",
    "Organization directory",
    "Directorio de organizaciones",
    "組織一覽",
    "Список организаций",
    "조직 목록",
    "دليل المنظمات",
    "Diretório de organizações",
    "Organisationsverzeichnis"
  ],
  [
    "empty",
    "Aucune organisation connue pour l'instant.",
    "No known organizations yet.",
    "Aún no se conoce ninguna organización.",
    "目前沒有已知的組織。",
    "Пока нет известных организаций.",
    "아직 알려진 조직이 없습니다.",
    "لا توجد منظمات معروفة حتى الآن.",
    "Nenhuma organização conhecida por enquanto.",
    "Noch keine Organisation bekannt."
  ],
  [
    "privateDetails",
    "Chef : non communiqué · Siège : non communiqué",
    "Leader: undisclosed · Headquarters: undisclosed",
    "Líder: no comunicado · Sede: no comunicada",
    "領袖：未公開 · 總部：未公開",
    "Руководитель: не раскрыт · Штаб-квартира: не раскрыта",
    "대표: 비공개 · 본부: 비공개",
    "القائد: غير معلن · المقر: غير معلن",
    "Líder: não divulgado · Sede: não divulgada",
    "Leitung: nicht bekannt gegeben · Sitz: nicht bekannt gegeben"
  ],
  [
    "leaderPrefix",
    "Chef : ",
    "Leader: ",
    "Líder: ",
    "領袖：",
    "Руководитель: ",
    "대표: ",
    "القائد: ",
    "Líder: ",
    "Leitung: "
  ],
  [
    "seatPrefix",
    "Siège : ",
    "Headquarters: ",
    "Sede: ",
    "總部：",
    "Штаб-квартира: ",
    "본부: ",
    "المقر: ",
    "Sede: ",
    "Sitz: "
  ],
  [
    "unknownSeat",
    "Siège inconnu",
    "Unknown headquarters",
    "Sede desconocida",
    "總部不詳",
    "Штаб-квартира неизвестна",
    "본부 불명",
    "المقر غير معروف",
    "Sede desconhecida",
    "Sitz unbekannt"
  ],
  [
    "type_politique",
    "Organisation Politique",
    "Political Organization",
    "Organización Política",
    "政治組織",
    "Политическая организация",
    "정치 조직",
    "منظمة سياسية",
    "Organização Política",
    "Politische Organisation"
  ],
  [
    "type_religieuse",
    "Organisation Religieuse",
    "Religious Organization",
    "Organización Religiosa",
    "宗教組織",
    "Религиозная организация",
    "종교 조직",
    "منظمة دينية",
    "Organização Religiosa",
    "Religiöse Organisation"
  ],
  [
    "type_syndicale",
    "Organisation Syndicale",
    "Trade Union Organization",
    "Organización Sindical",
    "工會組織",
    "Профсоюзная организация",
    "노동조합 조직",
    "منظمة نقابية",
    "Organização Sindical",
    "Gewerkschaftsorganisation"
  ],
  [
    "type_economique",
    "Organisation Economique",
    "Economic Organization",
    "Organización Económica",
    "經濟組織",
    "Экономическая организация",
    "경제 조직",
    "منظمة اقتصادية",
    "Organização Econômica",
    "Wirtschaftsorganisation"
  ],
  [
    "type_criminelle",
    "Organisation Criminelle",
    "Criminal Organization",
    "Organización Criminal",
    "犯罪組織",
    "Преступная организация",
    "범죄 조직",
    "منظمة إجرامية",
    "Organização Criminosa",
    "Kriminelle Organisation"
  ],
  [
    "type_loge",
    "Loge Maconnique",
    "Masonic Lodge",
    "Logia Masónica",
    "共濟會會所",
    "Масонская ложа",
    "프리메이슨 지부",
    "محفل ماسوني",
    "Loja Maçônica",
    "Freimaurerloge"
  ],
  [
    "type_mediatique",
    "Organisation Mediatique",
    "Media Organization",
    "Organización de Medios",
    "媒體組織",
    "Медиаорганизация",
    "언론 조직",
    "منظمة إعلامية",
    "Organização de Mídia",
    "Medienorganisation"
  ],
  [
    "type_sportive",
    "Club Sportif",
    "Sports Club",
    "Club Deportivo",
    "體育俱樂部",
    "Спортивный клуб",
    "스포츠 클럽",
    "نادٍ رياضي",
    "Clube Esportivo",
    "Sportverein"
  ],
  [
    "type_supporters",
    "Club de Supporters",
    "Supporters’ Club",
    "Club de Aficionados",
    "球迷會",
    "Клуб болельщиков",
    "서포터즈 클럽",
    "نادي مشجعين",
    "Clube de Torcedores",
    "Fanclub"
  ]
];
 for(const [index,lang]of locales.entries())if(global.RP_I18N_RESOURCES?.[lang]?.translation)
  global.RP_I18N_RESOURCES[lang].translation.organizationDirectory=Object.fromEntries(rows.map(row=>[row[0],row[index+1]]));
})(window);
