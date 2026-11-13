// Textes fixes de présentation uniquement : commandes de chantier, sans action métier.
(function(global){
 'use strict';
 const locales=["fr","en","es","zh-TW","ru","ko","ar","pt-BR","de"];
 const rows=[
  [
    "waiting",
    "Reprenez d’abord la commande précédente avec les mêmes paramètres pour vérifier son résultat.",
    "First resume the previous order with the same parameters to check its result.",
    "Retoma primero la orden anterior con los mismos parámetros para comprobar su resultado.",
    "請先以相同參數繼續上一筆指令，以確認其結果。",
    "Сначала возобновите предыдущую команду с теми же параметрами, чтобы проверить её результат.",
    "먼저 같은 매개변수로 이전 명령을 재개하여 결과를 확인하세요.",
    "استأنف أولًا الأمر السابق بالمعلمات نفسها للتحقق من نتيجته.",
    "Primeiro retome a ordem anterior com os mesmos parâmetros para verificar o resultado.",
    "Setzen Sie zuerst den vorherigen Auftrag mit denselben Parametern fort, um sein Ergebnis zu prüfen."
  ],
  [
    "notStarted",
    "La reprise sûre de cette opération ne peut pas être enregistrée.",
    "A safe retry of this operation cannot be saved.",
    "No se puede guardar la reanudación segura de esta operación.",
    "無法儲存此操作的安全重試資訊。",
    "Не удаётся сохранить данные для безопасного возобновления этой операции.",
    "이 작업을 안전하게 재개하기 위한 정보를 저장할 수 없습니다.",
    "لا يمكن حفظ معلومات الاستئناف الآمن لهذه العملية.",
    "Não é possível salvar a retomada segura desta operação.",
    "Die Daten für eine sichere Wiederaufnahme dieses Vorgangs können nicht gespeichert werden."
  ],
  [
    "statePending",
    "Le serveur a confirmé l’opération, mais son état actualisé reste à relire. L’intention de reprise est conservée.",
    "The server has confirmed the operation, but its updated state still needs to be retrieved. The retry request is retained.",
    "El servidor ha confirmado la operación, pero aún hay que volver a consultar su estado actualizado. Se conserva la solicitud de reanudación.",
    "伺服器已確認操作，但仍須重新讀取更新後的狀態。重試意圖已保留。",
    "Сервер подтвердил операцию, но её обновлённое состояние ещё нужно перечитать. Намерение возобновить операцию сохранено.",
    "서버가 작업을 확인했지만 갱신된 상태를 다시 읽어야 합니다. 재개 요청은 보존됩니다.",
    "أكد الخادم العملية، لكن حالتها المحدَّثة لا تزال بحاجة إلى إعادة قراءة. تم الاحتفاظ بطلب الاستئناف.",
    "O servidor confirmou a operação, mas o estado atualizado ainda precisa ser relido. A intenção de retomada foi mantida.",
    "Der Server hat den Vorgang bestätigt, aber der aktualisierte Zustand muss noch einmal abgerufen werden. Die Wiederaufnahmeanforderung bleibt gespeichert."
  ],
  [
    "financePending",
    "La relecture financière reste à confirmer. L’intention de reprise est conservée.",
    "The financial refresh still needs confirmation. The retry request is retained.",
    "La nueva consulta financiera aún debe confirmarse. Se conserva la solicitud de reanudación.",
    "財務資料的重新讀取尚待確認。重試意圖已保留。",
    "Повторное чтение финансовых данных ещё не подтверждено. Намерение возобновить операцию сохранено.",
    "재조회한 재정 정보는 아직 확인이 필요합니다. 재개 요청은 보존됩니다.",
    "لا تزال إعادة قراءة البيانات المالية بحاجة إلى تأكيد. تم الاحتفاظ بطلب الاستئناف.",
    "A releitura financeira ainda precisa ser confirmada. A intenção de retomada foi mantida.",
    "Der erneute Abruf der Finanzdaten muss noch bestätigt werden. Die Wiederaufnahmeanforderung bleibt gespeichert."
  ],
  [
    "received",
    "Les locaux sont ouverts. Les reliquats sont conservés dans la caisse et le stock du bâtiment.",
    "The premises are open. Remaining funds and materials are kept in the building’s treasury and stock.",
    "Los locales están abiertos. Los remanentes se conservan en la caja y las existencias del edificio.",
    "各場所已開放。剩餘款項與物資保留在建築的金庫及庫存中。",
    "Помещения открыты. Остатки средств и материалов сохранены в кассе и запасах здания.",
    "건물 내 공간이 개방되었습니다. 잔여 자금과 물자는 건물의 금고와 재고에 보관됩니다.",
    "المقرات مفتوحة. تُحفَظ الأموال والمواد المتبقية في خزينة المبنى ومخزونه.",
    "Os espaços estão abertos. Os saldos restantes são mantidos no caixa e no estoque do edifício.",
    "Die Räumlichkeiten sind geöffnet. Restbestände bleiben in der Kasse und im Lager des Gebäudes."
  ],
  [
    "wageInvalid",
    "Indiquez un nombre entier de francs, au moins le salaire minimum de {{values.minimum}} FR de l’heure.",
    "Enter a whole number of francs, at least the minimum wage of {{values.minimum}} FR per hour.",
    "Introduce una cantidad entera de francos, al menos el salario mínimo de {{values.minimum}} FR por hora.",
    "請輸入整數金額（法郎），不得低於每小時 {{values.minimum}} FR 的最低工資。",
    "Укажите целое число франков, не ниже минимальной зарплаты {{values.minimum}} FR в час.",
    "정수 단위의 프랑을 입력하세요. 시간당 최저 임금인 {{values.minimum}} FR 이상이어야 합니다.",
    "أدخل عددًا صحيحًا من الفرنكات، لا يقل عن الحد الأدنى للأجر البالغ {{values.minimum}} FR في الساعة.",
    "Informe um número inteiro de francos, no mínimo o salário mínimo de {{values.minimum}} FR por hora.",
    "Geben Sie eine ganze Anzahl Franken ein, mindestens den Mindestlohn von {{values.minimum}} FR pro Stunde."
  ],
  [
    "wageSaved",
    "Les ouvriers de votre chantier seront payés {{values.amount}} FR de l’heure.",
    "Workers on your construction site will be paid {{values.amount}} FR per hour.",
    "Los obreros de tu obra cobrarán {{values.amount}} FR por hora.",
    "您工地的工人將獲得每小時 {{values.amount}} FR 的工資。",
    "Рабочим на вашей стройке будут платить {{values.amount}} FR в час.",
    "공사장의 노동자들에게 시간당 {{values.amount}} FR가 지급됩니다.",
    "سيتقاضى عمال موقع البناء لديك {{values.amount}} FR في الساعة.",
    "Os operários da sua obra receberão {{values.amount}} FR por hora.",
    "Die Arbeiter auf Ihrer Baustelle erhalten {{values.amount}} FR pro Stunde."
  ],
  [
    "priceInvalid",
    "Utilisez un nombre entier de francs, positif ou nul.",
    "Use a whole number of francs, positive or zero.",
    "Utiliza una cantidad entera de francos, positiva o igual a cero.",
    "請使用正整數或零的法郎金額。",
    "Используйте целое неотрицательное число франков.",
    "0 이상의 정수 단위 프랑 금액을 사용하세요.",
    "استخدم عددًا صحيحًا من الفرنكات، موجبًا أو صفرًا.",
    "Use um número inteiro de francos, positivo ou zero.",
    "Verwenden Sie eine ganze Anzahl Franken, positiv oder null."
  ],
  [
    "priceUnconfirmed",
    "Les prix n’ont pas pu être confirmés par le serveur. Relisez-les avant de réessayer.",
    "The server could not confirm the prices. Retrieve them again before retrying.",
    "El servidor no ha podido confirmar los precios. Vuelve a consultarlos antes de reintentarlo.",
    "伺服器無法確認價格。請重新讀取價格後再重試。",
    "Сервер не смог подтвердить цены. Перечитайте их перед повторной попыткой.",
    "서버에서 가격을 확인하지 못했습니다. 다시 시도하기 전에 가격을 재조회하세요.",
    "لم يتمكن الخادم من تأكيد الأسعار. أعد قراءتها قبل المحاولة مجددًا.",
    "O servidor não conseguiu confirmar os preços. Releia-os antes de tentar novamente.",
    "Der Server konnte die Preise nicht bestätigen. Rufen Sie sie vor einem erneuten Versuch noch einmal ab."
  ],
  [
    "priceReload",
    "Relisez les prix sur le serveur avant de réessayer.",
    "Retrieve the prices from the server again before retrying.",
    "Vuelve a consultar los precios en el servidor antes de reintentarlo.",
    "請重新從伺服器讀取價格後再重試。",
    "Перечитайте цены с сервера перед повторной попыткой.",
    "다시 시도하기 전에 서버에서 가격을 재조회하세요.",
    "أعد قراءة الأسعار من الخادم قبل المحاولة مجددًا.",
    "Releia os preços no servidor antes de tentar novamente.",
    "Rufen Sie die Preise vor einem erneuten Versuch noch einmal vom Server ab."
  ],
  [
    "titleWaiting",
    "Commande en attente",
    "Order pending",
    "Orden pendiente",
    "指令待處理",
    "Команда ожидает",
    "명령 대기 중",
    "أمر معلّق",
    "Ordem pendente",
    "Auftrag ausstehend"
  ],
  [
    "titleNotStarted",
    "Commande non lancée",
    "Order not started",
    "Orden no iniciada",
    "指令未啟動",
    "Команда не запущена",
    "명령이 시작되지 않음",
    "لم يبدأ الأمر",
    "Ordem não iniciada",
    "Auftrag nicht gestartet"
  ],
  [
    "titleConfirmed",
    "Commande acquise",
    "Order confirmed",
    "Orden confirmada",
    "指令已確認",
    "Команда подтверждена",
    "명령 확인됨",
    "تم تأكيد الأمر",
    "Ordem confirmada",
    "Auftrag bestätigt"
  ],
  [
    "titleReceived",
    "Bâtiment réceptionné",
    "Building handed over",
    "Edificio entregado",
    "建築已驗收",
    "Здание принято",
    "건물 인수 완료",
    "تم استلام المبنى",
    "Edifício recebido",
    "Gebäude abgenommen"
  ],
  [
    "titleWageRefused",
    "Taux refusé",
    "Rate refused",
    "Tarifa rechazada",
    "時薪遭拒",
    "Ставка отклонена",
    "임금률 거부됨",
    "رُفض المعدل",
    "Taxa recusada",
    "Lohnsatz abgelehnt"
  ],
  [
    "titleWageSaved",
    "Taux enregistré",
    "Rate saved",
    "Tarifa guardada",
    "時薪已儲存",
    "Ставка сохранена",
    "임금률 저장됨",
    "تم حفظ المعدل",
    "Taxa salva",
    "Lohnsatz gespeichert"
  ],
  [
    "titlePriceInvalid",
    "Prix invalide",
    "Invalid price",
    "Precio no válido",
    "價格無效",
    "Недопустимая цена",
    "유효하지 않은 가격",
    "سعر غير صالح",
    "Preço inválido",
    "Ungültiger Preis"
  ],
  [
    "titlePriceUnconfirmed",
    "Prix non confirmés",
    "Prices not confirmed",
    "Precios no confirmados",
    "價格未確認",
    "Цены не подтверждены",
    "가격 미확인",
    "الأسعار غير مؤكدة",
    "Preços não confirmados",
    "Preise nicht bestätigt"
  ],
["uncertain", "La réponse est incertaine. Reprenez la même commande pour vérifier son résultat sans second traitement.", "The response is uncertain. Resume the same order to check its result without processing it a second time.", "La respuesta es incierta. Retoma la misma orden para comprobar su resultado sin procesarla una segunda vez.", "回覆尚不確定。請繼續同一筆指令，在不重複處理的情況下確認結果。", "Ответ не определён. Возобновите ту же команду, чтобы проверить результат без повторной обработки.", "응답이 확실하지 않습니다. 같은 명령을 재개하여 중복 처리 없이 결과를 확인하세요.", "الرد غير مؤكّد. استأنف الأمر نفسه للتحقق من نتيجته دون معالجته مرة ثانية.", "A resposta é incerta. Retome a mesma ordem para verificar o resultado sem processá-la uma segunda vez.", "Die Antwort ist unklar. Setzen Sie denselben Auftrag fort, um sein Ergebnis ohne erneute Ausführung zu prüfen."],
["serverRefusal", "Le serveur a refusé cette commande.", "The server refused this order.", "El servidor ha rechazado esta orden.", "伺服器拒絕了此指令。", "Сервер отклонил эту команду.", "서버가 이 명령을 거부했습니다.", "رفض الخادم هذا الأمر.", "O servidor recusou esta ordem.", "Der Server hat diesen Auftrag abgelehnt."]
];
 for(const [i,lang]of locales.entries()){
  const t=global.RP_I18N_RESOURCES?.[lang]?.translation;if(!t)continue;
  t.constructionFeedback=Object.fromEntries(rows.map(row=>[row[0],row[i+1]]));
 }
 for(const row of rows)if(row[0].startsWith('title'))global.RPToastI18n?.registerTitle?.(row[1],'constructionFeedback.'+row[0]);
 // Même français : réemploi du titre déjà disponible, sans dupliquer ses traductions.
 global.RPToastI18n?.registerTitle?.('Commande non confirmée','naval.notConfirmed');
})(window);
