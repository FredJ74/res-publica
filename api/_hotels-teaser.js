// Capitales en teaser (Fred, 28/11/2026) : répliques fixes et mémoire des PNJ référents des hôtels de Ciudad Roja et d'Al Madina.
// Le serveur décide (ciudad_roja_augusto_tirade : une fois par joueur, à la piscine ; hotel_teaser_habitues : passages réels).

export const PNJ_PISCINE_CIUDAD_ROJA = ['svetlana_zolotova', 'valentina_fuego'];
export const PNJ_REFERENTS_HABITUES = ['matias_bandeja', 'rosario_esmeralda', 'karim_sahn', 'faris_dukhan', 'amira_miftah'];

// Texte exact de Fred en français ; traductions fidèles pour les huit autres langues.
const TIRADE_AUGUSTO = {
  fr: "Dis donc Gringo, tu ne serais pas en train d'essayer de me voler mes filles ?! Tu crois peut-être avoir une chance ? Tu sais pourquoi elles sont avec moi ? Parce que je suis beau... AHAHAH ! Mais non, c'est parce que je les paye ! Alors si tu as de l'argent, tu appelles l'agence Roxane Velours, et ils te trouveront ce que tu veux ! Femmes, hommes, peu importe ! Et si tu as de l'argent, invite-toi à notre table de joueurs de poker au casino de la ville. On aime bien les petits présomptueux de ton espèce. Ton arrogance me plaît, gringo !",
  en: "Hey Gringo, you wouldn't be trying to steal my girls, would you?! You think you stand a chance? You know why they're with me? Because I'm handsome... AHAHAH! No, it's because I pay them! So if you've got money, call the Roxane Velours agency and they'll find you whatever you want! Women, men, whatever! And if you've got money, join our poker table at the city casino. We like cocky little guys like you. I like your arrogance, gringo!",
  es: "¡Oye, Gringo! ¿No estarás intentando robarme a mis chicas?! ¿Crees que tienes alguna oportunidad? ¿Sabes por qué están conmigo? Porque soy guapo... ¡AJAJAJ! ¡Pues no, es porque les pago! Así que si tienes dinero, llama a la agencia Roxane Velours y te encontrarán lo que quieras. ¡Mujeres, hombres, da igual! Y si tienes dinero, siéntate a nuestra mesa de póker en el casino de la ciudad. Nos gustan los presumidos como tú. ¡Me gusta tu arrogancia, gringo!",
  de: "Sag mal, Gringo, du versuchst doch nicht etwa, mir meine Mädchen auszuspannen?! Glaubst du, du hast eine Chance? Weißt du, warum sie bei mir sind? Weil ich schön bin... AHAHAH! Nein, weil ich sie bezahle! Wenn du also Geld hast, ruf die Agentur Roxane Velours an, die finden dir, was du willst! Frauen, Männer, egal! Und wenn du Geld hast, setz dich an unseren Pokertisch im Casino der Stadt. Wir mögen kleine Angeber wie dich. Deine Arroganz gefällt mir, Gringo!",
  ru: "Слушай, гринго, ты что, пытаешься увести моих девочек?! Думаешь, у тебя есть шанс? Знаешь, почему они со мной? Потому что я красавец... АХАХАХ! Да нет, потому что я им плачу! Так что если у тебя есть деньги — звони в агентство «Роксана Велур», там найдут что захочешь! Женщины, мужчины — неважно! А если есть деньги, подсаживайся к нашему покерному столу в городском казино. Мы любим таких самоуверенных юнцов, как ты. Мне нравится твоя наглость, гринго!",
  ko: "이봐 그링고, 설마 내 여자들을 빼앗으려는 건 아니겠지?! 네가 승산이 있다고 생각해? 그녀들이 왜 나랑 있는지 알아? 내가 잘생겨서… 아하하! 아니, 내가 돈을 주니까지! 그러니 돈이 있으면 록산 벨루르 에이전시에 전화해. 원하는 걸 찾아줄 거야! 여자든 남자든 상관없어! 그리고 돈이 있으면 시내 카지노의 우리 포커 테이블에 끼어. 너 같은 건방진 녀석이 마음에 들거든. 네 오만함이 마음에 든다, 그링고!",
  ar: "اسمع يا غرينغو، لا تحاول أن تسرق فتياتي، أليس كذلك؟! أتظن أن لك فرصة؟ أتعرف لماذا هنّ معي؟ لأنني وسيم... هاهاها! لا، بل لأنني أدفع لهنّ! فإن كان معك مال، اتصل بوكالة روكسان فولور وسيجدون لك ما تريد! نساء، رجال، لا يهم! وإن كان معك مال، فانضم إلى طاولة البوكر عندنا في كازينو المدينة. نحب المغرورين الصغار من أمثالك. تعجبني غطرستك يا غرينغو!",
  'pt-BR': "Ei, Gringo, você não estaria tentando roubar as minhas garotas, estaria?! Acha que tem alguma chance? Sabe por que elas estão comigo? Porque eu sou bonito... AHAHAH! Que nada, é porque eu pago! Então, se você tem dinheiro, ligue para a agência Roxane Velours e eles vão encontrar o que você quiser! Mulheres, homens, tanto faz! E se você tem dinheiro, sente-se à nossa mesa de pôquer no cassino da cidade. A gente gosta de presunçosos como você. Gosto da sua arrogância, gringo!",
  'zh-TW': "喂，外國佬，你該不會想搶我的姑娘吧？！你以為你有機會嗎？知道她們為什麼跟著我嗎？因為我長得帥……哈哈哈！才不是，是因為我付錢給她們！所以你要是有錢，就打給洛珊·維洛經紀公司，他們會幫你找到你想要的！女人、男人，都行！要是你有錢，就來城裡賭場我們的撲克桌坐坐。我們就喜歡你這種自以為是的小子。我欣賞你的傲慢，外國佬！"
};

export function repliqueAugusto(langue) {
  const texte = TIRADE_AUGUSTO[langue] || TIRADE_AUGUSTO.fr;
  return 'Don Augusto Bigotes : « ' + texte + ' »';
}

// Consigne ajoutée au prompt d'un référent : les habitués réels de sa pièce (30 derniers jours).
export function consigneHabitues(v) {
  if (!v || v.ok !== true || !Array.isArray(v.habitues)) return '';
  if (!v.habitues.length) return 'HABITUÉS RÉELS : personne n’est venu ces trente derniers jours ; tu le dis si on te le demande, sans inventer de nom.';
  return 'HABITUÉS RÉELS (passages comptés par l’hôtel ces trente derniers jours ; tu peux les citer, sans inventer d’autres noms ni de chiffres) : '
    + v.habitues.map(h => String(h.nom) + ' (' + Number(h.passages) + ' passage' + (Number(h.passages) > 1 ? 's' : '') + ')').join(', ') + '.';
}

// Les deux douaniers moustachus de Ciudad Roja ne répondent qu'une chose (Fred, 28/11/2026).
export const PNJ_DOUANIERS_MOUSTACHUS = ['douanier_moustachu_uno', 'douanier_moustachu_dos'];
const VOYEZ_CHEFFE = { fr: 'Voyez avec la cheffe.', en: 'See the boss.', es: 'Vea con la jefa.', de: 'Fragen Sie die Chefin.', ru: 'Обращайтесь к начальнице.',
  ko: '대장님께 물어보세요.', ar: 'راجع الرئيسة.', 'pt-BR': 'Fale com a chefe.', 'zh-TW': '去找頭兒。' };
export const repliqueDouanier = langue => VOYEZ_CHEFFE[langue] || VOYEZ_CHEFFE.fr;
