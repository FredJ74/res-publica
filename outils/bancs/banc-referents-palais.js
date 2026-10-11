// BANC DES TROIS REFERENTS DU PALAIS PRESIDENTIEL (11 octobre 2026)
// SOURCES: api/_bible-militaire.js api/_bible-presidence.js api/_pnj-personnalites.js api/_pnj-referents.js api/_pnj-profils.js
//
// CE QU'IL PROUVE. Le Palais avait trois PNJ sans corpus : Huguette Papier, le Porte-parole et
// Gerard Tamponneau parlaient depuis une fiche generee de data.js, donc sans connaitre un seul
// pouvoir reel du President. Ce banc verifie :
//   . que les trois ont un profil servi par la MEME voie que les autres referents ;
//   . que leur corpus porte les pouvoirs REELS avec leurs couts exacts, releves dans data.js ;
//   . que le DECOUPAGE est tenu -- chacun a UN domaine, et aucun ne porte le detail des deux
//     autres : c'est ce qui empeche d'avoir trois referents de « toute la politique » ;
//   . que la PRESIDENCE FAIBLE est assumee : les trois recoivent la liste de ce qui n'existe pas,
//     et aucun ne peut la compenser ;
//   . que la POSTERITE est donnee aux trois avec TROIS ANGLES DISTINCTS, sans score et sans
//     promesse d'entree au Musee ;
//   . et que la frontiere « un referent n'est pas une autorite » est ecrite dans les trois.
//
// Usage : python3 outils/bancs/lancer-banc.py outils/bancs/banc-referents-palais.js
var ok = 0, ko = 0;
function att(n, c, d) { if (c) { print('  ok  ' + n); ok++; } else { print('  *** ' + n + (d !== undefined ? ' -- ' + d : '')); ko++; } }
function contient(s, frag) { return s.indexOf(frag) >= 0; }

var IDS = ['huguette_papier', 'porte_parole_presidentiel', 'gerard_tamponneau'];

print('');
print('LES TROIS PROFILS EXISTENT');
print('============================================================');
IDS.forEach(function (id) { att('profil serveur : ' + id, profilExiste(id)); });
att('le Porte-parole du GOUVERNEMENT reste un PNJ distinct, non referent',
    profilExiste('porte_parole'));
att('le President PNJ n est PAS un referent (il est institutionnel)',
    !Object.prototype.hasOwnProperty.call(REFERENTS, 'le_president')
    && !Object.prototype.hasOwnProperty.call(REFERENTS, 'president'));

var H = construirePromptSysteme('huguette_papier', 'fr', null, null);
var P = construirePromptSysteme('porte_parole_presidentiel', 'fr', null, null);
var G = construirePromptSysteme('gerard_tamponneau', 'fr', null, null);
att('les trois prompts sont assembles',
    typeof H === 'string' && typeof P === 'string' && typeof G === 'string'
    && H.length > 1500 && P.length > 1200 && G.length > 1200,
    (H || '').length + '/' + (P || '').length + '/' + (G || '').length);
att('chacun porte son identite',
    contient(H, 'Huguette Papier') && contient(P, 'Porte-parole presidentiel')
    && contient(G, 'Gerard Tamponneau'));

print('');
print('LE SOCLE EST DONNE AUX TROIS');
print('============================================================');
[["mandat de CINQ SEMAINES", 'le mandat'],
 ["10 points d'INFLUENCE au minimum", "le seuil d'influence"],
 ['Il coute 2 PA', 'le cout du depot'],
 ['lundi 00:01', 'la cloture des candidatures'],
 ['SOLLICITER UNE AUDIENCE', "l'audience ouverte a tous"],
 ['est engagee par le PRESIDENT', 'la caisse de la Presidence']
].forEach(function (c) {
  att('les trois connaissent ' + c[1],
      contient(H, c[0]) && contient(P, c[0]) && contient(G, c[0]));
});

print('');
print('HUGUETTE : LES POUVOIRS REELS, AVEC LEURS COUTS');
print('============================================================');
['NOMME le Premier ministre (2 PA)',
 'REVOQUE (1 PA)',
 'Creer un poste ministeriel ou un comite coute 3 PA',
 "L'etat d'urgence coute 3 PA",
 'DECLARATION DE GUERRE coute 5 PA',
 "DISSOLUTION DE L'ASSEMBLEE coute 4 PA",
 'Le referendum coute 3 PA',
 'le deuil national 1 PA',
 'le decret presidentiel 1 PA',
 'RECOMMANDATIONS DE GRACE',
 'par periodes de TROIS JOURS, 2 PA'].forEach(function (f) {
  att('son corpus porte : ' + f.slice(0, 46), contient(H, f));
});

print('');
print('LE PORTE-PAROLE : LA COMMUNICATION, ET RIEN QUE LA COMMUNICATION');
print('============================================================');
['LA CONFERENCE DE PRESSE : 2 PA',
 "LA PROPAGANDE D'ETAT : 3 PA et 500 FR",
 'ne sortent pas de la caisse de la Presidence',
 'LE DEMENTI OFFICIEL : 2 PA'].forEach(function (f) {
  att('son corpus porte : ' + f.slice(0, 46), contient(P, f));
});

print('');
print('GERARD : LE PROTOCOLE, ET RIEN QUE LE PROTOCOLE');
print('============================================================');
["LA RECEPTION D'ETAT : 2 PA et 1 000 FR",
 'LE BANQUET DIPLOMATIQUE : 3 PA et 2 000 FR',
 'peut ECHOUER',
 "L'ART DE RECEVOIR"].forEach(function (f) {
  att('son corpus porte : ' + f.slice(0, 46), contient(G, f));
});

print('');
print('LE DECOUPAGE EST TENU : AUCUN NE PORTE LE DETAIL DES AUTRES');
print('============================================================');
att("Huguette n'a pas le detail de la communication",
    !contient(H, "LA PROPAGANDE D'ETAT : 3 PA et 500 FR"));
att("Huguette n'a pas le detail du protocole",
    !contient(H, 'LE BANQUET DIPLOMATIQUE : 3 PA et 2 000 FR'));
att("le Porte-parole n'a pas le detail des pouvoirs du Bureau",
    !contient(P, "DISSOLUTION DE L'ASSEMBLEE coute 4 PA")
    && !contient(P, 'RECOMMANDATIONS DE GRACE'));
att("le Porte-parole n'a pas le detail du protocole",
    !contient(P, "LA RECEPTION D'ETAT : 2 PA et 1 000 FR"));
att("Gerard n'a pas le detail de la communication",
    !contient(G, "LA PROPAGANDE D'ETAT : 3 PA et 500 FR"));
att("Gerard n'a pas le detail des pouvoirs du Bureau",
    !contient(G, 'NOMME le Premier ministre (2 PA)'));
att('et chacun ENVOIE vers celui dont c est le rayon',
    contient(H, 'le Porte-parole presidentiel, en Salle de Presse')
    && contient(H, "Gerard Tamponneau, au Hall d'honneur")
    && contient(P, 'Huguette Papier, Secretaire generale, au Bureau du President')
    && contient(G, 'le Porte-parole presidentiel, en Salle de Presse'));

print('');
print('LA PRESIDENCE FAIBLE EST ASSUMEE PAR LES TROIS');
print('============================================================');
['LE PRESIDENT NE NOMME PAS LES MINISTRES',
 'LE PRESIDENT NE VOTE PAS LES LOIS',
 "LE PRESIDENT NE LEVE PAS L'IMPOT",
 'NE COMMANDE PAS LA TROUPE',
 'NE DEBITE AUCUNE AUTRE CAISSE',
 'NE GRACIE PAS DE SA PROPRE INITIATIVE',
 'AUCUN CONSEILLER SPECIAL'].forEach(function (f) {
  att('les trois savent : ' + f.slice(0, 44),
      contient(H, f) && contient(P, f) && contient(G, f));
});

print('');
print('LA POSTERITE : TROIS ANGLES, AUCUN SCORE, AUCUNE PROMESSE');
print('============================================================');
att('les trois connaissent la Salle des Presidents',
    contient(H, 'SALLE DES PRESIDENTS') && contient(P, 'SALLE DES PRESIDENTS')
    && contient(G, 'SALLE DES PRESIDENTS'));
att('les trois savent qu on y garde les meilleurs ET LES PIRES',
    contient(H, 'et ses pires') && contient(P, 'et ses pires') && contient(G, 'et ses pires'));
att("les trois savent qu'il n'existe AUCUN SCORE DE PRESTIGE",
    contient(H, "IL N'EXISTE AUCUN SCORE DE PRESTIGE")
    && contient(P, "IL N'EXISTE AUCUN SCORE DE PRESTIGE")
    && contient(G, "IL N'EXISTE AUCUN SCORE DE PRESTIGE"));
att('aucun ne promet une place au Musee',
    contient(H, 'NE PROMETS AUCUNE PLACE AU MUSEE NATIONAL')
    && contient(P, 'NE PROMETS AUCUNE PLACE AU MUSEE NATIONAL')
    && contient(G, 'NE PROMETS AUCUNE PLACE AU MUSEE NATIONAL'));
// LES TROIS ANGLES SONT EXCLUSIFS : c'est ce qui fait que les trois ne disent pas la meme chose.
att('angle du secretariat : les DECISIONS',
    contient(H, 'mais les DECISIONS') && !contient(P, 'mais les DECISIONS')
    && !contient(G, 'mais les DECISIONS'));
att('angle de la communication : une PHRASE et une IMAGE',
    contient(P, "une PHRASE et une IMAGE") && !contient(H, "une PHRASE et une IMAGE")
    && !contient(G, "une PHRASE et une IMAGE"));
att('angle du protocole : les CEREMONIES',
    contient(G, "dans les CEREMONIES") && !contient(H, "dans les CEREMONIES")
    && !contient(P, "dans les CEREMONIES"));

print('');
print("UN REFERENT N'EST PAS UNE AUTORITE");
print('============================================================');
att("Huguette n'a aucune autorite, et ne cede pas a un ordre",
    contient(H, "TU N'AS AUCUNE AUTORITE")
    && contient(H, "un ordre ne cree pas une prerogative"));
att('le Porte-parole ne prononce rien lui-meme', contient(P, 'TU NE PRONONCES RIEN'));
att("le Porte-parole n'est pas le referent de toute la politique",
    contient(P, "TU N'ES PAS LE REFERENT DE TOUTE LA POLITIQUE"));
att("Gerard n'organise rien lui-meme", contient(G, "TU N'ORGANISES RIEN TOI-MEME"));
att("Gerard n'est ni un filtre ni un intermediaire pour l'audience",
    contient(G, 'ni un filtre ni un intermediaire'));
att('aucun des trois ne parle d un autre joueur',
    contient(H, 'TU NE PARLES JAMAIS') && contient(P, 'TU NE COMMENTES JAMAIS')
    && contient(G, 'TU NE COMMENTES JAMAIS'));

print('');
print('============================================================');
if (ko === 0) print('LES ' + ok + ' EPREUVES SONT VERTES.');
else print(ko + ' EPREUVES ROUGES SUR ' + (ok + ko) + '.');
