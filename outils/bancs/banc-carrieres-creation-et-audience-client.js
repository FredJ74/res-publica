// Banc STRUCTUREL du cote navigateur des CARRIERES, de la NATURE PROFONDE, du CONSEILLER DE
// CREATION, de l'AUDIENCE et du GREFFE PUBLIC (12 octobre 2026, nuit).
// SOURCES: aucune -- ce banc lit les fichiers de production eux-memes, par readFile.
//
// POURQUOI STRUCTUREL. Le comportement des portes est eprouve EN BASE par
// outils/bancs/banc-carrieres-et-audience.sql (40 epreuves, transaction annulee). Ici on mesure
// ce qu'aucun banc SQL ne peut voir : que la nature profonde n'apporte plus un franc, que le
// conseiller ne SELECTIONNE rien, que l'ecran de l'empire n'a pas bouge, que le chat d'audience
// ne contient aucun bouton de plaidoirie, et que le Journal connait les douze faits judiciaires.
//
// LE PIEGE DU COMMENTAIRE : toute mesure d'ABSENCE porte sur le CODE, commentaires retires.
var RACINE = '/Users/fredericjasseron/ResPublica/';
function lire(f) { return readFile(RACINE + f); }

var donnees   = lire('data.js');
var creation  = lire('creation.js');
var index     = lire('index.html');
var i18n      = lire('i18n/resources.js');
var justice   = lire('plateau-justice-economie.js');
var routeur   = lire('plateau-router.js');
var conseil   = lire('api/conseiller-creation.js');
var collecte  = lire('api/_journal-collecte.js');
var genere    = lire('api/_referentiels-generes.js');

var ko = 0, attendus = 0;
function att(n, c, detail) {
  attendus++;
  if (c) print('  ok  ' + n);
  else { print('  *** ' + n); if (detail !== undefined) print('        ' + detail); ko++; }
}
function codeSeul(t) {
  var sansBlocs = t.replace(/\/\*[\s\S]*?\*\//g, ' ').replace(/<!--[\s\S]*?-->/g, ' ');
  return sansBlocs.split('\n').filter(function (l) { return !/^\s*\/\//.test(l); }).join('\n');
}
function bloc(t, debut, fin) {
  var i = t.indexOf(debut); if (i < 0) return '';
  var j = t.indexOf(fin, i); return j < 0 ? t.slice(i) : t.slice(i, j);
}
function compte(t, re) { return (t.match(re) || []).length; }
// Les catalogues de data.js, evalues pour de vrai : on mesure les VALEURS, pas le texte.
function litCatalogue(nom) {
  var i = donnees.indexOf('const ' + nom + ' = [');
  if (i < 0) return null;
  var j = donnees.indexOf('\n];', i);
  var src = donnees.slice(i + ('const ' + nom + ' = ').length, j + 2);
  return (new Function('return ' + src + ';'))();
}

print('BANC CARRIERES / NATURE / CONSEILLER / AUDIENCE -- COTE NAVIGATEUR');
print('');

print('1. LA NATURE PROFONDE N\'A PLUS QU\'UNE SEULE CONSEQUENCE MECANIQUE');
var natures = litCatalogue('ARCHETYPES');
att('les neuf natures sont toujours neuf', natures && natures.length === 9,
    natures ? natures.length : 'illisible');
// LES QUATRE CHAMPS SONT RETIRES, PAS MIS A ZERO (13 octobre 2026). `argBonus` etait deja a 0
// pour les neuf ; `infBonus`, `popBonus` et `disBonus` donnaient une popularite, une influence et
// une discretion de depart par caractere -- « Idealiste +25 POP », « Transgressif -15 POP » --
// donc un jugement collectif prononce avant le premier tour de jeu. L'epreuve mesure l'ABSENCE
// des champs eux-memes : un champ a zero invite a le remplir.
att('aucune nature ne porte plus argBonus / infBonus / popBonus / disBonus',
    natures.every(function (a) {
      return a.argBonus === undefined && a.infBonus === undefined
          && a.popBonus === undefined && a.disBonus === undefined; }),
    natures.filter(function (a) {
      return a.argBonus !== undefined || a.infBonus !== undefined
          || a.popBonus !== undefined || a.disBonus !== undefined;
    }).map(function (a) { return a.id; }).join(', '));
// LA CONTRE-MESURE : la seule consequence qui RESTE doit rester. Les trois ressources de depart
// sont les memes pour les neuf natures, et elles ne lisent plus la nature du tout.
att('les trois ressources de depart ne lisent plus la nature',
    /function resources\(\)\s*\{\s*return \{ inf:10, pop:10, dis:80 \};\s*\}/.test(creation),
    'resources() lit encore la nature ou a change de forme');
att('et le capital initial ne somme plus la nature',
    codeSeul(creation).indexOf('(ar?.argBonus||0)') < 0);
att('la structure mecanique est intacte : +2 / +2 / -2',
    natures.every(function (a) {
      var p = Object.keys(a.bonuses).map(function (k) { return a.bonuses[k]; });
      var m = Object.keys(a.malus).map(function (k) { return a.malus[k]; });
      return p.length === 2 && p[0] === 2 && p[1] === 2 && m.length === 1 && m[0] === -2;
    }));
att('les neuf identifiants sont INCHANGES -- aucune fiche existante a migrer',
    ['politician','authoritarian','oligarch','informer','legalist','believer',
     'shadow','anticapitalist','criminal'].every(function (id) {
      return natures.some(function (a) { return a.id === id; }); }));
att('les neuf nouveaux noms sont ceux de l\'arbitrage',
    ['Ambitieux','Autoritaire','Calculateur','Curieux','Legaliste',
     'Idealiste','Manipulateur','Solidaire','Transgressif'].every(function (nom) {
      return natures.some(function (a) { return a.name === nom; }); }),
    natures.map(function (a) { return a.name; }).join(', '));
att('aucun ancien libelle metier ou ideologique ne survit, ni dans data.js ni en i18n',
    !/Capitaliste|Anti-capitaliste|Homme de foi|Homme de l'ombre|Ordre et discipline|Diffuseur d'informations/.test(
      codeSeul(donnees) + codeSeul(i18n)));
att('et l\'ecran de creation n\'affiche plus de capital pour une nature',
    bloc(creation, "document.getElementById('arch-grid')", 'function selArch(')
      .indexOf('capitalLabel') < 0);
att('AUCUNE nature ne filtre une carriere : seules les ECOLES ferment des portes',
    natures.every(function (a) { return a.blocks === undefined; }));

print('');
print('2. LES DIX CARRIERES, INCHANGEES, ET LE SERVEUR LES RECOIT');
var carrieres = litCatalogue('CAREERS');
att('les dix familles professionnelles sont toujours dix', carrieres.length === 10);
att('et ce sont les memes identifiants',
    ['officer','business','magistrat','press','clergy','doctor','worker','intel','criminal_c','escort']
      .every(function (id) { return carrieres.some(function (c) { return c.id === id; }); }));
att('les quatre catalogues de creation sont GENERES pour le serveur, jamais ressaisis',
    ['CREATION_ORIGINES_SERVEUR','CREATION_ECOLES_SERVEUR',
     'CREATION_NATURES_SERVEUR','CREATION_CARRIERES_SERVEUR'].every(function (c) {
      return genere.indexOf('export const ' + c + ' =') >= 0; }));
att('l\'etape carriere annonce sa consequence AVANT la validation',
    creation.indexOf("t('creation.career.consequence')") >= 0
    && i18n.indexOf('professions specialisees auxquelles votre personnage pourra acceder') >= 0);
att('et elle annonce la seconde carriere unique a vie',
    i18n.indexOf('une seule autre carriere au cours de son existence') >= 0);

print('');
print('3. LE CONSEILLER CONSEILLE, IL NE CREE PAS');
att('l\'ecran du CHOIX DE L\'EMPIRE n\'est pas touche : le conseiller est pose APRES lui',
    index.indexOf('<div id="modal-conseiller"') > index.indexOf('<div id="s1" class="screen">')
    && index.indexOf('<div id="modal-conseiller"') < index.indexOf('<!-- SCREEN 2: ORIGIN -->'));
att('les deux chemins sont immediatement visibles',
    index.indexOf('onclick="conseillerPasser()"') >= 0
    && index.indexOf('onclick="conseillerDemander()"') >= 0);
att('il s\'ouvre une seule fois, a la sortie de l\'empire',
    creation.indexOf('conseillerOuvrirSiBesoin()') >= 0
    && bloc(creation, 'function conseillerOuvrirSiBesoin(', 'function conseillerPasser(')
         .indexOf('G.conseillerVu') >= 0);
att('la proposition vit dans G.conseil, et N\'ECRIT AUCUN des quatre choix',
    bloc(creation, 'async function conseillerDemander(', 'function echapperConseil(')
      .indexOf('G.conseil=prop') >= 0
    && !/G\.(origin|school|archetype|career)\s*=/.test(
         bloc(creation, 'async function conseillerDemander(', 'function echapperConseil(')));
att('le conseil ne devient qu\'une PASTILLE sur la carte conseillee',
    compte(creation, /marqueConseil\('/g) === 4
    && creation.indexOf('conseil-pastille') >= 0);
att('le navigateur revalide la proposition contre ses propres catalogues',
    bloc(creation, 'function conseilValide(', 'async function conseillerDemander(')
      .indexOf('(ca.blocks||[]).includes(sc.id)') >= 0);
att('un conseiller indisponible ne bloque pas la creation',
    creation.indexOf("t('creation.conseiller.unavailable')") >= 0);

print('');
print('4. L\'ENDPOINT DU CONSEILLER : LES REGLES VIENNENT DU SERVEUR');
att('le prompt est bati depuis les catalogues GENERES, pas depuis le navigateur',
    conseil.indexOf("from './_referentiels-generes.js'") >= 0
    && conseil.indexOf('CREATION_CARRIERES_SERVEUR.map') >= 0);
att('le navigateur n\'envoie que l\'empire et un texte libre',
    bloc(conseil, 'function validerPayload(', 'function ligneEffets(')
      .indexOf("['empire', 'souhait', 'lang', 'historique']") >= 0);
att('la sortie est REVALIDEE contre les memes catalogues, et un id inconnu la rejette',
    bloc(conseil, 'function valider(', 'export default')
      .indexOf('if (!dans(CREATION_ORIGINES_SERVEUR, prop.origin)) return null;') >= 0);
att('une carriere que les etudes proposees ferment est rejetee, dans les DEUX sens',
    bloc(conseil, 'function valider(', 'export default')
      .indexOf('(carriere.blocks || []).includes(prop.school)') >= 0
    && bloc(conseil, 'function valider(', 'export default')
         .indexOf('(ecole.blocks || []).includes(prop.career)') >= 0);
att('une reponse mal formee ne corrompt rien : fail closed',
    conseil.indexOf("catch (e) { brut = null; }") >= 0
    && conseil.indexOf("if (!prop) return res.status(422)") >= 0);
att('l\'appel est authentifie pour de vrai',
    conseil.indexOf('await joueurAuthentifie(req)') >= 0);
att('la regle de la seconde carriere unique est dans le prompt',
    conseil.indexOf('AU MAXIMUM UNE seconde') >= 0);
att('le cas « je ne sais pas » est explicitement prevu',
    conseil.indexOf("qu'il ne sait pas") >= 0 && conseil.indexOf('polyvalent') >= 0);
att('et le conseiller n\'est PAS un optimiseur de build',
    conseil.indexOf('meilleur build') >= 0 && conseil.indexOf('optimiseur de build') >= 0);

print('');
print('5. LES TEMOINS DU PLAIGNANT PARTENT AVEC LA PLAINTE');
att('le champ existe dans l\'ecran de depot', justice.indexOf("id=\"plainte-temoins\"") >= 0);
att('et il voyage dans LE MEME appel que la plainte',
    bloc(justice, 'async function soumettrePlaynte(', 'const res =')
      .indexOf('p_temoins:') >= 0);
att('l\'ecran dit que c\'est maintenant ou jamais',
    justice.indexOf("une fois la") >= 0
    && justice.indexOf('vous ne pourrez plus en ajouter') >= 0);
att('et le sort de chaque temoin est rendu au plaignant',
    justice.indexOf('temoins_cites') >= 0 && justice.indexOf('temoins_ecartes') >= 0);

print('');
print('6. L\'AUDIENCE : UN JOUR, UN LIEU, UNE PAROLE');
att('le juge fixe le jour, et le consentement du prevenu est une porte a part',
    justice.indexOf("sbRpc('justice_audience_fixer'") >= 0
    && justice.indexOf("sbRpc('justice_audience_consentir'") >= 0);
att('l\'ecran ne calcule AUCUN minimum lui-meme',
    bloc(justice, 'async function audienceFixer(', 'async function audienceConsentir(')
      .indexOf('+ 3') < 0);
att('le consentement est propose au PREVENU, sur sa fiche',
    justice.indexOf("audienceConsentir(\\'") >= 0
    && bloc(justice, 'function justiceSituationHtml(', 'appelables.forEach')
         .indexOf('consent-jour-') >= 0);
att('le chat existe, lit et ecrit par deux portes serveur',
    justice.indexOf("sbRpc('justice_audience_lire'") >= 0
    && justice.indexOf("sbRpc('justice_audience_ecrire'") >= 0);
att('le droit d\'ecrire vient du SERVEUR, jamais du role affiche',
    bloc(justice, 'async function rafraichirChatAudience(', 'async function audienceEcrire(')
      .indexOf('v.je_peux_ecrire') >= 0);
att('les messages sont affiches echappes, et les retours a la ligne conserves',
    bloc(justice, 'async function rafraichirChatAudience(', 'async function audienceEcrire(')
      .indexOf("justiceEch(m.texte).replace(/\\n/g, '<br>')") >= 0);
// MESURE SUR DES IDENTIFIANTS, ET DANS LE BLOC DE L'AUDIENCE SEULEMENT. Chercher ces mots dans
// tout le fichier attrapait trois textes legitimes : le refus « un crime ne se regle pas par une
// plaidoirie expeditive », la notice qui PROMET qu'on ne juge pas la sincerite d'une deposition,
// et une « chance de convaincre » qui appartient a une autre mecanique. Une mesure d'absence qui
// trouve la phrase expliquant l'interdiction ne mesure rien.
var audienceBloc = bloc(justice, '// LE CHAT JUDICIAIRE', 'async function ouvrirAffairesPubliques(')
                 + bloc(justice, 'async function ouvrirAudienceJuge(', 'async function audienceFixer(');
att('AUCUN bouton de plaidoirie, de relaxe demandee ni de score dans toute l\'audience',
    !/onclick="[a-zA-Z]*(Plaider|Relaxe|Convaincre|Noter)/.test(audienceBloc)
    && !/function\s+[a-zA-Z]*(plaider|noterPlaidoirie|scorer)/.test(codeSeul(audienceBloc))
    && !/credibilite|sincerite|score/.test(codeSeul(audienceBloc)));
att('et AUCUNE IA ne touche aux debats',
    bloc(justice, '// LE CHAT JUDICIAIRE', 'async function ouvrirAffairesPubliques(')
      .indexOf('/api/') < 0);

print('');
print('7. LE GREFFE PUBLIC, ET CE QU\'IL NE DIT PAS');
att('les deux ecrans publics existent et sont routes',
    justice.indexOf('async function ouvrirAffairesPubliques(') >= 0
    && justice.indexOf('async function ouvrirArchivesGreffe(') >= 0
    && routeur.indexOf("fn === 'greffe_affaires'") >= 0
    && routeur.indexOf("fn === 'greffe_archives'") >= 0);
att('les trois ordres neufs sont dans les DEUX tribunaux',
    compte(donnees, /\{fn:'greffe_affaires',/g) === 2
    && compte(donnees, /\{fn:'greffe_archives',/g) === 2
    && compte(donnees, /\{fn:'audience_salle',/g) === 2);
att('le registre public n\'affiche ni motif, ni plaignant, ni preuve',
    ['a.motif', 'a.plaignant', 'a.preuves', 'a.audition']
      .every(function (m) {
        return bloc(justice, 'async function ouvrirAffairesPubliques(',
                    'async function ouvrirArchivesGreffe(').indexOf(m) < 0; }));
att('les archives montrent la SUITE des actes, pas leur contenu',
    bloc(justice, 'async function ouvrirArchivesGreffe(', 'async function ouvrirAudienceDepuisLaSalle(')
      .indexOf('x.donnees') < 0);

print('');
print('8. LE JOURNAL CONNAIT LES FAITS JUDICIAIRES');
// TREIZE DEPUIS LE 13 OCTOBRE 2026, et le treizieme est arrive avec la decision qu'il publie :
// `justice_enquete_ouverte_par_le_juge`, le juge qui ouvre l'enquete malgre le non-lieu du
// parquet. Un type absent de TYPES_CHRONIQUE est JETE EN SILENCE par la collecte -- c'est
// arrive a la fuite et au scandale le 12 septembre 2026 -- donc cette liste doit grandir avec
// le registre `justice_faits_publics`, et jamais apres lui.
att('les treize types judiciaires sont mappes -- sinon ils seraient jetes en silence',
    ['justice_non_lieu','justice_poursuites','justice_abandon_parquet','justice_poursuite_maintenue',
     'justice_arret','justice_requalification','justice_condamnation','justice_relaxe',
     'justice_appel','justice_jugement_appel','justice_audience_fixee','justice_audience',
     'justice_enquete_ouverte_par_le_juge']
      .every(function (t) { return new RegExp('\\n\\s*' + t + ':(\\s|$)').test(collecte); }));
att('et ils sont tous du domaine justice',
    compte(collecte, /justice_[a-z_]+:\s*\{ domaine: 'justice'/g) === 13);

print('');
if (ko === 0) print('LES ' + attendus + ' EPREUVES SONT VERTES.');
else print('ECHEC : ' + ko + ' epreuve(s) sur ' + attendus + ' en defaut.');
