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
const DEPISTAGE=[
  ['pa',/\b(?:pa|ap|action points?|actionspunkte|punkte d.action|points? d.action|dormir|sommeil|sleep|rest|action point|행동력|نقاط العمل|行動點數)\b/iu],
  ['exploration',/(?:plan|carte|rue|navig|déplac|déplacement|voyag|transport|comment (?:aller|entrer|sortir)|where|map|travel|navigate|地圖|이동|خريطة)/iu],
  ['social',/(?:joueurs|pjs?\b|amis|rencontr|contact|forum|message|social|relations?|friend|players?|朋友|플레이어|اللاعبين)/iu],
  ['pjpnj',/(?:pnj|npc|personnage|dialogue|référent|objet|inventory|inventaire|non.joueur)/iu],
  ['economie',/(?:entrepris|business|argent|banque|salaire|travail|emploi|acheter|vendre|commerce|prix|stock|matièr|entrepreneur|money|job|work|buy|sell|公司|직업|عمل)/iu],
  ['politique',/(?:politique|élection|gouvern|mair|parti|ministre|présiden|déput|vote|election|government|politics|არჩევნ|選舉|선거|انتخاب)/iu],
  ['justice',/(?:police|crime|justice|procès|prison|arrest|illégal|voler|combat|délinquan|criminal|법원|قانون)/iu],
  ['sport',/(?:football|foot|stade|match|sport|supporter|jouer au ballon|soccer|basket|축구|كرة القدم)/iu],
  ['religion',/(?:religion|tractori|papyrusi|cocaïs|loukoumi|piété|temple|prière|教|종교|دين)/iu]
];
export function contexteAideQuestion(question,historique=[]) {
  const dernier=String(question||'');
  // Quelques tours de conversation suffisent à maintenir le sujet sans charger la
  // totalité du guide à chaque question (latence et coût limités).
  const texte=[dernier,...historique.slice(-2).map(x=>x.content||'')].join(' ');
  const choisis=DEPISTAGE.filter(([,rx])=>rx.test(texte)).map(([key])=>key).slice(0,3);
  return [AIDE_THEMES.demarrage,...choisis.map(key=>AIDE_THEMES[key])].join('\n\n');
}
