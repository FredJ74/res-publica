// =====================
// PLATEAU-GOULAG-ORDRES.JS
// Goulag de Sovarka : ordres internes des cinq pièces (décisions de Fred du 17/11/2026).
// L'écran ne décide rien : chaque ordre appelle une RPC serveur, affiche son verdict et
// relit la fiche. Les jets, PA, peines, sanctions et courriers sont tranchés par le serveur.
// Dépend du moteur préparé dans la PR #1020 (activation, transports, départ à pied) ; tant
// que le goulag n'est pas activé, toutes les RPC répondent « goulag_non_active ».
// =====================
(function () {
  'use strict';

  const LANGUES = ['fr', 'en', 'es', 'zh-TW', 'ru', 'ko', 'ar', 'pt-BR', 'de'];
  // Noms propres conservés en alphabet latin dans toutes les langues.
  const T = {
    fr: {
      oListe: 'Consulter la liste des détenus', oDormir: 'Dormir', oManger: 'Manger',
      oRegistre: 'Consulter le registre', oInterroger: 'Interroger un détenu',
      oSanction: 'Prononcer une sanction disciplinaire', oCorrompre: 'Corrompre le gardien',
      oIncidents: 'Consulter les incidents du camp', oMirador: 'Aller au mirador',
      oDortoir: 'Retourner au dortoir', oEntree: "Aller à l'entrée",
      dListe: 'Détenus, jours de peine restants et statut au dernier contrôle de minuit.',
      dDormirDortoir: '+1 PA. Un sommeil par jour purge une journée de peine.',
      dDormirCachot: '0 PA. Purge une journée de peine et une nuit de cachot.',
      dManger: '+1 PA. Un repas par jour.',
      dRegistre: 'Historique des détenus : tribunal, entrée, sortie, interrogatoires.',
      dInterroger: "−7 PA au détenu (jamais sous 1). Un secret peut être révélé à son juge.",
      dSanction: 'Juge présent uniquement : une ou deux nuits de cachot.',
      dCorrompre: 'Préparer une évasion en offrant un objet au gardien. Chance : 80 % + 2 par point de Charme (90 % au plus).',
      dIncidents: 'Évasions, sanctions et absences constatées à minuit.',
      dDeplacer: 'Circulation sous surveillance, ni libération ni transport.', mCorruptionRegle: 'Chaque tentative exige un objet de votre inventaire, remis au gardien même en cas d\'échec. Plusieurs tentatives par jour sont possibles.',
      sDetenu: 'Détenu', sAttente: 'Libération en attente', sFuite: 'En fuite',
      cNom: 'Nom', cJours: 'Jours restants', cStatut: 'Statut', cTribunal: 'Tribunal',
      cEntree: 'Entrée', cSortie: 'Sortie effective', cInterro: 'Interrogatoires',
      evadeLe: 'Évadé le {d}', inconnu: 'Inconnu', tribunalDe: 'Tribunal de {v}',
      aucunDetenu: 'Aucun détenu.', aucunIncident: 'Aucun incident.',
      iEvasionOk: 'Évasion réussie', iEvasionKo: 'Évasion manquée', iSanction: 'Sanction disciplinaire',
      iAbsence: 'Absence constatée à minuit', nuits: '{n} nuit(s)',
      choisirDetenu: 'Choisissez un détenu', nuit1: 'Une nuit', nuit2: 'Deux nuits',
      confirmer: 'Confirmer', annuler: 'Annuler', fermer: 'Fermer', sansObjet: 'Vous n\'avez aucun objet à offrir.',
      proposerObjet: 'Objet offert au gardien',
      tDormi: 'Sommeil', mDormi: '+{gain} PA. Jours de peine restants : {jours}.',
      tLibere: 'Libération', mLibere: "Votre peine est purgée. Vous êtes libre, devant l'entrée du camp.",
      tMange: 'Repas', mMange: '+1 PA.',
      tInterro: 'Interrogatoire', mInterroSecret: "Le détenu a parlé ({p} %). Le fait révélé est transmis à son juge.",
      mInterroRien: "Le détenu a cédé ({p} %), mais n'avait plus aucun secret à livrer.",
      mInterroEchec: "Le détenu n'a rien révélé ({p} %).",
      tSanction: 'Sanction', mSanction: '{nom} : {n} nuit(s) de cachot.',
      tCorruption: 'Corruption', mCorruptionOk: 'Le gardien accepte : votre prochaine tentative d’évasion sera facilitée.',
      mCorruptionKo: 'Le gardien refuse.',
      tDepart: "S'enfuir à pied", mDestination: 'Choisissez votre destination. Départ irréversible.',
      starovka: 'Starovka — 7 PA minimum, 7 jours de marche', krasnov: 'Krasnov — 10 PA minimum, 10 jours de marche',
      mJet: 'Sortie du camp : une tentative par jour, 80 % de réussite (95 % si un gardien a été corrompu).',
      tEvasionKo: 'Évasion manquée', mEvasionKo: 'Les gardes vous rattrapent : deux nuits au cachot. Votre peine reste entière.',
      tRefus: 'Ordre refusé', tReseau: 'Serveur injoignable', mReseau: "Aucune réponse du serveur ; rien n'a été appliqué à l'écran.",
      r: {
        goulag_non_active: "Le goulag n'est pas encore ouvert.", deja_dormi_aujourdhui: "Vous avez déjà dormi aujourd'hui.",
        deja_mange: "Vous avez déjà mangé aujourd'hui.", sanction_cachot_en_cours: 'Vous purgez une sanction au cachot.',
        sanction_terminee: 'Votre sanction est terminée : retour au dortoir.', detenu_epuise: 'Ce détenu est trop épuisé (1 PA ou moins).',
        reserve_juge_sovarka: 'Réservé à un juge de Sovarka.', juge_absent_du_bureau: 'Le juge doit être présent dans ce bureau.',
       
        gardien_deja_corrompu: 'Un gardien est déjà acquis à votre cause.', cadeau_obligatoire: 'Choisissez un objet à offrir au gardien.', objet_protege: 'Cet objet ne peut pas être donné.',
        tentative_deja_faite_aujourdhui: "Une seule tentative d'évasion par jour.", pa_insuffisants_depart: 'PA insuffisants pour ce trajet.',
        non_detenu_goulag: "Vous n'êtes pas détenu au goulag.", detenu_introuvable: 'Détenu introuvable.',
        reserve_habilite_entree: 'Réservé aux personnes habilitées présentes.', reserve_habilite_bureau: 'Réservé aux personnes habilitées présentes.',
        reserve_habilite_mirador: 'Réservé aux personnes habilitées présentes.', objet_introuvable: 'Objet introuvable dans votre inventaire.',
        pas_au_dortoir: 'Uniquement au dortoir.', pas_au_mirador: 'Uniquement au mirador.', pa_insuffisants: 'Pas assez de PA pour cet ordre.', requete_deja_utilisee: 'Cette demande a déjà été utilisée par quelqu\'un d\'autre ; recommencez.', defaut: 'Le serveur a refusé cet ordre.'
      }
    },
    en: {
      oListe: 'View the list of prisoners', oDormir: 'Sleep', oManger: 'Eat', oRegistre: 'View the register',
      oInterroger: 'Interrogate a prisoner', oSanction: 'Impose a disciplinary sanction', oCorrompre: 'Bribe the guard',
      oIncidents: 'View camp incidents', oMirador: 'Go to the watchtower', oDortoir: 'Return to the dormitory', oEntree: 'Go to the entrance',
      dListe: 'Prisoners, days of sentence left and status at the last midnight check.',
      dDormirDortoir: '+1 AP. One sleep per day serves one day of the sentence.',
      dDormirCachot: '0 AP. Serves one day of the sentence and one night in the punishment cell.',
      dManger: '+1 AP. One meal per day.', dRegistre: 'Prisoner history: court, entry, release, interrogations.',
      dInterroger: '−7 AP for the prisoner (never below 1). A secret may be revealed to their judge.',
      dSanction: 'Judge present only: one or two nights in the punishment cell.',
      dCorrompre: 'Prepare an escape by offering the guard an item. Chance: 80 % + 2 per Charm point (90 % at most).',
      dIncidents: 'Escapes, sanctions and absences recorded at midnight.', dDeplacer: 'Supervised movement, neither release nor transport.', mCorruptionRegle: 'Each attempt requires an item from your inventory, given to the guard even if it fails. Several attempts per day are possible.',
      sDetenu: 'Prisoner', sAttente: 'Release pending', sFuite: 'On the run',
      cNom: 'Name', cJours: 'Days left', cStatut: 'Status', cTribunal: 'Court', cEntree: 'Entry', cSortie: 'Actual release', cInterro: 'Interrogations',
      evadeLe: 'Escaped on {d}', inconnu: 'Unknown', tribunalDe: 'Court of {v}', aucunDetenu: 'No prisoners.', aucunIncident: 'No incidents.',
      iEvasionOk: 'Successful escape', iEvasionKo: 'Failed escape', iSanction: 'Disciplinary sanction', iAbsence: 'Absence recorded at midnight', nuits: '{n} night(s)',
      choisirDetenu: 'Choose a prisoner', nuit1: 'One night', nuit2: 'Two nights', confirmer: 'Confirm', annuler: 'Cancel', fermer: 'Close',
      sansObjet: 'You have no item to offer.', proposerObjet: 'Item offered to the guard',
      tDormi: 'Sleep', mDormi: '+{gain} AP. Days of sentence left: {jours}.', tLibere: 'Release',
      mLibere: 'Your sentence is served. You are free, in front of the camp entrance.', tMange: 'Meal', mMange: '+1 AP.',
      tInterro: 'Interrogation', mInterroSecret: 'The prisoner talked ({p} %). The revealed fact is sent to their judge.',
      mInterroRien: 'The prisoner gave in ({p} %), but had no secret left to reveal.', mInterroEchec: 'The prisoner revealed nothing ({p} %).',
      tSanction: 'Sanction', mSanction: '{nom}: {n} night(s) in the punishment cell.', tCorruption: 'Bribery',
      mCorruptionOk: 'The guard accepts: your next escape attempt will be easier.', mCorruptionKo: 'The guard refuses.',
      tDepart: 'Flee on foot', mDestination: 'Choose your destination. The departure is irreversible.',
      starovka: 'Starovka — 7 AP minimum, 7 days of walking', krasnov: 'Krasnov — 10 AP minimum, 10 days of walking',
      mJet: 'Leaving the camp: one attempt per day, 80 % success (95 % if a guard was bribed).',
      tEvasionKo: 'Failed escape', mEvasionKo: 'The guards catch you: two nights in the punishment cell. Your sentence remains in full.',
      tRefus: 'Order refused', tReseau: 'Server unreachable', mReseau: 'No answer from the server; nothing was applied on screen.',
      r: {
        goulag_non_active: 'The gulag is not open yet.', deja_dormi_aujourdhui: 'You have already slept today.', deja_mange: 'You have already eaten today.',
        sanction_cachot_en_cours: 'You are serving a sanction in the punishment cell.', sanction_terminee: 'Your sanction is over: back to the dormitory.',
        detenu_epuise: 'This prisoner is too exhausted (1 AP or less).', reserve_juge_sovarka: 'Reserved for a judge of Sovarka.',
        juge_absent_du_bureau: 'The judge must be present in this office.',
        gardien_deja_corrompu: 'A guard is already on your side.', cadeau_obligatoire: 'Choose an item to offer the guard.', objet_protege: 'This item cannot be given away.',
        tentative_deja_faite_aujourdhui: 'Only one escape attempt per day.', pa_insuffisants_depart: 'Not enough AP for this journey.',
        non_detenu_goulag: 'You are not a prisoner of the gulag.', detenu_introuvable: 'Prisoner not found.',
        reserve_habilite_entree: 'Reserved for authorised people present.', reserve_habilite_bureau: 'Reserved for authorised people present.',
        reserve_habilite_mirador: 'Reserved for authorised people present.', objet_introuvable: 'Item not found in your inventory.',
        pas_au_dortoir: 'Only in the dormitory.', pas_au_mirador: 'Only at the watchtower.', pa_insuffisants: 'Not enough AP for this order.', requete_deja_utilisee: 'This request was already used by someone else; please start again.', defaut: 'The server refused this order.'
      }
    },
    es: {
      oListe: 'Consultar la lista de presos', oDormir: 'Dormir', oManger: 'Comer', oRegistre: 'Consultar el registro',
      oInterroger: 'Interrogar a un preso', oSanction: 'Imponer una sanción disciplinaria', oCorrompre: 'Sobornar al guardia',
      oIncidents: 'Consultar los incidentes del campo', oMirador: 'Ir a la torre de vigilancia', oDortoir: 'Volver al dormitorio', oEntree: 'Ir a la entrada',
      dListe: 'Presos, días de condena restantes y estado en el último control de medianoche.',
      dDormirDortoir: '+1 PA. Un sueño al día cumple un día de condena.', dDormirCachot: '0 PA. Cumple un día de condena y una noche de calabozo.',
      dManger: '+1 PA. Una comida al día.', dRegistre: 'Historial de presos: tribunal, entrada, salida, interrogatorios.',
      dInterroger: '−7 PA al preso (nunca menos de 1). Puede revelarse un secreto a su juez.',
      dSanction: 'Solo con el juez presente: una o dos noches de calabozo.', dCorrompre: 'Preparar una fuga ofreciendo un objeto al guardia. Probabilidad: 80 % + 2 por punto de Carisma (90 % como máximo).',
      dIncidents: 'Fugas, sanciones y ausencias constatadas a medianoche.', dDeplacer: 'Desplazamiento vigilado, ni liberación ni transporte.', mCorruptionRegle: 'Cada intento exige un objeto de su inventario, entregado al guardia aunque falle. Se pueden hacer varios intentos al día.',
      sDetenu: 'Preso', sAttente: 'Liberación pendiente', sFuite: 'Fugado',
      cNom: 'Nombre', cJours: 'Días restantes', cStatut: 'Estado', cTribunal: 'Tribunal', cEntree: 'Entrada', cSortie: 'Salida efectiva', cInterro: 'Interrogatorios',
      evadeLe: 'Fugado el {d}', inconnu: 'Desconocido', tribunalDe: 'Tribunal de {v}', aucunDetenu: 'Ningún preso.', aucunIncident: 'Ningún incidente.',
      iEvasionOk: 'Fuga lograda', iEvasionKo: 'Fuga fallida', iSanction: 'Sanción disciplinaria', iAbsence: 'Ausencia constatada a medianoche', nuits: '{n} noche(s)',
      choisirDetenu: 'Elija un preso', nuit1: 'Una noche', nuit2: 'Dos noches', confirmer: 'Confirmar', annuler: 'Cancelar', fermer: 'Cerrar',
      sansObjet: 'No tiene ningún objeto que ofrecer.', proposerObjet: 'Objeto ofrecido al guardia',
      tDormi: 'Sueño', mDormi: '+{gain} PA. Días de condena restantes: {jours}.', tLibere: 'Liberación',
      mLibere: 'Ha cumplido su condena. Está libre, ante la entrada del campo.', tMange: 'Comida', mMange: '+1 PA.',
      tInterro: 'Interrogatorio', mInterroSecret: 'El preso ha hablado ({p} %). El hecho revelado se envía a su juez.',
      mInterroRien: 'El preso cedió ({p} %), pero ya no tenía secretos.', mInterroEchec: 'El preso no reveló nada ({p} %).',
      tSanction: 'Sanción', mSanction: '{nom}: {n} noche(s) de calabozo.', tCorruption: 'Soborno',
      mCorruptionOk: 'El guardia acepta: su próximo intento de fuga será más fácil.', mCorruptionKo: 'El guardia se niega.',
      tDepart: 'Huir a pie', mDestination: 'Elija su destino. La salida es irreversible.',
      starovka: 'Starovka — 7 PA mínimo, 7 días de marcha', krasnov: 'Krasnov — 10 PA mínimo, 10 días de marcha',
      mJet: 'Salida del campo: un intento al día, 80 % de éxito (95 % si se sobornó a un guardia).',
      tEvasionKo: 'Fuga fallida', mEvasionKo: 'Los guardias le atrapan: dos noches de calabozo. Su condena sigue íntegra.',
      tRefus: 'Orden rechazada', tReseau: 'Servidor inaccesible', mReseau: 'Sin respuesta del servidor; no se aplicó nada en pantalla.',
      r: {
        goulag_non_active: 'El gulag aún no está abierto.', deja_dormi_aujourdhui: 'Ya ha dormido hoy.', deja_mange: 'Ya ha comido hoy.',
        sanction_cachot_en_cours: 'Está cumpliendo una sanción en el calabozo.', sanction_terminee: 'Su sanción ha terminado: vuelta al dormitorio.',
        detenu_epuise: 'Este preso está demasiado agotado (1 PA o menos).', reserve_juge_sovarka: 'Reservado a un juez de Sovarka.',
        juge_absent_du_bureau: 'El juez debe estar presente en esta oficina.',
        gardien_deja_corrompu: 'Un guardia ya está de su lado.', cadeau_obligatoire: 'Elija un objeto para ofrecer al guardia.', objet_protege: 'Este objeto no se puede regalar.',
        tentative_deja_faite_aujourdhui: 'Solo un intento de fuga al día.', pa_insuffisants_depart: 'PA insuficientes para este trayecto.',
        non_detenu_goulag: 'No está preso en el gulag.', detenu_introuvable: 'Preso no encontrado.',
        reserve_habilite_entree: 'Reservado a personas autorizadas presentes.', reserve_habilite_bureau: 'Reservado a personas autorizadas presentes.',
        reserve_habilite_mirador: 'Reservado a personas autorizadas presentes.', objet_introuvable: 'Objeto no encontrado en su inventario.',
        pas_au_dortoir: 'Solo en el dormitorio.', pas_au_mirador: 'Solo en la torre de vigilancia.', pa_insuffisants: 'PA insuficientes para esta orden.', requete_deja_utilisee: 'Esta solicitud ya la usó otra persona; vuelva a empezar.', defaut: 'El servidor rechazó esta orden.'
      }
    },
    'zh-TW': {
      oListe: '查看囚犯名單', oDormir: '睡覺', oManger: '吃飯', oRegistre: '查看登記冊', oInterroger: '審問囚犯',
      oSanction: '宣布紀律處分', oCorrompre: '賄賂看守', oIncidents: '查看營地事件', oMirador: '前往瞭望塔', oDortoir: '返回宿舍', oEntree: '前往入口',
      dListe: '囚犯、剩餘刑期天數及最近一次午夜點名的狀態。', dDormirDortoir: '+1 行動點。每天睡一次可服完一天刑期。',
      dDormirCachot: '0 行動點。服完一天刑期並減少一晚禁閉。', dManger: '+1 行動點。每天一餐。',
      dRegistre: '囚犯紀錄：法院、入營、出營、審問次數。', dInterroger: '囚犯 −7 行動點（不低於 1）。秘密可能被透露給其法官。',
      dSanction: '僅限在場法官：一或兩晚禁閉。', dCorrompre: '向看守送一件物品，為越獄做準備。成功率：80% 加每點魅力 2%（最高 90%）。',
      dIncidents: '越獄、處分及午夜點名發現的缺席。', dDeplacer: '受監視的移動，既非釋放也非交通。', mCorruptionRegle: '每次嘗試都需要物品欄中的一件物品，即使失敗也歸看守所有。每天可嘗試多次。',
      sDetenu: '在押', sAttente: '待釋放', sFuite: '在逃',
      cNom: '姓名', cJours: '剩餘天數', cStatut: '狀態', cTribunal: '法院', cEntree: '入營', cSortie: '實際出營', cInterro: '審問次數',
      evadeLe: '{d} 越獄', inconnu: '不明', tribunalDe: '{v} 法院', aucunDetenu: '沒有囚犯。', aucunIncident: '沒有事件。',
      iEvasionOk: '越獄成功', iEvasionKo: '越獄失敗', iSanction: '紀律處分', iAbsence: '午夜點名發現缺席', nuits: '{n} 晚',
      choisirDetenu: '選擇一名囚犯', nuit1: '一晚', nuit2: '兩晚', confirmer: '確認', annuler: '取消', fermer: '關閉',
      sansObjet: '您沒有可送的物品。', proposerObjet: '送給看守的物品',
      tDormi: '睡眠', mDormi: '+{gain} 行動點。剩餘刑期：{jours} 天。', tLibere: '釋放', mLibere: '您已服完刑期，已獲自由，現在營地入口前。',
      tMange: '用餐', mMange: '+1 行動點。', tInterro: '審問', mInterroSecret: '囚犯開口了（{p}%）。透露的事實已轉交其法官。',
      mInterroRien: '囚犯屈服了（{p}%），但已沒有任何秘密。', mInterroEchec: '囚犯什麼也沒說（{p}%）。',
      tSanction: '處分', mSanction: '{nom}：禁閉 {n} 晚。', tCorruption: '賄賂', mCorruptionOk: '看守接受了：您下一次越獄會更容易。', mCorruptionKo: '看守拒絕了。',
      tDepart: '徒步逃離', mDestination: '選擇目的地。出發後無法回頭。',
      starovka: 'Starovka — 至少 7 行動點，步行 7 天', krasnov: 'Krasnov — 至少 10 行動點，步行 10 天',
      mJet: '離開營地：每天一次嘗試，成功率 80%（若已賄賂看守則為 95%）。',
      tEvasionKo: '越獄失敗', mEvasionKo: '看守抓住了您：禁閉兩晚。您的刑期維持不變。',
      tRefus: '命令被拒絕', tReseau: '無法連線伺服器', mReseau: '伺服器沒有回應；畫面上未套用任何變更。',
      r: {
        goulag_non_active: '古拉格尚未開放。', deja_dormi_aujourdhui: '您今天已經睡過了。', deja_mange: '您今天已經吃過了。',
        sanction_cachot_en_cours: '您正在禁閉室服處分。', sanction_terminee: '您的處分已結束：返回宿舍。', detenu_epuise: '這名囚犯太疲憊了（1 行動點或更少）。',
        reserve_juge_sovarka: '僅限 Sovarka 的法官。', juge_absent_du_bureau: '法官必須在此辦公室內。',
        gardien_deja_corrompu: '已有一名看守站在您這邊。', cadeau_obligatoire: '請選擇一件送給看守的物品。', objet_protege: '此物品無法贈送。',
        tentative_deja_faite_aujourdhui: '每天只能嘗試越獄一次。', pa_insuffisants_depart: '行動點不足以完成此行程。',
        non_detenu_goulag: '您不是古拉格的囚犯。', detenu_introuvable: '找不到該囚犯。', reserve_habilite_entree: '僅限在場的授權人員。',
        reserve_habilite_bureau: '僅限在場的授權人員。', reserve_habilite_mirador: '僅限在場的授權人員。', objet_introuvable: '您的物品欄中找不到該物品。',
        pas_au_dortoir: '僅限宿舍。', pas_au_mirador: '僅限瞭望塔。', pa_insuffisants: '行動點不足以執行此命令。', requete_deja_utilisee: '此請求已被他人使用，請重新操作。', defaut: '伺服器拒絕了此命令。'
      }
    },
    ru: {
      oListe: 'Просмотреть список заключённых', oDormir: 'Спать', oManger: 'Поесть', oRegistre: 'Просмотреть журнал',
      oInterroger: 'Допросить заключённого', oSanction: 'Назначить дисциплинарное взыскание', oCorrompre: 'Подкупить охранника',
      oIncidents: 'Просмотреть происшествия в лагере', oMirador: 'Пойти на вышку', oDortoir: 'Вернуться в барак', oEntree: 'Пойти ко входу',
      dListe: 'Заключённые, оставшиеся дни срока и статус на последней полуночной проверке.',
      dDormirDortoir: '+1 ОД. Один сон в день засчитывает один день срока.', dDormirCachot: '0 ОД. Засчитывает один день срока и одну ночь карцера.',
      dManger: '+1 ОД. Одна еда в день.', dRegistre: 'История заключённых: суд, поступление, освобождение, допросы.',
      dInterroger: '−7 ОД заключённому (не ниже 1). Тайна может быть сообщена его судье.',
      dSanction: 'Только при присутствии судьи: одна или две ночи карцера.', dCorrompre: 'Подготовить побег, предложив охраннику предмет. Шанс: 80 % + 2 за каждое очко Обаяния (не более 90 %).',
      dIncidents: 'Побеги, взыскания и отсутствия, выявленные в полночь.', dDeplacer: 'Перемещение под надзором — не освобождение и не транспорт.', mCorruptionRegle: 'Каждая попытка требует предмет из инвентаря, который остаётся у охранника даже при неудаче. В день можно делать несколько попыток.',
      sDetenu: 'Заключён', sAttente: 'Ожидает освобождения', sFuite: 'В бегах',
      cNom: 'Имя', cJours: 'Осталось дней', cStatut: 'Статус', cTribunal: 'Суд', cEntree: 'Поступление', cSortie: 'Фактическое освобождение', cInterro: 'Допросы',
      evadeLe: 'Бежал {d}', inconnu: 'Неизвестно', tribunalDe: 'Суд {v}', aucunDetenu: 'Заключённых нет.', aucunIncident: 'Происшествий нет.',
      iEvasionOk: 'Удачный побег', iEvasionKo: 'Неудачный побег', iSanction: 'Дисциплинарное взыскание', iAbsence: 'Отсутствие выявлено в полночь', nuits: 'ночей: {n}',
      choisirDetenu: 'Выберите заключённого', nuit1: 'Одна ночь', nuit2: 'Две ночи', confirmer: 'Подтвердить', annuler: 'Отмена', fermer: 'Закрыть',
      sansObjet: 'Вам нечего предложить.', proposerObjet: 'Предмет для охранника',
      tDormi: 'Сон', mDormi: '+{gain} ОД. Осталось дней срока: {jours}.', tLibere: 'Освобождение',
      mLibere: 'Срок отбыт. Вы свободны и стоите у входа в лагерь.', tMange: 'Еда', mMange: '+1 ОД.',
      tInterro: 'Допрос', mInterroSecret: 'Заключённый заговорил ({p} %). Раскрытый факт передан его судье.',
      mInterroRien: 'Заключённый сломался ({p} %), но тайн у него больше не осталось.', mInterroEchec: 'Заключённый ничего не сказал ({p} %).',
      tSanction: 'Взыскание', mSanction: '{nom}: ночей в карцере — {n}.', tCorruption: 'Подкуп',
      mCorruptionOk: 'Охранник согласен: следующая попытка побега будет легче.', mCorruptionKo: 'Охранник отказывается.',
      tDepart: 'Бежать пешком', mDestination: 'Выберите место назначения. Уход необратим.',
      starovka: 'Starovka — минимум 7 ОД, 7 дней пути', krasnov: 'Krasnov — минимум 10 ОД, 10 дней пути',
      mJet: 'Выход из лагеря: одна попытка в день, 80 % успеха (95 %, если охранник подкуплен).',
      tEvasionKo: 'Неудачный побег', mEvasionKo: 'Охрана вас ловит: две ночи в карцере. Срок остаётся полностью.',
      tRefus: 'Приказ отклонён', tReseau: 'Сервер недоступен', mReseau: 'Сервер не ответил; на экране ничего не изменено.',
      r: {
        goulag_non_active: 'Лагерь ещё не открыт.', deja_dormi_aujourdhui: 'Сегодня вы уже спали.', deja_mange: 'Сегодня вы уже ели.',
        sanction_cachot_en_cours: 'Вы отбываете взыскание в карцере.', sanction_terminee: 'Взыскание окончено: возвращение в барак.',
        detenu_epuise: 'Заключённый слишком измотан (1 ОД или меньше).', reserve_juge_sovarka: 'Только для судьи Sovarka.',
        juge_absent_du_bureau: 'Судья должен находиться в этом кабинете.',
        gardien_deja_corrompu: 'Один охранник уже на вашей стороне.', cadeau_obligatoire: 'Выберите предмет для охранника.', objet_protege: 'Этот предмет нельзя отдать.',
        tentative_deja_faite_aujourdhui: 'Только одна попытка побега в день.', pa_insuffisants_depart: 'Недостаточно ОД для этого пути.',
        non_detenu_goulag: 'Вы не заключённый лагеря.', detenu_introuvable: 'Заключённый не найден.',
        reserve_habilite_entree: 'Только для присутствующих допущенных лиц.', reserve_habilite_bureau: 'Только для присутствующих допущенных лиц.',
        reserve_habilite_mirador: 'Только для присутствующих допущенных лиц.', objet_introuvable: 'Предмет не найден в инвентаре.',
        pas_au_dortoir: 'Только в бараке.', pas_au_mirador: 'Только на вышке.', pa_insuffisants: 'Недостаточно ОД для этого приказа.', requete_deja_utilisee: 'Этот запрос уже использован другим игроком; начните заново.', defaut: 'Сервер отклонил этот приказ.'
      }
    },
    ko: {
      oListe: '수감자 명단 보기', oDormir: '잠자기', oManger: '식사하기', oRegistre: '등록부 보기', oInterroger: '수감자 심문',
      oSanction: '징계 처분 선고', oCorrompre: '간수 매수', oIncidents: '수용소 사건 보기', oMirador: '감시탑으로 가기', oDortoir: '숙소로 돌아가기', oEntree: '입구로 가기',
      dListe: '수감자, 남은 형기 일수, 마지막 자정 점검 시 상태.', dDormirDortoir: '+1 AP. 하루 한 번의 수면으로 형기 하루를 채웁니다.',
      dDormirCachot: '0 AP. 형기 하루와 독방 하룻밤을 채웁니다.', dManger: '+1 AP. 하루 한 끼.',
      dRegistre: '수감자 기록: 법원, 입소, 출소, 심문 횟수.', dInterroger: '수감자 −7 AP (1 미만 불가). 비밀이 담당 판사에게 전달될 수 있습니다.',
      dSanction: '판사가 있을 때만: 독방 하룻밤 또는 이틀 밤.', dCorrompre: '간수에게 물건을 주어 탈옥을 준비합니다. 확률: 80% + 매력 1점당 2% (최대 90%).',
      dIncidents: '탈옥, 징계, 자정에 확인된 부재.', dDeplacer: '감시 하의 이동이며 석방이나 이동 수단이 아닙니다.', mCorruptionRegle: '매 시도마다 인벤토리의 물건 하나가 필요하며, 실패해도 간수에게 넘어갑니다. 하루에 여러 번 시도할 수 있습니다.',
      sDetenu: '수감 중', sAttente: '석방 대기', sFuite: '도주 중',
      cNom: '이름', cJours: '남은 일수', cStatut: '상태', cTribunal: '법원', cEntree: '입소', cSortie: '실제 출소', cInterro: '심문',
      evadeLe: '{d} 탈옥', inconnu: '알 수 없음', tribunalDe: '{v} 법원', aucunDetenu: '수감자가 없습니다.', aucunIncident: '사건이 없습니다.',
      iEvasionOk: '탈옥 성공', iEvasionKo: '탈옥 실패', iSanction: '징계 처분', iAbsence: '자정에 확인된 부재', nuits: '{n}박',
      choisirDetenu: '수감자를 선택하세요', nuit1: '하룻밤', nuit2: '이틀 밤', confirmer: '확인', annuler: '취소', fermer: '닫기',
      sansObjet: '줄 수 있는 물건이 없습니다.', proposerObjet: '간수에게 줄 물건',
      tDormi: '수면', mDormi: '+{gain} AP. 남은 형기: {jours}일.', tLibere: '석방', mLibere: '형기를 마쳤습니다. 자유의 몸으로 수용소 입구 앞에 있습니다.',
      tMange: '식사', mMange: '+1 AP.', tInterro: '심문', mInterroSecret: '수감자가 입을 열었습니다 ({p}%). 밝혀진 사실은 담당 판사에게 전달됩니다.',
      mInterroRien: '수감자가 굴복했지만 ({p}%), 더 이상 털어놓을 비밀이 없었습니다.', mInterroEchec: '수감자는 아무것도 말하지 않았습니다 ({p}%).',
      tSanction: '징계', mSanction: '{nom}: 독방 {n}박.', tCorruption: '매수', mCorruptionOk: '간수가 받아들였습니다: 다음 탈옥 시도가 쉬워집니다.', mCorruptionKo: '간수가 거절했습니다.',
      tDepart: '걸어서 도주', mDestination: '목적지를 선택하세요. 출발은 되돌릴 수 없습니다.',
      starovka: 'Starovka — 최소 7 AP, 도보 7일', krasnov: 'Krasnov — 최소 10 AP, 도보 10일',
      mJet: '수용소 탈출: 하루 한 번 시도, 성공률 80% (간수를 매수했다면 95%).',
      tEvasionKo: '탈옥 실패', mEvasionKo: '간수들에게 붙잡혔습니다: 독방 이틀 밤. 형기는 그대로 남습니다.',
      tRefus: '명령 거부', tReseau: '서버에 연결할 수 없음', mReseau: '서버 응답이 없습니다. 화면에는 아무것도 적용되지 않았습니다.',
      r: {
        goulag_non_active: '굴라크는 아직 열리지 않았습니다.', deja_dormi_aujourdhui: '오늘은 이미 잠을 잤습니다.', deja_mange: '오늘은 이미 식사했습니다.',
        sanction_cachot_en_cours: '독방에서 징계를 받고 있습니다.', sanction_terminee: '징계가 끝났습니다: 숙소로 돌아갑니다.',
        detenu_epuise: '이 수감자는 너무 지쳐 있습니다 (1 AP 이하).', reserve_juge_sovarka: 'Sovarka의 판사만 가능합니다.',
        juge_absent_du_bureau: '판사가 이 사무실에 있어야 합니다.',
        gardien_deja_corrompu: '이미 간수 한 명이 당신 편입니다.', cadeau_obligatoire: '간수에게 줄 물건을 선택하세요.', objet_protege: '이 물건은 줄 수 없습니다.',
        tentative_deja_faite_aujourdhui: '탈옥 시도는 하루 한 번뿐입니다.', pa_insuffisants_depart: '이 여정에 필요한 AP가 부족합니다.',
        non_detenu_goulag: '굴라크 수감자가 아닙니다.', detenu_introuvable: '수감자를 찾을 수 없습니다.',
        reserve_habilite_entree: '현장에 있는 허가된 사람만 가능합니다.', reserve_habilite_bureau: '현장에 있는 허가된 사람만 가능합니다.',
        reserve_habilite_mirador: '현장에 있는 허가된 사람만 가능합니다.', objet_introuvable: '인벤토리에서 물건을 찾을 수 없습니다.',
        pas_au_dortoir: '숙소에서만 가능합니다.', pas_au_mirador: '감시탑에서만 가능합니다.', pa_insuffisants: '이 명령에 필요한 AP가 부족합니다.', requete_deja_utilisee: '이 요청은 이미 다른 사람이 사용했습니다. 다시 시도하세요.', defaut: '서버가 이 명령을 거부했습니다.'
      }
    },
    ar: {
      oListe: 'الاطلاع على قائمة السجناء', oDormir: 'النوم', oManger: 'الأكل', oRegistre: 'الاطلاع على السجل', oInterroger: 'استجواب سجين',
      oSanction: 'إصدار عقوبة تأديبية', oCorrompre: 'رشوة الحارس', oIncidents: 'الاطلاع على حوادث المعسكر', oMirador: 'الذهاب إلى برج المراقبة',
      oDortoir: 'العودة إلى المهجع', oEntree: 'الذهاب إلى المدخل',
      dListe: 'السجناء وأيام العقوبة المتبقية والحالة عند آخر تفقد منتصف الليل.', dDormirDortoir: '+1 نقطة عمل. نوم واحد يوميًا يقضي يومًا من العقوبة.',
      dDormirCachot: '0 نقطة عمل. يقضي يومًا من العقوبة وليلة في الزنزانة التأديبية.', dManger: '+1 نقطة عمل. وجبة واحدة يوميًا.',
      dRegistre: 'سجل السجناء: المحكمة، الدخول، الخروج، الاستجوابات.', dInterroger: '−7 نقاط عمل للسجين (ليس أقل من 1). قد يُكشف سرّ لقاضيه.',
      dSanction: 'بحضور القاضي فقط: ليلة أو ليلتان في الزنزانة التأديبية.', dCorrompre: 'التحضير للهروب بتقديم غرض للحارس. الفرصة: 80 % + 2 لكل نقطة جاذبية (90 % كحد أقصى).',
      dIncidents: 'محاولات الهروب والعقوبات والغيابات المسجلة عند منتصف الليل.', dDeplacer: 'تنقل تحت المراقبة، ليس إفراجًا ولا وسيلة نقل.', mCorruptionRegle: 'تتطلب كل محاولة غرضًا من مخزونك يُسلَّم للحارس حتى عند الفشل. يمكن القيام بعدة محاولات في اليوم.',
      sDetenu: 'محتجز', sAttente: 'إفراج قيد الانتظار', sFuite: 'هارب',
      cNom: 'الاسم', cJours: 'الأيام المتبقية', cStatut: 'الحالة', cTribunal: 'المحكمة', cEntree: 'الدخول', cSortie: 'الخروج الفعلي', cInterro: 'الاستجوابات',
      evadeLe: 'هرب في {d}', inconnu: 'غير معروف', tribunalDe: 'محكمة {v}', aucunDetenu: 'لا يوجد سجناء.', aucunIncident: 'لا توجد حوادث.',
      iEvasionOk: 'هروب ناجح', iEvasionKo: 'هروب فاشل', iSanction: 'عقوبة تأديبية', iAbsence: 'غياب مسجل عند منتصف الليل', nuits: '{n} ليلة',
      choisirDetenu: 'اختر سجينًا', nuit1: 'ليلة واحدة', nuit2: 'ليلتان', confirmer: 'تأكيد', annuler: 'إلغاء', fermer: 'إغلاق',
      sansObjet: 'ليس لديك أي غرض لتقدمه.', proposerObjet: 'الغرض المقدم للحارس',
      tDormi: 'النوم', mDormi: '+{gain} نقطة عمل. أيام العقوبة المتبقية: {jours}.', tLibere: 'الإفراج', mLibere: 'قضيت عقوبتك. أنت حر أمام مدخل المعسكر.',
      tMange: 'الوجبة', mMange: '+1 نقطة عمل.', tInterro: 'الاستجواب', mInterroSecret: 'تكلم السجين ({p} %). أُرسلت الواقعة المكشوفة إلى قاضيه.',
      mInterroRien: 'استسلم السجين ({p} %)، لكن لم يعد لديه أي سر.', mInterroEchec: 'لم يكشف السجين شيئًا ({p} %).',
      tSanction: 'العقوبة', mSanction: '{nom}: {n} ليلة في الزنزانة التأديبية.', tCorruption: 'الرشوة',
      mCorruptionOk: 'وافق الحارس: ستكون محاولة هروبك التالية أسهل.', mCorruptionKo: 'رفض الحارس.',
      tDepart: 'الفرار سيرًا على الأقدام', mDestination: 'اختر وجهتك. المغادرة لا رجعة فيها.',
      starovka: 'Starovka — 7 نقاط عمل على الأقل، 7 أيام سيرًا', krasnov: 'Krasnov — 10 نقاط عمل على الأقل، 10 أيام سيرًا',
      mJet: 'الخروج من المعسكر: محاولة واحدة يوميًا، نجاح 80 % (95 % إذا رُشي حارس).',
      tEvasionKo: 'هروب فاشل', mEvasionKo: 'أمسك بك الحراس: ليلتان في الزنزانة التأديبية. تبقى عقوبتك كاملة.',
      tRefus: 'رُفض الأمر', tReseau: 'تعذر الوصول إلى الخادم', mReseau: 'لا رد من الخادم؛ لم يُطبق أي شيء على الشاشة.',
      r: {
        goulag_non_active: 'لم يُفتح الغولاغ بعد.', deja_dormi_aujourdhui: 'لقد نمت اليوم بالفعل.', deja_mange: 'لقد أكلت اليوم بالفعل.',
        sanction_cachot_en_cours: 'أنت تقضي عقوبة في الزنزانة التأديبية.', sanction_terminee: 'انتهت عقوبتك: العودة إلى المهجع.',
        detenu_epuise: 'هذا السجين منهك جدًا (نقطة عمل واحدة أو أقل).', reserve_juge_sovarka: 'مخصص لقاضٍ من Sovarka.',
        juge_absent_du_bureau: 'يجب أن يكون القاضي حاضرًا في هذا المكتب.',
        gardien_deja_corrompu: 'هناك حارس في صفك بالفعل.', cadeau_obligatoire: 'اختر غرضًا تقدمه للحارس.', objet_protege: 'لا يمكن التخلي عن هذا الغرض.',
        tentative_deja_faite_aujourdhui: 'محاولة هروب واحدة فقط يوميًا.', pa_insuffisants_depart: 'نقاط العمل غير كافية لهذه الرحلة.',
        non_detenu_goulag: 'لست سجينًا في الغولاغ.', detenu_introuvable: 'لم يُعثر على السجين.',
        reserve_habilite_entree: 'مخصص للأشخاص المأذون لهم الحاضرين.', reserve_habilite_bureau: 'مخصص للأشخاص المأذون لهم الحاضرين.',
        reserve_habilite_mirador: 'مخصص للأشخاص المأذون لهم الحاضرين.', objet_introuvable: 'لم يُعثر على الغرض في مخزونك.',
        pas_au_dortoir: 'في المهجع فقط.', pas_au_mirador: 'في برج المراقبة فقط.', pa_insuffisants: 'نقاط العمل غير كافية لهذا الأمر.', requete_deja_utilisee: 'سبق أن استخدم شخص آخر هذا الطلب؛ أعد المحاولة.', defaut: 'رفض الخادم هذا الأمر.'
      }
    },
    'pt-BR': {
      oListe: 'Consultar a lista de presos', oDormir: 'Dormir', oManger: 'Comer', oRegistre: 'Consultar o registro',
      oInterroger: 'Interrogar um preso', oSanction: 'Aplicar uma sanção disciplinar', oCorrompre: 'Subornar o guarda',
      oIncidents: 'Consultar os incidentes do campo', oMirador: 'Ir à torre de vigia', oDortoir: 'Voltar ao dormitório', oEntree: 'Ir à entrada',
      dListe: 'Presos, dias de pena restantes e situação no último controle da meia-noite.',
      dDormirDortoir: '+1 PA. Um sono por dia cumpre um dia de pena.', dDormirCachot: '0 PA. Cumpre um dia de pena e uma noite de solitária.',
      dManger: '+1 PA. Uma refeição por dia.', dRegistre: 'Histórico dos presos: tribunal, entrada, saída, interrogatórios.',
      dInterroger: '−7 PA para o preso (nunca abaixo de 1). Um segredo pode ser revelado ao juiz dele.',
      dSanction: 'Somente com o juiz presente: uma ou duas noites de solitária.', dCorrompre: 'Preparar uma fuga oferecendo um objeto ao guarda. Chance: 80 % + 2 por ponto de Carisma (no máximo 90 %).',
      dIncidents: 'Fugas, sanções e ausências constatadas à meia-noite.', dDeplacer: 'Deslocamento vigiado, nem soltura nem transporte.', mCorruptionRegle: 'Cada tentativa exige um objeto do seu inventário, entregue ao guarda mesmo em caso de fracasso. Várias tentativas por dia são possíveis.',
      sDetenu: 'Preso', sAttente: 'Soltura pendente', sFuite: 'Foragido',
      cNom: 'Nome', cJours: 'Dias restantes', cStatut: 'Situação', cTribunal: 'Tribunal', cEntree: 'Entrada', cSortie: 'Saída efetiva', cInterro: 'Interrogatórios',
      evadeLe: 'Fugiu em {d}', inconnu: 'Desconhecido', tribunalDe: 'Tribunal de {v}', aucunDetenu: 'Nenhum preso.', aucunIncident: 'Nenhum incidente.',
      iEvasionOk: 'Fuga bem-sucedida', iEvasionKo: 'Fuga fracassada', iSanction: 'Sanção disciplinar', iAbsence: 'Ausência constatada à meia-noite', nuits: '{n} noite(s)',
      choisirDetenu: 'Escolha um preso', nuit1: 'Uma noite', nuit2: 'Duas noites', confirmer: 'Confirmar', annuler: 'Cancelar', fermer: 'Fechar',
      sansObjet: 'Você não tem nenhum objeto para oferecer.', proposerObjet: 'Objeto oferecido ao guarda',
      tDormi: 'Sono', mDormi: '+{gain} PA. Dias de pena restantes: {jours}.', tLibere: 'Soltura',
      mLibere: 'Sua pena foi cumprida. Você está livre, diante da entrada do campo.', tMange: 'Refeição', mMange: '+1 PA.',
      tInterro: 'Interrogatório', mInterroSecret: 'O preso falou ({p} %). O fato revelado foi enviado ao juiz dele.',
      mInterroRien: 'O preso cedeu ({p} %), mas não tinha mais segredos.', mInterroEchec: 'O preso não revelou nada ({p} %).',
      tSanction: 'Sanção', mSanction: '{nom}: {n} noite(s) de solitária.', tCorruption: 'Suborno',
      mCorruptionOk: 'O guarda aceita: sua próxima tentativa de fuga será mais fácil.', mCorruptionKo: 'O guarda recusa.',
      tDepart: 'Fugir a pé', mDestination: 'Escolha seu destino. A partida é irreversível.',
      starovka: 'Starovka — mínimo de 7 PA, 7 dias de caminhada', krasnov: 'Krasnov — mínimo de 10 PA, 10 dias de caminhada',
      mJet: 'Saída do campo: uma tentativa por dia, 80 % de sucesso (95 % se um guarda foi subornado).',
      tEvasionKo: 'Fuga fracassada', mEvasionKo: 'Os guardas pegam você: duas noites de solitária. Sua pena continua integral.',
      tRefus: 'Ordem recusada', tReseau: 'Servidor inacessível', mReseau: 'Sem resposta do servidor; nada foi aplicado na tela.',
      r: {
        goulag_non_active: 'O gulag ainda não está aberto.', deja_dormi_aujourdhui: 'Você já dormiu hoje.', deja_mange: 'Você já comeu hoje.',
        sanction_cachot_en_cours: 'Você está cumprindo uma sanção na solitária.', sanction_terminee: 'Sua sanção terminou: de volta ao dormitório.',
        detenu_epuise: 'Este preso está exausto demais (1 PA ou menos).', reserve_juge_sovarka: 'Reservado a um juiz de Sovarka.',
        juge_absent_du_bureau: 'O juiz precisa estar presente neste escritório.',
        gardien_deja_corrompu: 'Um guarda já está do seu lado.', cadeau_obligatoire: 'Escolha um objeto para oferecer ao guarda.', objet_protege: 'Este objeto não pode ser dado.',
        tentative_deja_faite_aujourdhui: 'Apenas uma tentativa de fuga por dia.', pa_insuffisants_depart: 'PA insuficientes para este trajeto.',
        non_detenu_goulag: 'Você não é preso do gulag.', detenu_introuvable: 'Preso não encontrado.',
        reserve_habilite_entree: 'Reservado às pessoas autorizadas presentes.', reserve_habilite_bureau: 'Reservado às pessoas autorizadas presentes.',
        reserve_habilite_mirador: 'Reservado às pessoas autorizadas presentes.', objet_introuvable: 'Objeto não encontrado no seu inventário.',
        pas_au_dortoir: 'Somente no dormitório.', pas_au_mirador: 'Somente na torre de vigia.', pa_insuffisants: 'PA insuficientes para esta ordem.', requete_deja_utilisee: 'Este pedido já foi usado por outra pessoa; recomece.', defaut: 'O servidor recusou esta ordem.'
      }
    },
    de: {
      oListe: 'Häftlingsliste einsehen', oDormir: 'Schlafen', oManger: 'Essen', oRegistre: 'Register einsehen', oInterroger: 'Einen Häftling verhören',
      oSanction: 'Disziplinarstrafe verhängen', oCorrompre: 'Den Wächter bestechen', oIncidents: 'Lagervorfälle einsehen',
      oMirador: 'Zum Wachturm gehen', oDortoir: 'Zur Baracke zurückkehren', oEntree: 'Zum Eingang gehen',
      dListe: 'Häftlinge, verbleibende Straftage und Status bei der letzten Mitternachtskontrolle.',
      dDormirDortoir: '+1 AP. Ein Schlaf pro Tag verbüßt einen Straftag.', dDormirCachot: '0 AP. Verbüßt einen Straftag und eine Nacht Arrestzelle.',
      dManger: '+1 AP. Eine Mahlzeit pro Tag.', dRegistre: 'Häftlingsverlauf: Gericht, Eintritt, Entlassung, Verhöre.',
      dInterroger: '−7 AP für den Häftling (nie unter 1). Ein Geheimnis kann seinem Richter mitgeteilt werden.',
      dSanction: 'Nur bei anwesendem Richter: eine oder zwei Nächte Arrestzelle.', dCorrompre: 'Eine Flucht vorbereiten, indem Sie dem Wächter einen Gegenstand anbieten. Chance: 80 % + 2 pro Charisma-Punkt (höchstens 90 %).',
      dIncidents: 'Fluchten, Strafen und um Mitternacht festgestellte Abwesenheiten.', dDeplacer: 'Bewachte Bewegung, weder Entlassung noch Transport.', mCorruptionRegle: 'Jeder Versuch erfordert einen Gegenstand aus Ihrem Inventar, der auch bei Misserfolg beim Wächter bleibt. Mehrere Versuche pro Tag sind möglich.',
      sDetenu: 'Häftling', sAttente: 'Entlassung ausstehend', sFuite: 'Auf der Flucht',
      cNom: 'Name', cJours: 'Verbleibende Tage', cStatut: 'Status', cTribunal: 'Gericht', cEntree: 'Eintritt', cSortie: 'Tatsächliche Entlassung', cInterro: 'Verhöre',
      evadeLe: 'Geflohen am {d}', inconnu: 'Unbekannt', tribunalDe: 'Gericht von {v}', aucunDetenu: 'Keine Häftlinge.', aucunIncident: 'Keine Vorfälle.',
      iEvasionOk: 'Gelungene Flucht', iEvasionKo: 'Gescheiterte Flucht', iSanction: 'Disziplinarstrafe', iAbsence: 'Abwesenheit um Mitternacht festgestellt', nuits: '{n} Nacht/Nächte',
      choisirDetenu: 'Häftling wählen', nuit1: 'Eine Nacht', nuit2: 'Zwei Nächte', confirmer: 'Bestätigen', annuler: 'Abbrechen', fermer: 'Schließen',
      sansObjet: 'Sie haben keinen Gegenstand anzubieten.', proposerObjet: 'Dem Wächter angebotener Gegenstand',
      tDormi: 'Schlaf', mDormi: '+{gain} AP. Verbleibende Straftage: {jours}.', tLibere: 'Entlassung',
      mLibere: 'Ihre Strafe ist verbüßt. Sie sind frei, vor dem Lagereingang.', tMange: 'Mahlzeit', mMange: '+1 AP.',
      tInterro: 'Verhör', mInterroSecret: 'Der Häftling hat geredet ({p} %). Die enthüllte Tatsache geht an seinen Richter.',
      mInterroRien: 'Der Häftling gab nach ({p} %), hatte aber kein Geheimnis mehr.', mInterroEchec: 'Der Häftling hat nichts verraten ({p} %).',
      tSanction: 'Strafe', mSanction: '{nom}: {n} Nacht/Nächte Arrestzelle.', tCorruption: 'Bestechung',
      mCorruptionOk: 'Der Wächter willigt ein: Ihr nächster Fluchtversuch wird leichter.', mCorruptionKo: 'Der Wächter lehnt ab.',
      tDepart: 'Zu Fuß fliehen', mDestination: 'Wählen Sie Ihr Ziel. Der Aufbruch ist unumkehrbar.',
      starovka: 'Starovka — mindestens 7 AP, 7 Tage Fußmarsch', krasnov: 'Krasnov — mindestens 10 AP, 10 Tage Fußmarsch',
      mJet: 'Verlassen des Lagers: ein Versuch pro Tag, 80 % Erfolg (95 %, wenn ein Wächter bestochen wurde).',
      tEvasionKo: 'Gescheiterte Flucht', mEvasionKo: 'Die Wachen fassen Sie: zwei Nächte Arrestzelle. Ihre Strafe bleibt vollständig.',
      tRefus: 'Befehl abgelehnt', tReseau: 'Server nicht erreichbar', mReseau: 'Keine Antwort des Servers; auf dem Bildschirm wurde nichts angewendet.',
      r: {
        goulag_non_active: 'Der Gulag ist noch nicht geöffnet.', deja_dormi_aujourdhui: 'Sie haben heute schon geschlafen.', deja_mange: 'Sie haben heute schon gegessen.',
        sanction_cachot_en_cours: 'Sie verbüßen eine Strafe in der Arrestzelle.', sanction_terminee: 'Ihre Strafe ist beendet: zurück in die Baracke.',
        detenu_epuise: 'Dieser Häftling ist zu erschöpft (1 AP oder weniger).', reserve_juge_sovarka: 'Nur für einen Richter von Sovarka.',
        juge_absent_du_bureau: 'Der Richter muss in diesem Büro anwesend sein.',
        gardien_deja_corrompu: 'Ein Wächter ist bereits auf Ihrer Seite.', cadeau_obligatoire: 'Wählen Sie einen Gegenstand für den Wächter.', objet_protege: 'Dieser Gegenstand kann nicht verschenkt werden.',
        tentative_deja_faite_aujourdhui: 'Nur ein Fluchtversuch pro Tag.', pa_insuffisants_depart: 'Nicht genug AP für diese Strecke.',
        non_detenu_goulag: 'Sie sind kein Häftling des Gulags.', detenu_introuvable: 'Häftling nicht gefunden.',
        reserve_habilite_entree: 'Nur für anwesende befugte Personen.', reserve_habilite_bureau: 'Nur für anwesende befugte Personen.',
        reserve_habilite_mirador: 'Nur für anwesende befugte Personen.', objet_introuvable: 'Gegenstand nicht im Inventar gefunden.',
        pas_au_dortoir: 'Nur in der Baracke.', pas_au_mirador: 'Nur auf dem Wachturm.', pa_insuffisants: 'Nicht genug AP für diesen Befehl.', requete_deja_utilisee: 'Diese Anfrage wurde bereits von jemand anderem verwendet; bitte neu beginnen.', defaut: 'Der Server hat diesen Befehl abgelehnt.'
      }
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
  function dateCourte(iso) {
    if (!iso) return '—';
    try { return new Date(iso).toLocaleDateString(langue(), { day: '2-digit', month: '2-digit', year: 'numeric' }); }
    catch (_) { return String(iso).slice(0, 10); }
  }
  function nomVille(code) {
    const v = code && typeof WORLD !== 'undefined' && WORLD.soviet && WORLD.soviet[code];
    return v && v.name ? v.name : null;
  }

  let occupe = false;
  async function rpc(nom, params) {
    if (typeof sbRpcVerdict !== 'function') return null;
    try { return await sbRpcVerdict(nom, params || {}); } catch (_) { return null; }
  }
  async function relire() {
    if (typeof sbLoadPersonnage === 'function') await sbLoadPersonnage().catch(() => null);
    if (typeof updateUI === 'function') updateUI();
  }
  async function executer(nom, params, succes) {
    if (occupe) return null;
    occupe = true;
    try {
      const v = await rpc(nom, params);
      if (!v) { toast(t('tReseau'), t('mReseau'), false); return null; }
      if (v.ok !== true) {
        if (v.raison === 'evasion_echouee') toast(t('tEvasionKo'), t('mEvasionKo'), false);
        else toast(t('tRefus'), motif(v), false);
        if (v.room || v.raison === 'evasion_echouee') await relire();
        return v;
      }
      if (succes) succes(v);
      await relire();
      return v;
    } finally { occupe = false; }
  }

  // ---- Fenêtre commune (classes cpj-* de la charte) ----
  function ouvrir(titre, corps) {
    const t1 = document.getElementById('postes-modal-title'), b = document.getElementById('postes-body'),
          m = document.getElementById('modal-postes');
    if (!t1 || !b || !m) return null;
    t1.textContent = titre;
    b.innerHTML = '<div class="cpj-dialogue goulag-ordres" dir="auto">' + corps + '</div>';
    m.classList.add('open');
    return b;
  }
  function fermer() {
    if (typeof fermerModalPostes === 'function') fermerModalPostes();
    else document.getElementById('modal-postes')?.classList.remove('open');
  }
  function tableau(entetes, lignes) {
    // Mise en page seule (aucune couleur) : défilement horizontal sur téléphone, sens d'écriture respecté.
    const cellule = 'padding:.35rem .5rem;text-align:start;vertical-align:top;white-space:nowrap';
    return '<div class="goulag-ordres-tableau" role="region" tabindex="0" style="max-width:100%;overflow-x:auto">'
      + '<table style="border-collapse:collapse;width:100%"><thead><tr>'
      + entetes.map(e => '<th scope="col" style="' + cellule + '">' + echapper(e) + '</th>').join('') + '</tr></thead><tbody>'
      + lignes.map(l => '<tr>' + l.map(c => '<td style="' + cellule + '">' + c + '</td>').join('') + '</tr>').join('') + '</tbody></table></div>';
  }
  function libelleStatut(s) { return t(s === 'en_fuite' ? 'sFuite' : s === 'liberation_en_attente' ? 'sAttente' : 'sDetenu'); }

  // ---- Entrée ----
  async function consulterListe() {
    const v = await executer('sovarka_goulag_liste_detenus', {});
    if (!v || v.ok !== true) return;
    const lignes = (v.detenus || []).map(d => [echapper(d.nom), echapper(d.jours_restants), echapper(libelleStatut(d.statut))]);
    ouvrir(t('oListe'), lignes.length ? tableau([t('cNom'), t('cJours'), t('cStatut')], lignes)
      : '<p class="cpj-note">' + echapper(t('aucunDetenu')) + '</p>');
  }

  // ---- Dortoir et cachot ----
  function dormir() {
    return executer('sovarka_goulag_dormir', {}, v => {
      if (v.libere) toast(t('tLibere'), t('mLibere'), true);
      else toast(t('tDormi'), t('mDormi', { gain: v.gain, jours: v.jours_restants }), true);
      if (typeof v.pa === 'number' && typeof state !== 'undefined') state.pa = v.pa;
    });
  }
  function manger() {
    return executer('sovarka_goulag_manger', {}, v => {
      toast(t('tMange'), t('mMange'), true);
      if (typeof v.pa === 'number' && typeof state !== 'undefined') state.pa = v.pa;
    });
  }
  function aller(piece) { return executer('sovarka_goulag_detenu_aller', { p_piece: piece }); }

  // ---- Bureau du chef ----
  async function consulterRegistre() {
    const v = await executer('sovarka_goulag_registre_consulter', {});
    if (!v || v.ok !== true) return;
    const lignes = (v.registre || []).map(r => {
      const ville = r.tribunal_pays === 'soviet' ? nomVille(r.tribunal_ville) : null;
      const sortie = r.sortie_le ? dateCourte(r.sortie_le) : (r.evasion_le ? t('evadeLe', { d: dateCourte(r.evasion_le) }) : '—');
      return [echapper(r.nom), echapper(ville ? t('tribunalDe', { v: ville }) : t('inconnu')),
              echapper(dateCourte(r.entree_le)), echapper(sortie), echapper(r.interrogatoires)];
    });
    ouvrir(t('oRegistre'), lignes.length
      ? tableau([t('cNom'), t('cTribunal'), t('cEntree'), t('cSortie'), t('cInterro')], lignes)
      : '<p class="cpj-note">' + echapper(t('aucunDetenu')) + '</p>');
  }

  async function choisirDetenu(titre, extra, valider) {
    const v = await executer('sovarka_goulag_detenus_choisir', {});
    if (!v || v.ok !== true) return;
    const liste = v.detenus || [];
    if (!liste.length) { ouvrir(titre, '<p class="cpj-note">' + echapper(t('aucunDetenu')) + '</p>'); return; }
    const corps = '<label class="cpj-note" for="goulag-ordres-detenu">' + echapper(t('choisirDetenu')) + '</label>'
      + '<select id="goulag-ordres-detenu" class="cpj-champ">' + liste.map(d => '<option value="' + echapper(d.nom) + '">' + echapper(d.nom) + '</option>').join('') + '</select>'
      + (extra || '')
      + '<div class="goulag-ordres-actions" style="display:flex;flex-wrap:wrap;gap:.6rem;margin-top:.8rem"><button type="button" class="cpj-touche cpj-primaire" id="goulag-ordres-ok">' + echapper(t('confirmer')) + '</button>'
      + '<button type="button" class="cpj-touche" id="goulag-ordres-annuler">' + echapper(t('annuler')) + '</button></div>';
    const b = ouvrir(titre, corps); if (!b) return;
    const ok = b.querySelector('#goulag-ordres-ok');
    b.querySelector('#goulag-ordres-annuler').addEventListener('click', fermer);
    // Une seule requête par confirmation : la clé est créée à l'ouverture, un double clic la rejoue.
    const cle = requete();
    ok.addEventListener('click', async () => {
      ok.disabled = true;
      const nom = b.querySelector('#goulag-ordres-detenu').value;
      try { await valider(nom, b, cle); } finally { ok.disabled = false; }
    });
  }

  function interroger() {
    return choisirDetenu(t('oInterroger'), '', async (nom, _b, cle) => {
      const v = await executer('sovarka_goulag_interroger', { p_detenu: nom, p_requete: cle });
      if (!v || v.ok !== true) return;
      if (typeof v.pa === 'number' && typeof state !== 'undefined') state.pa = v.pa;
      fermer();
      const msg = v.reussi ? (v.revelation ? 'mInterroSecret' : 'mInterroRien') : 'mInterroEchec';
      toast(t('tInterro'), t(msg, { p: v.probabilite }), v.reussi === true);
    });
  }

  function sanctionner() {
    const choix = '<fieldset class="goulag-ordres-choix" style="display:flex;flex-direction:column;gap:.4rem;border:0;padding:0;margin:.6rem 0"><label><input type="radio" name="goulag-ordres-nuits" value="1" checked> '
      + echapper(t('nuit1')) + '</label><label><input type="radio" name="goulag-ordres-nuits" value="2"> ' + echapper(t('nuit2')) + '</label></fieldset>';
    return choisirDetenu(t('oSanction'), choix, async (nom, b, cle) => {
      const nuits = Number(b.querySelector('input[name="goulag-ordres-nuits"]:checked')?.value || 0);
      const v = await executer('sovarka_goulag_sanctionner', { p_detenu: nom, p_nuits: nuits, p_requete: cle });
      if (!v || v.ok !== true) return;
      if (typeof v.pa === 'number' && typeof state !== 'undefined') state.pa = v.pa;
      fermer();
      toast(t('tSanction'), t('mSanction', { nom: v.detenu, n: v.nuits || nuits }), true);
    });
  }

  // ---- Mirador ----
  function corrompre() {
    // Un cadeau est obligatoire à chaque tentative : aucune option « sans objet ». L'inventaire affiché
    // n'est qu'un choix ; le serveur vérifie la présence réelle de l'objet et le consomme.
    const inv = (typeof state !== 'undefined' && Array.isArray(state.inventory)) ? state.inventory : [];
    if (!inv.length) {
      ouvrir(t('oCorrompre'), '<p class="cpj-note">' + echapper(t('dCorrompre')) + '</p><p class="cpj-note">' + echapper(t('sansObjet')) + '</p>');
      return;
    }
    const options = inv.map((o, i) => '<option value="' + i + '">' + echapper(o.name || o.stackKey || o.type || ('#' + i))
      + (Number(o.qty) > 1 ? ' ×' + echapper(o.qty) : '') + '</option>').join('');
    const corps = '<p class="cpj-note">' + echapper(t('dCorrompre')) + '</p>'
      + '<p class="cpj-note">' + echapper(t('mCorruptionRegle')) + '</p>'
      + '<label class="cpj-note" for="goulag-ordres-objet">' + echapper(t('proposerObjet')) + '</label>'
      + '<select id="goulag-ordres-objet" class="cpj-champ">' + options + '</select>'
      + '<div class="goulag-ordres-actions" style="display:flex;flex-wrap:wrap;gap:.6rem;margin-top:.8rem"><button type="button" class="cpj-touche cpj-primaire" id="goulag-ordres-ok">' + echapper(t('confirmer')) + '</button>'
      + '<button type="button" class="cpj-touche" id="goulag-ordres-annuler">' + echapper(t('annuler')) + '</button></div>';
    const b = ouvrir(t('oCorrompre'), corps); if (!b) return;
    const cle = requete(); const ok = b.querySelector('#goulag-ordres-ok');
    b.querySelector('#goulag-ordres-annuler').addEventListener('click', fermer);
    ok.addEventListener('click', async () => {
      ok.disabled = true;
      try {
        const idx = Number(b.querySelector('#goulag-ordres-objet').value);
        const objet = inv[idx];
        if (!objet) { toast(t('tRefus'), motif({ raison: 'cadeau_obligatoire' }), false); return; }
        const v = await executer('sovarka_goulag_corrompre', { p_requete: cle, p_index: idx,
          p_signature: { name: objet.name || '', type: objet.type || '', stackKey: objet.stackKey || '' } });
        if (!v || v.ok !== true) return;
        if (v.inventory && typeof sbAdopterInventaireServeur === 'function') sbAdopterInventaireServeur(v);
        fermer();
        toast(t('tCorruption'), t(v.reussi ? 'mCorruptionOk' : 'mCorruptionKo'), v.reussi === true);
      } finally { ok.disabled = false; }
    });
  }

  async function consulterIncidents() {
    const v = await executer('sovarka_goulag_incidents_consulter', {});
    if (!v || v.ok !== true) return;
    const natures = { evasion_reussie: 'iEvasionOk', evasion_echouee: 'iEvasionKo', sanction_disciplinaire: 'iSanction', absence_minuit: 'iAbsence' };
    const lignes = (v.incidents || []).map(i => [echapper(dateCourte(i.survenu_le)), echapper(t(natures[i.nature] || 'inconnu')),
      echapper(i.nom) + (i.nuits ? ' — ' + echapper(t('nuits', { n: i.nuits })) : '')]);
    ouvrir(t('oIncidents'), lignes.length ? tableau(['', t('cStatut'), t('cNom')], lignes)
      : '<p class="cpj-note">' + echapper(t('aucunIncident')) + '</p>');
  }

  // ---- « S'enfuir à pied » : départ du moteur #1020, avec le jet de sortie du serveur ----
  function choisirDepart() {
    const detenu = typeof state !== 'undefined' && !!state.estEmprisonne;
    const corps = '<p class="cpj-note">' + echapper(t('mDestination')) + '</p>'
      + (detenu ? '<p class="cpj-note">' + echapper(t('mJet')) + '</p>' : '')
      + '<fieldset class="goulag-ordres-choix" style="display:flex;flex-direction:column;gap:.4rem;border:0;padding:0;margin:.6rem 0"><label><input type="radio" name="goulag-ordres-dest" value="starovka" checked> ' + echapper(t('starovka')) + '</label>'
      + '<label><input type="radio" name="goulag-ordres-dest" value="krasnov"> ' + echapper(t('krasnov')) + '</label></fieldset>'
      + '<div class="goulag-ordres-actions" style="display:flex;flex-wrap:wrap;gap:.6rem;margin-top:.8rem"><button type="button" class="cpj-touche cpj-primaire" id="goulag-ordres-ok">' + echapper(t('confirmer')) + '</button>'
      + '<button type="button" class="cpj-touche" id="goulag-ordres-annuler">' + echapper(t('annuler')) + '</button></div>';
    const b = ouvrir(t('tDepart'), corps); if (!b) return;
    const ok = b.querySelector('#goulag-ordres-ok');
    b.querySelector('#goulag-ordres-annuler').addEventListener('click', fermer);
    ok.addEventListener('click', async () => {
      ok.disabled = true;
      try {
        const dest = b.querySelector('input[name="goulag-ordres-dest"]:checked')?.value;
        const v = await executer('goulag_toundra_demarrer', { p_destination: dest });
        fermer();
        if (v && v.ok === true && typeof window.goulagToundraOuvrir === 'function') await window.goulagToundraOuvrir();
      } finally { ok.disabled = false; }
    });
  }

  // ---- Ordres proposés par pièce (le serveur reste seul juge des droits) ----
  // Déclarations littérales (lues par le miroir des coûts) : seuls l'interrogatoire et la sanction
  // coûtent 1 PA (décisions de Fred du 17/11/2026). Le serveur prélève lui-même ce PA.
  const ORDRES = {
    liste: { fn: 'sovarka_goulag_liste', label: 'oListe', desc: 'dListe', pa: 0, cost: 0, icon: 'ti-list' },
    dormir: { fn: 'sovarka_goulag_dormir', label: 'oDormir', desc: 'dDormirDortoir', pa: 0, cost: 0, icon: 'ti-moon' },
    manger: { fn: 'sovarka_goulag_manger', label: 'oManger', desc: 'dManger', pa: 0, cost: 0, icon: 'ti-soup' },
    mirador: { fn: 'sovarka_goulag_mirador', label: 'oMirador', desc: 'dDeplacer', pa: 0, cost: 0, icon: 'ti-building-lighthouse' },
    dortoir: { fn: 'sovarka_goulag_dortoir', label: 'oDortoir', desc: 'dDeplacer', pa: 0, cost: 0, icon: 'ti-bed' },
    entree: { fn: 'sovarka_goulag_entree', label: 'oEntree', desc: 'dDeplacer', pa: 0, cost: 0, icon: 'ti-door-enter' },
    registre: { fn: 'sovarka_goulag_registre', label: 'oRegistre', desc: 'dRegistre', pa: 0, cost: 0, icon: 'ti-archive' },
    interroger: { fn: 'sovarka_goulag_interroger', label: 'oInterroger', desc: 'dInterroger', pa: 1, cost: 0, icon: 'ti-message-circle' },
    sanction: { fn: 'sovarka_goulag_sanction', label: 'oSanction', desc: 'dSanction', pa: 1, cost: 0, icon: 'ti-gavel' },
    corrompre: { fn: 'sovarka_goulag_corrompre', label: 'oCorrompre', desc: 'dCorrompre', pa: 0, cost: 0, icon: 'ti-coins' },
    incidents: { fn: 'sovarka_goulag_incidents', label: 'oIncidents', desc: 'dIncidents', pa: 0, cost: 0, icon: 'ti-alert-triangle' }
  };
  function ordre(cle, descAutre) {
    const d = ORDRES[cle];
    return { fn: d.fn, label: t(d.label), pa: d.pa, cost: d.cost, type: 'legal', icon: d.icon, successRate: 100, desc: t(descAutre || d.desc) };
  }
  function ordresDuLieu(buildingId, roomId, ville) {
    if (typeof state === 'undefined' || state.country !== 'soviet' || ville !== 'qhs' || buildingId !== 'qhs-prison') return [];
    // Goulag fermé ou serveur muet (plateau-goulag-ouverture.js) : aucun bouton, les ordres actuels restent.
    if (!(typeof window.goulagOuvert === 'function' && window.goulagOuvert() === true)) return [];
    const detenu = !!state.estEmprisonne;
    switch (roomId) {
      case 'entree_qhs':
        return detenu ? [ordre('dortoir'), ordre('mirador')]
                      : [ordre('liste')];
      case 'cellules_qhs':
        return detenu ? [ordre('dormir'), ordre('manger'),
                         ordre('mirador')] : [];
      case 'cachot_disciplinaire':
        return detenu ? [ordre('dormir', 'dDormirCachot')] : [];
      case 'bureau_chef':
        if (detenu) return [];
        return [ordre('registre'),
                ordre('interroger')]
          .concat(state.char?.poste?.id === 'juge' ? [ordre('sanction')] : []);
      case 'mirador':
        return detenu ? [ordre('corrompre'), ordre('dortoir'),
                         ordre('entree')]
                      : [ordre('incidents')];
      default: return [];
    }
  }

  const ROUTES = {
    sovarka_goulag_liste: consulterListe, sovarka_goulag_dormir: dormir, sovarka_goulag_manger: manger,
    sovarka_goulag_mirador: () => aller('mirador'), sovarka_goulag_dortoir: () => aller('cellules_qhs'),
    sovarka_goulag_entree: () => aller('entree_qhs'), sovarka_goulag_registre: consulterRegistre,
    sovarka_goulag_interroger: interroger, sovarka_goulag_sanction: sanctionner,
    sovarka_goulag_corrompre: corrompre, sovarka_goulag_incidents: consulterIncidents
  };

  if (typeof window !== 'undefined') {
    window.RP_ORDRES_DYNAMIQUES = window.RP_ORDRES_DYNAMIQUES || [];
    window.RP_ORDRES_DYNAMIQUES.push(ordresDuLieu);
    window.RP_GOULAG_ORDRES = ROUTES;
    window.goulagOrdresInternes = { ordresDuLieu, t, langues: LANGUES, textes: T, choisirDepart };
    // Raccord avec #1020 : « S'enfuir à pied » ouvre ce choix, qui appelle la même RPC de départ ;
    // le serveur y tranche désormais le jet de sortie du camp.
    // Les boutons d'ordre appellent doOrder (plateau-router.js, chargé en dernier) : ce module
    // l'enveloppe une fois la page chargée, sans modifier le routeur partagé avec la PR #1020.
    const raccorder = () => {
      if (typeof window.goulagToundraChoisirDepart === 'function') window.goulagToundraChoisirDepart = choisirDepart;
      const origine = window.doOrder;
      if (typeof origine === 'function' && !origine.goulagOrdresInternes) {
        const enveloppe = function (fn) {
          if (Object.prototype.hasOwnProperty.call(ROUTES, fn)) {
            if (typeof state !== 'undefined') state._ordreEnCours = fn;
            ROUTES[fn]();
            return;
          }
          return origine.apply(this, arguments);
        };
        enveloppe.goulagOrdresInternes = true;
        window.doOrder = enveloppe;
      }
    };
    if (typeof document !== 'undefined' && document.readyState === 'loading') document.addEventListener('DOMContentLoaded', raccorder);
    else raccorder();
  }
})();
