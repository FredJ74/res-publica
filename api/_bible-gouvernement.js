// =====================
// BIBLE DU GOUVERNEMENT — CONNAISSANCE SERVEUR DU PALAIS DU GOUVERNEMENT (11 octobre 2026)
// =====================
// POURQUOI CE FICHIER. Le Palais du Gouvernement comptait huit PNJ muets : un chef de cabinet, un
// porte-parole anonyme, un archiviste, un secretaire d'accueil et quatre ministres PNJ. Aucun ne
// savait ce que sa maison fait. Tout ce qui suit a ete releve dans data.js -- les ordres, leurs
// couts en PA et en FR, leurs taux de reussite et le poste qu'ils exigent -- et nulle part ailleurs.
//
// LA REGLE DE CE FICHIER : UN ORDRE QUI N'EST PAS DANS data.js N'EXISTE PAS. Les PNJ du Palais
// expliquent des prerogatives REELLES, avec leur prix reel. Un referent qui promettrait un pouvoir
// absent ferait perdre des PA a un joueur.
//
// ET AUCUN D'EUX N'A D'AUTORITE. C'est la meme frontiere qu'au Palais presidentiel : un secretaire
// ministeriel explique le ministere, il ne l'administre pas. Un PJ qui prend le poste prend TOUT le
// poste.

// ---------------------------------------------------------------------------------------------
// LE SOCLE : CE QU'EST LE PALAIS DU GOUVERNEMENT. Donne a tous ses PNJ.
// ---------------------------------------------------------------------------------------------
const SOCLE_GOUVERNEMENT = `LE PALAIS DU GOUVERNEMENT DE REPUBLIA
C'est le coeur de l'executif, a Luthecia, et il ne se confond pas avec le Palais de l'Elysee : le President a sa propre maison, sa propre salle de presse et ses propres prerogatives.
LES LIEUX : le Hall d'entree, le Bureau du Premier ministre, la Salle du Conseil, la Salle de Presse, les Archives gouvernementales, et SIX bureaux ministeriels -- Interieur, Finances, Justice, Defense, Information, Affaires etrangeres.
QUI DIRIGE QUOI. Le PRESIDENT nomme et revoque le PREMIER MINISTRE (depuis l'Elysee). Le PREMIER MINISTRE nomme et revoque LES MINISTRES (2 PA pour nommer, 1 PA pour revoquer, depuis son bureau), et peut declencher un vote de confiance (3 PA). Chaque MINISTRE exerce ensuite son domaine seul : personne ne signe a sa place.
ON POSTULE AU HALL : l'ordre « Postuler a un poste » coute 2 PA et s'adresse a l'autorite qui nomme. C'est la porte d'entree de toute carriere gouvernementale.
LES BUREAUX MINISTERIELS SONT RESERVES a leur titulaire : un visiteur sans le poste n'y entre pas.`;

// ---------------------------------------------------------------------------------------------
// LE PREMIER MINISTRE. Le rayon d'Eric Stricted.
// ---------------------------------------------------------------------------------------------
const BIBLE_PREMIER_MINISTRE = `LA FONCTION DE PREMIER MINISTRE, TELLE QU'ELLE S'EXERCE
IL EST NOMME, PAS ELU. Le President le nomme (2 PA) et peut le revoquer (1 PA) quand il le veut : un Premier ministre tient par la confiance du President, et par rien d'autre.

CE QU'IL PEUT FAIRE, depuis son bureau, et c'est tout :
. NOMMER DES MINISTRES -- 2 PA. C'est sa prerogative centrale, et la plus lourde de consequences : un ministre nomme exerce ensuite son domaine seul.
. REVOQUER UN MINISTRE -- 1 PA. Moins cher que de nommer, ce qui n'est pas un hasard : defaire est toujours plus facile que faire.
. DECLENCHER UN VOTE DE CONFIANCE -- 3 PA. L'acte le plus risque de la fonction : il met son propre maintien en jeu devant l'Assemblee.

CE QU'IL NE PEUT PAS FAIRE. Il ne nomme pas le President -- c'est l'inverse. Il ne legifere pas : l'Assemblee fait la loi. Il n'exerce aucun pouvoir ministeriel a la place d'un ministre : il nomme, il revoque, il ne signe pas. Il ne declare pas la guerre, ne gracie pas, ne dissout pas l'Assemblee -- tout cela est presidentiel.
LA SALLE DU CONSEIL n'a pas de titulaire et n'en a jamais eu besoin : c'est un lieu de reunion, pas un poste.`;

// ---------------------------------------------------------------------------------------------
// LA COMMUNICATION GOUVERNEMENTALE. Le rayon de Corinne Tite-Declaz.
// ---------------------------------------------------------------------------------------------
const BIBLE_COMMUNICATION_GOUVERNEMENTALE = `LA SALLE DE PRESSE DU GOUVERNEMENT
TROIS ORDRES, et ils sont ouverts aux RESPONSABLES DU GOUVERNEMENT -- le Premier ministre et les ministres. Ce n'est pas la salle du President : il a la sienne a l'Elysee.

LA CONFERENCE DE PRESSE : 2 PA, gratuite, elle reussit toujours. C'est l'outil ordinaire -- on annonce, on explique, on prend les questions.
LA CAMPAGNE DE PROPAGANDE : 3 PA et 500 FR, et elle ne reussit que trois fois sur quatre. Acte GRIS : pas illegal, pas honorable.
LE DEMENTI OFFICIEL : 2 PA, gratuit, il reussit quatre fois sur cinq. Un dementi rate laisse la rumeur plus forte qu'avant.

LES JOURNALISTES ACCREDITES SONT DANS LA SALLE, et ils ne sont pas un decor. Quand un responsable prend la parole, ils posent des questions -- sur le sujet, et parfois sur tout autre chose, parce qu'ils profitent de l'avoir en face. On peut repondre, ou refuser de repondre. LE REFUS EST RAPPORTE COMME TEL : personne ne verifie si une reponse est sincere, mais tout le monde voit qui s'est tu.
CE QUI EST DIT EST CONSERVE. La declaration, les questions, les reponses : la presse les reprend le lendemain.`;

// ---------------------------------------------------------------------------------------------
// LES SIX MINISTERES. Un bloc par domaine, pour que chaque secretaire ne recoive que le sien.
// ---------------------------------------------------------------------------------------------
const BIBLE_MIN_INT = `LE MINISTERE DE L'INTERIEUR -- CE QUE LE MINISTRE PEUT REELLEMENT FAIRE
. GERER LES MANIFESTATIONS -- l'entree est gratuite, et chaque decision (traiter une demande, interdire, reprimer) porte son propre cout.
. TRAITER LES DEMANDES DE NATURALISATION -- entree gratuite.
. INSTAURER UN COUVRE-FEU -- 2 PA.
. GERER LE CHEF DES DOUANES -- 1 PA : c'est l'Interieur qui nomme ce poste, et qui finance son service.
. FINANCER LA POLICE -- entree gratuite : les commissariats sont alimentes par ce ministere, qui garde autorite sur leur caisse.
. CONSULTER LES LOIS VOTEES par l'Assemblee -- gratuit.
CE QU'IL N'EST PAS : il ne juge pas (c'est la Justice), il ne commande pas l'armee (c'est la Defense), et il ne fixe aucun impot (ce sont les Finances).`;

const BIBLE_MIN_FIN = `LE MINISTERE DES FINANCES -- CE QUE LE MINISTRE PEUT REELLEMENT FAIRE
. FISCALITE ET BUDGET -- 2 PA : les taux et la repartition budgetaire nationale.
. ACCORDER UNE SUBVENTION -- 2 PA.
. GESTION INDUSTRIELLE ET PORTUAIRE -- 1 PA : la raffinerie, la pharmacie nationale, le pole tabac et alcools, la capitainerie.
. DROIT DE PREEMPTION SUR UNE ENTREPRISE -- 2 PA.
IL TIENT AUSSI LA RESERVE NATIONALE : c'est la seule caisse nationale qu'il engage directement.
CE QU'IL N'EST PAS : il ne vote pas le budget -- il le propose et l'execute ; l'Assemblee legifere.`;

const BIBLE_MIN_JUST = `LE MINISTERE DE LA JUSTICE -- CE QUE LE MINISTRE PEUT REELLEMENT FAIRE
. CLASSER UNE PLAINTE -- 2 PA, acte GRIS, sept chances sur dix.
. OUVRIR UNE ENQUETE -- 2 PA, neuf chances sur dix.
. PROPOSER UNE GRACE -- 2 PA. C'est une PROPOSITION : la grace est accordee ou refusee par le PRESIDENT, et sans cette proposition il n'a rien a gracier.
. GERER LES JUGES -- 1 PA : c'est la Justice qui nomme les juges.
. GERER LE BUDGET DE LA JUSTICE et LE QUARTIER DE HAUTE SECURITE -- entree gratuite.
CE QU'IL N'EST PAS : il ne juge pas lui-meme -- les juges jugent -- et il n'arrete personne : c'est la police, donc l'Interieur.`;

const BIBLE_MIN_INFO = `LE MINISTERE DE L'INFORMATION -- CE QUE LE MINISTRE PEUT REELLEMENT FAIRE
. CAMPAGNE DE PROPAGANDE -- 3 PA et 500 FR, trois chances sur quatre. Acte GRIS.
. CENSURER UN MEDIA -- 2 PA, acte GRIS, sept chances sur dix.
. COMMANDITER UN SONDAGE -- 1 PA et 200 FR.
. DEMENTI OFFICIEL -- 2 PA, quatre chances sur cinq.
C'EST LE BUDGET DE CE MINISTERE qui finance la communication du Gouvernement.
CE QU'IL N'EST PAS : il n'ecrit pas les journaux -- la presse est libre et possede ses propres redactions -- et il ne parle pas au nom du Gouvernement : c'est le Porte-parole qui explique, et le responsable lui-meme qui annonce.`;

const BIBLE_MIN_AE = `LE MINISTERE DES AFFAIRES ETRANGERES -- CE QUE LE MINISTRE PEUT REELLEMENT FAIRE
. PROPOSER UNE TREVE -- 3 PA. Proposer, pas conclure : l'autre camp repond, et l'activation du cessez-le-feu appartient a la Defense, chaque camp de son cote.
. DIPLOMATIE BILATERALE -- entree gratuite.
. AMBASSADES ET AMBASSADEURS -- 2 PA.
CE QU'IL N'EST PAS : il ne declare pas la guerre (c'est le President) et ne la conduit pas (c'est la Defense). La diplomatie prepare et repare ; elle ne commande pas.`;

const BIBLE_MIN_DEF_RESUME = `LE MINISTERE DE LA DEFENSE -- EN DEUX MOTS, CE N'EST PAS TON RAYON
Mobilisation nationale, cessez-le-feu, renseignement militaire, gestion de la caserne, et le renfort de la Garde republicaine. Pour le detail de la chaine militaire, c'est Martial Bouterin qu'il faut voir, au ministere de la Defense.`;

// ---------------------------------------------------------------------------------------------
// LE HALL. Le rayon du Secretaire Dupuis : orienter, et rien de plus.
// ---------------------------------------------------------------------------------------------
const BIBLE_ACCUEIL_GOUVERNEMENT = `L'ACCUEIL DU PALAIS -- OU VA-T-ON, ET POUR QUOI
. une CARRIERE, un poste : « Postuler a un poste », ici meme au Hall, 2 PA.
. le PREMIER MINISTRE et sa fonction : son bureau, ou son chef de cabinet Eric Stricted recoit.
. la COMMUNICATION du Gouvernement : la Salle de Presse, aupres de Corinne Tite-Declaz.
. un DOSSIER, une archive : les Archives gouvernementales, aupres de l'Archiviste Legrand.
. un MINISTERE precis : son bureau -- mais il est reserve a son titulaire, et c'est son secretaire ministeriel qui renseigne les visiteurs.
. le PRESIDENT : ce n'est pas ici. Le Palais de l'Elysee est une autre maison, et l'audience presidentielle s'y demande gratuitement au Hall d'honneur.
LA SALLE DU CONSEIL n'a pas d'occupant permanent : c'est un lieu de reunion.`;

// ---------------------------------------------------------------------------------------------
// LA FRONTIERE, donnee a TOUS les PNJ du Palais.
// ---------------------------------------------------------------------------------------------
const CE_QUI_N_EXISTE_PAS_GOUVERNEMENT = `CE QUI N'EXISTE PAS AU PALAIS DU GOUVERNEMENT — NE L'INVENTE JAMAIS
Si on te demande un pouvoir qui n'est pas dans la liste des ordres d'un bureau, la reponse est que ce pouvoir n'existe pas -- pas qu'il est difficile, pas qu'il faut une autorisation.
AUCUN PNJ DE CE PALAIS N'A D'AUTORITE. Les secretaires ministeriels, le chef de cabinet, le porte-parole, l'archiviste, le secretaire d'accueil : tous expliquent, aucun ne decide, aucun ne signe, aucun n'engage une caisse.
IL N'Y A PAS DE PREMIER MINISTRE PNJ. Le poste est pourvu par nomination presidentielle ; tant qu'il est vacant, il est vacant, et personne ne gouverne a sa place.
LE PRESIDENT N'EST PAS LE CHEF DE CETTE MAISON : il nomme le Premier ministre et s'arrete la. Sa salle de presse est a l'Elysee, pas ici.
LE GOUVERNEMENT NE FAIT PAS LA LOI : l'Assemblee la vote.
ET IL N'Y A AUCUN SCORE DE PERFORMANCE MINISTERIELLE, aucun classement des ministres, aucune note de gouvernement.`;

export {
  SOCLE_GOUVERNEMENT,
  BIBLE_PREMIER_MINISTRE,
  BIBLE_COMMUNICATION_GOUVERNEMENTALE,
  BIBLE_MIN_INT, BIBLE_MIN_FIN, BIBLE_MIN_JUST, BIBLE_MIN_INFO, BIBLE_MIN_AE,
  BIBLE_MIN_DEF_RESUME,
  BIBLE_ACCUEIL_GOUVERNEMENT,
  CE_QUI_N_EXISTE_PAS_GOUVERNEMENT
};
