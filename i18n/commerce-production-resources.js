/* Messages des verdicts existants, sans calcul ni nouvelle règle. */
(function(global){
 const words={
  "fr": {
    "unauthorized": "Vous n’êtes pas habilité à produire dans cet établissement.",
    "margin": "Le coût de ce lot dépasse la marge minimale à 25 FR. Aucun PA ni matière consommé.",
    "recipe": "Cette recette n'est pas autorisée pour cet établissement.",
    "pa": "{{values.pa}} PA requis.",
    "material": "Il manque du {{values.material}} en stock.",
    "cash": "L'établissement ne peut pas payer ce travail actuellement.",
    "full": "Le stock maximum de ce produit est atteint.",
    "served": "{{values.product}} — {{values.portions}} portions. +{{values.salary}} FR de salaire.",
    "journal": "Production de {{values.product}} ({{values.portions}} portions) à {{values.place}}."
  },
  "en": {
    "unauthorized": "You are not authorised to produce in this establishment.",
    "margin": "The cost of this batch exceeds the minimum margin at 25 FR. No AP or materials consumed.",
    "recipe": "This recipe is not authorised for this establishment.",
    "pa": "{{values.pa}} AP required.",
    "material": "Not enough {{values.material}} in stock.",
    "cash": "The establishment cannot pay for this work right now.",
    "full": "The maximum stock for this product has been reached.",
    "served": "{{values.product}} — {{values.portions}} portions. +{{values.salary}} FR in wages.",
    "journal": "Production of {{values.product}} ({{values.portions}} portions) at {{values.place}}."
  },
  "es": {
    "unauthorized": "No tienes autorización para producir en este establecimiento.",
    "margin": "El coste de este lote supera el margen mínimo a 25 FR. No se ha consumido ningún PA ni material.",
    "recipe": "Esta receta no está autorizada para este establecimiento.",
    "pa": "Se requieren {{values.pa}} PA.",
    "material": "Falta {{values.material}} en las existencias.",
    "cash": "El establecimiento no puede pagar este trabajo en este momento.",
    "full": "Se ha alcanzado el máximo de existencias de este producto.",
    "served": "{{values.product}} — {{values.portions}} porciones. +{{values.salary}} FR de salario.",
    "journal": "Producción de {{values.product}} ({{values.portions}} porciones) en {{values.place}}."
  },
  "zh-TW": {
    "unauthorized": "你未獲授權在此場所生產。",
    "margin": "此批次成本超出 25 FR 的最低利潤限制。未消耗任何行動點數或材料。",
    "recipe": "此配方未獲准用於此場所。",
    "pa": "需要 {{values.pa}} 行動點數。",
    "material": "庫存中的{{values.material}}不足。",
    "cash": "此場所目前無法支付這項工作。",
    "full": "此產品已達庫存上限。",
    "served": "{{values.product}} — {{values.portions}} 份。工資 +{{values.salary}} FR。",
    "journal": "在{{values.place}}生產{{values.product}}（{{values.portions}} 份）。"
  },
  "ru": {
    "unauthorized": "У вас нет права производить в этом заведении.",
    "margin": "Стоимость этой партии превышает минимальную маржу при 25 FR. ОД и материалы не потрачены.",
    "recipe": "Этот рецепт не разрешён для данного заведения.",
    "pa": "Требуется {{values.pa}} ОД.",
    "material": "На складе не хватает: {{values.material}}.",
    "cash": "Заведение сейчас не может оплатить эту работу.",
    "full": "Достигнут максимальный запас этого продукта.",
    "served": "{{values.product}} — {{values.portions}} порций. +{{values.salary}} FR зарплаты.",
    "journal": "Производство {{values.product}} ({{values.portions}} порций) в {{values.place}}."
  },
  "ko": {
    "unauthorized": "이 시설에서 생산할 권한이 없습니다.",
    "margin": "이 생산분의 비용이 25 FR 기준 최소 이윤 한도를 초과합니다. 행동력과 재료는 소모되지 않았습니다.",
    "recipe": "이 시설에서는 이 제작법을 사용할 수 없습니다.",
    "pa": "행동력 {{values.pa}} 필요.",
    "material": "재고에 {{values.material}}이(가) 부족합니다.",
    "cash": "현재 시설에서 이 작업의 임금을 지불할 수 없습니다.",
    "full": "이 상품의 최대 재고에 도달했습니다.",
    "served": "{{values.product}} — {{values.portions}}인분. 임금 +{{values.salary}} FR.",
    "journal": "{{values.place}}에서 {{values.product}} 생산({{values.portions}}인분)."
  },
  "ar": {
    "unauthorized": "لست مخوّلًا بالإنتاج في هذا المكان.",
    "margin": "تكلفة هذه الدفعة تتجاوز الحد الأدنى للهامش عند 25 FR. لم تُستهلك نقاط عمل أو مواد.",
    "recipe": "هذه الوصفة غير مسموحة في هذا المكان.",
    "pa": "يلزم {{values.pa}} من نقاط العمل.",
    "material": "المخزون لا يحتوي على ما يكفي من {{values.material}}.",
    "cash": "لا يستطيع المكان دفع أجر هذا العمل حاليًا.",
    "full": "بلغ مخزون هذا المنتج الحد الأقصى.",
    "served": "{{values.product}} — {{values.portions}} حصص. أجر +{{values.salary}} FR.",
    "journal": "إنتاج {{values.product}} ({{values.portions}} حصص) في {{values.place}}."
  },
  "pt-BR": {
    "unauthorized": "Você não tem autorização para produzir neste estabelecimento.",
    "margin": "O custo deste lote ultrapassa a margem mínima a 25 FR. Nenhum PA ou material consumido.",
    "recipe": "Esta receita não é autorizada para este estabelecimento.",
    "pa": "São necessários {{values.pa}} PA.",
    "material": "Falta {{values.material}} no estoque.",
    "cash": "O estabelecimento não pode pagar este trabalho no momento.",
    "full": "O estoque máximo deste produto foi atingido.",
    "served": "{{values.product}} — {{values.portions}} porções. +{{values.salary}} FR de salário.",
    "journal": "Produção de {{values.product}} ({{values.portions}} porções) em {{values.place}}."
  },
  "de": {
    "unauthorized": "Du bist nicht berechtigt, in diesem Betrieb zu produzieren.",
    "margin": "Die Kosten dieser Charge überschreiten die Mindestmarge bei 25 FR. Keine AP oder Materialien verbraucht.",
    "recipe": "Dieses Rezept ist für diesen Betrieb nicht zugelassen.",
    "pa": "{{values.pa}} AP erforderlich.",
    "material": "Nicht genügend {{values.material}} auf Lager.",
    "cash": "Der Betrieb kann diese Arbeit derzeit nicht bezahlen.",
    "full": "Der maximale Bestand dieses Produkts ist erreicht.",
    "served": "{{values.product}} — {{values.portions}} Portionen. +{{values.salary}} FR Lohn.",
    "journal": "Produktion von {{values.product}} ({{values.portions}} Portionen) in {{values.place}}."
  }
};
 for(const[locale,strings]of Object.entries(words))
  if(global.RP_I18N_RESOURCES?.[locale]?.translation)global.RP_I18N_RESOURCES[locale].translation.commerceProduction={...strings};
})(window);
