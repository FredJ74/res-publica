// =====================
// PLATEAU-ACCESSOIRE-PERSONNALISE.JS
// « Acheter un accessoire personnalisé » à la buvette des stades (décision de Fred du 27/11/2026) : maillot, casquette ou
// écharpe du club local, personnalisé par l'acheteur ; image générée par IA (fonction Edge accessoire-personnalise, sur le
// modèle de publicite-premium) après paiement ; +10 popularité tant qu'il est revêtu. Achat ouvert à tous, à l'unité, prix
// réglé dans la page MJ. Le prestataire de paiement n'est pas choisi : à l'étape du paiement, l'écran affiche « Paiement
// bientôt disponible » et ne crée ni ne débite rien.
// =====================
(function () {
  'use strict';

  const T = {
    fr: { titre: 'Accessoire personnalisé', intro: 'Un accessoire du club {club}, personnalisé à votre demande (par exemple votre nom dans le dos). Son image est créée par IA. Revêtu, il vous rapporte +10 popularité ; un accessoire par type peut être porté, et deux objets revêtus au plus.',
      type: 'Accessoire', maillot: 'Maillot', casquette: 'Casquette', echarpe: 'Écharpe', demande: 'Votre personnalisation', demandePh: 'Ex. : « DUPONT 10 » dans le dos',
      prix: 'Prix : {prix} €, payé à l’unité.', sansPrix: 'Prix pas encore fixé.', payer: 'Payer et créer mon accessoire', bientot: 'Paiement bientôt disponible',
      bientotTexte: 'Rien n’a été débité ni créé.', court: 'Décrivez votre personnalisation (3 caractères au moins).', refus: 'Refusé', reseau: 'Le serveur ne répond pas.',
      r: { pas_sur_place: 'Rendez-vous à la buvette du stade.', club_local_introuvable: 'Pas de club dans cette ville.', defaut: 'Action refusée.' } },
    en: { titre: 'Custom accessory', intro: 'An accessory of the {club} club, customised as you wish (for instance your name on the back). Its image is created by AI. Worn, it gives you +10 popularity; one accessory per type can be worn, and two worn items at most.',
      type: 'Accessory', maillot: 'Jersey', casquette: 'Cap', echarpe: 'Scarf', demande: 'Your customisation', demandePh: 'E.g. “SMITH 10” on the back',
      prix: 'Price: €{prix}, paid per item.', sansPrix: 'Price not set yet.', payer: 'Pay and create my accessory', bientot: 'Payment coming soon',
      bientotTexte: 'Nothing was charged or created.', court: 'Describe your customisation (at least 3 characters).', refus: 'Refused', reseau: 'The server is not responding.',
      r: { pas_sur_place: 'Go to the stadium snack bar.', club_local_introuvable: 'No club in this city.', defaut: 'Action refused.' } },
    es: { titre: 'Accesorio personalizado', intro: 'Un accesorio del club {club}, personalizado a su gusto (por ejemplo su nombre en la espalda). Su imagen la crea una IA. Puesto, le da +10 de popularidad; se puede llevar un accesorio por tipo y dos objetos puestos como máximo.',
      type: 'Accesorio', maillot: 'Camiseta', casquette: 'Gorra', echarpe: 'Bufanda', demande: 'Su personalización', demandePh: 'Ej.: «GARCÍA 10» en la espalda',
      prix: 'Precio: {prix} €, pagado por unidad.', sansPrix: 'Precio aún no fijado.', payer: 'Pagar y crear mi accesorio', bientot: 'Pago disponible pronto',
      bientotTexte: 'No se ha cobrado ni creado nada.', court: 'Describa su personalización (al menos 3 caracteres).', refus: 'Rechazado', reseau: 'El servidor no responde.',
      r: { pas_sur_place: 'Vaya al bar del estadio.', club_local_introuvable: 'No hay club en esta ciudad.', defaut: 'Acción rechazada.' } },
    'zh-TW': { titre: '個人化配件', intro: '{club} 俱樂部的配件，依你的要求客製（例如背後印上你的名字），圖像由 AI 生成。穿戴時人氣 +10；每種配件可穿戴一件，同時最多穿戴兩件物品。',
      type: '配件', maillot: '球衣', casquette: '棒球帽', echarpe: '圍巾', demande: '你的客製內容', demandePh: '例如：背後印「王大明 10」',
      prix: '價格：{prix} 歐元，按件付費。', sansPrix: '價格尚未訂定。', payer: '付款並製作我的配件', bientot: '付款功能即將開放',
      bientotTexte: '未扣款，也未製作任何東西。', court: '請描述你的客製內容（至少 3 個字元）。', refus: '已拒絕', reseau: '伺服器沒有回應。',
      r: { pas_sur_place: '請前往球場小賣部。', club_local_introuvable: '這座城市沒有俱樂部。', defaut: '操作被拒絕。' } },
    ru: { titre: 'Именной аксессуар', intro: 'Аксессуар клуба {club}, сделанный по вашему желанию (например, ваше имя на спине). Изображение создаёт ИИ. Надетый, он даёт +10 популярности; можно носить по одному аксессуару каждого типа и не более двух надетых предметов.',
      type: 'Аксессуар', maillot: 'Футболка', casquette: 'Кепка', echarpe: 'Шарф', demande: 'Ваша надпись', demandePh: 'Напр.: «ИВАНОВ 10» на спине',
      prix: 'Цена: {prix} €, оплата за штуку.', sansPrix: 'Цена ещё не установлена.', payer: 'Оплатить и создать аксессуар', bientot: 'Оплата скоро будет доступна',
      bientotTexte: 'Ничего не списано и не создано.', court: 'Опишите надпись (не менее 3 символов).', refus: 'Отказано', reseau: 'Сервер не отвечает.',
      r: { pas_sur_place: 'Пройдите в буфет стадиона.', club_local_introuvable: 'В этом городе нет клуба.', defaut: 'Действие отклонено.' } },
    ko: { titre: '맞춤 액세서리', intro: '{club} 클럽의 액세서리를 원하는 대로 맞춤 제작합니다(예: 등에 이름). 이미지는 AI가 만듭니다. 착용하면 인기 +10이며, 종류별로 하나씩, 동시에 최대 두 개의 물건만 착용할 수 있습니다.',
      type: '액세서리', maillot: '유니폼', casquette: '모자', echarpe: '머플러', demande: '맞춤 내용', demandePh: '예: 등에 “KIM 10”',
      prix: '가격: {prix}유로, 개당 결제.', sansPrix: '가격이 아직 정해지지 않았습니다.', payer: '결제하고 액세서리 만들기', bientot: '결제 기능 곧 제공',
      bientotTexte: '아무것도 결제되거나 만들어지지 않았습니다.', court: '맞춤 내용을 3자 이상 적어 주세요.', refus: '거부됨', reseau: '서버가 응답하지 않습니다.',
      r: { pas_sur_place: '경기장 매점으로 가세요.', club_local_introuvable: '이 도시에는 클럽이 없습니다.', defaut: '행동이 거부되었습니다.' } },
    ar: { titre: 'إكسسوار مخصّص', intro: 'إكسسوار لنادي {club}، مخصّص حسب طلبك (مثلًا اسمك على الظهر). تُنشئ صورته أداة ذكاء اصطناعي. عند ارتدائه يمنحك +10 شعبية؛ يمكن ارتداء إكسسوار واحد من كل نوع، وغرضين مرتديين على الأكثر.',
      type: 'الإكسسوار', maillot: 'قميص', casquette: 'قبعة', echarpe: 'وشاح', demande: 'تخصيصك', demandePh: 'مثال: «أحمد 10» على الظهر',
      prix: 'السعر: {prix} يورو، يُدفع للقطعة.', sansPrix: 'لم يُحدَّد السعر بعد.', payer: 'ادفع وأنشئ إكسسواري', bientot: 'الدفع متاح قريبًا',
      bientotTexte: 'لم يُخصم شيء ولم يُنشأ شيء.', court: 'صِف تخصيصك (3 أحرف على الأقل).', refus: 'مرفوض', reseau: 'الخادم لا يستجيب.',
      r: { pas_sur_place: 'توجّه إلى مقصف الملعب.', club_local_introuvable: 'لا يوجد نادٍ في هذه المدينة.', defaut: 'رُفض الإجراء.' } },
    'pt-BR': { titre: 'Acessório personalizado', intro: 'Um acessório do clube {club}, personalizado do seu jeito (por exemplo seu nome nas costas). A imagem é criada por IA. Vestido, dá +10 de popularidade; pode-se usar um acessório por tipo e no máximo dois objetos vestidos.',
      type: 'Acessório', maillot: 'Camisa', casquette: 'Boné', echarpe: 'Cachecol', demande: 'Sua personalização', demandePh: 'Ex.: “SILVA 10” nas costas',
      prix: 'Preço: {prix} €, pago por unidade.', sansPrix: 'Preço ainda não definido.', payer: 'Pagar e criar meu acessório', bientot: 'Pagamento disponível em breve',
      bientotTexte: 'Nada foi cobrado nem criado.', court: 'Descreva sua personalização (pelo menos 3 caracteres).', refus: 'Recusado', reseau: 'O servidor não responde.',
      r: { pas_sur_place: 'Vá até o bar do estádio.', club_local_introuvable: 'Não há clube nesta cidade.', defaut: 'Ação recusada.' } },
    de: { titre: 'Personalisiertes Accessoire', intro: 'Ein Accessoire des Vereins {club}, nach Ihrem Wunsch personalisiert (zum Beispiel Ihr Name auf dem Rücken). Das Bild erstellt eine KI. Getragen bringt es +10 Beliebtheit; ein Accessoire pro Art kann getragen werden, höchstens zwei Gegenstände zugleich.',
      type: 'Accessoire', maillot: 'Trikot', casquette: 'Kappe', echarpe: 'Schal', demande: 'Ihre Personalisierung', demandePh: 'Z. B. „MÜLLER 10“ auf dem Rücken',
      prix: 'Preis: {prix} €, pro Stück bezahlt.', sansPrix: 'Preis noch nicht festgelegt.', payer: 'Bezahlen und mein Accessoire erstellen', bientot: 'Bezahlung bald verfügbar',
      bientotTexte: 'Nichts wurde abgebucht oder erstellt.', court: 'Beschreiben Sie Ihre Personalisierung (mindestens 3 Zeichen).', refus: 'Abgelehnt', reseau: 'Der Server antwortet nicht.',
      r: { pas_sur_place: 'Gehen Sie zum Stadionkiosk.', club_local_introuvable: 'In dieser Stadt gibt es keinen Verein.', defaut: 'Aktion abgelehnt.' } }
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
  function echapper(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  }

  async function ouvrirAccessoirePersonnalise() {
    let v = null;
    if (typeof sbRpcVerdict === 'function') { try { v = await sbRpcVerdict('accessoire_personnalise_offre', {}); } catch (_) { v = null; } }
    if (!v) { showToast(t('titre'), t('reseau'), false); return; }
    if (v.ok !== true) { showToast(t('refus'), motif(v), false); return; }
    const t1 = document.getElementById('postes-modal-title'), b = document.getElementById('postes-body'), m = document.getElementById('modal-postes');
    if (!t1 || !b || !m) return;
    const prix = Number.isInteger(v.prix_centimes) ? (v.prix_centimes / 100).toFixed(2).replace('.', langue() === 'en' ? '.' : ',') : null;
    t1.textContent = t('titre');
    b.innerHTML = '<div class="cpj-dialogue accessoire-personnalise" dir="auto"><p class="cpj-note">' + echapper(t('intro', { club: v.club || '' })) + '</p>'
      + '<label class="cpj-note">' + echapper(t('type')) + ' <select id="acc-perso-type" class="cpj-champ">'
      + ['maillot', 'casquette', 'echarpe'].map(x => '<option value="' + x + '">' + echapper(t(x)) + '</option>').join('') + '</select></label>'
      + '<label class="cpj-note" style="display:block;margin-top:.5rem">' + echapper(t('demande'))
      + ' <input id="acc-perso-demande" class="cpj-champ" maxlength="300" style="width:100%" placeholder="' + echapper(t('demandePh')) + '"></label>'
      + '<p class="cpj-note">' + echapper(prix ? t('prix', { prix }) : t('sansPrix')) + '</p>'
      + '<button type="button" class="cpj-touche cpj-primaire" id="acc-perso-payer">' + echapper(t('payer')) + '</button>'
      + '<p class="cpj-note" id="acc-perso-message" style="margin-top:.6rem"></p></div>';
    m.classList.add('open');
    b.querySelector('#acc-perso-payer').addEventListener('click', () => {
      const demande = String(b.querySelector('#acc-perso-demande').value || '').trim();
      const msg = b.querySelector('#acc-perso-message');
      if (demande.length < 3) { msg.textContent = t('court'); return; }
      // Étape du paiement : prestataire non choisi (Fred, 27/11/2026). Rien n'est débité ni créé.
      msg.textContent = t('bientot') + ' — ' + t('bientotTexte');
      showToast(t('titre'), t('bientot'), false);
    });
  }

  window.ouvrirAccessoirePersonnalise = ouvrirAccessoirePersonnalise;
  window.RP_ACCESSOIRE_PERSONNALISE_T = T;
})();
