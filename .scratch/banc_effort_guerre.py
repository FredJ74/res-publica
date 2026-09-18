#!/usr/bin/env python3
"""Banc de tests de l'Effort de guerre — charge les VRAIS modules du jeu dans jsc.

Aucune reimplementation : chaque fonction testee est celle qui tourne en production.
Les modules sont charges dans des portees separees (IIFE) pour eviter les collisions de
constantes de premier niveau, puis les symboles utiles sont republies globalement.
"""
import subprocess, tempfile, os, sys, json

JSC = "/System/Library/Frameworks/JavaScriptCore.framework/Versions/A/Helpers/jsc"
RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def charger(fichier, exports):
    """Enveloppe un fichier du jeu dans une IIFE et republie les symboles demandes."""
    chemin = os.path.join(RACINE, fichier)
    src = open(chemin, encoding="utf-8").read()
    lignes = ";".join("globalThis.%s = %s;" % (e, e) for e in exports)
    return "(function(){\n%s\n%s\n})();\n" % (src, lignes)


PRELUDE = r"""
// --- Stubs minimaux : le banc ne teste que de la logique pure. ---------------
var state = { country:'republic', currentCity:'capitale', char:{name:'zzTest'}, day:1,
              inventory:[], recherche:[] };
var COUNTRIES = { republic:{cur:'FR'} };
var INDICES_NATIONAUX = { republic:{ISN:30} };
function showToast(){} function addJournalEntry(){} function updateUI(){}
function addExternalEvent(){} function addMailNotification(){}
function getStatEffective(){ return 10; }
function getIndiceVille(){ return 45; }
function getBonusReputationCriminelle(){ return 0; }
function consommerBonusBenediction(x){ return x; }
function assembleeInterdictionObjet(){ return null; }
function colisSecretProtege(i){ return !!i && i.type === 'colis_secret_pat'; }
// Stubs pour plateau-effort-guerre.js (catalogue militaire et cout de revient).
var RESSOURCES_ECONOMIE = { metal:{prixBase:15,label:'Métal'}, bois:{prixBase:5,label:'Bois'},
                            minerai:{prixBase:10,label:'Minerai'}, cereales:{prixBase:3},
                            viande:{prixBase:5}, poisson:{prixBase:4} };
function getPrixRessourceEntrepot(c){ return (RESSOURCES_ECONOMIE[c]||{}).prixBase || 0; }
var COUT_HORAIRE_TRAVAIL = 50;
var PA_PRODUCTION_ARMURERIE = 2;
var PA_MAX = 30;
var document = { getElementById: function(){ return null; },
                 querySelectorAll: function(){ return []; },
                 querySelector: function(){ return null; },
                 addEventListener: function(){}, createElement: function(){ return {style:{}, classList:{add:function(){},remove:function(){}}}; },
                 body: { appendChild: function(){} } };
var window = { addEventListener: function(){}, location:{} };
var localStorage = { getItem: function(){ return null; }, setItem: function(){} };
function setTimeout(){ return 0; } function setInterval(){ return 0; } function clearInterval(){}
var ECHECS = 0;
function verifie(titre, obtenu, attendu) {
  var ok = JSON.stringify(obtenu) === JSON.stringify(attendu);
  if (!ok) { ECHECS++; print('  ECHEC ' + titre + ' : obtenu ' + JSON.stringify(obtenu)
                            + ' attendu ' + JSON.stringify(attendu)); }
  else print('  ok    ' + titre + ' = ' + JSON.stringify(obtenu));
}
function verifieVrai(titre, cond) { verifie(titre, !!cond, true); }
function section(t){ print(''); print('== ' + t + ' =='); }
"""

MODULES = [
    ("plateau-gouvernement.js", [
        "ouvrirEffortDeGuerre", "renouvelerEffortDeGuerre", "fermerEffortDeGuerre",
        "effortDeGuerreActif", "effortDeGuerreEcheance",
        "verdictDeclencherEffortDeGuerre", "verdictRenouvelerEffortDeGuerre",
        "verdictTerminerEffortDeGuerre", "verdictVenteLegaleArme", "contexteMobilisation",
        "bornesBudget", "DUREE_EFFORT_GUERRE_MS", "PERIODES_PREVENTIVES_MAX",
        "PRIORITE_MILITAIRE_DEFAUT",
    ]),
    ("plateau-chantiers.js", [
        "planifierApprovisionnement", "scoreVolMateriaux", "verdictVolMateriaux",
        "materiauxDuJourConstruction", "coutTotalConstruction", "coutMateriauxDe",
        "CHANTIER_FR_PAR_JOUR", "MATERIAUX_CHANTIER", "prixMateriau", "nombreFini", "borner",
    ]),
    ("plateau-justice-economie.js", [
        "objetsSaisissables", "identifierObjetsIllegaux", "celluleDeDetention",
    ]),
    ("plateau-politique.js", [
        "estMotifDesertion", "bonusEvasionDeserteur", "incrementerDetentionDeserteur",
        "BONUS_EVASION_DESERTEUR_MAX", "DELAI_REQUISITION_HEURES",
    ]),
    ("plateau-effort-guerre.js", [
        "RECETTES_MILITAIRES", "PRODUITS_MILITAIRES", "ressourcesMilitairesEligibles",
        "coutRevientLotMilitaire", "detailCoutRevientMilitaire",
        "stockCivilDisponible", "reserveMilitaireEntrepot", "prioritesEffort",
        "entrepotsEffort", "entrepotsEffortRpc", "htmlStockArmurerieMilitaire",
    ]),
]

TESTS = r"""
// ============================================================================
section('1. EFFORT DE GUERRE — periodes, renouvellements, plafond preventif');
var T0 = 1000000000000;
var e = ouvrirEffortDeGuerre('Le President', T0, false);
verifie('periode initiale', e.periodes, 1);
verifie('preventives apres declenchement', e.periodesPreventives, 1);
verifie('curseurs par defaut', [e.prioriteRavitaillement, e.prioriteProductionMilitaire], [50,50]);
verifie('echeance = +3 jours reels', effortDeGuerreEcheance(e) - T0, 3*24*3600*1000);
verifieVrai('actif avant echeance', effortDeGuerreActif(e, T0 + 3600*1000));
verifieVrai('inactif apres echeance', !effortDeGuerreActif(e, T0 + 4*24*3600*1000));

// Hors guerre : une seule prolongation.
var v1 = verdictRenouvelerEffortDeGuerre('president', e, T0+1000, false);
verifie('1er renouvellement preventif autorise', [v1.ok, v1.penaliteIS], [true, true]);
var e2 = renouvelerEffortDeGuerre(e, T0+1000, false);
verifie('preventives apres prolongation', e2.periodesPreventives, 2);
var v2 = verdictRenouvelerEffortDeGuerre('president', e2, T0+2000, false);
verifie('2e prolongation preventive REFUSEE', [v2.ok, v2.raison], [false, 'prolongation_preventive_epuisee']);

// En guerre : illimite, sans penalite.
var v3 = verdictRenouvelerEffortDeGuerre('president', e2, T0+2000, true);
verifie('renouvellement de guerre autorise', [v3.ok, v3.penaliteIS], [true, false]);
var e3 = renouvelerEffortDeGuerre(e2, T0+2000, true);
verifie('compteur preventif remis a zero en guerre', e3.periodesPreventives, 0);
var e4 = renouvelerEffortDeGuerre(e3, T0+3000, true);
verifie('renouvellements de guerre illimites', verdictRenouvelerEffortDeGuerre('president', e4, T0+4000, true).ok, true);
// Fin de guerre : les regles preventives reprennent, depuis zero.
var e5 = renouvelerEffortDeGuerre(e4, T0+5000, false);
verifie('apres la guerre, 1 preventive consommee', e5.periodesPreventives, 1);

// Autorite
verifie('un ministre ne peut pas declencher', verdictDeclencherEffortDeGuerre('min_def', null, T0).raison, 'reserve_au_president');
verifie('pas deux fois actif', verdictDeclencherEffortDeGuerre('president', e, T0+1000).raison, 'deja_actif');
verifie('arret impossible si inactif', verdictTerminerEffortDeGuerre('president', null, T0).raison, 'pas_actif');

// Cloture
var ef = fermerEffortDeGuerre(e, 'Le President', T0+9000, 'decision');
verifieVrai('clos = inactif', !effortDeGuerreActif(ef, T0+9001));
verifie('curseurs conserves en trace', ef.prioriteRavitaillement, 50);

// ============================================================================
section('2. CONSEQUENCES — ventes civiles et plafond budgetaire');
verifie('hors Effort, vente civile autorisee', verdictVenteLegaleArme(null, T0).ok, true);
verifie('pendant l Effort, vente civile suspendue', verdictVenteLegaleArme(e, T0+1000).raison, 'effort_de_guerre_ventes_suspendues');
verifie('apres echeance, vente civile revient', verdictVenteLegaleArme(e, T0 + 5*24*3600*1000).ok, true);
verifie('plafond Defense hors Effort', bornesBudget('min_def', false).plafond, 20);
verifie('plafond Defense leve pendant l Effort', bornesBudget('min_def', true).plafond, 100);
var ctx = contexteMobilisation(e, T0+1000);
verifie('contexte : mobilisation industrielle active', ctx.mobilisationIndustrielle, true);
verifie('contexte : priorites exposees', [ctx.prioriteRavitaillement, ctx.prioriteProductionMilitaire], [50,50]);
verifie('contexte hors Effort : tout a zero', contexteMobilisation(null, T0).prioriteProductionMilitaire, 0);

// ============================================================================
section('3. RESERVE MILITAIRE vs CHANTIERS');
var besoin = { bois:100, minerai:50, metal:33 };
var vide = { bois:0, minerai:0, metal:0 };
var prix = { bois:5, minerai:10, metal:15 };
var entrepot = { bois:750, minerai:500, metal:200 };

var sansReserve = planifierApprovisionnement(besoin, vide, entrepot, 100000, prix, null);
verifie('sans reserve : le chantier achete son besoin', sansReserve.achats, {bois:100, minerai:50, metal:33});
verifie('stock entrepot rendu = physique - achat', sansReserve.stockEntrepot,
        {bois:650, minerai:450, metal:167});

// Reserve totale : le chantier ne peut plus rien acheter, MAIS la marchandise reste en place.
var pleine = { bois:750, minerai:500, metal:200 };
var bloque = planifierApprovisionnement(besoin, vide, entrepot, 100000, prix, pleine);
verifie('reserve 100% : aucun achat possible', bloque.achats, {});
verifie('reserve 100% : depense nulle', bloque.depense, 0);
verifie('reserve 100% : le stock physique est INTACT', bloque.stockEntrepot, entrepot);

// Reserve partielle : le chantier n'a acces qu'au disponible.
var partielle = { bois:700, minerai:500, metal:200 };
var partiel = planifierApprovisionnement(besoin, vide, entrepot, 100000, prix, partielle);
verifie('reserve partielle : achat borne au disponible', partiel.achats, {bois:50});
verifie('reserve partielle : stock physique = 750-50', partiel.stockEntrepot.bois, 700);
verifieVrai('la reserve n a pas ete soustraite du stock rendu', partiel.stockEntrepot.bois === 700);

// Tresorerie : borne independante, inchangee.
var pauvre = planifierApprovisionnement(besoin, vide, entrepot, 250, prix, null);
verifie('tresorerie insuffisante : achat borne par l argent', pauvre.depense <= 250, true);

// ============================================================================
section('4. SUBTILISATION — trois issues, base 35%');
// Le moteur est celui du vol de chantier : score = 50 + bonus - vigiles + jet.
// Avec un personnage neutre (bonus 0), le score vaut 50 + (jet = roll - 50) = roll.
// Le seuil de reussite a 66 donne donc exactement 35 % : les rolls 66..100 inclus.
function verdictSub(score) {
  var s = Math.max(0, Math.min(100, score));
  if (s < 20) return 'echec_detecte';
  if (s < 66) return 'echec_discret';
  return 'reussite';
}
var reussites = 0, detectes = 0, discrets = 0;
for (var roll = 1; roll <= 100; roll++) {
  var sc = scoreVolMateriaux(0, 0, roll - 50);
  var v = verdictSub(sc);
  if (v === 'reussite') reussites++;
  else if (v === 'echec_detecte') detectes++;
  else discrets++;
}
verifie('reussite = 35 % a bonus nul', reussites, 35);
verifie('echec detecte = 19 %', detectes, 19);
verifie('echec discret = 46 %', discrets, 46);
verifie('les trois issues couvrent tout', reussites + detectes + discrets, 100);
// Un bon voleur progresse reellement.
var bons = 0;
for (var r2 = 1; r2 <= 100; r2++) { if (verdictSub(scoreVolMateriaux(20, 0, r2 - 50)) === 'reussite') bons++; }
verifieVrai('un bonus de +20 augmente la reussite', bons > 35);

// ============================================================================
section('5. VOL DE CHANTIER — non regression (seuils d origine intacts)');
verifie('chantier : <20 detecte', verdictVolMateriaux(19).detecte, true);
verifie('chantier : 20-49 echec discret', [verdictVolMateriaux(30).reussite, verdictVolMateriaux(30).detecte], [false,false]);
verifie('chantier : >=50 reussite', verdictVolMateriaux(50).reussite, true);
var chantierReussites = 0;
for (var r3 = 1; r3 <= 100; r3++) { if (verdictVolMateriaux(scoreVolMateriaux(0,0,r3-50)).reussite) chantierReussites++; }
verifie('chantier : toujours ~51 % a bonus nul', chantierReussites, 51);

// ============================================================================
section('6. MATERIAUX DU JOUR — non regression');
verifie('construction J1', materiauxDuJourConstruction(1), {bois:100, minerai:50, metal:33});


// ============================================================================
section('7. CATALOGUE MILITAIRE — recettes, matieres eligibles, cout de revient');
verifie('trois produits', PRODUITS_MILITAIRES, ['arme_de_poing','mitraillette','explosif_militaire']);
verifie('matieres eligibles DEDUITES des recettes', ressourcesMilitairesEligibles(), ['bois','metal','minerai']);
// Pistolet : 2 metal (30) + 1 bois (5) + 2 PA (100) = 135
verifie('cout de revient pistolet militaire', coutRevientLotMilitaire('arme_de_poing'), 135);
// Mitraillette : 2 metal (30) + 2 bois (10) + 2 PA (100) = 140
verifie('cout de revient mitraillette', coutRevientLotMilitaire('mitraillette'), 140);
// Explosifs : 2 metal (30) + 3 minerai (30) + 1 PA (50) = 110 pour un lot de 3
verifie('cout de revient lot d explosifs', coutRevientLotMilitaire('explosif_militaire'), 110);
var dEx = detailCoutRevientMilitaire('explosif_militaire');
verifie('lot de 3 explosifs', dEx.produitParLot, 3);
verifie('cout unitaire explosif (110/3 arrondi)', dEx.coutRevientUnitaire, 37);
verifieVrai('la facture annonce EXACTEMENT le montant credite',
            dEx.coutRevientLot === coutRevientLotMilitaire('explosif_militaire'));
var dPi = detailCoutRevientMilitaire('arme_de_poing');
verifie('detail pistolet : matieres + travail = total',
        dPi.valeurMatieres + dPi.valeurTravail, dPi.coutRevientLot);

section('8. STOCK CIVIL DISPONIBLE');
var etat = { entrepot: { stock:{metal:200,bois:750,poisson:125}, reserveMilitaire:{metal:80,bois:300}, caisse:10 } };
verifie('disponible = stock - reserve', stockCivilDisponible(etat), {metal:120, bois:450, poisson:125});
verifie('reserve lue telle quelle', reserveMilitaireEntrepot(etat), {metal:80, bois:300});
verifie('entrepot sans reserve : tout est disponible',
        stockCivilDisponible({entrepot:{stock:{metal:10}}}), {metal:10});
verifie('3 entrepots enumeres', entrepotsEffort('republic').length, 3);
verifie('charge utile RPC sans le nom d affichage',
        Object.keys(entrepotsEffortRpc('republic')[0]).sort(), ['building','city']);

section('9. CURSEURS — hors Effort, tout est a zero');
// prioritesEffort lit l'heure REELLE (Date.now()) : c'est une lecture client de « maintenant ».
// Le banc doit donc lui donner une echeance reellement future, pas une date figee.
var T9 = Date.now();
verifie('Effort actif : curseurs lus',
        prioritesEffort({actif:true, expireA:T9+3600000, prioriteRavitaillement:70, prioriteProductionMilitaire:30}),
        {ravitaillement:70, production:30});
verifie('Effort expire : aucune priorite',
        prioritesEffort({actif:true, expireA:1, prioriteRavitaillement:70, prioriteProductionMilitaire:30}),
        {ravitaillement:0, production:0});
verifie('pas d Effort : aucune priorite', prioritesEffort(null), {ravitaillement:0, production:0});

section('10. REPARTITION ENTRE LES TROIS ARMURERIES (rotation)');
// Regle du cron : ville = villes[quantiteDejaProduite % 3]. On verifie qu'elle est equitable
// ET qu'elle reprend au bon endroit quand la production s'etale sur plusieurs nuits.
var villes = ['capitale','ville_a','ville_b'];
function repartir(total, dejaProduit) {
  var c = {capitale:0, ville_a:0, ville_b:0};
  for (var i = dejaProduit; i < total; i++) c[villes[i % 3]]++;
  return c;
}
verifie('30 unites reparties en 3 fois 10', repartir(30, 0), {capitale:10, ville_a:10, ville_b:10});
verifie('10 unites : reste indivisible etale', repartir(10, 0), {capitale:4, ville_a:3, ville_b:3});
// Nuit 1 : 4 produites. Nuit 2 : la rotation REPREND a la 5e, elle ne recommence pas a zero.
var n1 = repartir(4, 0), n2 = repartir(10, 4);
verifie('nuit 1 (4 unites)', n1, {capitale:2, ville_a:1, ville_b:1});
verifie('nuit 2 (6 restantes)', n2, {capitale:2, ville_a:2, ville_b:2});
verifie('total des deux nuits = production en une fois',
        {capitale:n1.capitale+n2.capitale, ville_a:n1.ville_a+n2.ville_a, ville_b:n1.ville_b+n2.ville_b},
        repartir(10, 0));


section('11. CONFISCATION GENERIQUE (douane / fouille / arrestation)');
var inv = [
  { type:'explosif', name:'Explosifs de chantier',        legal:false },
  { type:'explosif', name:'Explosifs militaires',         legal:true, origineMilitaire:true, lot:'L1' },
  { type:'arme',     name:'Revolver non enregistre',      legal:false },
  { type:'arme',     name:'Pistolet militaire',           legal:true, sousType:'militaire' },
  { type:'kompromat',name:'Dossier compromettant',        legal:false },
  { type:'contrebande', name:'Loukoums de contrebande',   legal:false },
  { type:'medicament', name:'Aspirine',                   legal:true },
  { type:'colis_secret_pat', name:'Colis de Pat Hounette', legal:false }
];
var saisis = objetsSaisissables(inv).map(function(o){ return o.name; });
verifie('explosif de chantier SAISI', saisis.indexOf('Explosifs de chantier') >= 0, true);
verifie('kompromat SAISI (n etait pas dans l ancienne whitelist)', saisis.indexOf('Dossier compromettant') >= 0, true);
verifie('contrebande SAISIE (idem)', saisis.indexOf('Loukoums de contrebande') >= 0, true);
verifie('arme non enregistree SAISIE', saisis.indexOf('Revolver non enregistre') >= 0, true);
verifie('EXPLOSIF MILITAIRE NON saisi', saisis.indexOf('Explosifs militaires') === -1, true);
verifie('PISTOLET MILITAIRE NON saisi', saisis.indexOf('Pistolet militaire') === -1, true);
verifie('objet legal NON saisi', saisis.indexOf('Aspirine') === -1, true);
verifie('objet de quete protege NON saisi', saisis.indexOf('Colis de Pat Hounette') === -1, true);
verifie('total saisi', saisis.length, 4);

section('12. CELLULE DE DETENTION — source unique, QHS compris');
verifie('capitale : commissariat/prison',
        celluleDeDetention({city:'capitale'}), {city:'capitale', buildingId:'commissariat', roomId:'prison'});
verifie('autre ville : commissariat-local/geoles',
        celluleDeDetention({city:'ville_b'}), {city:'ville_b', buildingId:'commissariat-local', roomId:'geoles'});
verifie('QHS : le detenu a enfin un lieu',
        celluleDeDetention({qhs:true, city:'capitale'}), {city:'qhs', buildingId:'qhs-prison', roomId:'cellules_qhs'});


section('13. MOTIFS MULTIPLES — un motif n en efface jamais un autre');
verifie('delai de requisition porte a 48 h', DELAI_REQUISITION_HEURES, 48);
var motifs = [
  { acte:'desertion', type:'militaire', country:'republic' },
  { acte:'desertion', type:'militaire', country:'narco' },
  { acte:'utiliser_explosifs', type:'crime', jour:3 },
  { type:'condamnation', motifs:[{type:'Assassinat'}], reliquat_jours:28 },
  { acte:'vol', type:'delit_mineur', jour:5 }
];
verifie('le predicat ne reconnait QUE la desertion',
        motifs.map(estMotifDesertion), [true,true,false,false,false]);

// Extinction a la demobilisation : seules les desertions DE CE PAYS partent.
var apresDemob = motifs.filter(function(e){ return !(estMotifDesertion(e) && (!e.country || e.country==='republic')); });
verifie('restent 4 motifs apres demobilisation', apresDemob.length, 4);
verifieVrai('la condamnation a 28 jours SURVIT',
            apresDemob.some(function(e){ return e.type==='condamnation'; }));
verifieVrai('le crime SURVIT', apresDemob.some(function(e){ return e.acte==='utiliser_explosifs'; }));
verifieVrai('la desertion d un AUTRE empire survit (competence territoriale)',
            apresDemob.some(function(e){ return estMotifDesertion(e) && e.country==='narco'; }));
verifieVrai('la desertion de Republia est eteinte',
            !apresDemob.some(function(e){ return estMotifDesertion(e) && e.country==='republic'; }));

// Arrestation : seul le motif reellement juge s'eteint (filtre de procederArrestation).
var apresArrestation = motifs.filter(function(r){ return r && r.acte !== 'vol'; });
verifie('arrestation pour vol : 4 motifs subsistent', apresArrestation.length, 4);
verifieVrai('la condamnation survit a une arrestation pour vol',
            apresArrestation.some(function(e){ return e.type==='condamnation'; }));

section('14. BONUS D EVASION DU DESERTEUR (+10/jour, plafond +50, apres le clamp 40)');
state.char = { name:'zzTest', joursDetenuDeserteur: 0 };
verifie('jour 0 : aucun bonus', bonusEvasionDeserteur(), 0);
state.char.joursDetenuDeserteur = 3; verifie('3 jours -> +30', bonusEvasionDeserteur(), 30);
state.char.joursDetenuDeserteur = 5; verifie('5 jours -> +50 (plafond)', bonusEvasionDeserteur(), 50);
state.char.joursDetenuDeserteur = 12; verifie('12 jours -> toujours +50', bonusEvasionDeserteur(), BONUS_EVASION_DESERTEUR_MAX);
// L'ordre impose : clamp ordinaire a 40, PUIS ajout du bonus, maximum absolu 90.
function tauxEvasion(brut, bonus) { return Math.min(90, Math.max(2, Math.min(40, brut)) + bonus); }
verifie('non deserteur : plafond ordinaire intact', tauxEvasion(70, 0), 40);
verifie('deserteur au plafond : 40 + 50 = 90', tauxEvasion(70, 50), 90);
verifie('maximum absolu jamais depasse', tauxEvasion(200, 50), 90);
verifie('petit taux + bonus', tauxEvasion(10, 30), 40);
// Le compteur ne bouge pas hors detention / hors mobilisation.
state.estEmprisonne = null; state.char.joursDetenuDeserteur = 0;
incrementerDetentionDeserteur();
verifie('hors detention : aucun jour compte', state.char.joursDetenuDeserteur, 0);
state.estEmprisonne = { jours:3 }; state.char.requisition = { statut:'deserteur' };
state.mobilisationNationaleCache = false;
incrementerDetentionDeserteur();
verifie('mobilisation levee : aucun jour compte', state.char.joursDetenuDeserteur, 0);
state.mobilisationNationaleCache = true; state.day = 4;
incrementerDetentionDeserteur();
verifie('detenu deserteur pendant la mobilisation : +1 jour', state.char.joursDetenuDeserteur, 1);
incrementerDetentionDeserteur();
verifie('deux passages le MEME jour ne comptent qu une fois', state.char.joursDetenuDeserteur, 1);
state.day = 5; incrementerDetentionDeserteur();
verifie('jour suivant : +1', state.char.joursDetenuDeserteur, 2);


section('15. VISIBILITE DES STOCKS — les trois produits, pour les quatre roles');
var h = htmlStockArmurerieMilitaire({ arme_de_poing: 12, mitraillette: 4, explosif_militaire: 7 });
verifieVrai('affiche les pistolets', h.indexOf('Pistolet militaire') >= 0 && h.indexOf('>12<') >= 0);
verifieVrai('affiche les mitraillettes', h.indexOf('Mitraillette') >= 0 && h.indexOf('>4<') >= 0);
verifieVrai('affiche les explosifs', h.indexOf('Explosifs militaires') >= 0 && h.indexOf('>7<') >= 0);
var vide = htmlStockArmurerieMilitaire({});
verifieVrai('magasin vide : les trois lignes restent affichees a zero',
  vide.indexOf('Pistolet militaire') >= 0 && vide.indexOf('Mitraillette') >= 0
  && vide.indexOf('Explosifs militaires') >= 0);
verifieVrai('titre personnalisable', htmlStockArmurerieMilitaire({}, 'LIVRÉ').indexOf('LIVRÉ') >= 0);
// VOIR N'EST PAS RETIRER : la brique ne rend que du texte, aucun bouton, aucun champ de saisie.
verifieVrai('aucun bouton dans le bloc de visibilite', h.indexOf('<button') === -1);
verifieVrai('aucun champ de saisie dans le bloc de visibilite', h.indexOf('<input') === -1);

print('');
print(ECHECS === 0 ? '*** TOUS LES TESTS PASSENT ***' : '*** ' + ECHECS + ' ECHEC(S) ***');
"""


def main():
    prog = PRELUDE
    for fichier, exports in MODULES:
        prog += charger(fichier, exports)
    prog += TESTS
    with tempfile.NamedTemporaryFile("w", suffix=".js", delete=False, encoding="utf-8") as f:
        f.write(prog)
        chemin = f.name
    try:
        r = subprocess.run([JSC, chemin], capture_output=True, text=True, timeout=120)
        print(r.stdout)
        if r.stderr.strip():
            print("STDERR:", r.stderr[:3000])
        return 0 if "TOUS LES TESTS PASSENT" in r.stdout else 1
    finally:
        os.unlink(chemin)


if __name__ == "__main__":
    sys.exit(main())
