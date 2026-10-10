#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GENERATEUR DU MIROIR SERVEUR DES OFFRES DU BUREAU NATIONAL DE L'EMPLOI
(chantier 5, chaine 20, 10 octobre 2026).

POURQUOI CE MIROIR EXISTE. La prise d'un poste au BNE est un acte concurrent : plusieurs joueurs
peuvent viser la meme offre, et c'est le nombre de PLACES qui dit si le dernier arrive est accepte.
Or ce nombre ne vivait qu'en memoire du navigateur (OFFRES_EMPLOI_BNE, data.js). Le transmettre a
la porte serveur aurait ete exactement le defaut ferme le meme jour sur l'approvisionnement de
chantier : un parametre que le client dicte et qui BORNE une autorisation est une faille, meme
derriere une RPC -- un client modifie annoncant `places: 99` aurait pris un poste complet.

On ne recopie donc aucune valeur a la main. Le VRAI data.js est charge dans JavaScriptCore et les
offres sont capturees telles que le jeu les lit.

Sorties :
  python3 outils/generateurs/generer_offres_emploi_bne.py            -> resume
  python3 outils/generateurs/generer_offres_emploi_bne.py --sql      -> les VALUES
  python3 outils/generateurs/generer_offres_emploi_bne.py --empreinte

REJOUER apres toute modification de OFFRES_EMPLOI_BNE (ajout ou retrait d'une offre, changement
de places, de salaire, de portee ou de ville). Le libelle, lui, n'entre PAS dans le miroir : il
part en clair dans les messages du jeu, que le client compose -- seules les valeurs qui BORNENT
une decision serveur sont miroitees.
"""
import hashlib, json, os, subprocess, sys, tempfile

JSC = "/System/Library/Frameworks/JavaScriptCore.framework/Versions/Current/Helpers/jsc"


def _racine():
    """La racine du depot, trouvee en REMONTANT jusqu'a data.js, jamais en comptant des niveaux
    de repertoire -- le comptage a casse les huit generateurs au chantier 2H."""
    d = os.path.dirname(os.path.abspath(__file__))
    while d != os.path.dirname(d):
        if os.path.exists(os.path.join(d, "data.js")):
            return d
        d = os.path.dirname(d)
    raise SystemExit("racine du depot introuvable : aucun data.js en remontant")


RACINE = _racine()


def collecter():
    js = """
var document = { getElementById: function(){return null;}, addEventListener: function(){},
                 querySelector: function(){return null;}, querySelectorAll: function(){return [];},
                 createElement: function(){ return { style:{}, classList:{add:function(){},remove:function(){}},
                                                     addEventListener:function(){}, appendChild:function(){} }; },
                 body: { appendChild: function(){} } };
var window = { addEventListener: function(){}, location: { search: '' } };
var localStorage = { getItem: function(){return null;}, setItem: function(){}, removeItem: function(){} };
var navigator = { language: 'fr' };
load('%s/data.js');
var out = [];
Object.keys(OFFRES_EMPLOI_BNE).sort().forEach(function (k) {
  var o = OFFRES_EMPLOI_BNE[k];
  out.push({ id: k, job: o.job, portee: o.portee,
             ville: (o.ville === undefined ? null : o.ville),
             salaire: Number(o.salaire), places: Number(o.places) });
});
print(JSON.stringify(out));
""" % RACINE
    f = tempfile.NamedTemporaryFile('w', suffix='.js', delete=False, encoding='utf-8')
    f.write(js); f.close()
    try:
        p = subprocess.run([JSC, f.name], capture_output=True, text=True, timeout=120)
    finally:
        os.unlink(f.name)
    if p.returncode != 0 or not p.stdout.strip():
        print('ECHEC DU CHARGEMENT :', (p.stdout + p.stderr)[-800:])
        sys.exit(2)
    offres = json.loads(p.stdout.strip().splitlines()[-1])
    # UNE OFFRE SANS PLACES OU AVEC UN NOMBRE NON FINI FAIT ECHOUER LE GENERATEUR. Semer un
    # plafond invalide reviendrait a semer une place illimitee -- exactement ce que ce miroir
    # existe pour empecher.
    for o in offres:
        if not isinstance(o['places'], (int, float)) or o['places'] != o['places'] or o['places'] < 0:
            print("OFFRE INVALIDE : %s porte places=%r" % (o['id'], o['places'])); sys.exit(3)
        # LISTE CLOSE MESUREE, PAS DEVINEE : la premiere version de ce generateur n'admettait
        # que 'locale' et 'nationale', et il a ECHOUE sur `hotesse_ambassade`, qui est
        # 'internationale'. C'est exactement ce qu'on attend d'un garde-fou -- il a refuse de
        # semer un referentiel qu'il ne comprenait pas, au lieu de le tronquer en silence.
        if o['portee'] not in ('locale', 'nationale', 'internationale'):
            print("OFFRE INVALIDE : %s porte portee=%r" % (o['id'], o['portee'])); sys.exit(3)
        if o['portee'] == 'locale' and not o['ville']:
            print("OFFRE INVALIDE : %s est locale sans ville" % o['id']); sys.exit(3)
    return offres


def sql_nul(v):
    return 'NULL' if v is None else "'" + str(v).replace("'", "''") + "'"


def empreinte(offres):
    return hashlib.md5('\n'.join(
        '%s|%s|%s|%s|%d|%d' % (o['id'], o['job'], o['portee'], o['ville'] or '',
                               int(o['salaire']), int(o['places'])) for o in offres
    ).encode()).hexdigest()[:16]


if __name__ == '__main__':
    offres = collecter()
    if '--sql' in sys.argv:
        print(',\n'.join("  (%s, %s, %s, %s, %d, %d)"
                         % (sql_nul(o['id']), sql_nul(o['job']), sql_nul(o['portee']),
                            sql_nul(o['ville']), int(o['salaire']), int(o['places']))
                         for o in offres))
    elif '--empreinte' in sys.argv:
        print(empreinte(offres))
    else:
        print('offres : %d' % len(offres))
        for o in offres:
            print('  %-22s %-12s %-10s %-10s salaire %4d  places %d'
                  % (o['id'], o['job'], o['portee'], o['ville'] or '-',
                     int(o['salaire']), int(o['places'])))
        print('empreinte : %s' % empreinte(offres))
