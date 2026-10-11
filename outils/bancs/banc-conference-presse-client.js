// BANC DE LA CONFERENCE DE PRESSE -- COTE JAVASCRIPT (11 octobre 2026)
// SOURCES: aucune -- le banc lit lui-meme les quatre fichiers qu'il eprouve
//
// POURQUOI UN BANC STRUCTUREL ET NON COMPORTEMENTAL. La boucle de la conference traverse un
// endpoint Vercel, un fournisseur IA paye, une identite de service et une pop-up de navigateur :
// on ne la joue pas sous JavaScriptCore. Ce qu'on peut prouver, et ce qui compte, c'est que les
// REGLES de l'arbitrage sont ecrites dans le code et non seulement dans un commentaire :
//
//   . l'IA FORMULE DES QUESTIONS, elle ne juge pas. Son prompt le lui interdit nommement, et rien
//     dans le code ne produit de note, de score ou de verdict de veracite ;
//   . le MINIMUM D'UNE QUESTION ne depend pas du fournisseur : un repli deterministe existe, et
//     un « FIN » au premier rang est ignore ;
//   . au-dela du premier rang, une panne FERME la conference normalement -- elle ne la corrompt
//     pas et n'annule pas la communication ;
//   . le navigateur n'ECRIT JAMAIS une question : il n'existe aucun insert ni update client sur
//     les deux tables de la conference ;
//   . FERMER LA POP-UP met fin a la conference, et il n'existe qu'une seule sortie -- aucun clic
//     dans le vide ne coupe la parole aux journalistes ;
//   . AUCUN COMPTEUR « 3/5 » n'est affiche ;
//   . la trace publique du jour passe par la couche publique EXISTANTE, et le Journal n'y voit
//     que le libelle -- jamais la transcription ;
//   . il n'y a AUCUNE publication automatique de la conference le lendemain.
//
// Usage : python3 outils/bancs/lancer-banc.py outils/bancs/banc-conference-presse-client.js
var ok = 0, ko = 0;
function att(n, c, d) { if (c) { print('  ok  ' + n); ok++; } else { print('  *** ' + n + (d !== undefined ? ' -- ' + d : '')); ko++; } }
function contient(s, f) { return s.indexOf(f) >= 0; }
function compte(s, re) { var m = s.match(re); return m ? m.length : 0; }
var RACINE = '/Users/fredericjasseron/ResPublica/';
function lire(c) { return readFile(RACINE + c); }

var API  = lire('api/conference.js');
var SB   = lire('supabase.js');
var POL  = lire('plateau-politique.js');
var COL  = lire('api/_journal-collecte.js');
var RED  = lire('api/redaction.js');

print('');
print("L'IA POSE DES QUESTIONS, ELLE NE JUGE PAS");
print('============================================================');
// LES INTERDITS SONT CHERCHES DANS LE PROMPT LUI-MEME, pas dans le fichier entier : un commentaire
// qui dit « l IA ne doit pas juger » ne contraint rien. C est la lecon du 11 octobre, ou une preuve
// SQL s etait accusee elle-meme en lisant ses propres commentaires.
var SYS = API.split('const SYSTEME = [')[1].split("].join('\n');")[0];
att('le prompt systeme est reellement envoye au fournisseur',
    contient(API, 'systeme: SYSTEME,'));
att('les interdits vivent dans le prompt, pas dans un commentaire',
    contient(SYS, 'CE QUE TU NE FAIS JAMAIS') && contient(SYS, 'aucun score'));
att('le prompt lui interdit de dire si une reponse est vraie ou fausse',
    contient(API, 'tu ne dis pas si une réponse est vraie ou fausse')
    && contient(API, 'accuses personne de mentir'));
att('le prompt lui interdit d interpreter un refus de repondre',
    contient(API, 'interprètes pas un refus de répondre')
    && contient(API, 'ne lui prêtes aucune intention'));
att('le prompt lui interdit toute note, score ou appreciation de credibilite',
    contient(API, "tu ne donnes aucune note, aucun score, aucune appréciation de crédibilité"));
att('le prompt lui interdit d inventer un fait',
    contient(API, 'inventes aucun fait') && contient(API, 'utilises que ce qui t'));
att('le prompt lui interdit de commenter, conclure ou resumer',
    contient(API, 'tu ne commentes pas, tu ne conclus pas, tu ne résumes pas'));
// CONTRE-EPREUVE : aucun vocabulaire de jugement ne sort de l endpoint vers la base. Les mots
// interdits sont cherches HORS des lignes de commentaire, qui ont le droit de les NOMMER pour
// expliquer qu ils sont interdits -- c est la lecon du 11 octobre : prosrc inclut les commentaires.
var CORPS = API.split('export default async function handler')[1];
CORPS = CORPS.split('\n').filter(function (l) { return !/^\s*(\/\/|\*|\/\*)/.test(l); }).join('\n');
['veracite', 'credibilite', 'mensonge', 'jugement', 'score', 'note', 'qualite'].forEach(function (mot) {
  att('aucun champ « ' + mot + ' » n est produit par le corps de l endpoint',
      !contient(CORPS, mot), mot);
});

print('');
print('LE MINIMUM D UNE QUESTION NE DEPEND PAS DU FOURNISSEUR');
print('============================================================');
att('un repli deterministe existe, et il porte cinq questions neutres',
    compte(API, /^  '/gm) >= 5 && contient(API, 'const REPLI = ['));
var BLOC_REPLI = API.split('const REPLI = [')[1].split('];')[0];
att('les questions de repli ne presupposent rien sur la veracite',
    !/menti|vrai|faux|cach|dissimul/.test(BLOC_REPLI), BLOC_REPLI.slice(0, 80));
att('un FIN au premier rang est ignore -- la condition est explicite',
    contient(API, 'SAUF avant la premiere question') && contient(API, 'if (rang > 1) {'));
att('au-dela du premier rang, une panne ferme la conference NORMALEMENT (p_interrompue: false)',
    contient(API, "if (rang > 1 && fournisseurMuet)")
    && compte(API, /p_interrompue: false/g) >= 3);
att('aucune panne ne clot la conference comme une INTERRUPTION',
    compte(API, /p_interrompue: true/g) === 0);
att('le nombre maximum est declare une fois, et vaut 5',
    contient(API, 'const QUESTIONS_MAXIMUM = 5;'));
att('le serveur impose la longueur de la question',
    contient(API, 'const JETONS_QUESTION = 120;') && contient(API, 'maxTokens: JETONS_QUESTION'));
att('le navigateur ne peut envoyer QUE l identifiant de la conference',
    contient(API, "Object.keys(body).some(k => k !== 'conference')"));
att('l identifiant est valide en forme avant tout appel paye',
    contient(API, '/^conf-[0-9]{6,20}$/'));

print('');
print("L'AUTORITE DE L'ENDPOINT");
print('============================================================');
att('il exige une session Supabase reellement verifiee',
    contient(API, 'await joueurAuthentifie(req)') && contient(API, "status(401)"));
att('il refuse de travailler sans identite de service plutot que de retomber sur anon',
    contient(API, '!identiteServeurDisponible()') && contient(API, 'status(503)'));
att('il exige que le demandeur soit L AUTEUR de la conference',
    contient(API, "conf.auteur !== monNom") && contient(API, "status(403)"));
att('il ecrit la question sous identite de SERVICE, jamais avec le jeton du joueur',
    /conference_question_poser'[\s\S]{0,160}\{ service: true \}/.test(API));
att('il lit le personnage du demandeur avec SON jeton, pas avec la cle de service',
    /mon_personnage'[\s\S]{0,80}\{ jeton: utilisateur\.jeton \}/.test(API));
att('un appel rejoue rend la question en attente au lieu d en poser une seconde',
    contient(API, 'const enAttente = echanges.find(e => e.reponse == null && !e.refus);'));
att('le contexte public recent vient de la couche publique du jeu',
    contient(API, "sbGetVerdict('chronique_nationale'"));
att('une panne de ce contexte ne casse pas la conference',
    contient(API, 'if (!r || !r.ok || !Array.isArray(r.donnees)) return [];'));
att('la conference n est pas un usage de /api/redaction -- cette voie rend du texte au client',
    !contient(RED, 'conference'));

print('');
print('LE NAVIGATEUR N ECRIT JAMAIS DANS LA TRANSCRIPTION');
print('============================================================');
att('aucun sbInsert sur les tables de la conference',
    compte(SB, /sbInsert\('conferences_presse/g) === 0);
att('aucun sbUpdate sur les tables de la conference',
    compte(SB, /sbUpdate\('conferences_presse/g) === 0);
att('aucun sbGet direct sur les tables de la conference -- tout passe par les portes',
    compte(SB, /sbGet\('conferences_presse/g) === 0);
att('la question est demandee a /api/conference, pas ecrite par une RPC cliente',
    contient(SB, "fetch('/api/conference'") && compte(SB, /conference_question_poser/g) === 0);
att('le jeton du joueur est joint a cet appel',
    /fetch\('\/api\/conference'[\s\S]{0,240}'Authorization': 'Bearer ' \+ jeton/.test(SB));
att('les trois portes clientes existent : repondre, clore, lire',
    contient(SB, "sbRpc('conference_repondre'") && contient(SB, "sbRpc('conference_clore'")
    && contient(SB, "sbRpc('conference_lire'"));
att('la matiere de la redaction a sa porte, en lecture seule',
    contient(SB, "sbRpc('conference_matiere'"));
att('un refus n est pas envoye comme une reponse vide',
    contient(SB, "p_reponse: refus === true ? null : String"));
att('la porte de publication transmet l accord de caisse, et il est explicite',
    contient(SB, 'p_accepte_sa_caisse: accepteSaCaisse === true'));

print('');
print('FERMER LA POP-UP MET FIN A LA CONFERENCE');
print('============================================================');
att('quitter la salle clot la conference comme une INTERRUPTION',
    /function quitterConferenceDePresse[\s\S]{0,900}sbConferenceClore\(id, true\)/.test(POL));
att('la fermeture d une conference deja terminee ne la requalifie PAS en interruption',
    /function fermerConferenceDePresse[\s\S]{0,300}\}/.test(POL)
    && !/function fermerConferenceDePresse[\s\S]{0,300}sbConferenceClore/.test(POL));
att('le fond de la pop-up ne porte aucun gestionnaire de clic',
    /conference-presse-overlay'[\s\S]{0,900}AUCUN onclick SUR LE FOND/.test(POL)
    && !/el\.onclick\s*=/.test(POL));
att('la seule sortie est un bouton explicite « Quitter la salle »',
    compte(POL, /quitterConferenceDePresse\(\)/g) >= 3);
att('le refus de repondre a son propre bouton',
    contient(POL, "bouton('repondreConferenceDePresse(true)', 'Refuser de répondre'"));
att('une reponse vide est refusee cote client aussi, sans devenir un refus implicite',
    contient(POL, "showToast('Réponse vide', 'Répondez, ou refusez explicitement de répondre.'"));
att('une panne de question ne propose PAS de recommencer la communication',
    contient(POL, "'Redemander'") && contient(POL, 'Votre communication, elle, est bien publiée.'));
att('les echanges deja joues restent a l ecran',
    /\(c\.echanges \|\| \[\]\)\.forEach/.test(POL));
att('les textes du ministre et des journalistes sont echappes avant affichage',
    contient(POL, "? escapeHtmlText : (t => String(t == null ? '' : t))")
    && contient(POL, 'esc(e.reponse)') && contient(POL, 'esc(e.question)'));
// AUCUN COMPTEUR : ni « 3/5 », ni « question 3 sur 5 », ni le `reste_possible` du serveur.
att('aucun compteur de questions n est affiche',
    !/\d\s*\/\s*5/.test(POL.split('function dessinerConferenceDePresse')[1] || '')
    && !contient(POL, 'reste_possible'));
att('la pop-up s ouvre a partir de l identifiant rendu par le SERVEUR',
    contient(POL, 'if (conferenceAOuvrir) ouvrirConferenceDePresse(conferenceAOuvrir);')
    && contient(POL, "conferenceAOuvrir = r.conference || null;"));
att('une conference deja ouverte est rouverte au lieu de bloquer la tribune',
    /raison === 'conference_deja_ouverte' && r\.conference/.test(POL));

print('');
print('LE FINANCEMENT, EN DEUX TEMPS, SANS MELANGE');
print('============================================================');
att('le premier appel ne donne aucun accord',
    /sbCommunicationPublier\([\s\S]{0,260}blocs, false\)/.test(POL));
att('le second n a lieu qu apres un oui explicite de l humain',
    /const accepte = await demanderAccordFinancementTribune\(r\);[\s\S]{0,400}blocs, true\)/.test(POL));
att('un renoncement le dit clairement : rien n a ete preleve',
    contient(POL, "showToast('Communication annulée'")
    && contient(POL, 'Aucun franc et aucun PA n') && contient(POL, 'ont été prélevés.'));
att('la fenetre dit qu il n y a pas de financement partage',
    contient(POL, "Il n'y a pas de ")
    && contient(POL, 'financement partagé'));
att('elle nomme les deux soldes que le serveur vient de lire',
    contient(POL, "fr(refus.solde_information)") && contient(POL, 'fr(refus.solde_proposee)'));
att('quand aucune caisse ne couvre, aucun bouton de paiement n est propose',
    /if \(possible\) \{[\s\S]{0,420}Payer ' \+ cout \+ ' FR sur ma caisse/.test(POL));
att('le refus de PA est rendu avec le compte reel et le requis',
    contient(POL, "fr(r.pa_reel) + ' sur ' + fr(r.requis)"));
att('la double insuffisance est expliquee, pas reduite a « action impossible »',
    contient(POL, "raison === 'les_deux_caisses_insuffisantes'"));
att('aucun solde de caisse n est decide cote client',
    !/solde\s*[<>]=?\s*cost/.test(POL));

print('');
print('LA TRACE PUBLIQUE DU JOUR, ET RIEN DE PLUS');
print('============================================================');
att('le type de chronique est raccorde -- sans cela la trace serait jetee en silence',
    /conference_presse:\s*\{ domaine: 'politique'/.test(COL));
att('le collecteur ne lit JAMAIS les tables de la conference',
    compte(COL, /conferences_presse/g) === 0);
att('et il ne connait de la conference que le libelle de la chronique',
    contient(COL, 'resume: def.resume ? def.resume(r) : r.libelle'));
att('aucun resume de conference n est fabrique par le collecteur',
    !/conference_presse[\s\S]{0,200}resume:\s*resume/.test(COL));
att('le raccord dit explicitement que la transcription n y figure pas',
    contient(COL, 'La TRANSCRIPTION n') && contient(COL, 'y figure pas, et ne doit jamais y figurer'));

print('');
print('AUCUNE PUBLICATION AUTOMATIQUE LE LENDEMAIN');
print('============================================================');
att('aucun fichier de api/ ne depose un article a partir d une conference',
    compte(API, /journal_articles_en_attente/g) === 0
    && compte(COL, /conference[\s\S]{0,80}journal_articles_en_attente/g) === 0);
att('la matiere est demandee par la redaction, elle ne se pousse pas toute seule',
    contient(SB, 'async function sbConferenceMatiere') && !contient(API, 'conference_matiere'));
att('et elle ne porte ni titre d article, ni angle, ni commentaire',
    contient(SB, 'ni angle, ni commentaire : ce travail appartient au journaliste joueur'));

print('');
print('============================================================');
if (ko === 0) print('LES ' + ok + ' EPREUVES SONT VERTES.');
else print(ko + ' EPREUVES ROUGES SUR ' + (ok + ko) + '.');
