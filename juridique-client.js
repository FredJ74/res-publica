// =====================
// JURIDIQUE-CLIENT.JS — textes juridiques, accords, compte et signalements (Fred, 28/11/2026, étape 5)
// Chargé par index.html, plateau.html et juridique.html. Tout est décidé par le serveur
// (migration 20261128130000_juridique_accords_comptes) ; l'écran affiche ce qu'il renvoie :
//  - liens vers les textes (juridique.html?texte=…&lang=…), pied de l'accueil et onglet « Informations légales » de l'Aide ;
//  - case d'acceptation à la création du personnage (juridique_accepter), avant le premier ordre ;
//  - fenêtre de ré-acceptation à la connexion (juridique_etat) et sur un refus « conditions_a_accepter » ;
//  - notification des sanctions de modération (raison, règle, contenu, durée, contestation) ;
//  - fiche du compte : « Télécharger mes données » (mes_donnees_exporter) et « Supprimer mon compte »
//    (succession existante puis compte_suppression_finaliser) ;
//  - « Signaler » un nom de personnage ou une image personnalisée (contenu_signaler).
// =====================
(function (global) {
  'use strict';
  const TEXTES = ['mentions-legales', 'cgu', 'cgv', 'confidentialite'];
  const CONTACT = 'contact@human-gambit.com';
  const T = {
    fr: { t: { 'mentions-legales': 'Mentions légales', cgu: "Conditions générales d'utilisation", cgv: 'Conditions générales de vente', confidentialite: 'Politique de confidentialité' },
      legal: 'Informations légales', foi: 'La version française fait foi.', contact: 'Contact : {c}',
      caseTexte: "J'ai lu et j'accepte les {cgu} et la {conf}, et j'ai au moins 16 ans.", cguCourt: 'CGU', confCourt: 'politique de confidentialité',
      caseRequise: 'Cochez la case pour continuer.', accordEchec: "L'accord n'a pas pu être enregistré. Réessayez.", age: 'Vous devez avoir au moins 16 ans.',
      reaccTitre: 'Conditions mises à jour', reaccTexte: 'Pour continuer à jouer, lisez et acceptez la version en vigueur des textes suivants :',
      versionDu: 'version {v} du {d}', accepter: 'Accepter et continuer', plusTard: 'Plus tard',
      plusTardNote: "Tant que vous n'avez pas accepté, vos ordres sont refusés. Depuis votre fiche, vous pouvez télécharger vos données ou supprimer votre compte.",
      sanction: 'Décision de modération', avertissement: 'Vous recevez un avertissement de la modération.', retrait_contenu: 'Un de vos contenus a été retiré par la modération.',
      suspension: 'Votre compte est suspendu par la modération : vos ordres, le forum, le courrier et le chat sont bloqués pendant la durée indiquée.', regle: 'Règle enfreinte', contenu: 'Contenu visé',
      duree: 'Durée', jours: '{n} jour(s), jusqu’au {fin}', sansDuree: 'Sans durée', raison: 'Raison', contester: 'Vous pouvez contester cette décision en écrivant à {c}.', compris: "J'ai compris",
      suspendu: 'Compte suspendu', suspenduTexte: 'Vos ordres, le forum, le courrier et le chat sont bloqués jusqu’au {fin}.',
      compte: 'Mon compte et mes données', exporter: 'Télécharger mes données', exportEnCours: 'Préparation du fichier…', exportEchec: "Le fichier n'a pas pu être préparé.",
      supprimer: 'Supprimer mon compte', supprTexte: "Action irréversible. Votre personnage ({nom}) disparaît par la succession habituelle, puis votre compte est effacé. Vos messages publics du forum restent visibles, signés « Ancien joueur ».",
      supprSansPerso: 'Action irréversible : votre compte sera effacé.', supprSaisie: 'Tapez « {mot} » pour confirmer', supprMot: 'SUPPRIMER', supprBouton: 'Supprimer définitivement',
      supprMauvais: 'La confirmation ne correspond pas.', supprEchec: "La suppression n'a pas abouti ({r}).", supprOk: 'Compte supprimé. Au revoir.', annuler: 'Annuler',
      signalerNom: 'Signaler ce nom', signalerImage: 'Signaler cette image', motif: 'Pourquoi signalez-vous ce contenu ? (motif transmis à la modération)',
      signalerOk: 'Merci : la modération examinera ce contenu.', deja: 'Vous aviez déjà signalé ce contenu.', signalerEchec: "Le signalement n'a pas pu être envoyé.", motifRequis: 'Indiquez un motif.', signalement: 'Signalement',
      chargement: 'Chargement…', introuvable: 'Texte introuvable.', versionLigne: 'Version {v} — {d}', traduction: 'Traduction : seule la version française fait foi.', lireFr: 'Lire la version française', retourJeu: 'Retour au jeu' },
    en: { t: { 'mentions-legales': 'Legal notice', cgu: 'Terms of use', cgv: 'Terms of sale', confidentialite: 'Privacy policy' },
      legal: 'Legal information', foi: 'The French version is authoritative.', contact: 'Contact: {c}',
      caseTexte: 'I have read and accept the {cgu} and the {conf}, and I am at least 16 years old.', cguCourt: 'Terms of use', confCourt: 'privacy policy',
      caseRequise: 'Tick the box to continue.', accordEchec: 'Your acceptance could not be recorded. Please try again.', age: 'You must be at least 16 years old.',
      reaccTitre: 'Updated terms', reaccTexte: 'To keep playing, read and accept the current version of the following texts:',
      versionDu: 'version {v} of {d}', accepter: 'Accept and continue', plusTard: 'Later',
      plusTardNote: 'Until you accept, your orders are refused. From your sheet, you can download your data or delete your account.',
      sanction: 'Moderation decision', avertissement: 'You have received a warning from the moderators.', retrait_contenu: 'One of your contents has been removed by the moderators.',
      suspension: 'Your account has been suspended by the moderators: your orders, forum, mail and chat are blocked for the stated period.', regle: 'Rule broken', contenu: 'Content concerned',
      duree: 'Duration', jours: '{n} day(s), until {fin}', sansDuree: 'No duration', raison: 'Reason', contester: 'You may contest this decision by writing to {c}.', compris: 'Understood',
      suspendu: 'Account suspended', suspenduTexte: 'Your orders, forum, mail and chat are blocked until {fin}.',
      compte: 'My account and my data', exporter: 'Download my data', exportEnCours: 'Preparing the file…', exportEchec: 'The file could not be prepared.',
      supprimer: 'Delete my account', supprTexte: 'This cannot be undone. Your character ({nom}) disappears through the usual succession, then your account is erased. Your public forum messages remain visible, signed “Former player”.',
      supprSansPerso: 'This cannot be undone: your account will be erased.', supprSaisie: 'Type “{mot}” to confirm', supprMot: 'DELETE', supprBouton: 'Delete permanently',
      supprMauvais: 'The confirmation does not match.', supprEchec: 'The deletion did not complete ({r}).', supprOk: 'Account deleted. Goodbye.', annuler: 'Cancel',
      signalerNom: 'Report this name', signalerImage: 'Report this image', motif: 'Why are you reporting this content? (reason sent to the moderators)',
      signalerOk: 'Thank you: the moderators will review this content.', deja: 'You had already reported this content.', signalerEchec: 'The report could not be sent.', motifRequis: 'Please give a reason.', signalement: 'Report',
      chargement: 'Loading…', introuvable: 'Text not found.', versionLigne: 'Version {v} — {d}', traduction: 'Translation: only the French version is authoritative.', lireFr: 'Read the French version', retourJeu: 'Back to the game' },
    es: { t: { 'mentions-legales': 'Aviso legal', cgu: 'Condiciones generales de uso', cgv: 'Condiciones generales de venta', confidentialite: 'Política de privacidad' },
      legal: 'Información legal', foi: 'La versión francesa es la que da fe.', contact: 'Contacto: {c}',
      caseTexte: 'He leído y acepto las {cgu} y la {conf}, y tengo al menos 16 años.', cguCourt: 'condiciones de uso', confCourt: 'política de privacidad',
      caseRequise: 'Marque la casilla para continuar.', accordEchec: 'No se pudo registrar su aceptación. Inténtelo de nuevo.', age: 'Debe tener al menos 16 años.',
      reaccTitre: 'Condiciones actualizadas', reaccTexte: 'Para seguir jugando, lea y acepte la versión vigente de los siguientes textos:',
      versionDu: 'versión {v} del {d}', accepter: 'Aceptar y continuar', plusTard: 'Más tarde',
      plusTardNote: 'Mientras no acepte, sus órdenes serán rechazadas. Desde su ficha puede descargar sus datos o eliminar su cuenta.',
      sanction: 'Decisión de moderación', avertissement: 'Ha recibido una advertencia de la moderación.', retrait_contenu: 'La moderación ha retirado uno de sus contenidos.',
      suspension: 'La moderación ha suspendido su cuenta: sus órdenes, el foro, el correo y el chat quedan bloqueados durante el periodo indicado.', regle: 'Norma infringida', contenu: 'Contenido afectado',
      duree: 'Duración', jours: '{n} día(s), hasta el {fin}', sansDuree: 'Sin duración', raison: 'Motivo', contester: 'Puede impugnar esta decisión escribiendo a {c}.', compris: 'Entendido',
      suspendu: 'Cuenta suspendida', suspenduTexte: 'Sus órdenes, el foro, el correo y el chat están bloqueados hasta el {fin}.',
      compte: 'Mi cuenta y mis datos', exporter: 'Descargar mis datos', exportEnCours: 'Preparando el archivo…', exportEchec: 'No se pudo preparar el archivo.',
      supprimer: 'Eliminar mi cuenta', supprTexte: 'Acción irreversible. Su personaje ({nom}) desaparece mediante la sucesión habitual y después se borra su cuenta. Sus mensajes públicos del foro siguen visibles, firmados «Antiguo jugador».',
      supprSansPerso: 'Acción irreversible: su cuenta será borrada.', supprSaisie: 'Escriba «{mot}» para confirmar', supprMot: 'ELIMINAR', supprBouton: 'Eliminar definitivamente',
      supprMauvais: 'La confirmación no coincide.', supprEchec: 'La eliminación no se completó ({r}).', supprOk: 'Cuenta eliminada. Adiós.', annuler: 'Cancelar',
      signalerNom: 'Denunciar este nombre', signalerImage: 'Denunciar esta imagen', motif: '¿Por qué denuncia este contenido? (motivo enviado a la moderación)',
      signalerOk: 'Gracias: la moderación examinará este contenido.', deja: 'Ya había denunciado este contenido.', signalerEchec: 'No se pudo enviar la denuncia.', motifRequis: 'Indique un motivo.', signalement: 'Denuncia',
      chargement: 'Cargando…', introuvable: 'Texto no encontrado.', versionLigne: 'Versión {v} — {d}', traduction: 'Traducción: solo la versión francesa da fe.', lireFr: 'Leer la versión francesa', retourJeu: 'Volver al juego' },
    de: { t: { 'mentions-legales': 'Impressum', cgu: 'Allgemeine Nutzungsbedingungen', cgv: 'Allgemeine Verkaufsbedingungen', confidentialite: 'Datenschutzerklärung' },
      legal: 'Rechtliche Hinweise', foi: 'Maßgeblich ist die französische Fassung.', contact: 'Kontakt: {c}',
      caseTexte: 'Ich habe die {cgu} und die {conf} gelesen und akzeptiere sie, und ich bin mindestens 16 Jahre alt.', cguCourt: 'Nutzungsbedingungen', confCourt: 'Datenschutzerklärung',
      caseRequise: 'Kreuzen Sie das Kästchen an, um fortzufahren.', accordEchec: 'Ihre Zustimmung konnte nicht gespeichert werden. Bitte erneut versuchen.', age: 'Sie müssen mindestens 16 Jahre alt sein.',
      reaccTitre: 'Aktualisierte Bedingungen', reaccTexte: 'Um weiterzuspielen, lesen und akzeptieren Sie die geltende Fassung folgender Texte:',
      versionDu: 'Fassung {v} vom {d}', accepter: 'Akzeptieren und fortfahren', plusTard: 'Später',
      plusTardNote: 'Solange Sie nicht zustimmen, werden Ihre Befehle abgelehnt. In Ihrem Profil können Sie Ihre Daten herunterladen oder Ihr Konto löschen.',
      sanction: 'Moderationsentscheidung', avertissement: 'Sie haben eine Verwarnung der Moderation erhalten.', retrait_contenu: 'Einer Ihrer Inhalte wurde von der Moderation entfernt.',
      suspension: 'Ihr Konto wurde von der Moderation gesperrt: Ihre Befehle, das Forum, die Post und der Chat sind für den angegebenen Zeitraum blockiert.', regle: 'Verletzte Regel', contenu: 'Betroffener Inhalt',
      duree: 'Dauer', jours: '{n} Tag(e), bis {fin}', sansDuree: 'Ohne Dauer', raison: 'Begründung', contester: 'Sie können diese Entscheidung anfechten, indem Sie an {c} schreiben.', compris: 'Verstanden',
      suspendu: 'Konto gesperrt', suspenduTexte: 'Ihre Befehle, das Forum, die Post und der Chat sind bis {fin} blockiert.',
      compte: 'Mein Konto und meine Daten', exporter: 'Meine Daten herunterladen', exportEnCours: 'Datei wird vorbereitet…', exportEchec: 'Die Datei konnte nicht vorbereitet werden.',
      supprimer: 'Mein Konto löschen', supprTexte: 'Nicht umkehrbar. Ihre Figur ({nom}) verschwindet über die übliche Erbfolge, danach wird Ihr Konto gelöscht. Ihre öffentlichen Forumsbeiträge bleiben sichtbar, unterzeichnet mit „Ehemaliger Spieler“.',
      supprSansPerso: 'Nicht umkehrbar: Ihr Konto wird gelöscht.', supprSaisie: 'Geben Sie „{mot}“ zur Bestätigung ein', supprMot: 'LÖSCHEN', supprBouton: 'Endgültig löschen',
      supprMauvais: 'Die Bestätigung stimmt nicht überein.', supprEchec: 'Die Löschung wurde nicht abgeschlossen ({r}).', supprOk: 'Konto gelöscht. Auf Wiedersehen.', annuler: 'Abbrechen',
      signalerNom: 'Diesen Namen melden', signalerImage: 'Dieses Bild melden', motif: 'Warum melden Sie diesen Inhalt? (Grund wird an die Moderation übermittelt)',
      signalerOk: 'Danke: Die Moderation wird diesen Inhalt prüfen.', deja: 'Sie hatten diesen Inhalt bereits gemeldet.', signalerEchec: 'Die Meldung konnte nicht gesendet werden.', motifRequis: 'Bitte geben Sie einen Grund an.', signalement: 'Meldung',
      chargement: 'Wird geladen…', introuvable: 'Text nicht gefunden.', versionLigne: 'Fassung {v} — {d}', traduction: 'Übersetzung: Maßgeblich ist nur die französische Fassung.', lireFr: 'Französische Fassung lesen', retourJeu: 'Zurück zum Spiel' },
    ru: { t: { 'mentions-legales': 'Правовая информация', cgu: 'Условия использования', cgv: 'Условия продажи', confidentialite: 'Политика конфиденциальности' },
      legal: 'Правовая информация', foi: 'Юридическую силу имеет французская версия.', contact: 'Связь: {c}',
      caseTexte: 'Я прочитал(а) и принимаю {cgu} и {conf}, и мне не меньше 16 лет.', cguCourt: 'условия использования', confCourt: 'политику конфиденциальности',
      caseRequise: 'Отметьте поле, чтобы продолжить.', accordEchec: 'Не удалось сохранить согласие. Попробуйте ещё раз.', age: 'Вам должно быть не меньше 16 лет.',
      reaccTitre: 'Условия обновлены', reaccTexte: 'Чтобы продолжить игру, прочитайте и примите действующую версию следующих текстов:',
      versionDu: 'версия {v} от {d}', accepter: 'Принять и продолжить', plusTard: 'Позже',
      plusTardNote: 'Пока вы не примете условия, ваши приказы отклоняются. В своей анкете вы можете скачать свои данные или удалить аккаунт.',
      sanction: 'Решение модерации', avertissement: 'Вы получили предупреждение от модерации.', retrait_contenu: 'Модерация удалила один из ваших материалов.',
      suspension: 'Модерация заблокировала ваш аккаунт: ваши приказы, форум, почта и чат недоступны в течение указанного срока.', regle: 'Нарушенное правило', contenu: 'Затронутый материал',
      duree: 'Срок', jours: '{n} дн., до {fin}', sansDuree: 'Без срока', raison: 'Причина', contester: 'Вы можете оспорить это решение, написав на {c}.', compris: 'Понятно',
      suspendu: 'Аккаунт заблокирован', suspenduTexte: 'Ваши приказы, форум, почта и чат заблокированы до {fin}.',
      compte: 'Мой аккаунт и мои данные', exporter: 'Скачать мои данные', exportEnCours: 'Подготовка файла…', exportEchec: 'Не удалось подготовить файл.',
      supprimer: 'Удалить мой аккаунт', supprTexte: 'Это действие необратимо. Ваш персонаж ({nom}) исчезает через обычное наследование, затем аккаунт удаляется. Ваши публичные сообщения на форуме остаются видны с подписью «Бывший игрок».',
      supprSansPerso: 'Это действие необратимо: ваш аккаунт будет удалён.', supprSaisie: 'Введите «{mot}» для подтверждения', supprMot: 'УДАЛИТЬ', supprBouton: 'Удалить навсегда',
      supprMauvais: 'Подтверждение не совпадает.', supprEchec: 'Удаление не завершено ({r}).', supprOk: 'Аккаунт удалён. До свидания.', annuler: 'Отмена',
      signalerNom: 'Пожаловаться на имя', signalerImage: 'Пожаловаться на изображение', motif: 'Почему вы жалуетесь на этот материал? (причина передаётся модерации)',
      signalerOk: 'Спасибо: модерация рассмотрит этот материал.', deja: 'Вы уже жаловались на этот материал.', signalerEchec: 'Не удалось отправить жалобу.', motifRequis: 'Укажите причину.', signalement: 'Жалоба',
      chargement: 'Загрузка…', introuvable: 'Текст не найден.', versionLigne: 'Версия {v} — {d}', traduction: 'Перевод: юридическую силу имеет только французская версия.', lireFr: 'Читать французскую версию', retourJeu: 'Вернуться в игру' },
    ko: { t: { 'mentions-legales': '법적 고지', cgu: '이용 약관', cgv: '판매 약관', confidentialite: '개인정보 처리방침' },
      legal: '법적 정보', foi: '프랑스어판이 우선합니다.', contact: '문의: {c}',
      caseTexte: '{cgu} 및 {conf}을(를) 읽고 동의하며, 만 16세 이상입니다.', cguCourt: '이용 약관', confCourt: '개인정보 처리방침',
      caseRequise: '계속하려면 확인란을 선택하세요.', accordEchec: '동의를 저장하지 못했습니다. 다시 시도하세요.', age: '만 16세 이상이어야 합니다.',
      reaccTitre: '약관이 변경되었습니다', reaccTexte: '계속 플레이하려면 다음 문서의 현행 버전을 읽고 동의하세요:',
      versionDu: '{d} 버전 {v}', accepter: '동의하고 계속하기', plusTard: '나중에',
      plusTardNote: '동의하기 전까지는 명령이 거부됩니다. 내 정보에서 데이터를 내려받거나 계정을 삭제할 수 있습니다.',
      sanction: '운영진 조치 안내', avertissement: '운영진으로부터 경고를 받았습니다.', retrait_contenu: '운영진이 회원님의 콘텐츠 하나를 삭제했습니다.',
      suspension: '운영진이 회원님의 계정을 정지했습니다. 표시된 기간 동안 명령, 포럼, 우편, 채팅을 이용할 수 없습니다.', regle: '위반한 규칙', contenu: '대상 콘텐츠',
      duree: '기간', jours: '{n}일, {fin}까지', sansDuree: '기간 없음', raison: '사유', contester: '이 결정에 이의가 있으면 {c} 으로 연락해 주세요.', compris: '확인했습니다',
      suspendu: '계정 정지', suspenduTexte: '{fin}까지 명령, 포럼, 우편, 채팅이 차단됩니다.',
      compte: '내 계정과 데이터', exporter: '내 데이터 내려받기', exportEnCours: '파일을 준비하는 중…', exportEchec: '파일을 준비하지 못했습니다.',
      supprimer: '계정 삭제', supprTexte: '되돌릴 수 없습니다. 캐릭터({nom})는 일반 상속 절차로 사라지고, 이어서 계정이 삭제됩니다. 포럼의 공개 글은 「전 플레이어」 이름으로 남습니다.',
      supprSansPerso: '되돌릴 수 없습니다. 계정이 삭제됩니다.', supprSaisie: '확인하려면 「{mot}」을(를) 입력하세요', supprMot: '삭제', supprBouton: '영구 삭제',
      supprMauvais: '확인 문구가 일치하지 않습니다.', supprEchec: '삭제가 완료되지 않았습니다({r}).', supprOk: '계정이 삭제되었습니다. 안녕히 가세요.', annuler: '취소',
      signalerNom: '이 이름 신고', signalerImage: '이 이미지 신고', motif: '이 콘텐츠를 신고하는 이유는 무엇인가요? (사유는 운영진에게 전달됩니다)',
      signalerOk: '감사합니다. 운영진이 이 콘텐츠를 검토합니다.', deja: '이미 신고한 콘텐츠입니다.', signalerEchec: '신고를 보내지 못했습니다.', motifRequis: '사유를 입력하세요.', signalement: '신고',
      chargement: '불러오는 중…', introuvable: '문서를 찾을 수 없습니다.', versionLigne: '버전 {v} — {d}', traduction: '번역본입니다. 프랑스어판만 효력이 있습니다.', lireFr: '프랑스어판 읽기', retourJeu: '게임으로 돌아가기' },
    ar: { t: { 'mentions-legales': 'إشعار قانوني', cgu: 'شروط الاستخدام العامة', cgv: 'شروط البيع العامة', confidentialite: 'سياسة الخصوصية' },
      legal: 'معلومات قانونية', foi: 'النسخة الفرنسية هي المعتمدة.', contact: 'للتواصل: {c}',
      caseTexte: 'قرأت {cgu} و{conf} وأوافق عليهما، وعمري 16 عامًا على الأقل.', cguCourt: 'شروط الاستخدام', confCourt: 'سياسة الخصوصية',
      caseRequise: 'ضع علامة في المربع للمتابعة.', accordEchec: 'تعذر تسجيل موافقتك. حاول مجددًا.', age: 'يجب أن يكون عمرك 16 عامًا على الأقل.',
      reaccTitre: 'تم تحديث الشروط', reaccTexte: 'لمواصلة اللعب، اقرأ النسخة السارية من النصوص التالية ووافق عليها:',
      versionDu: 'النسخة {v} بتاريخ {d}', accepter: 'موافقة ومتابعة', plusTard: 'لاحقًا',
      plusTardNote: 'ما دمت لم توافق، تُرفض أوامرك. يمكنك من بطاقتك تنزيل بياناتك أو حذف حسابك.',
      sanction: 'قرار من الإشراف', avertissement: 'تلقيت تحذيرًا من فريق الإشراف.', retrait_contenu: 'أزال فريق الإشراف أحد محتوياتك.',
      suspension: 'علّق فريق الإشراف حسابك: أوامرك والمنتدى والبريد والدردشة محظورة طوال المدة المذكورة.', regle: 'القاعدة المخالفة', contenu: 'المحتوى المعني',
      duree: 'المدة', jours: '{n} يوم/أيام، حتى {fin}', sansDuree: 'بلا مدة', raison: 'السبب', contester: 'يمكنك الاعتراض على هذا القرار بالكتابة إلى {c}.', compris: 'فهمت',
      suspendu: 'الحساب معلّق', suspenduTexte: 'أوامرك والمنتدى والبريد والدردشة محظورة حتى {fin}.',
      compte: 'حسابي وبياناتي', exporter: 'تنزيل بياناتي', exportEnCours: 'جارٍ تحضير الملف…', exportEchec: 'تعذر تحضير الملف.',
      supprimer: 'حذف حسابي', supprTexte: 'إجراء لا رجعة فيه. تختفي شخصيتك ({nom}) عبر الإرث المعتاد، ثم يُمحى حسابك. تبقى رسائلك العامة في المنتدى ظاهرة بتوقيع «لاعب سابق».',
      supprSansPerso: 'إجراء لا رجعة فيه: سيُمحى حسابك.', supprSaisie: 'اكتب «{mot}» للتأكيد', supprMot: 'حذف', supprBouton: 'حذف نهائي',
      supprMauvais: 'التأكيد غير مطابق.', supprEchec: 'لم يكتمل الحذف ({r}).', supprOk: 'تم حذف الحساب. وداعًا.', annuler: 'إلغاء',
      signalerNom: 'الإبلاغ عن هذا الاسم', signalerImage: 'الإبلاغ عن هذه الصورة', motif: 'لماذا تبلغ عن هذا المحتوى؟ (يُرسل السبب إلى فريق الإشراف)',
      signalerOk: 'شكرًا: سيفحص فريق الإشراف هذا المحتوى.', deja: 'سبق أن أبلغت عن هذا المحتوى.', signalerEchec: 'تعذر إرسال البلاغ.', motifRequis: 'اذكر سببًا.', signalement: 'بلاغ',
      chargement: 'جارٍ التحميل…', introuvable: 'النص غير موجود.', versionLigne: 'النسخة {v} — {d}', traduction: 'ترجمة: النسخة الفرنسية وحدها هي المعتمدة.', lireFr: 'قراءة النسخة الفرنسية', retourJeu: 'العودة إلى اللعبة' },
    'pt-BR': { t: { 'mentions-legales': 'Aviso legal', cgu: 'Termos de uso', cgv: 'Termos de venda', confidentialite: 'Política de privacidade' },
      legal: 'Informações legais', foi: 'A versão francesa é a que prevalece.', contact: 'Contato: {c}',
      caseTexte: 'Li e aceito os {cgu} e a {conf}, e tenho pelo menos 16 anos.', cguCourt: 'termos de uso', confCourt: 'política de privacidade',
      caseRequise: 'Marque a caixa para continuar.', accordEchec: 'Não foi possível registrar seu aceite. Tente novamente.', age: 'Você precisa ter pelo menos 16 anos.',
      reaccTitre: 'Termos atualizados', reaccTexte: 'Para continuar jogando, leia e aceite a versão vigente dos seguintes textos:',
      versionDu: 'versão {v} de {d}', accepter: 'Aceitar e continuar', plusTard: 'Mais tarde',
      plusTardNote: 'Enquanto você não aceitar, suas ordens serão recusadas. Na sua ficha, você pode baixar seus dados ou excluir sua conta.',
      sanction: 'Decisão da moderação', avertissement: 'Você recebeu uma advertência da moderação.', retrait_contenu: 'Um dos seus conteúdos foi removido pela moderação.',
      suspension: 'Sua conta foi suspensa pela moderação: suas ordens, o fórum, o correio e o chat ficam bloqueados durante o período indicado.', regle: 'Regra violada', contenu: 'Conteúdo em questão',
      duree: 'Duração', jours: '{n} dia(s), até {fin}', sansDuree: 'Sem duração', raison: 'Motivo', contester: 'Você pode contestar esta decisão escrevendo para {c}.', compris: 'Entendi',
      suspendu: 'Conta suspensa', suspenduTexte: 'Suas ordens, o fórum, o correio e o chat estão bloqueados até {fin}.',
      compte: 'Minha conta e meus dados', exporter: 'Baixar meus dados', exportEnCours: 'Preparando o arquivo…', exportEchec: 'Não foi possível preparar o arquivo.',
      supprimer: 'Excluir minha conta', supprTexte: 'Ação irreversível. Seu personagem ({nom}) desaparece pela sucessão habitual e, em seguida, sua conta é apagada. Suas mensagens públicas no fórum continuam visíveis, assinadas “Ex-jogador”.',
      supprSansPerso: 'Ação irreversível: sua conta será apagada.', supprSaisie: 'Digite “{mot}” para confirmar', supprMot: 'EXCLUIR', supprBouton: 'Excluir definitivamente',
      supprMauvais: 'A confirmação não confere.', supprEchec: 'A exclusão não foi concluída ({r}).', supprOk: 'Conta excluída. Até logo.', annuler: 'Cancelar',
      signalerNom: 'Denunciar este nome', signalerImage: 'Denunciar esta imagem', motif: 'Por que você está denunciando este conteúdo? (motivo enviado à moderação)',
      signalerOk: 'Obrigado: a moderação vai analisar este conteúdo.', deja: 'Você já havia denunciado este conteúdo.', signalerEchec: 'Não foi possível enviar a denúncia.', motifRequis: 'Informe um motivo.', signalement: 'Denúncia',
      chargement: 'Carregando…', introuvable: 'Texto não encontrado.', versionLigne: 'Versão {v} — {d}', traduction: 'Tradução: só a versão francesa prevalece.', lireFr: 'Ler a versão francesa', retourJeu: 'Voltar ao jogo' },
    'zh-TW': { t: { 'mentions-legales': '法律聲明', cgu: '使用條款', cgv: '銷售條款', confidentialite: '隱私權政策' },
      legal: '法律資訊', foi: '以法文版本為準。', contact: '聯絡：{c}',
      caseTexte: '我已閱讀並同意{cgu}與{conf}，且年滿 16 歲。', cguCourt: '使用條款', confCourt: '隱私權政策',
      caseRequise: '請勾選方框以繼續。', accordEchec: '無法記錄您的同意，請再試一次。', age: '您必須年滿 16 歲。',
      reaccTitre: '條款已更新', reaccTexte: '若要繼續遊戲，請閱讀並同意下列文件的現行版本：',
      versionDu: '{d} 第 {v} 版', accepter: '同意並繼續', plusTard: '稍後',
      plusTardNote: '在您同意之前，您的命令都會被拒絕。您可以在角色資料中下載資料或刪除帳號。',
      sanction: '管理決定通知', avertissement: '您已收到管理團隊的警告。', retrait_contenu: '管理團隊已移除您的一項內容。',
      suspension: '管理團隊已停權您的帳號：在所示期間內無法下達命令，也無法使用論壇、信件與聊天。', regle: '違反的規則', contenu: '相關內容',
      duree: '期間', jours: '{n} 天，至 {fin}', sansDuree: '無期限', raison: '理由', contester: '如對此決定有異議，請寫信至 {c}。', compris: '我知道了',
      suspendu: '帳號已停權', suspenduTexte: '在 {fin} 前，您無法下達命令，也無法使用論壇、信件與聊天。',
      compte: '我的帳號與資料', exporter: '下載我的資料', exportEnCours: '正在準備檔案…', exportEchec: '無法準備檔案。',
      supprimer: '刪除我的帳號', supprTexte: '此操作無法復原。您的角色（{nom}）將依一般繼承程序消失，隨後刪除您的帳號。您在論壇的公開訊息仍會保留，署名為「前玩家」。',
      supprSansPerso: '此操作無法復原：您的帳號將被刪除。', supprSaisie: '請輸入「{mot}」以確認', supprMot: '刪除', supprBouton: '永久刪除',
      supprMauvais: '確認內容不符。', supprEchec: '刪除未完成（{r}）。', supprOk: '帳號已刪除，再見。', annuler: '取消',
      signalerNom: '檢舉這個名字', signalerImage: '檢舉這張圖片', motif: '您為什麼檢舉這項內容？（理由會轉交管理團隊）',
      signalerOk: '謝謝：管理團隊將審查這項內容。', deja: '您已檢舉過這項內容。', signalerEchec: '無法送出檢舉。', motifRequis: '請填寫理由。', signalement: '檢舉',
      chargement: '載入中…', introuvable: '找不到文件。', versionLigne: '第 {v} 版 — {d}', traduction: '譯本：僅以法文版本為準。', lireFr: '閱讀法文版本', retourJeu: '返回遊戲' }
  };
  const LANGUES = Object.keys(T);

  function langue() {
    let code = null;
    try { code = global.RPPlateauI18n?.language?.() || global.i18next?.language || null; } catch (_) {}
    if (!code) { try { code = global.localStorage?.getItem('respublica_language'); } catch (_) {} }
    return LANGUES.includes(code) ? code : 'fr';
  }
  function tr(cle, vars, lg) {
    const d = T[lg || langue()] || T.fr;
    let s = d[cle] != null ? d[cle] : T.fr[cle];
    if (typeof s !== 'string') return '';
    for (const [k, v] of Object.entries(vars || {})) s = s.split('{' + k + '}').join(String(v));
    return s;
  }
  function titre(texte, lg) { return ((T[lg || langue()] || T.fr).t || T.fr.t)[texte] || texte; }
  const esc = s => String(s == null ? '' : s).replace(/[&<>"']/g, k => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[k]));
  function lien(texte, lg) { return 'juridique.html?texte=' + encodeURIComponent(texte) + '&lang=' + encodeURIComponent(lg || langue()); }
  function dateLocale(d, lg) {
    if (!d) return '';
    const x = new Date(String(d).length === 10 ? d + 'T12:00:00Z' : d);
    if (isNaN(x)) return String(d);
    try { return x.toLocaleDateString(lg || langue(), { timeZone: 'Europe/Paris' }); } catch (_) { return x.toISOString().slice(0, 10); }
  }
  function dateHeure(d, lg) {
    const x = new Date(d); if (!d || isNaN(x)) return String(d || '');
    try { return x.toLocaleString(lg || langue(), { timeZone: 'Europe/Paris', dateStyle: 'short', timeStyle: 'short' }); } catch (_) { return x.toISOString(); }
  }
  async function rpc(fn, params) {
    if (typeof global.sbRpc !== 'function') return null;
    try { const v = await global.sbRpc(fn, params || {}); return Array.isArray(v) ? v[0] : v; } catch (_) { return null; }
  }
  function toast(titreT, corps, ok) {
    if (typeof global.showToast === 'function') global.showToast(titreT, corps, !!ok);
    else global.alert(corps);
  }

  // ---- Fenêtre commune (classes de style.css) ----
  function fenetre(html, id) {
    fermer(id);
    const fond = document.createElement('div');
    fond.className = 'modal-overlay open hg-juridique-fond';
    fond.id = id || 'hg-juridique-fenetre';
    fond.style.zIndex = '100000';
    fond.innerHTML = '<div class="modal-box cpj-dialogue hg-juridique-boite" role="dialog" aria-modal="true" dir="' + (langue() === 'ar' ? 'rtl' : 'ltr') + '" style="max-width:560px;padding:1.1rem 1.2rem">' + html + '</div>';
    document.body.appendChild(fond);
    return fond;
  }
  function fermer(id) { const f = document.getElementById(id || 'hg-juridique-fenetre'); if (f) f.remove(); }

  // ---- Liens ----
  function htmlLiens(lg, separateur) {
    return TEXTES.map(t => '<a href="' + esc(lien(t, lg)) + '" target="_blank" rel="noopener">' + esc(titre(t, lg)) + '</a>').join(separateur || ' · ');
  }
  function remplirPied() {
    const el = document.getElementById('hg-pied-juridique');
    if (!el) return;
    el.innerHTML = htmlLiens() + ' · <a href="mailto:' + CONTACT + '">' + esc(CONTACT) + '</a>';
    el.setAttribute('aria-label', tr('legal'));
  }
  function htmlCaseAcceptation(id) {
    const lg = langue();
    const a = (t, court) => '<a href="' + esc(lien(t, lg)) + '" target="_blank" rel="noopener">' + esc(court) + '</a>';
    const texte = esc(tr('caseTexte')).replace('{cgu}', a('cgu', tr('cguCourt'))).replace('{conf}', a('confidentialite', tr('confCourt')));
    return '<label class="hg-juridique-case cpj-note" style="display:flex;gap:.55rem;align-items:flex-start;cursor:pointer;line-height:1.5">'
      + '<input type="checkbox" id="' + esc(id) + '" style="margin-top:.25rem;flex-shrink:0"> <span>' + texte + '</span></label>';
  }
  function remplirCaseCreation() {
    const hote = document.getElementById('hg-case-juridique');
    if (!hote) return;
    const cochee = !!document.getElementById('hg-case-juridique-input')?.checked;
    hote.innerHTML = htmlCaseAcceptation('hg-case-juridique-input');
    const c = document.getElementById('hg-case-juridique-input');
    if (c) c.checked = cochee;
  }
  // Création du personnage : vérification immédiate de la case, sans appel au serveur.
  function caseCochee() {
    const c = document.getElementById('hg-case-juridique-input');
    return { ok: !!(c && c.checked), message: tr('caseRequise') };
  }
  // Création du personnage : la case doit être cochée ; le serveur enregistre l'accord (versions en vigueur).
  async function accepterCreation() {
    const c = document.getElementById('hg-case-juridique-input');
    if (!c || !c.checked) return { ok: false, raison: 'case_non_cochee', message: tr('caseRequise') };
    if (typeof global.rpAuthAssurerSession === 'function') { try { await global.rpAuthAssurerSession(); } catch (_) {} }
    const v = await rpc('juridique_accepter', { p_langue: langue(), p_age_16: true });
    if (v && v.ok === true) return v;
    return { ok: false, raison: (v && v.raison) || 'erreur', message: v && v.raison === 'age_16_requis' ? tr('age') : tr('accordEchec') };
  }

  // ---- Ré-acceptation ----
  let enCours = false;
  function ouvrirReacceptation(textes) {
    const liste = (Array.isArray(textes) ? textes : []).filter(x => x && x.texte);
    if (!liste.length || document.getElementById('hg-juridique-reacceptation')) return;
    const lg = langue();
    let html = '<div class="modal-title">' + esc(tr('reaccTitre')) + '</div><p>' + esc(tr('reaccTexte')) + '</p><ul style="margin:.4rem 0 .8rem 1.1rem">';
    for (const x of liste) html += '<li><a href="' + esc(lien(x.texte, lg)) + '" target="_blank" rel="noopener">' + esc(titre(x.texte, lg)) + '</a> <span class="cpj-note">(' + esc(tr('versionDu', { v: x.version, d: dateLocale(x.date, lg) })) + ')</span></li>';
    html += '</ul>' + htmlCaseAcceptation('hg-reacc-case') + '<p class="cpj-note" id="hg-reacc-msg" role="alert"></p>'
      + '<div style="display:flex;gap:.6rem;flex-wrap:wrap;margin-top:.6rem"><button type="button" class="cpj-touche cpj-primaire" id="hg-reacc-ok">' + esc(tr('accepter')) + '</button>'
      + '<button type="button" class="cpj-touche" id="hg-reacc-tard">' + esc(tr('plusTard')) + '</button></div>';
    const f = fenetre(html, 'hg-juridique-reacceptation');
    f.querySelector('#hg-reacc-ok').onclick = async () => {
      const msg = f.querySelector('#hg-reacc-msg');
      if (!f.querySelector('#hg-reacc-case').checked) { msg.textContent = tr('caseRequise'); return; }
      if (enCours) return; enCours = true;
      const v = await rpc('juridique_accepter', { p_langue: langue(), p_age_16: true });
      enCours = false;
      if (v && v.ok === true) { fermer('hg-juridique-reacceptation'); return; }
      msg.textContent = v && v.raison === 'age_16_requis' ? tr('age') : tr('accordEchec');
    };
    f.querySelector('#hg-reacc-tard').onclick = () => {
      const msg = f.querySelector('#hg-reacc-msg');
      if (msg.dataset.vu === '1') { fermer('hg-juridique-reacceptation'); return; }
      msg.dataset.vu = '1'; msg.textContent = tr('plusTardNote');
    };
  }

  // ---- Sanctions ----
  function htmlSanction(s, lg) {
    const duree = s.duree_jours ? tr('jours', { n: s.duree_jours, fin: dateHeure(s.fin, lg) }, lg) : tr('sansDuree', null, lg);
    return '<p><strong>' + esc(tr(s.type, null, lg)) + '</strong></p><dl class="cpj-note" style="margin:.3rem 0">'
      + '<dt>' + esc(tr('regle', null, lg)) + '</dt><dd>' + esc(s.regle) + '</dd>'
      + '<dt>' + esc(tr('contenu', null, lg)) + '</dt><dd style="white-space:pre-wrap;max-height:8em;overflow:auto">' + esc(s.contenu || '—') + '</dd>'
      + '<dt>' + esc(tr('duree', null, lg)) + '</dt><dd>' + esc(duree) + '</dd>'
      + '<dt>' + esc(tr('raison', null, lg)) + '</dt><dd>' + esc(s.raison) + '</dd></dl>'
      + '<p>' + esc(tr('contester', { c: CONTACT }, lg)).replace(esc(CONTACT), '<a href="mailto:' + CONTACT + '">' + esc(CONTACT) + '</a>') + '</p>';
  }
  function afficherSanctions(liste) {
    const file = (Array.isArray(liste) ? liste : []).slice();
    const suivante = () => {
      const s = file.shift(); if (!s) return;
      const f = fenetre('<div class="modal-title">' + esc(tr('sanction')) + '</div>' + htmlSanction(s)
        + '<button type="button" class="cpj-touche cpj-primaire" id="hg-sanction-ok">' + esc(tr('compris')) + '</button>', 'hg-juridique-sanction');
      f.querySelector('#hg-sanction-ok').onclick = async () => { await rpc('sanction_vue', { p_id: s.id }); fermer('hg-juridique-sanction'); suivante(); };
    };
    suivante();
  }

  // Refus d'un ordre (supabase.js, point d'écoute commun) : fenêtre d'acceptation ou rappel de la suspension.
  function refus(v) {
    if (!v) return;
    if (v.raison === 'conditions_a_accepter') ouvrirReacceptation(v.textes);
    else if (v.raison === 'compte_suspendu' && v.sanction) toast(tr('suspendu'), tr('suspenduTexte', { fin: dateHeure(v.sanction.fin) }), false);
  }

  // Chargement du plateau : état juridique du compte (note aussi l'activité côté serveur).
  async function verifierConnexion() {
    const v = await rpc('juridique_etat', {});
    if (!v || v.ok !== true) return v;
    if (Array.isArray(v.sanctions_non_vues) && v.sanctions_non_vues.length) afficherSanctions(v.sanctions_non_vues);
    if (!v.exempte && Array.isArray(v.a_accepter) && v.a_accepter.length) ouvrirReacceptation(v.a_accepter);
    return v;
  }

  // ---- Onglet « Informations légales » de l'Aide ----
  function renderAide() {
    const zone = document.getElementById('rules-content'); if (!zone) return;
    document.querySelectorAll('.rules-tab').forEach(t => t.classList.toggle('active', t.dataset.section === 'juridique'));
    const lg = langue();
    zone.setAttribute('dir', lg === 'ar' ? 'rtl' : 'ltr');
    zone.innerHTML = '<section class="aide-hrp hg-juridique-aide" style="padding:1rem 1.2rem"><h2>' + esc(tr('legal')) + '</h2><ul style="line-height:2">'
      + TEXTES.map(t => '<li><a href="' + esc(lien(t, lg)) + '" target="_blank" rel="noopener">' + esc(titre(t, lg)) + '</a></li>').join('')
      + '</ul><p class="cpj-note">' + esc(tr('foi')) + '</p><p class="cpj-note">' + esc(tr('contact', { c: CONTACT })) + '</p></section>';
  }

  // ---- Fiche du compte ----
  function htmlCompte() {
    return '<div class="hg-juridique-compte">'
      + '<div class="cpj-note" style="letter-spacing:.08em;text-transform:uppercase">' + esc(tr('compte')) + '</div>'
      + '<div style="display:flex;gap:.5rem;flex-wrap:wrap;margin-top:.4rem">'
      + '<button type="button" class="cpj-touche" onclick="RPJuridique.exporter()"><i class="ti ti-download"></i> ' + esc(tr('exporter')) + '</button>'
      + '<button type="button" class="cpj-touche" onclick="RPJuridique.supprimerCompte()"><i class="ti ti-user-x"></i> ' + esc(tr('supprimer')) + '</button>'
      + '</div><div class="cpj-note" style="margin-top:.4rem">' + htmlLiens() + '</div></div>';
  }
  async function exporter() {
    toast(tr('compte'), tr('exportEnCours'), true);
    const v = await rpc('mes_donnees_exporter', {});
    if (!v || v.ok !== true) { toast(tr('compte'), tr('exportEchec'), false); return; }
    const nom = 'human-gambit-mes-donnees-' + new Date().toISOString().slice(0, 10) + '.json';
    const url = URL.createObjectURL(new Blob([JSON.stringify(v, null, 2)], { type: 'application/json' }));
    const a = document.createElement('a'); a.href = url; a.download = nom; document.body.appendChild(a); a.click();
    setTimeout(() => { URL.revokeObjectURL(url); a.remove(); }, 1000);
  }
  async function supprimerCompte() {
    const d = await rpc('compte_suppression_demander', {});
    if (!d || d.ok !== true) { toast(tr('supprimer'), tr('supprEchec', { r: (d && d.raison) || 'erreur' }), false); return; }
    const nom = d.personnage || null;
    const mot = nom || tr('supprMot');
    const f = fenetre('<div class="modal-title">' + esc(tr('supprimer')) + '</div><p>' + esc(nom ? tr('supprTexte', { nom }) : tr('supprSansPerso')) + '</p>'
      + '<input type="text" class="cpj-champ" id="hg-suppr-saisie" style="width:100%;box-sizing:border-box" placeholder="' + esc(tr('supprSaisie', { mot })) + '">'
      + '<p class="cpj-note" id="hg-suppr-msg" role="alert"></p><div style="display:flex;gap:.6rem;flex-wrap:wrap">'
      + '<button type="button" class="cpj-touche cpj-primaire" id="hg-suppr-ok">' + esc(tr('supprBouton')) + '</button>'
      + '<button type="button" class="cpj-touche" id="hg-suppr-annuler">' + esc(tr('annuler')) + '</button></div>', 'hg-juridique-suppression');
    f.querySelector('#hg-suppr-annuler').onclick = () => fermer('hg-juridique-suppression');
    f.querySelector('#hg-suppr-ok').onclick = async () => {
      const msg = f.querySelector('#hg-suppr-msg');
      if (f.querySelector('#hg-suppr-saisie').value.trim() !== mot) { msg.textContent = tr('supprMauvais'); return; }
      const bouton = f.querySelector('#hg-suppr-ok'); bouton.disabled = true;
      // Le personnage disparaît par la mécanique de succession existante (plateau-personnage.js), puis le compte est effacé.
      if (nom) {
        const r = typeof global.rpDetruirePersonnageParSuccession === 'function'
          ? await global.rpDetruirePersonnageParSuccession(nom).catch(() => ({ ok: false, raison: 'exception' }))
          : { ok: false, raison: 'succession_indisponible' };
        if (!r || r.ok !== true) { bouton.disabled = false; msg.textContent = tr('supprEchec', { r: (r && r.raison) || 'erreur' }); return; }
      }
      const v = await rpc('compte_suppression_finaliser', {});
      if (!v || v.ok !== true) { bouton.disabled = false; msg.textContent = tr('supprEchec', { r: (v && v.raison) || 'erreur' }); return; }
      try {
        for (const k of Object.keys(global.localStorage || {})) if (/^respublica_|^sb-/.test(k) && k !== 'respublica_language') global.localStorage.removeItem(k);
      } catch (_) {}
      msg.textContent = tr('supprOk');
      setTimeout(() => { global.location.href = 'index.html'; }, 1500);
    };
  }

  // ---- Signaler un nom ou une image ----
  async function signalerContenu(source, personnage, image) {
    if (!personnage && !(source === 'image' && image)) return;
    const motif = global.prompt(tr('motif'));
    if (motif === null) return;
    if (!String(motif).trim()) { toast(tr('signalement'), tr('motifRequis'), false); return; }
    const v = await rpc('contenu_signaler', { p_source: source, p_personnage: personnage, p_image: image || null, p_motif: String(motif).slice(0, 500) });
    const ok = !!(v && v.ok === true);
    toast(tr('signalement'), ok ? (v.deja ? tr('deja') : tr('signalerOk')) : tr('signalerEchec'), ok);
  }
  function htmlSignaler(personnage, image) {
    const p = esc(JSON.stringify(String(personnage || '')));
    let h = '<div class="hg-juridique-signaler" style="display:flex;gap:.4rem;justify-content:center;flex-wrap:wrap;margin-top:.5rem">'
      + '<button type="button" class="cpj-touche" onclick="RPJuridique.signalerContenu(\'nom\',' + p + ')"><i class="ti ti-flag"></i> ' + esc(tr('signalerNom')) + '</button>';
    if (image && /^(https?:\/\/|\/?images\/)/i.test(String(image))) {
      h += '<button type="button" class="cpj-touche" onclick="RPJuridique.signalerContenu(\'image\',' + p + ',' + esc(JSON.stringify(String(image))) + ')"><i class="ti ti-flag"></i> ' + esc(tr('signalerImage')) + '</button>';
    }
    return h + '</div>';
  }

  // Décor personnalisé d'un commerce ou d'un logement (pièce marquée data-commerce-decor) : bouton « Signaler cette image ».
  function suivreDecors() {
    const piece = document.getElementById('piece-image');
    if (!piece || typeof MutationObserver !== 'function') return;
    const maj = () => {
      let b = piece.querySelector('.hg-juridique-signal-decor');
      const m = /url\(["']?([^"')]+)["']?\)/.exec(piece.style.backgroundImage || '');
      if (piece.getAttribute('data-commerce-decor') !== '1' || !m) { if (b) b.remove(); return; }
      if (!b) {
        b = document.createElement('button'); b.type = 'button'; b.className = 'cpj-touche hg-juridique-signal-decor';
        b.innerHTML = '<i class="ti ti-flag"></i>';
        b.onclick = e => { e.stopPropagation(); signalerContenu('image', null, b.dataset.image); };
        piece.appendChild(b);
      }
      b.dataset.image = m[1]; b.title = tr('signalerImage'); b.setAttribute('aria-label', tr('signalerImage'));
    };
    new MutationObserver(maj).observe(piece, { attributes: true, attributeFilter: ['data-commerce-decor', 'style'] });
    maj();
  }

  global.RPJuridique = { TEXTES, LANGUES, T, langue, tr, titre, lien, htmlLiens, remplirPied, htmlCaseAcceptation, remplirCaseCreation,
    accepterCreation, caseCochee, ouvrirReacceptation, afficherSanctions, refus, verifierConnexion, renderAide, htmlCompte, exporter,
    supprimerCompte, signalerContenu, htmlSignaler, dateLocale };
  global.rpJuridiqueRefus = refus;

  function libelleOnglet() {
    const o = document.querySelector('.rules-tab[data-section="juridique"]');
    if (o) o.textContent = tr('legal');
  }
  function auChargement() {
    remplirPied(); remplirCaseCreation(); libelleOnglet(); suivreDecors();
    if (document.getElementById('vue-rules') && typeof global.sbRpc === 'function') {
      // Plateau : attendre la session, puis lire l'état juridique du compte.
      setTimeout(() => {
        const go = () => verifierConnexion().catch(() => null);
        if (typeof global.rpAuthAssurerSession === 'function') global.rpAuthAssurerSession().then(go, go); else go();
      }, 2500);
    }
  }
  if (typeof document !== 'undefined') {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', auChargement); else auChargement();
    try { global.i18next?.on?.('languageChanged', () => { remplirPied(); remplirCaseCreation(); libelleOnglet(); }); } catch (_) {}
  }
})(typeof window !== 'undefined' ? window : globalThis);
