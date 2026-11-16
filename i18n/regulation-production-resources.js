/* Régulation de la production et fenêtre de récolte (16/11/2026), neuf langues.
 * Présentation seule : le serveur décide (regulation_production_lire / _fixer, recolte_effectuer).
 */
(function(global){
 const words={
  "fr": {
    "harvestTitle": "Récolter",
    "perAp": "{{values.n}} par PA",
    "limitPlayer": "Régulation : {{values.max}} récolte(s) par joueur et par jour ; vous en êtes à {{values.done}}.",
    "limitCity": "Plafond de la ville : {{values.done}} / {{values.max}} récolte(s) aujourd'hui.",
    "title": "Régulation de la production",
    "intro": "Pour chaque ressource de la ville : un maximum de récoltes par joueur et par jour et/ou un plafond total de la ville par jour. Laissez vide pour ne pas limiter ; 0 interdit la récolte. Chaque enregistrement coûte 1 PA.",
    "none": "Aucune ressource naturelle à récolter dans cette ville.",
    "today": "Aujourd'hui : {{values.n}} récolte(s) dans la ville.",
    "setBy": "Règle en vigueur, fixée par {{values.who}}.",
    "perPlayer": "Maximum par joueur et par jour",
    "cityCap": "Plafond total de la ville par jour",
    "save": "Enregistrer (1 PA)"
  },
  "en": {
    "harvestTitle": "Harvest",
    "perAp": "{{values.n}} per AP",
    "limitPlayer": "Regulation: {{values.max}} harvest(s) per player per day; you are at {{values.done}}.",
    "limitCity": "City cap: {{values.done}} / {{values.max}} harvest(s) today.",
    "title": "Production regulation",
    "intro": "For each resource of the city: a maximum number of harvests per player per day and/or a total city cap per day. Leave empty for no limit; 0 forbids harvesting. Each save costs 1 AP.",
    "none": "No natural resource to harvest in this city.",
    "today": "Today: {{values.n}} harvest(s) in the city.",
    "setBy": "Rule in force, set by {{values.who}}.",
    "perPlayer": "Maximum per player per day",
    "cityCap": "Total city cap per day",
    "save": "Save (1 AP)"
  },
  "es": {
    "harvestTitle": "Recolectar",
    "perAp": "{{values.n}} por PA",
    "limitPlayer": "Regulación: {{values.max}} recolección(es) por jugador y por día; lleva {{values.done}}.",
    "limitCity": "Tope de la ciudad: {{values.done}} / {{values.max}} recolección(es) hoy.",
    "title": "Regulación de la producción",
    "intro": "Para cada recurso de la ciudad: un máximo de recolecciones por jugador y por día y/o un tope total de la ciudad por día. Déjelo vacío para no limitar; 0 prohíbe recolectar. Cada registro cuesta 1 PA.",
    "none": "No hay ningún recurso natural que recolectar en esta ciudad.",
    "today": "Hoy: {{values.n}} recolección(es) en la ciudad.",
    "setBy": "Regla vigente, fijada por {{values.who}}.",
    "perPlayer": "Máximo por jugador y por día",
    "cityCap": "Tope total de la ciudad por día",
    "save": "Registrar (1 PA)"
  },
  "zh-TW": {
    "harvestTitle": "採集",
    "perAp": "每點行動點 {{values.n}}",
    "limitPlayer": "管制：每位玩家每日 {{values.max}} 次採集；您已採集 {{values.done}} 次。",
    "limitCity": "全市上限：今日 {{values.done}} / {{values.max}} 次採集。",
    "title": "生產管制",
    "intro": "本市每種資源：每位玩家每日的採集上限，及／或全市每日總上限。留空表示不設限；0 表示禁止採集。每次儲存消耗 1 點行動點。",
    "none": "本市沒有可採集的天然資源。",
    "today": "今日：全市 {{values.n}} 次採集。",
    "setBy": "現行規定，由 {{values.who}} 訂定。",
    "perPlayer": "每位玩家每日上限",
    "cityCap": "全市每日總上限",
    "save": "儲存（1 點行動點）"
  },
  "ru": {
    "harvestTitle": "Собрать",
    "perAp": "{{values.n}} за ОД",
    "limitPlayer": "Регулирование: {{values.max}} сбор(ов) на игрока в день; у вас уже {{values.done}}.",
    "limitCity": "Предел города: {{values.done}} / {{values.max}} сбор(ов) сегодня.",
    "title": "Регулирование добычи",
    "intro": "Для каждого ресурса города: максимум сборов на игрока в день и/или общий дневной предел для города. Оставьте пустым, чтобы не ограничивать; 0 запрещает сбор. Каждое сохранение стоит 1 ОД.",
    "none": "В этом городе нет природных ресурсов для сбора.",
    "today": "Сегодня: {{values.n}} сбор(ов) в городе.",
    "setBy": "Действующее правило, установлено: {{values.who}}.",
    "perPlayer": "Максимум на игрока в день",
    "cityCap": "Общий дневной предел города",
    "save": "Сохранить (1 ОД)"
  },
  "ko": {
    "harvestTitle": "채집",
    "perAp": "행동력 1당 {{values.n}}",
    "limitPlayer": "규제: 플레이어당 하루 {{values.max}}회 채집; 현재 {{values.done}}회.",
    "limitCity": "도시 상한: 오늘 {{values.done}} / {{values.max}}회 채집.",
    "title": "생산 규제",
    "intro": "도시의 각 자원마다: 플레이어별 하루 채집 한도 및/또는 도시 전체의 하루 상한. 비워 두면 제한이 없고, 0이면 채집이 금지됩니다. 저장할 때마다 행동력 1이 듭니다.",
    "none": "이 도시에는 채집할 천연자원이 없습니다.",
    "today": "오늘: 도시 전체 {{values.n}}회 채집.",
    "setBy": "현행 규정, {{values.who}}이(가) 정함.",
    "perPlayer": "플레이어별 하루 한도",
    "cityCap": "도시 전체 하루 상한",
    "save": "저장 (행동력 1)"
  },
  "ar": {
    "harvestTitle": "جمع",
    "perAp": "{{values.n}} لكل نقطة عمل",
    "limitPlayer": "تنظيم: {{values.max}} عملية جمع لكل لاعب في اليوم؛ بلغتَ {{values.done}}.",
    "limitCity": "سقف المدينة: {{values.done}} / {{values.max}} عملية جمع اليوم.",
    "title": "تنظيم الإنتاج",
    "intro": "لكل مورد في المدينة: حد أقصى لعمليات الجمع لكل لاعب في اليوم و/أو سقف إجمالي للمدينة في اليوم. اتركه فارغًا لعدم التقييد؛ والقيمة 0 تمنع الجمع. كل تسجيل يكلّف نقطة عمل واحدة.",
    "none": "لا يوجد مورد طبيعي للجمع في هذه المدينة.",
    "today": "اليوم: {{values.n}} عملية جمع في المدينة.",
    "setBy": "القاعدة السارية، حدّدها {{values.who}}.",
    "perPlayer": "الحد الأقصى لكل لاعب في اليوم",
    "cityCap": "السقف الإجمالي للمدينة في اليوم",
    "save": "تسجيل (نقطة عمل واحدة)"
  },
  "pt-BR": {
    "harvestTitle": "Colher",
    "perAp": "{{values.n}} por PA",
    "limitPlayer": "Regulação: {{values.max}} coleta(s) por jogador por dia; você está em {{values.done}}.",
    "limitCity": "Teto da cidade: {{values.done}} / {{values.max}} coleta(s) hoje.",
    "title": "Regulação da produção",
    "intro": "Para cada recurso da cidade: um máximo de coletas por jogador por dia e/ou um teto total da cidade por dia. Deixe vazio para não limitar; 0 proíbe a coleta. Cada registro custa 1 PA.",
    "none": "Nenhum recurso natural para coletar nesta cidade.",
    "today": "Hoje: {{values.n}} coleta(s) na cidade.",
    "setBy": "Regra em vigor, fixada por {{values.who}}.",
    "perPlayer": "Máximo por jogador por dia",
    "cityCap": "Teto total da cidade por dia",
    "save": "Registrar (1 PA)"
  },
  "de": {
    "harvestTitle": "Sammeln",
    "perAp": "{{values.n}} pro AP",
    "limitPlayer": "Regulierung: {{values.max}} Ernte(n) pro Spieler und Tag; Sie stehen bei {{values.done}}.",
    "limitCity": "Obergrenze der Stadt: heute {{values.done}} / {{values.max}} Ernte(n).",
    "title": "Produktionsregulierung",
    "intro": "Für jede Ressource der Stadt: ein Höchstwert an Ernten pro Spieler und Tag und/oder eine Gesamtobergrenze der Stadt pro Tag. Leer lassen für keine Begrenzung; 0 verbietet das Ernten. Jedes Speichern kostet 1 AP.",
    "none": "In dieser Stadt gibt es keine natürliche Ressource zu ernten.",
    "today": "Heute: {{values.n}} Ernte(n) in der Stadt.",
    "setBy": "Geltende Regel, festgelegt von {{values.who}}.",
    "perPlayer": "Höchstwert pro Spieler und Tag",
    "cityCap": "Gesamtobergrenze der Stadt pro Tag",
    "save": "Speichern (1 AP)"
  }
};
 for(const[locale,strings]of Object.entries(words))if(global.RP_I18N_RESOURCES?.[locale]?.translation)global.RP_I18N_RESOURCES[locale].translation.regulationProduction={...strings};
})(window);
