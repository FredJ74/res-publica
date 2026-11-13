/* Musée national de Républia : présentation des douze premières biographies, noms et dates inchangés.
 * Aucun changement aux figures spécifiques à Sovarka ni aux autres musées de province.
 */
(function(global){'use strict';
const words={
  "fr": {
    "title": "Personnalités",
    "empty": "Rien à consulter ici pour l'instant.",
    "back": "Retour à la liste",
    "bios": {
      "Antoine Ferréol": "Premier ministre, artisan de la réforme fiscale de 1934.",
      "Solange Vernier": "Première femme ministre de Républia, portefeuille de l'Intérieur.",
      "Gustave Ombreval": "Député historique, 40 ans de mandat ininterrompu.",
      "Blaise Corentin": "Ministre des Affaires étrangères, artisan du traité avec El Estado.",
      "Professeure Adèle Rocheval": "Fondatrice de l'Université de Républia.",
      "Jean-Baptiste Lherminier": "Philosophe, penseur de la doctrine républicaine.",
      "Marthe Aubignac": "Journaliste d'investigation et lanceuse d'alerte, plusieurs affaires d'État révélées.",
      "Thierry Munster": "Découvreur de la maladie dégénérative de l'ongle, inventeur du vernis thérapeutique.",
      "Cardinal Théodore Passerand": "Figure religieuse la plus influente du siècle dernier.",
      "Lucien Farge": "Fondateur du premier grand syndicat ouvrier du pays.",
      "Grande Maîtresse Odile Vasseur": "Dirigeante historique d'une loge influente.",
      "Patrick Lemaître": "Chef des supporters de l'Union Cheminote de Montrouge, organisateur de la grande manifestation de 3 semaines contre le maire de Montrouge en 1993."
    }
  },
  "en": {
    "title": "Notable figures",
    "empty": "Nothing to view here at the moment.",
    "back": "Back to the list",
    "bios": {
      "Antoine Ferréol": "Prime Minister and architect of the 1934 tax reform.",
      "Solange Vernier": "Républia's first female minister, in charge of the Interior.",
      "Gustave Ombreval": "Long-serving member of parliament with 40 uninterrupted years in office.",
      "Blaise Corentin": "Foreign Minister and architect of the treaty with El Estado.",
      "Professeure Adèle Rocheval": "Founder of the University of Républia.",
      "Jean-Baptiste Lherminier": "Philosopher and leading thinker of republican doctrine.",
      "Marthe Aubignac": "Investigative journalist and whistleblower who uncovered several affairs of state.",
      "Thierry Munster": "Discovered degenerative nail disease and invented therapeutic nail varnish.",
      "Cardinal Théodore Passerand": "The most influential religious figure of the previous century.",
      "Lucien Farge": "Founder of the country's first major workers' union.",
      "Grande Maîtresse Odile Vasseur": "Historic leader of an influential lodge.",
      "Patrick Lemaître": "Leader of Union Cheminote de Montrouge supporters, who organised a three-week protest against Montrouge's mayor in 1993."
    }
  },
  "es": {
    "title": "Personalidades",
    "empty": "No hay nada que consultar aquí por ahora.",
    "back": "Volver a la lista",
    "bios": {
      "Antoine Ferréol": "Primer ministro y artífice de la reforma fiscal de 1934.",
      "Solange Vernier": "Primera mujer ministra de Républia, al frente de Interior.",
      "Gustave Ombreval": "Diputado histórico, con 40 años de mandato ininterrumpido.",
      "Blaise Corentin": "Ministro de Asuntos Exteriores y artífice del tratado con El Estado.",
      "Professeure Adèle Rocheval": "Fundadora de la Universidad de Républia.",
      "Jean-Baptiste Lherminier": "Filósofo y pensador de la doctrina republicana.",
      "Marthe Aubignac": "Periodista de investigación y denunciante que destapó varios asuntos de Estado.",
      "Thierry Munster": "Descubrió la enfermedad degenerativa de las uñas e inventó el esmalte terapéutico.",
      "Cardinal Théodore Passerand": "La figura religiosa más influyente del siglo pasado.",
      "Lucien Farge": "Fundador del primer gran sindicato obrero del país.",
      "Grande Maîtresse Odile Vasseur": "Dirigente histórica de una logia influyente.",
      "Patrick Lemaître": "Líder de la afición de Union Cheminote de Montrouge; organizó en 1993 una protesta de tres semanas contra el alcalde de Montrouge."
    }
  },
  "zh-TW": {
    "title": "知名人物",
    "empty": "目前沒有可查閱的內容。",
    "back": "返回列表",
    "bios": {
      "Antoine Ferréol": "曾任總理，是 1934 年稅制改革的推動者。",
      "Solange Vernier": "Républia 首位女性部長，主管內政。",
      "Gustave Ombreval": "資深國會議員，連續任職四十年。",
      "Blaise Corentin": "外交部長，也是與 El Estado 締約的主要推手。",
      "Professeure Adèle Rocheval": "Républia 大學創辦人。",
      "Jean-Baptiste Lherminier": "哲學家，共和主義學說的重要思想家。",
      "Marthe Aubignac": "調查記者兼吹哨者，揭露多起國家醜聞。",
      "Thierry Munster": "發現退化性指甲疾病，並發明治療用指甲油。",
      "Cardinal Théodore Passerand": "上個世紀最具影響力的宗教人物。",
      "Lucien Farge": "創立國內第一個大型工人工會。",
      "Grande Maîtresse Odile Vasseur": "一個頗具影響力的秘密會社的歷史領袖。",
      "Patrick Lemaître": "Union Cheminote de Montrouge 球迷領袖，於 1993 年組織長達三週、反對 Montrouge 市長的大型示威。"
    }
  },
  "ru": {
    "title": "Выдающиеся личности",
    "empty": "Пока здесь нечего смотреть.",
    "back": "Назад к списку",
    "bios": {
      "Antoine Ferréol": "Премьер-министр, автор налоговой реформы 1934 года.",
      "Solange Vernier": "Первая женщина-министр в Républia, возглавляла Министерство внутренних дел.",
      "Gustave Ombreval": "Исторический депутат, непрерывно занимавший свой пост 40 лет.",
      "Blaise Corentin": "Министр иностранных дел, подготовивший договор с El Estado.",
      "Professeure Adèle Rocheval": "Основательница Университета Républia.",
      "Jean-Baptiste Lherminier": "Философ, теоретик республиканской доктрины.",
      "Marthe Aubignac": "Журналистка-расследователь и разоблачительница нескольких государственных скандалов.",
      "Thierry Munster": "Открыл дегенеративное заболевание ногтей и изобрёл лечебный лак.",
      "Cardinal Théodore Passerand": "Самый влиятельный религиозный деятель прошлого века.",
      "Lucien Farge": "Основатель первого крупного рабочего профсоюза страны.",
      "Grande Maîtresse Odile Vasseur": "Многолетняя руководительница влиятельной ложи.",
      "Patrick Lemaître": "Лидер болельщиков Union Cheminote de Montrouge, организовавший трёхнедельную акцию протеста против мэра Montrouge в 1993 году."
    }
  },
  "ko": {
    "title": "주요 인물",
    "empty": "현재 이곳에서 볼 자료가 없습니다.",
    "back": "목록으로 돌아가기",
    "bios": {
      "Antoine Ferréol": "총리를 지냈으며 1934년 세제 개혁을 주도했다.",
      "Solange Vernier": "Républia 최초의 여성 장관으로 내무부를 맡았다.",
      "Gustave Ombreval": "40년 동안 연속으로 재임한 역사적인 국회의원.",
      "Blaise Corentin": "외무장관으로 El Estado와의 조약 체결을 이끌었다.",
      "Professeure Adèle Rocheval": "Républia 대학교 설립자.",
      "Jean-Baptiste Lherminier": "공화주의 이론의 사상적 기반을 세운 철학자.",
      "Marthe Aubignac": "여러 국가적 비리를 폭로한 탐사보도 기자이자 내부고발자.",
      "Thierry Munster": "퇴행성 손톱 질환을 발견하고 치료용 매니큐어를 발명했다.",
      "Cardinal Théodore Passerand": "지난 세기 가장 영향력 있는 종교 지도자.",
      "Lucien Farge": "국내 최초의 대규모 노동조합 설립자.",
      "Grande Maîtresse Odile Vasseur": "영향력 있는 비밀 결사단의 역사적인 지도자.",
      "Patrick Lemaître": "Union Cheminote de Montrouge 응원단장으로, 1993년 Montrouge 시장에 반대하는 3주간의 대규모 시위를 조직했다."
    }
  },
  "ar": {
    "title": "شخصيات بارزة",
    "empty": "لا يوجد ما يمكن الاطلاع عليه هنا حاليًا.",
    "back": "العودة إلى القائمة",
    "bios": {
      "Antoine Ferréol": "رئيس وزراء وصاحب إصلاح الضرائب لعام 1934.",
      "Solange Vernier": "أول امرأة تتولى منصب وزيرة في Républia، وكانت مسؤولة عن الداخلية.",
      "Gustave Ombreval": "نائب تاريخي شغل مقعده أربعين عامًا دون انقطاع.",
      "Blaise Corentin": "وزير الخارجية وصاحب الدور الرئيسي في المعاهدة مع El Estado.",
      "Professeure Adèle Rocheval": "مؤسسة جامعة Républia.",
      "Jean-Baptiste Lherminier": "فيلسوف ومنظّر للفكر الجمهوري.",
      "Marthe Aubignac": "صحفية تحقيقات ومبلّغة كشفت عدة فضائح تتعلق بالدولة.",
      "Thierry Munster": "اكتشف مرضًا تنكسيًا يصيب الأظافر واخترع طلاء أظافر علاجيًا.",
      "Cardinal Théodore Passerand": "الشخصية الدينية الأكثر نفوذًا في القرن الماضي.",
      "Lucien Farge": "مؤسس أول نقابة عمالية كبيرة في البلاد.",
      "Grande Maîtresse Odile Vasseur": "زعيمة تاريخية لمحفل ذي نفوذ.",
      "Patrick Lemaître": "زعيم مشجعي Union Cheminote de Montrouge، ونظّم مظاهرة كبيرة استمرت ثلاثة أسابيع ضد عمدة Montrouge عام 1993."
    }
  },
  "pt-BR": {
    "title": "Personalidades",
    "empty": "Não há nada para consultar aqui no momento.",
    "back": "Voltar à lista",
    "bios": {
      "Antoine Ferréol": "Primeiro-ministro e responsável pela reforma tributária de 1934.",
      "Solange Vernier": "Primeira mulher ministra de Républia, responsável pelo Interior.",
      "Gustave Ombreval": "Deputado histórico, com 40 anos de mandato ininterrupto.",
      "Blaise Corentin": "Ministro das Relações Exteriores e responsável pelo tratado com El Estado.",
      "Professeure Adèle Rocheval": "Fundadora da Universidade de Républia.",
      "Jean-Baptiste Lherminier": "Filósofo e pensador da doutrina republicana.",
      "Marthe Aubignac": "Jornalista investigativa e denunciante que revelou vários escândalos de Estado.",
      "Thierry Munster": "Descobriu uma doença degenerativa das unhas e inventou o esmalte terapêutico.",
      "Cardinal Théodore Passerand": "A figura religiosa mais influente do século passado.",
      "Lucien Farge": "Fundador do primeiro grande sindicato de trabalhadores do país.",
      "Grande Maîtresse Odile Vasseur": "Líder histórica de uma loja influente.",
      "Patrick Lemaître": "Líder da torcida do Union Cheminote de Montrouge, organizou em 1993 um protesto de três semanas contra o prefeito de Montrouge."
    }
  },
  "de": {
    "title": "Persönlichkeiten",
    "empty": "Hier gibt es derzeit nichts zu sehen.",
    "back": "Zurück zur Liste",
    "bios": {
      "Antoine Ferréol": "Premierminister und Wegbereiter der Steuerreform von 1934.",
      "Solange Vernier": "Erste Ministerin von Républia, zuständig für das Innenressort.",
      "Gustave Ombreval": "Historischer Abgeordneter mit 40 Jahren ununterbrochener Amtszeit.",
      "Blaise Corentin": "Außenminister und Wegbereiter des Vertrags mit El Estado.",
      "Professeure Adèle Rocheval": "Gründerin der Universität von Républia.",
      "Jean-Baptiste Lherminier": "Philosoph und Vordenker der republikanischen Lehre.",
      "Marthe Aubignac": "Investigativjournalistin und Whistleblowerin, die mehrere Staatsaffären aufdeckte.",
      "Thierry Munster": "Entdeckte eine degenerative Nagelerkrankung und erfand einen therapeutischen Nagellack.",
      "Cardinal Théodore Passerand": "Einflussreichste religiöse Persönlichkeit des vergangenen Jahrhunderts.",
      "Lucien Farge": "Gründer der ersten großen Arbeitergewerkschaft des Landes.",
      "Grande Maîtresse Odile Vasseur": "Langjährige Leiterin einer einflussreichen Loge.",
      "Patrick Lemaître": "Anführer der Fans von Union Cheminote de Montrouge, organisierte 1993 einen dreiwöchigen Protest gegen den Bürgermeister von Montrouge."
    }
  }
};
const resources=global.RP_I18N_RESOURCES;
if(resources)for(const [locale,values] of Object.entries(words)){
 const target=resources[locale]?.translation;
 if(target)target.museumNationalBios=values;
}
function lang(){
 return global.RP_I18N_GAME_ENABLED===true?(global.RPPlateauI18n?.language?.()||'fr'):'fr';
}
function text(key,original){
 const l=lang();return l==='fr'?String(original):words[l]?.[key]||String(original);
}
function bio(nom,original){
 const l=lang();return l==='fr'?String(original):words[l]?.bios?.[nom]||String(original);
}
global.RPMuseumNationalBiosI18n=Object.freeze({words,text,bio});
})(window);
