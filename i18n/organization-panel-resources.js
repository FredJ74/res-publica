/* Onglet des organisations : présentation seule, moteur commun et références existantes. */
(function(global){
 'use strict';
 const locales=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
 const rows=[
  [
    "empty",
    "Vous n'appartenez a aucune organisation.",
    "You do not belong to any organization.",
    "No perteneces a ninguna organización.",
    "你尚未加入任何組織。",
    "Вы не состоите ни в одной организации.",
    "가입한 조직이 없습니다.",
    "أنت لا تنتمي إلى أي منظمة.",
    "Você não faz parte de nenhuma organização.",
    "Du gehörst keiner Organisation an."
  ],
  [
    "emptyHelp",
    "Louez un local et creez votre organisation depuis \"Gerer mon local\".",
    "Rent premises and create your organization via \"$t(orderVariants.local_manage)\".",
    "Alquila un local y crea tu organización desde «$t(orderVariants.local_manage)».",
    "租用場所，然後透過「$t(orderVariants.local_manage)」建立你的組織。",
    "Арендуйте помещение и создайте свою организацию через «$t(orderVariants.local_manage)».",
    "점포를 임대하고 \"$t(orderVariants.local_manage)\"에서 조직을 만드세요.",
    "استأجر مقرًا وأنشئ منظمتك من خلال «$t(orderVariants.local_manage)».",
    "Alugue um estabelecimento e crie sua organização em «$t(orderVariants.local_manage)».",
    "Miete ein Lokal und gründe deine Organisation über „$t(orderVariants.local_manage)“."
  ],
  [
    "memberCount",
    "{{values.count}} membres",
    "$t(sovarkaPartis.secMembers): {{values.count}}",
    "$t(sovarkaPartis.secMembers): {{values.count}}",
    "$t(sovarkaPartis.secMembers)：{{values.count}}",
    "$t(sovarkaPartis.secMembers): {{values.count}}",
    "$t(sovarkaPartis.secMembers): {{values.count}}",
    "$t(sovarkaPartis.secMembers): {{values.count}}",
    "$t(sovarkaPartis.secMembers): {{values.count}}",
    "$t(sovarkaPartis.secMembers): {{values.count}}"
  ],
  [
    "mail",
    "Courrier",
    "Mail",
    "Correo",
    "郵件",
    "Почта",
    "우편",
    "البريد",
    "Correio",
    "Post"
  ],
  [
    "actions",
    "Actions",
    "Actions",
    "Acciones",
    "行動",
    "Действия",
    "행동",
    "الإجراءات",
    "Ações",
    "Aktionen"
  ],
  [
    "serviceInactive",
    "Service serveur non activé",
    "Server service not activated",
    "Servicio del servidor no activado",
    "伺服器服務尚未啟用",
    "Сервис сервера не активирован",
    "서버 서비스가 활성화되지 않았습니다",
    "خدمة الخادم غير مفعّلة",
    "Serviço do servidor não ativado",
    "Serverdienst nicht aktiviert"
  ],
  [
    "equipmentUnavailable",
    "Équipements — indisponibles",
    "Equipment — unavailable",
    "Equipamiento — no disponible",
    "設備 — 暫不開放",
    "Оснащение — недоступно",
    "장비 — 이용 불가",
    "التجهيزات — غير متاحة",
    "Equipamentos — indisponíveis",
    "Ausstattung — nicht verfügbar"
  ],
  [
    "applicationCount",
    "Candidatures ({{values.count}})",
    "Applications ({{values.count}})",
    "Solicitudes ({{values.count}})",
    "申請（{{values.count}}）",
    "Заявки ({{values.count}})",
    "가입 신청 ({{values.count}})",
    "طلبات الانضمام ({{values.count}})",
    "Solicitações ({{values.count}})",
    "Bewerbungen ({{values.count}})"
  ],
  [
    "noApplications",
    "Aucune candidature",
    "No applications",
    "Ninguna solicitud",
    "沒有申請",
    "Нет заявок",
    "가입 신청 없음",
    "لا توجد طلبات انضمام",
    "Nenhuma solicitação",
    "Keine Bewerbungen"
  ],
  [
    "leave",
    "Quitter cette organisation",
    "Leave this organization",
    "Abandonar esta organización",
    "退出此組織",
    "Покинуть эту организацию",
    "이 조직 탈퇴",
    "مغادرة هذه المنظمة",
    "Sair desta organização",
    "Diese Organisation verlassen"
  ],
  [
    "electionPrefix",
    "ÉLECTION — ",
    "ELECTION — ",
    "ELECCIÓN — ",
    "選舉 — ",
    "ВЫБОРЫ — ",
    "선거 — ",
    "الانتخابات — ",
    "ELEIÇÃO — ",
    "WAHL — "
  ],
  [
    "candidaciesOpen",
    "Candidatures ouvertes",
    "Candidate nominations open",
    "Candidaturas abiertas",
    "候選人登記開放",
    "Приём кандидатур открыт",
    "후보 등록 중",
    "باب الترشح مفتوح",
    "Candidaturas abertas",
    "Kandidaturen offen"
  ],
  [
    "voteOpen",
    "Vote en cours",
    "Voting in progress",
    "Votación en curso",
    "投票進行中",
    "Идёт голосование",
    "투표 진행 중",
    "التصويت جارٍ",
    "Votação em andamento",
    "Abstimmung läuft"
  ],
  [
    "stand",
    "Se présenter",
    "Stand as a candidate",
    "Presentarse",
    "參選",
    "Выдвинуть свою кандидатуру",
    "후보로 출마",
    "الترشح",
    "Candidatar-se",
    "Kandidieren"
  ]
];
 for(const [index,lang]of locales.entries())if(global.RP_I18N_RESOURCES?.[lang]?.translation)
  global.RP_I18N_RESOURCES[lang].translation.organizationPanel=Object.fromEntries(rows.map(row=>[row[0],row[index+1]]));
})(window);
