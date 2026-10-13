// BANC CLIENT -- LES DOCUMENTS DU GREFFE ET LA SALLE DE REUNION DE L'UNIVERSITE
// (13 octobre 2026).
// SOURCES: aucune -- ce banc lit les fichiers du depot lui-meme, par readFile.
//
// QUATRE QUESTIONS, ET AUCUNE NE SE MESURE SUR UNE INTENTION.
//
// 1. LES CINQ ORDRES DU GREFFE SONT-ILS DECLARES, AUX BONS MONTANTS, DANS LES DEUX GREFFES ?
//    Un ordre declare dans un seul greffe serait une regle a deux vitesses selon la ville.
//
// 2. LE NAVIGATEUR FABRIQUE-T-IL ENCORE UN DOCUMENT ? L'ancien `faux_casier` etait un objet
//    pousse dans `state.inventory` par le client, avec `legal: false` ECRIT DEDANS -- un faux
//    qui s'annonce comme tel, et qui ne touchait rien. La mesure est l'ABSENCE : aucun des cinq
//    handlers ne doit ecrire dans l'inventaire, et aucun ne doit lire une authenticite.
//
// 3. LA SALLE DE REUNION EST-ELLE REELLEMENT SORTIE DU SYSTEME DES LOCATIONS ? Pas « le bouton
//    est parti » : ni `isLocationRoom`, ni `locationData`, ni `louer_local`, ni `gerer_local`.
//
// 4. « SUIVRE UNE FORMATION » EST-ELLE DESACTIVEE POUR DE VRAI ? Trois verrous, et les trois
//    sont mesures : le drapeau `bientot` (clic inerte), l'absence de route, et l'absence au
//    miroir des couts -- qui ferait refuser `ordre_inconnu` meme a un appel force.
//
// ET DEUX REGLES CONSERVEES, MESUREES POUR ELLES-MEMES : « Donner une conference » est INTACTE,
// et « Recruter des militants » existe toujours dans les deux pieces de l'universite.

var ko = 0, attendus = 0;
function att(n, c, detail) {
  attendus++;
  if (c) print('  ok  ' + n);
  else { print('  *** ' + n); if (detail !== undefined) print('        ' + detail); ko++; }
}
// SUBSTITUTIONS laisse une contre-epreuve remplacer UN SEUL fichier par une copie patchee, sans
// jamais toucher le depot. En exploitation la variable n'existe pas, donc rien ne change : c'est
// le banc qui doit rougir sur la copie, et un banc qu'on ne peut pas faire rougir ne prouve rien.
function lire(f) {
  if (typeof SUBSTITUTIONS !== 'undefined' && SUBSTITUTIONS && SUBSTITUTIONS[f]) {
    return readFile(SUBSTITUTIONS[f]);
  }
  return readFile('/Users/fredericjasseron/ResPublica/' + f);
}
// Les lignes de commentaire retirees : un commentaire qui NOMME ce qu'il interdit ne doit pas
// faire echouer l'epreuve qui verifie l'interdiction.
function codeSeul(texte) {
  return texte.split('\n').filter(function (l) {
    return !/^\s*\/\//.test(l) && !/^\s*\*/.test(l);
  }).join('\n');
}
function compte(texte, motif) { return (texte.match(motif) || []).length; }
function bloc(t, d, f) {
  var i = t.indexOf(d); if (i < 0) return '';
  var j = t.indexOf(f, i + d.length); return j < 0 ? t.slice(i) : t.slice(i, j);
}

var dataJs    = lire('data.js');
var routeur   = lire('plateau-router.js');
var justice   = lire('plateau-justice-economie.js');
var politique = lire('plateau-politique.js');
var orgas     = lire('plateau-organisations-quetes.js');
var perso     = lire('plateau-personnage.js');
var dataCode  = codeSeul(dataJs);

print('');
print('1. LES CINQ ORDRES DU GREFFE, DANS LES DEUX GREFFES');
// LES DEUX GREFFES : celui du tribunal de la capitale et celui du tribunal local, partage par
// Port-Sainte-Marie et Montrouge. Chaque ordre doit etre declare DEUX fois, et pas une.
var ORDRES_GREFFE = [
  { fn: 'casier_mon_extrait',           pa: 1, cost: 100, type: 'legal' },
  { fn: 'casier_extrait_enquete',       pa: 1, cost: 0,   type: 'legal' },
  { fn: 'orga_extrait_duplicata',       pa: 1, cost: 75,  type: 'legal' },
  { fn: 'greffe_corrompre_dossier',     pa: 3, cost: 300, type: 'illegal' },
  { fn: 'greffe_corrompre_faux_casier', pa: 3, cost: 300, type: 'illegal' }
];
ORDRES_GREFFE.forEach(function (o) {
  var motif = new RegExp("fn:'" + o.fn + "'", 'g');
  att("l ordre " + o.fn + " est declare dans les DEUX greffes",
      compte(dataCode, motif) === 2, compte(dataCode, motif) + ' declaration(s)');
  var ligne = dataCode.split('\n').filter(function (l) { return l.indexOf("fn:'" + o.fn + "'") >= 0; })[0] || '';
  att("  " + o.fn + " : " + o.pa + " PA, " + o.cost + " FR, type " + o.type,
      ligne.indexOf('pa:' + o.pa + ',') >= 0
      && ligne.indexOf('cost:' + o.cost + ',') >= 0
      && ligne.indexOf("type:'" + o.type + "'") >= 0, ligne.slice(0, 160));
});
// LES DEUX ORDRES ILLEGAUX PORTENT `tauxFixe`, parce que leur jet est tenu par le SERVEUR -- 25 %
// de decouverte, la valeur du precedent du fonctionnaire nomme. Sans ce drapeau, l'ecran
// afficherait un taux module par l'ISN que le serveur n'applique pas.
att('les deux corruptions du greffier declarent un taux FIXE',
    compte(dataCode, /tauxFixe:true/g) === 4,
    compte(dataCode, /tauxFixe:true/g) + ' declaration(s) de tauxFixe');

print('');
print('2. LE NAVIGATEUR NE FABRIQUE PLUS AUCUN DOCUMENT');
att('le faux casier a quitte DOCUMENTS_FALSIFIABLES',
    dataCode.indexOf("id:'faux_casier'") < 0);
att('les QUATRE autres documents falsifiables sont intacts',
    dataCode.indexOf("id:'fausse_identite'") >= 0
    && dataCode.indexOf("id:'faux_permis'") >= 0
    && dataCode.indexOf("id:'faux_contrat'") >= 0
    && dataCode.indexOf("id:'fausse_convocation'") >= 0);
// LES CINQ HANDLERS N'ECRIVENT PAS DANS L'INVENTAIRE. C'est la porte serveur qui ecrit l'objet
// sur la ligne du personnage ; le navigateur RELIT.
var HANDLERS = ['doCasierMonExtrait', 'confirmerCasierExtraitEnquete', 'confirmerExtraitDuplicata',
                'confirmerGreffeCorrompreDossier', 'confirmerGreffeCorrompreFauxCasier'];
HANDLERS.forEach(function (h) {
  var corps = codeSeul(bloc(justice, 'async function ' + h, '\n}\n'));
  att('  ' + h + ' n ecrit rien dans l inventaire',
      corps.length > 0 && corps.indexOf('state.inventory') < 0 && corps.indexOf('inventory.push') < 0,
      corps.length === 0 ? 'handler introuvable' : undefined);
  att('  ' + h + ' relit l inventaire au serveur',
      corps.indexOf('rafraichirInventaireDepuisServeur') >= 0);
});
att('la relecture de l inventaire interroge bien la base',
    codeSeul(bloc(justice, 'async function rafraichirInventaireDepuisServeur', '\n}\n'))
      .indexOf("sbGet('personnages'") >= 0);
// LA MISE EN PAGE D'UN DOCUMENT NE REVELE PAS SON AUTHENTICITE, et pour une raison structurelle :
// l'objet ne la porte pas. Un faux extrait s'affiche donc exactement comme un vrai.
var rendu = codeSeul(bloc(justice, 'function documentOfficielHtml', '\n}\n'));
att('la fiche d un document ne lit aucune authenticite',
    rendu.length > 0 && rendu.indexOf('authentique') < 0 && rendu.indexOf('casier_faux') < 0
    && rendu.indexOf('FAUX') < 0);
att('elle lit le contenu FIGE de l objet, et ne relit pas la base',
    rendu.indexOf('item.contenu') >= 0 && rendu.indexOf('sbRpc') < 0 && rendu.indexOf('sbGet') < 0);
att('la fiche d objet d inventaire sait afficher un document officiel',
    codeSeul(perso).indexOf("item.type === 'document_officiel'") >= 0
    && codeSeul(perso).indexOf('documentOfficielHtml(item)') >= 0);

print('');
print('3. LES SEPT ORDRES NEUFS SONT ROUTES AVANT TOUT PRELEVEMENT CLIENT');
// Chaque porte serveur appelle `payer_ordre` ELLE-MEME : un prelevement client en plus
// prelverait deux fois. La mesure est la POSITION de la route dans le fichier, avant l'appel
// generique a deduireCoutOrdre.
// LE POINT DE BASCULE EST L'APPEL GENERIQUE, pas la premiere mention du mot : `deduireCoutOrdre`
// est nommee des le dixieme caractere du fichier, dans un commentaire d'en-tete. L'ancre est
// donc la LIGNE D'APPEL du chemin generique, celle qui preleve.
var posCout = routeur.indexOf('const rPaiement = await deduireCoutOrdre(');
att('le point de prelevement generique du routeur est identifie', posCout > 0, 'position ' + posCout);
['casier_mon_extrait', 'casier_extrait_enquete', 'orga_extrait_duplicata',
 'greffe_corrompre_dossier', 'greffe_corrompre_faux_casier',
 'syndicat_etudiant_creer', 'syndicat_etudiant_gerer'].forEach(function (fn) {
  var pos = routeur.indexOf("fn === '" + fn + "'");
  att('  ' + fn + ' : route presente et placee avant deduireCoutOrdre',
      pos > 0 && (posCout < 0 || pos < posCout), 'route a ' + pos + ', cout a ' + posCout);
});

// L'ORDRE ET LA PORTE N'ONT PAS TOUJOURS LE MEME NOM, et une confusion entre les deux ne se voit
// pas a la lecture : elle rend un 404 PostgREST, affiche « Acces refuse ». L'ordre
// `orga_extrait_duplicata` est routee vers une porte qui s'appelle, elle,
// `organisation_extrait_duplicata` -- c'est le nom de l'ORDRE que la porte declare a
// `payer_ordre`, et le nom de la FONCTION que le navigateur doit appeler. L'epreuve mesure les
// SEPT appels, un par porte, et exige le nom exact de chacune.
var APPELS = [
  { ou: 'justice',  fn: 'doCasierMonExtrait',                porte: 'casier_mon_extrait' },
  { ou: 'justice',  fn: 'confirmerCasierExtraitEnquete',     porte: 'casier_extrait_enquete' },
  { ou: 'justice',  fn: 'confirmerExtraitDuplicata',         porte: 'organisation_extrait_duplicata' },
  { ou: 'justice',  fn: 'confirmerGreffeCorrompreDossier',   porte: 'greffe_corrompre_dossier' },
  { ou: 'justice',  fn: 'confirmerGreffeCorrompreFauxCasier',porte: 'greffe_corrompre_faux_casier' },
  { ou: 'orgas',    fn: 'confirmerSyndicatEtudiantCreer',    porte: 'syndicat_etudiant_domicilier' }
];
APPELS.forEach(function (a) {
  var src = a.ou === 'justice' ? justice : orgas;
  var corps = codeSeul(bloc(src, 'async function ' + a.fn, '\n}\n'));
  att('  ' + a.fn + ' appelle la porte ' + a.porte,
      corps.length > 0 && corps.indexOf("sbRpc('" + a.porte + "'") >= 0,
      corps.length === 0 ? 'handler introuvable' : undefined);
});
att('et aucun handler du greffe n appelle un ORDRE comme si c etait une porte',
    codeSeul(justice).indexOf("sbRpc('orga_extrait_duplicata'") < 0
    && codeSeul(orgas).indexOf("sbRpc('syndicat_etudiant_creer'") < 0);

print('');
print('4. LA SALLE DE REUNION EST SORTIE DU SYSTEME DES LOCATIONS');
var salle = bloc(dataJs, 'salle_reunion: {', '\n      }');
att('la piece existe toujours', salle.length > 0);
att('elle n est plus declaree comme un local a louer', salle.indexOf('isLocationRoom') < 0);
att('elle n a plus de donnees de location (prix, bonus)', salle.indexOf('locationData') < 0);
att('l ordre louer_local a quitte la piece', salle.indexOf("fn:'louer_local'") < 0);
att('l ordre gerer_local a quitte la piece', salle.indexOf("fn:'gerer_local'") < 0);
att('son nom ne dit plus « Local a louer »', salle.indexOf('Local à louer') < 0);
att('les DEUX familles d ordres de l arbitrage y sont, et elles seules',
    salle.indexOf("fn:'syndicat_etudiant_creer'") >= 0
    && salle.indexOf("fn:'syndicat_etudiant_gerer'") >= 0
    && salle.indexOf("fn:'recruter_etud'") >= 0
    && compte(salle, /fn:'/g) === 3, compte(salle, /fn:'/g) + ' ordre(s)');
var ligneCreer = salle.split('\n').filter(function (l) { return l.indexOf("fn:'syndicat_etudiant_creer'") >= 0; })[0] || '';
att('la domiciliation coute 2 PA et 150 FR',
    ligneCreer.indexOf('pa:2,') >= 0 && ligneCreer.indexOf('cost:150,') >= 0, ligneCreer.slice(0, 140));
// AUCUNE EXCLUSIVITE COTE NAVIGATEUR NON PLUS : l'ecran des syndicats liste CEUX QUI SONT LA,
// sans jamais refuser au motif qu'un local est occupe.
var ecranSyndicats = codeSeul(bloc(orgas, 'function ouvrirSyndicatsEtudiants', '\n}\n'));
att('l ecran des syndicats ne refuse aucun local deja occupe',
    ecranSyndicats.length > 0 && ecranSyndicats.indexOf('deja etablie') < 0
    && ecranSyndicats.indexOf('Local déjà occupé') < 0);
att('et il reutilise les ecrans d organisation qui existent',
    ecranSyndicats.indexOf('ouvrirGestionMembres') >= 0
    && ecranSyndicats.indexOf('demanderAdhesion') >= 0
    && ecranSyndicats.indexOf('ouvrirOrdresOrga') >= 0);
var creation = codeSeul(bloc(orgas, 'async function confirmerSyndicatEtudiantCreer', '\n}\n'));
att('la creation d un syndicat etudiant passe par la porte serveur, et par elle seule',
    creation.indexOf("sbRpc('syndicat_etudiant_domicilier'") >= 0
    && creation.indexOf('state.organisations.push') < 0
    && creation.indexOf('sbSaveOrganisation') < 0);

print('');
print('5. « SUIVRE UNE FORMATION » : TROIS VERROUS, ET AUCUN N EST COSMETIQUE');
var amphi = bloc(dataJs, 'amphi: {', '\n      }');
att('le bouton EXISTE et il est visible', amphi.indexOf("fn:'suivre_formation'") >= 0);
att('il porte le drapeau generique `bientot`', amphi.indexOf('bientot:') >= 0);
att('son infobulle dit exactement ce que l arbitrage demande',
    amphi.indexOf('Bientôt disponible : cet ordre permettra d\\\'acquérir une seconde carrière.') >= 0);
att('il ne coute rien du tout', amphi.indexOf("fn:'suivre_formation', label:'Suivre une formation', pa:0, cost:0") >= 0);
att('AUCUNE route ne mene a cet ordre', codeSeul(routeur).indexOf("'suivre_formation'") < 0);
// LE DRAPEAU EST GENERIQUE : il ne nomme aucun ordre dans le moteur de rendu, donc le prochain
// ordre differe n'aura pas besoin d'une ligne de plus.
var rendeur = codeSeul(bloc(politique, 'function renderRoomActions', '\nfunction ouvrirAudioguide'));
att('le moteur de rendu connait `bientot` sans nommer aucun ordre',
    rendeur.indexOf('o.bientot') >= 0 && rendeur.indexOf('suivre_formation') < 0);
att('un ordre `bientot` est GRISE', rendeur.indexOf('needsBientot || needsPost') >= 0);
att('et son clic n appelle aucune porte : un toast, et rien d autre',
    rendeur.indexOf("if (needsBientot) {") >= 0
    && bloc(rendeur, 'if (needsBientot) {', '} else if (needsPost)').indexOf('doOrder') < 0);
att('le moteur de rendu respecte aussi le taux FIXE du serveur',
    rendeur.indexOf("o.type === 'illegal' && !o.tauxFixe") >= 0);

print('');
print('6. CE QUI NE DEVAIT PAS BOUGER N A PAS BOUGE');
// « DONNER UNE CONFERENCE » EST CONSERVEE STRICTEMENT TELLE QUELLE : meme cout, meme taux, meme
// description, meme type. C'est son role pendant les elections qui l'exige.
att('« Donner une conference » est intacte, mot pour mot',
    amphi.indexOf("{fn:'donner_conf',    label:'Donner une conference',  pa:2, cost:0,   type:'legal', icon:'ti-microphone',  successRate:100, desc:'Soutenir un candidat en campagne (3 electeurs convertis) OU sensibiliser sur un theme (+2 indice, utilisable hors campagne).'}") >= 0);
att('« Recruter des militants » existe toujours dans les DEUX pieces de l universite',
    compte(amphi, /fn:'recruter_etud'/g) === 1 && compte(salle, /fn:'recruter_etud'/g) === 1);
// LES DEUX GARDES DESCENDUES AU SERVEUR SONT NOMMEES A L ECRAN : un refus serveur doit se lire.
var militants = codeSeul(bloc(orgas, 'async function doRecruterMilitants', '\n}\n'));
att('l ecran des militants nomme les deux refus serveur neufs',
    militants.indexOf('adhesion_syndicale_requise') >= 0
    && militants.indexOf('recrutement_du_jour_deja_fait') >= 0);
att('et il conserve ses pre-controles : un refus certain n atteint pas le serveur',
    militants.indexOf('dernierRecrutementMilitant') >= 0
    && militants.indexOf("o.type === 'syndicale'") >= 0);

print('');
if (ko > 0) throw new Error(ko + ' EPREUVE(S) ROUGE(S) sur ' + attendus);
print('LES ' + attendus + ' EPREUVES SONT VERTES.');
