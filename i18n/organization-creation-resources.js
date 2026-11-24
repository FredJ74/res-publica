/* Création d’organisation : présentation seule, moteur commun. */
(function(global){
 'use strict';
 const locales=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
 const rows=[
  [
    "createTitle",
    "🏛 Créer une Organisation",
    "🏛 Create an Organization",
    "🏛 Crear una Organización",
    "🏛 建立組織",
    "🏛 Создать организацию",
    "🏛 조직 만들기",
    "🏛 إنشاء منظمة",
    "🏛 Criar uma Organização",
    "🏛 Eine Organisation gründen"
  ],
  [
    "chooseHelp",
    "Choisissez le type d'organisation à fonder. Vous ne pouvez fonder qu'une organisation de chaque type.",
    "Choose the type of organization to found. You can only found one organization of each type.",
    "Elige el tipo de organización que quieres fundar. Solo puedes fundar una organización de cada tipo.",
    "請選擇要創立的組織類型。每種類型只能創立一個組織。",
    "Выберите тип организации, которую хотите основать. Можно основать только одну организацию каждого типа.",
    "설립할 조직 유형을 선택하세요. 각 유형의 조직은 하나씩만 설립할 수 있습니다.",
    "اختر نوع المنظمة التي تريد تأسيسها. لا يمكنك تأسيس أكثر من منظمة واحدة من كل نوع.",
    "Escolha o tipo de organização a fundar. Você só pode fundar uma organização de cada tipo.",
    "Wähle den Organisationstyp, den du gründen möchtest. Du kannst nur eine Organisation jedes Typs gründen."
  ],
  [
    "secretBadge",
    "Secrète",
    "Secret",
    "Secreta",
    "秘密",
    "Секретная",
    "비밀",
    "سرّية",
    "Secreta",
    "Geheim"
  ],
  [
    "requirementsPrefix",
    "Requis : ",
    "Required: ",
    "Requisitos: ",
    "條件：",
    "Требования: ",
    "필요 조건: ",
    "المتطلبات: ",
    "Requisitos: ",
    "Voraussetzungen: "
  ],
  [
    "noneRequirement",
    "Aucun",
    "None",
    "Ninguno",
    "無",
    "Нет",
    "없음",
    "لا شيء",
    "Nenhum",
    "Keine"
  ],
  [
    "foundPrefix",
    "Fonder : ",
    "Found: ",
    "Fundar: ",
    "創立：",
    "Основать: ",
    "설립: ",
    "تأسيس: ",
    "Fundar: ",
    "Gründen: "
  ],
  [
    "localType_criminelle",
    "Organisation Secrète",
    "Secret Organization",
    "Organización Secreta",
    "秘密組織",
    "Секретная организация",
    "비밀 조직",
    "منظمة سرّية",
    "Organização Secreta",
    "Geheime Organisation"
  ],
  [
    "localType_mediatique",
    "Organisation de presse",
    "Press organization",
    "Organización de prensa",
    "新聞組織",
    "Организация прессы",
    "신문 조직",
    "منظمة صحفية",
    "Organização de imprensa",
    "Presseorganisation"
  ],
  [
    "localType_economique",
    "Organisation commerciale",
    "Commercial organization",
    "Organización comercial",
    "商業組織",
    "Коммерческая организация",
    "상업 조직",
    "منظمة تجارية",
    "Organização comercial",
    "Handelsorganisation"
  ],
  [
    "blockingPop",
    "POP insuffisante ({{values.current}}/{{values.required}})",
    "Insufficient POP ({{values.current}}/{{values.required}})",
    "POP insuficiente ({{values.current}}/{{values.required}})",
    "POP 不足（{{values.current}}/{{values.required}}）",
    "Недостаточно POP ({{values.current}}/{{values.required}})",
    "POP 부족 ({{values.current}}/{{values.required}})",
    "POP غير كافية ({{values.current}}/{{values.required}})",
    "POP insuficiente ({{values.current}}/{{values.required}})",
    "POP unzureichend ({{values.current}}/{{values.required}})"
  ],
  [
    "blockingInf",
    "INF insuffisante ({{values.current}}/{{values.required}})",
    "Insufficient INF ({{values.current}}/{{values.required}})",
    "INF insuficiente ({{values.current}}/{{values.required}})",
    "INF 不足（{{values.current}}/{{values.required}}）",
    "Недостаточно INF ({{values.current}}/{{values.required}})",
    "INF 부족 ({{values.current}}/{{values.required}})",
    "INF غير كافية ({{values.current}}/{{values.required}})",
    "INF insuficiente ({{values.current}}/{{values.required}})",
    "INF unzureichend ({{values.current}}/{{values.required}})"
  ],
  [
    "blockingDis",
    "DIS insuffisante ({{values.current}}/{{values.required}})",
    "Insufficient DIS ({{values.current}}/{{values.required}})",
    "DIS insuficiente ({{values.current}}/{{values.required}})",
    "DIS 不足（{{values.current}}/{{values.required}}）",
    "Недостаточно DIS ({{values.current}}/{{values.required}})",
    "DIS 부족 ({{values.current}}/{{values.required}})",
    "DIS غير كافية ({{values.current}}/{{values.required}})",
    "DIS insuficiente ({{values.current}}/{{values.required}})",
    "DIS unzureichend ({{values.current}}/{{values.required}})"
  ],
  [
    "blockingFunds",
    "Fonds insuffisants ({{values.current}}/{{values.required}} {{values.currency}})",
    "Insufficient funds ({{values.current}}/{{values.required}} {{values.currency}})",
    "Fondos insuficientes ({{values.current}}/{{values.required}} {{values.currency}})",
    "資金不足（{{values.current}}/{{values.required}} {{values.currency}}）",
    "Недостаточно средств ({{values.current}}/{{values.required}} {{values.currency}})",
    "자금 부족 ({{values.current}}/{{values.required}} {{values.currency}})",
    "أموال غير كافية ({{values.current}}/{{values.required}} {{values.currency}})",
    "Fundos insuficientes ({{values.current}}/{{values.required}} {{values.currency}})",
    "Unzureichende Mittel ({{values.current}}/{{values.required}} {{values.currency}})"
  ],
  [
    "nameLabel",
    "NOM DE L'ORGANISATION",
    "ORGANIZATION NAME",
    "NOMBRE DE LA ORGANIZACIÓN",
    "組織名稱",
    "НАЗВАНИЕ ОРГАНИЗАЦИИ",
    "조직 이름",
    "اسم المنظمة",
    "NOME DA ORGANIZAÇÃO",
    "NAME DER ORGANISATION"
  ],
  [
    "namePlaceholder",
    "Ex: Loge du Grand Nord, Parti du Progrès...",
    "E.g. Loge du Grand Nord, Parti du Progrès...",
    "Ej.: Loge du Grand Nord, Parti du Progrès...",
    "例如：Loge du Grand Nord、Parti du Progrès...",
    "Напр.: Loge du Grand Nord, Parti du Progrès...",
    "예: Loge du Grand Nord, Parti du Progrès...",
    "مثال: Loge du Grand Nord، Parti du Progrès...",
    "Ex.: Loge du Grand Nord, Parti du Progrès...",
    "Z. B. Loge du Grand Nord, Parti du Progrès..."
  ],
  [
    "descriptionLabel",
    "DESCRIPTION (optionnel)",
    "DESCRIPTION (optional)",
    "DESCRIPCIÓN (opcional)",
    "說明（選填）",
    "ОПИСАНИЕ (необязательно)",
    "설명 (선택 사항)",
    "الوصف (اختياري)",
    "DESCRIÇÃO (opcional)",
    "BESCHREIBUNG (optional)"
  ],
  [
    "descriptionPlaceholder",
    "Décrivez votre organisation en quelques mots...",
    "Describe your organization in a few words...",
    "Describe tu organización en pocas palabras...",
    "請用簡短文字描述你的組織...",
    "Опишите свою организацию в нескольких словах...",
    "조직을 간단히 설명하세요...",
    "صِف منظمتك ببضع كلمات...",
    "Descreva sua organização em poucas palavras...",
    "Beschreibe deine Organisation in wenigen Worten..."
  ],
  [
    "confidentiality",
    "🔒 Confidentialité automatique : chef, siège et membres resteront cachés au public. L'adhésion se fera uniquement sur invitation.",
    "🔒 Automatic confidentiality: the leader, headquarters and members will remain hidden from the public. Membership will be by invitation only.",
    "🔒 Confidencialidad automática: el líder, la sede y los miembros permanecerán ocultos al público. La adhesión será únicamente por invitación.",
    "🔒 自動保密：領袖、總部及成員將不對公眾公開。僅能受邀加入。",
    "🔒 Автоматическая конфиденциальность: руководитель, штаб-квартира и члены будут скрыты от публики. Вступить можно будет только по приглашению.",
    "🔒 자동 비공개: 대표, 본부와 구성원은 대중에게 공개되지 않습니다. 초대로만 가입할 수 있습니다.",
    "🔒 سرّية تلقائية: سيبقى القائد والمقر والأعضاء محجوبين عن الجمهور. ستكون العضوية بالدعوة فقط.",
    "🔒 Confidencialidade automática: o líder, a sede e os membros permanecerão ocultos do público. A adesão será somente por convite.",
    "🔒 Automatische Vertraulichkeit: Leitung, Sitz und Mitglieder bleiben vor der Öffentlichkeit verborgen. Der Beitritt erfolgt ausschließlich auf Einladung."
  ],
  [
    "tradeLabel",
    "CORPS DE MÉTIER REPRÉSENTÉ (optionnel)",
    "TRADE REPRESENTED (optional)",
    "SECTOR PROFESIONAL REPRESENTADO (opcional)",
    "代表的職業類別（選填）",
    "ПРЕДСТАВЛЯЕМАЯ ПРОФЕССИОНАЛЬНАЯ ГРУППА (необязательно)",
    "대표 직업군 (선택 사항)",
    "الفئة المهنية المُمثَّلة (اختياري)",
    "CATEGORIA PROFISSIONAL REPRESENTADA (opcional)",
    "VERTRETENE BERUFSGRUPPE (optional)"
  ],
  [
    "tradeGeneric",
    "Aucun (générique)",
    "None (generic)",
    "Ninguno (genérico)",
    "無（一般類型）",
    "Нет (общая)",
    "없음 (일반)",
    "لا شيء (عام)",
    "Nenhuma (genérica)",
    "Keine (allgemein)"
  ],
  [
    "tradePolice",
    "Forces de l'ordre (bloque la répression policière en cas de grève de ce syndicat)",
    "Law enforcement (blocks police repression if this union goes on strike)",
    "Fuerzas del orden (bloquea la represión policial si este sindicato se declara en huelga)",
    "執法人員（此工會罷工時，會阻止警方鎮壓）",
    "Правоохранительные органы (блокирует полицейское подавление при забастовке этого профсоюза)",
    "치안 기관 (이 노동조합이 파업하면 경찰의 진압을 차단합니다)",
    "قوات إنفاذ القانون (يمنع القمع الشرطي عند إضراب هذه النقابة)",
    "Forças da ordem (bloqueia a repressão policial em caso de greve deste sindicato)",
    "Ordnungskräfte (verhindert polizeiliche Repression bei einem Streik dieser Gewerkschaft)"
  ],
  [
    "foundButton",
    "Fonder cette organisation",
    "Found this organization",
    "Fundar esta organización",
    "創立此組織",
    "Основать эту организацию",
    "이 조직 설립하기",
    "تأسيس هذه المنظمة",
    "Fundar esta organização",
    "Diese Organisation gründen"
  ]
];
 for(const [index,lang]of locales.entries())if(global.RP_I18N_RESOURCES?.[lang]?.translation)
  global.RP_I18N_RESOURCES[lang].translation.organizationCreation=Object.fromEntries(rows.map(row=>[row[0],row[index+1]]));
 // Le sens d’un champ suit la langue choisie, jamais son premier caractère saisi.
 // Présentation uniquement : aucune reconstruction, aucun événement métier.
 function sensSaisie(){
  const langue=global.RPPlateauI18n?.language?.() || global.RPI18nPlateau?.locale?.() || 'fr';
  for(const id of ['orga-nom-input','orga-desc-input']){
   const champ=global.document?.getElementById(id);
   if(!champ)continue;
   const dir=langue==='ar'?'rtl':'ltr';
   if(champ.getAttribute('dir')!==dir)champ.setAttribute('dir',dir);
   if(champ.style.textAlign!=='start')champ.style.textAlign='start';
  }
 }
 (global.RP_I18N_CHANGE_CALLBACKS=global.RP_I18N_CHANGE_CALLBACKS || []).push(sensSaisie);
 function observerFormulaire(){
  sensSaisie();
  if(global.MutationObserver && global.document?.body)
   new global.MutationObserver(sensSaisie).observe(global.document.body,{childList:true,subtree:true});
 }
 if(global.document?.readyState==='loading')global.document.addEventListener('DOMContentLoaded',observerFormulaire,{once:true});
 else observerFormulaire();
})(window);
