#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GENERATEUR DU MIROIR DES VILLES (chantier 4E, 7 octobre 2026).

LE SERVEUR NE SAVAIT PAS CE QU'EST UNE VILLE. Il manipulait pourtant des identifiants de
ville partout : `republic_mairie-capitale`, `commissariat_ville_a`, `tribunal_ville_b`,
`republic_mairie_caserne`. Faute de referentiel, il n'avait aucun moyen de distinguer une
VRAIE ville d'un segment quelconque -- ni de refuser `caserne`, qui n'est pas une ville mais
une zone militaire hors des villes, et ne releve donc d'aucune mairie.

Ce generateur seme les douze couples (pays, ville) canoniques depuis VILLES (data.js) et
calcule l'empreinte qui permet de prouver que la base n'a pas derive.

Sorties :
  python3 outils/generateurs/generer_villes.py            -> resume
  python3 outils/generateurs/generer_villes.py --sql      -> les VALUES
  python3 outils/generateurs/generer_villes.py --empreinte

REJOUER apres toute modification de VILLES (nouvelle ville, renommage, nouvel empire).

LES ZONES SPECIALES NE SONT PAS SEMEES, et ce n'est pas un oubli : caserne et QHS existent
dans WORLD comme zones (isSpecial), hors des villes et hors de toute mairie. Les faire entrer
ici donnerait au serveur la preuve du contraire.
"""
import hashlib, json, os, subprocess, sys, tempfile

JSC = "/System/Library/Frameworks/JavaScriptCore.framework/Versions/Current/Helpers/jsc"


def _racine():
    """La racine du depot, trouvee en REMONTANT jusqu'a data.js (voir le commentaire
    de generer_postes_nommes.py : un repere ne se decale pas)."""
    d = os.path.dirname(os.path.abspath(__file__))
    while d != os.path.dirname(d):
        if os.path.exists(os.path.join(d, "data.js")):
            return d
        d = os.path.dirname(d)
    raise SystemExit("racine du depot introuvable : aucun data.js en remontant")


RACINE = _racine()

# L'ORDRE DES PAYS EST CELUI DE COUNTRIES, celui des villes celui de VILLES : tous deux
# declares, aucun tri alphabetique impose. Le rang sert a l'affichage cote base (« les trois
# villes de l'empire, dans l'ordre »), exactement ce que rend villesDe() cote navigateur.
#
# ON VERIFIE AUSSI WORLD. Le referentiel et la carte doivent nommer la meme ville du meme nom :
# c'est la divergence que ce chantier a trouvee sur HUIT villes sur douze. Le generateur refuse
# de produire quoi que ce soit si elle reapparait -- un controle qui ne bloque pas ne controle
# rien.
EXTRACTEUR = """
load('%s/data.js');
var sortie = [], desaccords = [], zones = [];
Object.keys(COUNTRIES).forEach(function (pays) {
  var t = VILLES[pays];
  if (!t) { desaccords.push(pays + ' : empire sans villes dans VILLES'); return; }
  Object.keys(t).forEach(function (ville, i) {
    var monde = WORLD[pays] && WORLD[pays][ville];
    if (!monde) desaccords.push(pays + '/' + ville + ' : absente de WORLD');
    else if (monde.name !== t[ville].nom) {
      desaccords.push(pays + '/' + ville + ' : VILLES dit « ' + t[ville].nom +
                      ' », WORLD dit « ' + monde.name + ' »');
    } else if (monde.isSpecial) {
      desaccords.push(pays + '/' + ville + ' : WORLD la marque isSpecial, ce n est pas une ville');
    }
    sortie.push({ pays: pays, ville: ville, nom: t[ville].nom,
                  est_capitale: t[ville].capitale === true, rang: i + 1 });
  });
  // Les zones hors-ville de cet empire, listees pour le rapport : elles doivent etre dans
  // WORLD et PAS dans VILLES.
  Object.keys(WORLD[pays] || {}).forEach(function (v) {
    if (WORLD[pays][v].isSpecial) {
      zones.push({ pays: pays, zone: v, nom: WORLD[pays][v].name,
                   dans_villes: !!(VILLES[pays] && VILLES[pays][v]) });
    }
  });
});
print(JSON.stringify({ villes: sortie, desaccords: desaccords, zones: zones }));
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
        print('ECHEC DE CHARGEMENT DE data.js :')
        print((p.stdout + p.stderr)[-2000:])
        sys.exit(1)
    d = json.loads(p.stdout.strip().splitlines()[-1])

    # REFUS, pas avertissement. Si WORLD et VILLES se contredisent, le miroir serait seme sur
    # un desaccord et le jeu continuerait d'afficher deux noms pour un meme lieu.
    if d['desaccords']:
        print('REFUS : VILLES et WORLD ne disent pas la meme chose.')
        for m in d['desaccords']:
            print('  - %s' % m)
        sys.exit(1)
    for z in d['zones']:
        if z['dans_villes']:
            print('REFUS : %s/%s est une zone speciale et figure dans VILLES.' % (z['pays'], z['zone']))
            sys.exit(1)
    return d


def empreinte(villes):
    """Porte sur les CINQ colonnes semees, triees par (pays, ville) en COLLATE "C".

    COLLATE "C" N'EST PAS DECORATIF : Python trie par point de code, PostgreSQL par la
    collation de la colonne, qui ignore la ponctuation au poids primaire. Sans COLLATE "C"
    cote SQL, les deux formules trient differemment des qu'un identifiant porte un tiret ou
    un souligne -- et `ville_a` / `ville_b` en portent.

    Le pendant SQL est villes_empreinte_reelle(), ecrite sur la meme chaine et le meme tri."""
    corpus = '\n'.join('%s|%s|%s|%s|%d' % (v['pays'], v['ville'], v['nom'],
                                           '1' if v['est_capitale'] else '0', v['rang'])
                       for v in sorted(villes, key=lambda v: (v['pays'], v['ville'])))
    return hashlib.md5(corpus.encode('utf-8')).hexdigest()[:16]


def sql(villes):
    def q(v):
        return "'" + str(v).replace("'", "''") + "'"
    return ',\n'.join(
        "  (%s, %s, %s, %s, %d)" % (q(v['pays']), q(v['ville']), q(v['nom']),
                                    'true' if v['est_capitale'] else 'false', v['rang'])
        for v in sorted(villes, key=lambda v: (v['pays'], v['ville'])))


if __name__ == '__main__':
    d = extraire()
    villes = d['villes']
    if '--sql' in sys.argv:
        print(sql(villes))
    elif '--empreinte' in sys.argv:
        print(empreinte(villes))
    else:
        print('villes canoniques : %d' % len(villes))
        for v in villes:
            print('  %-9s %-9s rang %d  %s%s' % (v['pays'], v['ville'], v['rang'], v['nom'],
                                                 '  (capitale)' if v['est_capitale'] else ''))
        print('')
        print('zones hors-ville, volontairement absentes du referentiel : %d' % len(d['zones']))
        for z in d['zones']:
            print('  %-9s %-9s %s' % (z['pays'], z['zone'], z['nom']))
        print('')
        print('VILLES et WORLD concordent sur les %d villes.' % len(villes))
        print('empreinte : %s' % empreinte(villes))
