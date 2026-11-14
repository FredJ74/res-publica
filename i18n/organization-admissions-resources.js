/* Demandes et invitations : présentation uniquement, moteur commun. */
(function(global){
 'use strict';
 const locales=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
 const rows=[
  [
    "requestDay",
    "Demande du Jour ",
    "Request from Day ",
    "Solicitud del día ",
    "申請日：",
    "Заявка от дня ",
    "신청일: ",
    "طلب من اليوم ",
    "Solicitação do dia ",
    "Antrag von Tag "
  ],
  [
    "invite",
    "Inviter",
    "Invite",
    "Invitar",
    "邀請",
    "Пригласить",
    "초대",
    "دعوة",
    "Convidar",
    "Einladen"
  ],
  [
    "searching",
    "Recherche des personnages...",
    "Searching for characters...",
    "Buscando personajes...",
    "正在搜尋角色...",
    "Поиск персонажей...",
    "캐릭터 검색 중...",
    "جارٍ البحث عن الشخصيات...",
    "Buscando personagens...",
    "Charaktere werden gesucht..."
  ],
  [
    "noInvitee",
    "Aucun personnage disponible à inviter.",
    "No characters available to invite.",
    "No hay personajes disponibles para invitar.",
    "沒有可邀請的角色。",
    "Нет персонажей, которых можно пригласить.",
    "초대할 수 있는 캐릭터가 없습니다.",
    "لا توجد شخصيات متاحة لدعوتها.",
    "Nenhum personagem disponível para convidar.",
    "Keine Charaktere zum Einladen verfügbar."
  ],
  [
    "privacy",
    "L'invitation est privée : seul(e) le/la destinataire en a connaissance.",
    "The invitation is private: only the recipient knows about it.",
    "La invitación es privada: solo la persona destinataria tiene conocimiento de ella.",
    "邀請是私密的：只有收件者知情。",
    "Приглашение конфиденциально: о нём знает только получатель.",
    "초대는 비공개이며 받는 사람만 알 수 있습니다.",
    "الدعوة خاصة: لا يعلم بها سوى الشخص المرسل إليه.",
    "O convite é privado: apenas a pessoa destinatária tem conhecimento dele.",
    "Die Einladung ist privat: Nur die eingeladene Person erfährt davon."
  ],
  [
    "send",
    "Envoyer l'invitation",
    "Send invitation",
    "Enviar la invitación",
    "傳送邀請",
    "Отправить приглашение",
    "초대 보내기",
    "إرسال الدعوة",
    "Enviar o convite",
    "Einladung senden"
  ]
];
 for(const [index,lang]of locales.entries())if(global.RP_I18N_RESOURCES?.[lang]?.translation)
  global.RP_I18N_RESOURCES[lang].translation.organizationAdmissions=Object.fromEntries(rows.map(row=>[row[0],row[index+1]]));
})(window);
