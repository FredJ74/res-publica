// =====================
// PLATEAU-INTERROGATOIRES.JS
// « Interroger un détenu » au QHS (commissaire) et au Renseignement (ministres), et « Indices d'interrogatoire »
// au Bureau des magistrats (juges). Décision de Fred du 27/11/2026 : modèle de l'interrogatoire du goulag. L'écran
// ne décide rien : jet, PA, indice transmis et mauvais traitement sont tranchés par le serveur
// (qhs_interroger, renseignement_interroger, interrogatoire_indices_lire, interrogatoire_indice_traiter).
// =====================
(function () {
  'use strict';

  const T = {
    fr: {
      tInterro: 'Interroger un détenu', tIndices: 'Indices d’interrogatoire', tRefus: 'Refusé', tReseau: 'Réseau',
      mReseau: 'Le serveur ne répond pas. Rien n’a été prélevé.',
      intro: 'L’interrogatoire coûte 1 PA et retire 7 PA au détenu (jamais sous 1). Chance : 50 % + 5 par point de Volonté d’écart. Il est consigné comme mauvais traitement, réussi ou non.',
      go: 'Interroger', aucun: 'Aucun détenu à interroger.',
      mSecretJuge: 'Le détenu a parlé ({p} % de chances) : un fait a été transmis au juge qui l’a condamné.',
      mSecretJuges: 'Le détenu a parlé ({p} % de chances) : le fait a été transmis aux juges, et vous en recevez une copie au courrier.',
      mRien: 'Le détenu a cédé ({p} % de chances), mais n’avait rien de nouveau à révéler.',
      mEchec: 'Le détenu n’a rien lâché ({p} % de chances).',
      introIndices: 'Faits révélés en interrogatoire. Vous en saisir ouvre une affaire à votre nom contre le détenu ; classer l’écarte.',
      saisir: 'Me saisir', classer: 'Classer', aucunIndice: 'Aucun indice.', perso: 'Pour vous seul', tous: 'Pour les juges du pays',
      saisiPar: 'Saisi par {n}', classePar: 'Classé par {n}', par: 'Interrogé par {n}',
      lgoulag: 'Goulag', lqhs: 'QHS', lrenseignement: 'Renseignement',
      mSaisi: 'Affaire ouverte : elle vous attend dans vos dossiers.', mClasse: 'Indice classé.',
      r: { autorite_insuffisante: 'Cet ordre ne relève pas de votre fonction.', pas_sur_place: 'Vous devez être dans la salle d’interrogatoire.',
        detenu_introuvable: 'Ce détenu n’est pas ici.', detenu_epuise: 'Le détenu est épuisé (1 PA ou moins).',
        pas_en_interrogatoire: 'Ce détenu n’est plus en salle d’interrogatoire.', pa_insuffisants: 'Il vous manque des PA.',
        reserve_juge: 'Réservé aux juges.', indice_introuvable: 'Cet indice ne vous est pas destiné.',
        indice_deja_traite: 'Cet indice a déjà été traité.', requete_deja_utilisee: 'Demande déjà utilisée.',
        defaut: 'Action refusée. Rien n’a été prélevé.' }
    },
    en: {
      tInterro: 'Question a detainee', tIndices: 'Interrogation leads', tRefus: 'Refused', tReseau: 'Network',
      mReseau: 'The server is not responding. Nothing was charged.',
      intro: 'Questioning costs 1 AP and takes 7 AP from the detainee (never below 1). Chance: 50% + 5 per point of Willpower difference. It is recorded as ill-treatment, whether it works or not.',
      go: 'Question', aucun: 'No detainee to question.',
      mSecretJuge: 'The detainee talked ({p}% chance): a fact was sent to the judge who sentenced them.',
      mSecretJuges: 'The detainee talked ({p}% chance): the fact was sent to the judges, and you receive a copy by mail.',
      mRien: 'The detainee gave in ({p}% chance) but had nothing new to reveal.',
      mEchec: 'The detainee gave nothing away ({p}% chance).',
      introIndices: 'Facts revealed under questioning. Taking one up opens a case in your name against the detainee; filing it sets it aside.',
      saisir: 'Take it up', classer: 'File it', aucunIndice: 'No leads.', perso: 'For you only', tous: 'For the country’s judges',
      saisiPar: 'Taken up by {n}', classePar: 'Filed by {n}', par: 'Questioned by {n}',
      lgoulag: 'Gulag', lqhs: 'High Security Wing', lrenseignement: 'Intelligence',
      mSaisi: 'Case opened: it is waiting in your files.', mClasse: 'Lead filed.',
      r: { autorite_insuffisante: 'This order is not part of your office.', pas_sur_place: 'You must be in the interrogation room.',
        detenu_introuvable: 'This detainee is not here.', detenu_epuise: 'The detainee is exhausted (1 AP or less).',
        pas_en_interrogatoire: 'This detainee is no longer in the interrogation room.', pa_insuffisants: 'You do not have enough AP.',
        reserve_juge: 'Judges only.', indice_introuvable: 'This lead is not meant for you.',
        indice_deja_traite: 'This lead has already been handled.', requete_deja_utilisee: 'Request already used.',
        defaut: 'Action refused. Nothing was charged.' }
    },
    es: {
      tInterro: 'Interrogar a un detenido', tIndices: 'Indicios de interrogatorio', tRefus: 'Rechazado', tReseau: 'Red',
      mReseau: 'El servidor no responde. No se ha cobrado nada.',
      intro: 'El interrogatorio cuesta 1 PA y quita 7 PA al detenido (nunca por debajo de 1). Probabilidad: 50 % + 5 por punto de diferencia de Voluntad. Queda registrado como malos tratos, salga bien o no.',
      go: 'Interrogar', aucun: 'Ningún detenido que interrogar.',
      mSecretJuge: 'El detenido ha hablado ({p} % de probabilidad): se ha transmitido un hecho al juez que lo condenó.',
      mSecretJuges: 'El detenido ha hablado ({p} % de probabilidad): el hecho se ha transmitido a los jueces y usted recibe una copia por correo.',
      mRien: 'El detenido ha cedido ({p} % de probabilidad), pero no tenía nada nuevo que revelar.',
      mEchec: 'El detenido no ha soltado nada ({p} % de probabilidad).',
      introIndices: 'Hechos revelados en interrogatorio. Asumirlo abre un caso a su nombre contra el detenido; archivarlo lo descarta.',
      saisir: 'Asumirlo', classer: 'Archivar', aucunIndice: 'Ningún indicio.', perso: 'Solo para usted', tous: 'Para los jueces del país',
      saisiPar: 'Asumido por {n}', classePar: 'Archivado por {n}', par: 'Interrogado por {n}',
      lgoulag: 'Gulag', lqhs: 'Alta Seguridad', lrenseignement: 'Inteligencia',
      mSaisi: 'Caso abierto: le espera en sus expedientes.', mClasse: 'Indicio archivado.',
      r: { autorite_insuffisante: 'Esta orden no corresponde a su cargo.', pas_sur_place: 'Debe estar en la sala de interrogatorios.',
        detenu_introuvable: 'Este detenido no está aquí.', detenu_epuise: 'El detenido está agotado (1 PA o menos).',
        pas_en_interrogatoire: 'Este detenido ya no está en la sala de interrogatorios.', pa_insuffisants: 'Le faltan PA.',
        reserve_juge: 'Reservado a los jueces.', indice_introuvable: 'Este indicio no es para usted.',
        indice_deja_traite: 'Este indicio ya ha sido tratado.', requete_deja_utilisee: 'Solicitud ya utilizada.',
        defaut: 'Acción rechazada. No se ha cobrado nada.' }
    },
    'zh-TW': {
      tInterro: '訊問被拘留者', tIndices: '訊問線索', tRefus: '已拒絕', tReseau: '網路',
      mReseau: '伺服器沒有回應。未扣除任何費用。',
      intro: '訊問花費 1 PA，並使被拘留者失去 7 PA（不會低於 1）。機率：50% + 每點意志差距 5%。無論成功與否，都會記錄為虐待。',
      go: '訊問', aucun: '沒有可訊問的被拘留者。',
      mSecretJuge: '被拘留者開口了（機率 {p}%）：一項事實已轉交給判決他的法官。',
      mSecretJuges: '被拘留者開口了（機率 {p}%）：該事實已轉交給法官們，你也會收到一份郵件副本。',
      mRien: '被拘留者屈服了（機率 {p}%），但沒有新的事可透露。',
      mEchec: '被拘留者什麼也沒說（機率 {p}%）。',
      introIndices: '訊問中揭露的事實。受理會以你的名義對被拘留者立案；歸檔則將其擱置。',
      saisir: '受理', classer: '歸檔', aucunIndice: '沒有線索。', perso: '僅限你本人', tous: '給本國所有法官',
      saisiPar: '由 {n} 受理', classePar: '由 {n} 歸檔', par: '由 {n} 訊問',
      lgoulag: '古拉格', lqhs: '高度戒備區', lrenseignement: '情報局',
      mSaisi: '已立案：案件在你的卷宗中等候。', mClasse: '線索已歸檔。',
      r: { autorite_insuffisante: '此命令不屬於你的職權。', pas_sur_place: '你必須在訊問室內。',
        detenu_introuvable: '此被拘留者不在這裡。', detenu_epuise: '被拘留者已筋疲力盡（1 PA 或更少）。',
        pas_en_interrogatoire: '此被拘留者已不在訊問室。', pa_insuffisants: '你的 PA 不足。',
        reserve_juge: '僅限法官。', indice_introuvable: '此線索不是給你的。',
        indice_deja_traite: '此線索已處理過。', requete_deja_utilisee: '請求已使用。',
        defaut: '操作被拒絕。未扣除任何費用。' }
    },
    ru: {
      tInterro: 'Допросить задержанного', tIndices: 'Улики с допросов', tRefus: 'Отказано', tReseau: 'Сеть',
      mReseau: 'Сервер не отвечает. Ничего не списано.',
      intro: 'Допрос стоит 1 ОД и отнимает у задержанного 7 ОД (не ниже 1). Шанс: 50 % + 5 за каждое очко разницы Воли. Он фиксируется как жестокое обращение, удачный или нет.',
      go: 'Допросить', aucun: 'Некого допрашивать.',
      mSecretJuge: 'Задержанный заговорил (шанс {p} %): факт передан судье, который его осудил.',
      mSecretJuges: 'Задержанный заговорил (шанс {p} %): факт передан судьям, а вы получаете копию по почте.',
      mRien: 'Задержанный сломался (шанс {p} %), но ничего нового не сообщил.',
      mEchec: 'Задержанный ничего не выдал (шанс {p} %).',
      introIndices: 'Факты, выявленные на допросах. Взяться за дело — значит открыть его на своё имя против задержанного; в архив — отложить.',
      saisir: 'Взяться', classer: 'В архив', aucunIndice: 'Улик нет.', perso: 'Только для вас', tous: 'Для судей страны',
      saisiPar: 'Взял {n}', classePar: 'В архиве у {n}', par: 'Допрашивал {n}',
      lgoulag: 'Гулаг', lqhs: 'Особый режим', lrenseignement: 'Разведка',
      mSaisi: 'Дело открыто: оно ждёт в ваших папках.', mClasse: 'Улика отправлена в архив.',
      r: { autorite_insuffisante: 'Этот приказ не входит в ваши полномочия.', pas_sur_place: 'Нужно находиться в допросной.',
        detenu_introuvable: 'Этого задержанного здесь нет.', detenu_epuise: 'Задержанный обессилен (1 ОД или меньше).',
        pas_en_interrogatoire: 'Этого задержанного уже нет в допросной.', pa_insuffisants: 'Не хватает ОД.',
        reserve_juge: 'Только для судей.', indice_introuvable: 'Эта улика не для вас.',
        indice_deja_traite: 'Эта улика уже рассмотрена.', requete_deja_utilisee: 'Запрос уже использован.',
        defaut: 'Действие отклонено. Ничего не списано.' }
    },
    ko: {
      tInterro: '구금자 심문', tIndices: '심문 단서', tRefus: '거부됨', tReseau: '네트워크',
      mReseau: '서버가 응답하지 않습니다. 아무것도 차감되지 않았습니다.',
      intro: '심문에는 1 PA가 들고 구금자의 PA를 7 깎습니다(1 미만으로는 내려가지 않음). 확률: 50% + 의지 차이 1점당 5%. 성공 여부와 관계없이 가혹 행위로 기록됩니다.',
      go: '심문하기', aucun: '심문할 구금자가 없습니다.',
      mSecretJuge: '구금자가 입을 열었습니다(확률 {p}%): 사실 하나가 그를 판결한 판사에게 전달되었습니다.',
      mSecretJuges: '구금자가 입을 열었습니다(확률 {p}%): 그 사실이 판사들에게 전달되었고, 당신도 우편으로 사본을 받습니다.',
      mRien: '구금자가 굴복했지만(확률 {p}%) 새로 밝힐 것이 없었습니다.',
      mEchec: '구금자가 아무것도 털어놓지 않았습니다(확률 {p}%).',
      introIndices: '심문에서 드러난 사실입니다. 맡으면 당신 이름으로 구금자에 대한 사건이 열리고, 보관하면 제외됩니다.',
      saisir: '맡기', classer: '보관', aucunIndice: '단서가 없습니다.', perso: '당신에게만', tous: '국내 판사 전원에게',
      saisiPar: '{n} 판사가 맡음', classePar: '{n} 판사가 보관함', par: '{n}이(가) 심문함',
      lgoulag: '굴라크', lqhs: '고보안 구역', lrenseignement: '정보부',
      mSaisi: '사건이 열렸습니다. 당신의 서류에서 기다리고 있습니다.', mClasse: '단서를 보관했습니다.',
      r: { autorite_insuffisante: '이 명령은 당신의 직무가 아닙니다.', pas_sur_place: '심문실에 있어야 합니다.',
        detenu_introuvable: '이 구금자는 여기 없습니다.', detenu_epuise: '구금자가 지쳐 있습니다(PA 1 이하).',
        pas_en_interrogatoire: '이 구금자는 더 이상 심문실에 없습니다.', pa_insuffisants: 'PA가 부족합니다.',
        reserve_juge: '판사 전용입니다.', indice_introuvable: '이 단서는 당신에게 온 것이 아닙니다.',
        indice_deja_traite: '이미 처리된 단서입니다.', requete_deja_utilisee: '이미 사용된 요청입니다.',
        defaut: '행동이 거부되었습니다. 아무것도 차감되지 않았습니다.' }
    },
    ar: {
      tInterro: 'استجواب محتجز', tIndices: 'قرائن الاستجواب', tRefus: 'مرفوض', tReseau: 'الشبكة',
      mReseau: 'الخادم لا يستجيب. لم يُخصم شيء.',
      intro: 'يكلّف الاستجواب نقطة عمل واحدة وينتزع 7 نقاط عمل من المحتجز (لا تقل أبدًا عن 1). الفرصة: 50٪ + 5 لكل نقطة فرق في الإرادة. يُسجَّل سوءَ معاملة، نجح أم لم ينجح.',
      go: 'استجواب', aucun: 'لا يوجد محتجز للاستجواب.',
      mSecretJuge: 'تكلّم المحتجز (فرصة {p}٪): أُحيلت واقعة إلى القاضي الذي حكم عليه.',
      mSecretJuges: 'تكلّم المحتجز (فرصة {p}٪): أُحيلت الواقعة إلى القضاة، وتصلك نسخة بالبريد.',
      mRien: 'استسلم المحتجز (فرصة {p}٪) لكن لم يكن لديه جديد يكشفه.',
      mEchec: 'لم يبح المحتجز بشيء (فرصة {p}٪).',
      introIndices: 'وقائع كُشفت أثناء الاستجواب. وضع يدك عليها يفتح قضية باسمك ضد المحتجز؛ والحفظ يستبعدها.',
      saisir: 'وضع اليد', classer: 'حفظ', aucunIndice: 'لا توجد قرائن.', perso: 'لك وحدك', tous: 'لقضاة البلاد',
      saisiPar: 'تولّاها {n}', classePar: 'حفظها {n}', par: 'استجوبه {n}',
      lgoulag: 'الغولاغ', lqhs: 'الجناح شديد الحراسة', lrenseignement: 'الاستخبارات',
      mSaisi: 'فُتحت القضية: إنها تنتظرك في ملفاتك.', mClasse: 'حُفظت القرينة.',
      r: { autorite_insuffisante: 'هذا الأمر ليس من صلاحيات منصبك.', pas_sur_place: 'يجب أن تكون في غرفة الاستجواب.',
        detenu_introuvable: 'هذا المحتجز ليس هنا.', detenu_epuise: 'المحتجز منهك (نقطة عمل واحدة أو أقل).',
        pas_en_interrogatoire: 'لم يعد هذا المحتجز في غرفة الاستجواب.', pa_insuffisants: 'تنقصك نقاط عمل.',
        reserve_juge: 'مخصص للقضاة.', indice_introuvable: 'هذه القرينة ليست موجهة إليك.',
        indice_deja_traite: 'سبق التعامل مع هذه القرينة.', requete_deja_utilisee: 'الطلب مستخدم بالفعل.',
        defaut: 'رُفض الإجراء. لم يُخصم شيء.' }
    },
    'pt-BR': {
      tInterro: 'Interrogar um detido', tIndices: 'Indícios de interrogatório', tRefus: 'Recusado', tReseau: 'Rede',
      mReseau: 'O servidor não responde. Nada foi cobrado.',
      intro: 'O interrogatório custa 1 PA e tira 7 PA do detido (nunca abaixo de 1). Chance: 50% + 5 por ponto de diferença de Vontade. É registrado como maus-tratos, dando certo ou não.',
      go: 'Interrogar', aucun: 'Nenhum detido para interrogar.',
      mSecretJuge: 'O detido falou ({p}% de chance): um fato foi enviado ao juiz que o condenou.',
      mSecretJuges: 'O detido falou ({p}% de chance): o fato foi enviado aos juízes, e você recebe uma cópia pelo correio.',
      mRien: 'O detido cedeu ({p}% de chance), mas não tinha nada de novo a revelar.',
      mEchec: 'O detido não entregou nada ({p}% de chance).',
      introIndices: 'Fatos revelados em interrogatório. Assumir abre um processo em seu nome contra o detido; arquivar o descarta.',
      saisir: 'Assumir', classer: 'Arquivar', aucunIndice: 'Nenhum indício.', perso: 'Só para você', tous: 'Para os juízes do país',
      saisiPar: 'Assumido por {n}', classePar: 'Arquivado por {n}', par: 'Interrogado por {n}',
      lgoulag: 'Gulag', lqhs: 'Alta Segurança', lrenseignement: 'Inteligência',
      mSaisi: 'Processo aberto: ele espera nos seus autos.', mClasse: 'Indício arquivado.',
      r: { autorite_insuffisante: 'Esta ordem não faz parte do seu cargo.', pas_sur_place: 'Você precisa estar na sala de interrogatório.',
        detenu_introuvable: 'Este detido não está aqui.', detenu_epuise: 'O detido está exausto (1 PA ou menos).',
        pas_en_interrogatoire: 'Este detido não está mais na sala de interrogatório.', pa_insuffisants: 'Faltam PA.',
        reserve_juge: 'Reservado aos juízes.', indice_introuvable: 'Este indício não é para você.',
        indice_deja_traite: 'Este indício já foi tratado.', requete_deja_utilisee: 'Pedido já utilizado.',
        defaut: 'Ação recusada. Nada foi cobrado.' }
    },
    de: {
      tInterro: 'Einen Gefangenen verhören', tIndices: 'Hinweise aus Verhören', tRefus: 'Abgelehnt', tReseau: 'Netzwerk',
      mReseau: 'Der Server antwortet nicht. Nichts wurde abgebucht.',
      intro: 'Das Verhör kostet 1 AP und nimmt dem Gefangenen 7 AP (nie unter 1). Chance: 50 % + 5 je Punkt Willensunterschied. Es wird als Misshandlung festgehalten, ob erfolgreich oder nicht.',
      go: 'Verhören', aucun: 'Kein Gefangener zu verhören.',
      mSecretJuge: 'Der Gefangene hat geredet ({p} % Chance): Eine Tat wurde dem Richter übermittelt, der ihn verurteilt hat.',
      mSecretJuges: 'Der Gefangene hat geredet ({p} % Chance): Die Tat wurde den Richtern übermittelt, und Sie erhalten eine Kopie per Post.',
      mRien: 'Der Gefangene ist eingeknickt ({p} % Chance), hatte aber nichts Neues zu verraten.',
      mEchec: 'Der Gefangene hat nichts preisgegeben ({p} % Chance).',
      introIndices: 'Im Verhör enthüllte Taten. Wenn Sie sich damit befassen, wird in Ihrem Namen ein Verfahren gegen den Gefangenen eröffnet; Ablegen legt den Hinweis beiseite.',
      saisir: 'Übernehmen', classer: 'Ablegen', aucunIndice: 'Keine Hinweise.', perso: 'Nur für Sie', tous: 'Für die Richter des Landes',
      saisiPar: 'Übernommen von {n}', classePar: 'Abgelegt von {n}', par: 'Verhört von {n}',
      lgoulag: 'Gulag', lqhs: 'Hochsicherheitstrakt', lrenseignement: 'Nachrichtendienst',
      mSaisi: 'Verfahren eröffnet: Es wartet in Ihren Akten.', mClasse: 'Hinweis abgelegt.',
      r: { autorite_insuffisante: 'Dieser Befehl gehört nicht zu Ihrem Amt.', pas_sur_place: 'Sie müssen im Verhörraum sein.',
        detenu_introuvable: 'Dieser Gefangene ist nicht hier.', detenu_epuise: 'Der Gefangene ist erschöpft (1 AP oder weniger).',
        pas_en_interrogatoire: 'Dieser Gefangene ist nicht mehr im Verhörraum.', pa_insuffisants: 'Ihnen fehlen AP.',
        reserve_juge: 'Nur für Richter.', indice_introuvable: 'Dieser Hinweis ist nicht für Sie bestimmt.',
        indice_deja_traite: 'Dieser Hinweis wurde bereits bearbeitet.', requete_deja_utilisee: 'Anfrage bereits verwendet.',
        defaut: 'Aktion abgelehnt. Nichts wurde abgebucht.' }
    }
  };

  function langue() {
    const brut = (typeof i18next !== 'undefined' && i18next.language) ? String(i18next.language) : 'fr';
    if (T[brut]) return brut;
    const court = brut.slice(0, 2).toLowerCase();
    if (court === 'zh') return 'zh-TW';
    if (court === 'pt') return 'pt-BR';
    return T[court] ? court : 'fr';
  }
  function t(cle, vars) {
    const l = T[langue()] || T.fr;
    let s = (l[cle] !== undefined ? l[cle] : T.fr[cle]) || cle;
    Object.keys(vars || {}).forEach(k => { s = s.split('{' + k + '}').join(String(vars[k])); });
    return s;
  }
  function motif(v) {
    const l = T[langue()] || T.fr; const r = v && v.raison;
    return (r && (l.r[r] || T.fr.r[r])) || l.r.defaut;
  }
  function echapper(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  }
  function requete() {
    if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') return crypto.randomUUID();
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, c => {
      const r = (crypto.getRandomValues(new Uint8Array(1))[0] & 15); return (c === 'x' ? r : (r & 3) | 8).toString(16);
    });
  }
  function toast(titre, msg, ok) { if (typeof showToast === 'function') showToast(titre, msg, ok); }
  async function rpc(nom, params) {
    if (typeof sbRpcVerdict !== 'function') return null;
    try { return await sbRpcVerdict(nom, params || {}); } catch (_) { return null; }
  }
  async function relire() {
    if (typeof sbLoadPersonnage === 'function') await sbLoadPersonnage().catch(() => null);
    if (typeof updateUI === 'function') updateUI();
  }
  function ouvrir(titre, corps) {
    const t1 = document.getElementById('postes-modal-title'), b = document.getElementById('postes-body'),
          m = document.getElementById('modal-postes');
    if (!t1 || !b || !m) return null;
    t1.textContent = titre;
    b.innerHTML = '<div class="cpj-dialogue interrogatoires" dir="auto">' + corps + '</div>';
    m.classList.add('open');
    return b;
  }
  function bouton(libelle, attr) {
    return '<button type="button" class="cpj-touche cpj-primaire" ' + attr + '>' + echapper(libelle) + '</button>';
  }

  let occupe = false;
  // Liste des détenus puis interrogatoire. lieu : 'qhs' | 'renseignement'.
  async function ouvrirInterrogatoire(lieu) {
    const v = await rpc(lieu === 'qhs' ? 'qhs_detenus_interrogatoire' : 'renseignement_detenus_interrogatoire', {});
    if (!v) { toast(t('tReseau'), t('mReseau'), false); return; }
    if (v.ok !== true) { toast(t('tRefus'), motif(v), false); return; }
    const detenus = Array.isArray(v.detenus) ? v.detenus : [];
    const corps = '<p class="cpj-note">' + echapper(t('intro')) + '</p>' + (detenus.length
      ? detenus.map(d => '<div style="display:flex;gap:.6rem;align-items:center;margin:.3rem 0"><span>' + echapper(d.nom) + '</span>'
          + bouton(t('go'), 'data-interroger="' + echapper(d.nom) + '"') + '</div>').join('')
      : '<p class="cpj-note">' + echapper(t('aucun')) + '</p>');
    const b = ouvrir(t('tInterro'), corps); if (!b) return;
    const cle = requete();
    b.querySelectorAll('[data-interroger]').forEach(el => el.addEventListener('click', () => interroger(lieu, el.getAttribute('data-interroger'), cle)));
  }

  async function interroger(lieu, nom, cle) {
    if (occupe) return;
    occupe = true;
    try {
      const v = await rpc(lieu === 'qhs' ? 'qhs_interroger' : 'renseignement_interroger',
        lieu === 'qhs' ? { p_detenu: nom, p_requete: cle } : { p_detenu: nom });
      if (!v) { toast(t('tReseau'), t('mReseau'), false); return; }
      if (v.ok !== true) { toast(t('tRefus'), motif(v), false); return; }
      if (typeof appliquerPaiementServeur === 'function' && v.pa != null) appliquerPaiementServeur({ pa: v.pa });
      const msg = !v.reussi ? 'mEchec' : !v.revelation ? 'mRien' : lieu === 'qhs' ? 'mSecretJuge' : 'mSecretJuges';
      toast(t('tInterro'), t(msg, { p: v.probabilite }), v.reussi === true);
      if (typeof addJournalEntry === 'function') addJournalEntry(t('tInterro') + ' : ' + v.detenu, v.reussi ? 'event-good' : 'event-info');
      await relire();
    } finally { occupe = false; }
    await ouvrirInterrogatoire(lieu);
  }

  async function ouvrirIndices() {
    const v = await rpc('interrogatoire_indices_lire', {});
    if (!v) { toast(t('tReseau'), t('mReseau'), false); return; }
    if (v.ok !== true) { toast(t('tRefus'), motif(v), false); return; }
    const liste = Array.isArray(v.indices) ? v.indices : [];
    const corps = '<p class="cpj-note">' + echapper(t('introIndices')) + '</p>' + (liste.length ? liste.map(i => {
      const tete = '<strong>' + echapper(i.detenu) + '</strong> — ' + echapper(t('l' + i.lieu)) + ' · '
        + echapper(t(i.personnel ? 'perso' : 'tous'));
      const etat = i.statut === 'en_attente'
        ? '<div style="display:flex;gap:.6rem;margin-top:.3rem">' + bouton(t('saisir'), 'data-indice="' + Number(i.id) + '" data-decision="saisir"')
          + '<button type="button" class="cpj-touche" data-indice="' + Number(i.id) + '" data-decision="classer">' + echapper(t('classer')) + '</button></div>'
        : '<p class="cpj-note">' + echapper(t(i.statut === 'saisi' ? 'saisiPar' : 'classePar', { n: i.traite_par || '?' })) + '</p>';
      return '<div style="margin:.6rem 0;padding-bottom:.4rem;border-bottom:1px solid rgba(169,141,86,.3)"><div>' + tete + '</div><div>'
        + echapper(i.texte) + '</div><div class="cpj-note">' + echapper(t('par', { n: i.interrogateur })) + '</div>' + etat + '</div>';
    }).join('') : '<p class="cpj-note">' + echapper(t('aucunIndice')) + '</p>');
    const b = ouvrir(t('tIndices'), corps); if (!b) return;
    b.querySelectorAll('[data-indice]').forEach(el => el.addEventListener('click', () =>
      traiter(Number(el.getAttribute('data-indice')), el.getAttribute('data-decision'))));
  }

  async function traiter(id, decision) {
    if (occupe) return;
    occupe = true;
    try {
      const v = await rpc('interrogatoire_indice_traiter', { p_id: id, p_decision: decision });
      if (!v) { toast(t('tReseau'), t('mReseau'), false); return; }
      if (v.ok !== true) { toast(t('tRefus'), motif(v), false); return; }
      toast(t('tIndices'), t(decision === 'saisir' ? 'mSaisi' : 'mClasse'), true);
    } finally { occupe = false; }
    await ouvrirIndices();
  }

  window.ouvrirInterrogatoireQhs = () => ouvrirInterrogatoire('qhs');
  window.ouvrirInterrogatoireRenseignement = () => ouvrirInterrogatoire('renseignement');
  window.ouvrirIndicesInterrogatoire = ouvrirIndices;
  window.RP_INTERROGATOIRES_T = T;
})();
