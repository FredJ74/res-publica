// PAVILLON DES AMBASSADEURS ET RÉSIDENCE IMPÉRIALE (Novomirsk) : standard de l'agence internationale Roxane Velours,
// service d'étage et dossiers confidentiels du ministre de l'Intérieur (décisions de Fred, 12/11/2026,
// GAME-DESIGN-NOVOMIRSK.md). Le serveur lit la demande, choisit les escorts, encaisse, pose la trace, sert les plats
// et tient les dossiers ; l'écran n'affiche que ses réponses.
const ESC_TEXTES = {
  fr: {
    tStandard: 'Agence internationale Roxane Velours', rebecca: 'Rebecca', vous: 'Vous',
    accueil: 'Bonsoir, agence internationale Roxane Velours à l’appareil, Rebecca pour vous servir. Que puis-je pour vous ?',
    placeholder: 'Votre réponse…', repondre: 'Répondre',
    confirme: 'Très bien, je vous les envoie de suite. Le coût est de {nombre} × {prix} PSK. Validez le paiement sur votre téléphone.',
    valider: 'Valider le paiement', refuser: 'Refuser le paiement',
    annule: 'Vous n’avez pas validé, ce n’est pas grave. En espérant vous satisfaire une prochaine fois. Passez une bonne soirée.',
    fermer: 'Raccrocher',
    reformuler: 'Pardon ? Dites-moi simplement combien de personnes, et si vous préférez une escort, un escort, ou les deux.',
    complet: 'Je suis navrée, toutes nos personnes disponibles sont déjà auprès de vous ce soir.',
    tArrivee: 'On frappe à la porte', arrivee: '{noms} vous rejoignent. {montant} PSK réglés, puis {prix} PSK par jour et par personne.',
    tService: 'Service d’étage — Grand Hôtel de Sovarka',
    serviceIntro: 'La carte du restaurant du Grand Hôtel, servie dans votre appartement. Service : {service} PSK par commande.',
    commander: 'Commander ({prix} + {service} PSK)', epuise: 'Épuisé', tServi: 'Servi', servi: '{plat} vous est servi ({total} PSK).',
    tDossiers: 'Dossiers confidentiels', aucunDossier: 'Aucun dossier pour l’instant.',
    typ_projet_article: 'Projet d’article', typ_secret_escort: 'Confidence d’escort', typ_dossier_pirate: 'Dossier informatique copié',
    st_nouveau: 'Nouveau', st_lu: 'Lu', st_en_attente: 'En attente', st_publie: 'Publié', parPnj: 'décision de l’administration',
    publier: 'Valider la publication', attente: 'Mettre en attente',
    tPublie: 'Publication validée', publieMsg: 'L’article paraîtra dans la prochaine édition.',
    tAttente: 'Projet en attente', attenteMsg: 'Le projet reste dans votre bureau, publiable quand vous le voudrez.',
    tRefus: 'Refusé', indispo: 'Réponse du serveur non confirmée.',
    m_reserve_au_locataire: 'Seul le locataire peut le demander, depuis son appartement.', m_fonds_insuffisants: 'Vous n’avez pas cette somme.',
    m_agence_complete: 'Toutes les personnes disponibles sont déjà auprès de vous.', m_poste_requis: 'Réservé au ministre de l’Intérieur.',
    m_deja_publie: 'Cet article est déjà publié.', m_projet_introuvable: 'Projet introuvable.', m_stock_insuffisant: 'Ce plat est épuisé.',
    m_carte_indisponible: 'La cuisine du Grand Hôtel ne répond pas.', m_produit_non_propose: 'Ce plat n’est pas à la carte.'
  },
  en: {
    tStandard: 'Roxane Velours International Agency', rebecca: 'Rebecca', vous: 'You',
    accueil: 'Good evening, Roxane Velours International Agency, Rebecca speaking. How may I help you?',
    placeholder: 'Your answer…', repondre: 'Reply',
    confirme: 'Very well, I am sending them right away. The cost is {nombre} × {prix} PSK. Please confirm the payment on your phone.',
    valider: 'Confirm payment', refuser: 'Decline payment',
    annule: 'You did not confirm, never mind. We hope to be of service another time. Have a lovely evening.',
    fermer: 'Hang up',
    reformuler: 'I beg your pardon? Just tell me how many people, and whether you would prefer a female escort, a male escort, or both.',
    complet: 'I am so sorry, all our available companions are already with you tonight.',
    tArrivee: 'A knock at the door', arrivee: '{noms} join you. {montant} PSK paid, then {prix} PSK per day per person.',
    tService: 'Room service — Grand Hotel of Sovarka',
    serviceIntro: 'The Grand Hotel restaurant menu, served in your apartment. Service: {service} PSK per order.',
    commander: 'Order ({prix} + {service} PSK)', epuise: 'Sold out', tServi: 'Served', servi: '{plat} is served ({total} PSK).',
    tDossiers: 'Confidential files', aucunDossier: 'No files yet.',
    typ_projet_article: 'Draft article', typ_secret_escort: 'Escort’s confidence', typ_dossier_pirate: 'Copied computer file',
    st_nouveau: 'New', st_lu: 'Read', st_en_attente: 'On hold', st_publie: 'Published', parPnj: 'administration’s decision',
    publier: 'Approve publication', attente: 'Put on hold',
    tPublie: 'Publication approved', publieMsg: 'The article will appear in the next edition.',
    tAttente: 'Draft on hold', attenteMsg: 'The draft stays in your office, ready to publish whenever you wish.',
    tRefus: 'Refused', indispo: 'Server reply not confirmed.',
    m_reserve_au_locataire: 'Only the tenant can ask for this, from their apartment.', m_fonds_insuffisants: 'You do not have that much money.',
    m_agence_complete: 'All available companions are already with you.', m_poste_requis: 'Reserved for the Minister of the Interior.',
    m_deja_publie: 'This article has already been published.', m_projet_introuvable: 'Draft not found.', m_stock_insuffisant: 'This dish is sold out.',
    m_carte_indisponible: 'The Grand Hotel kitchen is not answering.', m_produit_non_propose: 'This dish is not on the menu.'
  },
  es: {
    tStandard: 'Agencia internacional Roxane Velours', rebecca: 'Rebecca', vous: 'Usted',
    accueil: 'Buenas noches, agencia internacional Roxane Velours, le atiende Rebecca. ¿En qué puedo ayudarle?',
    placeholder: 'Su respuesta…', repondre: 'Responder',
    confirme: 'Muy bien, se los envío enseguida. El coste es de {nombre} × {prix} PSK. Valide el pago en su teléfono.',
    valider: 'Validar el pago', refuser: 'Rechazar el pago',
    annule: 'No ha validado, no pasa nada. Esperamos poder atenderle en otra ocasión. Que pase una buena noche.',
    fermer: 'Colgar',
    reformuler: '¿Perdón? Dígame simplemente cuántas personas, y si prefiere una escort, un escort o ambos.',
    complet: 'Lo siento mucho, todas nuestras personas disponibles ya están con usted esta noche.',
    tArrivee: 'Llaman a la puerta', arrivee: '{noms} se unen a usted. {montant} PSK pagados, y luego {prix} PSK por día y por persona.',
    tService: 'Servicio de habitaciones — Gran Hotel de Sovarka',
    serviceIntro: 'La carta del restaurante del Gran Hotel, servida en su apartamento. Servicio: {service} PSK por pedido.',
    commander: 'Pedir ({prix} + {service} PSK)', epuise: 'Agotado', tServi: 'Servido', servi: '{plat} está servido ({total} PSK).',
    tDossiers: 'Expedientes confidenciales', aucunDossier: 'Todavía no hay expedientes.',
    typ_projet_article: 'Borrador de artículo', typ_secret_escort: 'Confidencia de escort', typ_dossier_pirate: 'Archivo informático copiado',
    st_nouveau: 'Nuevo', st_lu: 'Leído', st_en_attente: 'En espera', st_publie: 'Publicado', parPnj: 'decisión de la administración',
    publier: 'Validar la publicación', attente: 'Dejar en espera',
    tPublie: 'Publicación validada', publieMsg: 'El artículo aparecerá en la próxima edición.',
    tAttente: 'Borrador en espera', attenteMsg: 'El borrador se queda en su despacho, publicable cuando quiera.',
    tRefus: 'Rechazado', indispo: 'Respuesta del servidor no confirmada.',
    m_reserve_au_locataire: 'Solo el inquilino puede pedirlo, desde su apartamento.', m_fonds_insuffisants: 'No tiene esa cantidad.',
    m_agence_complete: 'Todas las personas disponibles ya están con usted.', m_poste_requis: 'Reservado al ministro del Interior.',
    m_deja_publie: 'Este artículo ya está publicado.', m_projet_introuvable: 'Borrador no encontrado.', m_stock_insuffisant: 'Este plato está agotado.',
    m_carte_indisponible: 'La cocina del Gran Hotel no responde.', m_produit_non_propose: 'Este plato no está en la carta.'
  },
  de: {
    tStandard: 'Internationale Agentur Roxane Velours', rebecca: 'Rebecca', vous: 'Sie',
    accueil: 'Guten Abend, internationale Agentur Roxane Velours, Rebecca am Apparat. Was kann ich für Sie tun?',
    placeholder: 'Ihre Antwort…', repondre: 'Antworten',
    confirme: 'Sehr gut, ich schicke sie Ihnen sofort. Die Kosten betragen {nombre} × {prix} PSK. Bestätigen Sie die Zahlung auf Ihrem Telefon.',
    valider: 'Zahlung bestätigen', refuser: 'Zahlung ablehnen',
    annule: 'Sie haben nicht bestätigt, das macht nichts. Wir hoffen, Ihnen ein andermal dienen zu können. Einen schönen Abend noch.',
    fermer: 'Auflegen',
    reformuler: 'Wie bitte? Sagen Sie mir einfach, wie viele Personen und ob Sie eine Escort, einen Escort oder beides wünschen.',
    complet: 'Es tut mir sehr leid, alle unsere verfügbaren Personen sind heute Abend schon bei Ihnen.',
    tArrivee: 'Es klopft an der Tür', arrivee: '{noms} gesellen sich zu Ihnen. {montant} PSK bezahlt, danach {prix} PSK pro Tag und Person.',
    tService: 'Zimmerservice — Grand Hotel von Sovarka',
    serviceIntro: 'Die Karte des Grand-Hotel-Restaurants, in Ihrer Wohnung serviert. Service: {service} PSK pro Bestellung.',
    commander: 'Bestellen ({prix} + {service} PSK)', epuise: 'Ausverkauft', tServi: 'Serviert', servi: '{plat} wird Ihnen serviert ({total} PSK).',
    tDossiers: 'Vertrauliche Akten', aucunDossier: 'Noch keine Akten.',
    typ_projet_article: 'Artikelentwurf', typ_secret_escort: 'Anvertrautes an eine Escort', typ_dossier_pirate: 'Kopierte Computerdatei',
    st_nouveau: 'Neu', st_lu: 'Gelesen', st_en_attente: 'Zurückgestellt', st_publie: 'Veröffentlicht', parPnj: 'Entscheidung der Verwaltung',
    publier: 'Veröffentlichung freigeben', attente: 'Zurückstellen',
    tPublie: 'Veröffentlichung freigegeben', publieMsg: 'Der Artikel erscheint in der nächsten Ausgabe.',
    tAttente: 'Entwurf zurückgestellt', attenteMsg: 'Der Entwurf bleibt in Ihrem Büro und kann jederzeit veröffentlicht werden.',
    tRefus: 'Abgelehnt', indispo: 'Serverantwort nicht bestätigt.',
    m_reserve_au_locataire: 'Nur der Mieter kann das verlangen, aus seiner Wohnung.', m_fonds_insuffisants: 'So viel Geld haben Sie nicht.',
    m_agence_complete: 'Alle verfügbaren Personen sind bereits bei Ihnen.', m_poste_requis: 'Dem Innenminister vorbehalten.',
    m_deja_publie: 'Dieser Artikel ist bereits erschienen.', m_projet_introuvable: 'Entwurf nicht gefunden.', m_stock_insuffisant: 'Dieses Gericht ist ausverkauft.',
    m_carte_indisponible: 'Die Küche des Grand Hotels antwortet nicht.', m_produit_non_propose: 'Dieses Gericht steht nicht auf der Karte.'
  },
  ru: {
    tStandard: 'Международное агентство «Роксана Велюр»', rebecca: 'Ребекка', vous: 'Вы',
    accueil: 'Добрый вечер, международное агентство «Роксана Велюр», у телефона Ребекка. Чем могу помочь?',
    placeholder: 'Ваш ответ…', repondre: 'Ответить',
    confirme: 'Очень хорошо, сейчас же их направлю. Стоимость: {nombre} × {prix} PSK. Подтвердите оплату на своём телефоне.',
    valider: 'Подтвердить оплату', refuser: 'Отклонить оплату',
    annule: 'Вы не подтвердили — ничего страшного. Надеемся порадовать вас в другой раз. Приятного вечера.',
    fermer: 'Повесить трубку',
    reformuler: 'Простите? Просто скажите, сколько человек и кого вы предпочитаете: девушку, мужчину или обоих.',
    complet: 'Мне очень жаль, все наши свободные сотрудники уже с вами этим вечером.',
    tArrivee: 'В дверь стучат', arrivee: '{noms} присоединяются к вам. Оплачено {montant} PSK, далее {prix} PSK в день за человека.',
    tService: 'Обслуживание в номерах — Гранд-отель Соварки',
    serviceIntro: 'Меню ресторана Гранд-отеля с подачей в ваши апартаменты. Обслуживание: {service} PSK за заказ.',
    commander: 'Заказать ({prix} + {service} PSK)', epuise: 'Закончилось', tServi: 'Подано', servi: '{plat} подано ({total} PSK).',
    tDossiers: 'Секретные досье', aucunDossier: 'Досье пока нет.',
    typ_projet_article: 'Проект статьи', typ_secret_escort: 'Откровение эскорту', typ_dossier_pirate: 'Скопированный компьютерный файл',
    st_nouveau: 'Новое', st_lu: 'Прочитано', st_en_attente: 'Отложено', st_publie: 'Опубликовано', parPnj: 'решение администрации',
    publier: 'Разрешить публикацию', attente: 'Отложить',
    tPublie: 'Публикация разрешена', publieMsg: 'Статья выйдет в следующем номере.',
    tAttente: 'Проект отложен', attenteMsg: 'Проект остаётся в вашем кабинете — опубликуйте, когда захотите.',
    tRefus: 'Отказано', indispo: 'Ответ сервера не подтверждён.',
    m_reserve_au_locataire: 'Это может сделать только арендатор из своих апартаментов.', m_fonds_insuffisants: 'У вас нет такой суммы.',
    m_agence_complete: 'Все свободные сотрудники уже с вами.', m_poste_requis: 'Только для министра внутренних дел.',
    m_deja_publie: 'Эта статья уже опубликована.', m_projet_introuvable: 'Проект не найден.', m_stock_insuffisant: 'Это блюдо закончилось.',
    m_carte_indisponible: 'Кухня Гранд-отеля не отвечает.', m_produit_non_propose: 'Этого блюда нет в меню.'
  },
  ko: {
    tStandard: '록산 벨루르 국제 에이전시', rebecca: '레베카', vous: '당신',
    accueil: '안녕하세요, 록산 벨루르 국제 에이전시의 레베카입니다. 무엇을 도와드릴까요?',
    placeholder: '답변을 입력하세요…', repondre: '답하기',
    confirme: '알겠습니다, 바로 보내 드리겠습니다. 비용은 {nombre} × {prix} PSK입니다. 휴대전화에서 결제를 승인해 주세요.',
    valider: '결제 승인', refuser: '결제 거절',
    annule: '승인하지 않으셨군요, 괜찮습니다. 다음에 만족시켜 드리길 바랍니다. 좋은 저녁 보내세요.',
    fermer: '전화 끊기',
    reformuler: '네? 몇 분이 필요한지, 여성 에스코트인지 남성 에스코트인지, 아니면 둘 다인지만 말씀해 주세요.',
    complet: '정말 죄송합니다. 오늘 밤 가능한 인원은 모두 이미 손님 곁에 있습니다.',
    tArrivee: '누군가 문을 두드립니다', arrivee: '{noms}이(가) 합류합니다. {montant} PSK 결제, 이후 1인당 하루 {prix} PSK.',
    tService: '룸서비스 — 소바르카 그랜드 호텔',
    serviceIntro: '그랜드 호텔 레스토랑 메뉴를 객실로 가져다 드립니다. 서비스료: 주문당 {service} PSK.',
    commander: '주문 ({prix} + {service} PSK)', epuise: '품절', tServi: '서빙 완료', servi: '{plat}이(가) 나왔습니다 ({total} PSK).',
    tDossiers: '기밀 서류', aucunDossier: '아직 서류가 없습니다.',
    typ_projet_article: '기사 초안', typ_secret_escort: '에스코트에게 털어놓은 비밀', typ_dossier_pirate: '복사된 컴퓨터 파일',
    st_nouveau: '새 서류', st_lu: '읽음', st_en_attente: '보류', st_publie: '게재됨', parPnj: '행정부 결정',
    publier: '게재 승인', attente: '보류하기',
    tPublie: '게재 승인됨', publieMsg: '기사는 다음 호에 실립니다.',
    tAttente: '초안 보류', attenteMsg: '초안은 집무실에 남아 언제든 게재할 수 있습니다.',
    tRefus: '거부됨', indispo: '서버 응답이 확인되지 않았습니다.',
    m_reserve_au_locataire: '임차인만 자신의 아파트에서 요청할 수 있습니다.', m_fonds_insuffisants: '그만한 돈이 없습니다.',
    m_agence_complete: '가능한 인원이 모두 이미 함께 있습니다.', m_poste_requis: '내무부 장관 전용입니다.',
    m_deja_publie: '이미 게재된 기사입니다.', m_projet_introuvable: '초안을 찾을 수 없습니다.', m_stock_insuffisant: '이 요리는 품절입니다.',
    m_carte_indisponible: '그랜드 호텔 주방이 응답하지 않습니다.', m_produit_non_propose: '메뉴에 없는 요리입니다.'
  },
  ar: {
    tStandard: 'وكالة روكسان فولور الدولية', rebecca: 'ريبيكا', vous: 'أنت',
    accueil: 'مساء الخير، وكالة روكسان فولور الدولية، معك ريبيكا. كيف يمكنني مساعدتك؟',
    placeholder: 'ردّك…', repondre: 'ردّ',
    confirme: 'حسنًا جدًا، سأرسلهم إليك فورًا. التكلفة {nombre} × {prix} PSK. يرجى تأكيد الدفع على هاتفك.',
    valider: 'تأكيد الدفع', refuser: 'رفض الدفع',
    annule: 'لم تؤكد، لا بأس. نأمل أن نرضيك في مرة قادمة. أتمنى لك أمسية سعيدة.',
    fermer: 'إنهاء المكالمة',
    reformuler: 'عفوًا؟ قل لي فقط كم شخصًا، وهل تفضّل مرافقة أم مرافقًا أم كليهما.',
    complet: 'يؤسفني ذلك، جميع من لدينا من المتاحين معك بالفعل هذا المساء.',
    tArrivee: 'طرقٌ على الباب', arrivee: '{noms} ينضمون إليك. دُفع {montant} PSK، ثم {prix} PSK يوميًا لكل شخص.',
    tService: 'خدمة الغرف — فندق سوفاركا الكبير',
    serviceIntro: 'قائمة مطعم الفندق الكبير تُقدَّم في شقتك. الخدمة: {service} PSK لكل طلب.',
    commander: 'اطلب ({prix} + {service} PSK)', epuise: 'نفد', tServi: 'تم التقديم', servi: 'قُدِّم لك {plat} ({total} PSK).',
    tDossiers: 'ملفات سرية', aucunDossier: 'لا توجد ملفات بعد.',
    typ_projet_article: 'مسودة مقال', typ_secret_escort: 'سرّ بُحْ به لمرافقة', typ_dossier_pirate: 'ملف حاسوبي منسوخ',
    st_nouveau: 'جديد', st_lu: 'مقروء', st_en_attente: 'معلّق', st_publie: 'منشور', parPnj: 'قرار الإدارة',
    publier: 'الموافقة على النشر', attente: 'تعليق',
    tPublie: 'تمت الموافقة على النشر', publieMsg: 'سيظهر المقال في العدد القادم.',
    tAttente: 'المسودة معلّقة', attenteMsg: 'تبقى المسودة في مكتبك، قابلة للنشر متى شئت.',
    tRefus: 'مرفوض', indispo: 'لم يتأكد ردّ الخادم.',
    m_reserve_au_locataire: 'لا يطلب ذلك إلا المستأجر من شقته.', m_fonds_insuffisants: 'ليس لديك هذا المبلغ.',
    m_agence_complete: 'جميع المتاحين معك بالفعل.', m_poste_requis: 'مخصص لوزير الداخلية.',
    m_deja_publie: 'هذا المقال منشور بالفعل.', m_projet_introuvable: 'المسودة غير موجودة.', m_stock_insuffisant: 'نفد هذا الطبق.',
    m_carte_indisponible: 'مطبخ الفندق الكبير لا يردّ.', m_produit_non_propose: 'هذا الطبق ليس في القائمة.'
  },
  'pt-BR': {
    tStandard: 'Agência internacional Roxane Velours', rebecca: 'Rebecca', vous: 'Você',
    accueil: 'Boa noite, agência internacional Roxane Velours, aqui é a Rebecca. Em que posso ajudar?',
    placeholder: 'Sua resposta…', repondre: 'Responder',
    confirme: 'Muito bem, vou enviá-los agora mesmo. O custo é de {nombre} × {prix} PSK. Confirme o pagamento no seu telefone.',
    valider: 'Confirmar pagamento', refuser: 'Recusar pagamento',
    annule: 'Você não confirmou, não tem problema. Esperamos atendê-lo numa próxima vez. Tenha uma ótima noite.',
    fermer: 'Desligar',
    reformuler: 'Como? Diga-me apenas quantas pessoas e se prefere uma acompanhante, um acompanhante ou os dois.',
    complet: 'Sinto muito, todas as nossas pessoas disponíveis já estão com você esta noite.',
    tArrivee: 'Batem à porta', arrivee: '{noms} se juntam a você. {montant} PSK pagos, depois {prix} PSK por dia por pessoa.',
    tService: 'Serviço de quarto — Grande Hotel de Sovarka',
    serviceIntro: 'O cardápio do restaurante do Grande Hotel, servido no seu apartamento. Serviço: {service} PSK por pedido.',
    commander: 'Pedir ({prix} + {service} PSK)', epuise: 'Esgotado', tServi: 'Servido', servi: '{plat} foi servido ({total} PSK).',
    tDossiers: 'Dossiês confidenciais', aucunDossier: 'Nenhum dossiê por enquanto.',
    typ_projet_article: 'Rascunho de artigo', typ_secret_escort: 'Confidência a uma acompanhante', typ_dossier_pirate: 'Arquivo de computador copiado',
    st_nouveau: 'Novo', st_lu: 'Lido', st_en_attente: 'Em espera', st_publie: 'Publicado', parPnj: 'decisão da administração',
    publier: 'Aprovar publicação', attente: 'Deixar em espera',
    tPublie: 'Publicação aprovada', publieMsg: 'O artigo sairá na próxima edição.',
    tAttente: 'Rascunho em espera', attenteMsg: 'O rascunho fica no seu gabinete, para publicar quando quiser.',
    tRefus: 'Recusado', indispo: 'Resposta do servidor não confirmada.',
    m_reserve_au_locataire: 'Só o inquilino pode pedir, do seu apartamento.', m_fonds_insuffisants: 'Você não tem essa quantia.',
    m_agence_complete: 'Todas as pessoas disponíveis já estão com você.', m_poste_requis: 'Reservado ao ministro do Interior.',
    m_deja_publie: 'Este artigo já foi publicado.', m_projet_introuvable: 'Rascunho não encontrado.', m_stock_insuffisant: 'Este prato está esgotado.',
    m_carte_indisponible: 'A cozinha do Grande Hotel não responde.', m_produit_non_propose: 'Este prato não está no cardápio.'
  },
  'zh-TW': {
    tStandard: '羅珊・維露國際經紀公司', rebecca: '蕾貝卡', vous: '您',
    accueil: '晚安，這裡是羅珊・維露國際經紀公司，我是蕾貝卡，很高興為您服務。請問有什麼需要？',
    placeholder: '您的回答…', repondre: '回覆',
    confirme: '好的，我馬上為您安排。費用為 {nombre} × {prix} PSK。請在您的手機上確認付款。',
    valider: '確認付款', refuser: '拒絕付款',
    annule: '您沒有確認，沒關係。希望下次能為您服務。祝您有個愉快的夜晚。',
    fermer: '掛斷',
    reformuler: '抱歉？請直接告訴我需要幾位，以及您想要女伴、男伴，還是兩者都要。',
    complet: '非常抱歉，今晚我們所有可安排的人員都已在您身邊。',
    tArrivee: '有人敲門', arrivee: '{noms} 前來陪伴您。已付 {montant} PSK，之後每人每天 {prix} PSK。',
    tService: '客房服務 — 索瓦卡大飯店',
    serviceIntro: '大飯店餐廳的菜單，送到您的公寓。服務費：每筆訂單 {service} PSK。',
    commander: '點餐（{prix} + {service} PSK）', epuise: '售罄', tServi: '已上菜', servi: '{plat} 已為您送上（{total} PSK）。',
    tDossiers: '機密檔案', aucunDossier: '目前沒有檔案。',
    typ_projet_article: '文章草稿', typ_secret_escort: '向伴遊吐露的秘密', typ_dossier_pirate: '被複製的電腦檔案',
    st_nouveau: '新件', st_lu: '已讀', st_en_attente: '擱置中', st_publie: '已刊出', parPnj: '行政部門決定',
    publier: '批准刊登', attente: '暫時擱置',
    tPublie: '已批准刊登', publieMsg: '文章將刊登於下一期。',
    tAttente: '草稿已擱置', attenteMsg: '草稿留在您的辦公室，隨時可以刊登。',
    tRefus: '已拒絕', indispo: '伺服器回應未確認。',
    m_reserve_au_locataire: '只有承租人能在自己的公寓提出。', m_fonds_insuffisants: '您沒有這筆錢。',
    m_agence_complete: '所有可安排的人員都已在您身邊。', m_poste_requis: '僅限內政部長。',
    m_deja_publie: '這篇文章已經刊出。', m_projet_introuvable: '找不到草稿。', m_stock_insuffisant: '這道菜已售罄。',
    m_carte_indisponible: '大飯店的廚房沒有回應。', m_produit_non_propose: '這道菜不在菜單上。'
  }
};

let escActeEnCours = false, escDevis = null, escTexte = '';

function escT(cle, vars = {}) {
  const lang = (typeof window !== 'undefined' && window.RP_I18N_GAME_ENABLED === true && window.RPPlateauI18n?.language?.()) || 'fr';
  const modele = (ESC_TEXTES[lang] || ESC_TEXTES.fr)[cle] || ESC_TEXTES.fr[cle] || cle;
  return modele.replace(/\{(\w+)\}/g, (tout, k) => Object.hasOwn(vars, k) ? String(vars[k]) : tout);
}
const escEch = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const escJs = s => JSON.stringify(String(s)).replace(/"/g, '&quot;');
const escModal = (titre, html, rouvrir) => (typeof sovModal === 'function') ? sovModal(titre, html, rouvrir) : vehModal(titre, html);
const escFermer = () => document.getElementById('modal-postes')?.classList.remove('open');
const escMotif = v => { const k = 'm_' + (v?.raison || ''); return ESC_TEXTES.fr[k] ? escT(k) : escT('indispo'); };
const escBouton = (libelle, js, primaire) =>
  '<button class="cpj-touche' + (primaire ? ' cpj-primaire' : '') + '" style="margin:.4rem .4rem 0 0" onclick="' + js + '">' + libelle + '</button>';
const escReplique = (qui, texte) => '<p><strong style="color:#e5c477">' + escEch(qui) + ' :</strong> ' + escEch(texte) + '</p>';

// Acte idempotent : clé de requête stable par geste, oubliée après une réponse du serveur.
async function escActe(rpc, params, geste) {
  if (escActeEnCours) return null;
  escActeEnCours = true;
  const cle = 'hg-escort:' + (state.char?.name || '') + ':' + rpc + ':' + geste;
  try {
    let requete = sessionStorage.getItem(cle);
    if (!requete) { requete = crypto.randomUUID(); sessionStorage.setItem(cle, requete); }
    const v = await sbRpcVerdict(rpc, Object.assign({ p_requete: requete }, params)).catch(() => null);
    if (v && !v.transport) sessionStorage.removeItem(cle);
    if (v && v.ok === true) {
      if (typeof appliquerPaiementServeur === 'function' && (v.pa != null || v.liquide != null)) appliquerPaiementServeur({ pa: v.pa, liquide: v.liquide, arg: v.arg });
      if (typeof updateHeader === 'function') updateHeader();
    }
    return v;
  } finally { escActeEnCours = false; }
}

// ---------- LE STANDARD DE L'AGENCE ROXANE VELOURS ----------
function ouvrirStandardEscort(rejoue) {
  if (rejoue !== true) { escDevis = null; escTexte = ''; }
  escStandardSaisie(escT('accueil'));
}

function escStandardSaisie(repliqueRebecca) {
  const html = escReplique(escT('rebecca'), repliqueRebecca)
    + '<textarea id="esc-standard-reponse" class="cpj-champ" maxlength="300" rows="3" style="width:100%" placeholder="' + escEch(escT('placeholder')) + '">'
    + escEch(escTexte) + '</textarea>'
    + escBouton(escT('repondre'), 'standardEscortRepondre()', true) + escBouton(escT('fermer'), 'escFermer()', false);
  escModal(escT('tStandard'), html, () => escStandardSaisie(repliqueRebecca));
}

async function standardEscortRepondre() {
  const champ = document.getElementById('esc-standard-reponse');
  escTexte = String(champ?.value || '').trim();
  if (!escTexte) return;
  const v = await sbRpcVerdict('escort_standard_devis', { p_texte: escTexte }).catch(() => null);
  if (!v) { showToast(escT('tRefus'), escT('indispo'), false); return; }
  if (v.ok !== true) {
    if (v.raison === 'genre_imprecis' || v.raison === 'demande_incomprise') { escStandardSaisie(escT('reformuler')); return; }
    if (v.raison === 'agence_complete') { escStandardFin(escT('complet')); return; }
    showToast(escT('tRefus'), escMotif(v), false); return;
  }
  escDevis = v;
  escStandardConfirmation();
}

function escStandardConfirmation() {
  const v = escDevis;
  if (!v) return;
  const icone = (classe, js, titre, couleur) => '<button type="button" class="cpj-touche" title="' + escEch(titre) + '" aria-label="' + escEch(titre)
    + '" style="font-size:2.2rem;line-height:1;padding:.3rem .7rem;margin:.6rem .8rem 0 0;color:' + couleur + '" onclick="' + js + '"><i class="ti ' + classe + '"></i></button>';
  const html = escReplique(escT('vous'), escTexte)
    + escReplique(escT('rebecca'), escT('confirme', { nombre: Number(v.nombre) || 0, prix: Number(v.prix) || 0 }))
    + '<div>' + icone('ti-circle-check', 'standardEscortValider()', escT('valider'), '#7fc98f')
    + icone('ti-circle-x', 'standardEscortRefuser()', escT('refuser'), '#d9776f') + '</div>';
  escModal(escT('tStandard'), html, escStandardConfirmation);
}

function escStandardFin(replique) {
  escModal(escT('tStandard'), escReplique(escT('rebecca'), replique) + escBouton(escT('fermer'), 'escFermer()', true), () => escStandardFin(replique));
}

function standardEscortRefuser() {
  escDevis = null;
  escStandardFin(escT('annule'));
}

async function standardEscortValider() {
  const d = escDevis;
  if (!d) return;
  const v = await escActe('escort_standard_valider', { p_femmes: Number(d.femmes) || 0, p_hommes: Number(d.hommes) || 0 },
    (d.femmes || 0) + ':' + (d.hommes || 0) + ':' + escTexte);
  if (!v) return;
  if (v.ok !== true) {
    if (v.raison === 'agence_complete') { escStandardFin(escT('complet')); return; }
    showToast(escT('tRefus'), escMotif(v), false); return;
  }
  escDevis = null; escTexte = '';
  // Même projection que l'embauche à l'agence de Républia : employés, groupe, paie quotidienne.
  if (!v.rejeu) (v.escorts || []).forEach(e => { if (typeof escortsAgenceAdopter === 'function') escortsAgenceAdopter(e, v.agence); });
  if (typeof sauvegarderPersonnageImmediat === 'function') sauvegarderPersonnageImmediat();
  escFermer();
  if (typeof updateUI === 'function') updateUI();
  showToast(escT('tArrivee'), escT('arrivee', { noms: (v.escorts || []).map(e => e.nom).join(', '), montant: Number(v.montant) || 0,
    prix: Number((v.escorts || [])[0]?.cout_jour) || 0 }), true, true);
}

// ---------- SERVICE D'ÉTAGE ----------
async function ouvrirServiceEtage(cache) {
  const v = (cache === true && window.escCarteCache) || await sbRpcVerdict('service_etage_carte', {}).catch(() => null);
  if (!v || v.ok !== true) { showToast(escT('tService'), escMotif(v), false); return; }
  window.escCarteCache = v;
  const nom = p => (typeof nomProduitCommerce === 'function') ? nomProduitCommerce(p.produit, p.label) : p.label;
  const html = '<p>' + escT('serviceIntro', { service: Number(v.service) || 0 }) + '</p>'
    + (v.carte || []).map(p => '<div style="border-top:1px solid #394656;padding:.5rem 0"><div>' + escEch(nom(p)) + '</div>'
      + (Number(p.stock) > 0 && p.prix != null
        ? escBouton(escT('commander', { prix: Number(p.prix), service: Number(v.service) || 0 }), 'serviceEtageCommander(' + escJs(p.produit) + ')', false)
        : '<p class="cpj-note">' + escT('epuise') + '</p>') + '</div>').join('');
  escModal(escT('tService'), html, () => ouvrirServiceEtage(true));
}

async function serviceEtageCommander(produit) {
  const v = await escActe('service_etage_commander', { p_produit: produit }, produit);
  if (!v) return;
  if (v.ok !== true) { showToast(escT('tRefus'), escMotif(v), false); return; }
  if (typeof v.hp === 'number') state.hp = v.hp;
  if (typeof v.moral === 'number') state.moral = v.moral;
  if (typeof updateUI === 'function') updateUI();
  const p = (window.escCarteCache?.carte || []).find(x => x.produit === produit);
  const nom = p ? ((typeof nomProduitCommerce === 'function') ? nomProduitCommerce(p.produit, p.label) : p.label) : produit;
  showToast(escT('tServi'), escT('servi', { plat: nom, total: (Number(v.prix) || 0) + (Number(v.service) || 0) }), true);
  window.escCarteCache = null;
  await ouvrirServiceEtage();
}

// ---------- DOSSIERS CONFIDENTIELS DU MINISTRE DE L'INTÉRIEUR ----------
async function ouvrirDossiersInterieur(cache) {
  const v = (cache === true && window.escDossiersCache) || await sbRpcVerdict('interieur_dossiers_lire', {}).catch(() => null);
  if (!v || v.ok !== true) { showToast(escT('tDossiers'), escMotif(v), false); return; }
  window.escDossiersCache = v;
  const liste = v.dossiers || [];
  const html = liste.length ? liste.map(d => {
    const statut = escT('st_' + d.statut) + (d.decide_par === 'PNJ' ? ' (' + escT('parPnj') + ')' : '');
    const decidable = d.type === 'projet_article' && (d.statut === 'nouveau' || d.statut === 'en_attente');
    return '<section style="border:1px solid #394656;border-radius:8px;padding:.8rem;margin-bottom:.7rem">'
      + '<strong style="color:#e5c477">' + escT('typ_' + d.type) + '</strong> <span class="cpj-note">· ' + escEch(d.cree_le) + ' · ' + escEch(statut) + '</span>'
      + '<p><strong>' + escEch(d.titre) + '</strong></p><p style="white-space:pre-wrap">' + escEch(d.contenu) + '</p>'
      + (decidable ? escBouton(escT('publier'), 'interieurDecider(' + Number(d.id) + ',\'publier\')', true)
        + (d.statut === 'nouveau' ? escBouton(escT('attente'), 'interieurDecider(' + Number(d.id) + ',\'attente\')', false) : '') : '')
      + '</section>';
  }).join('') : '<p>' + escT('aucunDossier') + '</p>';
  escModal(escT('tDossiers'), html, () => ouvrirDossiersInterieur(true));
}

async function interieurDecider(id, action) {
  if (escActeEnCours) return;
  escActeEnCours = true;
  let v;
  try { v = await sbRpcVerdict('interieur_projet_decider', { p_id: id, p_action: action }).catch(() => null); }
  finally { escActeEnCours = false; }
  if (!v || v.ok !== true) { showToast(escT('tRefus'), escMotif(v), false); return; }
  showToast(escT(action === 'publier' ? 'tPublie' : 'tAttente'), escT(action === 'publier' ? 'publieMsg' : 'attenteMsg'), true);
  window.escDossiersCache = null;
  await ouvrirDossiersInterieur();
}

if (typeof window !== 'undefined') Object.assign(window, { ESC_TEXTES, ouvrirStandardEscort, standardEscortRepondre, standardEscortValider,
  standardEscortRefuser, escFermer, ouvrirServiceEtage, serviceEtageCommander, ouvrirDossiersInterieur, interieurDecider });
