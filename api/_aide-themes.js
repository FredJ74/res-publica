// Documentation pédagogique HRP : synthèse des rubriques de REGLES
// (plateau-personnage.js, « Tutoriel », « Plateau », « Interactions », etc.)
// Ne pas recopier les barèmes chiffrés, susceptibles de changer indépendamment.
// Cette base est conçue pour fournir des repères, pas une deuxième source de règles.
export const AIDE_THEMES = Object.freeze({
  demarrage:`LE JEU : Human Gambit / Res Publica est un monde partagé et un bac à sable social. Le personnage choisit librement ses activités et ses ambitions. Aucun objectif obligatoire ne définit ce qu'est une réussite. Pour démarrer : explorer la ville, entrer dans un bâtiment, discuter avec des joueurs humains (PJ), choisir des activités et créer un réseau. La politique, le commerce, les métiers, le sport, les enquêtes et les rivalités se croisent. La question importante est : quel personnage veux-tu devenir ?`,
  pa:`POINTS D'ACTION : PA signifie points d'action. Ils servent à accomplir certains ordres ; leur coût figure sur les commandes. D'autres ordres sont gratuits. Le sommeil (une fois par journée réelle) restaure les PA et conditionne le salaire journalier ; on ne rattrape pas une journée manquée. Les PA ne sont pas les statistiques INT, CHA, VOL, PER, DUP ou ENT. Ne jamais fournir de plafond ou quantité universelle à partir d'une documentation non vérifiée : les états et bonus varient.`,
  exploration:`SE DÉPLACER : l'interface présente des rues, bâtiments, pièces et ordres disponibles. Le Plan sert à se repérer. On entre dans un bâtiment, puis dans une pièce, puis on choisit une action. Les bâtiments peuvent avoir des conditions d'accès ; un bouton inaccessible ou un refus doit être expliqué selon son message, jamais par une raison inventée. Un lieu peut être lié à une activité : hôtel pour dormir, mairie pour la vie locale, entreprises pour produire ou commercer, centre de transport pour voyager.`,
  pjpnj:`PERSONNAGES : PJ = personnage d'un joueur humain ; PNJ = personnage non-joueur. Les deux peuvent être abordés, mais leur statut n'est pas interchangeable. Les PNJ référents expliquent leur propre domaine ; le conseiller Aide, lui, répond HRP et ne prend jamais de décision dans le monde du jeu. Certains PNJ disposent de dialogues IA. Une affirmation faite en conversation ne crée jamais à elle seule un objet ou une transaction. Seuls les ordres effectivement confirmés peuvent avoir des conséquences.`,
  social:`RELATIONS : le bouton Messages/Forums permet de participer aux échanges publics et privés selon leurs droits. Il existe des forums locaux, nationaux et internationaux, des espaces de presse, de sport et des groupes ou organisations. On peut échanger des messages, ajouter des contacts, discuter en personne, rejoindre une organisation et agir collectivement. La vie sociale entre joueurs est au coeur de l'expérience ; les autres joueurs ne sont pas des figurants.`,
  economie:`ARGENT ET ÉCONOMIE : l'argent du personnage peut être réparti entre liquide et banque. On peut chercher un emploi, percevoir son salaire selon les règles du sommeil, ouvrir ou travailler dans des commerces, acheter, vendre, produire, transporter des marchandises et créer des projets. Ressources et prix varient selon les empires ; les taxes et les pénuries créent des opportunités. Ne pas promettre un revenu, un coût ou une garantie de succès sans le barème réel de l'ordre.`,
  politique:`POLITIQUE : les joueurs peuvent participer à des partis, campagnes et élections, exercer des mandats, publier des messages, nouer des alliances et défendre des intérêts économiques ou sociaux. Les postes et pouvoirs sont liés à des droits et à des procédures ; aucune nomination, candidature ou décision ne se réalise par une simple discussion avec le conseiller HRP. Consulter les rubriques Politique, Élections et les référents concernés pour les détails.`,
  justice:`RISQUES ET JUSTICE : certaines actions sont illégales et peuvent mener à la détection, à des sanctions, à une arrestation, à des combats et à des procédures judiciaires. Les ordres et leurs risques sont validés par le serveur. Ne pas déduire une probabilité ou une sanction précise à partir du monde réel. Le conseiller n'aide pas à exécuter une action ni à cacher des preuves : il explique le système de jeu.`,
  sport:`SPORT : le football comporte des clubs, matches, supporters, fonctions et résultats. Les matches peuvent se suivre dans les stades et constituent un rendez-vous collectif. Les règles de présence, de temps réel, de soutien et d'ordres sportifs dépendent des fonctions et événements. Pour les valeurs exactes, renvoyer vers l'onglet Football ou le référent concerné.`,
  religion:`RELIGIONS FICTIVES : chaque empire possède sa religion parodique propre : Papyrusisme en Republia, Tractorisme en Sovarka, Cocaïsme en El Estado et Loukoumisme en Al Khalija. Elles peuvent influencer les relations sociales et le pouvoir. Ne pas présenter ces religions comme réelles ; consulter la rubrique Religions pour les ordres et effets précis.`
});
// Racines multilingues des mêmes thèmes canoniques, pas de corpus parallèle.
// Ne pas entourer les écritures non latines de \b : JavaScript y utilise les
// frontières ASCII, même avec /u. Les questions courantes priment sur le passé.
const DEPISTAGE=[
  ['pa', /(?:\b(?:pa|ap)\b|points? d.action|action points?|actionspunkte|aktionspunkte|puntos? de acci[oó]n|pontos? de a[cç][aã]o|очки? действ|очков действ|행동력|행동 포인트|نقاط العمل|نقاط الحركة|行動點數|行動點|dormir|sommeil|sleep|schlaf|dormid|sueño|сон|спать|수면|잠|النوم|睡眠|睡覺)/iu],
  ['exploration', /(?:plan|carte|rue|navig|déplac|voyag|transport|comment (?:aller|entrer|sortir)|where|map|travel|calle|viajar|mapa|rua|reisen|karte|bewegen|улиц|карт[аеуы]|путешеств|перемещ|地圖|移動|旅行|이동|지도|여행|خريطة|التنقل|السفر)/iu],
  ['social', /(?:joueurs|\bpjs?\b|amis|rencontr|contact|forum|message|social|relations?|friend|players?|jugador|amigo|mensaj|jogador|mensag|spieler|freund|nachricht|игрок|друз|сообщен|форум|朋友|玩家|訊息|論壇|플레이어|친구|메시지|게시판|اللاعب|الأصدقاء|رسائل|منتدى)/iu],
  ['pjpnj', /(?:\bpnj\b|\bnpc\b|personnage|dialogue|référent|objet|inventory|inventaire|non.joueur|inventario|personaje|personagem|inventar|figur|персонаж|инвентар|角色|背包|物品|캐릭터|인벤토리|الشخصية|المخزون)/iu],
  ['economie', /(?:entrepris|business|argent|banque|salaire|travail|emploi|acheter|vendre|commerce|prix|stock|matièr|entrepreneur|money|job|work|buy|sell|dinero|banco|trabaj|comprar|vender|dinheiro|sal[aá]rio|emprego|geld|bank|arbeit|kaufen|verkaufen|деньг|банк|работ|зарплат|купить|продать|公司|銀行|金錢|工作|買|賣|직업|은행|돈|구매|판매|عمل|مال|مصرف|بنك|شراء|بيع)/iu],
  ['politique', /(?:politique|élection|gouvern|mair|parti|ministre|présiden|déput|vote|election|government|politics|elecci|pol[ií]tic|eleiç|wahl|regierung|partei|выбор|политик|правитель|選舉|政治|선거|정치|انتخاب|سياسة|حكومة)/iu],
  ['justice', /(?:police|crime|justice|procès|prison|arrest|illégal|voler|combat|délinquan|criminal|pol[ií]c|justi[cç]|pris[oóã]|polizei|gef[aä]ngnis|kampf|полици|суд|тюрьм|бой|警察|司法|監獄|戰鬥|경찰|법원|감옥|전투|قانون|شرطة|سجن|قتال)/iu],
  ['sport', /(?:football|foot|stade|match|sport|supporter|jouer au ballon|soccer|basket|f[uú]tbol|futebol|fußball|футбол|стадион|足球|體育|축구|스포츠|كرة القدم|رياضة)/iu],
  ['religion', /(?:religi[oó]n|tractori|papyrusi|cocaïs|loukoumi|piété|temple|prière|religi[aã]o|религи|храм|宗教|祈禱|종교|기도|دين|صلاة)/iu]
];
export function contexteAideQuestion(question,historique=[]) {
  const dernier=String(question||'').normalize('NFKC');
  const passes=[dernier,...historique.filter(x=>x.role==='user').slice(-2).reverse().map(x=>String(x.content||'').normalize('NFKC'))];
  const choisis=[];
  for (const texte of passes) {
    for (const [key,rx] of DEPISTAGE) if (!choisis.includes(key) && rx.test(texte)) choisis.push(key);
    if (choisis.length>=3) break;
  }
  return [AIDE_THEMES.demarrage,...choisis.slice(0,3).map(key=>AIDE_THEMES[key])].join('\n\n');
}
