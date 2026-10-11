// BANC CLIENT -- SUPPRESSION DE L'ANCIENNE UNIVERSITE ET REFONTE DES INTERACTIONS PNJ
// (12 octobre 2026).
// SOURCES: aucune -- ce banc lit les fichiers du depot lui-meme, par readFile.
//
// DEUX BLOCS, DEUX QUESTIONS.
//
// 1. L'ANCIEN SYSTEME `se_former` A-T-IL REELLEMENT DISPARU ? La question ne se mesure pas sur
//    une intention mais sur l'ABSENCE de ses six pieces : l'ordre, son effet declare, sa route,
//    ses deux handlers, et le terme `bonusFormation` dans la formule des caracteristiques.
//
// 2. LES SIX REGLES DE LA REFONTE PNJ SONT-ELLES TENUES ? Chacune est verifiee sur le CODE, pas
//    sur les commentaires -- plusieurs de ces commentaires nomment precisement ce qu'ils
//    interdisent, et un banc qui chercherait le mot brut serait vert pour la mauvaise raison.

var ko = 0, attendus = 0;
function att(n, c, detail) {
  attendus++;
  if (c) print('  ok  ' + n);
  else { print('  *** ' + n); if (detail !== undefined) print('        ' + detail); ko++; }
}
function lire(f) { return readFile('/Users/fredericjasseron/ResPublica/' + f); }
// Les lignes de commentaire retirees : un commentaire qui NOMME ce qu'il interdit ne doit pas
// faire echouer l'epreuve qui verifie l'interdiction.
function codeSeul(texte) {
  return texte.split('\n').filter(function (l) {
    return !/^\s*\/\//.test(l) && !/^\s*\*/.test(l);
  }).join('\n');
}
function compte(texte, motif) { return (texte.match(motif) || []).length; }

var dataJs   = lire('data.js');
var routeur  = lire('plateau-router.js');
var orgas    = lire('plateau-organisations-quetes.js');
var perso    = lire('plateau-personnage.js');
var pnjJs    = lire('plateau-pnj.js');
var illegal  = lire('plateau-actions-illegales-rumeurs.js');
var justice  = lire('plateau-justice-economie.js');

print('');
print('1. L ANCIEN SYSTEME UNIVERSITAIRE N EXISTE PLUS');
att("l ordre se_former a quitte data.js",
    codeSeul(dataJs).indexOf("fn:'se_former'") < 0);
att("son effet declare a quitte ORDER_EFFECTS",
    codeSeul(dataJs).indexOf('se_former:') < 0);
att("sa route a quitte le routeur",
    codeSeul(routeur).indexOf("fn === 'se_former'") < 0);
att("il a quitte la liste alwaysSuccess",
    codeSeul(routeur).indexOf("'se_former'") < 0);
att('doSeFormer n existe plus',
    orgas.indexOf('function doSeFormer') < 0);
att('appliquerFormation n existe plus',
    orgas.indexOf('function appliquerFormation') < 0);
att('et la suppression est expliquee dans le fichier',
    orgas.indexOf('SUIVRE UNE FORMATION A ETE SUPPRIME') >= 0);

print('');
print('2. LE BONUS DE FORMATION N A PLUS AUCUN EFFET');
// LA MESURE DECISIVE : getStatEffective ne lit plus le champ, et la somme ne le contient plus.
var iGSE = orgas.indexOf('function getStatEffective(');
var corpsGSE = codeSeul(orgas.slice(iGSE, orgas.indexOf('\n}', iGSE) + 2));
att('getStatEffective ne lit plus bonusFormation',
    corpsGSE.indexOf('bonusFormation') < 0, corpsGSE.slice(0, 200));
att('et la somme des termes ne le contient plus',
    corpsGSE.indexOf('base + bonusLocal + malusExcommunication') >= 0
    && corpsGSE.indexOf('base + bonus +') < 0);
att('plus aucun PRODUCTEUR de bonusFormation dans tout le depot',
    [dataJs, routeur, orgas, perso, pnjJs, illegal, justice].every(function (f) {
      return compte(codeSeul(f), /bonusFormation\s*=/g) === 0;
    }));
att('plus aucun LECTEUR de bonusFormation dans tout le depot',
    [dataJs, routeur, orgas, perso, pnjJs, illegal, justice].every(function (f) {
      return codeSeul(f).indexOf('bonusFormation') < 0;
    }));
att('le verrou journalier dernierFormationJour n a plus ni producteur ni lecteur',
    [orgas, perso, routeur].every(function (f) {
      return codeSeul(f).indexOf('dernierFormationJour') < 0;
    }));
att('la remise a zero au sommeil a disparu, et le fichier dit pourquoi',
    codeSeul(perso).indexOf('bonusFormation') < 0
    && perso.indexOf('LA REMISE A ZERO DU BONUS DE FORMATION A ETE RETIREE') >= 0);
// LA DEFENSE JUDICIAIRE : la dependance est coupee, et la nouvelle formule n est PAS inventee.
att('la defense judiciaire ne depend plus du bonus de formation',
    codeSeul(justice).indexOf('bonusFormation') < 0);
att('et le fichier dit que sa nouvelle formule reste a ecrire, sans l inventer',
    justice.indexOf('LA DEPENDANCE AU BONUS DE FORMATION EST SUPPRIMEE') >= 0
    && justice.indexOf('sera reconstruite au serveur dans le chantier judiciaire') >= 0);

print('');
print('3. LES AUTRES FONCTIONS DE L UNIVERSITE SONT INTACTES');
att("Donner une conference existe toujours",
    dataJs.indexOf("fn:'donner_conf'") >= 0);
att("Recruter des militants existe toujours",
    dataJs.indexOf("fn:'recruter_etud'") >= 0);
att('leurs deux handlers existent toujours',
    orgas.indexOf('function doDonnerConference') >= 0 || illegal.indexOf('function doDonnerConference') >= 0
    || lire('plateau-politique.js').indexOf('function doDonnerConference') >= 0);
att('et le stage a la caserne, voisin immediat du code retire, est intact',
    orgas.indexOf('async function doStageCaserne') >= 0);

print('');
print('4. PNJ : AJOUTER AU REPERTOIRE, ET L EXCEPTION D ACCUEIL');
var codePnj = codeSeul(pnjJs);
att("il ne reste qu UN seul bouton Ajouter au repertoire dans la fiche PNJ",
    compte(codePnj, /Ajouter au r[ée]pertoire<\/button>/g) === 1,
    compte(codePnj, /Ajouter au r[ée]pertoire<\/button>/g) + ' bouton(s)');
att('et il est garde par l exception d accueil',
    codePnj.indexOf('pnjOnboardingRepertoire(pnj)') >= 0);
att('la liste de l exception est declaree dans data.js',
    dataJs.indexOf('const PNJ_ONBOARDING_REPERTOIRE_NOMS') >= 0);
att('elle contient Jeremy -- dont l ajout FAIT AVANCER la quete d accueil',
    dataJs.indexOf("'Jérémy'") >= 0);
att("et le hook de la quete sur addContact est intact",
    codePnj.indexOf('queteAccueilProposerCarriere()') >= 0);
att('pnjOnboardingRepertoire compare le nom NU, suffixe (PNJ) retire',
    codePnj.indexOf("replace(' (PNJ)', '')") >= 0
    && pnjJs.indexOf('function pnjOnboardingRepertoire') >= 0);

print('');
print('5. PNJ : SALUER A DISPARU, ET SON GAIN AVEC');
att('le bouton Saluer n existe plus',
    codePnj.indexOf('Saluer</button>') < 0);
att('doSaluerPersonne n existe plus',
    pnjJs.indexOf('function doSaluerPersonne') < 0);
att('et aucun appelant ne subsiste',
    codeSeul(pnjJs + routeur + dataJs).indexOf('doSaluerPersonne') < 0);
att('le +2 INF du salut a disparu avec elle',
    codePnj.indexOf('salutationsDuJour') < 0);
att('et le fichier dit la verite sur la colonne persistee',
    pnjJs.indexOf('personnages_donnees.salutations_du_jour') >= 0);

print('');
print('6. PNJ : UN SEUL BOUTON DONNER, PUIS LE CHOIX');
att("il n y a plus de bouton Donner un objet",
    codePnj.indexOf('Donner un objet</button>') < 0);
att('il ne reste qu UN bouton Donner',
    compte(codePnj, /> Donner<\/button>/g) === 1,
    compte(codePnj, /> Donner<\/button>/g) + ' bouton(s)');
att('il ouvre le choix, pas directement le don d argent',
    codePnj.indexOf('ouvrirDonPnjChoix(') >= 0);
att('le choix propose les deux branches',
    pnjJs.indexOf('ouvrirDonPnjModal(') >= 0 && pnjJs.indexOf('ouvrirDonObjetPnjModal(') >= 0);
att("et il avertit que le don a un non-employe est sans retour",
    pnjJs.indexOf('Seul un vol le pourrait') >= 0);
att("l avertissement se fonde sur state.employes, l etat qui paie les employes",
    pnjJs.indexOf('(state.employes || [])') >= 0);

print('');
print('7. PNJ : VOLER ANNONCE SON GENRE, SANS REVELER L INVENTAIRE');
var codeIll = codeSeul(illegal);
att('la fiche PNJ ouvre desormais le choix de butin',
    codePnj.indexOf('ouvrirModalVolerChoix(') >= 0);
att('les deux genres sont proposes explicitement',
    illegal.indexOf('Voler de l\\\'argent</button>') >= 0 && illegal.indexOf('Voler un objet</button>') >= 0);
att('le tirage 60/40 a disparu',
    codeIll.indexOf('Math.random() < 0.6') < 0);
att('le genre annonce est celui qui est applique',
    codeIll.indexOf("let butin = (genre === 'objet') ? 'objet' : 'argent';") >= 0);
// LE POINT LE PLUS IMPORTANT : plus aucun repli croise, donc l issue ne renseigne plus sur ce
// que la cible possede.
att('aucun repli croise argent<->objet ne subsiste',
    codeIll.indexOf("butin = 'argent';\n") < 0
    && compte(codeIll, /butin = objetsEligibles\.length > 0/g) === 0);
att("les deux genres indisponibles aboutissent a la MEME issue : rien",
    compte(codeIll, /butin = 'rien';/g) === 2,
    compte(codeIll, /butin = 'rien';/g) + ' issue(s) rien');
att("l inventaire de la cible n est jamais affiche avant le vol",
    illegal.indexOf('Vous ne saurez ce qu\\\'elle porte qu\\\'en le prenant') >= 0);
att('la tentative reste possible : le choix ne depend pas de ce que la cible possede',
    codeIll.indexOf('function ouvrirModalVolerChoix') >= 0
    && codeIll.slice(codeIll.indexOf('function ouvrirModalVolerChoix'),
                     codeIll.indexOf('function ouvrirModalVoler(')).indexOf('inventory') < 0);
att('les quatre paliers de detection sont intacts',
    codeIll.indexOf('const identifie = jetFinal < 50;') >= 0
    && codeIll.indexOf('const detecteAnonyme = jetFinal >= 50 && jetFinal < 75;') >= 0);
att('le bonus de carriere au vol est intact',
    codeIll.indexOf('BONUS_CARRIERE_VOL[char?.career]') >= 0);

print('');
print('8. PNJ : LA ZONE DE QUESTION EST UN VRAI TEXTAREA');
att('ce n est plus un input d une ligne',
    codePnj.indexOf('id="pnj-question-libre" type="text"') < 0);
att('c est un textarea de plusieurs lignes',
    codePnj.indexOf('<textarea id="pnj-question-libre"') >= 0
    && codePnj.indexOf('rows="3"') >= 0);
att('avec retour a la ligne automatique',
    codePnj.indexOf('overflow-wrap:break-word') >= 0 && codePnj.indexOf('white-space:pre-wrap') >= 0);
att('Entree envoie, et le saut de ligne parasite est empeche',
    codePnj.indexOf('event.preventDefault();') >= 0
    && codePnj.indexOf('envoyerQuestion();') >= 0);
att('Maj/Ctrl/Alt + Entree passent a la ligne',
    codePnj.indexOf('event.shiftKey || event.ctrlKey || event.altKey || event.metaKey') >= 0);
att('le moteur conversationnel n est pas touche',
    pnjJs.indexOf('function envoyerQuestion(') >= 0 && pnjJs.indexOf('state._currentPnjEnc = enc;') >= 0);

print('');
print('9. PNJ : NEUTRALISER EST RESERVE AUX CLASSES ALPHA ET BETA');
att('l ordre generique est garde par la classe de la cible',
    codePnj.indexOf('const gammaCible = pnjEstGamma(pnj);') >= 0
    && codePnj.indexOf('if (!gammaCible) {') >= 0);
att('pnjEstGamma reconnait les deux familles gamma, et elles seules',
    pnjJs.indexOf('function pnjEstGamma') >= 0
    && codePnj.indexOf('assembleeSiegeParNomPnj(pnj.name)') >= 0
    && codePnj.indexOf('PNJ_TITULAIRES_DE_POSTE_NOMS') >= 0);
att('la liste des titulaires de poste est declaree dans data.js',
    dataJs.indexOf('const PNJ_TITULAIRES_DE_POSTE_NOMS') >= 0);
att('elle porte quinze noms -- la copie du registre en base',
    (function () {
      var i = dataJs.indexOf('const PNJ_TITULAIRES_DE_POSTE_NOMS');
      var bloc = dataJs.slice(i, dataJs.indexOf('];', i));
      return compte(bloc, /\n  ['"]/g) === 15;
    })(),
    'liste de taille inattendue');
// ET LA MECANIQUE INSTITUTIONNELLE DE L ASSEMBLEE N EST PAS TOUCHEE : un depute garde une entree,
// NOMMEE COMME TELLE, vers la meme porte serveur qu avant.
att('un depute PNJ garde une entree distincte, nommee Assemblee',
    codePnj.indexOf('Endormir ce député (Assemblée)') >= 0
    && codePnj.indexOf('} else if (siegeGamma) {') >= 0);
att('elle mene a la meme fonction qu avant -- rien de l Assemblee n est reecrit',
    compte(codePnj, /ouvrirModalAssassinat\(/g) === 2);
// LA DISTINCTION QUE LE BOUTON PROMET DOIT ETRE CELLE QUE LE GESTIONNAIRE APPLIQUE. Les deux
// predicats ne disent pas la meme chose : assembleeSiegeParNomPnj repond oui des que le NOM
// figure sur un siege, meme tenu aujourd'hui par un assistant parlementaire joueur ;
// neutraliserCibleEstDepute exige en plus que le siege soit effectivement occupe par le PNJ.
// C'est le second que confirmerAssassinatArme applique pour router vers l'Assemblee -- donc
// c'est le second qui doit garder le bouton, sinon le coup repartirait dans l'ordre generique.
att('le bouton Assemblee est garde par LE MEME predicat que le routage du gestionnaire',
    codePnj.indexOf('neutraliserCibleEstDepute(pnj)') >= 0
    && codeIll.indexOf('const siegeDepute = neutraliserCibleEstDepute(cible);') >= 0);
// ET C'EST LA PREUVE QUE LES DEUX ORDRES NE SE TOUCHENT PAS : la branche depute RETOURNE avant
// la moindre ligne de l'ordre generique -- avant deduireCoutOrdre, avant le tirage, avant les PA.
att('un depute ne traverse JAMAIS l ordre generique : la branche retourne avant',
    (function () {
      var i = codeIll.indexOf('if (siegeDepute) {');
      if (i < 0) return false;
      var j = codeIll.indexOf('const paCost = m.paPJ;', i);
      if (j < 0) return false;
      var entre = codeIll.slice(i, j);
      return entre.indexOf('await neutraliserDeputePnj(cible, mode, taux, siegeDepute);') >= 0
          && entre.indexOf('return;') >= 0;
    })(),
    'la sortie anticipee de la branche depute a disparu');
att('la porte serveur de l Assemblee est intacte',
    codeIll.indexOf('sbAssembleeNeutraliserDepute(state.char?.name, siege.id, mode, rq)') >= 0
    && codeIll.indexOf('function neutraliserDeputePnj') >= 0);
att('son bareme PA/PNJ propre est intact',
    codeIll.indexOf('function neutraliserTauxDepute') >= 0);
att('et les protections garde/police du vol et de la neutralisation sont intactes',
    codeIll.indexOf('function neutraliserPerCible') >= 0
    && codeIll.indexOf('function neutraliserPossedeArme') >= 0);

print('');
if (ko === 0) print('LES ' + attendus + ' EPREUVES SONT VERTES.');
else print('ECHEC : ' + ko + ' epreuve(s) sur ' + attendus + ' en defaut.');
