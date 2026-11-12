// Énigme du trésor des Tsars, Novomirsk (Fred, 12/11/2026) : mots clés et répliques fixes des PNJ.
// /api/chat détecte un mot clé, puis demande au SERVEUR (tresor_tsars_parler, jeton du joueur) si la scène
// a lieu : lieu, ordre des étapes et possession du livre sont jugés en base. Sans scène, le dialogue
// continue normalement avec l'IA, qui ne connaît pas l'énigme : un PNJ abordé trop tôt ne révèle rien.

export const PNJ_TRESOR_TSARS = ['galina_karpova', 'evgueni_sudakov', 'tatiana_bortchova'];

const LANGUES = ['fr', 'en', 'es', 'zh-TW', 'ru', 'ko', 'ar', 'pt-BR', 'de'];

// Mots clés : mots entiers pour les langues à espaces (préfixe accepté à partir de 4 lettres, pour les
// pluriels et les déclinaisons), sous-chaîne pour le chinois, le coréen et l'arabe. Le français vaut
// toujours, quelle que soit la langue du joueur.
const MOTS = {
  galina_karpova: {
    fr: ['or', 'tresor', 'coffre'], en: ['gold', 'treasure', 'chest'], es: ['oro', 'tesoro', 'cofre'],
    'pt-BR': ['ouro', 'tesouro', 'cofre', 'bau'], de: ['gold', 'schatz', 'truhe', 'kiste'],
    ru: ['золот', 'клад', 'сокровищ', 'сундук'], 'zh-TW': ['黃金', '金子', '寶藏', '宝藏', '寶物', '箱子', '寶箱'],
    ko: ['황금', '금화', '보물', '상자'], ar: ['ذهب', 'كنز', 'صندوق']
  },
  evgueni_sudakov: {
    fr: ['or', 'tresor', 'coffre', 'aigle', 'imperial', 'imperiale', 'empereur', 'tsar', 'tsars'],
    en: ['gold', 'treasure', 'chest', 'eagle', 'imperial', 'emperor', 'tsar', 'czar'],
    es: ['oro', 'tesoro', 'cofre', 'aguila', 'imperial', 'emperador', 'zar'],
    'pt-BR': ['ouro', 'tesouro', 'cofre', 'bau', 'aguia', 'imperial', 'imperador', 'czar', 'tsar'],
    de: ['gold', 'schatz', 'truhe', 'kiste', 'adler', 'kaiser', 'kaiserlich', 'zar'],
    ru: ['золот', 'клад', 'сокровищ', 'сундук', 'орел', 'орёл', 'орл', 'импер', 'царь', 'цар'],
    'zh-TW': ['黃金', '金子', '寶藏', '宝藏', '寶物', '箱子', '寶箱', '鷹', '鹰', '帝國', '帝国', '皇帝', '沙皇'],
    ko: ['황금', '금화', '보물', '상자', '독수리', '제국', '황제', '차르'],
    ar: ['ذهب', 'كنز', 'صندوق', 'نسر', 'إمبراطور', 'امبراطور', 'قيصر']
  }
};
const SOUS_CHAINE = new Set(['zh-TW', 'ko', 'ar', 'ru']);

// /api/chat parle en codes à deux lettres (zh, pt) ; ce module en codes régionaux.
const CODE = { zh: 'zh-TW', pt: 'pt-BR' };
const langueModule = (l) => { const c = String(l || '').slice(0, 2).toLowerCase(); return CODE[c] || (LANGUES.includes(c) ? c : 'fr'); };

function normaliser(t) {
  return String(t || '').toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '');
}

// Tatiana réagit au livre lui-même (le serveur vérifie qu'il est dans l'inventaire) : pas de mot clé requis.
export function contientMotCle(profil, message, langue) {
  const listes = MOTS[profil];
  if (!listes) return false;
  const brut = normaliser(message);
  const mots = brut.split(/[^\p{L}\p{N}]+/u).filter(Boolean);
  const essayer = (lang) => (listes[lang] || []).some((cle) => {
    const k = normaliser(cle);
    if (SOUS_CHAINE.has(lang)) return brut.includes(k);
    return mots.some((m) => m === k || (k.length >= 4 && m.startsWith(k)));
  });
  const lang = langueModule(langue);
  return essayer('fr') || (lang !== 'fr' && essayer(lang));
}

const REPLIQUES = {
  karpova: [
    "Ah… vous aussi, vous avez entendu parler de cette histoire… ? Mon mari pêche de père en fils sur ce secteur. Nous n'avons jamais rien retrouvé, sauf ce morceau de bois gravé de l'aigle impérial… Il y a bien le vieux Evgueni Sudakov qui pourrait vous en parler, mais nos familles sont brouillées. Il est à l'EHPAD, mais il perd la tête, sauf quand il s'agit de nous insulter parce qu'on lui aurait pris sa zone de pêche.",
    "Ah… so you've heard that story too…? My husband's family have fished this stretch from father to son. We've never found a thing, except this piece of wood carved with the imperial eagle… There's old Evgueni Sudakov who could tell you about it, but our families aren't on speaking terms. He's in the care home, and he's losing his mind — except when it comes to insulting us because we supposedly took his fishing grounds.",
    "Ah… ¿usted también ha oído hablar de esa historia…? Mi marido pesca en este tramo de padre a hijo. Nunca hemos encontrado nada, salvo este trozo de madera grabado con el águila imperial… Está el viejo Evgueni Sudakov, que podría hablarle de ello, pero nuestras familias están peleadas. Está en la residencia de mayores y pierde la cabeza, salvo cuando se trata de insultarnos porque supuestamente le quitamos su zona de pesca.",
    "啊……您也聽說過那個故事了……？我丈夫家世世代代都在這一帶打魚。我們從來沒撈到過什麼，只有這塊刻著帝國雙頭鷹的木頭……老葉夫根尼·蘇達科夫倒是能跟您說說，可是我們兩家早就鬧翻了。他住在安養院，腦子已經不太清楚了，只有罵我們的時候特別清醒，因為他說我們搶了他的漁區。",
    "Ах… вы тоже слышали эту историю…? Мой муж рыбачит на этом участке, как его отец и дед. Мы так ничего и не нашли, кроме этого куска дерева с вырезанным имперским орлом… Есть ещё старый Евгений Судаков, он мог бы вам рассказать, но наши семьи в ссоре. Он в доме престарелых и совсем выжил из ума — кроме тех случаев, когда надо нас обругать за то, что мы будто бы отняли у него участок для ловли.",
    "아… 당신도 그 이야기를 들으셨군요…? 우리 남편네는 대대로 이 구역에서 고기를 잡아 왔어요. 아무것도 건진 적이 없어요. 제국 독수리가 새겨진 이 나무 조각 하나 빼고요… 예브게니 수다코프 영감이라면 이야기해 줄 수 있을 텐데, 우리 집안과는 사이가 틀어졌어요. 요양원에 있는데 정신이 오락가락해요. 우리가 자기 어장을 빼앗았다며 욕할 때만 빼고요.",
    "آه… أنت أيضاً سمعت بهذه الحكاية…؟ زوجي يصطاد في هذه الناحية أباً عن جد. لم نعثر على شيء قط، سوى قطعة الخشب هذه المنقوش عليها النسر الإمبراطوري… هناك العجوز إيفغيني سوداكوف، يمكنه أن يحدّثك عن ذلك، لكن عائلتينا متخاصمتان. إنه في دار رعاية المسنين، ويفقد عقله، إلا حين يتعلق الأمر بشتمنا لأننا، كما يزعم، أخذنا منه منطقة صيده.",
    "Ah… o senhor também ouviu falar dessa história…? Meu marido pesca neste trecho de pai para filho. Nunca encontramos nada, a não ser este pedaço de madeira gravado com a águia imperial… Tem o velho Evgueni Sudakov, que poderia lhe contar, mas nossas famílias estão brigadas. Ele está na casa de repouso e está perdendo o juízo, menos quando se trata de nos insultar porque teríamos tomado a zona de pesca dele.",
    "Ach … Sie haben also auch von dieser Geschichte gehört …? Mein Mann fischt in diesem Abschnitt, wie schon sein Vater und Großvater. Wir haben nie etwas gefunden, außer diesem Stück Holz mit dem eingeschnitzten Kaiseradler … Da wäre noch der alte Jewgeni Sudakow, der Ihnen davon erzählen könnte, aber unsere Familien sind verkracht. Er ist im Altenheim und verliert den Verstand — außer wenn es darum geht, uns zu beschimpfen, weil wir ihm angeblich sein Fanggebiet weggenommen haben."
  ],
  sudakov: [
    "*Ses yeux se mettent à briller.* Ahah, vous aussi, vous cherchez le trésor du tsar Sergueï le Terrible ?! J'ai couru après toute ma vie, en vain ! J'étais persuadé que la barque avait coulé le long des quais, là où ces maudits Karpov ont eu la concession de pêche ! J'avais fait la demande avant eux ! Je les déteste ! Grrrrrrrr !!!\n\nEh bien moi, ça me ferait plaisir que vous le trouviez avant eux ! Et j'ai un indice précieux ! Ici, à l'EHPAD, l'an passé, il y avait une vieille dame, décédée depuis… Elle faisait le ménage au palais présidentiel. Il y aurait là-bas un livre où l'on aurait consigné l'histoire du naufrage du tsar, avec l'endroit exact où la barque a coulé. Trouvez-le : il devrait vous permettre de retrouver le fameux trésor des tsars.",
    "*His eyes light up.* Haha, so you're after the treasure of Tsar Sergei the Terrible too?! I chased it all my life, in vain! I was convinced the boat sank along the quays, right where those cursed Karpovs got the fishing concession! I applied before them! I hate them! Grrrrrrrr!!!\n\nWell, I'd be delighted if you found it before they do! And I have a precious clue! Here in the care home, last year, there was an old lady — dead now… She used to clean at the presidential palace. There's supposed to be a book over there recording the story of the tsar's shipwreck, with the exact spot where the boat sank. Find it: it should lead you to the famous treasure of the tsars.",
    "*Le brillan los ojos.* ¡Jaja, usted también busca el tesoro del zar Serguéi el Terrible?! ¡Lo he perseguido toda mi vida, en vano! ¡Estaba convencido de que la barca se hundió a lo largo de los muelles, justo donde esos malditos Karpov obtuvieron la concesión de pesca! ¡Yo la había pedido antes que ellos! ¡Los detesto! ¡¡¡Grrrrrrrr!!!\n\n¡Pues a mí me encantaría que usted lo encontrara antes que ellos! ¡Y tengo una pista valiosa! Aquí, en la residencia, el año pasado había una anciana, fallecida desde entonces… Hacía la limpieza en el palacio presidencial. Allí habría un libro donde se consignó la historia del naufragio del zar, con el lugar exacto donde se hundió la barca. Encuéntrelo: debería permitirle dar con el famoso tesoro de los zares.",
    "*他的眼睛閃閃發亮。* 哈哈，您也在找「恐怖的」謝爾蓋沙皇的寶藏？！我追了一輩子，什麼也沒找到！我一直認定那艘小船是沉在碼頭邊，就在那些該死的卡爾波夫家拿到捕魚特許的地方！我可是比他們先申請的！我恨死他們了！嘎嘎嘎嘎嘎！！！\n\n好啊，要是您能比他們先找到，我可高興了！而且我有一條寶貴的線索！去年這家安養院裡住過一位老太太，現在已經過世了……她以前在總統府做清潔。據說那裡有一本書，記載了沙皇沉船的經過，還有小船沉沒的確切地點。找到它：它應該能帶您找到那著名的沙皇寶藏。",
    "*Его глаза загораются.* Ага, вы тоже ищете сокровище царя Сергея Грозного?! Я гонялся за ним всю жизнь, и всё зря! Я был уверен, что лодка затонула у набережной, там, где эти проклятые Карповы получили рыболовную концессию! Я подал заявку раньше них! Ненавижу их! Ррррррр!!!\n\nНу а я был бы рад, если бы вы нашли его раньше них! И у меня есть ценная подсказка! Здесь, в доме престарелых, в прошлом году жила одна старушка, с тех пор умерла… Она убиралась в президентском дворце. Там будто бы есть книга, где записана история крушения царя, с точным местом, где затонула лодка. Найдите её: она должна привести вас к знаменитому сокровищу царей.",
    "*그의 눈이 반짝이기 시작합니다.* 하하, 당신도 폭군 세르게이 차르의 보물을 찾는 거요?! 난 평생 그걸 쫓아다녔지만 허사였소! 난 그 배가 부두를 따라 가라앉았다고 굳게 믿었소. 바로 그 망할 카르포프네가 어업권을 따낸 자리 말이오! 내가 그들보다 먼저 신청했는데! 정말 싫소! 으르르르르르!!!\n\n그러니 당신이 그들보다 먼저 찾아낸다면 난 기쁘겠소! 그리고 나한테 귀한 단서가 있지! 작년에 이 요양원에 할머니 한 분이 있었는데, 지금은 세상을 떠났소… 대통령궁에서 청소를 하던 분이었지. 그곳에 차르의 난파 이야기가 적힌 책이 있다더군. 배가 가라앉은 정확한 장소까지 말이오. 그걸 찾으시오. 그러면 그 유명한 차르의 보물을 찾을 수 있을 거요.",
    "*تلمع عيناه.* هاها، أنت أيضاً تبحث عن كنز القيصر سيرغي الرهيب؟! لقد ركضت خلفه طوال حياتي بلا جدوى! كنت مقتنعاً بأن القارب غرق على طول الأرصفة، هناك حيث حصل آل كاربوف الملعونون على امتياز الصيد! لقد قدّمت الطلب قبلهم! أكرههم! غررررررر!!!\n\nحسناً، سيسعدني أن تجده قبلهم! ولديّ دليل ثمين! هنا في دار الرعاية، العام الماضي، كانت هناك سيدة عجوز توفيت منذ ذلك الحين… كانت تعمل في تنظيف القصر الرئاسي. يُقال إن هناك كتاباً دُوّنت فيه قصة غرق القيصر، مع المكان الدقيق الذي غرق فيه القارب. ابحث عنه: يُفترض أن يقودك إلى كنز القياصرة الشهير.",
    "*Os olhos dele brilham.* Haha, o senhor também está atrás do tesouro do czar Serguei, o Terrível?! Corri atrás dele a vida inteira, em vão! Eu tinha certeza de que o barco afundou ao longo do cais, bem onde aqueles malditos Karpov ganharam a concessão de pesca! Eu tinha pedido antes deles! Eu os detesto! Grrrrrrrr!!!\n\nPois eu ficaria feliz se o senhor o encontrasse antes deles! E tenho uma pista preciosa! Aqui na casa de repouso, no ano passado, havia uma senhora idosa, já falecida… Ela fazia a limpeza no palácio presidencial. Lá haveria um livro em que foi registrada a história do naufrágio do czar, com o local exato onde o barco afundou. Encontre-o: ele deve levá-lo ao famoso tesouro dos czares.",
    "*Seine Augen beginnen zu leuchten.* Haha, Sie suchen also auch den Schatz von Zar Sergej dem Schrecklichen?! Ich bin ihm mein ganzes Leben hinterhergelaufen, vergeblich! Ich war überzeugt, dass das Boot am Kai entlang gesunken ist, genau dort, wo diese verfluchten Karpows die Fischereikonzession bekommen haben! Ich hatte sie vor ihnen beantragt! Ich hasse sie! Grrrrrrrr!!!\n\nNun, mich würde es freuen, wenn Sie ihn vor ihnen finden! Und ich habe einen wertvollen Hinweis! Hier im Altenheim gab es letztes Jahr eine alte Dame, inzwischen verstorben … Sie hat im Präsidentenpalast geputzt. Dort soll es ein Buch geben, in dem die Geschichte vom Schiffbruch des Zaren aufgezeichnet ist, mit der genauen Stelle, an der das Boot sank. Finden Sie es: Es sollte Sie zum berühmten Schatz der Zaren führen."
  ],
  tatiana_livre: [
    "Montrez-moi ce que vous avez, peut-être que je pourrai alors vous aider, mais là, je ne sais pas de quoi vous parlez. C'est ce livre que vous cachez ? Donnez-le-moi.",
    "Show me what you've got — maybe then I can help you, but right now I don't know what you're talking about. Is it that book you're hiding? Give it to me.",
    "Enséñeme lo que tiene, quizá entonces pueda ayudarle, pero ahora mismo no sé de qué me habla. ¿Es ese libro lo que esconde? Démelo.",
    "把您手上的東西給我看看，也許我就能幫您了，不過現在我不知道您在說什麼。您藏著的是那本書嗎？給我吧。",
    "Покажите, что у вас есть, может, тогда я смогу вам помочь, а так я не понимаю, о чём вы. Это та книга, что вы прячете? Дайте её мне.",
    "가진 걸 보여 주세요. 그러면 도와드릴 수 있을지도 몰라요. 지금은 무슨 말씀인지 모르겠어요. 숨기고 계신 게 그 책인가요? 저한테 주세요.",
    "أرني ما لديك، فربما أستطيع مساعدتك حينها، أما الآن فلا أعرف عمّا تتحدث. هل هو هذا الكتاب الذي تخفيه؟ أعطني إياه.",
    "Mostre-me o que tem, talvez então eu possa ajudar, mas agora não sei do que está falando. É esse livro que está escondendo? Me dê.",
    "Zeigen Sie mir, was Sie haben, vielleicht kann ich Ihnen dann helfen, aber so weiß ich nicht, wovon Sie sprechen. Ist es dieses Buch, das Sie verstecken? Geben Sie es mir."
  ]
};

export function repliqueTresorTsars(scene, langue) {
  const l = REPLIQUES[scene];
  if (!l) return null;
  const i = LANGUES.indexOf(langueModule(langue));
  return l[i > 0 ? i : 0];
}
