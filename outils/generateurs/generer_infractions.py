#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GENERATEUR DU CATALOGUE CANONIQUE DES INFRACTIONS (12 octobre 2026).

LE SERVEUR NE SAVAIT PAS CE QU'EST UNE INFRACTION. Il ecrivait des peines -- `jugements.peine`
etait une CHAINE LIBRE composee par le navigateur, et `justice_rendre_sentence` l'archivait sans
jamais la confronter a un bareme. Le code penal du jeu existait pourtant deja, entier, mais
UNIQUEMENT dans le navigateur : trois tables de `plateau-core.js` et une fonction de resolution.

Ce generateur recopie ce code penal vers la base, SANS EN CHANGER UNE VALEUR, et calcule
l'empreinte qui permet de prouver que la base n'a pas derive du canon.

LA REGLE DE RESOLUTION N'EST PAS REECRITE ICI, ELLE EST REJOUEE. `getPeineParActe(acte, false)`
est la seule verite du projet sur la peine de reference d'une infraction :

    specifique = PEINES_ACTES[pays][acte]          -> si present, il GAGNE
    sinon type = ACTES_ILLEGAUX[acte].type         -> PEINES[type]
    sinon                                           -> PEINES.delit_mineur

Le generateur appelle donc la fonction REELLE, extraite du fichier de production, plutot que d'en
reimplementer la logique en Python -- une reimplementation aurait pu diverger sans bruit.

CE QUE LE GENERATEUR NE FAIT PAS, ET C'EST LE POINT LE PLUS IMPORTANT :
  . il n'invente aucune duree, aucune amende, aucune categorie ;
  . il ne fusionne aucun doublon -- les trois paires de nomenclature relevees par l'inventaire
    (`assassinat`/`assassiner_*`, `corruption_fonctionnaire`/`corrompre_fonct`,
    `achat_arme_illegal`/`acheter_arme_illegale`) portent des durees de reference DIFFERENTES,
    donc les resoudre l'une vers l'autre CHANGERAIT une peine. Elles sont rapportees comme
    arbitrages de game design, pas resolues ;
  . il n'etend rien aux trois autres empires : `PEINES_ACTES` ne declare que `republic`, et
    inventer un bareme pour Novomirsk serait un arbitrage.

Sorties :
  python3 outils/generateurs/generer_infractions.py              -> resume + doublons
  python3 outils/generateurs/generer_infractions.py --sql        -> les VALUES de `infractions`
  python3 outils/generateurs/generer_infractions.py --sql-categories
  python3 outils/generateurs/generer_infractions.py --empreinte

REJOUER apres toute modification de PEINES, PEINES_ACTES ou ACTES_ILLEGAUX.
"""
import hashlib
import json
import os
import subprocess
import sys
import tempfile

JSC = "/System/Library/Frameworks/JavaScriptCore.framework/Versions/Current/Helpers/jsc"


def _racine():
    d = os.path.dirname(os.path.abspath(__file__))
    while d != os.path.dirname(d):
        if os.path.exists(os.path.join(d, "data.js")):
            return d
        d = os.path.dirname(d)
    raise SystemExit("racine du depot introuvable : aucun data.js en remontant")


RACINE = _racine()

# L'EXTRACTION NE CHARGE PAS plateau-core.js, ET ELLE NE PEUT PAS. Le fichier est un module de
# navigateur : il lit `state`, `document`, `COUNTRIES`. On en decoupe donc les trois declarations
# litterales et la fonction de resolution, par leurs ancres de texte, puis on les evalue seules --
# exactement la methode de l'inventaire du 12 octobre 2026.
#
# `state` est pose a la main avec le seul champ que `getPeineParActe` lit : le pays. Et il n'y a
# qu'un pays a lire, parce que PEINES_ACTES n'en declare qu'un.
EXTRACTEUR = r"""
var src = readFile('%s/plateau-core.js');

function bloc(nom) {
  var i = src.indexOf('const ' + nom + ' = {');
  if (i < 0) throw new Error('bloc introuvable : ' + nom);
  var d = src.indexOf('{', i);
  var f = src.indexOf('\n};', i);
  if (f < 0) throw new Error('bloc non ferme : ' + nom);
  return '(' + src.slice(d, f + 2) + ')';
}

function fonction(nom) {
  var i = src.indexOf('function ' + nom + '(');
  if (i < 0) throw new Error('fonction introuvable : ' + nom);
  var f = src.indexOf('\n}', i);
  if (f < 0) throw new Error('fonction non fermee : ' + nom);
  return src.slice(i, f + 2);
}

var PEINES       = eval(bloc('PEINES'));
var PEINES_ACTES = eval(bloc('PEINES_ACTES'));
var ACTES_ILLEGAUX = eval(bloc('ACTES_ILLEGAUX'));
var state = { country: 'republic' };
eval(fonction('getPeineParActe'));

var ids = {};
Object.keys(ACTES_ILLEGAUX).forEach(function (k) { ids[k] = true; });
Object.keys(PEINES_ACTES.republic || {}).forEach(function (k) { ids[k] = true; });

var sortie = [];
Object.keys(ids).forEach(function (id) {
  var p = getPeineParActe(id, false);
  var acte = ACTES_ILLEGAUX[id];
  var propre = (PEINES_ACTES.republic || {})[id];
  sortie.push({
    id: id,
    libelle: p.label,
    categorie: acte ? acte.type : null,
    jours_reference: p.jours,
    amende_reference: p.amende,
    detect_rate: acte ? acte.detectRate : null,
    bareme_propre: !!propre,
    detectable: !!acte
  });
});

var categories = Object.keys(PEINES).map(function (c) {
  return { id: c, libelle: PEINES[c].label, jours_reference: PEINES[c].jours,
           amende_reference: PEINES[c].amendeBase };
});

print(JSON.stringify({
  infractions: sortie,
  categories: categories,
  empires_avec_bareme_propre: Object.keys(PEINES_ACTES)
}));
""" % RACINE


def extraire():
    f = tempfile.NamedTemporaryFile('w', suffix='.js', delete=False, encoding='utf-8')
    f.write(EXTRACTEUR)
    f.close()
    try:
        p = subprocess.run([JSC, f.name], capture_output=True, text=True, timeout=120)
    finally:
        os.unlink(f.name)
    if p.returncode != 0:
        print("ECHEC D'EXTRACTION DE plateau-core.js :")
        print((p.stdout + p.stderr)[-2000:])
        sys.exit(1)
    d = json.loads(p.stdout.strip().splitlines()[-1])

    # REFUS, PAS AVERTISSEMENT. Une infraction sans duree de reference rendrait la borne de peine
    # incalculable, donc la porte du juge inutilisable : le miroir ne doit pas naitre comme ca.
    for i in d['infractions']:
        if not isinstance(i['jours_reference'], int) or i['jours_reference'] < 1:
            print('REFUS : %s n a pas de duree de reference utilisable (%r)'
                  % (i['id'], i['jours_reference']))
            sys.exit(1)
        if not isinstance(i['amende_reference'], int) or i['amende_reference'] < 0:
            print('REFUS : %s a une amende de reference invalide (%r)'
                  % (i['id'], i['amende_reference']))
            sys.exit(1)
        if i['categorie'] is not None and i['categorie'] not in [c['id'] for c in d['categories']]:
            print('REFUS : %s porte la categorie inconnue %r' % (i['id'], i['categorie']))
            sys.exit(1)
    return d


# LES TROIS PAIRES DE NOMENCLATURE RELEVEES PAR L'INVENTAIRE. Elles ne sont PAS resolues : le
# generateur les rapporte, et c'est tout. Chacune porte deux durees de reference differentes, donc
# les fusionner changerait une peine -- ce que le cahier des charges interdit explicitement.
DOUBLONS = [
    ('assassinat', ['assassiner_mains', 'assassiner_arme', 'assassiner_feu']),
    ('tentative_assassinat', ['assassiner_mains', 'assassiner_arme', 'assassiner_feu']),
    ('corruption_fonctionnaire', ['corrompre_fonct']),
    ('achat_arme_illegal', ['acheter_arme_illegale']),
]


def doublons(infractions):
    """Rend les paires presentes, avec leurs deux references, pour le rapport."""
    par_id = {i['id']: i for i in infractions}
    out = []
    for gauche, droites in DOUBLONS:
        if gauche not in par_id:
            continue
        for droite in droites:
            if droite in par_id:
                out.append((gauche, par_id[gauche]['jours_reference'],
                            droite, par_id[droite]['jours_reference']))
    return out


def empreinte(infractions):
    """Porte sur les SEPT colonnes semees, triees par id en COLLATE "C".

    COLLATE "C" n'est pas decoratif : les identifiants portent des soulignes, que la collation
    par defaut de PostgreSQL ignore au poids primaire alors que Python trie par point de code.
    Le pendant SQL est infractions_empreinte_reelle(), ecrite sur la meme chaine et le meme tri."""
    corpus = '\n'.join(
        '%s|%s|%s|%d|%d|%s|%s' % (
            i['id'], i['libelle'], i['categorie'] or '',
            i['jours_reference'], i['amende_reference'],
            '' if i['detect_rate'] is None else str(i['detect_rate']),
            '1' if i['bareme_propre'] else '0')
        for i in sorted(infractions, key=lambda i: i['id']))
    return hashlib.md5(corpus.encode('utf-8')).hexdigest()[:16]


def _q(v):
    if v is None:
        return 'NULL'
    return "'" + str(v).replace("'", "''") + "'"


def sql(infractions):
    return ',\n'.join(
        "  (%s, %s, %s, %d, %d, %s, %s, %s)" % (
            _q(i['id']), _q(i['libelle']), _q(i['categorie']),
            i['jours_reference'], i['amende_reference'],
            'NULL' if i['detect_rate'] is None else str(i['detect_rate']),
            'true' if i['bareme_propre'] else 'false',
            'true' if i['detectable'] else 'false')
        for i in sorted(infractions, key=lambda i: i['id']))


def sql_categories(categories):
    return ',\n'.join(
        "  (%s, %s, %d, %d)" % (_q(c['id']), _q(c['libelle']),
                                c['jours_reference'], c['amende_reference'])
        for c in sorted(categories, key=lambda c: c['id']))


if __name__ == '__main__':
    d = extraire()
    inf, cat = d['infractions'], d['categories']
    if '--sql' in sys.argv:
        print(sql(inf))
    elif '--sql-categories' in sys.argv:
        print(sql_categories(cat))
    elif '--empreinte' in sys.argv:
        print(empreinte(inf))
    else:
        print('infractions canoniques : %d' % len(inf))
        print('  dont bareme propre   : %d' % sum(1 for i in inf if i['bareme_propre']))
        print('  dont detectables     : %d' % sum(1 for i in inf if i['detectable']))
        print('  dont bareme SANS acte (jamais detectables) : %d'
              % sum(1 for i in inf if i['bareme_propre'] and not i['detectable']))
        print('')
        print('%-28s %-13s %5s %7s %5s' % ('identifiant', 'categorie', 'jours', 'amende', 'det%'))
        for i in sorted(inf, key=lambda i: (i['jours_reference'], i['id'])):
            print('%-28s %-13s %5d %7d %5s%s'
                  % (i['id'], i['categorie'] or '--', i['jours_reference'],
                     i['amende_reference'],
                     '--' if i['detect_rate'] is None else i['detect_rate'],
                     '  (bareme propre)' if i['bareme_propre'] else ''))
        print('')
        print('categories generiques : %d  -- une categorie est une CLASSE, pas une charge :'
              % len(cat))
        print('elles ne sont jamais une qualification finale recevable.')
        for c in sorted(cat, key=lambda c: c['jours_reference']):
            print('  %-13s %2d j  %5d FR  %s' % (c['id'], c['jours_reference'],
                                                 c['amende_reference'], c['libelle']))
        print('')
        dbl = doublons(inf)
        print('PAIRES DE NOMENCLATURE NON RESOLUES : %d' % len(dbl))
        print('Aucune n est resolue, et la raison est la meme pour toutes : les deux cotes')
        print('portent des durees de reference DIFFERENTES, donc fusionner changerait une peine.')
        for g, jg, dr, jd in dbl:
            print('  %-26s %2d j   <->  %-24s %2d j' % (g, jg, dr, jd))
        print('')
        print('empires avec un bareme propre : %s' % ', '.join(d['empires_avec_bareme_propre']))
        print('les autres retombent integralement sur les categories -- non etendu ici.')
        print('')
        print('empreinte : %s' % empreinte(inf))
