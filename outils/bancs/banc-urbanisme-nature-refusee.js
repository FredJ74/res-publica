// PREUVE DE LA GARDE DE NATURE SUR L'ARCHIVE D'URBANISME (chantier 7, 10 octobre 2026)
// SOURCES: api/_referentiels-generes.js api/cron-minuit.js
//
// CE QU'IL PROUVE. archiverEvenementUrbanismeServeur ecrit dans dossiers_urbanisme, qui est
// append-only : une ligne fausse ne se corrige pas apres coup. Son libelle est produit par
// libelleAccordTaciteServeur, dont la mesure du chantier 7 a etabli qu'il rend « Accord tacite
// au benefice de ... » POUR TOUTE nature -- y compris un refus. Le seul appelant d'aujourd'hui
// passe 'accord_tacite', donc rien n'est faux en base ; mais la copie etait un piege en attente
// d'un appelant, exactement comme la table de niveaux de construction que le depot nomme ainsi.
//
// La garde posee refuse toute nature autre qu'accord_tacite. Ce banc verifie les deux moities :
//   . une nature etrangere est REFUSEE, et AUCUNE ECRITURE N'EST TENTEE ;
//   . l'accord tacite, lui, passe encore -- une garde qui ferme tout ne prouve rien.
// Il verifie aussi que la garde du PAYS (chantier 4G) n'a pas ete deplacee par celle-ci : un
// pays non declare reste refuse, et il est examine AVANT la nature.
//
// Le transport est remplace par un espion : sbInsert et signalerEchec sont reassignes apres le
// chargement du vrai module. Aucune ligne n'est ecrite nulle part, et le banc ne touche pas a
// la base.

var ecritures = [], echecs = [];
sbInsert = function (table, ligne) { ecritures.push({ table: table, ligne: ligne }); return Promise.resolve([ligne]); };
signalerEchec = function (quoi, detail) { echecs.push(quoi + ' ' + String(detail)); };

var ko = 0, n = 0;
function att(libelle, condition, detail) {
  n++;
  if (condition) { print('  ok  ' + libelle); }
  else { print('  *** ' + libelle); if (detail !== undefined) print('        ' + detail); ko++; }
}

function doc(nature, pays) {
  return { nature: nature, pays: pays, ville: 'capitale', buildingId: 'b1',
           numeroDossier: 'URB-1', demandeur: 'Arnie', jour: 5, palierLabel: 'Commerce',
           batimentLabel: 'b1', surfaceExploitable: 120, decoupage: [], motifRefus: null };
}

print('');
print('GARDE DE NATURE SUR L\'ARCHIVE D\'URBANISME');
print('============================================================================');

function essai(etiquette, d, attenduRendu, attenduEcritures, motifEchec) {
  ecritures = []; echecs = [];
  return archiverEvenementUrbanismeServeur(d).then(function (rendu) {
    att(etiquette + ' : rend ' + attenduRendu, rendu === attenduRendu, 'rendu=' + rendu);
    att(etiquette + ' : ' + attenduEcritures + ' ecriture(s)',
        ecritures.length === attenduEcritures, 'ecritures=' + ecritures.length);
    if (motifEchec) {
      att(etiquette + ' : echec signale sous ' + motifEchec,
          echecs.length === 1 && echecs[0].indexOf(motifEchec) === 0, JSON.stringify(echecs));
    } else {
      att(etiquette + ' : aucun echec signale', echecs.length === 0, JSON.stringify(echecs));
    }
  });
}

essai('accord tacite', doc('accord_tacite', 'republic'), true, 1, null)
  .then(function () {
    att('accord tacite : le libelle archive est bien celui d\'un accord tacite',
        ecritures.length === 1 && ecritures[0].ligne.libelle.indexOf('Accord tacite') === 0,
        ecritures.length ? ecritures[0].ligne.libelle : '(aucune ecriture)');
    att('accord tacite : la nature archivee est accord_tacite',
        ecritures.length === 1 && ecritures[0].ligne.type_evenement === 'accord_tacite',
        ecritures.length ? String(ecritures[0].ligne.type_evenement) : '(aucune ecriture)');
  })
  .then(function () { return essai('refus', doc('refus', 'republic'), false, 0, 'urbanisme:nature_sans_libelle'); })
  .then(function () { return essai('depot', doc('depot', 'republic'), false, 0, 'urbanisme:nature_sans_libelle'); })
  .then(function () { return essai('nature absente', doc(undefined, 'republic'), false, 0, 'urbanisme:nature_sans_libelle'); })
  .then(function () { return essai('pays non declare', doc('accord_tacite', undefined), false, 0, 'urbanisme:pays_non_declare'); })
  .then(function () { return essai('pays inconnu ET nature etrangere', doc('refus', 'atlantide'), false, 0, 'urbanisme:pays_non_declare'); })
  .then(function () {
    print('');
    if (ko === 0) { print('LES ' + n + ' EPREUVES SONT VERTES.'); }
    else { print('ECHEC : ' + ko + ' epreuve(s) sur ' + n + '.'); }
  })
  .catch(function (e) { print('ECHEC : exception -- ' + e + '\n' + (e && e.stack)); });
