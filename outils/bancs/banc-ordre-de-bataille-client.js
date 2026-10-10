// BANC DE LA LECTURE CLIENTE DE L'ORDRE DE BATAILLE (10 octobre 2026, cloture de la caserne)
// SOURCES: supabase.js
//
// CE QU'IL PROUVE, et que le banc SQL ne peut pas prouver. Le banc SQL etablit que la porte
// `militaire_compagnies_lisibles` projette correctement et que la table n'est plus lisible en
// direct. Il reste une question purement cliente : les TRENTE-TROIS sites d'appel du navigateur
// passent-ils bien par la porte, et la forme de sortie est-elle restee la meme ?
//
// `sbGetCompagnies` est l'unique point de lecture. Ce banc remplace le transport par deux espions
// et verifie trois choses :
//   . elle appelle la RPC, et JAMAIS le SELECT REST sur compagnies_militaires ;
//   . elle rend toujours un tableau de `{id, ...data}` -- la forme que les ecrans consomment ;
//   . le filtre par pays tient encore, et une porte muette rend un tableau vide, jamais une
//     exception : un ecran militaire qui leverait a la lecture serait pire qu'un ecran vide.
//
// Usage : python3 outils/bancs/lancer-banc.py outils/bancs/banc-ordre-de-bataille-client.js

var ok = 0, ko = 0;
function att(n, c, d) {
  if (c) { print('  ok  ' + n); ok++; }
  else { print('  *** ' + n + (d !== undefined ? ' -- ' + d : '')); ko++; }
}

var appelsRpc = [], appelsRest = [];
var reponseRpc = null;

sbRpc = function (nom, args) { appelsRpc.push(nom); return Promise.resolve(reponseRpc); };
sbGet = function (table, filtre) { appelsRest.push(table); return Promise.resolve([]); };

print('');
print("LECTURE CLIENTE DE L'ORDRE DE BATAILLE");
print('============================================================================');

var CIE = 'compagnie-republic-1';
reponseRpc = [
  { id: CIE, data: { pays: 'republic', capitaineNom: null,
                     sections: [{ id: 's1', lieutenantNom: 'Vince Kubrick', mission: 'securiser',
                                  soldats: [{ ville: null, buildingId: null, roomId: null,
                                              leaderCourant: 'Vince Kubrick' }] }] } },
  { id: 'compagnie-narco-1', data: { pays: 'narco', sections: [] } }
];

appelsRpc = []; appelsRest = [];
sbGetCompagnies('republic').then(function (r) {
  att('la porte serveur est appelee', appelsRpc.length === 1
      && appelsRpc[0] === 'militaire_compagnies_lisibles', appelsRpc.join(','));
  att('aucun SELECT direct sur compagnies_militaires', appelsRest.length === 0,
      appelsRest.join(','));
  att('la forme de sortie est inchangee : un tableau de {id, ...data}',
      Array.isArray(r) && r.length === 1 && r[0].id === CIE && r[0].pays === 'republic',
      JSON.stringify(r && r.map(function (x) { return x.id; })));
  att('le blob est deplie a plat, comme avant',
      r[0].sections && r[0].sections[0].lieutenantNom === 'Vince Kubrick');
  att('le filtre par pays tient : la compagnie etrangere est ecartee',
      r.every(function (x) { return x.pays === 'republic'; }));
}).then(function () {
  // UNE COMPAGNIE SANS CAPITAINE EST UN ETAT NORMAL DU JEU, pas une anomalie : la lecture ne
  // doit ni la masquer ni la rejeter.
  return sbGetCompagnies('republic').then(function (r) {
    att('une compagnie sans capitaine est rendue telle quelle',
        r.length === 1 && r[0].capitaineNom === null, JSON.stringify(r[0].capitaineNom));
    att('ses sections et son lieutenant survivent a l absence de capitaine',
        r[0].sections.length === 1 && r[0].sections[0].lieutenantNom === 'Vince Kubrick');
  });
}).then(function () {
  // SANS ARGUMENT DE PAYS, la porte decide seule : elle ne rend de toute facon que le pays de
  // l'appelant. Le filtre client reste une seconde garde, jamais la seule.
  return sbGetCompagnies().then(function (r) {
    att('sans pays demande, tout ce que la porte rend passe', r.length === 2, String(r.length));
  });
}).then(function () {
  reponseRpc = null;
  return sbGetCompagnies('republic').then(function (r) {
    att('une porte muette rend un tableau vide, jamais une exception',
        Array.isArray(r) && r.length === 0, JSON.stringify(r));
  });
}).then(function () {
  print('');
  if (ko === 0) print('LES ' + ok + ' EPREUVES SONT VERTES.');
  else print('ECHEC : ' + ko + ' epreuve(s) sur ' + (ok + ko) + '.');
}).catch(function (e) { print('ECHEC : exception -- ' + e + '\n' + (e && e.stack)); });
