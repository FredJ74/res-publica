// Banc STRUCTUREL du cote navigateur de la peine serveur (12 octobre 2026).
// SOURCES: aucune -- ce banc lit les fichiers de production eux-memes, par readFile.
//
// POURQUOI STRUCTUREL. Ce que ce lot change cote navigateur, ce n'est pas un calcul : c'est QUI
// decide. Les valeurs ne sont plus composees ici, elles sont demandees au serveur et revalidees
// par lui. On ne peut donc pas l'eprouver en appelant les fonctions -- il n'y a plus rien a
// calculer a appeler. Ce qui se mesure, c'est que les anciennes autorites ont DISPARU du fichier
// et que les nouvelles portes sont bien celles qui sont appelees. Le COMPORTEMENT des portes,
// lui, est eprouve en base par outils/bancs/banc-justice-peine-serveur.sql (22 epreuves).
var justice = readFile('/Users/fredericjasseron/ResPublica/plateau-justice-economie.js');
var core    = readFile('/Users/fredericjasseron/ResPublica/plateau-core.js');

var ko = 0, attendus = 0;
function att(n, c, detail) {
  attendus++;
  if (c) print('  ok  ' + n);
  else { print('  *** ' + n); if (detail !== undefined) print('        ' + detail); ko++; }
}
function compte(texte, motif) { return (texte.match(motif) || []).length; }
// LE PIEGE DU COMMENTAIRE QUI NOMME CE QU'IL INTERDIT, rencontre deux fois le 11 octobre 2026 :
// ce fichier EXPLIQUE longuement ce qu'il a retire, donc chercher ces noms dans le texte brut les
// retrouve dans leur propre explication. La mesure porte sur le CODE.
function codeSeul(texte) {
  return texte.split('\n').filter(function (l) { return !/^\s*\/\//.test(l); }).join('\n');
}
function bloc(texte, depart, fin) {
  var i = texte.indexOf(depart);
  if (i < 0) return '';
  var j = texte.indexOf(fin, i + depart.length);
  return j < 0 ? texte.slice(i) : texte.slice(i, j);
}

var corpsSentence = bloc(justice, 'async function appliquerSentence(', '\nfunction getLocationsActives');
var corpsPlainte  = bloc(justice, 'async function soumettrePlaynte(', '\n// ');
var corpsQualif   = bloc(justice, 'function ouvrirQualificationSentence(', '\n// LA PLAGE EST CELLE DU SERVEUR');
var corpsModul    = bloc(justice, 'async function ouvrirModulationSentence(', '\n// LE PRONONCE RELIT');
var corpsPrononce = bloc(justice, 'async function prononcerSentence(', '\nasync function appliquerSentence(');
var corpsJuge     = bloc(justice, 'async function ouvrirDossiersJuge(', '\nconst JUGE_REFUS');
var corpsParquet  = bloc(justice, 'async function ouvrirParquet(', '\n// LES MESSAGES DE REFUS');

print('');
print('1. LA DUREE N EST PLUS COMPOSEE PAR LE NAVIGATEUR');
att('le « 3 jours en dur » a disparu de la sentence',
    codeSeul(corpsSentence).indexOf('let duree = 3') < 0);
att('les deux drapeaux ne modulent plus arithmetiquement la peine',
    codeSeul(corpsSentence).indexOf('duree - 1') < 0
    && codeSeul(corpsSentence).indexOf('duree + 2') < 0);
att('la duree de prison vient du serveur',
    codeSeul(corpsSentence).indexOf('const duree = joursServeur;') >= 0);
att('le QHS n ecrit plus 30 en dur',
    compte(codeSeul(corpsSentence), /jours: 30/g) === 0);
att('la torture ne compte plus ses antecedents dans le navigateur',
    codeSeul(corpsSentence).indexOf('sbGetActionsTracablesParAuteur') < 0);
att('l amende n est plus un 500 en dur',
    codeSeul(corpsSentence).indexOf('const montant = 500') < 0
    && codeSeul(corpsSentence).indexOf('amendeServeur') >= 0);

print('');
print('2. LA PORTE NE RECOIT PLUS NI BLOB D AFFAIRE NI CHAINE DE PEINE');
att('plus aucun p_affaire transmis',
    codeSeul(justice).indexOf('p_affaire: affaire') < 0);
att('plus aucune chaine de peine transmise',
    codeSeul(justice).indexOf('p_peine:') < 0);
att('la porte recoit l identifiant de l affaire',
    codeSeul(corpsSentence).indexOf('p_affaire_id: affaire.id') >= 0);
att('elle recoit l infraction canonique et le genre',
    codeSeul(corpsSentence).indexOf('p_infraction: infraction') >= 0
    && codeSeul(corpsSentence).indexOf('p_genre: type') >= 0);
att('elle recoit les nombres valides, pas un libelle',
    codeSeul(corpsSentence).indexOf('p_jours: joursServeur') >= 0
    && codeSeul(corpsSentence).indexOf('p_amende: amendeServeur') >= 0);
att('appliquerSentence recoit les valeurs du serveur en parametres',
    justice.indexOf('async function appliquerSentence(affaireId, type, infraction, joursServeur, amendeServeur, pa, cost)') >= 0);

print('');
print('3. LE JUGE QUALIFIE AVANT DE PRONONCER');
// LES CINQ SANCTIONS SONT TOUJOURS LA, mais l'ecran a change (12 octobre 2026 au soir).
// `ouvrirRendreSentence`, qui portait les cinq boutons et listait un statut mort (`deposee`), a
// ete remplacee par `ouvrirDossiersJuge`, qui lit le role au serveur. Les boutons y appellent
// donc `ouvrirQualificationSentence(' + a + ', ...)` et plus `(&quot;...&quot;, ...)`. L'epreuve
// porte sur LE NOMBRE DE GENRES OFFERTS, pas sur la forme de l'appel -- c'est ce qui compte :
// perdre le QHS ou la torture en changeant d'ecran aurait ete une regression silencieuse.
att('les cinq genres de sanction sont tous offerts au juge',
    ['prison', 'amende', 'amenagement', 'qhs', 'torture'].every(function (g) {
      return corpsJuge.indexOf("ouvrirQualificationSentence(' + a + '," + String.fromCharCode(92, 39) + g) >= 0;
    }),
    'longueur du bloc du juge : ' + corpsJuge.length);
att('et ils passent tous par l ecran de qualification du bareme',
    compte(corpsJuge, /ouvrirQualificationSentence\(' \+ a \+ '/g) === 5,
    compte(corpsJuge, /ouvrirQualificationSentence\(' \+ a \+ '/g) + ' appel(s)');
att('aucun bouton n appelle plus directement appliquerSentence',
    codeSeul(justice).indexOf('appliquerSentence(&quot;') < 0);
att('la liste des infractions est construite depuis le canon du navigateur',
    justice.indexOf('function infractionsCanoniques') >= 0
    && corpsQualif.indexOf('infractionsCanoniques()') >= 0);
att('elle couvre les DEUX tables du canon, resolues par getPeineParActe',
    bloc(justice, 'function infractionsCanoniques', '\n}').indexOf('ACTES_ILLEGAUX') >= 0
    && bloc(justice, 'function infractionsCanoniques', '\n}').indexOf('PEINES_ACTES') >= 0
    && bloc(justice, 'function infractionsCanoniques', '\n}').indexOf('getPeineParActe(id, false)') >= 0);
// VINGT-TROIS DES 39 INFRACTIONS N ONT PAS DE NOM PROPRE : elles heritent du libelle de leur
// categorie. Sans l identifiant a cote, le juge choisirait entre douze lignes « Delit mineur ».
att('l identifiant est affiche a cote du libelle',
    corpsQualif.indexOf('+ i.libelle +') >= 0 && corpsQualif.indexOf('+ i.id +') >= 0);
att('le motif de la plainte est presente comme une ALLEGATION, pas une qualification',
    corpsQualif.indexOf("Ce n\\'est pas une qualification juridique") >= 0);

print('');
print('4. LA PLAGE VIENT DU SERVEUR, PAS D UN CALCUL LOCAL');
att('l ecran de modulation interroge justice_peine_proposer',
    corpsModul.indexOf("sbRpc('justice_peine_proposer'") >= 0);
att('il ne recalcule aucune borne lui-meme',
    codeSeul(corpsModul).indexOf('* 0.5') < 0 && codeSeul(corpsModul).indexOf('* 1.5') < 0);
att('le prononce RELIT la plage avant d appliquer quoi que ce soit',
    corpsPrononce.indexOf("sbRpc('justice_peine_proposer'") >= 0
    && corpsPrononce.indexOf('appliquerSentence(') > corpsPrononce.indexOf("sbRpc('justice_peine_proposer'"));
att('une sanction imposee ignore la valeur du formulaire',
    corpsPrononce.indexOf('if (r.impose === true)') >= 0
    && corpsPrononce.indexOf('jours = surJours ? r.jours_min : 0;') >= 0);
att('le cas ou l attenuation est inexprimable est DIT au juge',
    corpsModul.indexOf('r.plancher_technique === true') >= 0);
att('le libelle affiche est celui du serveur',
    codeSeul(corpsSentence).indexOf('const peineOfficielle = vSentence.peine || details;') >= 0);

print('');
print('5. LA PLAINTE NE SE PAIE PLUS DANS LE NAVIGATEUR');
att('soumettrePlaynte n appelle plus deduireCoutOrdre',
    codeSeul(corpsPlainte).indexOf('deduireCoutOrdre') < 0);
att('elle ne recoit plus ni pa ni cost',
    justice.indexOf('async function soumettrePlaynte() {') >= 0);
att('le bouton ne lui transmet plus de montant',
    justice.indexOf('onclick="soumettrePlaynte()"') >= 0);
att('les refus de paiement sont nommes au plaignant',
    corpsPlainte.indexOf('pa_insuffisants:') >= 0
    && corpsPlainte.indexOf('fonds_insuffisants:') >= 0);
att('les soldes sont rafraichis depuis le verdict de la porte',
    corpsPlainte.indexOf('res.paiement.ok === true') >= 0);

print('');
print('6. CE QUI NE DEVAIT PAS BOUGER N A PAS BOUGE');
att('la garde « QHS et torture exigent une personne detenue » est intacte',
    corpsSentence.indexOf("(type === 'qhs' || type === 'torture') && !(await estActuellementDetenu(") >= 0);
att('le pre-controle d autorite avant toute consequence est intact',
    corpsSentence.indexOf("sbRpc('affaire_autorite_de'") >= 0
    && corpsSentence.indexOf("sbRpc('affaire_autorite_de'") < corpsSentence.indexOf('deduireCoutOrdre'));
att('sans peine appliquee, aucun jugement n est archive',
    corpsSentence.indexOf('if (!peineAppliquee)') >= 0);
att('le code penal du navigateur n a PAS ete touche -- c est lui le canon',
    compte(core, /const PEINES = \{/g) === 1 && compte(core, /const PEINES_ACTES = \{/g) === 1
    && compte(core, /const ACTES_ILLEGAUX = \{/g) === 1
    && core.indexOf('function getPeineParActe(acte, demasque)') >= 0);

print('');
if (ko === 0) print('LES ' + attendus + ' EPREUVES SONT VERTES.');
else print('ECHEC : ' + ko + ' epreuve(s) sur ' + attendus + ' en defaut.');
