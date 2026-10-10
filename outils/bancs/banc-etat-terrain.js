// Banc STRUCTUREL de L'ETAT D'UN TERRAIN -- chantier 5, les 22 `sbSetTerrainState` (10 oct. 2026).
// SOURCES: aucune -- ce banc lit les six fichiers de production lui-meme, par readFile.
//
// CE QUE L'INVENTAIRE DISAIT, ET CE QUE LA MESURE A TROUVE. L'audit nommait « 19 ecritures
// avalees, 11 autoritaires ». Le releve exhaustif en a trouve VINGT-DEUX, dont trois qui lisaient
// deja leur resultat -- et le compte d'ecritures AUTORITAIRES est plus eleve que 11, parce que la
// policy d'UPDATE de `terrains_etat` est `acteur_identifie()` : tout joueur connecte pouvait
// reecrire l'etat ENTIER de n'importe quel terrain du jeu. Deux exemples mesures :
//
//   * `doAccepterTransfertCompromis` posait `compromisPar` a son propre nom SANS verifier que le
//     transfert lui avait ete propose -- seul l'ecran filtrait ;
//   * `traiterPermis` ne verifiait RIEN : `requiresPost: 'maire_adjoint'` et « dans cette ville
//     uniquement » vivaient dans data.js, cote navigateur.
//
// ET UNE TROISIEME, TROUVEE DANS LE COMMENTAIRE DU DEPOT LUI-MEME : le gel successoral d'une
// ENTREPRISE avait sa porte depuis le chantier C (« un succession_gel invente suffisait a geler
// l'entreprise d'autrui »), celui d'un TERRAIN ecrivait encore le blob entier. Le meme defaut
// etait reste ouvert sur la moitie des actifs -- et il y est pire depuis ce lot, puisque
// `succession_gel` est la cle que les quatre portes consultent pour refuser toute action.
//
// LE TRAITEMENT EST PAR MECANISME, PAS PAR SITE : huit portes pour vingt-deux ecritures, et un
// ECRIVAIN INTERNE unique derriere elles. Le comportement des portes est eprouve en transaction
// annulee cote base (`banc-etat-terrain.sql`) ; l'accord de la porte du chantier avec les formules
// du jeu est prouve sur une grille de 184 chantiers (`comparer-progression-chantier.py`).
var RACINE = '/Users/fredericjasseron/ResPublica/';
var FICHIERS = ['supabase.js', 'plateau-justice-economie.js', 'plateau-pnj.js',
                'plateau-immobilier.js', 'plateau-personnage.js', 'plateau-chantiers.js'];
var CIBLE = (typeof CHEMIN_FICHIER === 'string') ? CHEMIN_FICHIER : null;
var SRC = {};
for (var f = 0; f < FICHIERS.length; f++) {
  SRC[FICHIERS[f]] = readFile((CIBLE === FICHIERS[f] && typeof CHEMIN_SOURCE === 'string')
    ? CHEMIN_SOURCE : RACINE + FICHIERS[f]);
}
// LES COMMENTAIRES DE CE LOT NOMMENT LES DEFAUTS FERMES : les compter reviendrait a declarer un
// defaut present parce qu'on explique qu'il a disparu. On mesure donc le CODE seul.
function sansCommentaires(texte) {
  return texte.split('\n').filter(function (l) { return l.trim().indexOf('//') !== 0; }).join('\n');
}
var CODE = {};
for (var g = 0; g < FICHIERS.length; g++) CODE[FICHIERS[g]] = sansCommentaires(SRC[FICHIERS[g]]);

var ko = 0, attendus = 0;
function att(n, c, detail) {
  attendus++;
  if (c) print('  ok  ' + n);
  else { print('  *** ' + n); if (detail !== undefined) print('        ' + detail); ko++; }
}
function compte(texte, motif) { return (texte.match(motif) || []).length; }
function partout(motif) {
  var n = 0;
  for (var i = 0; i < FICHIERS.length; i++) n += compte(CODE[FICHIERS[i]], motif);
  return n;
}
function bloc(fichier, nom) {
  var src = SRC[fichier];
  var i = src.indexOf('async function ' + nom + '(');
  if (i < 0) i = src.indexOf('function ' + nom + '(');
  if (i < 0) throw new Error('introuvable : ' + nom + ' dans ' + fichier);
  var j = src.indexOf('{', i), p = 0, k = j;
  while (k < src.length) { if (src[k] === '{') p++; else if (src[k] === '}') { p--; if (!p) break; } k++; }
  return src.slice(i, k + 1);
}

print('');
print('BANC DE L ETAT D UN TERRAIN');
print('============================================================================');

print('1. LA PLUS GROSSE SURFACE D ECRITURE CLIENTE DU JEU A DISPARU');
att('sbSetTerrainState n existe plus dans supabase.js',
    CODE['supabase.js'].indexOf('async function sbSetTerrainState(') < 0);
att('et plus aucun appel dans les six fichiers',
    partout(/sbSetTerrainState\(/g) === 0, partout(/sbSetTerrainState\(/g) + ' appel(s)');
att('sbGetTerrainState, qui ne fait que lire, est conservee',
    CODE['supabase.js'].indexOf('async function sbGetTerrainState(') >= 0);
att('sbGetTerrainsPossedesPar, qui ne fait que lire, est conservee',
    CODE['supabase.js'].indexOf('async function sbGetTerrainsPossedesPar(') >= 0);

print('');
print('2. LE PASSE-PLAT DES PORTES, ET LES DEUX HELPERS QUI L ENCADRENT');
var hActe = bloc('plateau-justice-economie.js', 'sbTerrainActe');
att('sbTerrainActe rend le VERDICT, pas un booleen -- un refus doit pouvoir etre nomme',
    hActe.indexOf('return await sbRpc(porte, args)') >= 0
    && hActe.indexOf('.catch(() => null)') >= 0);
var hRempl = bloc('plateau-justice-economie.js', 'remplacerTerrainState');
att('remplacerTerrainState remplace EN BLOC, il ne fusionne pas',
    hRempl.indexOf('state.terrainsState[buildingId] = etat;') >= 0
    && hRempl.indexOf('...') < 0);
var hRefus = bloc('plateau-justice-economie.js', 'signalerRefusTerrain');
att('signalerRefusTerrain nomme au moins vingt-cinq motifs de refus',
    compte(hRefus, /^\s{4}[a-z_]+:/gm) >= 25, compte(hRefus, /^\s{4}[a-z_]+:/gm) + ' motif(s)');
att('un verdict absent est dit comme une panne de transport, pas comme un refus metier',
    hRefus.indexOf("le serveur n'a pas répondu") >= 0);

print('');
print('3. LES VINGT-DEUX ECRITURES PASSENT PAR HUIT PORTES, UNE PAR MECANISME');
var ACTES = {
  'terrain_compromis_acte': 6, 'terrain_permis_acte': 5, 'terrain_chantier_acte': 2,
  'terrain_lots_acte': 6, 'terrain_reamenagement_poser': 1
};
var totalPortes = 0;
Object.keys(ACTES).sort().forEach(function (porte) {
  var n = partout(new RegExp("sbTerrainActe\\('" + porte + "'", 'g'));
  totalPortes += n;
  att(porte + ' : ' + ACTES[porte] + ' appel(s)', n === ACTES[porte], n + ' trouve(s)');
});
// Les deux portes successorales sont appelees par sbRpc direct : elles vivent dans
// plateau-personnage.js, qui ne connait pas les helpers de plateau-justice-economie.js.
att('terrain_succession_geler : 1 appel',
    partout(/sbRpc\('terrain_succession_geler'/g) === 1);
att('terrain_succession_annuler_compromis : 1 appel',
    partout(/sbRpc\('terrain_succession_annuler_compromis'/g) === 1);
att('soit VINGT-DEUX ecritures routees, le compte exact du releve',
    totalPortes + 2 === 22, (totalPortes + 2) + ' routee(s)');

// CHAQUE APPEL LIT SON VERDICT, ET AUCUN NE L'AVALE. Cette epreuve manquait : une contre-epreuve
// qui supprimait la lecture du verdict du transfert de compromis laissait ce banc VERT. Un banc
// qui ne rougit pas sur un defaut reintroduit ne prouve rien -- on le corrige avant de considerer
// le defaut ferme. On releve la VARIABLE de chaque appel, puis on exige son `.ok !== true`.
var sansVerdict = [];
['plateau-justice-economie.js', 'plateau-pnj.js', 'plateau-immobilier.js'].forEach(function (fic) {
  var code = CODE[fic];
  var re = /(?:const|let)\s+(\w+)\s*=\s*(?:await\s+)?sbTerrainActe\(/g, m;
  while ((m = re.exec(code)) !== null) {
    if (code.indexOf(m[1] + '.ok !== true') < 0) sansVerdict.push(fic + ':' + m[1]);
  }
});
att('les dix-neuf appels nommes lisent tous leur verdict',
    sansVerdict.length === 0, 'sans verdict : ' + sansVerdict.join(', '));
// Le vingtieme n'affecte pas de variable : il est non bloquant (le bail est deja signe ailleurs)
// et lit son verdict dans un `.then`.
att("et le vingtieme, non bloquant, lit le sien dans son `.then`",
    CODE['plateau-immobilier.js'].indexOf('.then(function (v) {') >= 0
    && CODE['plateau-immobilier.js'].indexOf('(!v || v.ok !== true)') >= 0);

print('');
print('4. LES SEIZE ACTES SONT NOMMES, ET AUCUN AUTRE');
var ACTES_NOMMES = [
  'compromis_signer', 'compromis_pret_demander', 'compromis_transfert_proposer',
  'compromis_transfert_accepter', 'achat_direct_deposer', 'achat_direct_accelerer',
  'permis_deposer', 'permis_prevenir_maire', 'permis_decider', 'permis_accelerer',
  'permis_plan_modifier', 'chantier_accelerer', 'chantier_materiaux_voler',
  'lot_ajouter', 'lot_fusion_proposer', 'lot_fusion_accepter', 'lot_fusion_refuser',
  'lot_louer', 'lot_bail_libere'
];
var manquants = ACTES_NOMMES.filter(function (a) {
  return partout(new RegExp("p_acte: '" + a + "'", 'g')) === 0;
});
att('les dix-neuf actes des quatre portes a liste close sont tous appeles',
    manquants.length === 0, 'manquants : ' + manquants.join(', '));

print('');
print('5. PLUS AUCUN SITE N ENVOIE L ETAT ENTIER');
// Les trois pires envoyaient `ts` ou `etat`, l'objet du cache -- dans la ligne que le cron fait
// avancer chaque nuit.
var bPrev = sansCommentaires(bloc('plateau-justice-economie.js', 'verifierInstructionPermis'));
// LA PIRE DES VINGT-DEUX : passive, declenchee a l'entree dans la piece pour N'IMPORTE QUEL
// joueur, et porteuse de TOUT l'etat (`sbSetTerrainState(..., ts)`). Elle ne pose meme plus le
// drapeau en memoire : la porte le pose elle-meme apres avoir revu ses trois conditions sous
// verrou, et `remplacerTerrainState` recopie ce que le serveur a arrete.
att("prevenir le maire n'envoie plus rien d'autre que l'acte",
    bPrev.indexOf("p_acte: 'permis_prevenir_maire'") >= 0
    && bPrev.indexOf('p_patch') < 0
    && bPrev.indexOf('ts.permis.mairePrevenu = true;') < 0);
att("et `rien_a_signaler` est traite comme le cas NORMAL, sans toast",
    bPrev.indexOf('signalerRefusTerrain') < 0 && bPrev.indexOf('vPrev.ok !== true') >= 0);
var bDec = sansCommentaires(bloc('plateau-justice-economie.js', 'traiterPermis'));
att('la decision du permis ne transmet que `permis` (et `constructionAutorisee` si valide)',
    bDec.indexOf('p_patch: valide') >= 0
    && bDec.indexOf("{ permis: etat.permis, constructionAutorisee: true }") >= 0);
att("et son verdict est lu : un refus ARRETE la decision",
    bDec.indexOf('vDec.ok !== true') >= 0
    && bDec.indexOf('vDec.ok !== true') < bDec.indexOf('remplacerTerrainState(buildingId, vDec.etat)'));
var bCorr = sansCommentaires(bloc('plateau-justice-economie.js', 'doCorrompreFonctionnairePermis'));
att("la corruption du fonctionnaire ne transmet que `permis`",
    bCorr.indexOf('p_patch: { permis: ts.permis }') >= 0);

print('');
print('6. LE CHANTIER : LE NAVIGATEUR N ENVOIE PLUS AUCUN NOMBRE');
var bCh = sansCommentaires(bloc('plateau-justice-economie.js', 'doCorrompreChantier'));
att("l'acceleration n'envoie ni progression, ni gain, ni duree",
    bCh.indexOf('p_acte: \'chantier_accelerer\'') >= 0
    && bCh.indexOf('p_patch') < 0 && bCh.indexOf('p_progression') < 0);
att("et elle recopie la progression ARRETEE PAR LE SERVEUR",
    bCh.indexOf('Number(vCh.progression)') >= 0 && bCh.indexOf('Number(vCh.reste)') >= 0);
att("appliquerVerrouPlan n'est plus appele dans ce chemin",
    bCh.indexOf('appliquerVerrouPlan(') < 0);
var bVol = sansCommentaires(bloc('plateau-justice-economie.js', 'confirmerVolMateriaux'));
att("le vol credite la quantite REELLEMENT emportee, pas celle que ce navigateur avait calculee",
    bVol.indexOf('qte = Number(vVol.quantite) || 0;') >= 0
    && bVol.indexOf('qte = Number(vVol.quantite) || 0;') < bVol.lastIndexOf('addToInventory('));
att("et il ne decremente plus le stock lui-meme",
    bVol.indexOf('stock[matiere] = Math.max(0,') < 0);

print('');
print('7. LES LOTS : UN LOT, PAS LE TABLEAU');
['doAjouterSubdivision', 'doFusionnerLot', 'doAccepterFusionLot', 'doRefuserFusionLot'].forEach(function (fn) {
  var b = sansCommentaires(bloc('plateau-justice-economie.js', fn));
  att(fn + ' n ecrit plus le tableau entier',
      b.indexOf('{ subdivisions: subdivisions }') < 0
      && compte(b, /p_lots: \[/g) === 1);
});
var bAcc = sansCommentaires(bloc('plateau-justice-economie.js', 'doAccepterFusionLot'));
att("le lot absorbe est designe par son IDENTIFIANT, plus par un indice de tableau",
    bAcc.indexOf('p_retirer: idVide ? [idVide] : null') >= 0
    && bAcc.indexOf('subdivisions.splice(') < 0);
var bProp = sansCommentaires(bloc('plateau-justice-economie.js', 'doFusionnerLot'));
att("et la proposition emporte cet identifiant avec elle",
    bProp.indexOf('idVide: lotVide.id || null') >= 0);
var bLib = sansCommentaires(bloc('plateau-immobilier.js', 'libererMiroirLot'));
att("la liberation du bail ne reecrit plus le decoupage entier",
    bLib.indexOf("p_acte: 'lot_bail_libere'") >= 0
    && bLib.indexOf('p_lots: [lot]') >= 0);

print('');
print('8. LA SUCCESSION : LE TERRAIN REJOINT L ENTREPRISE');
var bSucc = sansCommentaires(bloc('plateau-personnage.js', 'ouvrirSuccession'));
att('le gel passe par sa porte, et son verdict est lu',
    bSucc.indexOf("sbRpc('terrain_succession_geler'") >= 0
    && bSucc.indexOf("!r || r.ok !== true) return { ok: false, raison: 'echec_gel_terrain'") >= 0);
att("le nettoyage des engagements du defunt aussi",
    bSucc.indexOf("sbRpc('terrain_succession_annuler_compromis'") >= 0);
att("plus aucun blob de terrain compose dans cette fonction",
    bSucc.indexOf('succession_gel: successionId }') < 0
    && bSucc.indexOf('compromisExpireAt: null, achatDirect: null') < 0);

print('');
if (ko === 0) print('LES ' + attendus + ' EPREUVES SONT VERTES.');
else print('ECHEC : ' + ko + ' epreuve(s) sur ' + attendus + ' en defaut.');
