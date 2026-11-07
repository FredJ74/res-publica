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
 const stadium={
  "fr": "Ça c'est le stade de notre équipe de Luthécia ! On y est tous très attaché.<br><br>Il y a 12 clubs qui s'affrontent pour savoir qui sera le meilleur. Pour connaître le classement, il suffit de le consulter.<br><br>Si vous voulez intégrer l'équipe, il faut prendre sa licence dans le vestiaire et vous entraîner jusqu'à faire partie des 15 meilleurs joueurs du club. Demandez conseil à l'entraîneur adjoint, il est là pour ça.<br><br>On peut boire un coup, acheter des accessoires du club, parier sur les matchs, ou encore rejoindre le club des supporters.<br><br>Attention, il ne faut pas croire mais c'est bien plus qu'un endroit où l'on fait du sport. Vous verrez à l'usage, mais ici des maires ont perdu leur poste ou à l'inverse ont été réélus selon l'humeur des supporters...<br><br>Allez-y, jetez un œil, essayez quelque chose !",
  "en": "This is the stadium of Luthécia's team! We're all very attached to it.<br><br>Twelve clubs compete to find out which is best. You can check the league table to see the standings.<br><br>If you want to join the team, get your licence in the changing room and train until you're among the club's 15 best players. Ask the assistant coach for advice — that's what he's here for.<br><br>You can have a drink, buy club merchandise, bet on matches or join the supporters' club.<br><br>Don't be fooled: this is much more than a place for sport. You'll see for yourself — some mayors have lost their offices here, while others have been re-elected, depending on the supporters' mood...<br><br>Go on, have a look around and try something!",
  "es": "¡Este es el estadio del equipo de Luthécia! Todos le tenemos mucho cariño.<br><br>Doce clubes compiten para ver cuál es el mejor. Puede consultar la clasificación para conocer las posiciones.<br><br>Si quiere entrar en el equipo, consiga su licencia en el vestuario y entrene hasta estar entre los 15 mejores jugadores del club. Pida consejo al segundo entrenador: para eso está aquí.<br><br>Puede tomar algo, comprar artículos del club, apostar en los partidos o unirse al grupo de aficionados.<br><br>Pero no se engañe: esto es mucho más que un lugar para practicar deporte. Ya verá que aquí algunos alcaldes han perdido su cargo y otros han sido reelegidos, según el humor de los aficionados...<br><br>¡Vamos, eche un vistazo y pruebe algo!",
  "zh-TW": "這就是盧特西亞球隊的體育場！大家都對它很有感情。<br><br>十二家俱樂部在這裡競爭，看看誰最出色。你可以查看聯賽排名。<br><br>想加入球隊的話，得先到更衣室辦理球員資格，再不斷訓練，直到躋身俱樂部前十五名球員。可以請教助理教練，他就是來幫忙的。<br><br>你可以喝點東西、購買俱樂部周邊商品、投注比賽，或加入球迷俱樂部。<br><br>別以為這裡只是運動場所。以後你就知道了：有些市長因為球迷的情緒失去職位，另一些卻因此成功連任……<br><br>來吧，四處看看，試著做點什麼！",
  "ru": "Это стадион команды Лютеции! Мы все очень к нему привязаны.<br><br>Двенадцать клубов борются за первое место. Их положение можно узнать из турнирной таблицы.<br><br>Хотите попасть в команду — оформите лицензию в раздевалке и тренируйтесь, пока не войдёте в пятнадцать лучших игроков клуба. Попросите совета у помощника тренера: он для этого и здесь.<br><br>Здесь можно выпить, купить клубные товары, сделать ставку на матч или вступить в клуб болельщиков.<br><br>Но не думайте, что это лишь спортивная площадка. Увидите сами: одни мэры здесь теряли должность, а других переизбирали — всё зависело от настроения болельщиков...<br><br>Ну же, осмотритесь и попробуйте что-нибудь!",
  "ko": "여기가 루테시아 팀의 경기장이에요! 모두가 무척 아끼는 곳이죠.<br><br>열두 개 구단이 최고 자리를 놓고 경쟁해요. 순위를 알고 싶다면 리그 표를 확인하면 됩니다.<br><br>팀에 들어가려면 탈의실에서 선수 등록을 하고, 훈련해서 구단의 상위 15명 안에 들어야 해요. 보조 코치에게 조언을 구하세요. 그게 코치의 일이니까요.<br><br>음료를 마시거나 구단 상품을 사고, 경기에 돈을 걸거나 서포터스 클럽에 가입할 수도 있어요.<br><br>하지만 이곳을 단순히 운동하는 곳이라고 생각하면 안 돼요. 팬들의 분위기에 따라 시장이 자리를 잃기도 하고 재선되기도 했거든요…<br><br>자, 둘러보고 뭔가 해보세요!",
  "ar": "هذا ملعب فريق لوتيسيا! نحن جميعًا متعلقون به كثيرًا.<br><br>يتنافس اثنا عشر ناديًا لمعرفة من الأفضل. ويمكنك الاطلاع على جدول الترتيب لمعرفة المراكز.<br><br>إذا أردت الانضمام إلى الفريق، فاستخرج رخصتك من غرفة الملابس وتدرّب حتى تصبح ضمن أفضل خمسة عشر لاعبًا في النادي. اطلب نصيحة المدرب المساعد، فهذا دوره.<br><br>يمكنك تناول مشروب، وشراء مستلزمات النادي، والمراهنة على المباريات، أو الانضمام إلى نادي المشجعين.<br><br>لكن لا تظن أنه مجرد مكان للرياضة. ستكتشف أن بعض رؤساء البلديات فقدوا مناصبهم هنا، فيما أُعيد انتخاب آخرين، وفق مزاج المشجعين...<br><br>هيا، ألق نظرة وجرّب شيئًا!",
  "pt-BR": "Este é o estádio do time de Luthécia! Todos nós temos um carinho enorme por ele.<br><br>Doze clubes disputam para ver qual é o melhor. Você pode consultar a tabela para saber a classificação.<br><br>Se quiser entrar no time, tire sua licença no vestiário e treine até ficar entre os 15 melhores jogadores do clube. Peça orientação ao auxiliar técnico — é para isso que ele está aqui.<br><br>Você pode tomar uma bebida, comprar produtos do clube, apostar nos jogos ou entrar para a torcida organizada.<br><br>Mas não se engane: isso é muito mais do que um lugar para praticar esportes. Você vai ver que alguns prefeitos perderam o cargo por aqui, enquanto outros foram reeleitos, dependendo do humor da torcida...<br><br>Vá em frente, dê uma olhada e experimente alguma coisa!",
  "de": "Das ist das Stadion der Mannschaft von Luthécia! Wir hängen alle sehr daran.<br><br>Zwölf Vereine treten gegeneinander an, um den besten zu ermitteln. Die Tabelle zeigt Ihnen die Platzierungen.<br><br>Wenn Sie ins Team möchten, holen Sie sich in der Umkleide eine Spielerlizenz und trainieren Sie, bis Sie zu den 15 besten Spielern des Vereins gehören. Der Co-Trainer hilft Ihnen gern dabei.<br><br>Sie können etwas trinken, Vereinsartikel kaufen, auf Spiele wetten oder dem Fanclub beitreten.<br><br>Aber glauben Sie nicht, dass hier nur Sport stattfindet. Sie werden sehen: Manche Bürgermeister haben ihr Amt verloren, andere wurden wiedergewählt — je nach Stimmung der Fans...<br><br>Also los, sehen Sie sich um und probieren Sie etwas aus!"
};
 for(const [lang,scene] of Object.entries(stadium)) labels[lang].stadium=scene;
 const guidance={
  "fr": {
    "turnLeft": "Allons sur la gauche, j'ai quelque chose à vous montrer.",
    "keepDirection": "Continuez dans cette direction.",
    "selectBuilding": "Cliquez sur le bon batiment.",
    "routeStadium": "On va aller dans un super endroit : le stade de foot !<br><br>Pour ça il faut sortir puis aller sur la gauche, et ensuite, prendre la route perpendiculaire, puis tourner à droite.<br><br>Au pire, si vous êtes perdu, vous pouvez consulter le plan, en haut à droite.",
    "exploreStadium": "Je vous laisse découvrir le stade. Si vous avez des questions pendant la visite, n'hésitez pas à me les poser.",
    "bedroomSleepOrder": "Parfait ! Maintenant, dès que vous passerez l'ordre Dormir dans cette chambre réservée, vous vous requinquerez bien mieux. Bon, en attendant, allons faire un tour au bar, juste à côté."
  },
  "en": {
    "turnLeft": "Let's go left. I've got something to show you.",
    "keepDirection": "Keep going in this direction.",
    "selectBuilding": "Click on the correct building.",
    "routeStadium": "We're going somewhere great: the football stadium!<br><br>To get there, go outside and turn left. Take the road crossing your path, then turn right.<br><br>If you get lost, you can check the map in the top-right corner.",
    "exploreStadium": "I'll let you explore the stadium. If you have questions during the visit, just ask me.",
    "bedroomSleepOrder": "Perfect! When you use the order Sleep in this reserved room, you'll recover much better. But for now, let's visit the bar just next door."
  },
  "es": {
    "turnLeft": "Vamos a la izquierda, quiero enseñarle algo.",
    "keepDirection": "Continúe en esta dirección.",
    "selectBuilding": "Haga clic en el edificio correcto.",
    "routeStadium": "¡Vamos a un sitio estupendo: el estadio de fútbol!<br><br>Para llegar, salga y vaya a la izquierda. Después tome la calle perpendicular y gire a la derecha.<br><br>Si se pierde, puede consultar el mapa arriba a la derecha.",
    "exploreStadium": "Le dejaré explorar el estadio. Si tiene alguna pregunta durante la visita, no dude en hacérmela.",
    "bedroomSleepOrder": "¡Perfecto! Cuando utilice la orden Dormir en esta habitación reservada, recuperará mucha más energía. Pero antes vamos al bar de al lado."
  },
  "zh-TW": {
    "turnLeft": "往左走吧，我有東西要給你看。",
    "keepDirection": "沿著這個方向繼續走。",
    "selectBuilding": "點選正確的建築。",
    "routeStadium": "我們要去一個很棒的地方：足球場！<br><br>先離開建築並向左走，再走上交叉的道路，接著右轉。<br><br>如果迷路了，可以查看右上角的地圖。",
    "exploreStadium": "你先自己逛逛體育場。有問題隨時問我。",
    "bedroomSleepOrder": "太好了！只要使用「在這間已預訂的房間睡覺」指令，就能恢復更多體力。不過現在先去隔壁的酒吧看看吧。"
  },
  "ru": {
    "turnLeft": "Пойдёмте налево, я хочу вам кое-что показать.",
    "keepDirection": "Продолжайте идти в этом направлении.",
    "selectBuilding": "Нажмите на нужное здание.",
    "routeStadium": "Мы идём в замечательное место — на футбольный стадион!<br><br>Выйдите из здания и поверните налево, затем сверните на поперечную улицу и направо.<br><br>Если заблудитесь, посмотрите на карту в правом верхнем углу.",
    "exploreStadium": "Осмотритесь на стадионе. Если во время прогулки появятся вопросы, смело спрашивайте.",
    "bedroomSleepOrder": "Отлично! Когда вы выполните действие «Спать в забронированной комнате», сил восстановится гораздо больше. А пока заглянем в бар по соседству."
  },
  "ko": {
    "turnLeft": "왼쪽으로 가요. 보여 드릴 게 있어요.",
    "keepDirection": "이 방향으로 계속 가세요.",
    "selectBuilding": "올바른 건물을 선택하세요.",
    "routeStadium": "멋진 곳으로 가볼게요. 바로 축구 경기장이에요!<br><br>밖으로 나가 왼쪽으로 간 뒤, 가로지르는 길로 들어서서 오른쪽으로 도세요.<br><br>길을 잃으면 오른쪽 위에 있는 지도를 확인하세요.",
    "exploreStadium": "경기장을 자유롭게 둘러보세요. 구경 중 궁금한 게 있으면 언제든 물어보세요.",
    "bedroomSleepOrder": "좋아요! 예약한 방에서 잠자기 행동을 사용하면 회복 효과가 훨씬 좋아져요. 하지만 지금은 바로 옆에 있는 술집에 가보죠."
  },
  "ar": {
    "turnLeft": "هيا نتجه يسارًا، لدي شيء أريد أن أريك إياه.",
    "keepDirection": "واصل السير في هذا الاتجاه.",
    "selectBuilding": "انقر على المبنى الصحيح.",
    "routeStadium": "سنذهب إلى مكان رائع: ملعب كرة القدم!<br><br>اخرج أولًا ثم اتجه يسارًا، وبعد ذلك اسلك الطريق المتقاطع وانعطف يمينًا.<br><br>إذا ضللت الطريق، فيمكنك مراجعة الخريطة في الزاوية العلوية اليمنى.",
    "exploreStadium": "سأتركك تستكشف الملعب. إن كانت لديك أسئلة أثناء الزيارة، فلا تتردد في طرحها عليّ.",
    "bedroomSleepOrder": "ممتاز! عندما تستخدم أمر النوم في هذه الغرفة المحجوزة، ستستعيد طاقة أكبر بكثير. أما الآن فلنذهب إلى الحانة المجاورة."
  },
  "pt-BR": {
    "turnLeft": "Vamos para a esquerda, tenho algo para mostrar.",
    "keepDirection": "Continue nessa direção.",
    "selectBuilding": "Clique no prédio certo.",
    "routeStadium": "Vamos a um lugar incrível: o estádio de futebol!<br><br>Para chegar lá, saia e vire à esquerda. Depois pegue a rua transversal e vire à direita.<br><br>Se ficar perdido, consulte o mapa no canto superior direito.",
    "exploreStadium": "Vou deixar você explorar o estádio. Se tiver alguma pergunta durante a visita, é só me chamar.",
    "bedroomSleepOrder": "Perfeito! Quando você usar a ordem Dormir neste quarto reservado, vai recuperar muito mais energia. Mas antes vamos dar uma olhada no bar ao lado."
  },
  "de": {
    "turnLeft": "Gehen wir nach links. Ich möchte Ihnen etwas zeigen.",
    "keepDirection": "Gehen Sie weiter in diese Richtung.",
    "selectBuilding": "Klicken Sie auf das richtige Gebäude.",
    "routeStadium": "Wir gehen an einen tollen Ort: ins Fußballstadion!<br><br>Gehen Sie nach draußen und nach links, nehmen Sie dann die Querstraße und biegen Sie rechts ab.<br><br>Falls Sie sich verlaufen, finden Sie oben rechts die Karte.",
    "exploreStadium": "Ich lasse Sie das Stadion erkunden. Wenn Sie während des Besuchs Fragen haben, fragen Sie mich einfach.",
    "bedroomSleepOrder": "Perfekt! Sobald Sie den Befehl In diesem reservierten Zimmer schlafen ausführen, erholen Sie sich viel besser. Aber zuerst sehen wir uns die Bar nebenan an."
  }
};
 for(const [lang,texts] of Object.entries(guidance)) Object.assign(labels[lang],texts);
 const social={
  "fr": {
    "partWays": "Je vais vous laisser découvrir la ville seul(e). Nos chemins se séparent ici. Pour le moment, bien sûr !<br><br>Si vous avez besoin de moi, cliquez sur ma fiche pour m'ajouter à vos contacts, et utilisez ensuite le bouton Messages/Forums pour m'envoyer un mail.",
    "careerChoice": "Bon, une dernière chose... Vous commencez à connaître Luthécia. Mais visiter une ville, c'est une chose. S'y faire une place, c'en est une autre. Vous avez une idée de ce que vous aimeriez devenir ?",
    "contactsTip": "Au fait, tant que j'y pense : dès que vous croisez quelqu'un d'intéressant, cliquez sur sa fiche et ajoutez-le à votre répertoire — ça vous servira pour porter plainte, lancer une rumeur ciblée, ou lui envoyer un mail plus tard.",
    "contactJeremy": "Et si jamais vous avez encore besoin de moi après ça : ajoutez-moi au répertoire tant qu'on est encore ensemble, et envoyez-moi un mail via Messages/Forums quand vous voulez. Je vous répondrai où que je sois.",
    "localForumInvite": "Vous commencez à connaître Luthécia... mais Luthécia ne vous connaît pas encore.<br><br>Le forum local est le lieu où les citoyens débattent, annoncent leurs projets et commencent parfois leurs premières querelles.<br><br>Souhaitez-vous vous présenter aux autres habitants ?"
  },
  "en": {
    "partWays": "I'll let you explore the city on your own now. This is where we part ways — for the moment, of course!<br><br>If you need me, click on my profile to add me to your contacts, then use Messages/Forums to send me a letter.",
    "careerChoice": "One last thing... You're starting to get to know Luthécia. But visiting a city and finding your place in it are two different things. Have you thought about what you'd like to become?",
    "contactsTip": "Oh, and while I remember: whenever you meet someone interesting, click on their profile and add them to your contacts. You'll need that later to file a complaint, start a targeted rumour or send them a message.",
    "contactJeremy": "And if you need me again after this, add me to your contacts while we're still together and write to me through Messages/Forums whenever you like. I'll answer wherever I am.",
    "localForumInvite": "You're starting to know Luthécia... but Luthécia doesn't know you yet.<br><br>The local forum is where citizens debate, announce their plans and sometimes start their first arguments.<br><br>Would you like to introduce yourself to the other residents?"
  },
  "es": {
    "partWays": "Ahora le dejaré descubrir la ciudad por su cuenta. Nuestros caminos se separan aquí... ¡por el momento, claro!<br><br>Si me necesita, haga clic en mi ficha para añadirme a sus contactos y después utilice Mensajes/Foros para enviarme un correo.",
    "careerChoice": "Una última cosa... Está empezando a conocer Luthécia. Pero visitar una ciudad no es lo mismo que hacerse un sitio en ella. ¿Tiene alguna idea de lo que le gustaría llegar a ser?",
    "contactsTip": "Ah, casi se me olvida: cada vez que conozca a alguien interesante, haga clic en su ficha y añádalo a sus contactos. Más adelante le servirá para presentar una denuncia, lanzar un rumor dirigido o enviarle un correo.",
    "contactJeremy": "Y si después vuelve a necesitarme, añádame a sus contactos mientras seguimos juntos y escríbame mediante Mensajes/Foros cuando quiera. Le responderé esté donde esté.",
    "localForumInvite": "Está empezando a conocer Luthécia... pero Luthécia todavía no le conoce.<br><br>El foro local es donde los ciudadanos debaten, anuncian sus proyectos y a veces inician sus primeras disputas.<br><br>¿Quiere presentarse a los demás habitantes?"
  },
  "zh-TW": {
    "partWays": "現在讓你自己去探索這座城市吧。我們就先在這裡分開，當然，只是暫時的！<br><br>如果需要我，點選我的個人資料將我加入聯絡人，再使用「訊息／論壇」寄信給我。",
    "careerChoice": "還有最後一件事……你已經開始認識盧特西亞了。不過，參觀一座城市和在城裡找到自己的位置是兩回事。你想過將來想成為什麼樣的人嗎？",
    "contactsTip": "對了，差點忘了說：遇到有趣的人時，點選他的個人資料，把他加入聯絡人。之後要提起申訴、散播針對性的謠言，或寫信給他，都會用得上。",
    "contactJeremy": "以後如果還需要我的幫忙，趁我們還在一起時把我加入聯絡人，隨時透過「訊息／論壇」寄信給我。不論我身在何處都會回覆。",
    "localForumInvite": "你開始認識盧特西亞了……但盧特西亞還不認識你。<br><br>在地方論壇裡，市民討論政治、宣布計畫，有時也會展開第一場爭執。<br><br>你願意向其他居民介紹自己嗎？"
  },
  "ru": {
    "partWays": "Теперь оставлю вас исследовать город самостоятельно. Здесь наши пути расходятся — пока что, конечно!<br><br>Если понадоблюсь, нажмите на мою карточку, добавьте меня в контакты и отправьте письмо через «Сообщения/Форумы».",
    "careerChoice": "И ещё кое-что... Вы уже начинаете узнавать Лютецию. Но одно дело — осмотреть город, и совсем другое — найти в нём своё место. Вы думали, кем хотели бы стать?",
    "contactsTip": "Кстати, пока не забыл: встретив интересного человека, откройте его карточку и добавьте в контакты. Это пригодится, чтобы подать жалобу, пустить адресный слух или позже написать ему письмо.",
    "contactJeremy": "И если понадоблюсь потом, добавьте меня в контакты, пока мы рядом, и пишите через «Сообщения/Форумы» когда угодно. Я отвечу, где бы ни находился.",
    "localForumInvite": "Вы начинаете знакомиться с Лютецией... но Лютеция пока не знакома с вами.<br><br>На местном форуме жители спорят, объявляют о планах, а порой устраивают свои первые ссоры.<br><br>Хотите представиться остальным горожанам?"
  },
  "ko": {
    "partWays": "이제 혼자 도시를 둘러보세요. 여기서 잠시 헤어질게요. 물론 당분간만요!<br><br>제가 필요하면 제 프로필을 눌러 연락처에 추가하고, 메시지/포럼 메뉴로 편지를 보내 주세요.",
    "careerChoice": "마지막으로 한 가지만 더요… 이제 루테시아를 조금 알게 되셨죠. 하지만 도시를 구경하는 것과 그 안에서 자기 자리를 찾는 것은 다르답니다. 어떤 사람이 되고 싶은지 생각해 보셨나요?",
    "contactsTip": "참, 잊기 전에 말씀드릴게요. 흥미로운 사람을 만나면 프로필을 눌러 연락처에 추가하세요. 나중에 고소를 하거나 특정인을 겨냥한 소문을 퍼뜨리거나 편지를 보낼 때 필요해요.",
    "contactJeremy": "나중에라도 제가 필요하면 아직 같이 있을 때 연락처에 추가해 두세요. 언제든 메시지/포럼에서 편지를 보내 주시면 어디에 있든 답장할게요.",
    "localForumInvite": "이제 루테시아를 조금 알게 되셨지만… 루테시아는 아직 당신을 모르죠.<br><br>지역 포럼에서는 시민들이 토론하고 계획을 알리고 때로는 첫 다툼을 시작하기도 해요.<br><br>다른 주민들에게 자기소개를 해보시겠어요?"
  },
  "ar": {
    "partWays": "سأتركك الآن تكتشف المدينة وحدك. هنا نفترق، مؤقتًا بالطبع!<br><br>إذا احتجت إليّ، انقر على ملفي لإضافتي إلى جهات اتصالك، ثم استخدم الرسائل/المنتديات لإرسال رسالة إليّ.",
    "careerChoice": "شيء أخير... لقد بدأت تتعرف إلى لوتيسيا. لكن زيارة المدينة شيء، وإيجاد مكان لك فيها شيء آخر. هل فكرت في الشخص الذي تريد أن تصبحه؟",
    "contactsTip": "بالمناسبة، قبل أن أنسى: عندما تقابل شخصًا مثيرًا للاهتمام، انقر على ملفه وأضفه إلى جهات اتصالك. ستحتاج ذلك لاحقًا لتقديم شكوى أو نشر شائعة تستهدفه أو مراسلته.",
    "contactJeremy": "وإذا احتجت إليّ مرة أخرى بعد ذلك، فأضفني إلى جهات اتصالك ونحن ما زلنا معًا، واكتب إليّ عبر الرسائل/المنتديات متى شئت. سأجيبك أينما كنت.",
    "localForumInvite": "بدأت تتعرف إلى لوتيسيا... لكن لوتيسيا لم تتعرف إليك بعد.<br><br>المنتدى المحلي هو المكان الذي يناقش فيه المواطنون القضايا ويعلنون مشاريعهم، وقد يبدأون فيه خلافاتهم الأولى أيضًا.<br><br>هل تريد أن تقدّم نفسك إلى بقية السكان؟"
  },
  "pt-BR": {
    "partWays": "Agora vou deixar você descobrir a cidade por conta própria. Nossos caminhos se separam aqui — por enquanto, é claro!<br><br>Se precisar de mim, clique na minha ficha para me adicionar aos contatos e depois use Mensagens/Fóruns para me mandar um e-mail.",
    "careerChoice": "Mais uma coisa... Você está começando a conhecer Luthécia. Mas visitar uma cidade é diferente de conquistar seu espaço nela. Já pensou no que gostaria de se tornar?",
    "contactsTip": "Ah, antes que eu esqueça: sempre que encontrar alguém interessante, clique na ficha dessa pessoa e adicione aos seus contatos. Isso vai servir depois para fazer uma denúncia, espalhar um boato direcionado ou enviar uma mensagem.",
    "contactJeremy": "E se precisar de mim depois disso, adicione-me aos contatos enquanto ainda estamos juntos e escreva pelo menu Mensagens/Fóruns sempre que quiser. Vou responder de onde estiver.",
    "localForumInvite": "Você está começando a conhecer Luthécia... mas Luthécia ainda não conhece você.<br><br>O fórum local é onde os cidadãos debatem, anunciam seus projetos e às vezes começam suas primeiras brigas.<br><br>Quer se apresentar aos outros moradores?"
  },
  "de": {
    "partWays": "Jetzt lasse ich Sie die Stadt allein erkunden. Hier trennen sich unsere Wege — vorerst natürlich!<br><br>Falls Sie mich brauchen, klicken Sie auf meine Karte, fügen Sie mich Ihren Kontakten hinzu und schreiben Sie mir über Nachrichten/Foren.",
    "careerChoice": "Noch eine Sache... Sie lernen Luthécia langsam kennen. Aber eine Stadt zu besichtigen und dort seinen Platz zu finden, sind zwei verschiedene Dinge. Haben Sie eine Idee, was Sie werden möchten?",
    "contactsTip": "Ach, bevor ich es vergesse: Wenn Sie jemand Interessanten treffen, klicken Sie auf dessen Karte und nehmen Sie die Person in Ihre Kontakte auf. Das hilft Ihnen später bei Beschwerden, gezielten Gerüchten oder Briefen.",
    "contactJeremy": "Und falls Sie mich danach noch brauchen: Nehmen Sie mich in Ihre Kontakte auf, solange wir noch zusammen sind, und schreiben Sie mir jederzeit über Nachrichten/Foren. Ich antworte, wo immer ich bin.",
    "localForumInvite": "Sie lernen Luthécia langsam kennen... aber Luthécia kennt Sie noch nicht.<br><br>Im lokalen Forum diskutieren die Bürger, kündigen ihre Vorhaben an und beginnen manchmal ihre ersten Streitigkeiten.<br><br>Möchten Sie sich den anderen Bewohnern vorstellen?"
  }
};
 for(const [lang,texts] of Object.entries(social)) Object.assign(labels[lang],texts);
 const reminders={
  "fr": {
    "returnEmployees": "Me revoilà ! Au fait, si un jour vous voulez vous séparer de moi (ou de n'importe quel autre employé), il suffit de cliquer sur la petite croix à côté de sa carte, dans le panneau \"Mes Employés\", à gauche.",
    "rememberElections": "On va dans la salle des élections, vous vous souvenez ?",
    "goElections": "On va dans la salle des élections.",
    "leaveTownHall": "On sort de l'Hôtel de Ville, vous vous souvenez ?",
    "openCharacterSheet": "Allez donc consulter votre fiche personnage, je vous montrerai la suite après.",
    "returnHotel": "On va à l'hôtel-restaurant, vous vous souvenez ? C'est le deuxième bâtiment après l'Hôtel de Ville, sur la droite en sortant.",
    "toBar": "Allons faire un tour au bar, juste à côté.",
    "askDrink": "Vous pouvez m'offrir un verre ? J'ai très soif à force de parler.",
    "returnStadium": "On va au stade de foot ! Sortez, allez à gauche, puis prenez la route perpendiculaire et tournez à droite. Le plan peut vous aider, en haut à droite.",
    "tryStadium": "Allez-y, jetez un œil, essayez quelque chose au stade !",
    "sayGoodbyeAgain": "Nos chemins se séparent ici, vous vous souvenez ? Si besoin, cliquez sur ma fiche pour m'ajouter à vos contacts, puis utilisez le bouton Messages/Forums."
  },
  "en": {
    "returnEmployees": "I'm back! By the way, if you ever want to dismiss me (or any other employee), just click the small cross next to that employee's card in My Employees on the left.",
    "rememberElections": "We're going to the elections room, remember?",
    "goElections": "Let's go to the elections room.",
    "leaveTownHall": "Let's leave Town Hall, remember?",
    "openCharacterSheet": "Go and look at your character sheet. I'll show you what comes next afterward.",
    "returnHotel": "We're going to the hotel-restaurant, remember? It's the second building after Town Hall, on the right as you leave.",
    "toBar": "Let's visit the bar right next door.",
    "askDrink": "Could you buy me a drink? All this talking has made me thirsty.",
    "returnStadium": "We're off to the football stadium! Go outside, turn left, take the road crossing your path, then turn right. The map in the top-right corner can help.",
    "tryStadium": "Go on, take a look and try something at the stadium!",
    "sayGoodbyeAgain": "This is where we part ways, remember? If you need me, click my profile to add me to your contacts, then use Messages/Forums."
  },
  "es": {
    "returnEmployees": "¡He vuelto! Por cierto, si algún día quiere despedirme (o despedir a cualquier empleado), haga clic en la pequeña cruz junto a su ficha, en el panel Mis empleados, a la izquierda.",
    "rememberElections": "Vamos a la sala de elecciones, ¿recuerda?",
    "goElections": "Vamos a la sala de elecciones.",
    "leaveTownHall": "Salimos del Ayuntamiento, ¿recuerda?",
    "openCharacterSheet": "Consulte su ficha de personaje. Después le enseñaré el siguiente paso.",
    "returnHotel": "Vamos al hotel-restaurante, ¿recuerda? Es el segundo edificio después del Ayuntamiento, a la derecha al salir.",
    "toBar": "Vamos al bar de al lado.",
    "askDrink": "¿Me invita a una bebida? Tengo mucha sed de tanto hablar.",
    "returnStadium": "¡Vamos al estadio de fútbol! Salga, gire a la izquierda, tome la calle perpendicular y luego gire a la derecha. El mapa de arriba a la derecha puede ayudarle.",
    "tryStadium": "¡Vaya, eche un vistazo y pruebe algo en el estadio!",
    "sayGoodbyeAgain": "Aquí nos separamos, ¿recuerda? Si me necesita, haga clic en mi ficha para añadirme a sus contactos y luego utilice Mensajes/Foros."
  },
  "zh-TW": {
    "returnEmployees": "我回來了！對了，如果有一天你想讓我（或任何其他員工）離開，只要在左側「我的員工」面板中，點選該員工卡片旁的小叉號即可。",
    "rememberElections": "我們要去選舉室，還記得嗎？",
    "goElections": "我們去選舉室吧。",
    "leaveTownHall": "先離開市政廳，還記得嗎？",
    "openCharacterSheet": "先查看你的角色資料卡，接下來我會告訴你怎麼做。",
    "returnHotel": "我們要去旅館餐廳，還記得嗎？從市政廳出去往右走，它是第二棟建築。",
    "toBar": "去隔壁的酒吧看看吧。",
    "askDrink": "可以請我喝一杯嗎？講了這麼多話，口都渴了。",
    "returnStadium": "我們要去足球場！先出去，往左走，再轉進交叉的道路，然後右轉。右上角的地圖可以幫你。",
    "tryStadium": "去吧，逛逛體育場，試著做點什麼！",
    "sayGoodbyeAgain": "我們要在這裡分開了，還記得嗎？需要我的話，點選我的資料卡把我加入聯絡人，再使用「訊息／論壇」。"
  },
  "ru": {
    "returnEmployees": "Я вернулся! Кстати, если захотите расстаться со мной (или с любым другим работником), нажмите на маленький крестик возле его карточки в панели «Мои сотрудники» слева.",
    "rememberElections": "Пойдёмте в избирательный зал, помните?",
    "goElections": "Пойдёмте в избирательный зал.",
    "leaveTownHall": "Выйдем из мэрии, помните?",
    "openCharacterSheet": "Откройте карточку персонажа. Потом я покажу, что делать дальше.",
    "returnHotel": "Мы идём в гостиницу-ресторан, помните? Это второе здание после мэрии, справа от выхода.",
    "toBar": "Заглянем в бар по соседству.",
    "askDrink": "Не угостите меня напитком? От разговоров ужасно хочется пить.",
    "returnStadium": "Пойдёмте на футбольный стадион! Выйдите, поверните налево, затем на поперечную улицу и направо. Поможет карта в правом верхнем углу.",
    "tryStadium": "Ну же, осмотритесь на стадионе и попробуйте что-нибудь!",
    "sayGoodbyeAgain": "Здесь наши пути расходятся, помните? Если понадоблюсь, нажмите на мою карточку, добавьте меня в контакты и используйте «Сообщения/Форумы»."
  },
  "ko": {
    "returnEmployees": "다시 왔어요! 참, 언젠가 저나 다른 직원을 내보내고 싶다면 왼쪽 '내 직원' 패널에서 그 직원 카드 옆의 작은 X를 누르면 돼요.",
    "rememberElections": "선거실로 가기로 했죠, 기억나세요?",
    "goElections": "선거실로 가요.",
    "leaveTownHall": "시청을 나가기로 했죠, 기억나세요?",
    "openCharacterSheet": "캐릭터 정보를 확인하세요. 그다음 단계를 알려 드릴게요.",
    "returnHotel": "호텔 겸 식당으로 가기로 했죠? 시청에서 나가 오른쪽 두 번째 건물이에요.",
    "toBar": "바로 옆에 있는 술집에 가봐요.",
    "askDrink": "마실 것 하나 사주실래요? 계속 얘기했더니 목이 너무 말라요.",
    "returnStadium": "축구 경기장으로 가요! 밖으로 나가 왼쪽으로 간 다음, 가로지르는 길로 들어서서 오른쪽으로 도세요. 오른쪽 위 지도가 도움이 될 거예요.",
    "tryStadium": "자, 경기장을 둘러보고 뭔가 해보세요!",
    "sayGoodbyeAgain": "여기서 헤어지기로 했죠? 제가 필요하면 제 프로필을 눌러 연락처에 추가한 뒤 메시지/포럼을 이용하세요."
  },
  "ar": {
    "returnEmployees": "ها أنا عدت! بالمناسبة، إذا أردت يومًا الاستغناء عني (أو عن أي موظف آخر)، فما عليك إلا النقر على علامة × الصغيرة بجوار بطاقته في لوحة «موظفوي» إلى اليسار.",
    "rememberElections": "سنذهب إلى قاعة الانتخابات، أتذكر؟",
    "goElections": "هيا إلى قاعة الانتخابات.",
    "leaveTownHall": "لنخرج من مبنى البلدية، أتذكر؟",
    "openCharacterSheet": "اذهب واطلع على بطاقة شخصيتك، وسأريك الخطوة التالية بعد ذلك.",
    "returnHotel": "سنذهب إلى الفندق والمطعم، أتذكر؟ إنه المبنى الثاني بعد البلدية، على اليمين عند الخروج.",
    "toBar": "لنذهب إلى الحانة المجاورة.",
    "askDrink": "هل تشتري لي مشروبًا؟ لقد عطشت من كثرة الكلام.",
    "returnStadium": "سنذهب إلى ملعب كرة القدم! اخرج واتجه يسارًا، ثم اسلك الطريق المتقاطع وانعطف يمينًا. يمكن للخريطة أعلى اليمين مساعدتك.",
    "tryStadium": "هيا، ألق نظرة وجرّب شيئًا في الملعب!",
    "sayGoodbyeAgain": "هنا نفترق، أتذكر؟ إذا احتجت إليّ، انقر على ملفي لإضافتي إلى جهات اتصالك ثم استخدم الرسائل/المنتديات."
  },
  "pt-BR": {
    "returnEmployees": "Voltei! Aliás, se um dia quiser me dispensar (ou dispensar qualquer outro funcionário), basta clicar no pequeno X ao lado da ficha dele, no painel Meus funcionários à esquerda.",
    "rememberElections": "Vamos à sala das eleições, lembra?",
    "goElections": "Vamos à sala das eleições.",
    "leaveTownHall": "Vamos sair da Prefeitura, lembra?",
    "openCharacterSheet": "Vá consultar a ficha do seu personagem. Depois mostro o que vem a seguir.",
    "returnHotel": "Vamos ao hotel-restaurante, lembra? É o segundo prédio depois da Prefeitura, à direita quando você sai.",
    "toBar": "Vamos ao bar bem ao lado.",
    "askDrink": "Você pode me pagar uma bebida? Estou morrendo de sede de tanto falar.",
    "returnStadium": "Vamos ao estádio de futebol! Saia, vire à esquerda, pegue a rua transversal e vire à direita. O mapa no canto superior direito pode ajudar.",
    "tryStadium": "Vá, dê uma olhada e experimente alguma coisa no estádio!",
    "sayGoodbyeAgain": "Aqui nossos caminhos se separam, lembra? Se precisar de mim, clique na minha ficha, adicione-me aos contatos e use Mensagens/Fóruns."
  },
  "de": {
    "returnEmployees": "Da bin ich wieder! Falls Sie mich (oder einen anderen Mitarbeiter) eines Tages entlassen möchten, klicken Sie links im Bereich „Meine Mitarbeiter“ auf das kleine Kreuz neben der entsprechenden Karte.",
    "rememberElections": "Wir gehen in den Wahlraum, erinnern Sie sich?",
    "goElections": "Gehen wir in den Wahlraum.",
    "leaveTownHall": "Wir verlassen das Rathaus, erinnern Sie sich?",
    "openCharacterSheet": "Sehen Sie sich Ihren Charakterbogen an. Danach zeige ich Ihnen den nächsten Schritt.",
    "returnHotel": "Wir gehen ins Hotel-Restaurant, erinnern Sie sich? Es ist das zweite Gebäude nach dem Rathaus, rechts vom Ausgang.",
    "toBar": "Sehen wir uns die Bar nebenan an.",
    "askDrink": "Könnten Sie mir ein Getränk ausgeben? Vom vielen Reden habe ich großen Durst.",
    "returnStadium": "Auf zum Fußballstadion! Gehen Sie hinaus, nach links, dann in die Querstraße und rechts herum. Die Karte oben rechts hilft Ihnen.",
    "tryStadium": "Sehen Sie sich auf dem Stadion um und probieren Sie etwas aus!",
    "sayGoodbyeAgain": "Hier trennen sich unsere Wege, erinnern Sie sich? Falls Sie mich brauchen, klicken Sie auf meine Karte, nehmen Sie mich in Ihre Kontakte auf und nutzen Sie Nachrichten/Foren."
  }
};
 for(const [lang,texts] of Object.entries(reminders)) Object.assign(labels[lang],texts);
 const career={
  "fr": {
    "criminalChoice": "Plutôt du côté criminel",
    "politicalChoice": "Plutôt la politique",
    "entrepreneurialChoice": "Plutôt entreprendre",
    "undecidedChoice": "Je ne sais pas encore",
    "orientationRef": "Alors allez donc voir {{name}}. Vous le trouverez à {{place}}. Dites-lui que c'est moi qui vous envoie.",
    "orientationUndecided": "Je comprends, ce n'est pas facile de se déterminer. Continuez à arpenter la ville et rencontrer les habitants, ça vous aidera à vous faire une idée.",
    "criminalWarning": "Mais sachez que tout acte a des conséquences sur l'ensemble de la société, pas seulement pour vous.",
    "conclusionRef": "{{name}} saura vous aider, mais sachez que tout acte a des conséquences sur l'ensemble de la société, pas seulement pour vous.",
    "conclusionUnknown": "Sachez en tout cas que tout acte a des conséquences sur l'ensemble de la société, pas seulement pour vous.",
    "enterHere": "Entrons ici !"
  },
  "en": {
    "criminalChoice": "The criminal side",
    "politicalChoice": "Politics",
    "entrepreneurialChoice": "Starting a business",
    "undecidedChoice": "I don't know yet",
    "orientationRef": "Then go and see {{name}}. You'll find them at {{place}}. Tell them I sent you.",
    "orientationUndecided": "I understand. Choosing isn't easy. Keep exploring the city and meeting its residents; it'll help you find your path.",
    "criminalWarning": "But remember that every action has consequences for society as a whole, not just for you.",
    "conclusionRef": "{{name}} will be able to help you, but remember that every action has consequences for society as a whole, not just for you.",
    "conclusionUnknown": "In any case, remember that every action has consequences for society as a whole, not just for you.",
    "enterHere": "Let's go in!"
  },
  "es": {
    "criminalChoice": "El mundo criminal",
    "politicalChoice": "La política",
    "entrepreneurialChoice": "Crear una empresa",
    "undecidedChoice": "Aún no lo sé",
    "orientationRef": "Entonces vaya a ver a {{name}}. Lo encontrará en {{place}}. Dígale que le envío yo.",
    "orientationUndecided": "Lo entiendo, no es fácil decidirse. Siga recorriendo la ciudad y conociendo a sus habitantes; eso le ayudará a aclararse.",
    "criminalWarning": "Pero recuerde que cualquier acto tiene consecuencias para toda la sociedad, no solo para usted.",
    "conclusionRef": "{{name}} podrá ayudarle, pero recuerde que cualquier acto tiene consecuencias para toda la sociedad, no solo para usted.",
    "conclusionUnknown": "En cualquier caso, recuerde que cualquier acto tiene consecuencias para toda la sociedad, no solo para usted.",
    "enterHere": "¡Entremos aquí!"
  },
  "zh-TW": {
    "criminalChoice": "走上犯罪道路",
    "politicalChoice": "投身政治",
    "entrepreneurialChoice": "創業",
    "undecidedChoice": "我還沒想好",
    "orientationRef": "那就去找 {{name}} 吧。你可以在 {{place}} 找到他。記得告訴他是我介紹你來的。",
    "orientationUndecided": "我明白，這不容易決定。繼續逛逛城市、多認識居民，慢慢就會知道自己想走哪條路。",
    "criminalWarning": "但請記住，每個行動都會對整個社會產生影響，不只是影響你自己。",
    "conclusionRef": "{{name}} 應該能幫上忙。不過要記住，每個行動都會對整個社會產生影響，不只是影響你自己。",
    "conclusionUnknown": "無論如何，請記住，每個行動都會對整個社會產生影響，不只是影響你自己。",
    "enterHere": "進去吧！"
  },
  "ru": {
    "criminalChoice": "Криминальный путь",
    "politicalChoice": "Политика",
    "entrepreneurialChoice": "Предпринимательство",
    "undecidedChoice": "Пока не знаю",
    "orientationRef": "Тогда сходите к {{name}}. Его можно найти в {{place}}. Скажите, что это я вас направил.",
    "orientationUndecided": "Понимаю, определиться непросто. Продолжайте гулять по городу и знакомиться с его жителями — так вам будет легче выбрать свой путь.",
    "criminalWarning": "Но помните: любой поступок имеет последствия для всего общества, а не только для вас.",
    "conclusionRef": "{{name}} сможет вам помочь. Но помните: любой поступок имеет последствия для всего общества, а не только для вас.",
    "conclusionUnknown": "В любом случае помните: любой поступок имеет последствия для всего общества, а не только для вас.",
    "enterHere": "Давайте зайдём!"
  },
  "ko": {
    "criminalChoice": "범죄자의 길",
    "politicalChoice": "정치",
    "entrepreneurialChoice": "사업 시작",
    "undecidedChoice": "아직 모르겠어요",
    "orientationRef": "그렇다면 {{name}}을(를) 찾아가세요. {{place}}에 있을 거예요. 제가 보냈다고 전해주세요.",
    "orientationUndecided": "이해해요. 결정하기 쉽지 않죠. 도시를 돌아다니며 주민들을 만나보세요. 그러다 보면 마음을 정하는 데 도움이 될 거예요.",
    "criminalWarning": "하지만 모든 행동은 자신뿐 아니라 사회 전체에 영향을 준다는 것을 기억하세요.",
    "conclusionRef": "{{name}}이(가) 도와줄 거예요. 하지만 모든 행동은 자신뿐 아니라 사회 전체에 영향을 준다는 것을 기억하세요.",
    "conclusionUnknown": "어쨌든 모든 행동은 자신뿐 아니라 사회 전체에 영향을 준다는 걸 기억하세요.",
    "enterHere": "들어가요!"
  },
  "ar": {
    "criminalChoice": "طريق الجريمة",
    "politicalChoice": "السياسة",
    "entrepreneurialChoice": "ريادة الأعمال",
    "undecidedChoice": "لم أقرر بعد",
    "orientationRef": "إذًا اذهب للقاء {{name}}. ستجده في {{place}}. أخبره أنني أرسلتك.",
    "orientationUndecided": "أتفهم ذلك، فالاختيار ليس سهلًا. واصل التجول في المدينة والتعرف إلى سكانها؛ سيساعدك ذلك على تحديد طريقك.",
    "criminalWarning": "لكن تذكر أن لكل فعل تبعات على المجتمع بأسره، وليس عليك وحدك.",
    "conclusionRef": "سيستطيع {{name}} مساعدتك، لكن تذكر أن لكل فعل تبعات على المجتمع بأسره، وليس عليك وحدك.",
    "conclusionUnknown": "تذكر على أي حال أن لكل فعل تبعات على المجتمع بأسره، وليس عليك وحدك.",
    "enterHere": "هيا ندخل!"
  },
  "pt-BR": {
    "criminalChoice": "O caminho do crime",
    "politicalChoice": "A política",
    "entrepreneurialChoice": "Empreender",
    "undecidedChoice": "Ainda não sei",
    "orientationRef": "Então vá falar com {{name}}. Você encontrará essa pessoa em {{place}}. Diga que fui eu quem mandou você.",
    "orientationUndecided": "Entendo, não é fácil decidir. Continue andando pela cidade e conhecendo seus moradores; isso ajudará você a encontrar seu caminho.",
    "criminalWarning": "Mas lembre-se de que toda ação tem consequências para a sociedade inteira, não apenas para você.",
    "conclusionRef": "{{name}} poderá ajudar você, mas lembre-se de que toda ação tem consequências para a sociedade inteira, não apenas para você.",
    "conclusionUnknown": "De qualquer forma, lembre-se de que toda ação tem consequências para a sociedade inteira, não apenas para você.",
    "enterHere": "Vamos entrar!"
  },
  "de": {
    "criminalChoice": "Der kriminelle Weg",
    "politicalChoice": "Die Politik",
    "entrepreneurialChoice": "Ein Unternehmen gründen",
    "undecidedChoice": "Ich weiß es noch nicht",
    "orientationRef": "Dann gehen Sie zu {{name}}. Sie finden diese Person in {{place}}. Sagen Sie, dass ich Sie geschickt habe.",
    "orientationUndecided": "Das verstehe ich. Die Entscheidung ist nicht leicht. Erkunden Sie weiter die Stadt und lernen Sie die Bewohner kennen. Das wird Ihnen bei Ihrer Wahl helfen.",
    "criminalWarning": "Denken Sie aber daran, dass jede Handlung Folgen für die gesamte Gesellschaft hat, nicht nur für Sie.",
    "conclusionRef": "{{name}} kann Ihnen helfen. Denken Sie aber daran, dass jede Handlung Folgen für die gesamte Gesellschaft hat, nicht nur für Sie.",
    "conclusionUnknown": "Denken Sie auf jeden Fall daran, dass jede Handlung Folgen für die gesamte Gesellschaft hat, nicht nur für Sie.",
    "enterHere": "Gehen wir hinein!"
  }
};
 for(const [lang,texts] of Object.entries(career)) Object.assign(labels[lang],texts);
 const socialControls={
  "fr": {
    "introduceMyself": "Me présenter",
    "later": "Plus tard",
    "forumTitlePrefix": "Présentation de ",
    "jeremyMailFallback": "Oh, vous avez besoin de moi ? Je suis sur la Place du Marché, venez me chercher !",
    "newMailTitle": "Nouveau mail",
    "jeremyReplied": "Jérémy vous a répondu !",
    "replyLanguageInstruction": "Réponds EXCLUSIVEMENT en français."
  },
  "en": {
    "introduceMyself": "Introduce myself",
    "later": "Later",
    "forumTitlePrefix": "Introduction by ",
    "jeremyMailFallback": "Oh, you need me? I'm at the Market Square. Come and find me!",
    "newMailTitle": "New mail",
    "jeremyReplied": "Jérémy has replied!",
    "replyLanguageInstruction": "Reply EXCLUSIVELY in English."
  },
  "es": {
    "introduceMyself": "Presentarme",
    "later": "Más tarde",
    "forumTitlePrefix": "Presentación de ",
    "jeremyMailFallback": "¡Ah, me necesita! Estoy en la Plaza del Mercado, ¡venga a buscarme!",
    "newMailTitle": "Correo nuevo",
    "jeremyReplied": "¡Jérémy le ha respondido!",
    "replyLanguageInstruction": "Responde EXCLUSIVAMENTE en español."
  },
  "zh-TW": {
    "introduceMyself": "自我介紹",
    "later": "稍後再說",
    "forumTitlePrefix": "自我介紹：",
    "jeremyMailFallback": "哦，你需要我嗎？我在市場廣場，來找我吧！",
    "newMailTitle": "新郵件",
    "jeremyReplied": "Jérémy 已回覆！",
    "replyLanguageInstruction": "請只使用繁體中文（臺灣）回覆。"
  },
  "ru": {
    "introduceMyself": "Представиться",
    "later": "Позже",
    "forumTitlePrefix": "Представление: ",
    "jeremyMailFallback": "О, я вам нужен? Я на Рыночной площади, приходите за мной!",
    "newMailTitle": "Новое письмо",
    "jeremyReplied": "Jérémy ответил вам!",
    "replyLanguageInstruction": "Отвечай ИСКЛЮЧИТЕЛЬНО на русском языке."
  },
  "ko": {
    "introduceMyself": "자기소개하기",
    "later": "나중에",
    "forumTitlePrefix": "자기소개: ",
    "jeremyMailFallback": "아, 저를 찾으세요? 저는 시장 광장에 있어요. 여기로 와 주세요!",
    "newMailTitle": "새 편지",
    "jeremyReplied": "Jérémy가 답장했어요!",
    "replyLanguageInstruction": "반드시 한국어로만 답변하세요."
  },
  "ar": {
    "introduceMyself": "التعريف بنفسي",
    "later": "لاحقًا",
    "forumTitlePrefix": "تقديم: ",
    "jeremyMailFallback": "آه، هل تحتاج إليّ؟ أنا في ساحة السوق، تعال وابحث عني!",
    "newMailTitle": "رسالة جديدة",
    "jeremyReplied": "ردّ Jérémy على رسالتك!",
    "replyLanguageInstruction": "أجب باللغة العربية فقط."
  },
  "pt-BR": {
    "introduceMyself": "Me apresentar",
    "later": "Mais tarde",
    "forumTitlePrefix": "Apresentação de ",
    "jeremyMailFallback": "Ah, você precisa de mim? Estou na Praça do Mercado, venha me buscar!",
    "newMailTitle": "Novo e-mail",
    "jeremyReplied": "Jérémy respondeu!",
    "replyLanguageInstruction": "Responda EXCLUSIVAMENTE em português brasileiro."
  },
  "de": {
    "introduceMyself": "Mich vorstellen",
    "later": "Später",
    "forumTitlePrefix": "Vorstellung von ",
    "jeremyMailFallback": "Oh, brauchen Sie mich? Ich bin auf dem Marktplatz. Kommen Sie und holen Sie mich ab!",
    "newMailTitle": "Neue Nachricht",
    "jeremyReplied": "Jérémy hat geantwortet!",
    "replyLanguageInstruction": "Antworte AUSSCHLIESSLICH auf Deutsch."
  }
};
 for(const [lang,values] of Object.entries(socialControls)) Object.assign(labels[lang],values);
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
 // Recomposition des phrases d'orientation à partir des seuls référents
 // définis dans le jeu. Les noms et lieux ne sont jamais traduits par une IA.
 const models=new Set(['orientationRef','conclusionRef']);
 function format(key,variables,fallback) {
  if(!models.has(key)||typeof fallback!=='string')return fallback;
  const lng=global.RPPlateauI18n?.language?.()||'fr';
  let template=global.i18next?.t?.('jeremyScenes.'+key,{lng,defaultValue:labels.fr[key]});
  if(typeof template!=='string'||!template.trim()||/<|>/.test(template))return fallback;
  const name=String(variables?.name||'');
  const place=String(variables?.place||'');
  // Le HTML d'affichage des popups ne doit jamais interpréter les noms.
  const escape=s=>s.replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  template=template.replaceAll('{{name}}',escape(name)).replaceAll('{{place}}',escape(place));
  return template.includes('{{')||template.includes('}}')?fallback:template;
 }
 global.RPJeremyScenesI18n=Object.freeze({label,format});
})(window);
