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
