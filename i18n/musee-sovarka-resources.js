/* Fiches des musées de Sovarka (12/11/2026) : musée municipal de Novomirsk (et les salles reprises par
 * Krasnov) et musée présidentiel. Affichage seulement : la fiche française (plateau-musee-personnalites.js)
 * reste la référence et le repli ; une fiche est traduite seulement si son nom français est EXACTEMENT au
 * catalogue. Noms propres inchangés ; seuls titres, surnoms, « et » et intitulés sont traduits (n).
 * Ordre des colonnes : en, es, zh-TW, ru, ko, ar, pt-BR, de.
 */
(function(global){
'use strict';
const LANGUES=['en','es','zh-TW','ru','ko','ar','pt-BR','de'];
const UI={
  "vide":["Nothing to look at here for now.","Nada que consultar aquí por ahora.","目前這裡沒有可查閱的內容。","Пока здесь нечего смотреть.","지금은 이곳에서 볼 것이 없습니다.","لا شيء للاطلاع عليه هنا حاليًا.","Nada para consultar aqui por enquanto.","Hier gibt es vorerst nichts anzusehen."],
  "retour":["Back to the list","Volver a la lista","返回列表","Назад к списку","목록으로 돌아가기","العودة إلى القائمة","Voltar à lista","Zurück zur Liste"],
  "titre":["Notable figures","Personalidades","名人","Личности","인물","شخصيات","Personalidades","Persönlichkeiten"]
};
const F={
// Salle des Personnalités discrètes (Novomirsk)
"Sophia Nouiseteskaïa":{b:[
 "Inventor of a loom that produced a sheer veil of worldwide renown. A seamstress, she made nightwear from it. Legend has it that a woman draped in this veil had a crazy power over men.",
 "Inventora de un telar que producía un velo transparente de fama mundial. Costurera, hacía con él ropa de noche. Cuenta la leyenda que una mujer envuelta en ese velo tenía un poder loco sobre los hombres.",
 "她發明了一種織布機，能織出享譽世界的透明薄紗。身為裁縫，她用這種薄紗縫製睡衣。傳說披上這層薄紗的女人，對男人有著不可思議的魔力。",
 "Изобретательница ткацкого станка, производившего прозрачную вуаль мировой славы. Швея, она шила из неё ночные наряды. Легенда гласит, что женщина, укутанная этой вуалью, имела безумную власть над мужчинами.",
 "세계적으로 유명한 투명한 베일을 짜는 베틀의 발명가. 재봉사였던 그녀는 그 베일로 잠옷을 지었다. 전설에 따르면 이 베일을 두른 여인은 남자들을 홀리는 엄청난 힘을 가졌다고 한다.",
 "مخترعة نول ينسج حجابًا شفافًا ذاع صيته في العالم. كانت خيّاطة، فصنعت منه ملابس للنوم. وتقول الأسطورة إن المرأة الملتفّة بهذا الحجاب كانت تملك سلطانًا عجيبًا على الرجال.",
 "Inventora de um tear que produzia um véu transparente de fama mundial. Costureira, fazia com ele roupas de dormir. Diz a lenda que uma mulher envolta nesse véu tinha um poder louco sobre os homens.",
 "Erfinderin eines Webstuhls, der einen weltberühmten durchsichtigen Schleier herstellte. Als Schneiderin nähte sie daraus Nachtwäsche. Der Legende nach hatte eine Frau in diesem Schleier eine wahnsinnige Macht über die Männer."]},
"Viktor Polov":{b:[
 "Great horseman, courier of Tsar Leonid III. Sent urgently to fetch sugar from Krasnov, he crossed the river holding the sack at arm's length so it would not melt. As his horse sank, he threw the sack to another rider, who threw it to a third, who reached the bank. A sport was born from it, polo, in tribute to Viktor, lost in the waters of the Sovarka.",
 "Gran jinete, mensajero del zar Leonid III. Enviado con urgencia a buscar azúcar a Krasnov, cruzó el río con el saco a pulso para que no se derritiera. Al hundirse su caballo, lanzó el saco a otro jinete, que lo lanzó a un tercero, el cual alcanzó la orilla. De ahí nació un deporte, el polo, en homenaje a Viktor, desaparecido en las aguas del Sovarka.",
 "傑出的騎手，沙皇列昂尼德三世的信使。他奉命緊急前往克拉斯諾夫取糖，渡河時把糖袋高舉過頭，以免糖化掉。坐騎下沉時，他把袋子拋給另一名騎手，那人又拋給第三人，最後終於上岸。人們由此發明了一項運動——馬球（polo），以紀念葬身索瓦爾卡河的維克多。",
 "Великий наездник, курьер царя Леонида III. Посланный срочно за сахаром в Краснов, он переправился через реку, держа мешок на вытянутых руках, чтобы тот не растаял. Когда конь стал тонуть, он бросил мешок другому всаднику, тот — третьему, и третий достиг берега. Так родился спорт — поло, в честь Виктора, сгинувшего в водах Соварки.",
 "위대한 기수이자 레오니트 3세 황제의 전령. 크라스노프로 급히 설탕을 가지러 가던 그는 설탕이 녹지 않도록 자루를 팔을 뻗어 든 채 강을 건넜다. 말이 가라앉자 그는 자루를 다른 기수에게 던졌고, 그가 다시 세 번째 기수에게 던져 마침내 강기슭에 닿았다. 여기서 소바르카 강물 속으로 사라진 빅토르를 기리는 스포츠, 폴로가 탄생했다.",
 "فارس عظيم وساعي القيصر ليونيد الثالث. أُرسل على عجل لجلب السكر من كراسنوف، فعبر النهر رافعًا الكيس بذراعيه كي لا يذوب. ولما أخذ حصانه يغرق، رمى الكيس إلى فارس آخر، فرماه هذا إلى ثالث بلغ الضفة. ومن ذلك وُلدت رياضة البولو، تكريمًا لفيكتور الذي اختفى في مياه نهر سوفاركا.",
 "Grande cavaleiro, mensageiro do czar Leonid III. Enviado às pressas para buscar açúcar em Krasnov, atravessou o rio segurando o saco com os braços esticados para que não derretesse. Quando o cavalo afundou, jogou o saco para outro cavaleiro, que o jogou para um terceiro, que alcançou a margem. Daí nasceu um esporte, o polo, em homenagem a Viktor, desaparecido nas águas do Sovarka.",
 "Großer Reiter, Kurier von Zar Leonid III. Eilig nach Krasnow geschickt, um Zucker zu holen, durchquerte er den Fluss und hielt den Sack mit ausgestreckten Armen hoch, damit er nicht schmolz. Als sein Pferd versank, warf er den Sack einem anderen Reiter zu, der ihn einem dritten zuwarf, und dieser erreichte das Ufer. Daraus entstand ein Sport, Polo, zu Ehren von Viktor, verschollen in den Fluten der Sowarka."]},
"Alexander Aspirine":{b:[
 "Scientist, inventor of a fermented wine that cured headaches. In large doses, it made you vomit.",
 "Científico, inventor de un vino fermentado que quitaba el dolor de cabeza. En dosis altas, hacía vomitar.",
 "科學家，發明了一種能治頭痛的發酵酒。喝多了會讓人嘔吐。",
 "Учёный, изобретатель забродившего вина, снимавшего головную боль. В больших дозах вызывало рвоту.",
 "두통을 낫게 하는 발효 포도주를 발명한 과학자. 많이 마시면 토하게 만들었다.",
 "عالِم ومخترع نبيذ مخمّر يزيل الصداع. وبجرعات كبيرة كان يسبّب التقيؤ.",
 "Cientista, inventor de um vinho fermentado que curava dor de cabeça. Em doses altas, fazia vomitar.",
 "Wissenschaftler, Erfinder eines vergorenen Weins gegen Kopfschmerzen. In hoher Dosis brachte er einen zum Erbrechen."]},
"Ivan Betonov":{b:[
 "Engineer and architect, to whom we owe the Government Palace. The only flaw in his work: it was so colossal that the country ran short of building materials five years in a row.",
 "Ingeniero y arquitecto, a quien se debe el Palacio del Gobierno. Único defecto de su obra: era tan colosal que el país se quedó sin materiales de construcción cinco años seguidos.",
 "工程師兼建築師，政府宮出自他手。他的作品唯一的缺點：規模太過龐大，全國連續五年建材短缺。",
 "Инженер и архитектор, автор Дворца Правительства. Единственный недостаток его творения: оно было столь колоссальным, что страна пять лет подряд испытывала нехватку стройматериалов.",
 "정부 궁전을 지은 엔지니어이자 건축가. 그의 작품의 유일한 결점은 너무 거대해서 나라가 5년 연속 건축 자재 부족에 시달렸다는 것이다.",
 "مهندس ومعماري، يعود إليه الفضل في قصر الحكومة. العيب الوحيد في عمله: أنه كان ضخمًا إلى حدّ أن البلاد عانت نقصًا في مواد البناء خمس سنوات متتالية.",
 "Engenheiro e arquiteto, a quem se deve o Palácio do Governo. Único defeito da obra: era tão colossal que o país ficou sem materiais de construção cinco anos seguidos.",
 "Ingenieur und Architekt, dem man den Regierungspalast verdankt. Einziger Makel seines Werks: Es war so gewaltig, dass dem Land fünf Jahre lang Baumaterial fehlte."]},
"Anna Mouriskova":{b:[
 "Prostitute and spy. A stunning woman, she obtained every secret of the dignitaries she chose, through her beauty and intelligence. Comrade President Taras Sergeyevich Belov had her executed: jealousy, or because she knew too much about him, we will never know. The execution decree has never been found; officially, Comrade Belov only ever signed the one setting tea time.",
 "Prostituta y espía. Mujer espléndida, obtenía todos los secretos de los dignatarios que elegía, gracias a su belleza y su inteligencia. El camarada presidente Taras Serguéievich Belov la hizo ejecutar: celos, o porque sabía demasiado de él, nunca se sabrá. El decreto de ejecución nunca apareció; oficialmente, el camarada Belov solo firmó el de la hora del té.",
 "妓女兼間諜。她美貌出眾，憑藉美色與智慧，從她挑中的每位顯要口中套出所有秘密。塔拉斯·謝爾蓋耶維奇·別洛夫同志總統下令處決了她：是出於嫉妒，還是因為她知道他太多事，永遠無從得知。處決令始終未被找到；官方說法是，別洛夫同志只簽過一道法令——規定下午茶時間的那道。",
 "Проститутка и шпионка. Красавица, благодаря красоте и уму она выведывала все тайны выбранных ею сановников. Товарищ президент Тарас Сергеевич Белов приказал её казнить: из ревности или потому, что она слишком много о нём знала, — мы никогда не узнаем. Указ о казни так и не нашли; официально товарищ Белов подписал лишь указ о времени чаепития.",
 "매춘부이자 스파이. 빼어난 미인이었던 그녀는 미모와 지성으로 자신이 고른 고관들의 비밀을 모조리 알아냈다. 타라스 세르게예비치 벨로프 동지 대통령은 그녀를 처형했다. 질투 때문이었는지, 그녀가 그에 대해 너무 많이 알았기 때문이었는지는 영영 알 수 없다. 처형 명령서는 발견되지 않았다. 공식적으로 벨로프 동지가 서명한 법령은 차 마시는 시간을 정한 것 하나뿐이다.",
 "بائعة هوى وجاسوسة. امرأة فاتنة، كانت تنتزع كل أسرار الوجهاء الذين تختارهم بجمالها وذكائها. أمر الرفيق الرئيس تاراس سيرغيفيتش بيلوف بإعدامها: غيرةً، أم لأنها كانت تعرف عنه الكثير، لن نعرف أبدًا. لم يُعثر قط على مرسوم الإعدام؛ ورسميًا لم يوقّع الرفيق بيلوف إلا مرسوم موعد الشاي.",
 "Prostituta e espiã. Mulher deslumbrante, obtinha todos os segredos dos dignitários que escolhia, com sua beleza e inteligência. O camarada presidente Taras Sergueievitch Belov mandou executá-la: ciúme, ou porque ela sabia demais sobre ele, nunca saberemos. O decreto de execução nunca foi encontrado; oficialmente, o camarada Belov só assinou o da hora do chá.",
 "Prostituierte und Spionin. Als bildschöne Frau entlockte sie den Würdenträgern ihrer Wahl mit Schönheit und Klugheit jedes Geheimnis. Genosse Präsident Taras Sergejewitsch Below ließ sie hinrichten: aus Eifersucht oder weil sie zu viel über ihn wusste, wird man nie erfahren. Das Hinrichtungsdekret wurde nie gefunden; offiziell hat Genosse Below nur das zur Teestunde unterschrieben."]},
// Salle des criminels
"« Le Fantôme du Kolkhoze n° 7 »":{n:["“The Ghost of Kolkhoz No. 7”","«El Fantasma del Koljós n.º 7»","「第七集體農莊的幽靈」","«Призрак колхоза № 7»","‘제7 콜호스의 유령’","«شبح الكولخوز رقم 7»","“O Fantasma do Kolkhoz nº 7”","„Das Gespenst der Kolchose Nr. 7“"],
 d:["1920s","años veinte","1920年代","1920-е годы","1920년대","العشرينيات","anos 1920","1920er-Jahre"],b:[
 "Stole one beetroot from the collective silo every night. Never caught; the silo was declared “chronically under-producing”.",
 "Robaba cada noche una remolacha del silo colectivo. Nunca lo atraparon; el silo fue declarado «en subproducción crónica».",
 "每晚從集體穀倉偷走一顆甜菜。始終沒被抓到；穀倉被宣布為「長期產量不足」。",
 "Каждую ночь крал по свёкле из колхозного силоса. Так и не был пойман; силос объявили «хронически недопроизводящим».",
 "매일 밤 집단 저장고에서 비트 하나씩을 훔쳤다. 끝내 잡히지 않았고, 저장고는 ‘만성 생산 부족’ 판정을 받았다.",
 "كان يسرق كل ليلة شمندرة من صومعة التعاونية. لم يُقبض عليه قط؛ وأُعلنت الصومعة «في حالة نقص إنتاج مزمن».",
 "Roubava toda noite uma beterraba do silo coletivo. Nunca foi pego; o silo foi declarado “em subprodução crônica”.",
 "Stahl jede Nacht eine Rübe aus dem Kollektivsilo. Nie gefasst; das Silo wurde für „chronisch unterproduktiv“ erklärt."]},
"Grigori Faussaire":{b:[
 "Printed fake ration tickets so perfect that the Committee preferred them to the real ones.",
 "Imprimió cartillas de racionamiento falsas tan perfectas que el Comité las prefería a las auténticas.",
 "印製的假配給券完美無瑕，連委員會都比真券更喜歡它們。",
 "Печатал фальшивые продовольственные карточки, столь совершенные, что Комитет предпочитал их настоящим.",
 "가짜 배급표를 너무 완벽하게 찍어내서 위원회는 진짜보다 그것을 더 좋아했다.",
 "طبع بطاقات تموين مزوّرة بلغت من الإتقان أن اللجنة كانت تفضّلها على الأصلية.",
 "Imprimiu tíquetes de racionamento falsos tão perfeitos que o Comitê os preferia aos verdadeiros.",
 "Druckte so perfekte gefälschte Lebensmittelkarten, dass das Komitee sie den echten vorzog."]},
"Nina « La Samovar » Kipiatova":{n:["Nina “The Samovar” Kipiatova","Nina «La Samovar» Kipiatova","「茶炊」妮娜·基皮亞托娃","Нина «Самовар» Кипятова","‘사모바르’ 니나 키퍄토바","نينا «السماور» كيبياتوفا","Nina “A Samovar” Kipiatova","Nina „Der Samowar“ Kipiatowa"],b:[
 "Smuggler of foreign tea, hidden in state samovars. Sentenced to serve tea at the courthouse for twenty years.",
 "Contrabandista de té extranjero, escondido en samovares del Estado. Condenada a servir el té en el tribunal durante veinte años.",
 "走私外國茶葉，藏在國家的茶炊裡。被判在法院奉茶二十年。",
 "Контрабандистка иностранного чая, спрятанного в государственных самоварах. Приговорена двадцать лет подавать чай в суде.",
 "국영 사모바르에 숨겨 외국 차를 밀수했다. 20년간 법원에서 차를 따르라는 판결을 받았다.",
 "مهرّبة شاي أجنبي تخفيه في سماورات الدولة. حُكم عليها بتقديم الشاي في المحكمة عشرين عامًا.",
 "Contrabandista de chá estrangeiro, escondido em samovares do Estado. Condenada a servir chá no tribunal por vinte anos.",
 "Schmugglerin ausländischen Tees, versteckt in staatlichen Samowaren. Verurteilt, zwanzig Jahre lang im Gericht Tee zu servieren."]},
"Oleg Revendov":{b:[
 "Resold the same parade tractor three times on the black market. The tractor is still on People's Square.",
 "Revendió tres veces el mismo tractor de desfile en el mercado negro. El tractor sigue en la Plaza del Pueblo.",
 "在黑市上把同一輛閱兵拖拉機轉賣了三次。那輛拖拉機至今仍停在人民廣場上。",
 "Трижды перепродал на чёрном рынке один и тот же парадный трактор. Трактор до сих пор стоит на Народной площади.",
 "같은 열병식용 트랙터를 암시장에서 세 번이나 되팔았다. 그 트랙터는 지금도 인민 광장에 서 있다.",
 "باع الجرّار نفسه المخصّص للاستعراض ثلاث مرات في السوق السوداء. وما زال الجرّار في ساحة الشعب.",
 "Revendeu três vezes o mesmo trator de desfile no mercado negro. O trator continua na Praça do Povo.",
 "Verkaufte denselben Paradetraktor dreimal auf dem Schwarzmarkt. Der Traktor steht noch immer auf dem Platz des Volkes."]},
// Salle des maires
"Camarade Fiodor Plankine":{n:["Comrade Fiodor Plankine","Camarada Fiodor Plankine","菲奧多爾·普蘭金同志","Товарищ Фёдор Планкин","표도르 플란킨 동지","الرفيق فيودور بلانكين","Camarada Fiodor Plankine","Genosse Fiodor Plankine"],b:[
 "First president of the Municipal Soviet. Had the People's Prospekt drawn with a ruler, in a straight line, through three houses and a church.",
 "Primer presidente del Sóviet municipal. Hizo trazar la Prospekt del Pueblo con regla, en línea recta, a través de tres casas y una iglesia.",
 "市蘇維埃首任主席。他用直尺畫出人民大道，筆直穿過三棟房子和一座教堂。",
 "Первый председатель горсовета. Велел проложить Народный проспект по линейке, по прямой, через три дома и церковь.",
 "시 소비에트의 초대 의장. 인민 대로를 자로 그어 일직선으로 냈는데, 집 세 채와 교회 하나를 관통했다.",
 "أول رئيس للسوفييت البلدي. أمر برسم شارع الشعب بالمسطرة، في خط مستقيم، عبر ثلاثة منازل وكنيسة.",
 "Primeiro presidente do Soviete municipal. Mandou traçar a Prospekt do Povo com régua, em linha reta, atravessando três casas e uma igreja.",
 "Erster Vorsitzender des Stadtsowjets. Ließ den Prospekt des Volkes mit dem Lineal ziehen, schnurgerade, durch drei Häuser und eine Kirche."]},
"Antonina Bétonova":{b:[
 "President for twenty-six years. We owe her every grey building in the city, and grey itself, declared the municipal colour.",
 "Presidenta durante veintiséis años. A ella se deben todos los edificios grises de la ciudad, y el gris mismo, declarado color municipal.",
 "擔任主席二十六年。城裡所有灰色建築都出自她手，連灰色本身也是——她將其定為市色。",
 "Председательница двадцать шесть лет. Ей город обязан всеми серыми домами, да и самим серым цветом, объявленным городским.",
 "26년간 의장을 지냈다. 도시의 모든 회색 건물이 그녀 덕분이며, 시의 공식 색으로 지정된 회색 자체도 그렇다.",
 "رئيسة طوال ستة وعشرين عامًا. يعود إليها الفضل في كل مباني المدينة الرمادية، وفي اللون الرمادي نفسه الذي أُعلن لونًا للبلدية.",
 "Presidente por vinte e seis anos. Deve-se a ela todos os prédios cinzentos da cidade, e o próprio cinza, declarado cor municipal.",
 "Sechsundzwanzig Jahre lang Vorsitzende. Ihr verdankt die Stadt alle grauen Gebäude und das Grau selbst, zur Stadtfarbe erklärt."]},
"Camarade Ivan Provizorov":{n:["Comrade Ivan Provizorov","Camarada Ivan Provizorov","伊凡·普羅維佐羅夫同志","Товарищ Иван Провизоров","이반 프로비조로프 동지","الرفيق إيفان بروفيزوروف","Camarada Ivan Provizorov","Genosse Ivan Provizorov"],b:[
 "Acting president for nineteen years: the Committee never made up its mind to appoint him for good.",
 "Presidente interino durante diecinueve años: el Comité nunca se decidió a nombrarlo definitivamente.",
 "代理主席長達十九年：委員會始終下不了決心正式任命他。",
 "Исполняющий обязанности председателя девятнадцать лет: Комитет так и не решился назначить его окончательно.",
 "19년 동안 의장 직무대행이었다. 위원회는 끝내 그를 정식으로 임명할 결심을 하지 못했다.",
 "رئيس بالنيابة طوال تسعة عشر عامًا: لم تحسم اللجنة أمرها قط لتعيينه نهائيًا.",
 "Presidente interino por dezenove anos: o Comitê nunca se decidiu a nomeá-lo de vez.",
 "Neunzehn Jahre kommissarischer Vorsitzender: Das Komitee konnte sich nie entschließen, ihn endgültig zu ernennen."]},
"Mikhaïl Plénitoudov":{b:[
 "Elected with 104% of the vote. Asked for a recount, for form's sake.",
 "Elegido con el 104 % de los votos. Pidió un recuento, por guardar las formas.",
 "以104%的得票率當選。為了做做樣子，他要求重新計票。",
 "Избран со 104 % голосов. Потребовал пересчёта — для порядка.",
 "104%의 득표율로 당선되었다. 형식상 재검표를 요구했다.",
 "انتُخب بنسبة 104% من الأصوات. وطلب إعادة الفرز، من باب الشكليات.",
 "Eleito com 104% dos votos. Pediu recontagem, por formalidade.",
 "Mit 104 % der Stimmen gewählt. Verlangte der Form halber eine Nachzählung."]},
// Salle des personnalités (Krasnov)
"Babouchka Agafia Pirojkova":{n:["Babushka Agafia Pirojkova","Babushka Agafia Pirojkova","阿加菲婭·皮羅日科娃奶奶","Бабушка Агафья Пирожкова","아가피야 피로시코바 할머니","الجدّة أغافيا بيروجكوفا","Babushka Agafia Pirojkova","Babuschka Agafia Pirojkowa"],b:[
 "Fed the whole harbour district through the winter of the Great Shortage with a single pot, never emptied.",
 "Alimentó a todo el barrio del puerto durante el invierno de la Gran Escasez con una sola olla, que nunca se vació.",
 "在大饑荒那年冬天，她只用一口從未見底的鍋，餵飽了整個港區。",
 "Кормила весь портовый квартал зимой Великой Нехватки из одного-единственного котла, который так и не опустел.",
 "대기근의 겨울 동안 한 번도 바닥나지 않은 냄비 하나로 항구 지구 전체를 먹여 살렸다.",
 "أطعمت حيّ الميناء كله طوال شتاء النقص الكبير بقدر واحدة لم تفرغ أبدًا.",
 "Alimentou todo o bairro do porto durante o inverno da Grande Escassez com uma única panela, nunca esvaziada.",
 "Ernährte im Winter der Großen Knappheit das ganze Hafenviertel mit einem einzigen Topf, der nie leer wurde."]},
"Alexeï Balalaïkine":{b:[
 "Official singer of the Party: three hundred songs, all about the same tractor.",
 "Cantante oficial del Partido: trescientas canciones, todas sobre el mismo tractor.",
 "黨的官方歌手：三百首歌，全都在唱同一輛拖拉機。",
 "Официальный певец Партии: триста песен, и все про один и тот же трактор.",
 "당의 공식 가수. 300곡을 불렀는데 모두 같은 트랙터에 관한 노래였다.",
 "المغنّي الرسمي للحزب: ثلاثمئة أغنية، كلها عن الجرّار نفسه.",
 "Cantor oficial do Partido: trezentas canções, todas sobre o mesmo trator.",
 "Offizieller Sänger der Partei: dreihundert Lieder, alle über denselben Traktor."]},
"Docteure Zinaïda Garrotova":{n:["Doctor Zinaïda Garrotova","Doctora Zinaïda Garrotova","季娜伊達·加羅托娃醫師","Доктор Зинаида Гарротова","지나이다 가로토바 박사","الطبيبة زينايدا غاروتوفا","Doutora Zinaïda Garrotova","Doktorin Zinaïda Garrotowa"],b:[
 "Surgeon at the public hospital for forty years; operated by torchlight on power-cut nights.",
 "Cirujana del hospital público durante cuarenta años; operaba con linterna las noches de apagón.",
 "在公立醫院當了四十年外科醫師；停電的夜晚就打著手電筒動手術。",
 "Хирург городской больницы сорок лет; в вечера отключений оперировала при свете фонарика.",
 "40년간 공립병원 외과의사로 일했다. 정전되는 밤에는 손전등을 켜고 수술했다.",
 "جرّاحة في المستشفى العام طوال أربعين عامًا؛ كانت تُجري العمليات على ضوء مصباح يدوي في ليالي انقطاع الكهرباء.",
 "Cirurgiã do hospital público por quarenta anos; operava com lanterna nas noites de apagão.",
 "Vierzig Jahre Chirurgin am öffentlichen Krankenhaus; operierte an Abenden mit Stromausfall im Taschenlampenlicht."]},
"Kostia Poussetov":{b:[
 "Municipal champion of snow shovelling. Refuses the snowplough “on ideological principle”.",
 "Campeón municipal de quitar nieve con pala. Rechaza la quitanieves «por principio ideológico».",
 "市級鏟雪冠軍。「基於意識形態原則」拒用掃雪機。",
 "Городской чемпион по уборке снега лопатой. Отказывается от снегоуборщика «из идеологических соображений».",
 "시 삽 제설 챔피언. ‘이념적 원칙에 따라’ 제설기를 거부한다.",
 "بطل البلدية في إزاحة الثلج بالمجرفة. يرفض كاسحة الثلج «عن مبدأ أيديولوجي».",
 "Campeão municipal de remoção de neve com pá. Recusa o limpa-neve “por princípio ideológico”.",
 "Stadtmeister im Schneeschippen. Lehnt den Schneepflug „aus ideologischem Prinzip“ ab."]},
// Salle des entrepreneurs
"Directeur Pavel Kombinatov":{n:["Director Pavel Kombinatov","Director Pavel Kombinatov","帕維爾·孔比納托夫廠長","Директор Павел Комбинатов","파벨 콤비나토프 공장장","المدير بافيل كومبيناتوف","Diretor Pavel Kombinatov","Direktor Pawel Kombinatow"],b:[
 "Founded Novomirsk's first kombinat, which produced tractors, saucepans and medals all at once.",
 "Fundó el primer kombinat de Novomirsk, que producía a la vez tractores, cacerolas y medallas.",
 "創辦了新米爾斯克第一座聯合工廠，同時生產拖拉機、鍋子和獎章。",
 "Основал первый комбинат Новомирска, выпускавший одновременно тракторы, кастрюли и медали.",
 "노보미르스크 최초의 콤비나트를 세웠다. 그곳은 트랙터와 냄비와 훈장을 한꺼번에 생산했다.",
 "أسّس أول كومبينات في نوفوميرسك، كان ينتج في آن واحد الجرّارات والقدور والأوسمة.",
 "Fundou o primeiro kombinat de Novomirsk, que produzia ao mesmo tempo tratores, panelas e medalhas.",
 "Gründete das erste Kombinat von Nowomirsk, das zugleich Traktoren, Kochtöpfe und Orden herstellte."]},
"Alexandra Stakhanova":{b:[
 "Exceeded the Plan by 1,400% in a single night. The factory had to close for a week, for lack of raw materials.",
 "Superó el Plan en un 1400 % en una sola noche. La fábrica tuvo que cerrar una semana por falta de materias primas.",
 "一夜之間超額完成計畫1400%。工廠因原料用盡，不得不停工一週。",
 "За одну ночь перевыполнила План на 1400 %. Заводу пришлось закрыться на неделю из-за нехватки сырья.",
 "하룻밤 만에 계획을 1,400% 초과 달성했다. 원자재가 바닥나 공장은 일주일간 문을 닫아야 했다.",
 "تجاوزت الخطة بنسبة 1400% في ليلة واحدة. واضطر المصنع إلى الإغلاق أسبوعًا لنفاد المواد الأولية.",
 "Superou o Plano em 1.400% numa única noite. A fábrica teve de fechar uma semana por falta de matéria-prima.",
 "Übererfüllte den Plan in einer einzigen Nacht um 1 400 %. Die Fabrik musste eine Woche schließen, weil die Rohstoffe fehlten."]},
"Ingénieur Boris Pharmakov":{n:["Engineer Boris Pharmakov","Ingeniero Boris Pharmakov","鮑里斯·法爾馬科夫工程師","Инженер Борис Фармаков","보리스 파르마코프 기사","المهندس بوريس فارماكوف","Engenheiro Boris Pharmakov","Ingenieur Boris Pharmakow"],b:[
 "Founder of the Pharmanov factory. Invented a cough syrup that also cured, according to the label, ideological doubt.",
 "Fundador de la fábrica Pharmanov. Inventó un jarabe para la tos que también curaba, según la etiqueta, la duda ideológica.",
 "法爾馬諾夫藥廠創辦人。發明了一種止咳糖漿，據標籤所說，還能治療意識形態上的動搖。",
 "Основатель завода «Фарманов». Изобрёл сироп от кашля, который, согласно этикетке, лечил и идеологические сомнения.",
 "파르마노프 공장의 창립자. 기침 시럽을 발명했는데, 라벨에 따르면 이념적 의심도 치료해 주었다.",
 "مؤسّس مصنع فارمانوف. اخترع شراب سعال كان يشفي أيضًا، بحسب الملصق، من الشكّ الأيديولوجي.",
 "Fundador da fábrica Pharmanov. Inventou um xarope para tosse que também curava, segundo o rótulo, a dúvida ideológica.",
 "Gründer der Fabrik Pharmanow. Erfand einen Hustensaft, der laut Etikett auch ideologische Zweifel heilte."]},
"Dmitri Startoupov":{b:[
 "Created the city's first private company: an app that reports queues. All the queues.",
 "Creó la primera empresa privada de la ciudad: una aplicación que señala las colas. Todas las colas.",
 "創立了城裡第一家私人企業：一款回報排隊狀況的應用程式。所有的隊伍。",
 "Создал первую частную компанию города: приложение, сообщающее об очередях. Обо всех очередях.",
 "도시 최초의 민간 기업을 세웠다. 줄 서는 곳을 알려 주는 앱이다. 모든 줄을.",
 "أسّس أول شركة خاصة في المدينة: تطبيق يبلّغ عن الطوابير. كل الطوابير.",
 "Criou a primeira empresa privada da cidade: um aplicativo que avisa das filas. Todas as filas.",
 "Gründete das erste Privatunternehmen der Stadt: eine App, die Warteschlangen meldet. Alle Warteschlangen."]},
// Salle des organisations
"Grand Mécanicien Ephrem Tractorine":{n:["Grand Mechanic Ephrem Tractorine","Gran Mecánico Ephrem Tractorine","大技師埃夫雷姆·特拉克托林","Великий Механик Ефрем Тракторин","대기계공 에프렘 트락토린","الميكانيكي الأعظم إفريم تراكتورين","Grande Mecânico Ephrem Tractorine","Großmechaniker Ephrem Tractorine"],b:[
 "Founder of the cult of Tractorism. Blessed the city's first tractor, which started first time: it was seen as a miracle.",
 "Fundador del culto del Tractorismo. Bendijo el primer tractor de la ciudad, que arrancó a la primera: se vio en ello un milagro.",
 "拖拉機教的創始人。他為城裡第一輛拖拉機祝聖，結果一發就動：人們視之為神蹟。",
 "Основатель культа Тракторизма. Освятил первый трактор города, который завёлся с первого раза: в этом увидели чудо.",
 "트랙터교의 창시자. 도시 최초의 트랙터를 축복했는데, 그 트랙터가 단번에 시동이 걸리자 사람들은 기적이라 여겼다.",
 "مؤسّس عبادة الجرّارية. بارك أول جرّار في المدينة، فاشتغل من المحاولة الأولى: فرأى الناس في ذلك معجزة.",
 "Fundador do culto do Tratorismo. Abençoou o primeiro trator da cidade, que pegou de primeira: viram nisso um milagre.",
 "Gründer des Kults des Traktorismus. Segnete den ersten Traktor der Stadt, der auf Anhieb ansprang: Man sah darin ein Wunder."]},
"Camarade Vassili Cellulov":{n:["Comrade Vassili Cellulov","Camarada Vassili Cellulov","瓦西里·切盧洛夫同志","Товарищ Василий Целлулов","바실리 첼룰로프 동지","الرفيق فاسيلي تشيلولوف","Camarada Vassili Cellulov","Genosse Wassili Cellulow"],b:[
 "Secretary of the harbour Party cell for forty years. Knew everyone's name, address and opinions.",
 "Secretario de la célula del Partido del puerto durante cuarenta años. Conocía el nombre, la dirección y las opiniones de cada uno.",
 "擔任港口黨支部書記四十年。每個人的姓名、住址和想法，他都一清二楚。",
 "Сорок лет секретарь портовой партячейки. Знал имя, адрес и взгляды каждого.",
 "40년간 항구 당 세포의 서기였다. 모든 사람의 이름과 주소와 의견을 알고 있었다.",
 "أمين خلية الحزب في الميناء طوال أربعين عامًا. كان يعرف اسم كل واحد وعنوانه وآراءه.",
 "Secretário da célula do Partido do porto por quarenta anos. Conhecia o nome, o endereço e as opiniões de cada um.",
 "Vierzig Jahre Sekretär der Parteizelle des Hafens. Kannte Namen, Adresse und Meinung eines jeden."]},
"Lioubov Grèvina":{b:[
 "Leader of the 1956 knitters' strike, the only strike ever tolerated: they knitted socks for the army on the picket line.",
 "Líder de la huelga de las tejedoras de 1956, la única huelga jamás tolerada: tejían calcetines para el ejército en el piquete.",
 "1956年編織女工罷工的領袖，那是唯一被容忍的罷工：她們在糾察線上為軍隊織襪子。",
 "Предводительница забастовки вязальщиц 1956 года, единственной когда-либо дозволенной: в пикете они вязали носки для армии.",
 "1956년 뜨개질공 파업의 지도자. 유일하게 용인된 파업이었다. 그들은 피켓 시위를 하며 군대에 보낼 양말을 떴다.",
 "قائدة إضراب الحائكات عام 1956، الإضراب الوحيد الذي سُمح به يومًا: كنّ يحِكن الجوارب للجيش أثناء الاعتصام.",
 "Líder da greve das tricoteiras de 1956, a única greve jamais tolerada: elas tricotavam meias para o exército no piquete.",
 "Anführerin des Strickerinnenstreiks von 1956, des einzigen je geduldeten Streiks: Auf dem Streikposten strickten sie Socken für die Armee."]},
"Gena Ultrasov":{b:[
 "Leader of the Dynamo Novomirsk supporters. Banned from the stadium since 2001, he cheers the team on from the roof of the police station.",
 "Jefe de los hinchas del Dinamo Novomirsk. Con prohibición de entrar al estadio desde 2001, anima al equipo desde el tejado de la comisaría.",
 "新米爾斯克迪納摩隊的球迷領袖。自2001年起被禁止進入球場，他改在警察局屋頂上為球隊加油。",
 "Лидер болельщиков «Динамо Новомирск». С 2001 года ему запрещено ходить на стадион, и он болеет за команду с крыши комиссариата.",
 "디나모 노보미르스크 서포터스의 리더. 2001년부터 경기장 출입 금지 상태라 경찰서 지붕 위에서 팀을 응원한다.",
 "زعيم مشجّعي دينامو نوفوميرسك. ممنوع من دخول الملعب منذ 2001، فيشجّع الفريق من سطح مركز الشرطة.",
 "Chefe da torcida do Dínamo Novomirsk. Proibido de entrar no estádio desde 2001, torce pelo time do telhado da delegacia.",
 "Anführer der Fans von Dynamo Nowomirsk. Seit 2001 mit Stadionverbot, feuert er die Mannschaft vom Dach des Kommissariats an."]},
// Salle d'honneur militaire
"Général Arkadi Neigeov":{n:["General Arkadi Neigeov","General Arkadi Neigeov","阿爾卡季·內傑夫將軍","Генерал Аркадий Нейгеов","아르카디 네이게오프 장군","الجنرال أركادي نيجيوف","General Arkadi Neigeov","General Arkadi Neigeow"],b:[
 "Defended Novomirsk for an entire winter, at the head of two regiments and a single greatcoat, which they took turns wearing.",
 "Defendió Novomirsk todo un invierno, al mando de dos regimientos y un solo abrigo, que se pasaban por turnos.",
 "他率領兩個團、卻只有一件大衣，守住新米爾斯克整整一個冬天——大衣由士兵輪流穿。",
 "Целую зиму оборонял Новомирск во главе двух полков и одной-единственной шинели, которую они носили по очереди.",
 "두 개 연대와 단 한 벌의 외투를 이끌고 겨울 내내 노보미르스크를 지켰다. 외투는 돌아가며 입었다.",
 "دافع عن نوفوميرسك شتاءً كاملًا، على رأس فوجين ومعطف واحد كانوا يتناوبون على ارتدائه.",
 "Defendeu Novomirsk um inverno inteiro, à frente de dois regimentos e de um único casaco, que revezavam entre si.",
 "Verteidigte Nowomirsk einen ganzen Winter lang, an der Spitze zweier Regimenter und eines einzigen Mantels, den sie abwechselnd trugen."]},
"Sergent Tamara Chenillova":{n:["Sergeant Tamara Chenillova","Sargento Tamara Chenillova","塔瑪拉·切尼洛娃中士","Сержант Тамара Шенилова","타마라 셰닐로바 병장","الرقيب تامارا شينيلوفا","Sargento Tamara Chenillova","Sergeantin Tamara Chenillowa"],b:[
 "Drove her tank across a frozen lake to resupply the city. The tank sank; the supplies arrived.",
 "Condujo su tanque a través de un lago helado para abastecer la ciudad. El tanque se hundió; el abastecimiento llegó.",
 "她開著坦克橫越結冰的湖面為城市運送補給。坦克沉了；補給送到了。",
 "Провела свой танк по замёрзшему озеру, чтобы снабдить город. Танк утонул; провизия дошла.",
 "도시에 보급품을 전하려고 얼어붙은 호수 위로 전차를 몰았다. 전차는 가라앉았지만 보급품은 도착했다.",
 "قادت دبابتها عبر بحيرة متجمّدة لتموين المدينة. غرقت الدبابة؛ ووصلت المؤن.",
 "Conduziu seu tanque por um lago congelado para abastecer a cidade. O tanque afundou; o abastecimento chegou.",
 "Fuhr ihren Panzer über einen zugefrorenen See, um die Stadt zu versorgen. Der Panzer sank; der Nachschub kam an."]},
"Caporal Iouri Parado":{n:["Corporal Iouri Parado","Cabo Iouri Parado","尤里·帕拉多下士","Капрал Юрий Парадо","유리 파라도 상병","العريف يوري بارادو","Cabo Iouri Parado","Gefreiter Iouri Parado"],b:[
 "Medal of merit for thirty parades on People's Square, without ever missing a step.",
 "Medalla al mérito por treinta desfiles en la Plaza del Pueblo, sin perder nunca el paso.",
 "在人民廣場參加三十次閱兵、從未踏錯一步，因而獲頒功勳獎章。",
 "Медаль «За заслуги» за тридцать парадов на Народной площади, ни разу не сбившись с шага.",
 "인민 광장 열병식에 30번 참가하며 한 번도 발을 틀리지 않아 공로 훈장을 받았다.",
 "وسام الاستحقاق لثلاثين استعراضًا في ساحة الشعب، من دون أن يخطئ الخطوة مرة واحدة.",
 "Medalha de mérito por trinta desfiles na Praça do Povo, sem jamais perder o passo.",
 "Verdienstmedaille für dreißig Paraden auf dem Platz des Volkes, ohne je aus dem Tritt zu kommen."]},
"Lieutenante Daria Radarova":{n:["Lieutenant Daria Radarova","Teniente Daria Radarova","達麗亞·拉達羅娃中尉","Лейтенант Дарья Радарова","다리야 라다로바 중위","الملازمة داريا راداروفا","Tenente Daria Radarova","Leutnantin Daria Radarowa"],b:[
 "First woman to command the city's anti-aircraft battery. Never fired: everyone saw her coming.",
 "Primera mujer al mando de la batería antiaérea de la ciudad. Nunca disparó: todo el mundo la vio venir.",
 "第一位指揮城市防空砲兵連的女性。她從未開過火：大家早就看見她來了。",
 "Первая женщина, командовавшая городской зенитной батареей. Ни разу не выстрелила: все видели её издалека.",
 "도시 방공포대를 지휘한 최초의 여성. 한 번도 발포하지 않았다. 다들 그녀가 오는 걸 미리 봤으니까.",
 "أول امرأة تقود بطارية المدفعية المضادة للطائرات في المدينة. لم تطلق النار قط: فقد رآها الجميع قادمة.",
 "Primeira mulher a comandar a bateria antiaérea da cidade. Nunca disparou: todo mundo a viu chegando.",
 "Erste Frau an der Spitze der Flakbatterie der Stadt. Hat nie geschossen: Jeder sah sie kommen."]},
// Salle des unions
"Stepan Tchernov et Anna Belova":{n:["Stepan Tchernov and Anna Belova","Stepan Tchernov y Anna Belova","斯捷潘·切爾諾夫與安娜·別洛娃","Степан Чернов и Анна Белова","스테판 체르노프와 안나 벨로바","ستيبان تشيرنوف وآنا بيلوفا","Stepan Tchernov e Anna Belova","Stepan Tschernow und Anna Belowa"],
 d:["married in 1911","casados en 1911","1911年結婚","поженились в 1911 году","1911년 결혼","تزوّجا عام 1911","casados em 1911","verheiratet 1911"],b:[
 "Their union reconciled the harbour district and the factory district. The wedding lasted nine days and emptied the kvass reserves.",
 "Su unión reconcilió el barrio del puerto y el de las fábricas. La boda duró nueve días y agotó las reservas de kvas.",
 "他們的結合讓港區與工廠區言歸於好。婚宴辦了九天，把格瓦斯存貨喝得一乾二淨。",
 "Их союз примирил портовый квартал с заводским. Свадьба длилась девять дней и опустошила запасы кваса.",
 "두 사람의 결혼은 항구 지구와 공장 지구를 화해시켰다. 잔치는 아흐레 동안 이어져 크바스 비축분을 바닥냈다.",
 "صالح زواجهما بين حيّ الميناء وحيّ المصانع. دام العرس تسعة أيام وأفرغ مخزون الكفاس.",
 "A união dos dois reconciliou o bairro do porto e o das fábricas. A festa durou nove dias e esvaziou as reservas de kvass.",
 "Ihre Ehe versöhnte das Hafenviertel mit dem Fabrikviertel. Die Hochzeit dauerte neun Tage und leerte die Kwass-Vorräte."]},
"Fiodor et Galina Patiencev":{n:["Fiodor and Galina Patiencev","Fiodor y Galina Patiencev","菲奧多爾與加琳娜·帕先采夫","Фёдор и Галина Терпенцевы","표도르와 갈리나 파티엔체프","فيودور وغالينا باتيينتسيف","Fiodor e Galina Patiencev","Fiodor und Galina Patiencew"],
 d:["married in 1947","casados en 1947","1947年結婚","поженились в 1947 году","1947년 결혼","تزوّجا عام 1947","casados em 1947","verheiratet 1947"],b:[
 "Waited eleven years for a shared flat; they then lived there for fifty years, with two other families.",
 "Esperaron once años un piso común; después vivieron en él cincuenta años, con otras dos familias.",
 "為了一間共同的公寓等了十一年；之後在那裡住了五十年，還跟另外兩戶人家同住。",
 "Одиннадцать лет ждали общую квартиру; потом прожили в ней пятьдесят лет — вместе с двумя другими семьями.",
 "함께 살 아파트를 11년이나 기다렸다. 그 후 그곳에서 50년을 살았는데, 다른 두 가족과 함께였다.",
 "انتظرا أحد عشر عامًا شقة مشتركة؛ ثم عاشا فيها خمسين عامًا، مع عائلتين أخريين.",
 "Esperaram onze anos por um apartamento em comum; depois viveram nele cinquenta anos, com outras duas famílias.",
 "Warteten elf Jahre auf eine gemeinsame Wohnung; danach lebten sie dort fünfzig Jahre, mit zwei anderen Familien."]},
"Igor Rebondov et Svetlana Rebondova":{n:["Igor Rebondov and Svetlana Rebondova","Igor Rebondov y Svetlana Rebondova","伊戈爾·雷邦多夫與斯韋特蘭娜·雷邦多娃","Игорь Ребондов и Светлана Ребондова","이고르 레본도프와 스베틀라나 레본도바","إيغور ريبوندوف وسفيتلانا ريبوندوفا","Igor Rebondov e Svetlana Rebondova","Igor Rebondow und Swetlana Rebondowa"],
 d:["married in 1983, 1986 and 1990","casados en 1983, 1986 y 1990","1983、1986與1990年結婚","поженились в 1983, 1986 и 1990 годах","1983년, 1986년, 1990년 결혼","تزوّجا في 1983 و1986 و1990","casados em 1983, 1986 e 1990","verheiratet 1983, 1986 und 1990"],b:[
 "Three weddings, two divorces, always the same form. The Registry Office gave them a rubber stamp.",
 "Tres bodas, dos divorcios, siempre el mismo formulario. La Oficina del Registro Civil les regaló un sello.",
 "三次結婚、兩次離婚，用的總是同一張表格。戶政事務所送了他們一枚印章。",
 "Три свадьбы, два развода, всегда один и тот же бланк. ЗАГС подарил им печать.",
 "결혼 세 번, 이혼 두 번, 서류는 늘 같은 양식이었다. 호적 사무소는 그들에게 도장을 하나 선물했다.",
 "ثلاث زيجات وطلاقان، والاستمارة نفسها دائمًا. فأهداهما مكتب الأحوال المدنية ختمًا.",
 "Três casamentos, dois divórcios, sempre o mesmo formulário. O Cartório de Registro Civil lhes deu um carimbo de presente.",
 "Drei Hochzeiten, zwei Scheidungen, immer dasselbe Formular. Das Standesamt schenkte ihnen einen Stempel."]},
// Salle des scandales
"L'affaire du tracteur en carton":{n:["The cardboard tractor affair","El caso del tractor de cartón","紙板拖拉機事件","Дело о картонном тракторе","판지 트랙터 사건","قضية الجرّار الكرتوني","O caso do trator de papelão","Die Affäre um den Papptraktor"],b:[
 "The tractor presented to the Central Committee was a painted model. It paraded anyway, pushed by six workers.",
 "El tractor presentado al Comité Central era una maqueta pintada. Desfiló de todos modos, empujado por seis obreros.",
 "獻給中央委員會的拖拉機其實是塗了漆的模型。它照樣參加了遊行，由六名工人推著走。",
 "Трактор, представленный Центральному комитету, оказался раскрашенным макетом. Он всё равно прошёл парадом, его толкали шестеро рабочих.",
 "중앙위원회에 선보인 트랙터는 색칠한 모형이었다. 그래도 그 트랙터는 노동자 여섯 명이 밀어서 행진했다.",
 "كان الجرّار المقدَّم إلى اللجنة المركزية مجسّمًا مطليًّا. ومع ذلك شارك في الاستعراض، يدفعه ستة عمّال.",
 "O trator apresentado ao Comitê Central era uma maquete pintada. Desfilou mesmo assim, empurrado por seis operários.",
 "Der dem Zentralkomitee vorgeführte Traktor war ein bemaltes Modell. Er fuhr trotzdem in der Parade mit, geschoben von sechs Arbeitern."]},
"Le scandale des betteraves comptées deux fois":{n:["The double-counted beetroot scandal","El escándalo de las remolachas contadas dos veces","甜菜重複計算醜聞","Скандал с дважды посчитанной свёклой","두 번 센 비트 스캔들","فضيحة الشمندر المعدود مرتين","O escândalo das beterrabas contadas duas vezes","Der Skandal um die doppelt gezählten Rüben"],b:[
 "The kombinat declared a record harvest. It was later discovered that every beetroot was counted going into the silo and coming out.",
 "El kombinat declaró una cosecha récord. Más tarde se descubrió que contaba cada remolacha al entrar y al salir del silo.",
 "聯合工廠宣布創下收成紀錄。後來才發現，每顆甜菜進穀倉時算一次，出穀倉時又算一次。",
 "Комбинат заявил о рекордном урожае. Позже выяснилось, что каждую свёклу считали на входе в силос и на выходе.",
 "콤비나트는 기록적인 수확을 신고했다. 나중에 알고 보니 비트 하나하나를 저장고에 넣을 때 한 번, 꺼낼 때 한 번 셌던 것이다.",
 "أعلن الكومبينات محصولًا قياسيًا. واكتُشف لاحقًا أنه كان يعدّ كل شمندرة عند دخولها الصومعة وعند خروجها.",
 "O kombinat declarou uma colheita recorde. Descobriu-se depois que contava cada beterraba na entrada e na saída do silo.",
 "Das Kombinat meldete eine Rekordernte. Später kam heraus, dass jede Rübe beim Eingang ins Silo und beim Ausgang gezählt wurde."]},
"L'affaire du polonium au thé":{n:["The polonium tea affair","El caso del polonio en el té","茶裡的釙事件","Дело о полонии в чае","홍차 속 폴로늄 사건","قضية البولونيوم في الشاي","O caso do polônio no chá","Die Polonium-im-Tee-Affäre"],b:[
 "A foreign delegate fell ill after a cup of tea at the Grand Hotel. According to the official version, he was allergic to sugar.",
 "Un delegado extranjero enfermó tras una taza de té en el Gran Hotel. Según la versión oficial, era alérgico al azúcar.",
 "一名外國代表在大酒店喝了一杯茶後病倒。官方說法是：他對糖過敏。",
 "Иностранный делегат заболел после чашки чая в Гранд-отеле. По официальной версии, у него была аллергия на сахар.",
 "외국 대표가 그랜드 호텔에서 차 한 잔을 마신 뒤 병이 났다. 공식 발표에 따르면 그는 설탕 알레르기였다.",
 "مرض مندوب أجنبي بعد فنجان شاي في الفندق الكبير. وبحسب الرواية الرسمية، كان يعاني حساسية من السكر.",
 "Um delegado estrangeiro adoeceu depois de uma xícara de chá no Grande Hotel. Segundo a versão oficial, era alérgico a açúcar.",
 "Ein ausländischer Delegierter erkrankte nach einer Tasse Tee im Grand Hotel. Laut offizieller Version war er allergisch gegen Zucker."]},
"Le grand ravalement":{n:["The great facelift","La gran restauración","大翻修","Великий ремонт фасадов","대대적인 외벽 보수","الترميم الكبير","A grande reforma","Die große Fassadensanierung"],b:[
 "The renovation budget for the Prospekt's façades disappeared. The façades were repainted grey, the original colour.",
 "El presupuesto para renovar las fachadas de la Prospekt desapareció. Las fachadas se repintaron de gris, el color original.",
 "大道外牆的翻修預算不翼而飛。外牆被重新漆成灰色——也就是原本的顏色。",
 "Бюджет на ремонт фасадов проспекта исчез. Фасады перекрасили в серый — исходный цвет.",
 "대로 외벽 보수 예산이 사라졌다. 외벽은 원래 색인 회색으로 다시 칠해졌다.",
 "اختفت ميزانية ترميم واجهات الشارع الكبير. فأُعيد طلاء الواجهات بالرمادي، لونها الأصلي.",
 "O orçamento de reforma das fachadas da Prospekt desapareceu. As fachadas foram repintadas de cinza, a cor original.",
 "Das Budget für die Sanierung der Fassaden am Prospekt verschwand. Die Fassaden wurden grau gestrichen, in der ursprünglichen Farbe."]},
// Musée présidentiel (Palais présidentiel de Sovarka)
"Camarade Arkadi Ivanovitch Zolotov":{n:["Comrade Arkadi Ivanovich Zolotov","Camarada Arkadi Ivánovich Zolotov","阿爾卡季·伊凡諾維奇·佐洛托夫同志","Товарищ Аркадий Иванович Золотов","아르카디 이바노비치 졸로토프 동지","الرفيق أركادي إيفانوفيتش زولوتوف","Camarada Arkadi Ivanovitch Zolotov","Genosse Arkadi Iwanowitsch Solotow"],b:[
 "First President of the Republic of Sovarka. Inaugurated the Palace, then discovered there was nothing to decide there. Spent thirty years cutting ribbons.",
 "Primer Presidente de la República de Sovarka. Inauguró el Palacio y luego descubrió que allí no había nada que decidir. Pasó treinta años cortando cintas.",
 "索瓦爾卡共和國首任總統。他為總統宮剪綵啟用，隨後發現那裡根本沒有什麼需要他決定。他花了三十年剪綵。",
 "Первый Президент Республики Соварка. Открыл Дворец, а потом обнаружил, что решать там нечего. Тридцать лет перерезал ленточки.",
 "소바르카 공화국의 초대 대통령. 궁전을 개관한 뒤, 그곳에서 결정할 일이 아무것도 없다는 사실을 알게 되었다. 30년 동안 테이프만 잘랐다.",
 "أول رئيس لجمهورية سوفاركا. دشّن القصر، ثم اكتشف أنه لا شيء فيه يستدعي قرارًا. قضى ثلاثين عامًا يقصّ الأشرطة.",
 "Primeiro Presidente da República de Sovarka. Inaugurou o Palácio e depois descobriu que não havia nada a decidir ali. Passou trinta anos cortando fitas.",
 "Erster Präsident der Republik Sowarka. Weihte den Palast ein und stellte dann fest, dass es dort nichts zu entscheiden gab. Schnitt dreißig Jahre lang Bänder durch."]},
"Camarade Taras Sergueïevitch Belov":{n:["Comrade Taras Sergeyevich Belov","Camarada Taras Serguéievich Belov","塔拉斯·謝爾蓋耶維奇·別洛夫同志","Товарищ Тарас Сергеевич Белов","타라스 세르게예비치 벨로프 동지","الرفيق تاراس سيرغيفيتش بيلوف","Camarada Taras Sergueievitch Belov","Genosse Taras Sergejewitsch Below"],b:[
 "The only President to have signed a decree: the one setting tea time at the Palace. It is still in force.",
 "Único Presidente que firmó un decreto: el que fijaba la hora del té en el Palacio. Sigue vigente.",
 "唯一簽署過法令的總統：規定總統宮下午茶時間的那道法令。至今仍然有效。",
 "Единственный Президент, подписавший указ: о времени чаепития во Дворце. Он действует до сих пор.",
 "법령에 서명한 유일한 대통령. 궁전의 차 마시는 시간을 정한 법령이었다. 지금도 유효하다.",
 "الرئيس الوحيد الذي وقّع مرسومًا: مرسوم تحديد موعد الشاي في القصر. وما زال ساريًا.",
 "Único Presidente a ter assinado um decreto: o que fixava a hora do chá no Palácio. Ainda está em vigor.",
 "Einziger Präsident, der je ein Dekret unterzeichnet hat: das über die Teestunde im Palast. Es gilt bis heute."]},
"Camarade Boris Nikolaïevitch Gromov":{n:["Comrade Boris Nikolayevich Gromov","Camarada Borís Nikoláievich Grómov","鮑里斯·尼古拉耶維奇·格羅莫夫同志","Товарищ Борис Николаевич Громов","보리스 니콜라예비치 그로모프 동지","الرفيق بوريس نيكولايفيتش غروموف","Camarada Boris Nikolaievitch Gromov","Genosse Boris Nikolajewitsch Gromow"],b:[
 "Re-elected seven times without ever running. The Party had not thought it necessary to tell him.",
 "Reelegido siete veces sin haberse presentado. El Partido no había creído necesario avisarle.",
 "未曾參選卻連任七次。黨認為沒必要通知他。",
 "Переизбирался семь раз, ни разу не выдвинувшись. Партия не сочла нужным его предупредить.",
 "출마한 적도 없이 일곱 번 재선되었다. 당은 그에게 알릴 필요를 느끼지 못했다.",
 "أُعيد انتخابه سبع مرات من دون أن يترشّح. ولم يرَ الحزب ضرورة لإبلاغه.",
 "Reeleito sete vezes sem ter se candidatado. O Partido não achou necessário avisá-lo.",
 "Siebenmal wiedergewählt, ohne je kandidiert zu haben. Die Partei hielt es nicht für nötig, ihm Bescheid zu sagen."]},
"Vladimir Petrovitch Lebedev":{n:["Vladimir Petrovich Lebedev","Vladímir Petróvich Lébedev","弗拉基米爾·彼得羅維奇·列別傑夫","Владимир Петрович Лебедев","블라디미르 페트로비치 레베데프","فلاديمير بتروفيتش ليبيديف","Vladimir Petrovitch Lebedev","Wladimir Petrowitsch Lebedew"],b:[
 "A troubling resemblance to Comrade Gromov earned him the people's affection. Tried to summon the People's Council to his apartments. The Council replied by letter, in triplicate, that it was busy.",
 "Un parecido inquietante con el camarada Grómov le valió el cariño del pueblo. Intentó convocar al Consejo del Pueblo en sus aposentos. El Consejo respondió por carta, por triplicado, que estaba ocupado.",
 "他與格羅莫夫同志長得驚人地相似，因而深受人民愛戴。他曾試圖把人民委員會召到自己的寓所開會。委員會以一式三份的信函回覆：正在忙。",
 "Поразительное сходство с товарищем Громовым снискало ему любовь народа. Пытался созвать Народный совет в своих покоях. Совет ответил письмом в трёх экземплярах, что занят.",
 "그로모프 동지와 묘하게 닮은 덕에 인민의 사랑을 받았다. 인민 회의를 자신의 거처로 소집하려 했으나, 회의는 바쁘다는 답장을 세 부 작성해 보냈다.",
 "شبهٌ مثير للحيرة بالرفيق غروموف أكسبه محبة الشعب. حاول دعوة مجلس الشعب إلى جناحه. فردّ المجلس برسالة من ثلاث نسخ بأنه مشغول.",
 "Uma semelhança perturbadora com o camarada Gromov lhe valeu o afeto do povo. Tentou convocar o Conselho do Povo para seus aposentos. O Conselho respondeu por carta, em três vias, que estava ocupado.",
 "Eine verblüffende Ähnlichkeit mit Genosse Gromow brachte ihm die Zuneigung des Volkes ein. Versuchte, den Volksrat in seine Gemächer einzuberufen. Der Rat antwortete schriftlich, in dreifacher Ausfertigung, er sei beschäftigt."]},
"Camarade Guennadi Andreïevitch Sokolov":{n:["Comrade Gennadi Andreyevich Sokolov","Camarada Guennadi Andréievich Sokolov","根納季·安德烈耶維奇·索科洛夫同志","Товарищ Геннадий Андреевич Соколов","겐나디 안드레예비치 소콜로프 동지","الرفيق غينادي أندرييفيتش سوكولوف","Camarada Guennadi Andreievitch Sokolov","Genosse Gennadi Andrejewitsch Sokolow"],b:[
 "The same jaw, the same gaze as Comrades Gromov and Lebedev: a sign of admirable continuity. No family ties, of course. Had the silver samovar installed in the dining room. His term is considered the most useful in the Palace's history.",
 "La misma mandíbula, la misma mirada que los camaradas Grómov y Lébedev: señal de una admirable continuidad. Sin ningún parentesco, por supuesto. Hizo instalar el samovar de plata del comedor. Su mandato se considera el más útil de la historia del Palacio.",
 "與格羅莫夫、列別傑夫兩位同志如出一轍的下巴與眼神：令人讚嘆的延續性。當然，毫無親屬關係。他在餐廳裡安置了那座銀茶炊。他的任期被視為總統宮史上最有用的一任。",
 "Та же челюсть, тот же взгляд, что у товарищей Громова и Лебедева: знак восхитительной преемственности. Никакого родства, разумеется. Велел установить серебряный самовар в обеденном зале. Его срок считается самым полезным в истории Дворца.",
 "그로모프 동지, 레베데프 동지와 똑같은 턱, 똑같은 눈빛. 놀라운 연속성의 징표다. 물론 혈연관계는 전혀 없다. 식당에 은 사모바르를 들여놓았다. 그의 임기는 궁전 역사상 가장 유익했던 임기로 평가받는다.",
 "الفكّ نفسه والنظرة نفسها لدى الرفيقين غروموف وليبيديف: علامة على استمرارية مثيرة للإعجاب. لا صلة قرابة بالطبع. أمر بوضع السماور الفضي في قاعة الطعام. وتُعدّ ولايته الأنفع في تاريخ القصر.",
 "O mesmo queixo, o mesmo olhar dos camaradas Gromov e Lebedev: sinal de admirável continuidade. Nenhum parentesco, é claro. Mandou instalar o samovar de prata do salão de refeições. Seu mandato é considerado o mais útil da história do Palácio.",
 "Derselbe Kiefer, derselbe Blick wie bei den Genossen Gromow und Lebedew: Zeichen einer bewundernswerten Kontinuität. Keinerlei Verwandtschaft, versteht sich. Ließ den silbernen Samowar im Speisesaal aufstellen. Seine Amtszeit gilt als die nützlichste in der Geschichte des Palastes."]}
};
function langue(){
  const lang=(global.RP_I18N_GAME_ENABLED===true&&global.RPPlateauI18n?.language?.())||'fr';
  return LANGUES.indexOf(lang);
}
// Copie traduite d'une fiche ({nom, dates, bio}) ; la fiche d'origine sinon.
function fiche(p){
  const i=langue();
  const t=p&&F[p.nom];
  if(i<0||!t)return p;
  return {nom:(t.n&&t.n[i])||p.nom,dates:(t.d&&t.d[i])||p.dates,bio:(t.b&&t.b[i])||p.bio};
}
function ui(cle,fr){
  const i=langue();
  return (i>=0&&UI[cle]&&UI[cle][i])||fr;
}
global.RPMuseeSovarkaI18n=Object.freeze({fiche,ui,langues:Object.freeze(LANGUES.slice()),noms:Object.freeze(Object.keys(F))});
})(typeof window!=='undefined'?window:globalThis);
