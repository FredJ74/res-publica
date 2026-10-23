// #94 : les deux familles passent maintenant par les commandes atomiques.
// Les 23 garanties sont conservees ; tests comportementaux et PostgreSQL dans les bancs dedies.
var src = readFile(typeof CHEMIN_SOURCE === 'string'
  ? CHEMIN_SOURCE : '/Users/fredericjasseron/ResPublica/plateau-justice-economie.js');

var ko = 0, attendus = 0;
function att(n, c, detail) {
  attendus++;
  if (c) print('  ok  ' + n);
  else { print('  *** ' + n); if (detail !== undefined) print('        ' + detail); ko++; }
}
function compte(texte, motif) { return (texte.match(motif) || []).length; }
// LES COMMENTAIRES DE CE LOT NOMMENT LES DEFAUTS FERMES : les compter reviendrait a declarer un
// defaut present parce qu'on explique qu'il a disparu. On mesure donc le CODE seul.
function sansCommentaires(texte) {
  return texte.split('\n').filter(function (l) { return l.trim().indexOf('//') !== 0; }).join('\n');
}
function fonction(nom) {
  var i = src.indexOf('async function ' + nom + '(');
  if (i < 0) i = src.indexOf('function ' + nom + '(');
  if (i < 0) throw new Error('introuvable : ' + nom);
  var j = src.indexOf('{', i), p = 0, k = j;
  while (k < src.length) { if (src[k] === '{') p++; else if (src[k] === '}') { p--; if (!p) break; } k++; }
  return src.slice(i, k + 1);
}

var construction = sansCommentaires(fonction('confirmerConstruction'));
var reconfig = sansCommentaires(fonction('confirmerReconfiguration'));
var reconfigAvecCommentaires = fonction('confirmerReconfiguration');
var code = sansCommentaires(src);

print('');
print('1. LE MOTEUR DE L ENTREPOT N EST PLUS APPELE PAR LE NAVIGATEUR');
att("aucun sbRpc('approvisionner_chantier') dans tout le fichier",
    compte(code, /sbRpc\('approvisionner_chantier'/g) === 0,
    compte(code, /sbRpc\('approvisionner_chantier'/g) + ' appel(s)');
att('plus aucune tresorerie transmise au serveur',
    compte(code, /p_tresorerie:/g) === 0, compte(code, /p_tresorerie:/g) + ' occurrence(s)');
att('plus aucun stock de chantier transmis au serveur',
    compte(code, /p_stock_chantier:/g) === 0, compte(code, /p_stock_chantier:/g) + ' occurrence(s)');

print('');
print('2. LE REPLI QUI FAISAIT PASSER UNE PANNE POUR UN SUCCES A DISPARU');
att('plus aucun `|| { depense: 0 ...}`',
    compte(code, /\|\|\s*\{\s*depense:\s*0/g) === 0,
    compte(code, /\|\|\s*\{\s*depense:\s*0/g) + ' occurrence(s)');
att('plus aucun test `plan.depense > 0`',
    compte(code, /plan\.depense\s*>\s*0/g) === 0);

print('');
print('3. UNE COMMANDE COMMUNE PAR FAMILLE, AUCUN STOCK OU BUDGET CLIENT');
att('aucun appel historique a chantier_approvisionner', compte(code, /sbRpc\('chantier_approvisionner'/g) === 0);
att('construction : une commande de lancement', compte(construction, /constructionExecuterCommande\('lancer'/g) === 1);
att('construction sans second approvisionnement', compte(construction, /sbRpc\(/g) === 0);
att('reamenagement : une commande atomique', compte(reconfig, /constructionExecuterCommande\('reamenager'/g) === 1);
att('seul le plan est transmis', reconfig.indexOf("'reamenager', { lots }") >= 0 && reconfig.indexOf('p_chantier') < 0);
att('aucun besoin impose par le client', compte(code, /p_besoin: besoinJ1/g) === 0);
print('4. VERDICTS ET CONTEXTES');
att('construction refuse le verdict absent', construction.indexOf('if(!r)return') >= 0);
att('reamenagement refuse le verdict absent', reconfig.indexOf('!r || !contexteNavigationRueValide(contexte)') >= 0);
att('aucune fausse confirmation locale', reconfig.indexOf('poseCh') < 0 && reconfig.indexOf('appro.') < 0);
att('aucun snapshot financier recopie', reconfig.indexOf('state.arg =') < 0 && reconfig.indexOf('state.liquide =') < 0);
att('journal apres confirmation seulement', reconfig.indexOf('addJournalEntry(') > reconfig.indexOf('if (!r ||'));
print('5. AUCUN PAIEMENT OU CHANTIER COMPOSE PAR LE NAVIGATEUR');
att('construction sans ecriture directe', compte(construction, /sbSetTerrainState\(/g) === 0);
att('reamenagement sans porte legacy ou ecriture directe', compte(reconfig, /sbTerrainActe\(|sbSetTerrainState\(|setTerrainState\(/g) === 0);
att('aucun paiement avant la transaction', reconfig.indexOf('deduireCoutOrdre') < 0);
att('aucun dimensionnement impose au serveur', reconfig.indexOf('creerChantierReamenagement') < 0 && reconfig.indexOf('verserAuChantier') < 0);
att('plan fige avant la requete asynchrone', reconfig.indexOf('JSON.parse(JSON.stringify(') >= 0 && reconfig.indexOf('JSON.parse(') < reconfig.indexOf('await constructionExecuterCommande'));
print('');
print('6. CE QUE LE NAVIGATEUR NE CALCULE PLUS');
att('il ne recalcule plus les prix des trois materiaux pour cet achat',
    compte(code, /prix\[m\] = \(typeof RESSOURCES_ECONOMIE/g) === 0,
    compte(code, /prix\[m\] = \(typeof RESSOURCES_ECONOMIE/g) + ' occurrence(s)');
att("il ne relit plus l'etat de l'entrepot avant d'acheter",
    compte(construction, /sbGetBatimentEtat/g) === 0
    && compte(reconfig, /sbGetBatimentEtat/g) === 0);

print('');
if (ko === 0) print('LES ' + attendus + ' EPREUVES SONT VERTES.');
else print('ECHEC : ' + ko + ' epreuve(s) sur ' + attendus + ' en defaut.');
