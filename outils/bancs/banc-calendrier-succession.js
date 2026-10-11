// BANC DU CALENDRIER DE SUCCESSION -- UN MANDAT NE LAISSE PLUS DE VACANCE (11 octobre 2026).
// SOURCES: api/_referentiels-generes.js api/cron-minuit.js
//
// L'ARBITRAGE EPROUVE ICI. Un mandat dure cinq semaines, six s'il faut un second tour, et il ne
// doit JAMAIS exister de vacance institutionnelle du seul fait qu'une election est en cours. Le
// titulaire sortant garde ses pouvoirs jusqu'a l'instant exact ou le resultat definitif designe
// son successeur, et la succession est immediate a cet instant.
//
// CE BANC EST POUR MOITIE COMPORTEMENTAL. `calendrierSuccession` et `ouvrirSuccessionSurCycle`
// sont des fonctions pures : elles sont APPELEES, sur des dates reelles de Paris, et leurs
// reponses sont confrontees a des instants ecrits en clair. Le depouillement lui-meme reste un
// bloc inline du gestionnaire de cron -- il est donc eprouve STRUCTURELLEMENT, comme le fait
// deja banc-calendrier-electoral.js, et son comportement de porte est eprouve en base par
// banc-succession-sans-vacance.sql.
//
// LES DATES SONT CELLES DU CALENDRIER REEL DE 2026, changements d'heure compris : le passage a
// l'heure d'hiver tombe le dimanche 25 octobre 2026, et deux epreuves l'encadrent exprès.

var ko = 0, attendus = 0;
function att(n, c, detail) {
  attendus++;
  if (c) print('  ok  ' + n);
  else { print('  *** ' + n); if (detail !== undefined) print('        ' + detail); ko++; }
}
function compte(texte, motif) { return (texte.match(motif) || []).length; }

// Un instant, decrit en heure MURALE de Paris, via la fonction du jeu elle-meme : c'est elle qui
// porte la connaissance du fuseau, et l'employer ici evite de recopier un decalage a la main.
function paris(a, m, j, h, mi) { return instantHeureParis(a, m, j, h, mi || 0); }
function libelle(ts) {
  var p = partiesHeureParis(ts);
  return p.a + '-' + ('0' + p.m).slice(-2) + '-' + ('0' + p.j).slice(-2)
       + ' ' + ('0' + p.h).slice(-2) + ':' + ('0' + p.mi).slice(-2);
}
function jourSemaine(ts) {
  var p = partiesHeureParis(ts);
  return new Date(Date.UTC(p.a, p.m - 1, p.j)).getUTCDay();   // 0 = dimanche, 1 = lundi
}

print('');
print('1. UN MANDAT NORMAL : CINQ SEMAINES, QUATRE DE CANDIDATURES, GEL LA CINQUIEME');
// Mandat ouvert le lundi 28 septembre 2026 a 00:00 de Paris -- le cas reel du cycle presidentiel.
var LUN_28_SEP = paris(2026, 9, 28, 0, 0);
var c5 = calendrierSuccession(LUN_28_SEP, 5);
att('le mandat finit cinq semaines plus tard, au lundi 2026-11-02 00:00',
    libelle(c5.dateFinMandat) === '2026-11-02 00:00', libelle(c5.dateFinMandat));
att('la fin du mandat et la proclamation du successeur sont LE MEME INSTANT',
    c5.dateFinMandat === c5.dateResultats,
    libelle(c5.dateFinMandat) + ' vs ' + libelle(c5.dateResultats));
att('les candidatures ouvrent des la premiere minute du mandat',
    c5.dateDebutCandidatures === LUN_28_SEP, libelle(c5.dateDebutCandidatures));
att('elles gelent au lundi 00:01 de la cinquieme semaine, soit le 2026-10-26 00:01',
    libelle(c5.dateDebutCampagne) === '2026-10-26 00:01', libelle(c5.dateDebutCampagne));
// QUATRE SEMAINES CALENDAIRES, pas 28 x 24 h : entre le 28 septembre et le 26 octobre 2026 il y
// a une heure reelle de PLUS, parce que le changement d'heure tombe au milieu. Comparer des
// millisecondes ici aurait fait echouer l'epreuve sur un calendrier pourtant juste -- c'est le
// piege que ce banc existe pour ne pas reproduire.
att('le gel tombe au lundi de la cinquieme semaine, soit quatre semaines calendaires plus tard',
    c5.dateDebutCampagne === lundiMinuitParisApresSemaines(LUN_28_SEP, 4) + 60000,
    libelle(c5.dateDebutCampagne) + ' au lieu de '
    + libelle(lundiMinuitParisApresSemaines(LUN_28_SEP, 4) + 60000));
att('le vote a lieu le DERNIER DIMANCHE du mandat, le 2026-11-01 00:01',
    libelle(c5.dateVote) === '2026-11-01 00:01', libelle(c5.dateVote));
att('ce jour de vote est bien un dimanche', jourSemaine(c5.dateVote) === 0);
att('la proclamation est bien un lundi', jourSemaine(c5.dateResultats) === 1);
att('le vote est ouvert pendant 24 h moins une minute',
    c5.dateResultats - c5.dateVote === 24 * 3600 * 1000 - 60 * 1000,
    (c5.dateResultats - c5.dateVote) + ' ms');

print('');
print('2. LE PASSAGE A L HEURE D HIVER NE DEPLACE NI LE DIMANCHE NI MINUIT');
// Le changement d'heure tombe le dimanche 25 octobre 2026. Le mandat ci-dessus l'ENJAMBE : son
// gel est avant, son vote apres. Les deux restent a l'heure murale voulue -- ce qui serait faux
// si une seule de ces dates etait calculee en +N x 24 h.
att('le gel du 2026-10-26 est bien un lundi', jourSemaine(c5.dateDebutCampagne) === 1);
att('le vote du 2026-11-01, apres le changement d heure, est bien un dimanche 00:01',
    jourSemaine(c5.dateVote) === 0 && libelle(c5.dateVote) === '2026-11-01 00:01');
// Et un mandat qui commence avant le changement d'heure et finit apres dure bien cinq semaines
// CALENDAIRES, soit 35 jours de 24 h plus une heure reelle gagnee.
var cDst = calendrierSuccession(paris(2026, 10, 12, 0, 0), 5);
att('un mandat du 2026-10-12 finit au lundi 2026-11-16 00:00',
    libelle(cDst.dateFinMandat) === '2026-11-16 00:00', libelle(cDst.dateFinMandat));
att('il dure 35 jours CALENDAIRES, et une heure reelle de plus que 35 x 24 h',
    cDst.dateFinMandat - paris(2026, 10, 12, 0, 0) === 35 * 86400000 + 3600000,
    ((cDst.dateFinMandat - paris(2026, 10, 12, 0, 0)) / 3600000) + ' h');
// Et le passage a l'heure d'ete, dans l'autre sens : mandat du 2026-03-09 au 2026-04-13.
var cEte = calendrierSuccession(paris(2026, 3, 9, 0, 0), 5);
att('un mandat du 2026-03-09 finit au lundi 2026-04-13 00:00',
    libelle(cEte.dateFinMandat) === '2026-04-13 00:00', libelle(cEte.dateFinMandat));
att('il dure 35 jours CALENDAIRES, et une heure reelle de MOINS',
    cEte.dateFinMandat - paris(2026, 3, 9, 0, 0) === 35 * 86400000 - 3600000,
    ((cEte.dateFinMandat - paris(2026, 3, 9, 0, 0)) / 3600000) + ' h');
att('son vote reste un dimanche 00:01 malgre le changement d heure du 2026-03-29',
    libelle(cEte.dateVote) === '2026-04-12 00:01' && jourSemaine(cEte.dateVote) === 0,
    libelle(cEte.dateVote));

print('');
print('3. LA PROLONGATION DE DEUX SEMAINES REJOUE UN SCRUTIN COMPLET');
// Un scrutin sans verdict ne vacance pas le poste : il prolonge le mandat de deux semaines, une
// de candidatures et une de campagne puis de vote. C'est la seule duree qui laisse place a une
// candidature -- un seul dimanche de plus rendrait le scrutin desert par construction.
var c2 = calendrierSuccession(LUN_28_SEP, PROLONGATION_SEMAINES);
att('la prolongation vaut deux semaines', PROLONGATION_SEMAINES === 2, String(PROLONGATION_SEMAINES));
att('elle finit au lundi 2026-10-12 00:00',
    libelle(c2.dateFinMandat) === '2026-10-12 00:00', libelle(c2.dateFinMandat));
att('elle laisse exactement UNE semaine calendaire de candidatures',
    c2.dateDebutCampagne === lundiMinuitParisApresSemaines(LUN_28_SEP, 1) + 60000,
    libelle(c2.dateDebutCampagne));
att('son vote est un dimanche', jourSemaine(c2.dateVote) === 0);
att('une prolongation d UNE semaine ne laisserait AUCUNE candidature -- et c est pourquoi elle n existe pas',
    calendrierSuccession(LUN_28_SEP, 1).dateDebutCampagne <= LUN_28_SEP + 60000);

print('');
print('4. OUVRIR UNE SUCCESSION NE TOUCHE JAMAIS AU TITULAIRE EN EXERCICE');
// C'EST L'EPREUVE CENTRALE DU CORRECTIF. Le titulaire s'atteste par `eluId` / `elus` -- exactement
// ce que lit `poste_est_atteste` au serveur. Ouvrir le scrutin de sa succession ne doit effleurer
// ni l'un ni l'autre, sinon le poste devient vacant a l'instant meme ou l'election commence.
var cycle = {
  posteId: 'president', city: null,
  eluId: 'Le Président (PNJ)', elus: ['A', 'B', 'C'],
  dateDebutMandatTs: LUN_28_SEP,
  dissolutionUtilisee: true,
  candidats: [{ nom: 'Ancien candidat' }], votes: { 'X': 'Y' }, votesPNJ: { 'P': 'Y' },
  relancePossibleApres: 123, phase: 'mandat', resultatsTraites: true, tour: 2
};
var avantElu = cycle.eluId, avantElus = cycle.elus, avantDebut = cycle.dateDebutMandatTs;
ouvrirSuccessionSurCycle(cycle, LUN_28_SEP, 5);
att('le titulaire a siege unique est intact', cycle.eluId === avantElu, String(cycle.eluId));
att('les titulaires a sieges multiples sont intacts', cycle.elus === avantElus,
    JSON.stringify(cycle.elus));
att('la date de debut du mandat est intacte', cycle.dateDebutMandatTs === avantDebut);
att('la phase decrit desormais le SCRUTIN, pas le mandat', cycle.phase === 'candidatures', cycle.phase);
att('le scrutin repart au premier tour', cycle.tour === 1, String(cycle.tour));
att('la liste des candidats est vide', Array.isArray(cycle.candidats) && cycle.candidats.length === 0);
att('les bulletins du scrutin precedent sont effaces',
    Object.keys(cycle.votes).length === 0 && Object.keys(cycle.votesPNJ).length === 0);
att('le drapeau de depouillement est rouvert', cycle.resultatsTraites === false);
att('la relance apres vacance n existe plus', !('relancePossibleApres' in cycle));
att('la dissolution deja utilisee N EST PAS effacee par une simple ouverture de scrutin',
    cycle.dissolutionUtilisee === true);
att('la fin du mandat suit le calendrier de la succession',
    cycle.dateFinMandat === cycle.dateResultats
    && libelle(cycle.dateFinMandat) === '2026-11-02 00:00', libelle(cycle.dateFinMandat));

print('');
print('5. LES NEUF DEPUTES PNJ SONT CEUX DE L HEMICYCLE, ET EUX SEULS');
// L'audit du calendrier avait trouve DEUX castings entierement disjoints : celui que le
// depouillement inscrivait dans `cycle.elus`, et celui de `assemblee_sieges` reellement affiche.
// Le casting officiel est celui de l'hemicycle. Les neuf noms sont ecrits ici en clair, dans
// l'ordre des rangs : c'est cette liste que la base doit confirmer (banc SQL, epreuve dediee).
var OFFICIEL = {
  capitale: ['Étienne Vauclerc', 'Sophie Maréchal', 'President Laroche'],
  ville_a:  ['Yann Legall', 'Maëlle Leroux', 'Loïc Kermeur'],
  ville_b:  ['Nathalie Charron', 'Gérard Pichon', 'Élodie Vasseur']
};
var FANTOMES = ['Marchand', 'Rousseau', 'Lecoq', 'Girard', 'Ambroise',
                'Ferraille', 'Charbonnier', 'Houiller'];
['capitale', 'ville_a', 'ville_b'].forEach(function (v) {
  att('le casting electoral de ' + v + ' est celui de l hemicycle, dans l ordre des rangs',
      JSON.stringify(PNJ_DEPUTES_PAR_VILLE[v]) === JSON.stringify(OFFICIEL[v]),
      JSON.stringify(PNJ_DEPUTES_PAR_VILLE[v]));
});
att('il y a exactement neuf deputes PNJ, trois par ville',
    Object.keys(PNJ_DEPUTES_PAR_VILLE).length === 3
    && [].concat(PNJ_DEPUTES_PAR_VILLE.capitale, PNJ_DEPUTES_PAR_VILLE.ville_a,
                 PNJ_DEPUTES_PAR_VILLE.ville_b).length === 9);
var tous = JSON.stringify(PNJ_DEPUTES_PAR_VILLE);
FANTOMES.forEach(function (nom) {
  att('aucun depute fantome nomme ' + nom, tous.indexOf(nom) < 0);
});
att('aucun nom ne porte plus le suffixe « (PNJ) » : ce sont des personnes de l hemicycle',
    tous.indexOf('(PNJ)') < 0);

print('');
print('6. LE DEPOUILLEMENT NE PEUT PLUS EFFACER UN TITULAIRE — EPREUVES STRUCTURELLES');
var src = readFile('/Users/fredericjasseron/ResPublica/api/cron-minuit.js');
var iDebut = src.indexOf("const dateResultats = cycle.dateResultats;");
var iFin   = src.indexOf("// 1b. Cascade de nomination automatique");
var bloc   = (iDebut >= 0 && iFin > iDebut) ? src.slice(iDebut, iFin) : '';
att('le bloc du depouillement est localisable', bloc.length > 0);
att('aucune branche n assigne eluId a null ni elus a vide',
    compte(bloc, /eluId\s*=\s*null/g) === 0 && compte(bloc, /elus\s*=\s*\[\]/g) === 0);
att('aucune branche ne reconstruit un cycle',
    compte(bloc, /construireNouveauCycleElectoral/g) === 0);
att('plus aucune branche ne pose la phase de vacance',
    compte(bloc, /phase = 'vacant'/g) === 0);
att('plus aucune branche ne pose la phase du mandat',
    compte(bloc, /phase = 'mandat'/g) === 0);
att('la prise de fonctions date le mandat sur dateResultats, jamais sur l heure de la passe',
    bloc.indexOf('cycle.dateDebutMandatTs = dateResultats;') >= 0
    && compte(bloc, /dateDebutMandatTs = now/g) === 0);
att('le second tour ne touche ni eluId ni dateDebutMandatTs',
    bloc.indexOf("cycle.phase = 'second_tour'") >= 0
    && bloc.indexOf('cycle.dateFinMandat = calST.dateResultats;') >= 0);
att('la consignation garde sur dateResultats',
    bloc.indexOf('p_si_date_resultats: dateResultats') >= 0);
att('les deux blocs qui effacaient le titulaire ont disparu, et le fichier dit pourquoi',
    src.indexOf('LES DEUX BLOCS QUI VIVAIENT ICI SONT SUPPRIMES') >= 0
    && src.indexOf("if (cycle.phase === 'mandat' && cycle.dateFinMandat") < 0);
att('la cascade PNJ ne garde plus sur resultatsTraites, mais sur l absence de titulaire',
    src.indexOf('if (cycle.eluId) return;') >= 0
    && src.indexOf('if (!cycle.resultatsTraites || cycle.eluId) return;') < 0);

print('');
print('6 bis. LE NAVIGATEUR LIT PAR SCRUTIN, PAS PAR POSTE');
// LA MOITIE CLIENTE DES DEUX ESTAMPILLES. Un cycle n'etant plus detruit entre deux scrutins,
// `syncCyclesDepuisSupabase` reinjecterait dans le scrutin EN COURS les candidats et les bulletins
// de tous les scrutins precedents -- et le depouillement les compterait. Les deux lecteurs doivent
// donc filtrer, et REFUSER DE LIRE quand la clef du scrutin est inconnue : lire trop large est
// pire que ne rien lire.
var pol = readFile('/Users/fredericjasseron/ResPublica/plateau-politique.js');
function corpsDe(src, nom) {
  var i = src.indexOf('async function ' + nom + '(');
  if (i < 0) return '';
  var j = src.indexOf('\n}', i);
  return j < 0 ? src.slice(i) : src.slice(i, j + 2);
}
var cVotes = corpsDe(pol, 'sbGetVotes');
var cCands = corpsDe(pol, 'sbGetCandidatures');
att('sbGetVotes recoit le tour et filtre dessus',
    cVotes.indexOf('sbGetVotes(country, posteId, city, tour)') >= 0
    && cVotes.indexOf("'&tour=eq.'") >= 0, cVotes.slice(0, 120));
att('sbGetVotes ne lit RIEN sans tour connu',
    cVotes.indexOf('if (!isFinite(Number(tour))) return [];') >= 0);
att('sbGetCandidatures recoit la clef du scrutin et filtre dessus',
    cCands.indexOf('sbGetCandidatures(country, posteId, city, cleScrutin)') >= 0
    && cCands.indexOf("'&cle_scrutin=eq.'") >= 0);
att('sbGetCandidatures ne lit RIEN sans clef connue',
    cCands.indexOf('if (!isFinite(Number(cleScrutin))) return [];') >= 0);
att('la synchronisation passe les deux clefs du cycle courant',
    pol.indexOf('sbGetVotes(country, p.id, city, cycleSync.dateVote)') >= 0
    && pol.indexOf('sbGetCandidatures(country, p.id, city, cycleSync.dateDebutCandidatures)') >= 0);
// ET LA PHASE DU MANDAT NE FERME PLUS LES CANDIDATURES AU NAVIGATEUR : meme regle que le
// declencheur serveur, au nombre pres.
att('candidaturesOuvertes ne regarde plus que le gel',
    pol.indexOf('if (cycle.phase === PHASES_ELECTORALES.MANDAT || cycle.phase === PHASES_ELECTORALES.VACANT) return false;') < 0);
// ET « VACANT » SE DEDUIT DU TITULAIRE, PAS D'UNE DATE : c'est le « Vacant » affiche a tort entre
// la cloture du vote et la passe du cron qui disparait.
att('la queue de getPhaseActuelle rend DEPOUILLEMENT quand un titulaire existe',
    pol.indexOf('return cycleAUnTitulaire(cycle, posteId) ? PHASES_ELECTORALES.DEPOUILLEMENT : PHASES_ELECTORALES.VACANT;') >= 0);
att('la fenetre de contestation se lit sur dernierResultatTs',
    pol.indexOf('Number(c.dernierResultatTs)') >= 0
    && pol.indexOf('Number(cycle.dernierResultatTs)') >= 0);

print('');
print('6 ter. IL N EXISTE QU UN SEUL FABRICANT DE TITULAIRE, ET C EST LE SOCLE');
// LA QUESTION POSEE : une regle permanente peut-elle encore produire un mandat hors du socle
// commun ? La reponse se mesure sur les ECRIVAINS, pas sur les intentions.
//
// `dateFinMandat` n'a que DEUX ecrivains dans tout le code execute : `ouvrirSuccessionSurCycle`
// (le socle) et la branche du second tour (prolongation d'une semaine). S'il en apparait un
// troisieme, un mandat peut naitre avec un calendrier a lui.
var cron = src;          // api/cron-minuit.js, deja lu plus haut
function lignesDeCode(texte) {
  return texte.split('\n').filter(function (l) {
    return !/^\s*\/\//.test(l) && !/^\s*--/.test(l);
  });
}
function compteDansLeCode(texte, motif) {
  return lignesDeCode(texte).filter(function (l) { return motif.test(l); }).length;
}
att('dateFinMandat n a que deux ecrivains au serveur',
    compteDansLeCode(cron, /\bdateFinMandat\s*=/) === 2,
    compteDansLeCode(cron, /\bdateFinMandat\s*=/) + ' ecrivain(s)');
att('le navigateur n ecrit JAMAIS dateFinMandat',
    compteDansLeCode(pol, /\bdateFinMandat\s*=/) === 0,
    compteDansLeCode(pol, /\bdateFinMandat\s*=/) + ' ecrivain(s)');
// ET LE DERNIER FABRICANT DE TITULAIRE HORS SOCLE A DISPARU : le PNJ administrateur client
// posait `cycle.eluId` sans aucune date de mandat ni scrutin de succession.
att('le PNJ administrateur client n existe plus',
    pol.indexOf('const PNJ_ADMINISTRATEURS') < 0
    && pol.indexOf('function nommerAdministrateurSiVacant') < 0
    && pol.indexOf('function verifierPostesVacants()') < 0);
// LE MEME PIEGE QUE PLUS HAUT : plateau-core.js EXPLIQUE pourquoi l'appel a disparu, donc le nom
// est present dans son propre commentaire. La mesure porte sur les lignes de CODE.
att('et son appel a quitte la chaine de chargement',
    lignesDeCode(readFile('/Users/fredericjasseron/ResPublica/plateau-core.js'))
      .filter(function (l) { return l.indexOf('verifierPostesVacants()') >= 0; }).length === 0);
// LE REMPLISSAGE PNJ REEL VIT AU SERVEUR, ET IL PASSE PAR LE SOCLE.
att('la cascade PNJ serveur donne un mandat du socle',
    cron.indexOf('ouvrirSuccessionSurCycle(cycle, debutSecours, MANDAT_SEMAINES)') >= 0
    && cron.indexOf('const debutSecours = lundiMinuitParisApresSemaines(now, 0);') >= 0);
att('et elle ancre ce mandat sur un LUNDI 00:00 de Paris',
    jourSemaine(lundiMinuitParisApresSemaines(paris(2026, 10, 14, 1, 59), 0)) === 1
    && libelle(lundiMinuitParisApresSemaines(paris(2026, 10, 14, 1, 59), 0)) === '2026-10-12 00:00',
    libelle(lundiMinuitParisApresSemaines(paris(2026, 10, 14, 1, 59), 0)));
// `construireNouveauCycleElectoral` SUBSISTE, et il ne fabrique AUCUN mandat : c'est le
// generateur de GENESE d'un poste qui n'a jamais eu de titulaire (initCycleElectoral) et le
// relanceur de la dissolution presidentielle -- une regle distincte, qui coupe un mandat court
// volontairement. Son produit ne porte ni eluId, ni elus, ni dateFinMandat.
var genese = construireNouveauCycleElectoral('president', null, paris(2026, 10, 14, 1, 59));
att('le cycle de genese ne porte aucun titulaire',
    genese.eluId === null && !('elus' in genese));
att('et aucune date de fin de mandat',
    !('dateFinMandat' in genese));
att('mais il vote bien un dimanche et proclame un lundi',
    jourSemaine(genese.dateVote) === 0 && jourSemaine(genese.dateResultats) === 1);

print('');
print('7. LA DUREE DU MANDAT NE DERIVE PAS DE data.js');
// data.js declare `mandatSemaines: 5` sur les quatre postes electifs, et le serveur le ressaisit
// en dur. Les deux doivent concorder : l'audit du calendrier avait trouve que ce champ n'etait LU
// par personne, donc qu'une derive n'aurait rien rougi.
var dataJs = readFile('/Users/fredericjasseron/ResPublica/data.js');
var declares = (dataJs.match(/mandatSemaines:\s*(\d+)/g) || []).map(function (x) {
  return parseInt(x.replace(/[^0-9]/g, ''), 10);
});
att('data.js declare quatre durees de mandat', declares.length === 4, declares.join(','));
att('elles valent toutes ' + MANDAT_SEMAINES + ', comme la constante du serveur',
    declares.length === 4 && declares.every(function (d) { return d === MANDAT_SEMAINES; }),
    declares.join(',') + ' contre ' + MANDAT_SEMAINES);

print('');
print('8. LES QUATRE POSTES ELECTIFS SONT NOMMES ET PORTENT UNE PORTEE');
['president', 'chef_syndicat', 'maire', 'depute'].forEach(function (p) {
  att('le poste ' + p + ' a un nom lisible et une portee',
      !!POSTE_NOMS[p] && POSTE_NOMS[p] !== p && !!POSTE_SCOPE[p],
      POSTE_NOMS[p] + ' / ' + POSTE_SCOPE[p]);
});
att('chef_syndicat est national, comme la presidence',
    POSTE_SCOPE.chef_syndicat === 'national');
att('maire et depute sont locaux',
    POSTE_SCOPE.maire === 'local' && POSTE_SCOPE.depute === 'local');

print('');
if (ko === 0) print('LES ' + attendus + ' EPREUVES SONT VERTES.');
else print('ECHEC : ' + ko + ' epreuve(s) sur ' + attendus + ' en defaut.');
