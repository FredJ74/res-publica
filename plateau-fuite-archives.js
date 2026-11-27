// =====================
// PLATEAU-FUITE-ARCHIVES.JS
// « Produire une fuite » aux Archives Gouvernementales (Républia). Décision de Fred du 27/11/2026 : sur le modèle du
// vol d'archives des centres d'écoute de Sovarka. Le serveur (archives_gouv_fuite) tire une information réelle, tranche
// le vol (témoin, détection, bagarre) et dépose l'archive dans l'inventaire ; l'écran affiche seulement le verdict.
// La fuite de Sovarka (08/11) reste dans plateau-sovarka-pouvoir.js.
// =====================
(function () {
  'use strict';

  const T = {
    fr: { titre: 'Produire une fuite', refus: 'Refusé', reseau: 'Le serveur ne répond pas. Rien n’a été prélevé.',
      ok: 'Vous avez subtilisé une pièce des archives. Elle est dans votre inventaire : « {texte} »',
      combat: 'L’archiviste vous a surpris : la bagarre éclate.', remarque: 'Échec : l’archiviste vous a remarqué.',
      rien: 'Vous n’avez rien pu emporter, et personne ne vous a vu.',
      r: { pas_sur_place: 'Vous devez être dans les Archives Gouvernementales.', reserve_titulaire_poste: 'Réservé aux titulaires d’un poste.',
        archives_vides: 'Les archives ne contiennent rien d’exploitable pour l’instant. Rien n’a été prélevé.', pa_insuffisants: 'Il vous manque des PA.',
        defaut: 'Action refusée. Rien n’a été prélevé.' } },
    en: { titre: 'Leak information', refus: 'Refused', reseau: 'The server is not responding. Nothing was charged.',
      ok: 'You slipped a document out of the archives. It is in your inventory: “{texte}”',
      combat: 'The archivist caught you: a fight breaks out.', remarque: 'Failed: the archivist noticed you.',
      rien: 'You could not take anything, and nobody saw you.',
      r: { pas_sur_place: 'You must be in the Government Archives.', reserve_titulaire_poste: 'Office holders only.',
        archives_vides: 'The archives hold nothing usable for now. Nothing was charged.', pa_insuffisants: 'You do not have enough AP.',
        defaut: 'Action refused. Nothing was charged.' } },
    es: { titre: 'Filtrar información', refus: 'Rechazado', reseau: 'El servidor no responde. No se ha cobrado nada.',
      ok: 'Ha sustraído un documento de los archivos. Está en su inventario: «{texte}»',
      combat: 'El archivero le ha sorprendido: estalla la pelea.', remarque: 'Fracaso: el archivero le ha visto.',
      rien: 'No ha podido llevarse nada, y nadie le ha visto.',
      r: { pas_sur_place: 'Debe estar en los Archivos Gubernamentales.', reserve_titulaire_poste: 'Reservado a quienes ocupan un cargo.',
        archives_vides: 'Por ahora los archivos no contienen nada aprovechable. No se ha cobrado nada.', pa_insuffisants: 'Le faltan PA.',
        defaut: 'Acción rechazada. No se ha cobrado nada.' } },
    'zh-TW': { titre: '洩露情報', refus: '已拒絕', reseau: '伺服器沒有回應。未扣除任何費用。',
      ok: '你從檔案室偷出了一份文件，它在你的物品欄中：「{texte}」',
      combat: '檔案管理員發現了你：衝突爆發。', remarque: '失敗：檔案管理員注意到你了。',
      rien: '你什麼也沒拿到，也沒有人看見你。',
      r: { pas_sur_place: '你必須在政府檔案室內。', reserve_titulaire_poste: '僅限擔任職務者。',
        archives_vides: '檔案室目前沒有可利用的東西。未扣除任何費用。', pa_insuffisants: '你的 PA 不足。',
        defaut: '操作被拒絕。未扣除任何費用。' } },
    ru: { titre: 'Организовать утечку', refus: 'Отказано', reseau: 'Сервер не отвечает. Ничего не списано.',
      ok: 'Вы вынесли документ из архива. Он в вашем инвентаре: «{texte}»',
      combat: 'Архивариус застал вас: завязалась драка.', remarque: 'Провал: архивариус вас заметил.',
      rien: 'Вам ничего не удалось унести, и никто вас не видел.',
      r: { pas_sur_place: 'Нужно находиться в Правительственном архиве.', reserve_titulaire_poste: 'Только для должностных лиц.',
        archives_vides: 'Пока в архиве нет ничего полезного. Ничего не списано.', pa_insuffisants: 'Не хватает ОД.',
        defaut: 'Действие отклонено. Ничего не списано.' } },
    ko: { titre: '정보 유출', refus: '거부됨', reseau: '서버가 응답하지 않습니다. 아무것도 차감되지 않았습니다.',
      ok: '기록 보관소에서 문서 하나를 빼냈습니다. 인벤토리에 있습니다: “{texte}”',
      combat: '기록 보관인에게 들켰습니다. 싸움이 벌어집니다.', remarque: '실패: 기록 보관인이 당신을 알아챘습니다.',
      rien: '아무것도 가져가지 못했고, 아무도 당신을 보지 못했습니다.',
      r: { pas_sur_place: '정부 기록 보관소에 있어야 합니다.', reserve_titulaire_poste: '직책 보유자 전용입니다.',
        archives_vides: '지금은 기록 보관소에 쓸 만한 것이 없습니다. 아무것도 차감되지 않았습니다.', pa_insuffisants: 'PA가 부족합니다.',
        defaut: '행동이 거부되었습니다. 아무것도 차감되지 않았습니다.' } },
    ar: { titre: 'تسريب معلومات', refus: 'مرفوض', reseau: 'الخادم لا يستجيب. لم يُخصم شيء.',
      ok: 'اختلست وثيقة من الأرشيف. إنها في مخزونك: «{texte}»',
      combat: 'فاجأك أمين الأرشيف: اندلع العراك.', remarque: 'فشل: لاحظك أمين الأرشيف.',
      rien: 'لم تتمكن من أخذ شيء، ولم يرك أحد.',
      r: { pas_sur_place: 'يجب أن تكون في الأرشيف الحكومي.', reserve_titulaire_poste: 'مخصص لأصحاب المناصب.',
        archives_vides: 'لا يحتوي الأرشيف حاليًا على شيء قابل للاستغلال. لم يُخصم شيء.', pa_insuffisants: 'تنقصك نقاط عمل.',
        defaut: 'رُفض الإجراء. لم يُخصم شيء.' } },
    'pt-BR': { titre: 'Vazar informações', refus: 'Recusado', reseau: 'O servidor não responde. Nada foi cobrado.',
      ok: 'Você surrupiou um documento dos arquivos. Ele está no seu inventário: “{texte}”',
      combat: 'O arquivista pegou você: a briga começa.', remarque: 'Falha: o arquivista percebeu você.',
      rien: 'Você não conseguiu levar nada, e ninguém viu você.',
      r: { pas_sur_place: 'Você precisa estar nos Arquivos do Governo.', reserve_titulaire_poste: 'Reservado a quem ocupa um cargo.',
        archives_vides: 'Por enquanto os arquivos não têm nada aproveitável. Nada foi cobrado.', pa_insuffisants: 'Faltam PA.',
        defaut: 'Ação recusada. Nada foi cobrado.' } },
    de: { titre: 'Informationen durchsickern lassen', refus: 'Abgelehnt', reseau: 'Der Server antwortet nicht. Nichts wurde abgebucht.',
      ok: 'Sie haben ein Dokument aus dem Archiv entwendet. Es ist in Ihrem Inventar: „{texte}“',
      combat: 'Der Archivar hat Sie erwischt: Eine Schlägerei bricht aus.', remarque: 'Fehlschlag: Der Archivar hat Sie bemerkt.',
      rien: 'Sie konnten nichts mitnehmen, und niemand hat Sie gesehen.',
      r: { pas_sur_place: 'Sie müssen im Regierungsarchiv sein.', reserve_titulaire_poste: 'Nur für Amtsinhaber.',
        archives_vides: 'Das Archiv enthält derzeit nichts Verwertbares. Nichts wurde abgebucht.', pa_insuffisants: 'Ihnen fehlen AP.',
        defaut: 'Aktion abgelehnt. Nichts wurde abgebucht.' } }
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
  function motif(v) { const l = T[langue()] || T.fr, r = v && v.raison; return (r && (l.r[r] || T.fr.r[r])) || l.r.defaut; }

  let enCours = false;
  async function produireFuiteArchives() {
    if (enCours || typeof sbRpcVerdict !== 'function') return;
    enCours = true;
    const cle = 'hg-fuite-archives:' + ((typeof state !== 'undefined' && state.char && state.char.name) || '');
    let v = null;
    try {
      let requete = null;
      try { requete = sessionStorage.getItem(cle); } catch (_) { requete = null; }
      if (!requete) { requete = crypto.randomUUID(); try { sessionStorage.setItem(cle, requete); } catch (_) { /* rien */ } }
      v = await sbRpcVerdict('archives_gouv_fuite', { p_requete: requete }).catch(() => null);
      if (v && !v.transport) { try { sessionStorage.removeItem(cle); } catch (_) { /* rien */ } }
    } finally { enCours = false; }
    if (!v) { showToast(t('titre'), t('reseau'), false); return; }
    if (v.ok !== true) { showToast(t('refus'), motif(v), false); return; }
    if (Array.isArray(v.inventory) && typeof sbAdopterInventaireServeur === 'function') sbAdopterInventaireServeur(v);
    if (typeof appliquerPaiementServeur === 'function') appliquerPaiementServeur({ pa: v.pa, liquide: v.liquide, arg: v.arg });
    if (typeof adopterEtatCrimeServeur === 'function') adopterEtatCrimeServeur(v);
    if (v.issue === 'reussite') showToast(t('titre'), t('ok', { texte: v.archive || '' }), true, true);
    else if (v.issue === 'combat') showToast(t('titre'), t('combat'), false);
    else showToast(t('titre'), t(v.remarque ? 'remarque' : 'rien'), false);
    if (typeof addJournalEntry === 'function') addJournalEntry(t('titre') + ' : ' + (v.issue === 'reussite' ? (v.archive || '') : v.issue), v.issue === 'reussite' ? 'event-good' : 'event-bad');
    if (typeof renderInventory === 'function') renderInventory();
    if (typeof updateUI === 'function') updateUI();
    if (v.issue === 'combat' && Number.isSafeInteger(Number(v.bataille)) && typeof ouvrirPanneauCombat === 'function') await ouvrirPanneauCombat(Number(v.bataille));
  }

  window.produireFuiteArchives = produireFuiteArchives;
  window.RP_FUITE_ARCHIVES_T = T;
})();
