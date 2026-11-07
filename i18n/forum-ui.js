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
 // Messages statiques de lecture des forums : distinguer panne et vraie liste vide.
 const listing={
  "fr": {
    "chooseCategory": "Choisissez une catégorie à gauche",
    "categoryHelp": "Forums nationaux, internationaux ou privés — déroulez une catégorie pour voir ses forums.",
    "loadingTopics": "Chargement des sujets depuis le serveur…",
    "failedTopics": "Les sujets de cette rubrique n'ont pas pu être chargés.",
    "failedTopicsDetail": "Ce n'est pas qu'elle est vide : la lecture du serveur a échoué ou a dépassé 12 secondes.",
    "noTopics": "Aucun sujet.",
    "firstTopic": "Soyez le premier à en créer un !",
    "presidentOnly": "Seul le Président peut s'exprimer ici.",
    "topicColumn": "Sujet",
    "authorColumn": "Auteur",
    "lastPostColumn": "Dernier post",
    "viewsColumn": "Vues",
    "repliesColumn": "Rép."
  },
  "en": {
    "chooseCategory": "Choose a category on the left",
    "categoryHelp": "National, international or private forums — expand a category to see its forums.",
    "loadingTopics": "Loading topics from the server…",
    "failedTopics": "The topics in this section could not be loaded.",
    "failedTopicsDetail": "This does not mean the section is empty: the server read failed or exceeded 12 seconds.",
    "noTopics": "No topics.",
    "firstTopic": "Be the first to create one!",
    "presidentOnly": "Only the President may speak here.",
    "topicColumn": "Topic",
    "authorColumn": "Author",
    "lastPostColumn": "Latest post",
    "viewsColumn": "Views",
    "repliesColumn": "Replies"
  },
  "es": {
    "chooseCategory": "Elige una categoría a la izquierda",
    "categoryHelp": "Foros nacionales, internacionales o privados: despliega una categoría para ver sus foros.",
    "loadingTopics": "Cargando temas desde el servidor…",
    "failedTopics": "No se pudieron cargar los temas de esta sección.",
    "failedTopicsDetail": "Esto no significa que esté vacía: la lectura del servidor falló o tardó más de 12 segundos.",
    "noTopics": "No hay temas.",
    "firstTopic": "¡Sé el primero en crear uno!",
    "presidentOnly": "Solo el Presidente puede hablar aquí.",
    "topicColumn": "Tema",
    "authorColumn": "Autor",
    "lastPostColumn": "Última publicación",
    "viewsColumn": "Vistas",
    "repliesColumn": "Resp."
  },
  "zh-TW": {
    "chooseCategory": "請從左側選擇分類",
    "categoryHelp": "全國、國際或私人論壇：展開分類即可查看所屬論壇。",
    "loadingTopics": "正在從伺服器載入主題…",
    "failedTopics": "無法載入此分類中的主題。",
    "failedTopicsDetail": "這不代表分類是空的：伺服器讀取失敗或超過 12 秒。",
    "noTopics": "沒有主題。",
    "firstTopic": "成為第一位發表主題的人！",
    "presidentOnly": "只有總統可以在此發言。",
    "topicColumn": "主題",
    "authorColumn": "作者",
    "lastPostColumn": "最新貼文",
    "viewsColumn": "瀏覽",
    "repliesColumn": "回覆"
  },
  "ru": {
    "chooseCategory": "Выберите категорию слева",
    "categoryHelp": "Национальные, международные и закрытые форумы — раскройте категорию, чтобы увидеть её форумы.",
    "loadingTopics": "Загрузка тем с сервера…",
    "failedTopics": "Не удалось загрузить темы этого раздела.",
    "failedTopicsDetail": "Это не значит, что раздел пуст: ошибка чтения с сервера или превышено 12 секунд.",
    "noTopics": "Тем пока нет.",
    "firstTopic": "Создайте первую тему!",
    "presidentOnly": "Здесь может выступать только президент.",
    "topicColumn": "Тема",
    "authorColumn": "Автор",
    "lastPostColumn": "Последнее сообщение",
    "viewsColumn": "Просмотры",
    "repliesColumn": "Ответы"
  },
  "ko": {
    "chooseCategory": "왼쪽에서 분류를 선택하세요",
    "categoryHelp": "국가, 국제 또는 비공개 포럼: 분류를 펼쳐 포럼을 확인하세요.",
    "loadingTopics": "서버에서 주제를 불러오는 중…",
    "failedTopics": "이 분류의 주제를 불러오지 못했습니다.",
    "failedTopicsDetail": "비어 있다는 뜻이 아닙니다. 서버 읽기가 실패했거나 12초를 초과했습니다.",
    "noTopics": "주제가 없습니다.",
    "firstTopic": "첫 주제를 작성해 보세요!",
    "presidentOnly": "대통령만 이곳에 글을 쓸 수 있습니다.",
    "topicColumn": "주제",
    "authorColumn": "작성자",
    "lastPostColumn": "최근 게시물",
    "viewsColumn": "조회",
    "repliesColumn": "답글"
  },
  "ar": {
    "chooseCategory": "اختر فئة من اليسار",
    "categoryHelp": "منتديات وطنية أو دولية أو خاصة — افتح فئة لعرض منتدياتها.",
    "loadingTopics": "جارٍ تحميل المواضيع من الخادم…",
    "failedTopics": "تعذّر تحميل مواضيع هذا القسم.",
    "failedTopicsDetail": "هذا لا يعني أن القسم فارغ: فشلت قراءة الخادم أو تجاوزت 12 ثانية.",
    "noTopics": "لا توجد مواضيع.",
    "firstTopic": "كن أول من ينشئ موضوعًا!",
    "presidentOnly": "الرئيس وحده يستطيع النشر هنا.",
    "topicColumn": "الموضوع",
    "authorColumn": "الكاتب",
    "lastPostColumn": "آخر مشاركة",
    "viewsColumn": "المشاهدات",
    "repliesColumn": "الردود"
  },
  "pt-BR": {
    "chooseCategory": "Escolha uma categoria à esquerda",
    "categoryHelp": "Fóruns nacionais, internacionais ou privados — expanda uma categoria para ver seus fóruns.",
    "loadingTopics": "Carregando tópicos do servidor…",
    "failedTopics": "Não foi possível carregar os tópicos desta seção.",
    "failedTopicsDetail": "Isso não significa que esteja vazia: a leitura do servidor falhou ou ultrapassou 12 segundos.",
    "noTopics": "Nenhum tópico.",
    "firstTopic": "Seja o primeiro a criar um!",
    "presidentOnly": "Somente o Presidente pode se manifestar aqui.",
    "topicColumn": "Tópico",
    "authorColumn": "Autor",
    "lastPostColumn": "Última publicação",
    "viewsColumn": "Visualizações",
    "repliesColumn": "Resp."
  },
  "de": {
    "chooseCategory": "Wähle links eine Kategorie",
    "categoryHelp": "Nationale, internationale oder private Foren — klappe eine Kategorie auf, um ihre Foren zu sehen.",
    "loadingTopics": "Themen werden vom Server geladen…",
    "failedTopics": "Die Themen dieses Bereichs konnten nicht geladen werden.",
    "failedTopicsDetail": "Der Bereich ist nicht unbedingt leer: Der Serverzugriff schlug fehl oder dauerte länger als 12 Sekunden.",
    "noTopics": "Keine Themen.",
    "firstTopic": "Erstelle das erste Thema!",
    "presidentOnly": "Hier darf nur der Präsident Beiträge verfassen.",
    "topicColumn": "Thema",
    "authorColumn": "Autor",
    "lastPostColumn": "Letzter Beitrag",
    "viewsColumn": "Aufrufe",
    "repliesColumn": "Antw."
  }
};
 for(const [lang,labels] of Object.entries(listing)) Object.assign(words[lang],labels);
 // Compositeur riche partagé : traduction purement visuelle des contrôles.
 const composer={
  "fr": {
    "topicTitle": "Titre du sujet",
    "topicPlaceholder": "Intitulé du sujet...",
    "addTextZone": "Ajouter une zone de texte",
    "addImage": "Ajouter une image",
    "preview": "Prévisualiser",
    "backToEditing": "Revenir à l'édition",
    "publishTopic": "Publier le sujet",
    "publishReply": "Publier la réponse",
    "saveChanges": "Enregistrer les modifications",
    "cancel": "Annuler",
    "editMessage": "Modifier le message"
  },
  "en": {
    "topicTitle": "Topic title",
    "topicPlaceholder": "Topic title...",
    "addTextZone": "Add a text area",
    "addImage": "Add an image",
    "preview": "Preview",
    "backToEditing": "Back to editing",
    "publishTopic": "Publish topic",
    "publishReply": "Publish reply",
    "saveChanges": "Save changes",
    "cancel": "Cancel",
    "editMessage": "Edit message"
  },
  "es": {
    "topicTitle": "Título del tema",
    "topicPlaceholder": "Título del tema...",
    "addTextZone": "Añadir zona de texto",
    "addImage": "Añadir imagen",
    "preview": "Vista previa",
    "backToEditing": "Volver a editar",
    "publishTopic": "Publicar tema",
    "publishReply": "Publicar respuesta",
    "saveChanges": "Guardar cambios",
    "cancel": "Cancelar",
    "editMessage": "Editar mensaje"
  },
  "zh-TW": {
    "topicTitle": "主題標題",
    "topicPlaceholder": "主題標題…",
    "addTextZone": "新增文字區塊",
    "addImage": "新增圖片",
    "preview": "預覽",
    "backToEditing": "返回編輯",
    "publishTopic": "發布主題",
    "publishReply": "發布回覆",
    "saveChanges": "儲存修改",
    "cancel": "取消",
    "editMessage": "編輯訊息"
  },
  "ru": {
    "topicTitle": "Название темы",
    "topicPlaceholder": "Название темы...",
    "addTextZone": "Добавить текстовый блок",
    "addImage": "Добавить изображение",
    "preview": "Предпросмотр",
    "backToEditing": "Вернуться к редактированию",
    "publishTopic": "Опубликовать тему",
    "publishReply": "Опубликовать ответ",
    "saveChanges": "Сохранить изменения",
    "cancel": "Отмена",
    "editMessage": "Изменить сообщение"
  },
  "ko": {
    "topicTitle": "주제 제목",
    "topicPlaceholder": "주제 제목...",
    "addTextZone": "텍스트 영역 추가",
    "addImage": "이미지 추가",
    "preview": "미리 보기",
    "backToEditing": "편집으로 돌아가기",
    "publishTopic": "주제 게시",
    "publishReply": "답글 게시",
    "saveChanges": "변경 사항 저장",
    "cancel": "취소",
    "editMessage": "메시지 수정"
  },
  "ar": {
    "topicTitle": "عنوان الموضوع",
    "topicPlaceholder": "عنوان الموضوع...",
    "addTextZone": "إضافة مساحة نصية",
    "addImage": "إضافة صورة",
    "preview": "معاينة",
    "backToEditing": "العودة إلى التحرير",
    "publishTopic": "نشر الموضوع",
    "publishReply": "نشر الرد",
    "saveChanges": "حفظ التغييرات",
    "cancel": "إلغاء",
    "editMessage": "تعديل الرسالة"
  },
  "pt-BR": {
    "topicTitle": "Título do tópico",
    "topicPlaceholder": "Título do tópico...",
    "addTextZone": "Adicionar área de texto",
    "addImage": "Adicionar imagem",
    "preview": "Pré-visualizar",
    "backToEditing": "Voltar à edição",
    "publishTopic": "Publicar tópico",
    "publishReply": "Publicar resposta",
    "saveChanges": "Salvar alterações",
    "cancel": "Cancelar",
    "editMessage": "Editar mensagem"
  },
  "de": {
    "topicTitle": "Thementitel",
    "topicPlaceholder": "Thementitel...",
    "addTextZone": "Textbereich hinzufügen",
    "addImage": "Bild hinzufügen",
    "preview": "Vorschau",
    "backToEditing": "Zurück zur Bearbeitung",
    "publishTopic": "Thema veröffentlichen",
    "publishReply": "Antwort veröffentlichen",
    "saveChanges": "Änderungen speichern",
    "cancel": "Abbrechen",
    "editMessage": "Nachricht bearbeiten"
  }
};
 for(const [lang,labels] of Object.entries(composer)) Object.assign(words[lang],labels);
 // Listes et lecture des messages : libellés uniquement, conservation et ACL identiques.
 const mailbox={
  "fr": {
    "sentMessagesTitle": "Messages envoyés",
    "noSentMail": "Aucun message envoyé.",
    "toLabel": "À :",
    "archivesTitle": "Archives",
    "noArchivedMail": "Aucun message archivé.",
    "fromLabel": "De :",
    "receivedMessagesTitle": "Messages reçus",
    "noReceivedMail": "Aucun message reçu.",
    "unarchive": "Désarchiver",
    "archiveKeep": "Archiver (conserver indéfiniment)",
    "delete": "Supprimer",
    "orgReplyUnavailable": "La réponse directe à une organisation n'est pas encore disponible — aucune boîte de messagerie propre aux organisations n'existe à ce jour.",
    "autoDeleteNotice": "Ce message sera supprimé automatiquement 14 jours après réception, sauf archivage."
  },
  "en": {
    "sentMessagesTitle": "Sent messages",
    "noSentMail": "No sent messages.",
    "toLabel": "To:",
    "archivesTitle": "Archives",
    "noArchivedMail": "No archived messages.",
    "fromLabel": "From:",
    "receivedMessagesTitle": "Received messages",
    "noReceivedMail": "No received messages.",
    "unarchive": "Unarchive",
    "archiveKeep": "Archive (keep indefinitely)",
    "delete": "Delete",
    "orgReplyUnavailable": "Direct replies to organizations are not available yet — organizations do not currently have their own mailboxes.",
    "autoDeleteNotice": "This message will be deleted automatically 14 days after receipt unless archived."
  },
  "es": {
    "sentMessagesTitle": "Mensajes enviados",
    "noSentMail": "No hay mensajes enviados.",
    "toLabel": "Para:",
    "archivesTitle": "Archivos",
    "noArchivedMail": "No hay mensajes archivados.",
    "fromLabel": "De:",
    "receivedMessagesTitle": "Mensajes recibidos",
    "noReceivedMail": "No hay mensajes recibidos.",
    "unarchive": "Desarchivar",
    "archiveKeep": "Archivar (conservar indefinidamente)",
    "delete": "Eliminar",
    "orgReplyUnavailable": "Todavía no se puede responder directamente a una organización: las organizaciones aún no tienen buzón propio.",
    "autoDeleteNotice": "Este mensaje se eliminará automáticamente 14 días después de recibirlo, salvo que se archive."
  },
  "zh-TW": {
    "sentMessagesTitle": "已寄送訊息",
    "noSentMail": "沒有已寄送訊息。",
    "toLabel": "收件者：",
    "archivesTitle": "封存",
    "noArchivedMail": "沒有封存訊息。",
    "fromLabel": "寄件者：",
    "receivedMessagesTitle": "收到的訊息",
    "noReceivedMail": "沒有收到的訊息。",
    "unarchive": "取消封存",
    "archiveKeep": "封存（永久保留）",
    "delete": "刪除",
    "orgReplyUnavailable": "目前尚無法直接回覆組織：組織還沒有專屬信箱。",
    "autoDeleteNotice": "除非封存，否則此訊息將在收到 14 天後自動刪除。"
  },
  "ru": {
    "sentMessagesTitle": "Отправленные сообщения",
    "noSentMail": "Отправленных сообщений нет.",
    "toLabel": "Кому:",
    "archivesTitle": "Архив",
    "noArchivedMail": "Архивных сообщений нет.",
    "fromLabel": "От:",
    "receivedMessagesTitle": "Полученные сообщения",
    "noReceivedMail": "Полученных сообщений нет.",
    "unarchive": "Разархивировать",
    "archiveKeep": "Архивировать (хранить бессрочно)",
    "delete": "Удалить",
    "orgReplyUnavailable": "Прямой ответ организации пока недоступен — у организаций ещё нет собственных почтовых ящиков.",
    "autoDeleteNotice": "Сообщение автоматически удалится через 14 дней после получения, если его не архивировать."
  },
  "ko": {
    "sentMessagesTitle": "보낸 메시지",
    "noSentMail": "보낸 메시지가 없습니다.",
    "toLabel": "받는 사람:",
    "archivesTitle": "보관함",
    "noArchivedMail": "보관된 메시지가 없습니다.",
    "fromLabel": "보낸 사람:",
    "receivedMessagesTitle": "받은 메시지",
    "noReceivedMail": "받은 메시지가 없습니다.",
    "unarchive": "보관 해제",
    "archiveKeep": "보관(무기한 유지)",
    "delete": "삭제",
    "orgReplyUnavailable": "조직에 직접 답장하는 기능은 아직 없습니다. 조직에는 별도 우편함이 없습니다.",
    "autoDeleteNotice": "보관하지 않으면 이 메시지는 받은 날부터 14일 후 자동 삭제됩니다."
  },
  "ar": {
    "sentMessagesTitle": "الرسائل المرسلة",
    "noSentMail": "لا توجد رسائل مرسلة.",
    "toLabel": "إلى:",
    "archivesTitle": "الأرشيف",
    "noArchivedMail": "لا توجد رسائل مؤرشفة.",
    "fromLabel": "من:",
    "receivedMessagesTitle": "الرسائل الواردة",
    "noReceivedMail": "لا توجد رسائل واردة.",
    "unarchive": "إلغاء الأرشفة",
    "archiveKeep": "أرشفة (احتفاظ دائم)",
    "delete": "حذف",
    "orgReplyUnavailable": "الرد المباشر على منظمة غير متاح بعد — لا تمتلك المنظمات صناديق بريد خاصة بها حاليًا.",
    "autoDeleteNotice": "ستُحذف هذه الرسالة تلقائيًا بعد 14 يومًا من استلامها ما لم تُؤرشف."
  },
  "pt-BR": {
    "sentMessagesTitle": "Mensagens enviadas",
    "noSentMail": "Nenhuma mensagem enviada.",
    "toLabel": "Para:",
    "archivesTitle": "Arquivo",
    "noArchivedMail": "Nenhuma mensagem arquivada.",
    "fromLabel": "De:",
    "receivedMessagesTitle": "Mensagens recebidas",
    "noReceivedMail": "Nenhuma mensagem recebida.",
    "unarchive": "Desarquivar",
    "archiveKeep": "Arquivar (guardar indefinidamente)",
    "delete": "Excluir",
    "orgReplyUnavailable": "Ainda não é possível responder diretamente a uma organização — as organizações não possuem caixas de correio próprias.",
    "autoDeleteNotice": "Esta mensagem será excluída automaticamente 14 dias após o recebimento, a menos que seja arquivada."
  },
  "de": {
    "sentMessagesTitle": "Gesendete Nachrichten",
    "noSentMail": "Keine gesendeten Nachrichten.",
    "toLabel": "An:",
    "archivesTitle": "Archiv",
    "noArchivedMail": "Keine archivierten Nachrichten.",
    "fromLabel": "Von:",
    "receivedMessagesTitle": "Empfangene Nachrichten",
    "noReceivedMail": "Keine empfangenen Nachrichten.",
    "unarchive": "Archivierung aufheben",
    "archiveKeep": "Archivieren (dauerhaft behalten)",
    "delete": "Löschen",
    "orgReplyUnavailable": "Direkte Antworten an Organisationen sind noch nicht möglich — Organisationen haben derzeit keine eigenen Postfächer.",
    "autoDeleteNotice": "Diese Nachricht wird 14 Tage nach Empfang automatisch gelöscht, sofern sie nicht archiviert wird."
  }
};
 for(const [lang,labels] of Object.entries(mailbox)) Object.assign(words[lang],labels);
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
