// Banc du COTE NAVIGATEUR DES SUBVENTIONS MUNICIPALES (chaine 7, 10 octobre 2026).
// SOURCES: aucune -- ce banc lit les fichiers du depot eux-memes, par readFile.
//
// CE BANC REMPLACE `banc-chaine-7-inertie.js`, ET LE REMPLACEMENT EST LE SUJET. L'ancien tenait un
// GEL : il verifiait que `verifierSubventionMairie` restait inerte, son montant ecrit en dur a
// zero, en attendant un arbitrage de game design. L'arbitrage est rendu le 10 octobre 2026, la
// fonction est supprimee, et un banc qui surveille un gel leve n'a plus de sens -- il rougirait
// pour la bonne raison, ce qui est la pire facon de rougir.
//
// IL TIENT DEUX CHOSES A LA PLACE :
//   * LA RESORPTION. L'ancienne mecanique ne doit pas reapparaitre, ni en entier ni par morceaux.
//     Deux mecaniques de subvention municipale en parallele -- l'une fantome et quotidienne,
//     l'autre deliberee -- etait precisement ce que la consigne interdisait.
//   * LA DISCIPLINE DU NOUVEAU COTE CLIENT. Le navigateur ne doit ni calculer un disponible, ni
//     facturer les PA que la porte facture deja, ni nommer un statut, ni ecrire dans la caisse
//     d'un club. Chacun de ces quatre gestes serait une faille, et chacun a son epreuve.
var RACINE = '/Users/fredericjasseron/ResPublica/';

// LA SUBSTITUTION D'UN SEUL FICHIER, pour que les contre-epreuves puissent mordre. Ce banc lit
// SIX fichiers ; une contre-epreuve qui patche `supabase.js` doit pouvoir dire lequel sa copie
// remplace, sinon elle prouverait n'importe quoi. C'est le contrat de `lancer_cible` dans
// outils/bancs/contre-epreuves-chantier5.py.
function lire(f) {
  if (typeof CHEMIN_FICHIER === 'string' && typeof CHEMIN_SOURCE === 'string'
      && f === CHEMIN_FICHIER) return readFile(CHEMIN_SOURCE);
  return readFile(RACINE + f);
}
function sansCommentaires(texte) {
  return texte.split('\n').filter(function (l) {
    var t = l.trim();
    return t.indexOf('//') !== 0 && t.indexOf('--') !== 0;
  }).join('\n');
}

var ORGA    = lire('plateau-organisations-quetes.js');
var POLI    = lire('plateau-politique.js');
var SUPA    = lire('supabase.js');
var ROUTEUR = lire('plateau-router.js');
var DATA    = lire('data.js');
var CRON    = lire('api/cron-minuit.js');

var ko = 0, attendus = 0;
function att(n, c, detail) {
  attendus++;
  if (c) print('  ok  ' + n);
  else { print('  *** ' + n); if (detail !== undefined) print('        ' + detail); ko++; }
}
function compte(texte, motif) { return (texte.match(motif) || []).length; }
function bloc(source, nom) {
  var i = source.indexOf('async function ' + nom + '(');
  if (i < 0) i = source.indexOf('function ' + nom + '(');
  if (i < 0) throw new Error('introuvable : ' + nom);
  var j = source.indexOf('{', i), p = 0, k = j;
  while (k < source.length) {
    if (source[k] === '{') p++; else if (source[k] === '}') { p--; if (!p) break; }
    k++;
  }
  return source.slice(i, k + 1);
}

print('');
print('BANC DU COTE CLIENT DES SUBVENTIONS MUNICIPALES');
print('============================================================================');

// =============================================================================================
// 1. LA RESORPTION DE L'ANCIENNE CHAINE
// =============================================================================================
var ORGA_CODE = sansCommentaires(ORGA);

att('verifierSubventionMairie n existe plus comme fonction',
    ORGA_CODE.indexOf('function verifierSubventionMairie') < 0,
    'la fonction gelee doit etre supprimee, pas rebranchee');
att('et elle n est plus appelee nulle part',
    compte(ORGA_CODE, /verifierSubventionMairie\(/g) === 0,
    compte(ORGA_CODE, /verifierSubventionMairie\(/g) + ' appel(s) restant(s)');
att('son auxiliaire joursEcoulesDepuisMarqueurISO part avec elle',
    ORGA_CODE.indexOf('joursEcoulesDepuisMarqueurISO') < 0,
    'un auxiliaire sans appelant est un module mort');
att('le marqueur derniereSubventionJour n est plus ecrit',
    ORGA_CODE.indexOf('derniereSubventionJour') < 0,
    'le nouveau systeme n a aucun marqueur de journee : le jour vient du serveur');

// LA MEMOIRE DU GEL RESTE, ELLE. Un code dont on efface jusqu'au souvenir de sa dette invite a
// recommencer : le commentaire doit dire ce qui a ete supprime et pourquoi.
att('mais le commentaire de resorption explique ce qui a disparu',
    ORGA.indexOf("L'ANCIENNE CHAINE EST RESORBEE") >= 0
    && ORGA.indexOf('DEUX mecaniques') >= 0);
att('et il conserve la lecon du marqueur de journee partage',
    ORGA.indexOf('compteur PROPRE A CHAQUE PERSONNAGE') >= 0);

// =============================================================================================
// 2. L'ORDRE DU MAIRE EST DECLARE, ET A SON VRAI PRIX
// =============================================================================================
att('l ordre subvention_proposer est declare dans les DEUX bureaux du maire',
    compte(DATA, /fn:'subvention_proposer'/g) === 2,
    compte(DATA, /fn:'subvention_proposer'/g) + ' declaration(s) -- bureau_maire et bureau_maire_local');
att('il coute 2 PA et 0 FR, et il est reserve au poste de maire',
    compte(DATA, /fn:'subvention_proposer'[^}]*pa:2, cost:0/g) === 2
    && compte(DATA, /fn:'subvention_proposer'[^}]*requiresPost:'maire'/g) === 2,
    'payer_ordre refuse tout couple non declare : le miroir doit dire 2 PA');

// =============================================================================================
// 3. LE ROUTEUR NE FAIT PAS PAYER DEUX FOIS
// =============================================================================================
att('le routeur route l ordre vers doProposerSubvention',
    ROUTEUR.indexOf("if (fn === 'subvention_proposer')") >= 0);
att('et il ne lui transmet NI pa NI cost -- la porte facture elle-meme',
    ROUTEUR.indexOf('doProposerSubvention(); return;') >= 0,
    'passer pa/cost inviterait l ecran a appeler deduireCoutOrdre, donc a prelever deux fois');

var ECRAN = sansCommentaires(bloc(POLI, 'doProposerSubvention'));
var CONFIRME = sansCommentaires(bloc(POLI, 'confirmerPropositionSubvention'));

att('aucun des deux ecrans n appelle deduireCoutOrdre',
    ECRAN.indexOf('deduireCoutOrdre') < 0 && CONFIRME.indexOf('deduireCoutOrdre') < 0,
    'la porte appelle payer_ordre : un second prelevement couterait 4 PA au maire');
att('et l ecran recopie le paiement que le serveur a reellement ecrit',
    CONFIRME.indexOf('appliquerPaiementServeur(r.paiement)') >= 0,
    'l etat client n est qu une projection : il ne deduit pas les PA lui-meme');

// =============================================================================================
// 4. LE NAVIGATEUR NE CALCULE AUCUNE REGLE
// =============================================================================================
att('l ecran lit l enveloppe par la porte serveur',
    ECRAN.indexOf('sbSubventionEnveloppeLire()') >= 0);
att('il n invente ni le disponible ni la reserve',
    ECRAN.indexOf('e.disponible') >= 0 && ECRAN.indexOf('e.reserve') >= 0
    && ECRAN.indexOf('- e.reserve') < 0 && ECRAN.indexOf('e.solde -') < 0,
    'un disponible recalcule cote client finirait par differer de celui de la porte');
att('il ne decide pas qui est eligible : il affiche ce que le serveur lui donne',
    ECRAN.indexOf('e.eligibles') >= 0
    && ECRAN.indexOf('clubs_football') < 0 && ECRAN.indexOf('getClubLocal') < 0,
    'cet ecran ne sait pas ce qu est un club, et c est voulu');
att('il ne decide pas non plus qui peut repondre',
    ECRAN.indexOf('o.peut_repondre') >= 0);
att('une panne de lecture n est pas affichee comme une enveloppe vide',
    ECRAN.indexOf("e.ok !== true") >= 0 && ECRAN.indexOf('Rien n\\\'a été engagé') >= 0,
    'afficher zero pendant une indisponibilite inviterait a engager une somme fausse');

// =============================================================================================
// 5. LA REPONSE DE L'ORGANISATION
// =============================================================================================
var REPONSE = sansCommentaires(bloc(ORGA, 'repondreSubventionMunicipale'));
var BUDGET_CLUB_BRUT = sansCommentaires(bloc(ORGA, 'doConsulterBudgetClub'));

// CE QUI EST ENVOYE AU SERVEUR, ET RIEN D'AUTRE. L'epreuve porte sur les VERBES passes depuis
// les boutons, pas sur le corps de la fonction : celui-ci lit legitimement `r.statut` pour
// choisir son message, et confondre « lire l'issue rendue » avec « nommer l'issue » ferait
// rougir un code juste. Le seul geste dangereux serait d'ENVOYER un statut.
// Les quotes sont echappees dans le HTML genere (`\'accepter\'`) : le motif ne peut donc pas
// exiger une apostrophe nue, et il cherche le verbe entre la parenthese et sa fermeture.
att('les boutons n envoient que les deux verbes de la liste close',
    compte(BUDGET_CLUB_BRUT, /repondreSubventionMunicipale\([^)]*accepter/g) === 1
    && compte(BUDGET_CLUB_BRUT, /repondreSubventionMunicipale\([^)]*refuser/g) === 1
    && !/repondreSubventionMunicipale\([^)]*(acceptee|refusee|expiree|proposee)/.test(BUDGET_CLUB_BRUT),
    'un client qui nommerait le statut pourrait ecrire expiree lui-meme');
att('et le helper recoit cette variable, jamais un statut en dur',
    REPONSE.indexOf('sbSubventionRepondre(id, reponse)') >= 0);
att('elle lit le statut rendu par le serveur pour choisir son message',
    REPONSE.indexOf("r.statut === 'acceptee'") >= 0);
att('la course perdue a son propre message -- ce n est pas une panne',
    REPONSE.indexOf('course_perdue') >= 0
    && REPONSE.indexOf('Un autre dirigeant a répondu avant vous') >= 0);
att('et l ecran se recharge apres une reponse, pour ne pas garder un bouton mort',
    compte(REPONSE, /doConsulterBudgetClub\(\)/g) >= 2);

var BUDGET_CLUB = sansCommentaires(bloc(ORGA, 'doConsulterBudgetClub'));
att('l ecran du club ne montre que les propositions qui le concernent',
    BUDGET_CLUB.indexOf('p.beneficiaire === clubLocal.id') >= 0);
att('et il demande au serveur de quelles propositions je suis gestionnaire',
    BUDGET_CLUB.indexOf('sbSubventionsRecuesLire()') >= 0,
    'la liste des boutons vient du meme resolveur que la porte : pas de bouton refusable');

// =============================================================================================
// 6. AUCUNE ECRITURE FINANCIERE CLIENTE, AUCUN JUGEMENT DE JEU
// =============================================================================================
att('aucun ecran de subvention ne credite une caisse de club',
    ECRAN.indexOf('crediterBudgetClub') < 0 && CONFIRME.indexOf('crediterBudgetClub') < 0
    && REPONSE.indexOf('crediterBudgetClub') < 0,
    'le credit est fait par la porte, dans la meme transaction que le debit de l enveloppe');
att('aucun ecran ne porte de jugement de jeu sur une subvention',
    !/favoritisme|clientelisme|corruption/i.test(ECRAN + CONFIRME + REPONSE),
    'le systeme expose des faits ; les joueurs, la presse et les opposants interpretent');

// =============================================================================================
// 7. LES HELPERS NE TRANSMETTENT RIEN DE SENSIBLE
// =============================================================================================
var H1 = sansCommentaires(bloc(SUPA, 'sbSubventionProposer'));
var H2 = sansCommentaires(bloc(SUPA, 'sbSubventionRepondre'));
var H3 = sansCommentaires(bloc(SUPA, 'sbSubventionEnveloppeLire'));

att('sbSubventionProposer ne transmet que famille, beneficiaire et montant',
    H1.indexOf('p_famille') >= 0 && H1.indexOf('p_beneficiaire') >= 0 && H1.indexOf('p_montant') >= 0
    && H1.indexOf('p_ville') < 0 && H1.indexOf('p_poste') < 0 && H1.indexOf('p_pays') < 0);
att('sbSubventionEnveloppeLire ne transmet AUCUN argument',
    H3.indexOf('{}') >= 0 && H3.indexOf('p_ville') < 0,
    'la commune du maire est lue au serveur, pas annoncee par le navigateur');
att('sbSubventionRepondre ne transmet qu un identifiant et un verbe',
    H2.indexOf('p_id') >= 0 && H2.indexOf('p_reponse') >= 0 && H2.indexOf('p_montant') < 0);

var ARCHIVES = sansCommentaires(bloc(SUPA, 'sbSubventionsArchives'));
att('les archives publiques ne demandent que les propositions CLOSES',
    ARCHIVES.indexOf('statut=neq.proposee') >= 0,
    'une negociation en cours n est pas publique : seules les trois issues le sont');

// =============================================================================================
// 8. LA PASSE DE MINUIT EXPIRE CE QUI DOIT L ETRE
// =============================================================================================
att('le cron appelle subventions_expirer',
    CRON.indexOf("tacheQuotidienne('subventions_expirees'") >= 0
    && CRON.indexOf("sbRpc('subventions_expirer'") >= 0);
att('avec les entetes de service -- un cron n est pas un joueur',
    /sbRpc\('subventions_expirer',[^)]*HEADERS_SERVICE\)/.test(CRON));
att('et la tache est rapportee dans le corps de la passe',
    CRON.indexOf('subventionsExpirees, compromisResolus') >= 0,
    'une tache absente du rapport est une tache qu on ne verra pas echouer');
att('elle tourne APRES la cascade municipale, qui alimente l enveloppe',
    CRON.indexOf("tacheQuotidienne('budgets_municipaux'")
      < CRON.indexOf("tacheQuotidienne('subventions_expirees'"));

print('');
if (ko === 0) print('LES ' + attendus + ' EPREUVES SONT VERTES.');
else print('ECHEC : ' + ko + ' epreuve(s) sur ' + attendus + ' en defaut.');
