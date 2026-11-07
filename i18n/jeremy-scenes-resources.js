/* Deux premières scènes de visite de Jérémy.
 * Affichage seulement : aucun état, aucune transition ou autorité métier.
 */
(function(global){
 'use strict';
 const resources=global.RP_I18N_RESOURCES;
 if(!resources)return;
 const labels={
  "fr": {
    "welcomeJeremy": "Bonjour, je suis Jérémy, le stagiaire à tout faire de ce maudit Hôtel de Ville. Je suis bien content de pouvoir vous guider, le secrétaire n'arrête pas de me demander de lui faire du café et des photocopies. On va commencer par aller dans un endroit plus calme. On va aller dans la salle des élections.",
    "hotelInstructions": "Donc une bonne chambre, c'est primordial, mais un bon repas aussi. Il y a tout ça à l'hôtel-restaurant. On y va ?<br><br>C'est le deuxième bâtiment après l'Hôtel de Ville. Vous vous souvenez où c'est ? On en vient. Il faut sortir du bâtiment et aller à droite."
  },
  "en": {
    "welcomeJeremy": "Hello, I'm Jérémy, the all-purpose intern at this wretched Town Hall. I'm happy to show you around. The secretary keeps asking me to make coffee and photocopies. Let's start somewhere quieter: the elections room.",
    "hotelInstructions": "A decent room is essential, but so is a good meal. The hotel-restaurant has both. Shall we go?<br><br>It's the second building after Town Hall. Remember where it is? We just passed it. Leave the building and turn right."
  },
  "es": {
    "welcomeJeremy": "Hola, soy Jérémy, el becario para todo de este maldito Ayuntamiento. Me alegra poder guiarle. El secretario no deja de pedirme cafés y fotocopias. Empezaremos en un lugar más tranquilo: la sala de elecciones.",
    "hotelInstructions": "Una buena habitación es fundamental, pero comer bien también. El hotel-restaurante tiene ambas cosas. ¿Vamos?<br><br>Es el segundo edificio después del Ayuntamiento. ¿Recuerda dónde está? Acabamos de pasar por allí. Salga del edificio y gire a la derecha."
  },
  "zh-TW": {
    "welcomeJeremy": "你好，我是 Jérémy，這座討厭的市政廳裡什麼雜事都得做的實習生。很高興能帶你四處看看。秘書總是叫我泡咖啡、影印文件。我們先去個安靜一點的地方吧：選舉室。",
    "hotelInstructions": "一間好房間很重要，一頓好飯也一樣重要。旅館餐廳兩樣都有。要去嗎？<br><br>那是市政廳後面的第二棟建築。還記得在哪裡嗎？我們才剛經過。先離開這棟樓，再向右走。"
  },
  "ru": {
    "welcomeJeremy": "Здравствуйте, я Jérémy, стажёр на все руки в этой проклятой мэрии. Рад буду показать вам город. Секретарь без конца заставляет меня варить кофе и делать копии. Для начала пойдём туда, где поспокойнее, — в избирательный зал.",
    "hotelInstructions": "Хорошая комната — это главное, но и нормально поесть не помешает. В гостинице-ресторане есть и то и другое. Пойдёмте?<br><br>Это второе здание после мэрии. Помните, где оно? Мы только что оттуда. Выйдите из здания и поверните направо."
  },
  "ko": {
    "welcomeJeremy": "안녕하세요, 저는 이 지긋지긋한 시청에서 온갖 잡일을 하는 인턴 Jérémy입니다. 안내해 드릴 수 있어 기뻐요. 비서가 자꾸 커피를 타고 복사하라고 시키거든요. 우선 좀 조용한 곳인 선거실로 가죠.",
    "hotelInstructions": "좋은 방도 중요하지만 잘 먹는 것도 중요해요. 호텔 겸 식당에는 둘 다 있죠. 가볼까요?<br><br>시청 다음 두 번째 건물이에요. 어디인지 기억나세요? 방금 지나온 곳이죠. 건물에서 나가 오른쪽으로 가면 됩니다."
  },
  "ar": {
    "welcomeJeremy": "مرحبًا، أنا Jérémy، المتدرب الذي يُكلَّف بكل الأعمال في مبنى البلدية المزعج هذا. يسعدني أن أرشدك؛ فالسكرتير لا يكف عن مطالبتي بإعداد القهوة وتصوير الأوراق. لنبدأ بمكان أكثر هدوءًا: قاعة الانتخابات.",
    "hotelInstructions": "الغرفة الجيدة ضرورية، وكذلك الوجبة الجيدة. ستجد الأمرين في الفندق والمطعم. هل نذهب؟<br><br>إنه المبنى الثاني بعد البلدية. هل تتذكر مكانه؟ مررنا به للتو. اخرج من المبنى واتجه يمينًا."
  },
  "pt-BR": {
    "welcomeJeremy": "Olá, sou Jérémy, o estagiário faz-tudo desta maldita Prefeitura. Fico feliz em mostrar a cidade para você. O secretário não para de me mandar fazer café e tirar cópias. Vamos começar por um lugar mais tranquilo: a sala das eleições.",
    "hotelInstructions": "Um bom quarto é essencial, mas uma boa refeição também. O hotel-restaurante oferece os dois. Vamos lá?<br><br>É o segundo prédio depois da Prefeitura. Lembra onde fica? Acabamos de passar por lá. Saia do prédio e vire à direita."
  },
  "de": {
    "welcomeJeremy": "Hallo, ich bin Jérémy, der Praktikant für alles in diesem verfluchten Rathaus. Ich freue mich, Sie herumzuführen. Der Sekretär lässt mich ständig Kaffee kochen und Kopien machen. Fangen wir an einem ruhigeren Ort an: im Wahlraum.",
    "hotelInstructions": "Ein gutes Zimmer ist wichtig, aber gutes Essen auch. Im Hotel-Restaurant gibt es beides. Gehen wir?<br><br>Es ist das zweite Gebäude nach dem Rathaus. Wissen Sie noch, wo es ist? Wir sind gerade daran vorbeigekommen. Verlassen Sie das Gebäude und gehen Sie nach rechts."
  }
};
 const next={
  "fr": {
    "sleepInstructions": "Chaque jour, on se fatigue au travail. Il est important de se reposer en dormant. Une fois par jour seulement.<br><br>Idéalement, il vaut mieux dormir dans une chambre, on récupère mieux que si on dort n'importe où. Je vous montrerai juste après.",
    "hotelRoom": "Ici vous pouvez réserver une chambre, ou si vous avez les moyens, louer une suite. Une bonne nuit ici, c'est plus d'énergie pour le lendemain.",
    "barIntroduction": "Ici c'est un lieu un peu spécial, pas toujours bien fréquenté...<br><br>Enfin, c'est ce qu'on m'a dit, je n'ai pas le droit de venir seul ici, seulement avec des adultes.<br><br>Vous pouvez m'offrir un verre ? J'ai très soif à force de parler."
  },
  "en": {
    "sleepInstructions": "Every day, work tires us out. It's important to rest by sleeping. Only once a day.<br><br>Ideally, sleep in a room: you'll recover better than if you sleep just anywhere. I'll show you in a moment.",
    "hotelRoom": "Here you can book a room or, if you can afford it, rent a suite. A good night's sleep here means more energy tomorrow.",
    "barIntroduction": "This place is a little unusual, and the crowd isn't always the most respectable...<br><br>Or so I've been told. I'm not allowed to come here alone, only with adults.<br><br>Could you buy me a drink? All this talking has made me thirsty."
  },
  "es": {
    "sleepInstructions": "Cada día nos cansamos trabajando. Es importante descansar durmiendo, pero solo una vez al día.<br><br>Lo ideal es dormir en una habitación: recuperará mejor que si duerme en cualquier sitio. Enseguida se lo mostraré.",
    "hotelRoom": "Aquí puede reservar una habitación o, si tiene dinero, alquilar una suite. Una buena noche aquí le dará más energía para mañana.",
    "barIntroduction": "Este lugar es un poco especial; no siempre viene gente de fiar...<br><br>O eso me han dicho. No puedo venir solo, únicamente acompañado de adultos.<br><br>¿Me invita a una bebida? Tengo mucha sed de tanto hablar."
  },
  "zh-TW": {
    "sleepInstructions": "每天工作都會讓人疲倦，所以睡覺休息很重要。每天只能睡一次。<br><br>最好在房間裡睡，恢復效果比隨便找地方睡要好。我等一下就帶你看看。",
    "hotelRoom": "你可以在這裡訂房；手頭寬裕的話，也能租套房。在這裡好好睡一晚，明天就更有精神。",
    "barIntroduction": "這裡有點特別，來往的人不見得都很正派……<br><br>至少別人是這樣告訴我的。我不准自己來，得有大人陪同才行。<br><br>可以請我喝一杯嗎？講了這麼多話，口都渴了。"
  },
  "ru": {
    "sleepInstructions": "После работы каждый день устаёшь. Нужно отдыхать и спать. Но спать можно только раз в день.<br><br>Лучше всего — в комнате: так силы восстанавливаются лучше, чем где попало. Скоро покажу.",
    "hotelRoom": "Здесь можно забронировать комнату, а если средства позволяют — снять люкс. После хорошей ночи здесь завтра у вас будет больше сил.",
    "barIntroduction": "Это место немного особенное, публика тут не всегда приличная…<br><br>Ну, мне так говорили. Одному сюда мне нельзя — только со взрослыми.<br><br>Не угостите меня напитком? От разговоров ужасно хочется пить."
  },
  "ko": {
    "sleepInstructions": "매일 일하면 피곤해져요. 그래서 잠으로 쉬는 게 중요하죠. 하루에 한 번만 잘 수 있어요.<br><br>아무 데서나 자는 것보다 방에서 자는 편이 회복에 훨씬 좋아요. 잠시 후 보여 드릴게요.",
    "hotelRoom": "여기서는 객실을 예약할 수 있고, 여유가 있다면 스위트룸을 빌릴 수도 있어요. 여기서 푹 자면 다음 날 더 많은 에너지가 생기죠.",
    "barIntroduction": "여긴 좀 특이한 곳이에요. 손님들이 항상 점잖은 건 아니거든요…<br><br>그렇다고 들었어요. 저는 어른 없이 혼자 오면 안 된대요.<br><br>마실 것 하나 사주실래요? 계속 얘기했더니 목이 너무 말라요."
  },
  "ar": {
    "sleepInstructions": "نتعب من العمل كل يوم، ومن المهم أن نستريح بالنوم، لكن مرة واحدة فقط في اليوم.<br><br>من الأفضل أن تنام في غرفة؛ فذلك يعيد إليك طاقتك أكثر من النوم في أي مكان. سأريك ذلك بعد قليل.",
    "hotelRoom": "يمكنك حجز غرفة هنا، أو استئجار جناح إن كنت قادرًا على تحمّل تكلفته. ليلة نوم جيدة هنا تمنحك طاقة أكبر في الغد.",
    "barIntroduction": "هذا المكان مميز بعض الشيء، وروّاده ليسوا دائمًا من أفضل الناس...<br><br>هكذا أخبروني على الأقل. لا يُسمح لي بالمجيء وحدي؛ يجب أن أرافق بالغين.<br><br>هل تشتري لي مشروبًا؟ لقد عطشت من كثرة الكلام."
  },
  "pt-BR": {
    "sleepInstructions": "Todo dia a gente se cansa trabalhando. É importante descansar dormindo, mas só uma vez por dia.<br><br>O ideal é dormir num quarto: você recupera mais energia do que dormindo em qualquer lugar. Já vou mostrar.",
    "hotelRoom": "Aqui você pode reservar um quarto ou, se tiver dinheiro, alugar uma suíte. Uma boa noite de sono aqui traz mais energia para amanhã.",
    "barIntroduction": "Este lugar é um pouco diferente, nem sempre é bem frequentado...<br><br>Pelo menos foi o que me disseram. Não posso vir sozinho, só acompanhado de adultos.<br><br>Você pode me pagar uma bebida? Estou morrendo de sede de tanto falar."
  },
  "de": {
    "sleepInstructions": "Jeden Tag macht uns die Arbeit müde. Schlaf ist wichtig, aber man kann nur einmal am Tag schlafen.<br><br>Am besten schlafen Sie in einem Zimmer: Dort erholen Sie sich besser als irgendwo sonst. Ich zeige es Ihnen gleich.",
    "hotelRoom": "Hier können Sie ein Zimmer reservieren oder, wenn Sie es sich leisten können, eine Suite mieten. Nach einer guten Nacht hier haben Sie morgen mehr Energie.",
    "barIntroduction": "Dieser Ort ist etwas Besonderes. Das Publikum ist nicht immer ganz vertrauenswürdig...<br><br>Zumindest hat man mir das gesagt. Allein darf ich nicht herkommen, nur in Begleitung Erwachsener.<br><br>Könnten Sie mir ein Getränk ausgeben? Vom vielen Reden habe ich großen Durst."
  }
};
 for(const [lang,strings] of Object.entries(next)) Object.assign(labels[lang],strings);
 const cityTour={
  "fr": {
    "clinic": "Ici c'est le dispensaire. On peut se faire soigner gratuitement, ou à moindre frais. Bien sûr, si vous êtes riche, vous pouvez aller en hôpital privé pour de meilleurs soins.<br><br>Il y a aussi nos anciens, ici, à l'EHPAD. Ils sont un peu la mémoire de la ville, vous savez.<br><br>N'hésitez pas à venir leur parler.",
    "electionRoom": "Ici on est au cœur du système électoral car c'est ici qu'on vote.<br><br>On peut aussi voir qui est candidat aux élections par exemple.<br><br>Chaque pièce est dédiée à un usage.<br><br>À présent, on va aller en ville. On va déjà sortir de l'Hôtel de Ville."
  },
  "en": {
    "clinic": "This is the health clinic. You can receive treatment here for free or at low cost. If you're wealthy, of course, you can go to a private hospital for better care.<br><br>Our elderly residents are here too, in the care home. They're part of the town's memory, you know.<br><br>Don't hesitate to talk to them.",
    "electionRoom": "This is the heart of the electoral system: it's where we vote.<br><br>You can also see who's standing in the elections, for example.<br><br>Each room serves a different purpose.<br><br>Now let's head into town. First we need to leave Town Hall."
  },
  "es": {
    "clinic": "Este es el dispensario. Aquí puede recibir atención gratuita o a bajo precio. Si tiene dinero, claro, puede ir a un hospital privado para obtener mejores cuidados.<br><br>También están aquí nuestros mayores, en la residencia. Son un poco la memoria de la ciudad.<br><br>No dude en hablar con ellos.",
    "electionRoom": "Este es el corazón del sistema electoral, porque aquí se vota.<br><br>También puede ver quién se presenta a las elecciones, por ejemplo.<br><br>Cada sala tiene una función distinta.<br><br>Ahora iremos a la ciudad. Primero hay que salir del Ayuntamiento."
  },
  "zh-TW": {
    "clinic": "這裡是醫療站。你可以免費接受治療，或只付少量費用。當然，如果你很有錢，也能去私人醫院接受更好的照護。<br><br>我們的長者也住在這裡的養老院。他們就像是這座城市的活歷史。<br><br>有空不妨跟他們聊聊。",
    "electionRoom": "這裡是選舉制度的核心，因為大家就在這裡投票。<br><br>你也能查詢有哪些人參加選舉。<br><br>每個房間都有不同的用途。<br><br>現在我們要去城裡了。先離開市政廳吧。"
  },
  "ru": {
    "clinic": "Это медпункт. Здесь можно лечиться бесплатно или за небольшую плату. Если вы богаты, разумеется, можете обратиться в частную больницу за лучшим уходом.<br><br>Здесь же, в доме престарелых, живут наши старики. Они, можно сказать, сама память города.<br><br>Не стесняйтесь с ними разговаривать.",
    "electionRoom": "Здесь — сердце избирательной системы: именно тут проходят голосования.<br><br>Можно, например, посмотреть, кто баллотируется на выборах.<br><br>У каждой комнаты своё назначение.<br><br>А теперь отправимся в город. Сначала выйдем из мэрии."
  },
  "ko": {
    "clinic": "여기는 진료소예요. 무료나 저렴한 비용으로 치료받을 수 있죠. 물론 돈이 많다면 더 나은 치료를 위해 사립 병원에 갈 수도 있어요.<br><br>여기 요양원에는 어르신들도 계세요. 도시의 기억을 간직한 분들이죠.<br><br>기회가 있으면 이야기를 나눠 보세요.",
    "electionRoom": "이곳은 선거 제도의 중심이에요. 바로 여기서 투표하거든요.<br><br>선거에 누가 출마했는지도 확인할 수 있죠.<br><br>방마다 용도가 달라요.<br><br>이제 도시로 나가 볼까요? 먼저 시청을 나가야 해요."
  },
  "ar": {
    "clinic": "هذا هو المستوصف. يمكنك تلقي العلاج مجانًا أو بتكلفة بسيطة. وإذا كنت ثريًا، فبإمكانك الذهاب إلى مستشفى خاص للحصول على رعاية أفضل.<br><br>ويعيش كبار السن هنا أيضًا في دار المسنين. إنهم ذاكرة المدينة، كما تعلم.<br><br>لا تتردد في التحدث إليهم.",
    "electionRoom": "نحن هنا في قلب النظام الانتخابي؛ ففي هذا المكان يجري التصويت.<br><br>ويمكنك أيضًا معرفة المرشحين للانتخابات، على سبيل المثال.<br><br>لكل غرفة وظيفة محددة.<br><br>والآن سنخرج إلى المدينة. أولًا علينا مغادرة مبنى البلدية."
  },
  "pt-BR": {
    "clinic": "Aqui é o posto de saúde. Você pode receber atendimento gratuito ou pagando pouco. Se for rico, claro, pode procurar um hospital particular para um atendimento melhor.<br><br>Nossos idosos também estão aqui, no lar de repouso. Eles são um pouco a memória da cidade, sabe?<br><br>Não deixe de conversar com eles.",
    "electionRoom": "Aqui estamos no coração do sistema eleitoral: é onde as pessoas votam.<br><br>Também dá para consultar quem está concorrendo às eleições, por exemplo.<br><br>Cada sala tem uma função diferente.<br><br>Agora vamos conhecer a cidade. Primeiro, vamos sair da Prefeitura."
  },
  "de": {
    "clinic": "Das hier ist die Krankenstation. Hier kann man sich kostenlos oder für wenig Geld behandeln lassen. Wer reich ist, kann natürlich für eine bessere Versorgung in ein Privatkrankenhaus gehen.<br><br>Auch unsere älteren Mitbürger wohnen hier im Pflegeheim. Sie sind gewissermaßen das Gedächtnis der Stadt.<br><br>Sprechen Sie ruhig mit ihnen.",
    "electionRoom": "Hier sind wir im Herzen des Wahlsystems, denn hier wird gewählt.<br><br>Man kann zum Beispiel auch sehen, wer bei den Wahlen kandidiert.<br><br>Jeder Raum hat seine eigene Aufgabe.<br><br>Jetzt gehen wir in die Stadt. Zuerst verlassen wir das Rathaus."
  }
};
 for(const [lang,strings] of Object.entries(cityTour)) Object.assign(labels[lang],strings);
 for(const [lang,strings] of Object.entries(labels))
  if(resources[lang]?.translation)resources[lang].translation.jeremyScenes={...strings};
 function label(key,original){
  if(typeof original!=='string'||labels.fr[key]!==original)return original;
  const lang=global.RPPlateauI18n?.language?.()||'fr';
  const value=global.i18next?.t?.('jeremyScenes.'+key,{lng:lang,defaultValue:original});
  if(typeof value!=='string'||!value.trim())return original;
  if(/<(?!br\s*\/?\s*>)/i.test(value))return original;
  return value;
 }
 global.RPJeremyScenesI18n=Object.freeze({label});
})(window);
