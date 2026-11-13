/* États de connexion existants ; aucune décision d’authentification ici. */
(function(global){
 'use strict';
 const resources=global.RP_I18N_RESOURCES;if(!resources)return;
 const words={
  "fr": {
    "invalidEmail": "Cette adresse n'est pas valide.",
    "passwordRequired": "Saisissez votre mot de passe.",
    "unavailable": "Service momentanément indisponible.",
    "working": "Connexion…",
    "tooManyAttempts": "Trop de tentatives. Réessayez dans un instant.",
    "invalidCredentials": "Adresse ou mot de passe incorrect.",
    "noCharacter": "Connexion réussie, mais ce compte ne porte aucun personnage. Vous pouvez en créer un.",
    "characterUnavailable": "Personnage introuvable sur le serveur.",
    "welcome": "Bienvenue, {{values.name}}. Chargement…",
    "confirmationExpiredTitle": "Ce lien de confirmation n'est plus valable.",
    "confirmationExpiredBody": "Il a expiré, ou une adresse plus récente l'a remplacé. Rouvrez votre personnage sur l'appareil où vous jouez et demandez un nouveau courriel.",
    "confirmationSuccessTitle": "Votre adresse e-mail est confirmée.",
    "confirmationSuccessBody": "Votre personnage est désormais rattaché à votre compte. Connectez-vous ci-dessous avec cette adresse et votre mot de passe pour le retrouver, sur cet appareil ou sur n'importe quel autre."
  },
  "en": {
    "invalidEmail": "This address is not valid.",
    "passwordRequired": "Enter your password.",
    "unavailable": "Service temporarily unavailable.",
    "working": "Signing in…",
    "tooManyAttempts": "Too many attempts. Please try again shortly.",
    "invalidCredentials": "Incorrect email address or password.",
    "noCharacter": "You are signed in, but this account has no character. You can create one.",
    "characterUnavailable": "Character not found on the server.",
    "welcome": "Welcome, {{values.name}}. Loading…",
    "confirmationExpiredTitle": "This confirmation link is no longer valid.",
    "confirmationExpiredBody": "It has expired, or a more recent address has replaced it. Open your character again on the device you play on and request a new email.",
    "confirmationSuccessTitle": "Your email address is confirmed.",
    "confirmationSuccessBody": "Your character is now linked to your account. Sign in below with this address and your password to access your character on this device or any other."
  },
  "es": {
    "invalidEmail": "Esta dirección no es válida.",
    "passwordRequired": "Introduce tu contraseña.",
    "unavailable": "Servicio temporalmente no disponible.",
    "working": "Iniciando sesión…",
    "tooManyAttempts": "Demasiados intentos. Vuelve a intentarlo en un momento.",
    "invalidCredentials": "Dirección o contraseña incorrecta.",
    "noCharacter": "Has iniciado sesión, pero esta cuenta no tiene personaje. Puedes crear uno.",
    "characterUnavailable": "No se ha encontrado el personaje en el servidor.",
    "welcome": "Bienvenido, {{values.name}}. Cargando…",
    "confirmationExpiredTitle": "Este enlace de confirmación ya no es válido.",
    "confirmationExpiredBody": "Ha caducado o una dirección más reciente lo ha sustituido. Vuelve a abrir tu personaje en el dispositivo en el que juegas y solicita un nuevo correo.",
    "confirmationSuccessTitle": "Tu dirección de correo electrónico está confirmada.",
    "confirmationSuccessBody": "Tu personaje ya está vinculado a tu cuenta. Inicia sesión a continuación con esta dirección y tu contraseña para acceder a él desde este dispositivo o cualquier otro."
  },
  "zh-TW": {
    "invalidEmail": "這個地址無效。",
    "passwordRequired": "請輸入密碼。",
    "unavailable": "服務暫時無法使用。",
    "working": "登入中……",
    "tooManyAttempts": "嘗試次數過多，請稍後再試。",
    "invalidCredentials": "電子郵件地址或密碼不正確。",
    "noCharacter": "已成功登入，但此帳號尚無角色。你可以建立一個角色。",
    "characterUnavailable": "伺服器上找不到角色。",
    "welcome": "歡迎，{{values.name}}。載入中……",
    "confirmationExpiredTitle": "此確認連結已失效。",
    "confirmationExpiredBody": "連結已過期，或已由較新的地址取代。請在你遊玩的裝置上重新開啟角色，並要求寄送新的電子郵件。",
    "confirmationSuccessTitle": "你的電子郵件地址已確認。",
    "confirmationSuccessBody": "你的角色現已連結至你的帳號。請在下方使用此地址和密碼登入，即可在這台或任何其他裝置上存取角色。"
  },
  "ru": {
    "invalidEmail": "Этот адрес недействителен.",
    "passwordRequired": "Введите пароль.",
    "unavailable": "Служба временно недоступна.",
    "working": "Вход…",
    "tooManyAttempts": "Слишком много попыток. Повторите чуть позже.",
    "invalidCredentials": "Неверный адрес или пароль.",
    "noCharacter": "Вход выполнен, но у этой учётной записи нет персонажа. Вы можете создать его.",
    "characterUnavailable": "Персонаж не найден на сервере.",
    "welcome": "Добро пожаловать, {{values.name}}. Загрузка…",
    "confirmationExpiredTitle": "Эта ссылка для подтверждения больше недействительна.",
    "confirmationExpiredBody": "Срок её действия истёк, или её заменил более новый адрес. Снова откройте своего персонажа на устройстве, на котором играете, и запросите новое письмо.",
    "confirmationSuccessTitle": "Ваш адрес электронной почты подтверждён.",
    "confirmationSuccessBody": "Теперь ваш персонаж связан с вашей учётной записью. Войдите ниже с этим адресом и своим паролем, чтобы получить доступ к персонажу на этом или любом другом устройстве."
  },
  "ko": {
    "invalidEmail": "유효하지 않은 주소입니다.",
    "passwordRequired": "비밀번호를 입력하세요.",
    "unavailable": "서비스를 일시적으로 사용할 수 없습니다.",
    "working": "로그인 중…",
    "tooManyAttempts": "시도 횟수가 너무 많습니다. 잠시 후 다시 시도하세요.",
    "invalidCredentials": "이메일 주소 또는 비밀번호가 올바르지 않습니다.",
    "noCharacter": "로그인했지만 이 계정에는 캐릭터가 없습니다. 새로 만들 수 있습니다.",
    "characterUnavailable": "서버에서 캐릭터를 찾을 수 없습니다.",
    "welcome": "{{values.name}} 님, 환영합니다. 불러오는 중…",
    "confirmationExpiredTitle": "이 확인 링크는 더 이상 유효하지 않습니다.",
    "confirmationExpiredBody": "링크가 만료되었거나 더 최근의 주소로 대체되었습니다. 플레이하는 기기에서 캐릭터를 다시 열고 새 이메일을 요청하세요.",
    "confirmationSuccessTitle": "이메일 주소가 확인되었습니다.",
    "confirmationSuccessBody": "이제 캐릭터가 계정에 연결되었습니다. 아래에서 이 이메일 주소와 비밀번호로 로그인하면 이 기기나 다른 기기에서 캐릭터에 접속할 수 있습니다."
  },
  "ar": {
    "invalidEmail": "هذا العنوان غير صالح.",
    "passwordRequired": "أدخل كلمة المرور.",
    "unavailable": "الخدمة غير متاحة مؤقتًا.",
    "working": "جارٍ تسجيل الدخول…",
    "tooManyAttempts": "محاولات كثيرة جدًا. أعد المحاولة بعد قليل.",
    "invalidCredentials": "العنوان أو كلمة المرور غير صحيح.",
    "noCharacter": "تم تسجيل الدخول، لكن هذا الحساب لا يحتوي على شخصية. يمكنك إنشاء واحدة.",
    "characterUnavailable": "لم يُعثر على الشخصية في الخادم.",
    "welcome": "مرحبًا، {{values.name}}. جارٍ التحميل…",
    "confirmationExpiredTitle": "لم يعد رابط التأكيد هذا صالحًا.",
    "confirmationExpiredBody": "انتهت صلاحيته، أو حلّ محله عنوان أحدث. افتح شخصيتك مجددًا على الجهاز الذي تلعب عليه واطلب رسالة بريد إلكتروني جديدة.",
    "confirmationSuccessTitle": "تم تأكيد عنوان بريدك الإلكتروني.",
    "confirmationSuccessBody": "أصبحت شخصيتك الآن مرتبطة بحسابك. سجّل الدخول أدناه باستخدام هذا العنوان وكلمة مرورك للوصول إليها على هذا الجهاز أو أي جهاز آخر."
  },
  "pt-BR": {
    "invalidEmail": "Este endereço não é válido.",
    "passwordRequired": "Digite sua senha.",
    "unavailable": "Serviço temporariamente indisponível.",
    "working": "Entrando…",
    "tooManyAttempts": "Tentativas demais. Tente novamente daqui a pouco.",
    "invalidCredentials": "Endereço ou senha incorretos.",
    "noCharacter": "Você entrou, mas esta conta não tem personagem. Você pode criar um.",
    "characterUnavailable": "Personagem não encontrado no servidor.",
    "welcome": "Boas-vindas, {{values.name}}. Carregando…",
    "confirmationExpiredTitle": "Este link de confirmação não é mais válido.",
    "confirmationExpiredBody": "Ele expirou ou foi substituído por um endereço mais recente. Abra seu personagem novamente no aparelho em que você joga e solicite um novo e-mail.",
    "confirmationSuccessTitle": "Seu endereço de e-mail está confirmado.",
    "confirmationSuccessBody": "Seu personagem agora está vinculado à sua conta. Entre abaixo com esse endereço e sua senha para acessá-lo neste aparelho ou em qualquer outro."
  },
  "de": {
    "invalidEmail": "Diese Adresse ist ungültig.",
    "passwordRequired": "Gib dein Passwort ein.",
    "unavailable": "Dienst vorübergehend nicht verfügbar.",
    "working": "Anmeldung läuft…",
    "tooManyAttempts": "Zu viele Versuche. Versuche es gleich noch einmal.",
    "invalidCredentials": "Adresse oder Passwort falsch.",
    "noCharacter": "Du bist angemeldet, aber dieses Konto hat keinen Charakter. Du kannst einen erstellen.",
    "characterUnavailable": "Charakter auf dem Server nicht gefunden.",
    "welcome": "Willkommen, {{values.name}}. Wird geladen…",
    "confirmationExpiredTitle": "Dieser Bestätigungslink ist nicht mehr gültig.",
    "confirmationExpiredBody": "Er ist abgelaufen oder wurde durch eine neuere Adresse ersetzt. Öffne deinen Charakter erneut auf dem Gerät, auf dem du spielst, und fordere eine neue E-Mail an.",
    "confirmationSuccessTitle": "Deine E-Mail-Adresse ist bestätigt.",
    "confirmationSuccessBody": "Dein Charakter ist jetzt mit deinem Konto verknüpft. Melde dich unten mit dieser Adresse und deinem Passwort an, um auf diesem oder jedem anderen Gerät auf ihn zuzugreifen."
  }
};
 for(const [locale,strings]of Object.entries(words))
  if(resources[locale]?.translation)resources[locale].translation.connectionUi={...strings};
})(window);
