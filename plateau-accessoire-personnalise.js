// =====================
// PLATEAU-ACCESSOIRE-PERSONNALISE.JS
// « Acheter un accessoire personnalisé » à la buvette des stades : maillot, casquette ou écharpe du club local, personnalisé
// par l'acheteur ; image générée par IA (fonction Edge accessoire-personnalise, sur le modèle de publicite-premium).
// Règles de Fred (28/11/2026 ; achat, bêta et unité : 28/11 au soir) :
//   • revêtu, +5 popularité (comme l'accessoire standard), seulement dans la ville du club ; la personnalisation ne change
//     que l'apparence ;
//   • achat NON limité ; seul le port l'est : trois objets revêtus au plus, un seul accessoire de chaque type (crim_revetir) ;
//   • gratuit pendant la bêta ; abonné : renouvellement d'image de la semaine, puis achat à l'unité ; non-abonné : à l'unité
//     (écran de paiement commun, plateau-paiement.js). Le renouvellement (ou l'achat) est consommé dès que l'image est créée.
// Tout est décidé par le serveur (accessoire_personnalise_offre / _commander / _annuler) ; l'écran affiche ses réponses.
// Ce module porte aussi les textes de refus des accessoires de club standard (window.accessoireClubMotif).
// =====================
(function () {
  'use strict';

  const T = {
    fr: { titre: 'Accessoire personnalisé', intro: 'Un accessoire du club {club}, personnalisé à votre demande (par exemple votre nom dans le dos). Son image est créée par IA. Revêtu, il donne +5 popularité tant que vous êtes dans la ville du club, comme l’accessoire ordinaire : seule l’apparence change. Vous pouvez en posséder autant que vous voulez ; revêtus : trois objets au plus à la fois, dont une seule écharpe, une seule casquette et un seul maillot de club.',
      type: 'Accessoire', maillot: 'Maillot', casquette: 'Casquette', echarpe: 'Écharpe', demande: 'Votre personnalisation', demandePh: 'Ex. : « DUPONT 10 » dans le dos',
      prix: 'Prix : {prix} €, payé à l’unité.', sansPrix: 'Prix pas encore fixé.', payer: 'Payer et créer mon accessoire', bientot: 'Paiement bientôt disponible',
      bientotTexte: 'Rien n’a été débité ni créé.', court: 'Décrivez votre personnalisation (3 caractères au moins).', refus: 'Refusé', reseau: 'Le serveur ne répond pas.',
      inclus: 'Créer mon accessoire (inclus dans l’abonnement)', inclusNote: 'Inclus dans votre abonnement : cela utilise votre renouvellement d’image de la semaine.',
      hebdoPris: 'Votre renouvellement d’image de la semaine est déjà utilisé : l’accessoire s’achète à l’unité.',
      enCours: 'Commandes en cours', creerImage: 'Créer l’image', annuler: 'Annuler', voir: 'Voir l’aperçu', valider: 'Valider et recevoir', retoucher: 'Retoucher',
      retouchePh: 'Ce qu’il faut changer', travail: 'Création en cours, veuillez patienter…',
      imageIndispo: 'L’image n’a pas pu être créée ({raison}). Ce que la commande avait utilisé vous est rendu.',
      imageEchec: 'Création de l’image impossible : {raison}', livre: '{objet} rejoint votre inventaire.', annule: 'Commande annulée. Ce qu’elle avait utilisé vous est rendu.',
      standardNote: 'Revêtu, un accessoire de club donne +5 popularité tant que vous êtes dans la ville du club. Achat libre ; revêtus : une écharpe, une casquette et un maillot au plus, trois objets en tout.',
      betaBtn: 'Créer mon accessoire (gratuit pendant la bêta)', betaNote: 'Gratuit pendant la bêta, comme tout le premium.',
      uniteBtn: 'Créer mon accessoire (achat à l’unité déjà réglé)', uniteNote: 'Vous avez {n} accessoire(s) personnalisé(s) déjà payé(s) : la création en utilise un.',
      acheter: 'Acheter à l’unité', consomme: 'Dès que l’image est créée, votre renouvellement (ou votre achat) est utilisé, même si vous ne validez pas l’objet.',
      r: { achat_unite_requis: 'Il faut acheter cet accessoire à l’unité.', pas_sur_place: 'Rendez-vous à la buvette du stade.', club_local_introuvable: 'Pas de club dans cette ville.',
        renouvellement_hebdo_utilise: 'Votre renouvellement d’image de la semaine est déjà utilisé.', paiement_bientot: 'Paiement bientôt disponible : rien n’a été débité ni créé.',
        demande_invalide: 'Décrivez votre personnalisation (3 à 300 caractères).', commande_non_annulable: 'Cette commande ne peut plus être annulée.',
        commande_introuvable: 'Commande introuvable.', defaut: 'Action refusée.' } },
    en: { titre: 'Custom accessory', intro: 'An accessory of the {club} club, customised as you wish (for instance your name on the back). Its image is created by AI. Worn, it gives +5 popularity while you are in the club’s city, like the ordinary accessory: only the look changes. You may own as many as you like; worn: three items at a time at most, including only one club scarf, one cap and one jersey.',
      type: 'Accessory', maillot: 'Jersey', casquette: 'Cap', echarpe: 'Scarf', demande: 'Your customisation', demandePh: 'E.g. “SMITH 10” on the back',
      prix: 'Price: €{prix}, paid per item.', sansPrix: 'Price not set yet.', payer: 'Pay and create my accessory', bientot: 'Payment coming soon',
      bientotTexte: 'Nothing was charged or created.', court: 'Describe your customisation (at least 3 characters).', refus: 'Refused', reseau: 'The server is not responding.',
      inclus: 'Create my accessory (included in the subscription)', inclusNote: 'Included in your subscription: this uses your image renewal for the week.',
      hebdoPris: 'Your image renewal for this week is already used: the accessory is bought per item.',
      enCours: 'Orders in progress', creerImage: 'Create the image', annuler: 'Cancel', voir: 'See the preview', valider: 'Confirm and receive', retoucher: 'Retouch',
      retouchePh: 'What should change', travail: 'Creating, please wait…',
      imageIndispo: 'The image could not be created ({raison}). What the order used is given back to you.',
      imageEchec: 'The image could not be created: {raison}', livre: '{objet} is now in your inventory.', annule: 'Order cancelled. What it used is given back to you.',
      standardNote: 'Worn, a club accessory gives +5 popularity while you are in the club’s city. Buy as many as you like; worn: one scarf, one cap and one jersey at most, three items in all.',
      betaBtn: 'Create my accessory (free during the beta)', betaNote: 'Free during the beta, like all premium features.',
      uniteBtn: 'Create my accessory (single purchase already paid)', uniteNote: 'You have {n} custom accessory(ies) already paid for: creating one uses one of them.',
      acheter: 'Buy a single item', consomme: 'As soon as the image is created, your renewal (or purchase) is used, even if you do not confirm the item.',
      r: { achat_unite_requis: 'This accessory must be bought as a single item.', pas_sur_place: 'Go to the stadium snack bar.', club_local_introuvable: 'No club in this city.',
        renouvellement_hebdo_utilise: 'Your image renewal for this week is already used.', paiement_bientot: 'Payment coming soon: nothing was charged or created.',
        demande_invalide: 'Describe your customisation (3 to 300 characters).', commande_non_annulable: 'This order can no longer be cancelled.',
        commande_introuvable: 'Order not found.', defaut: 'Action refused.' } },
    es: { titre: 'Accesorio personalizado', intro: 'Un accesorio del club {club}, personalizado a su gusto (por ejemplo su nombre en la espalda). Su imagen la crea una IA. Puesto, da +5 de popularidad mientras esté en la ciudad del club, como el accesorio corriente: solo cambia el aspecto. Puede tener tantos como quiera; puestos: tres objetos a la vez como máximo, con una sola bufanda, una sola gorra y una sola camiseta de club.',
      type: 'Accesorio', maillot: 'Camiseta', casquette: 'Gorra', echarpe: 'Bufanda', demande: 'Su personalización', demandePh: 'Ej.: «GARCÍA 10» en la espalda',
      prix: 'Precio: {prix} €, pagado por unidad.', sansPrix: 'Precio aún no fijado.', payer: 'Pagar y crear mi accesorio', bientot: 'Pago disponible pronto',
      bientotTexte: 'No se ha cobrado ni creado nada.', court: 'Describa su personalización (al menos 3 caracteres).', refus: 'Rechazado', reseau: 'El servidor no responde.',
      inclus: 'Crear mi accesorio (incluido en la suscripción)', inclusNote: 'Incluido en su suscripción: usa su renovación de imagen de la semana.',
      hebdoPris: 'Su renovación de imagen de esta semana ya está usada: el accesorio se compra por unidad.',
      enCours: 'Pedidos en curso', creerImage: 'Crear la imagen', annuler: 'Cancelar', voir: 'Ver la vista previa', valider: 'Validar y recibir', retoucher: 'Retocar',
      retouchePh: 'Lo que hay que cambiar', travail: 'Creación en curso, espere…',
      imageIndispo: 'No se pudo crear la imagen ({raison}). Se le devuelve lo que el pedido había usado.',
      imageEchec: 'No se pudo crear la imagen: {raison}', livre: '{objet} entra en su inventario.', annule: 'Pedido cancelado. Se le devuelve lo que había usado.',
      standardNote: 'Puesto, un accesorio de club da +5 de popularidad mientras esté en la ciudad del club. Compra libre; puestos: una bufanda, una gorra y una camiseta como máximo, tres objetos en total.',
      betaBtn: 'Crear mi accesorio (gratis durante la beta)', betaNote: 'Gratis durante la beta, como todo el premium.',
      uniteBtn: 'Crear mi accesorio (compra por unidad ya pagada)', uniteNote: 'Tiene {n} accesorio(s) personalizado(s) ya pagado(s): la creación usa uno.',
      acheter: 'Comprar por unidad', consomme: 'En cuanto se crea la imagen, se usa su renovación (o su compra), aunque no valide el objeto.',
      r: { achat_unite_requis: 'Este accesorio debe comprarse por unidad.', pas_sur_place: 'Vaya al bar del estadio.', club_local_introuvable: 'No hay club en esta ciudad.',
        renouvellement_hebdo_utilise: 'Su renovación de imagen de esta semana ya está usada.', paiement_bientot: 'Pago disponible pronto: no se ha cobrado ni creado nada.',
        demande_invalide: 'Describa su personalización (de 3 a 300 caracteres).', commande_non_annulable: 'Este pedido ya no se puede cancelar.',
        commande_introuvable: 'Pedido no encontrado.', defaut: 'Acción rechazada.' } },
    'zh-TW': { titre: '個人化配件', intro: '{club} 俱樂部的配件，依你的要求客製（例如背後印上你的名字），圖像由 AI 生成。穿戴時，只要你身在俱樂部所在城市，人氣 +5，與一般配件相同：只改變外觀。擁有數量不限；穿戴時同時最多三件物品，其中俱樂部圍巾、棒球帽、球衣各只能一件。',
      type: '配件', maillot: '球衣', casquette: '棒球帽', echarpe: '圍巾', demande: '你的客製內容', demandePh: '例如：背後印「王大明 10」',
      prix: '價格：{prix} 歐元，按件付費。', sansPrix: '價格尚未訂定。', payer: '付款並製作我的配件', bientot: '付款功能即將開放',
      bientotTexte: '未扣款，也未製作任何東西。', court: '請描述你的客製內容（至少 3 個字元）。', refus: '已拒絕', reseau: '伺服器沒有回應。',
      inclus: '製作我的配件（訂閱方案內含）', inclusNote: '訂閱方案內含：將使用你本週的圖像更新次數。',
      hebdoPris: '你本週的圖像更新次數已用完：配件須按件購買。',
      enCours: '進行中的訂單', creerImage: '生成圖像', annuler: '取消', voir: '查看預覽', valider: '確認並領取', retoucher: '修改',
      retouchePh: '需要修改的地方', travail: '製作中，請稍候……',
      imageIndispo: '無法生成圖像（{raison}）。訂單所使用的次數已歸還給你。',
      imageEchec: '無法生成圖像：{raison}', livre: '{objet} 已放入你的物品欄。', annule: '訂單已取消。所使用的次數已歸還給你。',
      standardNote: '穿戴俱樂部配件時，只要身在俱樂部所在城市，人氣 +5。購買不限；穿戴時圍巾、棒球帽、球衣各最多一件，總共最多三件物品。',
      betaBtn: '製作我的配件（測試期間免費）', betaNote: '測試期間免費，與所有付費功能相同。',
      uniteBtn: '製作我的配件（已付款的單件購買）', uniteNote: '你有 {n} 件已付款的個人化配件：製作會使用其中一件。',
      acheter: '單件購買', consomme: '圖像一旦生成，你的更新次數（或購買）即被使用，即使你沒有確認該物品。',
      r: { achat_unite_requis: '此配件須單件購買。', pas_sur_place: '請前往球場小賣部。', club_local_introuvable: '這座城市沒有俱樂部。',
        renouvellement_hebdo_utilise: '你本週的圖像更新次數已用完。', paiement_bientot: '付款功能即將開放：未扣款，也未製作任何東西。',
        demande_invalide: '請描述你的客製內容（3 至 300 個字元）。', commande_non_annulable: '此訂單已無法取消。',
        commande_introuvable: '找不到訂單。', defaut: '操作被拒絕。' } },
    ru: { titre: 'Именной аксессуар', intro: 'Аксессуар клуба {club}, сделанный по вашему желанию (например, ваше имя на спине). Изображение создаёт ИИ. Надетый, он даёт +5 популярности, пока вы находитесь в городе клуба, как и обычный аксессуар: меняется только внешний вид. Иметь можно сколько угодно; надетыми — не более трёх предметов одновременно, из них лишь один шарф, одна кепка и одна футболка клуба.',
      type: 'Аксессуар', maillot: 'Футболка', casquette: 'Кепка', echarpe: 'Шарф', demande: 'Ваша надпись', demandePh: 'Напр.: «ИВАНОВ 10» на спине',
      prix: 'Цена: {prix} €, оплата за штуку.', sansPrix: 'Цена ещё не установлена.', payer: 'Оплатить и создать аксессуар', bientot: 'Оплата скоро будет доступна',
      bientotTexte: 'Ничего не списано и не создано.', court: 'Опишите надпись (не менее 3 символов).', refus: 'Отказано', reseau: 'Сервер не отвечает.',
      inclus: 'Создать аксессуар (входит в подписку)', inclusNote: 'Входит в вашу подписку: используется ваше обновление изображения на этой неделе.',
      hebdoPris: 'Обновление изображения на этой неделе уже использовано: аксессуар покупается поштучно.',
      enCours: 'Текущие заказы', creerImage: 'Создать изображение', annuler: 'Отменить', voir: 'Посмотреть эскиз', valider: 'Подтвердить и получить', retoucher: 'Доработать',
      retouchePh: 'Что изменить', travail: 'Создаётся, подождите…',
      imageIndispo: 'Не удалось создать изображение ({raison}). То, что использовал заказ, вам возвращено.',
      imageEchec: 'Не удалось создать изображение: {raison}', livre: '{objet} теперь в вашем инвентаре.', annule: 'Заказ отменён. То, что он использовал, вам возвращено.',
      standardNote: 'Надетый аксессуар клуба даёт +5 популярности, пока вы в городе клуба. Покупка без ограничений; надетыми — не более одного шарфа, одной кепки и одной футболки, всего три предмета.',
      betaBtn: 'Создать аксессуар (бесплатно во время беты)', betaNote: 'Бесплатно во время беты, как и весь премиум.',
      uniteBtn: 'Создать аксессуар (поштучная покупка уже оплачена)', uniteNote: 'У вас {n} уже оплаченных именных аксессуаров: создание использует один из них.',
      acheter: 'Купить поштучно', consomme: 'Как только изображение создано, ваше обновление (или покупка) считается использованным, даже если вы не подтвердите предмет.',
      r: { achat_unite_requis: 'Этот аксессуар нужно купить поштучно.', pas_sur_place: 'Пройдите в буфет стадиона.', club_local_introuvable: 'В этом городе нет клуба.',
        renouvellement_hebdo_utilise: 'Обновление изображения на этой неделе уже использовано.', paiement_bientot: 'Оплата скоро будет доступна: ничего не списано и не создано.',
        demande_invalide: 'Опишите надпись (от 3 до 300 символов).', commande_non_annulable: 'Этот заказ уже нельзя отменить.',
        commande_introuvable: 'Заказ не найден.', defaut: 'Действие отклонено.' } },
    ko: { titre: '맞춤 액세서리', intro: '{club} 클럽의 액세서리를 원하는 대로 맞춤 제작합니다(예: 등에 이름). 이미지는 AI가 만듭니다. 착용하면 클럽 도시에 있는 동안 인기 +5로, 일반 액세서리와 같습니다. 바뀌는 것은 겉모습뿐입니다. 원하는 만큼 가질 수 있으며, 동시에 착용할 수 있는 물건은 세 개까지이고 그중 클럽 머플러·모자·유니폼은 각각 하나뿐입니다.',
      type: '액세서리', maillot: '유니폼', casquette: '모자', echarpe: '머플러', demande: '맞춤 내용', demandePh: '예: 등에 “KIM 10”',
      prix: '가격: {prix}유로, 개당 결제.', sansPrix: '가격이 아직 정해지지 않았습니다.', payer: '결제하고 액세서리 만들기', bientot: '결제 기능 곧 제공',
      bientotTexte: '아무것도 결제되거나 만들어지지 않았습니다.', court: '맞춤 내용을 3자 이상 적어 주세요.', refus: '거부됨', reseau: '서버가 응답하지 않습니다.',
      inclus: '액세서리 만들기(구독에 포함)', inclusNote: '구독에 포함: 이번 주 이미지 갱신 1회를 사용합니다.',
      hebdoPris: '이번 주 이미지 갱신을 이미 사용했습니다. 액세서리는 개당 구매해야 합니다.',
      enCours: '진행 중인 주문', creerImage: '이미지 만들기', annuler: '취소', voir: '미리보기 보기', valider: '확정하고 받기', retoucher: '수정',
      retouchePh: '바꿀 내용', travail: '만드는 중입니다. 잠시 기다려 주세요…',
      imageIndispo: '이미지를 만들 수 없습니다({raison}). 주문에 사용된 것은 돌려드렸습니다.',
      imageEchec: '이미지를 만들 수 없습니다: {raison}', livre: '{objet}이(가) 인벤토리에 들어왔습니다.', annule: '주문이 취소되었습니다. 사용된 것은 돌려드렸습니다.',
      standardNote: '클럽 액세서리를 착용하면 클럽 도시에 있는 동안 인기 +5입니다. 구매는 자유이며, 착용은 머플러·모자·유니폼 각각 하나, 모두 합쳐 세 개까지입니다.',
      betaBtn: '액세서리 만들기(베타 기간 무료)', betaNote: '모든 프리미엄과 마찬가지로 베타 기간에는 무료입니다.',
      uniteBtn: '액세서리 만들기(이미 결제한 개별 구매)', uniteNote: '이미 결제한 맞춤 액세서리가 {n}개 있습니다. 만들 때 하나를 사용합니다.',
      acheter: '개별 구매', consomme: '이미지가 만들어지는 즉시, 물건을 확정하지 않더라도 갱신(또는 구매)이 사용됩니다.',
      r: { achat_unite_requis: '이 액세서리는 개별 구매해야 합니다.', pas_sur_place: '경기장 매점으로 가세요.', club_local_introuvable: '이 도시에는 클럽이 없습니다.',
        renouvellement_hebdo_utilise: '이번 주 이미지 갱신을 이미 사용했습니다.', paiement_bientot: '결제 기능 곧 제공: 아무것도 결제되거나 만들어지지 않았습니다.',
        demande_invalide: '맞춤 내용을 3~300자로 적어 주세요.', commande_non_annulable: '이 주문은 더 이상 취소할 수 없습니다.',
        commande_introuvable: '주문을 찾을 수 없습니다.', defaut: '행동이 거부되었습니다.' } },
    ar: { titre: 'إكسسوار مخصّص', intro: 'إكسسوار لنادي {club}، مخصّص حسب طلبك (مثلًا اسمك على الظهر). تُنشئ صورته أداة ذكاء اصطناعي. عند ارتدائه يمنح +5 شعبية ما دمت في مدينة النادي، مثل الإكسسوار العادي: لا يتغيّر إلا المظهر. يمكنك امتلاك ما تشاء منها؛ وعند الارتداء ثلاثة أغراض على الأكثر في آن واحد، منها وشاح واحد وقبعة واحدة وقميص واحد للنادي فقط.',
      type: 'الإكسسوار', maillot: 'قميص', casquette: 'قبعة', echarpe: 'وشاح', demande: 'تخصيصك', demandePh: 'مثال: «أحمد 10» على الظهر',
      prix: 'السعر: {prix} يورو، يُدفع للقطعة.', sansPrix: 'لم يُحدَّد السعر بعد.', payer: 'ادفع وأنشئ إكسسواري', bientot: 'الدفع متاح قريبًا',
      bientotTexte: 'لم يُخصم شيء ولم يُنشأ شيء.', court: 'صِف تخصيصك (3 أحرف على الأقل).', refus: 'مرفوض', reseau: 'الخادم لا يستجيب.',
      inclus: 'أنشئ إكسسواري (مشمول في الاشتراك)', inclusNote: 'مشمول في اشتراكك: يستهلك تجديد الصورة الخاص بهذا الأسبوع.',
      hebdoPris: 'تجديد الصورة لهذا الأسبوع مستخدم بالفعل: يُشترى الإكسسوار بالقطعة.',
      enCours: 'طلبات قيد التنفيذ', creerImage: 'أنشئ الصورة', annuler: 'إلغاء', voir: 'عرض المعاينة', valider: 'تأكيد واستلام', retoucher: 'تعديل',
      retouchePh: 'ما الذي يجب تغييره', travail: 'جارٍ الإنشاء، يُرجى الانتظار…',
      imageIndispo: 'تعذّر إنشاء الصورة ({raison}). أُعيد إليك ما استخدمه الطلب.',
      imageEchec: 'تعذّر إنشاء الصورة: {raison}', livre: 'أصبح {objet} في مخزونك.', annule: 'أُلغي الطلب. أُعيد إليك ما استخدمه.',
      standardNote: 'عند ارتداء إكسسوار النادي يمنح +5 شعبية ما دمت في مدينة النادي. الشراء غير محدود؛ وعند الارتداء وشاح واحد وقبعة واحدة وقميص واحد على الأكثر، وثلاثة أغراض في المجموع.',
      betaBtn: 'أنشئ إكسسواري (مجانًا خلال النسخة التجريبية)', betaNote: 'مجاني خلال النسخة التجريبية، مثل كل المزايا المميّزة.',
      uniteBtn: 'أنشئ إكسسواري (شراء بالقطعة مدفوع مسبقًا)', uniteNote: 'لديك {n} من الإكسسوارات المخصّصة المدفوعة مسبقًا: يستخدم الإنشاء واحدًا منها.',
      acheter: 'شراء بالقطعة', consomme: 'بمجرد إنشاء الصورة يُحتسب تجديدك (أو شراؤك) مستخدمًا، حتى لو لم تؤكّد الغرض.',
      r: { achat_unite_requis: 'يجب شراء هذا الإكسسوار بالقطعة.', pas_sur_place: 'توجّه إلى مقصف الملعب.', club_local_introuvable: 'لا يوجد نادٍ في هذه المدينة.',
        renouvellement_hebdo_utilise: 'تجديد الصورة لهذا الأسبوع مستخدم بالفعل.', paiement_bientot: 'الدفع متاح قريبًا: لم يُخصم شيء ولم يُنشأ شيء.',
        demande_invalide: 'صِف تخصيصك (من 3 إلى 300 حرف).', commande_non_annulable: 'لم يعد ممكنًا إلغاء هذا الطلب.',
        commande_introuvable: 'الطلب غير موجود.', defaut: 'رُفض الإجراء.' } },
    'pt-BR': { titre: 'Acessório personalizado', intro: 'Um acessório do clube {club}, personalizado do seu jeito (por exemplo seu nome nas costas). A imagem é criada por IA. Vestido, dá +5 de popularidade enquanto você estiver na cidade do clube, como o acessório comum: só muda a aparência. Você pode ter quantos quiser; vestidos: no máximo três objetos ao mesmo tempo, com um só cachecol, um só boné e uma só camisa de clube.',
      type: 'Acessório', maillot: 'Camisa', casquette: 'Boné', echarpe: 'Cachecol', demande: 'Sua personalização', demandePh: 'Ex.: “SILVA 10” nas costas',
      prix: 'Preço: {prix} €, pago por unidade.', sansPrix: 'Preço ainda não definido.', payer: 'Pagar e criar meu acessório', bientot: 'Pagamento disponível em breve',
      bientotTexte: 'Nada foi cobrado nem criado.', court: 'Descreva sua personalização (pelo menos 3 caracteres).', refus: 'Recusado', reseau: 'O servidor não responde.',
      inclus: 'Criar meu acessório (incluído na assinatura)', inclusNote: 'Incluído na sua assinatura: usa sua renovação de imagem da semana.',
      hebdoPris: 'Sua renovação de imagem desta semana já foi usada: o acessório é comprado por unidade.',
      enCours: 'Pedidos em andamento', creerImage: 'Criar a imagem', annuler: 'Cancelar', voir: 'Ver a prévia', valider: 'Confirmar e receber', retoucher: 'Retocar',
      retouchePh: 'O que deve mudar', travail: 'Criando, aguarde…',
      imageIndispo: 'Não foi possível criar a imagem ({raison}). O que o pedido havia usado foi devolvido.',
      imageEchec: 'Não foi possível criar a imagem: {raison}', livre: '{objet} entrou no seu inventário.', annule: 'Pedido cancelado. O que ele havia usado foi devolvido.',
      standardNote: 'Vestido, um acessório de clube dá +5 de popularidade enquanto você estiver na cidade do clube. Compra livre; vestidos: no máximo um cachecol, um boné e uma camisa, três objetos no total.',
      betaBtn: 'Criar meu acessório (grátis durante o beta)', betaNote: 'Grátis durante o beta, como todo o premium.',
      uniteBtn: 'Criar meu acessório (compra avulsa já paga)', uniteNote: 'Você tem {n} acessório(s) personalizado(s) já pago(s): a criação usa um.',
      acheter: 'Comprar avulso', consomme: 'Assim que a imagem é criada, sua renovação (ou compra) é usada, mesmo que você não confirme o objeto.',
      r: { achat_unite_requis: 'Este acessório precisa ser comprado avulso.', pas_sur_place: 'Vá até o bar do estádio.', club_local_introuvable: 'Não há clube nesta cidade.',
        renouvellement_hebdo_utilise: 'Sua renovação de imagem desta semana já foi usada.', paiement_bientot: 'Pagamento disponível em breve: nada foi cobrado nem criado.',
        demande_invalide: 'Descreva sua personalização (de 3 a 300 caracteres).', commande_non_annulable: 'Este pedido não pode mais ser cancelado.',
        commande_introuvable: 'Pedido não encontrado.', defaut: 'Ação recusada.' } },
    de: { titre: 'Personalisiertes Accessoire', intro: 'Ein Accessoire des Vereins {club}, nach Ihrem Wunsch personalisiert (zum Beispiel Ihr Name auf dem Rücken). Das Bild erstellt eine KI. Getragen bringt es +5 Beliebtheit, solange Sie in der Stadt des Vereins sind, wie das gewöhnliche Accessoire: nur das Aussehen ändert sich. Sie dürfen beliebig viele besitzen; getragen: höchstens drei Gegenstände zugleich, darunter nur ein Vereinsschal, eine Kappe und ein Trikot.',
      type: 'Accessoire', maillot: 'Trikot', casquette: 'Kappe', echarpe: 'Schal', demande: 'Ihre Personalisierung', demandePh: 'Z. B. „MÜLLER 10“ auf dem Rücken',
      prix: 'Preis: {prix} €, pro Stück bezahlt.', sansPrix: 'Preis noch nicht festgelegt.', payer: 'Bezahlen und mein Accessoire erstellen', bientot: 'Bezahlung bald verfügbar',
      bientotTexte: 'Nichts wurde abgebucht oder erstellt.', court: 'Beschreiben Sie Ihre Personalisierung (mindestens 3 Zeichen).', refus: 'Abgelehnt', reseau: 'Der Server antwortet nicht.',
      inclus: 'Mein Accessoire erstellen (im Abonnement enthalten)', inclusNote: 'In Ihrem Abonnement enthalten: Dies verbraucht Ihre Bilderneuerung dieser Woche.',
      hebdoPris: 'Ihre Bilderneuerung dieser Woche ist bereits verbraucht: Das Accessoire wird pro Stück gekauft.',
      enCours: 'Laufende Bestellungen', creerImage: 'Bild erstellen', annuler: 'Stornieren', voir: 'Vorschau ansehen', valider: 'Bestätigen und erhalten', retoucher: 'Nachbessern',
      retouchePh: 'Was geändert werden soll', travail: 'Wird erstellt, bitte warten…',
      imageIndispo: 'Das Bild konnte nicht erstellt werden ({raison}). Was die Bestellung verbraucht hatte, erhalten Sie zurück.',
      imageEchec: 'Das Bild konnte nicht erstellt werden: {raison}', livre: '{objet} liegt jetzt in Ihrem Inventar.', annule: 'Bestellung storniert. Was sie verbraucht hatte, erhalten Sie zurück.',
      standardNote: 'Getragen bringt ein Vereinsaccessoire +5 Beliebtheit, solange Sie in der Stadt des Vereins sind. Kauf unbegrenzt; getragen: höchstens ein Schal, eine Kappe und ein Trikot, insgesamt drei Gegenstände.',
      betaBtn: 'Mein Accessoire erstellen (während der Beta kostenlos)', betaNote: 'Während der Beta kostenlos, wie alle Premium-Funktionen.',
      uniteBtn: 'Mein Accessoire erstellen (Einzelkauf bereits bezahlt)', uniteNote: 'Sie haben {n} bereits bezahlte(s) personalisierte(s) Accessoire(s): Die Erstellung verbraucht eines.',
      acheter: 'Einzeln kaufen', consomme: 'Sobald das Bild erstellt ist, gilt Ihre Erneuerung (oder Ihr Kauf) als verbraucht, auch wenn Sie den Gegenstand nicht bestätigen.',
      r: { achat_unite_requis: 'Dieses Accessoire muss einzeln gekauft werden.', pas_sur_place: 'Gehen Sie zum Stadionkiosk.', club_local_introuvable: 'In dieser Stadt gibt es keinen Verein.',
        renouvellement_hebdo_utilise: 'Ihre Bilderneuerung dieser Woche ist bereits verbraucht.', paiement_bientot: 'Bezahlung bald verfügbar: Nichts wurde abgebucht oder erstellt.',
        demande_invalide: 'Beschreiben Sie Ihre Personalisierung (3 bis 300 Zeichen).', commande_non_annulable: 'Diese Bestellung kann nicht mehr storniert werden.',
        commande_introuvable: 'Bestellung nicht gefunden.', defaut: 'Aktion abgelehnt.' } }
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
  const corps = () => document.getElementById('postes-body');
  const message = (texte) => { const m = document.getElementById('acc-perso-message'); if (m) m.textContent = texte; };

  async function rpc(fn, params) {
    if (typeof sbRpcVerdict !== 'function') return null;
    try { return await sbRpcVerdict(fn, params || {}); } catch (_) { return null; }
  }
  // Fonction Edge de génération d'image : toute erreur (y compris « non déployée ») est rendue comme un échec nommé.
  async function edge(id, action, prompt) {
    try {
      const res = await fetch(SUPABASE_URL + '/functions/v1/accessoire-personnalise', { method: 'POST', headers: sbEnTetes(),
        body: JSON.stringify({ id, action, prompt: prompt || '' }) });
      const data = await res.json().catch(() => ({}));
      return res.ok && data && data.ok ? data : { ok: false, erreur: (data && data.error) || String(res.status) };
    } catch (e) { return { ok: false, erreur: (e && e.message) || 'reseau' }; }
  }

  async function ouvrirAccessoirePersonnalise() {
    const v = await rpc('accessoire_personnalise_offre', {});
    if (!v) { showToast(t('titre'), t('reseau'), false); return; }
    if (v.ok !== true) { showToast(t('refus'), motif(v), false); return; }
    const t1 = document.getElementById('postes-modal-title'), b = corps(), m = document.getElementById('modal-postes');
    if (!t1 || !b || !m) return;
    const prix = Number.isInteger(v.prix_centimes) ? (v.prix_centimes / 100).toFixed(2).replace('.', langue() === 'en' ? '.' : ',') : null;
    const types = ['maillot', 'casquette', 'echarpe'];
    const enCours = Array.isArray(v.en_cours) ? v.en_cours : [];
    t1.textContent = t('titre');
    let html = '<div class="cpj-dialogue accessoire-personnalise" dir="auto"><p class="cpj-note">' + echapper(t('intro', { club: v.club || '' })) + '</p>';
    if (enCours.length) {
      html += '<p class="cpj-note"><strong>' + echapper(t('enCours')) + '</strong></p>';
      enCours.forEach(c => {
        html += '<p class="cpj-note">' + echapper(t(c.type)) + ' — « ' + echapper(c.demande) + ' » ';
        if (c.etat === 'apercu') html += '<button type="button" class="cpj-touche" data-acc-voir="' + echapper(c.id) + '">' + echapper(t('voir')) + '</button>';
        else {
          html += '<button type="button" class="cpj-touche" data-acc-creer="' + echapper(c.id) + '" data-annulable="' + (c.annulable ? '1' : '') + '">' + echapper(t('creerImage')) + '</button>';
          if (c.annulable) html += ' <button type="button" class="cpj-touche" data-acc-annuler="' + echapper(c.id) + '">' + echapper(t('annuler')) + '</button>';
        }
        html += '</p>';
      });
    }
    {
      html += '<label class="cpj-note">' + echapper(t('type')) + ' <select id="acc-perso-type" class="cpj-champ">'
        + types.map(x => '<option value="' + x + '">' + echapper(t(x)) + '</option>').join('') + '</select></label>'
        + '<label class="cpj-note" style="display:block;margin-top:.5rem">' + echapper(t('demande'))
        + ' <input id="acc-perso-demande" class="cpj-champ" maxlength="300" style="width:100%" placeholder="' + echapper(t('demandePh')) + '"></label>';
      // Source décidée par le serveur : bêta, renouvellement de l'abonné, crédit à l'unité déjà payé, ou achat à l'unité.
      const creer = { beta: ['betaNote', 'betaBtn'], abonnement: ['inclusNote', 'inclus'], unite: ['uniteNote', 'uniteBtn'] }[v.source];
      if (creer) {
        html += '<p class="cpj-note">' + echapper(t(creer[0], { n: Number(v.credits_unite || 0) })) + ' ' + echapper(t('consomme')) + '</p>'
          + '<button type="button" class="cpj-touche cpj-primaire" id="acc-perso-inclus">' + echapper(t(creer[1])) + '</button>';
      } else {
        if (v.abonne === true) html += '<p class="cpj-note">' + echapper(t('hebdoPris')) + '</p>';
        html += '<p class="cpj-note">' + echapper(prix ? t('prix', { prix }) : t('sansPrix')) + '</p>';
        if (prix) html += '<button type="button" class="cpj-touche cpj-primaire" id="acc-perso-payer">' + echapper(t('acheter')) + '</button>';
      }
    }
    html += '<div id="acc-perso-apercu"></div><p class="cpj-note" id="acc-perso-message" style="margin-top:.6rem"></p></div>';
    b.innerHTML = html;
    m.classList.add('open');
    const lireDemande = () => String((b.querySelector('#acc-perso-demande') || {}).value || '').trim();
    const payer = b.querySelector('#acc-perso-payer');
    // Achat à l'unité : écran de paiement commun (vendeur, CGV, renonciation) ; le crédit n'existe qu'après le webhook signé.
    // De retour à la buvette, le joueur crée son accessoire avec ce crédit (source « unite »).
    if (payer) payer.addEventListener('click', () => {
      if (window.RPPaiement && typeof window.RPPaiement.confirmerAchat === 'function' && v.produit) {
        window.RPPaiement.confirmerAchat('accessoire_personnalise', null, v.produit); return;
      }
      message(t('bientot') + ' — ' + t('bientotTexte'));
    });
    const inclus = b.querySelector('#acc-perso-inclus');
    if (inclus) inclus.addEventListener('click', async () => {
      const demande = lireDemande();
      if (demande.length < 3) { message(t('court')); return; }
      inclus.disabled = true;
      const r = await rpc('accessoire_personnalise_commander', { p_type: b.querySelector('#acc-perso-type').value, p_demande: demande });
      if (!r) { inclus.disabled = false; message(t('reseau')); return; }
      if (r.ok !== true) { inclus.disabled = false; message(motif(r)); return; }
      await generer(r.id, true);
    });
    b.querySelectorAll('[data-acc-creer]').forEach(x => x.addEventListener('click', () => generer(x.dataset.accCreer, !!x.dataset.annulable)));
    b.querySelectorAll('[data-acc-annuler]').forEach(x => x.addEventListener('click', () => annuler(x.dataset.accAnnuler)));
    b.querySelectorAll('[data-acc-voir]').forEach(x => x.addEventListener('click', async () => {
      message(t('travail'));
      const d = await edge(x.dataset.accVoir, 'preview');
      if (!d.ok) { message(t('imageEchec', { raison: d.erreur })); return; }
      afficherApercu(x.dataset.accVoir, d);
    }));
  }

  async function generer(id, annulable) {
    message(t('travail'));
    const d = await edge(id, 'generate');
    if (d.ok) { afficherApercu(id, d); return; }
    // Image non créée : la commande est annulée par le serveur, et ce qu'elle avait pris (renouvellement, achat) est rendu.
    if (annulable) {
      const r = await rpc('accessoire_personnalise_annuler', { p_id: id });
      if (r && r.ok === true) { message(t('imageIndispo', { raison: d.erreur })); return; }
    }
    message(t('imageEchec', { raison: d.erreur }));
  }

  async function annuler(id) {
    const r = await rpc('accessoire_personnalise_annuler', { p_id: id });
    if (!r) { message(t('reseau')); return; }
    if (r.ok !== true) { message(motif(r)); return; }
    showToast(t('titre'), t('annule'), true);
    ouvrirAccessoirePersonnalise();
  }

  function afficherApercu(id, d) {
    const zone = document.getElementById('acc-perso-apercu');
    if (!zone) return;
    message('');
    zone.innerHTML = (d.url ? '<img src="' + echapper(d.url) + '" alt="" style="max-width:100%;margin:.5rem 0">' : '')
      + '<button type="button" class="cpj-touche cpj-primaire" id="acc-perso-valider">' + echapper(t('valider')) + '</button>'
      + (Number(d.retouches || 0) < 2 ? ' <input id="acc-perso-retouche" class="cpj-champ" maxlength="600" placeholder="' + echapper(t('retouchePh')) + '">'
        + ' <button type="button" class="cpj-touche" id="acc-perso-retoucher">' + echapper(t('retoucher')) + '</button>' : '');
    zone.querySelector('#acc-perso-valider').addEventListener('click', async () => {
      message(t('travail'));
      const f = await edge(id, 'finalize');
      if (!f.ok) { message(t('imageEchec', { raison: f.erreur })); return; }
      document.getElementById('modal-postes')?.classList.remove('open');
      showToast(t('titre'), t('livre', { objet: f.objet || '' }), true);
      if (typeof window.verifierObjetsRecus === 'function') { try { window.verifierObjetsRecus(); } catch (_) {} }
    });
    const retoucher = zone.querySelector('#acc-perso-retoucher');
    if (retoucher) retoucher.addEventListener('click', async () => {
      const notes = String(zone.querySelector('#acc-perso-retouche').value || '').trim();
      if (notes.length < 5) return;
      message(t('travail'));
      const r = await edge(id, 'retouch', notes);
      if (!r.ok) { message(t('imageEchec', { raison: r.erreur })); return; }
      afficherApercu(id, r);
    });
  }

  // Refus des accessoires de club standard (club_accessoire_acheter) : texte traduit, sinon NULL.
  function accessoireClubMotif(v) {
    const r = v && v.raison, l = T[langue()] || T.fr;
    return r && (l.r[r] || T.fr.r[r]) ? (l.r[r] || T.fr.r[r]) : null;
  }

  window.ouvrirAccessoirePersonnalise = ouvrirAccessoirePersonnalise;
  window.accessoireClubMotif = accessoireClubMotif;
  window.accessoireClubNote = () => t('standardNote');
  window.RP_ACCESSOIRE_PERSONNALISE_T = T;
})();
