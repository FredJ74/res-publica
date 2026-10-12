// Banc STRUCTUREL du cote navigateur du PARQUET (12 octobre 2026 au soir).
// SOURCES: aucune -- ce banc lit les fichiers de production eux-memes, par readFile.
//
// POURQUOI STRUCTUREL. Ce que cette tranche change cote navigateur, c'est QUI decide et QUI
// voit : il n'y a aucun calcul a appeler. Le comportement des portes est eprouve en base par
// outils/bancs/banc-parquet-serveur.sql (32 epreuves, transaction annulee). Ici on mesure que
// les anciennes autorites ont disparu du client, que les nouvelles sont bien branchees, et que
// rien n'annonce au joueur une suite que le jeu ne tiendra pas.
var justice   = readFile('/Users/fredericjasseron/ResPublica/plateau-justice-economie.js');
var politique = readFile('/Users/fredericjasseron/ResPublica/plateau-politique.js');
var routeur   = readFile('/Users/fredericjasseron/ResPublica/plateau-router.js');
var donnees   = readFile('/Users/fredericjasseron/ResPublica/data.js');
var navigation= readFile('/Users/fredericjasseron/ResPublica/plateau-navigation.js');
var referents = readFile('/Users/fredericjasseron/ResPublica/api/_pnj-referents.js');
var persos    = readFile('/Users/fredericjasseron/ResPublica/api/_pnj-personnalites.js');
var pnj       = readFile('/Users/fredericjasseron/ResPublica/plateau-pnj.js');
var cron      = readFile('/Users/fredericjasseron/ResPublica/api/cron-minuit.js');

var ko = 0, attendus = 0;
function att(n, c, detail) {
  attendus++;
  if (c) print('  ok  ' + n);
  else { print('  *** ' + n); if (detail !== undefined) print('        ' + detail); ko++; }
}
function compte(t, m) { return (t.match(m) || []).length; }
// LE PIEGE DU COMMENTAIRE QUI NOMME CE QU'IL INTERDIT s'est referme trois fois en deux jours,
// dont une sur une preuve de migration. La mesure porte sur le CODE.
function codeSeul(t) {
  return t.split('\n').filter(function (l) { return !/^\s*\/\//.test(l); }).join('\n');
}
function bloc(t, d, f) {
  var i = t.indexOf(d); if (i < 0) return '';
  var j = t.indexOf(f, i + d.length); return j < 0 ? t.slice(i) : t.slice(i, j);
}

print('');
print('1. JUGE FONTAINE N EST PLUS UNE AUTORITE JUDICIAIRE');
att('son nom ne subsiste dans AUCUN code de data.js, seulement dans deux commentaires',
    codeSeul(donnees).indexOf('Juge Fontaine') < 0,
    compte(donnees, /Juge Fontaine/g) + ' occurrence(s) au total');
att('elle a quitte la cascade PNJ du cron',
    codeSeul(cron).indexOf("capitale: 'Juge Fontaine'") < 0
    && cron.indexOf("capitale: 'Honoré Cozetoujours (PNJ)'") >= 0);
att('elle a quitte la liste des titulaires de poste',
    codeSeul(donnees).indexOf("'Juge Fontaine'") < 0);
att('elle a quitte les referents',
    codeSeul(referents).indexOf('juge_fontaine:') < 0
    && referents.indexOf('honore_cozetoujours: {') >= 0);
att('elle a quitte les personnalites',
    codeSeul(persos).indexOf("'juge_fontaine'") < 0
    && persos.indexOf("'honore_cozetoujours'") >= 0);
att('elle a quitte la liste des referents du navigateur',
    codeSeul(pnj).indexOf("'juge_fontaine'") < 0
    && pnj.indexOf("'honore_cozetoujours'") >= 0);
// LA SEULE SURVIVANCE EST NARRATIVE, ET ELLE EST DELIBEREMENT NON TOUCHEE : l'enigme du portrait
// fait parler « Juge Fontaine » pour autoriser l'ouverture d'un coffre. Remplacer ce dialogue par
// Honore serait une decision de game design -- son caractere est a l'oppose -- donc le cahier des
// charges demandait de SIGNALER avant de muter. C'est signale, et rien n'est mute.
att('sa seule survivance est le dialogue de l enigme, laissee intacte',
    readFile('/Users/fredericjasseron/ResPublica/plateau-enigme-portrait.js')
      .indexOf('Juge Fontaine') >= 0);

print('');
print('2. LES DEUX TITRES DYNAMIQUES DU TRIBUNAL');
var casting = bloc(donnees, '"name": "Honoré Cozetoujours (PNJ)"', '"job": "procureur"');
att('Honore est President du Tribunal, Vice-president si un joueur tient le poste',
    donnees.indexOf('"roleSiPnjTitulaire": "Président du Tribunal"') >= 0
    && donnees.indexOf('"roleSiPjTitulaire":  "Vice-président du Tribunal"') >= 0);
att('Saad est Procureur, Substitut si un joueur tient le poste',
    donnees.indexOf('"roleSiPnjTitulaire": "Procureur de la République"') >= 0
    && donnees.indexOf('"roleSiPjTitulaire":  "Substitut du Procureur"') >= 0);
att('les deux restent presents quand le poste est pourvu',
    compte(casting + donnees.slice(donnees.indexOf('"name": "Procureur Saad"')), /"resteApresPourvoi": true/g) >= 1);
att('Honore porte la ville de son poste -- le juge est un poste de ville',
    donnees.indexOf('"posteCity": "capitale"') >= 0);
// LE MECANISME EST GENERIQUE, et il a fallu le corriger pour qu'il marche ici : il lisait le
// GABARIT, alors que le casting du Tribunal vient d'une surcharge d'empire.
att('le titre dynamique lit la liste REELLEMENT affichee, plus le gabarit',
    navigation.indexOf('personnesNormalesDeLaPiece(buildingId, roomId)') >= 0
    && bloc(navigation, 'async function ajusterTitrePnjDePoste', '\n}')
         .indexOf('renderPersonsList(liste || [])') >= 0);
att('et le repli sur le gabarit subsiste, pour que le banc du mecanisme reste mesurable',
    bloc(navigation, 'async function ajusterTitrePnjDePoste', 'const porteurs')
      .indexOf("BUILDINGS[buildingId]?.rooms?.[roomId]?.persons") >= 0);

print('');
print('3. LE GABARIT PARTAGE NE PORTE PLUS AUCUN CASTING');
att('la salle d audience du gabarit a une liste vide',
    bloc(donnees, "'tribunal': {\n    name: \"Tribunal de la Capitale\"", 'orders:')
      .indexOf('persons: [],') >= 0);
att('et les quatre empires declarent toujours le leur',
    donnees.indexOf('El Juez Manchado (PNJ)') >= 0
    && donnees.indexOf('Camarade Juge Pravdine (PNJ)') >= 0
    && donnees.indexOf('Cheikh Al-Verdict (PNJ)') >= 0
    && donnees.indexOf('Honoré Cozetoujours (PNJ)') >= 0);

print('');
print('4. LE POSTE DE PROCUREUR EXISTE, NATIONAL, NOMME PAR LE MINISTRE');
att('il est declare au referentiel des postes nommes',
    donnees.indexOf("procureur:   { label: 'Procureur de la Republique', nommePar: 'min_just', scope: 'pays'") >= 0);
att('il a un PNJ par defaut, et c est Saad',
    cron.indexOf("procureur:               'Procureur Saad'") >= 0);
att('il entre dans la cascade nationale du cron, nomme par min_just',
    cron.indexOf("{ posteId: 'procureur',               nommePar: 'min_just' }") >= 0);
att('le miroir serveur des postes nommes le connait',
    readFile('/Users/fredericjasseron/ResPublica/api/_referentiels-generes.js')
      .indexOf('"procureur"') >= 0);

print('');
print('5. LE MINISTRE DE LA JUSTICE NE CLASSE PLUS RIEN');
att('la fonction de classement a disparu',
    politique.indexOf('async function annulerAffaire(') < 0);
att('son ecran a disparu',
    politique.indexOf('async function ouvrirModalAffaires(') < 0);
att('plus aucun appel a la porte ministerielle',
    codeSeul(politique).indexOf("plainte_classer_ministere") < 0);
att('les deux routes ont disparu du routeur',
    codeSeul(routeur).indexOf("fn === 'annuler_poursuites'") < 0);
att('et l ordre a quitte le canon',
    codeSeul(donnees).indexOf("fn:'annuler_poursuites'") < 0);

print('');
print('6. LES DEUX ECRANS DE LA CHAINE');
var corpsParquet = bloc(justice, 'async function ouvrirParquet(', '\n// LES MESSAGES DE REFUS');
var corpsJuge    = bloc(justice, 'async function ouvrirDossiersJuge(', '\nconst JUGE_REFUS');
att('l ecran du parquet lit ses dossiers au serveur',
    corpsParquet.indexOf("sbRpc('parquet_dossiers')") >= 0);
att('les cinq actes du parquet sont branches',
    ['parquet_enqueter', 'parquet_non_lieu', 'parquet_poursuivre',
     'parquet_transmettre_juge', 'parquet_abandonner'].every(function (f) {
       return justice.indexOf("'" + f + "'") >= 0; }));
att('l ecran du juge lit son role au serveur, et pas l etat local',
    corpsJuge.indexOf("sbRpc('juge_dossiers')") >= 0
    && codeSeul(corpsJuge).indexOf('state.plaintesEnCours') < 0);
att('les trois actes du juge sont branches',
    justice.indexOf("'juge_suite_apres_abandon'") >= 0
    && justice.indexOf("'justice_relaxer'") >= 0
    && justice.indexOf("'justice_rendre_sentence'") >= 0);
att('le routeur mene au parquet et au role du juge',
    routeur.indexOf("if (fn === 'parquet')                 { ouvrirParquet(); return; }") >= 0
    && routeur.indexOf("if (fn === 'rendre_sentence')         { ouvrirDossiersJuge(pa, cost); return; }") >= 0);
// L ECRAN DU PARQUET N OFFRE QUE CE QUE L ETAT AUTORISE, et il le sait AVANT le clic : le serveur
// rend un drapeau de presence par dossier.
att('il n offre aucun acte quand le Procureur n est pas dans le bon tribunal',
    corpsParquet.indexOf("x.present !== true") >= 0);
att('et les deux decisions apres abandon sont offertes ensemble, distinctes',
    corpsJuge.indexOf("jugeSuiteAbandon(' + a + ',\\'arret\\')") >= 0
    && corpsJuge.indexOf("jugeSuiteAbandon(' + a + ',\\'poursuivre\\')") >= 0);

print('');
print('7. LES TROIS QUALIFICATIONS, ET AUCUNE INTERPRETATION');
att('les trois niveaux sont affiches ensemble quand ils existent',
    bloc(justice, 'function justiceQualificationsHtml', '\n}')
      .indexOf('categorie_alleguee') >= 0
    && bloc(justice, 'function justiceQualificationsHtml', '\n}').indexOf('qualification_parquet') >= 0
    && bloc(justice, 'function justiceQualificationsHtml', '\n}').indexOf('qualification_finale') >= 0);
att('le texte du plaignant est presente comme une DECLARATION, dans les deux ecrans',
    corpsParquet.indexOf("declare : ") >= 0 && corpsJuge.indexOf("declare : ") >= 0);
att('le non-lieu dit ce qu il ne signifie pas',
    justice.indexOf("ni que la plainte etait") >= 0
    && justice.indexOf("ni que la personne visee est innocente") >= 0);
att('la relaxe est annoncee comme un jugement, pas comme une absence de peine',
    justice.indexOf("La relaxe est un jugement, pas une absence de peine") >= 0);
att('la chronologie est rendue avec les libelles DU SERVEUR',
    bloc(justice, 'function justiceChronologieHtml', '\n}').indexOf('a.libelle || a.type') >= 0);

print('');
print('8. LE DEPOT DE PLAINTE NE PROMET PLUS DE SUITE AUTOMATIQUE');
var corpsPlainte = bloc(justice, 'async function soumettrePlaynte(', '\n// Verifie si une accusation');
att('les trois issues immediates ont disparu',
    codeSeul(corpsPlainte).indexOf("transmise_commissaire") < 0
    && codeSeul(corpsPlainte).indexOf("enquete_ouverte") < 0);
att('le dossier est annonce AU PARQUET',
    corpsPlainte.indexOf('Dossier transmis au parquet') >= 0);
att('la promesse de 24 h a disparu du formulaire',
    codeSeul(justice).indexOf('communique par mail dans 24h') < 0);
att('la categorie alleguee est collectee et transmise',
    justice.indexOf("id=\"plainte-categorie\"") >= 0
    && corpsPlainte.indexOf('p_categorie: categorie || null') >= 0);
att('et elle est presentee comme une appreciation, pas une accusation',
    justice.indexOf('votre appreciation, pas une accusation retenue') >= 0);

print('');
print('9. L ANCIEN ECRAN DU JUGE A DISPARU');
att('ouvrirRendreSentence n existe plus',
    justice.indexOf('async function ouvrirRendreSentence(') < 0);
att('et plus aucun ecran ne filtre le statut mort « deposee »',
    codeSeul(justice).indexOf("status === 'deposee'") < 0
    && codeSeul(politique).indexOf("status === 'deposee'") < 0);
att('le commissaire ne voit que les dossiers ou le parquet a ordonne une enquete',
    codeSeul(justice).indexOf("p.status === 'enquete' && (p.city === ville") >= 0);
att('et son bouton « classer sans suite » a disparu',
    codeSeul(justice).indexOf("deciderDossierPlainte(\\'' + id + '\\',\\'classer\\')") < 0);
// LA DEFENSE SE FILTRE SUR `au_parquet`, ET SUR LUI SEUL. L'epreuve a ete REECRITE : elle
// exigeait d'abord la reunion des cinq statuts vivants du parquet, en lisant l'ancien
// `status === 'deposee'` comme « une affaire en cours contre moi ». C'est faux -- l'ancienne
// chaine avait deux statuts vivants avant jugement et la porte serveur n'acceptait que le
// premier -- et la porte refuse desormais tout le reste (registre 20261012102519). Un ecran plus
// large que sa porte fait payer un ordre pour un refus certain.
att('la defense de l accuse se filtre sur au_parquet, et sur lui seul',
    bloc(justice, 'async function doDefense(', 'const cur =')
      .indexOf("p.status === 'au_parquet'") >= 0
    && bloc(justice, 'async function doDefense(', 'const cur =')
      .indexOf("'abandon_demande'") < 0);

print('');
if (ko === 0) print('LES ' + attendus + ' EPREUVES SONT VERTES.');
else print('ECHEC : ' + ko + ' epreuve(s) sur ' + attendus + ' en defaut.');
