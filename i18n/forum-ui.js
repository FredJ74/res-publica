/* Commandes d'interface du forum : traduction d'affichage uniquement.
 * Ni identité de publication, ni forum, ni texte utilisateur, ni requête serveur.
 * Réutilise le même dictionnaire et le même moteur i18next que le plateau.
 */
(function(global){
 'use strict';
 const resources=global.RP_I18N_RESOURCES;
 if(!resources)return;
 const words={
  "fr": {
    "newTopic": "Nouveau sujet",
    "reply": "Répondre",
    "retry": "Réessayer",
    "newMail": "Nouveau mail",
    "back": "Retour",
    "backToTopic": "Retour au sujet",
    "postAs": "Publier en tant que",
    "sendAs": "Envoyer en tant que"
  },
  "en": {
    "newTopic": "New topic",
    "reply": "Reply",
    "retry": "Retry",
    "newMail": "New mail",
    "back": "Back",
    "backToTopic": "Back to topic",
    "postAs": "Post as",
    "sendAs": "Send as"
  },
  "es": {
    "newTopic": "Nuevo tema",
    "reply": "Responder",
    "retry": "Reintentar",
    "newMail": "Nuevo correo",
    "back": "Volver",
    "backToTopic": "Volver al tema",
    "postAs": "Publicar como",
    "sendAs": "Enviar como"
  },
  "zh-TW": {
    "newTopic": "新主題",
    "reply": "回覆",
    "retry": "重試",
    "newMail": "新郵件",
    "back": "返回",
    "backToTopic": "返回主題",
    "postAs": "以此身分發表",
    "sendAs": "以此身分傳送"
  },
  "ru": {
    "newTopic": "Новая тема",
    "reply": "Ответить",
    "retry": "Повторить попытку",
    "newMail": "Новое письмо",
    "back": "Назад",
    "backToTopic": "К теме",
    "postAs": "Опубликовать от имени",
    "sendAs": "Отправить от имени"
  },
  "ko": {
    "newTopic": "새 주제",
    "reply": "답글",
    "retry": "다시 시도",
    "newMail": "새 편지",
    "back": "뒤로",
    "backToTopic": "주제로 돌아가기",
    "postAs": "다음 이름으로 게시",
    "sendAs": "다음 이름으로 보내기"
  },
  "ar": {
    "newTopic": "موضوع جديد",
    "reply": "الرد",
    "retry": "إعادة المحاولة",
    "newMail": "رسالة جديدة",
    "back": "رجوع",
    "backToTopic": "العودة إلى الموضوع",
    "postAs": "النشر باسم",
    "sendAs": "الإرسال باسم"
  },
  "pt-BR": {
    "newTopic": "Novo tópico",
    "reply": "Responder",
    "retry": "Tentar novamente",
    "newMail": "Novo e-mail",
    "back": "Voltar",
    "backToTopic": "Voltar ao tópico",
    "postAs": "Publicar como",
    "sendAs": "Enviar como"
  },
  "de": {
    "newTopic": "Neues Thema",
    "reply": "Antworten",
    "retry": "Erneut versuchen",
    "newMail": "Neue Nachricht",
    "back": "Zurück",
    "backToTopic": "Zurück zum Thema",
    "postAs": "Veröffentlichen als",
    "sendAs": "Senden als"
  }
};
 // Menus du forum : le texte seulement, pas les catégories, compteurs ni accès.
 const sidebar={
  "fr": {
    "institutions": "Institutionnels",
    "mailbox": "Boîte Mail",
    "receivedMails": "Mails reçus",
    "sentMails": "Mails envoyés",
    "archivedMails": "Mails archivés",
    "nationalForums": "Forums nationaux",
    "internationalForums": "Forums internationaux",
    "privateForums": "Forums privés",
    "noMessages": "Aucun message",
    "noOrganizations": "Aucune organisation trouvée. Rejoignez ou fondez une organisation pour accéder à son forum privé."
  },
  "en": {
    "institutions": "Institutions",
    "mailbox": "Mailbox",
    "receivedMails": "Received mail",
    "sentMails": "Sent mail",
    "archivedMails": "Archived mail",
    "nationalForums": "National forums",
    "internationalForums": "International forums",
    "privateForums": "Private forums",
    "noMessages": "No messages",
    "noOrganizations": "No organizations found. Join or create an organization to access its private forum."
  },
  "es": {
    "institutions": "Instituciones",
    "mailbox": "Buzón",
    "receivedMails": "Correo recibido",
    "sentMails": "Correo enviado",
    "archivedMails": "Correo archivado",
    "nationalForums": "Foros nacionales",
    "internationalForums": "Foros internacionales",
    "privateForums": "Foros privados",
    "noMessages": "Sin mensajes",
    "noOrganizations": "No se encontraron organizaciones. Únete o crea una organización para acceder a su foro privado."
  },
  "zh-TW": {
    "institutions": "官方機構",
    "mailbox": "信箱",
    "receivedMails": "收到的郵件",
    "sentMails": "寄出的郵件",
    "archivedMails": "封存的郵件",
    "nationalForums": "全國論壇",
    "internationalForums": "國際論壇",
    "privateForums": "私人論壇",
    "noMessages": "沒有訊息",
    "noOrganizations": "找不到組織。加入或建立組織，即可進入其私人論壇。"
  },
  "ru": {
    "institutions": "Учреждения",
    "mailbox": "Почта",
    "receivedMails": "Входящие письма",
    "sentMails": "Отправленные письма",
    "archivedMails": "Архив писем",
    "nationalForums": "Национальные форумы",
    "internationalForums": "Международные форумы",
    "privateForums": "Закрытые форумы",
    "noMessages": "Нет сообщений",
    "noOrganizations": "Организации не найдены. Вступите в организацию или создайте свою, чтобы открыть её закрытый форум."
  },
  "ko": {
    "institutions": "기관",
    "mailbox": "우편함",
    "receivedMails": "받은 편지",
    "sentMails": "보낸 편지",
    "archivedMails": "보관된 편지",
    "nationalForums": "국가 포럼",
    "internationalForums": "국제 포럼",
    "privateForums": "비공개 포럼",
    "noMessages": "메시지 없음",
    "noOrganizations": "조직이 없습니다. 비공개 포럼에 접근하려면 조직에 가입하거나 새로 만드세요."
  },
  "ar": {
    "institutions": "المؤسسات",
    "mailbox": "صندوق البريد",
    "receivedMails": "البريد الوارد",
    "sentMails": "البريد المرسل",
    "archivedMails": "البريد المؤرشف",
    "nationalForums": "المنتديات الوطنية",
    "internationalForums": "المنتديات الدولية",
    "privateForums": "المنتديات الخاصة",
    "noMessages": "لا توجد رسائل",
    "noOrganizations": "لم يُعثر على منظمات. انضم إلى منظمة أو أنشئ واحدة للوصول إلى منتداها الخاص."
  },
  "pt-BR": {
    "institutions": "Instituições",
    "mailbox": "Caixa de correio",
    "receivedMails": "E-mails recebidos",
    "sentMails": "E-mails enviados",
    "archivedMails": "E-mails arquivados",
    "nationalForums": "Fóruns nacionais",
    "internationalForums": "Fóruns internacionais",
    "privateForums": "Fóruns privados",
    "noMessages": "Nenhuma mensagem",
    "noOrganizations": "Nenhuma organização encontrada. Entre em uma organização ou crie uma para acessar seu fórum privado."
  },
  "de": {
    "institutions": "Institutionen",
    "mailbox": "Postfach",
    "receivedMails": "Empfangene Nachrichten",
    "sentMails": "Gesendete Nachrichten",
    "archivedMails": "Archivierte Nachrichten",
    "nationalForums": "Nationale Foren",
    "internationalForums": "Internationale Foren",
    "privateForums": "Private Foren",
    "noMessages": "Keine Nachrichten",
    "noOrganizations": "Keine Organisation gefunden. Treten Sie einer Organisation bei oder gründen Sie eine, um auf ihr privates Forum zuzugreifen."
  }
};
 for(const [lang,labels] of Object.entries(sidebar)) Object.assign(words[lang],labels);
 const keys=new Set(Object.keys(words.fr));
 for(const [lang,labels] of Object.entries(words)){
  if(resources[lang]?.translation)
   resources[lang].translation.forumUI={...labels};
 }
 function labelHtml(key,original){
  if(!keys.has(key)||typeof original!=='string')return original;
  const locale=global.RPPlateauI18n?.language?.()||'fr';
  const translation=global.i18next?.t?.('forumUI.'+key,{lng:locale,defaultValue:original});
  if(typeof translation!=='string'||!translation.trim()||translation===original)return original;
  return translation.replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 }
 // Forums canoniques : seul l'affichage est traduit, jamais l'identifiant
 // ni les forums de joueurs, locaux ou d'organisations.
 const names={
  "fr": {
    "national": "Forum National",
    "presidence": "La Présidence à la Nation",
    "assemblee": "L'Assemblée nationale",
    "gouvernement": "Le Gouvernement à la Nation",
    "presse": "Presse & Médias",
    "international": "Forum International",
    "sport": "Championnat Sportif"
  },
  "en": {
    "national": "National Forum",
    "presidence": "Presidency to the Nation",
    "assemblee": "National Assembly",
    "gouvernement": "Government to the Nation",
    "presse": "Press & Media",
    "international": "International Forum",
    "sport": "Sports Championship"
  },
  "es": {
    "national": "Foro nacional",
    "presidence": "La Presidencia a la Nación",
    "assemblee": "Asamblea Nacional",
    "gouvernement": "El Gobierno a la Nación",
    "presse": "Prensa y medios",
    "international": "Foro internacional",
    "sport": "Campeonato deportivo"
  },
  "zh-TW": {
    "national": "全國論壇",
    "presidence": "總統府向全國發言",
    "assemblee": "國民議會",
    "gouvernement": "政府向全國發言",
    "presse": "新聞與媒體",
    "international": "國際論壇",
    "sport": "體育錦標賽"
  },
  "ru": {
    "national": "Национальный форум",
    "presidence": "Обращения президентской власти к народу",
    "assemblee": "Национальное собрание",
    "gouvernement": "Обращения правительства к народу",
    "presse": "Пресса и СМИ",
    "international": "Международный форум",
    "sport": "Спортивный чемпионат"
  },
  "ko": {
    "national": "국가 포럼",
    "presidence": "대통령의 대국민 발표",
    "assemblee": "국민의회",
    "gouvernement": "정부의 대국민 발표",
    "presse": "언론 및 미디어",
    "international": "국제 포럼",
    "sport": "스포츠 챔피언십"
  },
  "ar": {
    "national": "المنتدى الوطني",
    "presidence": "الرئاسة تخاطب الأمة",
    "assemblee": "الجمعية الوطنية",
    "gouvernement": "الحكومة تخاطب الأمة",
    "presse": "الصحافة والإعلام",
    "international": "المنتدى الدولي",
    "sport": "البطولة الرياضية"
  },
  "pt-BR": {
    "national": "Fórum Nacional",
    "presidence": "Presidência à Nação",
    "assemblee": "Assembleia Nacional",
    "gouvernement": "Governo à Nação",
    "presse": "Imprensa e mídia",
    "international": "Fórum Internacional",
    "sport": "Campeonato Esportivo"
  },
  "de": {
    "national": "Nationales Forum",
    "presidence": "Das Präsidialamt an die Nation",
    "assemblee": "Nationalversammlung",
    "gouvernement": "Die Regierung an die Nation",
    "presse": "Presse und Medien",
    "international": "Internationales Forum",
    "sport": "Sportmeisterschaft"
  }
};
 const descriptions={
  "fr": {
    "national": "Débats politiques nationaux",
    "presidence": "Discours et annonces officielles depuis la Présidence",
    "assemblee": "Projets de loi, débats parlementaires et résultats des scrutins",
    "gouvernement": "Réservé au gouvernement",
    "presse": "Réservé aux journalistes",
    "international": "Relations entre empires",
    "sport": "Résultats, classements et débats de supporters"
  },
  "en": {
    "national": "National political debates",
    "presidence": "Official speeches and announcements from the Presidency",
    "assemblee": "Bills, parliamentary debates and voting results",
    "gouvernement": "Reserved for government officials",
    "presse": "Reserved for journalists",
    "international": "Relations between empires",
    "sport": "Results, standings and supporters' debates"
  },
  "es": {
    "national": "Debates políticos nacionales",
    "presidence": "Discursos y comunicados oficiales de la Presidencia",
    "assemblee": "Proyectos de ley, debates parlamentarios y resultados de votaciones",
    "gouvernement": "Reservado al Gobierno",
    "presse": "Reservado a periodistas",
    "international": "Relaciones entre imperios",
    "sport": "Resultados, clasificaciones y debates de aficionados"
  },
  "zh-TW": {
    "national": "全國政治討論",
    "presidence": "總統府的官方演說與公告",
    "assemblee": "法案、議會辯論及表決結果",
    "gouvernement": "僅限政府成員",
    "presse": "僅限記者",
    "international": "帝國間的關係",
    "sport": "比賽結果、排名及球迷討論"
  },
  "ru": {
    "national": "Общенациональные политические дискуссии",
    "presidence": "Официальные выступления и объявления президента",
    "assemblee": "Законопроекты, парламентские дебаты и результаты голосований",
    "gouvernement": "Только для членов правительства",
    "presse": "Только для журналистов",
    "international": "Отношения между империями",
    "sport": "Результаты, турнирные таблицы и обсуждения болельщиков"
  },
  "ko": {
    "national": "국가 정치 토론",
    "presidence": "대통령의 공식 연설과 발표",
    "assemblee": "법안, 의회 토론 및 표결 결과",
    "gouvernement": "정부 관계자 전용",
    "presse": "언론인 전용",
    "international": "제국 간 관계",
    "sport": "경기 결과, 순위 및 팬 토론"
  },
  "ar": {
    "national": "نقاشات سياسية وطنية",
    "presidence": "خطابات الرئاسة وإعلاناتها الرسمية",
    "assemblee": "مشاريع القوانين والنقاشات البرلمانية ونتائج التصويت",
    "gouvernement": "مخصص لأعضاء الحكومة",
    "presse": "مخصص للصحفيين",
    "international": "العلاقات بين الإمبراطوريات",
    "sport": "النتائج والترتيب ونقاشات المشجعين"
  },
  "pt-BR": {
    "national": "Debates políticos nacionais",
    "presidence": "Discursos e comunicados oficiais da Presidência",
    "assemblee": "Projetos de lei, debates parlamentares e resultados das votações",
    "gouvernement": "Reservado ao governo",
    "presse": "Reservado aos jornalistas",
    "international": "Relações entre impérios",
    "sport": "Resultados, classificações e debates dos torcedores"
  },
  "de": {
    "national": "Nationale politische Debatten",
    "presidence": "Offizielle Reden und Bekanntmachungen des Präsidialamts",
    "assemblee": "Gesetzesentwürfe, Parlamentsdebatten und Abstimmungsergebnisse",
    "gouvernement": "Nur für Regierungsmitglieder",
    "presse": "Nur für Journalisten",
    "international": "Beziehungen zwischen den Imperien",
    "sport": "Ergebnisse, Tabellen und Debatten der Fans"
  }
};
 for(const locale of Object.keys(names)){
  if(resources[locale]?.translation){
   resources[locale].translation.forumNames={...names[locale]};
   resources[locale].translation.forumDescriptions={...descriptions[locale]};
  }
 }
 function forumText(kind,id,original){
  const fr=kind==='forumNames'?names.fr:descriptions.fr;
  if(typeof original!=='string'||fr[id]!==original)return original;
  const locale=global.RPPlateauI18n?.language?.()||'fr';
  const translation=global.i18next?.t?.(kind+'.'+id,{lng:locale,defaultValue:original});
  if(typeof translation!=='string'||!translation.trim()||translation===original)return original;
  return translation.replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 }
 function forumNameHtml(id,original){return forumText('forumNames',id,original);}
 function forumDescriptionHtml(id,original){return forumText('forumDescriptions',id,original);}
 global.RPForumUI=Object.freeze({labelHtml,forumNameHtml,forumDescriptionHtml});
})(window);
