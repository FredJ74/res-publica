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
    "welcome": "Bienvenue, {{values.name}}. Chargement…"
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
    "welcome": "Welcome, {{values.name}}. Loading…"
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
    "welcome": "Bienvenido, {{values.name}}. Cargando…"
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
    "welcome": "歡迎，{{values.name}}。載入中……"
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
    "welcome": "Добро пожаловать, {{values.name}}. Загрузка…"
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
    "welcome": "{{values.name}} 님, 환영합니다. 불러오는 중…"
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
    "welcome": "مرحبًا، {{values.name}}. جارٍ التحميل…"
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
    "welcome": "Boas-vindas, {{values.name}}. Carregando…"
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
    "welcome": "Willkommen, {{values.name}}. Wird geladen…"
  }
};
 for(const [locale,strings]of Object.entries(words))
  if(resources[locale]?.translation)resources[locale].translation.connectionUi={...strings};
})(window);
