// BANC DU HALL DE L'ASSEMBLEE NATIONALE — PREMIERE PASSE PNJ (11 octobre 2026)
// SOURCES: data.js api/_bible-assemblee.js api/_bible-gouvernement.js api/_bible-militaire.js api/_bible-presidence.js api/_pnj-personnalites.js api/_pnj-referents.js api/_pnj-profils.js
//
// CE QU'IL PROUVE. Le hall comptait trois PNJ muets. Ce banc verifie :
//   . que le GARDE ne pretend plus etre a l'Elysee -- sa fiche l'y placait pour les TROIS halls,
//     et son identifiant se derive du nom affiche, identique aux trois postes ;
//   . que l'HOTESSE est devenue la referente pedagogique de l'Assemblee, avec la procedure REELLE
//     relevee dans le code -- et rien de la theorie d'un parlement reel ;
//   . que RENEE TOITOUT est nommee, qu'elle recoit les REGARDS et rien de la procedure ;
//   . que chacune ignore le domaine de l'autre -- sinon l'une des deux est decorative ;
//   . et surtout que le bloc des regards DIT CE QU'IL NE SAIT PAS : sans cela, l'IA remplirait le
//     silence par une anecdote inventee, ce qui est l'interdit central de l'arbitrage.
//
// Usage : python3 outils/bancs/lancer-banc.py outils/bancs/banc-assemblee-hall.js
var ok = 0, ko = 0;
function att(n, c, d) { if (c) { print('  ok  ' + n); ok++; } else { print('  *** ' + n + (d !== undefined ? ' -- ' + d : '')); ko++; } }
function contient(s, f) { return String(s).indexOf(f) >= 0; }
function piece(salle) { return BUILDINGS['assemblee'].rooms[salle]; }
function qui(salle, job) {
  return (piece(salle).persons || []).filter(function (p) { return p.job === job; })[0];
}
var RACINE = '/Users/fredericjasseron/ResPublica/';
function existe(c) { try { return readFile(RACINE + c).length > 0; } catch (e) { return false; } }
// LA MEME NORMALISATION QUE slugPnj (plateau-pnj.js) : c'est elle qui relie le nom AFFICHE a
// l'identifiant du profil serveur. Un accent de divergence rendrait le PNJ muet.
function slugDeNom(nom) {
  return String(nom || '').replace(' (PNJ)', '').trim()
    .normalize('NFD').replace(/[̀-ͯ]/g, '')
    .toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '');
}

print('');
print('LES TROIS PNJ DU HALL SONT TOUJOURS LA, ET NOMMES');
print('============================================================');
var g = qui('accueil_assemblee', 'garde');
var h = qui('accueil_assemblee', 'hotesse_accueil');
var r = qui('accueil_assemblee', 'femme_menage');
att('le garde est dans le hall', !!g, g && g.name);
att("l'hotesse est dans le hall", !!h, h && h.name);
att("l'agente d'entretien est dans le hall", !!r, r && r.name);
att('elle porte desormais un NOM : Renee Toitout', r && r.name === 'Renée Toitout (PNJ)', r && r.name);
att('et son role dit son metier', r && r.role === "PNJ - Agente d'entretien", r && r.role);
att('son nom se normalise exactement en son identifiant de profil',
    r && slugDeNom(r.name) === 'renee_toitout', r && slugDeNom(r.name));
att("le nom de l'hotesse se normalise en son identifiant",
    h && slugDeNom(h.name) === 'hotesse_accueil', h && slugDeNom(h.name));
att('les trois portraits existent reellement sur le disque',
    existe('images/garde-republicain-assemblee.webp')
    && existe('images/hotesse-accueil-assemblee.webp')
    && existe('images/agent-entretien-assemblee.webp'));
att("l'image de Renee est INCHANGEE : seul le personnage est nomme",
    r && r.photoUrl === 'images/agent-entretien-assemblee.webp', r && r.photoUrl);
// CONTRE-EPREUVE : l'ancien identifiant generique ne repond plus. Un profil laisse derriere reste
// adressable, avec un nom generique et un savoir vide -- la lecon du General Faure.
att("l'ancien identifiant `agent_entretien` n'est plus adressable", !profilExiste('agent_entretien'));

print('');
print('LE GARDE NE PRETEND PLUS ETRE A L ELYSEE');
print('============================================================');
att('il a un profil serveur', profilExiste('garde_republicain'));
var pG = construirePromptSysteme('garde_republicain', 'fr', null, null);
// LE DEFAUT CORRIGE : le MEME nom affiche est en faction dans TROIS halls, donc les trois tombaient
// sur une fiche qui nommait l'Elysee et la securite presidentielle. Deux faits faux sur trois.
// IL NOMME LES TROIS POSTES -- c'est le fait institutionnel -- mais il ne DECLARE AUCUN LIEU DE
// TRAVAIL : sa fiche n'a plus de champ `lieu`, et il dit « a l'un d'eux ». C'est la seule forme
// honnete : le serveur recoit un identifiant de profil, pas une piece.
att("il ne declare aucun lieu de travail",
    !contient(pG, 'Ton lieu de travail') && !contient(pG, 'Tu travailles'));
att("et il dit explicitement etre en faction a l'un des trois",
    contient(pG, "Tu es en faction a l'un d'eux"));
att("le Palais de l'Elysee n'est plus son adresse",
    !contient(pG, "Palais de l'Elysee de Republia"));
att("il ne se dit plus charge de la securite PRESIDENTIELLE",
    !contient(pG, 'Securite presidentielle') && !contient(pG, 'securite presidentielle'));
att('il sait que la Garde tient TROIS postes nationaux',
    contient(pG, 'TROIS POSTES NATIONAUX'));
att('il connait le garde permanent gratuit et ses quatre heures',
    contient(pG, 'GRATUIT') && contient(pG, 'QUATRE HEURES'));
att('il connait le renfort : 24 h, 50 FR par homme, sur la caisse de la Defense',
    contient(pG, 'VINGT-QUATRE HEURES') && contient(pG, '50 FR par garde supplementaire')
    && contient(pG, 'caisse du Ministere de la Defense'));
att("il sait qu'un renfort tombe n'est PAS remplace",
    contient(pG, "UN RENFORT TOMBE N'EST PAS REMPLACE"));
att("il sait que la Garde appartient a l'Etat, pas au ministre",
    contient(pG, "LA GARDE APPARTIENT A L'ETAT"));
att("il ne nomme pas son poste, il dit « ici »",
    contient(pG, 'TU NE NOMMES AUCUN BATIMENT EN PARTICULIER'));
att("il ne dit jamais qui est passe", contient(pG, 'tu ne dis jamais qui tu as vu entrer'));
att("il n'a aucune autorite politique", contient(pG, "TU N'AS AUCUNE AUTORITE POLITIQUE"));
// IL N'EST PAS REFERENT : il garde, il n'enseigne pas. Son savoir s'arrete a son corps.
att('il renvoie la procedure de l Assemblee a l hotesse',
    contient(pG, "c'est l'hotesse d'accueil"));

print('');
print("L HOTESSE EXPLIQUE LA PROCEDURE REELLE, PAS UN PARLEMENT THEORIQUE");
print('============================================================');
var pH = construirePromptSysteme('hotesse_accueil', 'fr', null, null);
att('elle connait le socle : neuf sieges, trois par ville',
    contient(pH, 'NEUF SIEGES, TROIS PAR VILLE'));
att('elle connait le mandat de cinq semaines et le minimum de 5 INF',
    contient(pH, 'CINQ SEMAINES') && contient(pH, "5 points d'influence"));
att('elle sait que les deputes sont elus AU NIVEAU DE LA VILLE',
    contient(pH, 'elus AU NIVEAU DE LA VILLE'));
att('elle sait qui peut deposer, et que le President ne peut PAS',
    contient(pH, 'Reserve aux DEPUTES, au PREMIER MINISTRE et aux MINISTRES')
    && contient(pH, "Le President de la Republique n'y est PAS eligible"));
att('elle sait que le depot exige la presence dans l hemicycle',
    contient(pH, "etre PRESENT dans l'hemicycle"));
att('elle connait les couts reels de l hemicycle',
    contient(pH, 'OBSERVER LES DEBATS (1 PA)') && contient(pH, 'DEPOSER UN PROJET DE LOI (1 PA)')
    && contient(pH, 'VOTER UNE LOI -- gratuit') && contient(pH, 'MARCHANDER UN VOTE (1 PA et 100 FR)'));
att('elle sait que le marchandage est preleve meme en cas d echec, et qu il est LEGAL',
    contient(pH, 'MEME EN CAS D\'ECHEC') && contient(pH, "C'est LEGAL a Republia"));
att("elle sait qu'un amendement s'ajoute SOUS le texte et ne le remplace jamais",
    contient(pH, 'il ne le remplace jamais'));
att('elle connait l echeance du mercredi 22 heures',
    contient(pH, 'CLOT LE MERCREDI A 22 HEURES'));
att("elle sait qu'un vote arrive apres l echeance est refuse meme sans depouillement",
    contient(pH, "c'est l'heure qui tranche, pas le passage du depouillement"));
att('elle distingue les trois natures de proposition, et le sort de la loi RP',
    contient(pH, 'une loi RP est declarative') && contient(pH, 'TERMINEE des son adoption'));
att('elle distingue ADOPTEE et EN VIGUEUR',
    contient(pH, "ADOPTEE N'EST PAS EN VIGUEUR"));
att("elle sait que c'est le Ministre de l'Interieur qui met en application, en 36 heures",
    contient(pH, 'MINISTRE DE L\'INTERIEUR EN FONCTION') && contient(pH, '36 HEURES REELLES'));
att('elle connait le bareme de sanction et qui il frappe',
    contient(pH, '20 points de popularite au premier palier')
    && contient(pH, 'TOUS les ministres en fonction AU MOMENT DU PALIER'));
att('elle sait que la portee RESTREINT et n elargit jamais',
    contient(pH, 'Une portee RESTREINT ; elle n\'elargit jamais'));
att("elle connait l'indemnite reelle du depute : 250 FR par jour",
    contient(pH, '250 FR par jour'));
att('elle connait les couloirs et les archives',
    contient(pH, 'CONSULTER LE LOBBYISTE (1 PA et 150 FR)')
    && contient(pH, 'CONSULTER LE REGISTRE -- gratuit'));

print('');
print("ET ELLE DIT CE QUI N EXISTE PAS, AU LIEU DE L INVENTER");
print('============================================================');
att('ni commission, ni seance des questions, ni motion de censure, ni navette',
    contient(pH, 'NI COMMISSION, NI SEANCE DES QUESTIONS, NI MOTION DE CENSURE'));
att("le vote de confiance n'appartient pas a l'Assemblee",
    contient(pH, "LE VOTE DE CONFIANCE N'APPARTIENT PAS A L'ASSEMBLEE"));
att('la dissolution est un pouvoir presidentiel, decide a l Elysee',
    contient(pH, 'LA DISSOLUTION EST UN POUVOIR DU PRESIDENT'));
att('aucun PNJ du hall n a d autorite',
    contient(pH, "AUCUN PNJ DE CE HALL N'A D'AUTORITE"));
att('aucune note de depute, aucun classement, aucun score d assiduite',
    contient(pH, 'AUCUNE NOTE DE DEPUTE'));

print('');
print("L HOTESSE NE COMMENTE PAS, NE JUGE PAS, NE SAIT RIEN DE PRIVE");
print('============================================================');
att('elle ne commente jamais politiquement',
    contient(pH, 'TU NE COMMENTES JAMAIS POLITIQUEMENT'));
att('elle ne juge ni les deputes ni les joueurs',
    contient(pH, 'TU NE JUGES NI LES DEPUTES NI LES JOUEURS'));
att('elle ne connait aucune information privee',
    contient(pH, "TU NE CONNAIS AUCUNE INFORMATION PRIVEE"));
att("elle n'invente aucune procedure",
    contient(pH, "TU N'INVENTES AUCUNE PROCEDURE"));
att("elle n'a aucune autorite", contient(pH, "TU N'AS AUCUNE AUTORITE"));

print('');
print('RENEE CONSTATE, ELLE N ENQUETE PAS');
print('============================================================');
att('elle a un profil serveur', profilExiste('renee_toitout'));
var pR = construirePromptSysteme('renee_toitout', 'fr', null, null);
att('elle sait que les faits transmis sont les SEULS qu elle connaisse',
    contient(pR, 'LES FAITS QU\'ON TE DONNE SONT LES SEULS QUE TU CONNAISSES'));
att("si on ne lui donne rien, elle n'a rien vu -- et c'est ecrit en premier",
    contient(pR, "SI ON NE TE DONNE RIEN, TU N'AS RIEN VU"));
att("elle n'invente JAMAIS une anecdote pour remplir le silence",
    contient(pR, "TU N'INVENTES JAMAIS une anecdote"));
att('elle constate et ne conclut pas',
    contient(pR, 'TU CONSTATES, TU N\'ENQUETES PAS'));
att('elle ne peut pas affirmer une negociation, un complot ou de l argent',
    contient(pR, 'negociaient un vote') && contient(pR, "qu'on preparait un coup"));
att("elle n'invente jamais le contenu d'une conversation",
    contient(pR, "TU N'INVENTES JAMAIS LE CONTENU D'UNE CONVERSATION"));
att('une impression reste une impression, donnee comme telle',
    contient(pR, "Une impression de Renee n'est pas une information"));
att("elle sait que les deputes PNJ ne se deplacent pas",
    contient(pR, 'LES DEPUTES PNJ NE SE DEPLACENT PAS'));
att("elle sait que l'assiduite ne se juge qu'au depouillement",
    contient(pR, "L'ASSIDUITE AUX VOTES ne se juge qu'au depouillement"));
att('elle ne donne aucune information privee',
    contient(pR, 'TU NE DONNES JAMAIS : l\'argent de quiconque'));
att("elle n'est ni espionne ni enquetrice",
    contient(pR, "TU N'ES NI ESPIONNE NI ENQUETRICE"));
att('elle est discrete dans son comportement, meme quand elle est critique',
    contient(pR, 'TU RESTES DISCRETE DANS TON COMPORTEMENT'));
att('elle digresse parce qu on lui donne rarement l occasion de parler',
    contient(pR, "ON NE TE DONNE PRESQUE JAMAIS L'OCCASION DE PARLER"));
// LE JEU DE MOTS NE S'EXPLIQUE PAS : il est la pour qui le remarque.
att('son nom ne fait l objet d aucune explication dans son prompt',
    !/re-?nettoie|jeu de mots/i.test(pR));

print('');
print('CHACUNE IGNORE LE DOMAINE DE L AUTRE');
print('============================================================');
// Si l'une des deux recevait les deux corpus, l'autre deviendrait decorative : c'est la regle de
// decoupage etablie au Palais presidentiel, appliquee ici.
att("Renee ne connait PAS la procedure parlementaire",
    !contient(pR, 'CLOT LE MERCREDI A 22 HEURES') && !contient(pR, 'DEPOSER UN PROJET DE LOI (1 PA)'));
att("l'hotesse ne recoit PAS les regards de Renee",
    !contient(pH, 'CE QUE TU VOIS, ET CE QUE TU N\'EN CONCLUS PAS'));
att('les deux partagent le socle de la maison',
    contient(pH, "L'ASSEMBLEE NATIONALE DE REPUBLIA") && contient(pR, "L'ASSEMBLEE NATIONALE DE REPUBLIA"));
att('les deux portent la frontiere du batiment',
    contient(pH, "NE L'INVENTE JAMAIS") && contient(pR, "NE L'INVENTE JAMAIS"));
att("Renee renvoie la procedure a l'hotesse",
    contient(pR, "l'hotesse d'accueil, au hall"));

print('');
print('LE CINQUIEME CANAL : CE QUE LE BLOC DIT, ET CE QU IL AVOUE NE PAS SAVOIR');
print('============================================================');
// RIEN A SIGNALER : le cas le plus frequent, et le plus dangereux. Le bloc doit l'ECRIRE.
var vide = construirePromptSysteme('renee_toitout', 'fr', null, null, null, null,
  { ok: true, rien_a_signaler: true, passages: [], ensemble: [], scrutins: [], deputes: [],
    aucun_scrutin: true });
att('rien a signaler : le bloc le dit explicitement',
    contient(vide, 'RIEN. Aucun passage, aucune rencontre, aucun scrutin'));
att('et il ordonne de le dire simplement, sans inventer',
    contient(vide, "n'invente ni visite, ni nom, ni anecdote"));
att('aucune liste de passages n est fabriquee quand il n y en a pas',
    !contient(vide, 'LES PASSAGES :'));

// DES FAITS REELS : la forme exacte de ce que la porte rend.
var plein = construirePromptSysteme('renee_toitout', 'fr', null, null, null, null,
  { ok: true, rien_a_signaler: false, aucun_scrutin: true,
    passages: [
      { qui: 'Arnie', passages: 7, pieces: ['accueil_assemblee', 'hemicycle'],
        dernier_jour: 23, derniere_heure: '01h', poste_actuel: 'min_def',
        raison_institutionnelle: true },
      { qui: 'Vince Kubrick', passages: 1, pieces: ['accueil_assemblee'],
        dernier_jour: 7, derniere_heure: '22h', poste_actuel: 'lieutenant',
        raison_institutionnelle: false }],
    ensemble: [{ qui_a: 'Arnie', qui_b: 'Vince Kubrick', fois: 2, dernier_jour: 19 }],
    deputes: [{ ville: 'capitale', rang: 1, nom: 'Etienne Vauclerc', endormi: false },
              { ville: 'ville_b', rang: 2, nom: 'Gerard Pichon', endormi: true }],
    scrutins: [] });
att('un passage est rendu avec son compte, ses pieces et sa date',
    contient(plein, 'Arnie : 7 passage(s), vu(e) dans accueil_assemblee, hemicycle')
    && contient(plein, 'Dernier passage au jour 23 vers 01h'));
att('le poste est donne comme celui d AUJOURD HUI, pas celui du jour-la',
    contient(plein, 'Poste occupe AUJOURD HUI : min_def'));
att("l'absence de raison institutionnelle est donnee comme un FAIT, pas un soupcon",
    contient(plein, "c'est un FAIT, pas un soupcon"));
att('une co-presence est rendue, et bornee a ce qu elle est',
    contient(plein, 'Arnie et Vince Kubrick, 2 fois')
    && contient(plein, 'tu ne sais pas de quoi ils parlaient'));
att('un depute endormi se voit, et seulement lui',
    contient(plein, 'CEUX QUI DORMENT EN CE MOMENT : Gerard Pichon'));
att("aucun scrutin : le bloc interdit de conclure a une assiduite",
    contient(plein, "AUCUN SCRUTIN N'A ENCORE ETE DEPOUILLE")
    && contient(plein, "tu ne peux dire de PERSONNE qu'il est assidu ou absent"));

// ABSENCES PARTIELLES : chaque categorie vide doit se dire, separement.
var partiel = construirePromptSysteme('renee_toitout', 'fr', null, null, null, null,
  { ok: true, rien_a_signaler: false, aucun_scrutin: false,
    passages: [], ensemble: [], deputes: [],
    scrutins: [{ titre: 'Interdiction du metal', resultat: 'adoptee', session: 3,
                 pour: ['Yann Legall'], contre: [], abstention: [],
                 non_votants: ['Sophie Marechal'], endormis: [] }] });
att('aucun passage : le bloc le dit au lieu de se taire',
    contient(partiel, 'AUCUN PASSAGE ENREGISTRE sur la periode'));
att('aucune rencontre : le bloc le dit, et interdit d en inventer',
    contient(partiel, 'aucune a inventer'));
att('un scrutin depouille est rendu nominativement, non-votants compris',
    contient(partiel, 'Ont vote pour : Yann Legall')
    && contient(partiel, "N ONT PAS VOTE : Sophie Marechal"));
att('et une liste vide se dit « personne », jamais par un blanc',
    contient(partiel, 'Contre : personne'));

print('');
print('LE CANAL N EST DEMANDE QUE POUR RENEE');
print('============================================================');
// CONTRE-EPREUVE DE PERIMETRE : le bloc est pose par construirePromptSysteme pour tout profil qui
// recoit des regards -- mais chat.js ne les demande QUE pour Renee. On verifie la constante.
var CHAT = readFile(RACINE + 'api/chat.js');
att("chat.js ne demande les regards que pour `renee_toitout`",
    contient(CHAT, "const REGARDS_ASSEMBLEE = 'renee_toitout';")
    && contient(CHAT, 'profilId === REGARDS_ASSEMBLEE'));
att('et la porte ne recoit QU UNE fenetre en jours -- ni pays, ni batiment, ni nom',
    contient(CHAT, 'assemblee_regards:            () => ({ p_jours: 7 })'));
att('le canal est lu sous le JETON DU JOUEUR, jamais sous une cle de service',
    contient(CHAT, "lireMemoire('assemblee_regards', null, jeton)"));
// LES SIX CANAUX HISTORIQUES RESTENT DISTINCTS : le sixieme est
// l'ETAPE DE LA VISITE d'accueil, et il n'appartient qu'a Jeremy -- comme les regards de
// l'Assemblee n'appartiennent qu'a Renee. Aucun ne se substitue a un autre, et ils partent
// ENSEMBLE. Le septieme relit la fonction des deux PNJ municipaux permanents,
// sans remplacer une memoire ni concerner les autres profils.
att('les sept canaux partent ensemble et restent distincts',
    contient(CHAT, 'const [relation, pedagogie, contextePublic, mandats, regards, visite, fonctionMunicipale] = await Promise.all([')
    && contient(CHAT, 'lireFonctionMunicipale(req.body.profil, utilisateur.jeton)'));
att('et le sixieme n est demande que pour Jeremy, pas pour Renee',
    contient(CHAT, "const VISITE_D_ACCUEIL = 'jeremy';")
    && contient(CHAT, 'profilId === VISITE_D_ACCUEIL'));

print('');
print('AUCUN DE CES PNJ NE RECOIT UN POUVOIR NI UNE JAUGE');
print('============================================================');
['garde_republicain', 'hotesse_accueil', 'renee_toitout'].forEach(function (id) {
  var p = construirePromptSysteme(id, 'fr', null, null);
  att(id + ' : aucun score ni jauge de sympathie',
      !/score de sympathie|note de sympathie|jauge de sympathie|points de sympathie/i.test(p));
  att(id + ' : il ne fait entrer personne par faveur et n engage aucune caisse',
      !/tu peux faire entrer|tu autorises l acces|tu engages la caisse/i.test(p));
});

print('');
print('============================================================');
if (ko === 0) print('LES ' + ok + ' EPREUVES SONT VERTES.');
else print(ko + ' EPREUVES ROUGES SUR ' + (ok + ko) + '.');
