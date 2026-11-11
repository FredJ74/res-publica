/* Libellés de gestion existants, sans calcul ni action. */
(function(global){
 const words={
  "fr": {
    "commercepj": {
      "titre": {
        "gestion": "Mon commerce"
      },
      "gestion": {
        "local": "Local",
        "activites": "Activités",
        "aucuneActivite": "Aucune activité déclarée. Choisissez-en avant de créer un produit.",
        "produits": "Mes produits",
        "aucunProduit": "Vous ne proposez encore aucun produit.",
        "nouveau": "Créer un produit",
        "modifierActivites": "Modifier mes activités",
        "identite": "Local : {{values.local}} · Activités : {{values.activites}}"
      },
      "menu": {
        "boutique": "Voir ma boutique"
      },
      "global": {
        "aucuneMatiere": "Aucune matière : les activités déclarées par votre commerce n'ouvrent encore aucune fabrication."
      },
      "matiere": {
        "prix": "Prix de rachat",
        "enregistre": "Réglage enregistré",
        "illimite": "Illimité",
        "utilisee": "Utilisée par vos produits",
        "refusCourt": "vous n'en voulez pas",
        "maxAide": "Fixez le stock maximum de chaque matière : 0 signifie que votre commerce n'en veut pas, et personne ne pourra vous en vendre. Maximum autorisé : {{values.plafond}}."
      },
      "appro": {
        "titre": "Vendre ou donner des matières",
        "recherche": "Ce commerce recherche",
        "aucune": "Ce commerce ne recherche aucune matière pour le moment.",
        "vous": "Vous en avez",
        "besoin": "Il peut en prendre",
        "vendre": "Vendre",
        "donner": "Donner",
        "quantite": "Quantité",
        "vendu": "Matière vendue",
        "donne": "Matière donnée",
        "partiel": "Seules {{values.faites}} unités sur {{values.voulues}} ont pu être prises."
      },
      "ref": {
        "stockMax": "Stock maximum",
        "maxAide": "0 signifie « sans limite ». Un lot dont le rendement dépasserait ce maximum est refusé en entier : le rendement d'une recette ne se coupe pas."
      },
      "machine": {
        "plaque": "SYSTÈME COMMERCIAL RÉPUBLIA",
        "eteindre": "Fermer"
      },
      "tab": {
        "caisse": "Caisse",
        "produits": "Produits vendus",
        "matieres": "Matières premières"
      },
      "caisse": {
        "solde": "Solde",
        "vosPa": "Vos PA",
        "montant": "Montant",
        "apport": "Apport",
        "prelever": "Prélever",
        "apportFait": "Apport versé en caisse",
        "preleveFait": "Prélèvement effectué"
      },
      "col": {
        "produit": "Produit",
        "matiere": "Matière",
        "stock": "Stock",
        "stockMax": "Stock max.",
        "prixVente": "Prix de vente",
        "rachat": "Prix de rachat"
      },
      "prod": {
        "lots": "Lots",
        "pa": "PA",
        "verses": "versés",
        "enCours": "…"
      }
    }
  },
  "en": {
    "commercepj": {
      "titre": {
        "gestion": "My business"
      },
      "gestion": {
        "local": "Premises",
        "activites": "Activities",
        "aucuneActivite": "No activity declared. Choose one before creating a product.",
        "produits": "My products",
        "aucunProduit": "You do not offer any products yet.",
        "nouveau": "Create a product",
        "modifierActivites": "Change my activities",
        "identite": "Premises : {{values.local}} · Activities : {{values.activites}}"
      },
      "menu": {
        "boutique": "View my shop"
      },
      "global": {
        "aucuneMatiere": "No materials: your declared activities do not yet allow any manufacturing."
      },
      "matiere": {
        "prix": "Buyback price",
        "enregistre": "Setting saved",
        "illimite": "Unlimited",
        "utilisee": "Used by your products",
        "refusCourt": "you do not want any",
        "maxAide": "Set the maximum stock for each material: 0 means your business does not want any, and nobody will be able to sell it to you. Allowed maximum: {{values.plafond}}."
      },
      "appro": {
        "titre": "Sell or donate materials",
        "recherche": "This business needs",
        "aucune": "This business does not need any materials at the moment.",
        "vous": "You have",
        "besoin": "It can take",
        "vendre": "Sell",
        "donner": "Donate",
        "quantite": "Quantity",
        "vendu": "Material sold",
        "donne": "Material donated",
        "partiel": "Only {{values.faites}} of the {{values.voulues}} units could be accepted."
      },
      "ref": {
        "stockMax": "Maximum stock",
        "maxAide": "0 means “unlimited”. A batch whose yield would exceed this maximum is refused in full: a recipe's yield cannot be split."
      },
      "machine": {
        "plaque": "RÉPUBLIA BUSINESS SYSTEM",
        "eteindre": "Close"
      },
      "tab": {
        "caisse": "Cashbox",
        "produits": "Products sold",
        "matieres": "Raw materials"
      },
      "caisse": {
        "solde": "Balance",
        "vosPa": "Your AP",
        "montant": "Amount",
        "apport": "Contribution",
        "prelever": "Withdraw",
        "apportFait": "Contribution paid into cashbox",
        "preleveFait": "Withdrawal completed"
      },
      "col": {
        "produit": "Product",
        "matiere": "Material",
        "stock": "Stock",
        "stockMax": "Max. stock",
        "prixVente": "Sale price",
        "rachat": "Buyback price"
      },
      "prod": {
        "lots": "Batches",
        "pa": "AP",
        "verses": "paid",
        "enCours": "…"
      }
    }
  },
  "es": {
    "commercepj": {
      "titre": {
        "gestion": "Mi comercio"
      },
      "gestion": {
        "local": "Local",
        "activites": "Actividades",
        "aucuneActivite": "No hay ninguna actividad declarada. Elige una antes de crear un producto.",
        "produits": "Mis productos",
        "aucunProduit": "Aún no ofreces ningún producto.",
        "nouveau": "Crear un producto",
        "modifierActivites": "Cambiar mis actividades",
        "identite": "Local : {{values.local}} · Actividades : {{values.activites}}"
      },
      "menu": {
        "boutique": "Ver mi tienda"
      },
      "global": {
        "aucuneMatiere": "Sin materiales: las actividades declaradas de tu comercio aún no permiten fabricar nada."
      },
      "matiere": {
        "prix": "Precio de recompra",
        "enregistre": "Configuración guardada",
        "illimite": "Sin límite",
        "utilisee": "Utilizado por tus productos",
        "refusCourt": "no lo quieres",
        "maxAide": "Fija las existencias máximas de cada material: 0 significa que tu comercio no lo quiere y nadie podrá vendértelo. Máximo permitido: {{values.plafond}}."
      },
      "appro": {
        "titre": "Vender o donar materiales",
        "recherche": "Este comercio busca",
        "aucune": "Este comercio no busca materiales por ahora.",
        "vous": "Tienes",
        "besoin": "Puede aceptar",
        "vendre": "Vender",
        "donner": "Donar",
        "quantite": "Cantidad",
        "vendu": "Material vendido",
        "donne": "Material donado",
        "partiel": "Solo se pudieron aceptar {{values.faites}} de las {{values.voulues}} unidades."
      },
      "ref": {
        "stockMax": "Existencias máximas",
        "maxAide": "0 significa «sin límite». Se rechaza todo lote cuyo rendimiento supere este máximo: el rendimiento de una receta no se puede dividir."
      },
      "machine": {
        "plaque": "SISTEMA COMERCIAL RÉPUBLIA",
        "eteindre": "Cerrar"
      },
      "tab": {
        "caisse": "Caja",
        "produits": "Productos vendidos",
        "matieres": "Materias primas"
      },
      "caisse": {
        "solde": "Saldo",
        "vosPa": "Tus PA",
        "montant": "Importe",
        "apport": "Aportación",
        "prelever": "Retirar",
        "apportFait": "Aportación ingresada en caja",
        "preleveFait": "Retirada realizada"
      },
      "col": {
        "produit": "Producto",
        "matiere": "Material",
        "stock": "Existencias",
        "stockMax": "Máx. existencias",
        "prixVente": "Precio de venta",
        "rachat": "Precio de recompra"
      },
      "prod": {
        "lots": "Lotes",
        "pa": "PA",
        "verses": "pagados",
        "enCours": "…"
      }
    }
  },
  "zh-TW": {
    "commercepj": {
      "titre": {
        "gestion": "我的商店"
      },
      "gestion": {
        "local": "營業場所",
        "activites": "業務",
        "aucuneActivite": "尚未申報業務。建立商品前請先選擇。",
        "produits": "我的商品",
        "aucunProduit": "你尚未提供任何商品。",
        "nouveau": "建立商品",
        "modifierActivites": "變更我的業務",
        "identite": "營業場所 : {{values.local}} · 業務 : {{values.activites}}"
      },
      "menu": {
        "boutique": "查看我的商店"
      },
      "global": {
        "aucuneMatiere": "無材料：商店已申報的業務尚不提供製造項目。"
      },
      "matiere": {
        "prix": "收購價",
        "enregistre": "設定已儲存",
        "illimite": "無限制",
        "utilisee": "用於你的商品",
        "refusCourt": "你不需要此材料",
        "maxAide": "設定各材料的庫存上限：0 表示商店不需要此材料，任何人都無法出售給你。允許上限：{{values.plafond}}。"
      },
      "appro": {
        "titre": "出售或捐贈材料",
        "recherche": "此商店需要",
        "aucune": "此商店目前不需要任何材料。",
        "vous": "你持有",
        "besoin": "可接受",
        "vendre": "出售",
        "donner": "捐贈",
        "quantite": "數量",
        "vendu": "材料已出售",
        "donne": "材料已捐贈",
        "partiel": "{{values.voulues}} 單位中僅能接收 {{values.faites}} 單位。"
      },
      "ref": {
        "stockMax": "庫存上限",
        "maxAide": "0 表示「無限制」。若批次產量超過此上限，整批將被拒絕：配方產量不可拆分。"
      },
      "machine": {
        "plaque": "RÉPUBLIA 商業系統",
        "eteindre": "關閉"
      },
      "tab": {
        "caisse": "現金箱",
        "produits": "販售商品",
        "matieres": "原料"
      },
      "caisse": {
        "solde": "餘額",
        "vosPa": "你的行動點數",
        "montant": "金額",
        "apport": "投入資金",
        "prelever": "提取",
        "apportFait": "投入資金已存入現金箱",
        "preleveFait": "提取完成"
      },
      "col": {
        "produit": "商品",
        "matiere": "材料",
        "stock": "庫存",
        "stockMax": "庫存上限",
        "prixVente": "售價",
        "rachat": "收購價"
      },
      "prod": {
        "lots": "批次",
        "pa": "行動點數",
        "verses": "已支付",
        "enCours": "…"
      }
    }
  },
  "ru": {
    "commercepj": {
      "titre": {
        "gestion": "Мой бизнес"
      },
      "gestion": {
        "local": "Помещение",
        "activites": "Виды деятельности",
        "aucuneActivite": "Деятельность не заявлена. Выберите её перед созданием продукта.",
        "produits": "Мои продукты",
        "aucunProduit": "Вы пока не предлагаете продуктов.",
        "nouveau": "Создать продукт",
        "modifierActivites": "Изменить деятельность",
        "identite": "Помещение : {{values.local}} · Виды деятельности : {{values.activites}}"
      },
      "menu": {
        "boutique": "Посмотреть мой магазин"
      },
      "global": {
        "aucuneMatiere": "Материалов нет: заявленная деятельность пока не предусматривает производства."
      },
      "matiere": {
        "prix": "Закупочная цена",
        "enregistre": "Настройка сохранена",
        "illimite": "Без ограничений",
        "utilisee": "Используется в ваших продуктах",
        "refusCourt": "вам это не нужно",
        "maxAide": "Задайте максимальный запас каждого материала: 0 означает, что он вашему бизнесу не нужен и никто не сможет его вам продать. Допустимый максимум: {{values.plafond}}."
      },
      "appro": {
        "titre": "Продать или пожертвовать материалы",
        "recherche": "Этому бизнесу нужны",
        "aucune": "Сейчас этому бизнесу не нужны материалы.",
        "vous": "У вас есть",
        "besoin": "Может принять",
        "vendre": "Продать",
        "donner": "Пожертвовать",
        "quantite": "Количество",
        "vendu": "Материал продан",
        "donne": "Материал пожертвован",
        "partiel": "Принято только {{values.faites}} из {{values.voulues}} единиц."
      },
      "ref": {
        "stockMax": "Максимальный запас",
        "maxAide": "0 означает «без ограничений». Партия, выход которой превысит этот максимум, отклоняется целиком: выход рецепта нельзя разделить."
      },
      "machine": {
        "plaque": "ТОРГОВАЯ СИСТЕМА RÉPUBLIA",
        "eteindre": "Закрыть"
      },
      "tab": {
        "caisse": "Касса",
        "produits": "Продаваемые продукты",
        "matieres": "Сырьё"
      },
      "caisse": {
        "solde": "Баланс",
        "vosPa": "Ваши ОД",
        "montant": "Сумма",
        "apport": "Взнос",
        "prelever": "Снять",
        "apportFait": "Взнос зачислен в кассу",
        "preleveFait": "Снятие выполнено"
      },
      "col": {
        "produit": "Продукт",
        "matiere": "Материал",
        "stock": "Запас",
        "stockMax": "Макс. запас",
        "prixVente": "Цена продажи",
        "rachat": "Закупочная цена"
      },
      "prod": {
        "lots": "Партии",
        "pa": "ОД",
        "verses": "выплачено",
        "enCours": "…"
      }
    }
  },
  "ko": {
    "commercepj": {
      "titre": {
        "gestion": "내 상점"
      },
      "gestion": {
        "local": "영업장",
        "activites": "업종",
        "aucuneActivite": "등록된 업종이 없습니다. 상품을 만들기 전에 선택하세요.",
        "produits": "내 상품",
        "aucunProduit": "아직 판매하는 상품이 없습니다.",
        "nouveau": "상품 만들기",
        "modifierActivites": "업종 변경",
        "identite": "영업장 : {{values.local}} · 업종 : {{values.activites}}"
      },
      "menu": {
        "boutique": "내 매장 보기"
      },
      "global": {
        "aucuneMatiere": "재료 없음: 등록된 업종에는 아직 제조 기능이 없습니다."
      },
      "matiere": {
        "prix": "매입가",
        "enregistre": "설정 저장됨",
        "illimite": "무제한",
        "utilisee": "내 상품에 사용됨",
        "refusCourt": "구매하지 않음",
        "maxAide": "각 재료의 최대 재고를 정하세요. 0은 상점에서 해당 재료를 원하지 않아 아무도 판매할 수 없다는 뜻입니다. 허용 상한: {{values.plafond}}."
      },
      "appro": {
        "titre": "재료 판매 또는 기부",
        "recherche": "이 상점에서 찾는 재료",
        "aucune": "현재 이 상점에서는 재료를 구하지 않습니다.",
        "vous": "보유량",
        "besoin": "수령 가능량",
        "vendre": "판매",
        "donner": "기부",
        "quantite": "수량",
        "vendu": "재료 판매 완료",
        "donne": "재료 기부 완료",
        "partiel": "{{values.voulues}}개 중 {{values.faites}}개만 받을 수 있었습니다."
      },
      "ref": {
        "stockMax": "최대 재고",
        "maxAide": "0은 ‘무제한’입니다. 생산량이 이 상한을 넘는 생산분은 전부 거부됩니다. 제작법의 생산량은 나눌 수 없습니다."
      },
      "machine": {
        "plaque": "RÉPUBLIA 상거래 시스템",
        "eteindre": "닫기"
      },
      "tab": {
        "caisse": "금고",
        "produits": "판매 상품",
        "matieres": "원재료"
      },
      "caisse": {
        "solde": "잔액",
        "vosPa": "내 행동력",
        "montant": "금액",
        "apport": "입금",
        "prelever": "인출",
        "apportFait": "금고 입금 완료",
        "preleveFait": "인출 완료"
      },
      "col": {
        "produit": "상품",
        "matiere": "재료",
        "stock": "재고",
        "stockMax": "최대 재고",
        "prixVente": "판매가",
        "rachat": "매입가"
      },
      "prod": {
        "lots": "생산분",
        "pa": "행동력",
        "verses": "지급됨",
        "enCours": "…"
      }
    }
  },
  "ar": {
    "commercepj": {
      "titre": {
        "gestion": "متجري"
      },
      "gestion": {
        "local": "المحل",
        "activites": "الأنشطة",
        "aucuneActivite": "لا يوجد نشاط معلن. اختر نشاطًا قبل إنشاء منتج.",
        "produits": "منتجاتي",
        "aucunProduit": "لا تعرض أي منتجات بعد.",
        "nouveau": "إنشاء منتج",
        "modifierActivites": "تعديل أنشطتي",
        "identite": "المحل : {{values.local}} · الأنشطة : {{values.activites}}"
      },
      "menu": {
        "boutique": "عرض متجري"
      },
      "global": {
        "aucuneMatiere": "لا توجد مواد: الأنشطة المعلنة لمتجرك لا تتيح التصنيع بعد."
      },
      "matiere": {
        "prix": "سعر إعادة الشراء",
        "enregistre": "حُفظ الإعداد",
        "illimite": "بلا حد",
        "utilisee": "تستخدمها منتجاتك",
        "refusCourt": "لا تريد منها",
        "maxAide": "حدد أقصى مخزون لكل مادة: 0 يعني أن متجرك لا يريدها ولن يتمكن أحد من بيعها لك. الحد المسموح: {{values.plafond}}."
      },
      "appro": {
        "titre": "بيع مواد أو التبرع بها",
        "recherche": "هذا المتجر يبحث عن",
        "aucune": "هذا المتجر لا يبحث عن مواد حاليًا.",
        "vous": "لديك",
        "besoin": "يمكنه قبول",
        "vendre": "بيع",
        "donner": "تبرع",
        "quantite": "الكمية",
        "vendu": "بيعت المادة",
        "donne": "تم التبرع بالمادة",
        "partiel": "لم يمكن قبول سوى {{values.faites}} وحدة من أصل {{values.voulues}}."
      },
      "ref": {
        "stockMax": "المخزون الأقصى",
        "maxAide": "0 يعني «بلا حد». تُرفض الدفعة كاملة إذا تجاوز إنتاجها هذا الحد: لا يمكن تقسيم إنتاج الوصفة."
      },
      "machine": {
        "plaque": "نظام RÉPUBLIA التجاري",
        "eteindre": "إغلاق"
      },
      "tab": {
        "caisse": "الصندوق",
        "produits": "المنتجات المعروضة",
        "matieres": "المواد الخام"
      },
      "caisse": {
        "solde": "الرصيد",
        "vosPa": "نقاط عملك",
        "montant": "المبلغ",
        "apport": "إيداع",
        "prelever": "سحب",
        "apportFait": "أُودعت المساهمة في الصندوق",
        "preleveFait": "تم السحب"
      },
      "col": {
        "produit": "المنتج",
        "matiere": "المادة",
        "stock": "المخزون",
        "stockMax": "أقصى مخزون",
        "prixVente": "سعر البيع",
        "rachat": "سعر إعادة الشراء"
      },
      "prod": {
        "lots": "الدفعات",
        "pa": "نقاط العمل",
        "verses": "مدفوعة",
        "enCours": "…"
      }
    }
  },
  "pt-BR": {
    "commercepj": {
      "titre": {
        "gestion": "Meu comércio"
      },
      "gestion": {
        "local": "Estabelecimento",
        "activites": "Atividades",
        "aucuneActivite": "Nenhuma atividade declarada. Escolha uma antes de criar um produto.",
        "produits": "Meus produtos",
        "aucunProduit": "Você ainda não oferece nenhum produto.",
        "nouveau": "Criar um produto",
        "modifierActivites": "Alterar minhas atividades",
        "identite": "Estabelecimento : {{values.local}} · Atividades : {{values.activites}}"
      },
      "menu": {
        "boutique": "Ver minha loja"
      },
      "global": {
        "aucuneMatiere": "Sem materiais: as atividades declaradas do comércio ainda não permitem fabricar nada."
      },
      "matiere": {
        "prix": "Preço de recompra",
        "enregistre": "Configuração salva",
        "illimite": "Sem limite",
        "utilisee": "Usado nos seus produtos",
        "refusCourt": "você não quer este material",
        "maxAide": "Defina o estoque máximo de cada material: 0 significa que seu comércio não o quer, e ninguém poderá vendê-lo a você. Máximo permitido: {{values.plafond}}."
      },
      "appro": {
        "titre": "Vender ou doar materiais",
        "recherche": "Este comércio procura",
        "aucune": "Este comércio não procura materiais no momento.",
        "vous": "Você tem",
        "besoin": "Pode aceitar",
        "vendre": "Vender",
        "donner": "Doar",
        "quantite": "Quantidade",
        "vendu": "Material vendido",
        "donne": "Material doado",
        "partiel": "Só foi possível aceitar {{values.faites}} das {{values.voulues}} unidades."
      },
      "ref": {
        "stockMax": "Estoque máximo",
        "maxAide": "0 significa “sem limite”. Um lote cujo rendimento ultrapasse este máximo é recusado por inteiro: o rendimento de uma receita não pode ser dividido."
      },
      "machine": {
        "plaque": "SISTEMA COMERCIAL RÉPUBLIA",
        "eteindre": "Fechar"
      },
      "tab": {
        "caisse": "Caixa",
        "produits": "Produtos vendidos",
        "matieres": "Matérias-primas"
      },
      "caisse": {
        "solde": "Saldo",
        "vosPa": "Seus PA",
        "montant": "Valor",
        "apport": "Aporte",
        "prelever": "Retirar",
        "apportFait": "Aporte depositado no caixa",
        "preleveFait": "Retirada realizada"
      },
      "col": {
        "produit": "Produto",
        "matiere": "Material",
        "stock": "Estoque",
        "stockMax": "Estoque máx.",
        "prixVente": "Preço de venda",
        "rachat": "Preço de recompra"
      },
      "prod": {
        "lots": "Lotes",
        "pa": "PA",
        "verses": "pagos",
        "enCours": "…"
      }
    }
  },
  "de": {
    "commercepj": {
      "titre": {
        "gestion": "Mein Geschäft"
      },
      "gestion": {
        "local": "Geschäftsraum",
        "activites": "Tätigkeiten",
        "aucuneActivite": "Keine Tätigkeit angegeben. Wähle eine, bevor du ein Produkt erstellst.",
        "produits": "Meine Produkte",
        "aucunProduit": "Du bietest noch keine Produkte an.",
        "nouveau": "Produkt erstellen",
        "modifierActivites": "Tätigkeiten ändern",
        "identite": "Geschäftsraum : {{values.local}} · Tätigkeiten : {{values.activites}}"
      },
      "menu": {
        "boutique": "Meinen Laden ansehen"
      },
      "global": {
        "aucuneMatiere": "Keine Materialien: Die angegebenen Tätigkeiten ermöglichen noch keine Herstellung."
      },
      "matiere": {
        "prix": "Ankaufspreis",
        "enregistre": "Einstellung gespeichert",
        "illimite": "Unbegrenzt",
        "utilisee": "Von deinen Produkten verwendet",
        "refusCourt": "du möchtest nichts davon",
        "maxAide": "Lege den maximalen Bestand jedes Materials fest: 0 bedeutet, dass dein Geschäft es nicht möchte und niemand es dir verkaufen kann. Zulässiges Maximum: {{values.plafond}}."
      },
      "appro": {
        "titre": "Materialien verkaufen oder spenden",
        "recherche": "Dieses Geschäft sucht",
        "aucune": "Dieses Geschäft sucht derzeit keine Materialien.",
        "vous": "Du besitzt",
        "besoin": "Es kann annehmen",
        "vendre": "Verkaufen",
        "donner": "Spenden",
        "quantite": "Menge",
        "vendu": "Material verkauft",
        "donne": "Material gespendet",
        "partiel": "Nur {{values.faites}} von {{values.voulues}} Einheiten konnten angenommen werden."
      },
      "ref": {
        "stockMax": "Maximaler Bestand",
        "maxAide": "0 bedeutet „unbegrenzt“. Eine Charge, deren Ertrag dieses Maximum überschreiten würde, wird vollständig abgelehnt: Der Ertrag eines Rezepts ist nicht teilbar."
      },
      "machine": {
        "plaque": "RÉPUBLIAS HANDELSSYSTEM",
        "eteindre": "Schließen"
      },
      "tab": {
        "caisse": "Kasse",
        "produits": "Verkaufte Produkte",
        "matieres": "Rohstoffe"
      },
      "caisse": {
        "solde": "Saldo",
        "vosPa": "Deine AP",
        "montant": "Betrag",
        "apport": "Einzahlung",
        "prelever": "Abheben",
        "apportFait": "Einzahlung in die Kasse erfolgt",
        "preleveFait": "Abhebung erfolgt"
      },
      "col": {
        "produit": "Produkt",
        "matiere": "Material",
        "stock": "Bestand",
        "stockMax": "Max. Bestand",
        "prixVente": "Verkaufspreis",
        "rachat": "Ankaufspreis"
      },
      "prod": {
        "lots": "Chargen",
        "pa": "AP",
        "verses": "ausgezahlt",
        "enCours": "…"
      }
    }
  }
};
 for(const[locale,tree]of Object.entries(words))if(global.RP_I18N_RESOURCES?.[locale]?.translation)global.RP_I18N_RESOURCES[locale].translation.commercepj=tree.commercepj;
})(window);
