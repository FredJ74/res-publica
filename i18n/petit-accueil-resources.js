/* Premier dialogue fixe de la quête d'accueil.
 * Texte présenté uniquement, sans changement de l'étape ou des commandes.
 * Les traductions restent des brouillons éditoriaux avant autorisation publique.
 */
(function(global){
 'use strict';
 const resource=global.RP_I18N_RESOURCES;
 if(!resource)return;
 const labels={
  "fr": {
    "intro": "Ah, un petit nouveau ! Vous allez avoir besoin d'aide pour découvrir la ville, j'imagine. Ça tombe bien, on a un jeune stagiaire ici qu'on ne sait pas comment occuper. En plus il ne sait pas faire un bon café, mais par contre, il est originaire de la ville. En fait... (en parlant tout bas) c'est le neveu du Maire, on n'a pas eu d'autre choix que de le prendre... Jérémy ! Viens par ici, on a une mission pour toi ! Tu vas accompagner {{player}} dans la ville. (se tournant vers vous) Enfin si vous êtes d'accord bien sûr. Vous voulez l'aide de Jérémy ?",
    "accept": "Oui, j'accepte l'aide de Jérémy",
    "decline": "Non merci"
  },
  "en": {
    "intro": "Ah, a newcomer! I imagine you'll need help getting to know the city. Just as well: we have a young intern here and never know what to do with him. He can't even make a decent coffee, but he was born here. Actually... (whispering) he's the Mayor's nephew. We didn't have much choice about hiring him... Jérémy! Come here, we've got a mission for you! You're going to show {{player}} around town. (turning back to you) If you agree, of course. Would you like Jérémy's help?",
    "accept": "Yes, I'd like Jérémy's help",
    "decline": "No, thank you"
  },
  "es": {
    "intro": "¡Ah, alguien nuevo! Imagino que necesitará ayuda para conocer la ciudad. Por suerte, tenemos aquí a un joven becario al que nunca sabemos qué encargarle. Ni siquiera prepara bien el café, aunque es de aquí. En realidad... (bajando la voz) es el sobrino del alcalde; no tuvimos más remedio que contratarlo... ¡Jérémy! ¡Ven, tenemos una misión para ti! Acompañarás a {{player}} por la ciudad. (volviéndose hacia usted) Siempre que esté de acuerdo, claro. ¿Quiere que Jérémy le ayude?",
    "accept": "Sí, acepto la ayuda de Jérémy",
    "decline": "No, gracias"
  },
  "zh-TW": {
    "intro": "啊，是新來的！我想你需要有人帶你認識這座城市。正巧，我們這裡有位年輕實習生，總不知道該派他做什麼。他連咖啡都煮不好，不過倒是在本地長大的。其實……（壓低聲音）他是市長的外甥，我們也沒辦法不錄用他……Jérémy！過來，有任務給你！你要陪 {{player}} 熟悉這座城市。（轉向你）當然，得先徵得你的同意。你願意讓 Jérémy 幫忙嗎？",
    "accept": "好，我接受 Jérémy 的幫助",
    "decline": "不用了，謝謝"
  },
  "ru": {
    "intro": "А, новенький! Полагаю, вам понадобится помощь, чтобы освоиться в городе. Кстати, у нас тут молодой стажёр, и мы никак не придумаем ему занятие. Даже кофе нормально сварить не умеет, зато сам местный. Вообще-то... (понизив голос) он племянник мэра, так что взять его пришлось... Jérémy! Иди сюда, у нас для тебя поручение! Покажешь {{player}} наш город. (оборачиваясь к вам) Разумеется, если вы согласны. Хотите, чтобы Jérémy помог вам?",
    "accept": "Да, я согласен на помощь Jérémy",
    "decline": "Нет, спасибо"
  },
  "ko": {
    "intro": "아, 새로 오셨군요! 도시를 알아보려면 도움이 필요하시겠죠. 마침 여기 뭘 시켜야 할지 모르는 젊은 인턴이 있습니다. 커피도 제대로 못 타지만 이 도시 출신이거든요. 사실은… (목소리를 낮추며) 시장의 조카여서 채용할 수밖에 없었죠… Jérémy! 이리 와! 맡길 일이 있다! {{player}}에게 도시를 안내해 줘. (당신에게 돌아서며) 물론 동의하신다면요. Jérémy의 도움을 받으시겠습니까?",
    "accept": "네, Jérémy의 도움을 받을게요",
    "decline": "아니요, 괜찮습니다"
  },
  "ar": {
    "intro": "آه، وافد جديد! أظن أنك ستحتاج إلى مساعدة لاكتشاف المدينة. لحسن الحظ، لدينا متدرب شاب لا نعرف بماذا نشغله. حتى القهوة لا يجيد إعدادها، لكنه من أبناء المدينة. في الحقيقة... (بصوت منخفض) إنه ابن أخت العمدة، ولم يكن أمامنا خيار سوى تعيينه... Jérémy! تعال إلى هنا، لدينا مهمة لك! سترافق {{player}} للتعرّف إلى المدينة. (يلتفت إليك) طبعًا، إن وافقت. هل تريد مساعدة Jérémy؟",
    "accept": "نعم، أقبل مساعدة Jérémy",
    "decline": "لا، شكرًا"
  },
  "pt-BR": {
    "intro": "Ah, alguém novo! Imagino que você precise de ajuda para conhecer a cidade. Ainda bem: temos um jovem estagiário aqui e nunca sabemos o que pedir a ele. Nem um bom café ele consegue fazer, mas nasceu na cidade. Na verdade... (baixando a voz) ele é sobrinho do prefeito; não tivemos escolha a não ser contratá-lo... Jérémy! Venha cá, temos uma missão para você! Você vai mostrar a cidade a {{player}}. (voltando-se para você) Se concordar, é claro. Quer a ajuda de Jérémy?",
    "accept": "Sim, aceito a ajuda de Jérémy",
    "decline": "Não, obrigado"
  },
  "de": {
    "intro": "Ah, ein Neuankömmling! Sie brauchen bestimmt Hilfe, um die Stadt kennenzulernen. Das trifft sich gut: Wir haben hier einen jungen Praktikanten, mit dem wir nichts anzufangen wissen. Nicht einmal guten Kaffee kann er kochen, aber er stammt von hier. Eigentlich... (leise) ist er der Neffe des Bürgermeisters; wir hatten keine andere Wahl, als ihn einzustellen... Jérémy! Komm her, wir haben eine Aufgabe für dich! Du wirst {{player}} durch die Stadt führen. (wendet sich wieder an Sie) Natürlich nur, wenn Sie einverstanden sind. Möchten Sie Jérémy um Hilfe bitten?",
    "accept": "Ja, ich nehme Jérémys Hilfe an",
    "decline": "Nein, danke"
  }
};
 for(const [locale,texts] of Object.entries(labels))
  if(resource[locale]?.translation)resource[locale].translation.petitAccueil={...texts};
 const keys=Object.keys(labels.fr);
 function translated(key,defaultValue,variables={}){
  if(!keys.includes(key))return defaultValue;
  const locale=global.RPPlateauI18n?.language?.()||'fr';
  const text=global.i18next?.t?.('petitAccueil.'+key,{lng:locale,...variables,
    defaultValue:defaultValue||labels.fr[key]});
  if(typeof text!=='string'||!text.trim())return defaultValue||labels.fr[key];
  return text;
 }
 global.RPPetitAccueilI18n=Object.freeze({translated});
})(window);
