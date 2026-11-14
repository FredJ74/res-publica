/* Paramètres des organisations : libellés seulement, moteur commun. */
(function(global){
 'use strict';
 const locales=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
 const rows=[
  [
    "title",
    "Parametres",
    "Settings",
    "Configuración",
    "設定",
    "Настройки",
    "설정",
    "الإعدادات",
    "Configurações",
    "Einstellungen"
  ],
  [
    "nameLabel",
    "NOM",
    "NAME",
    "NOMBRE",
    "名稱",
    "НАЗВАНИЕ",
    "이름",
    "الاسم",
    "NOME",
    "NAME"
  ],
  [
    "mottoLabel",
    "DEVISE",
    "MOTTO",
    "LEMA",
    "格言",
    "ДЕВИЗ",
    "표어",
    "الشعار",
    "LEMA",
    "WAHLSPRUCH"
  ],
  [
    "mottoPlaceholder",
    "Ex: La force dans l'union...",
    "E.g.: Strength in unity...",
    "Ej.: La unión hace la fuerza...",
    "例：團結就是力量...",
    "Например: Сила в единстве...",
    "예: 단결이 힘이다...",
    "مثال: القوة في الاتحاد...",
    "Ex.: A união faz a força...",
    "Z. B.: Gemeinsam sind wir stark..."
  ],
  [
    "avatarLabel",
    "AVATAR DE L'ORGANISATION",
    "ORGANIZATION AVATAR",
    "AVATAR DE LA ORGANIZACIÓN",
    "組織頭像",
    "АВАТАР ОРГАНИЗАЦИИ",
    "조직 아바타",
    "الصورة الرمزية للمنظمة",
    "AVATAR DA ORGANIZAÇÃO",
    "ORGANISATIONSAVATAR"
  ],
  [
    "previewHelp",
    "Aperçu — mis à jour à chaque changement, avant sauvegarde.",
    "Preview — updated with each change, before saving.",
    "Vista previa — se actualiza con cada cambio, antes de guardar.",
    "預覽 — 每次變更時更新，儲存前即可查看。",
    "Предпросмотр — обновляется при каждом изменении, до сохранения.",
    "미리보기 — 저장 전에 변경할 때마다 갱신됩니다.",
    "معاينة — تُحدَّث مع كل تغيير، قبل الحفظ.",
    "Prévia — atualizada a cada alteração, antes de salvar.",
    "Vorschau — wird bei jeder Änderung vor dem Speichern aktualisiert."
  ],
  [
    "imageUrl",
    "URL de l'image",
    "Image URL",
    "URL de la imagen",
    "圖片網址",
    "URL изображения",
    "이미지 URL",
    "رابط الصورة",
    "URL da imagem",
    "Bild-URL"
  ],
  [
    "or",
    "— ou —",
    "— or —",
    "— o —",
    "— 或 —",
    "— или —",
    "— 또는 —",
    "— أو —",
    "— ou —",
    "— oder —"
  ],
  [
    "importImage",
    "Importer une image depuis mon ordinateur",
    "Upload an image from my computer",
    "Subir una imagen desde mi ordenador",
    "從我的電腦上傳圖片",
    "Загрузить изображение с моего компьютера",
    "내 컴퓨터에서 이미지 업로드",
    "رفع صورة من جهازي",
    "Enviar uma imagem do meu computador",
    "Ein Bild von meinem Computer hochladen"
  ],
  [
    "imageFormats",
    "PNG (transparence supportée), JPG/JPEG ou WEBP — 2 Mo maximum.",
    "PNG (transparency supported), JPG/JPEG or WEBP — 2 MB maximum.",
    "PNG (con transparencia), JPG/JPEG o WEBP — máximo 2 MB.",
    "PNG（支援透明背景）、JPG/JPEG 或 WEBP — 最大 2 MB。",
    "PNG (с поддержкой прозрачности), JPG/JPEG или WEBP — не более 2 МБ.",
    "PNG(투명도 지원), JPG/JPEG 또는 WEBP — 최대 2 MB.",
    "PNG (يدعم الشفافية) أو JPG/JPEG أو WEBP — بحد أقصى 2 ميغابايت.",
    "PNG (com transparência), JPG/JPEG ou WEBP — máximo de 2 MB.",
    "PNG (Transparenz unterstützt), JPG/JPEG oder WEBP — maximal 2 MB."
  ],
  [
    "save",
    "Sauvegarder",
    "Save",
    "Guardar",
    "儲存",
    "Сохранить",
    "저장",
    "حفظ",
    "Salvar",
    "Speichern"
  ],
  [
    "visibility",
    "VISIBILITE",
    "VISIBILITY",
    "VISIBILIDAD",
    "可見性",
    "ВИДИМОСТЬ",
    "공개 여부",
    "الظهور",
    "VISIBILIDADE",
    "SICHTBARKEIT"
  ],
  [
    "makeSecret",
    "Rendre secrete",
    "Make secret",
    "Hacer secreta",
    "設為秘密",
    "Сделать тайной",
    "비밀로 설정",
    "جعلها سرية",
    "Tornar secreta",
    "Geheim machen"
  ],
  [
    "makeVisible",
    "Rendre visible",
    "Make visible",
    "Hacer visible",
    "設為可見",
    "Сделать видимой",
    "공개로 설정",
    "إظهارها",
    "Tornar visível",
    "Sichtbar machen"
  ],
  [
    "dissolve",
    "Dissoudre",
    "Dissolve",
    "Disolver",
    "解散",
    "Распустить",
    "해산",
    "حلّ المنظمة",
    "Dissolver",
    "Auflösen"
  ]
];
 for(const [index,lang]of locales.entries())if(global.RP_I18N_RESOURCES?.[lang]?.translation)
  global.RP_I18N_RESOURCES[lang].translation.organizationSettings=Object.fromEntries(rows.map(row=>[row[0],row[index+1]]));
})(window);
