#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GENERATEUR DU MIROIR DES REGLES DE NOMINATION (chantier « autorite des postes », 15 sept. 2026).

Meme doctrine que les autres miroirs du depot : le serveur doit savoir QUI a le droit de nommer
QUOI, sinon il ne peut pas verifier une nomination -- et le navigateur reste libre de pretendre
qu'il en a le droit. On ne recopie pas POSTES_NOMMES_EXCLUSIFS a la main : on charge le VRAI
data.js dans JavaScriptCore et on capture la table telle que le jeu la lit.

Sorties :
  python3 .scratch/generer_postes_nommes.py            -> resume
  python3 .scratch/generer_postes_nommes.py --sql      -> les VALUES
  python3 .scratch/generer_postes_nommes.py --empreinte

REJOUER apres toute modification de POSTES_NOMMES_EXCLUSIFS (ajout d'un poste, changement de
nommePar ou de scope).
"""
import hashlib, json, os, subprocess, sys, tempfile

JSC = "/System/Library/Frameworks/JavaScriptCore.framework/Versions/Current/Helpers/jsc"
RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

EXTRACTEUR = """
load('%s/data.js');
var sortie = [];
Object.keys(POSTES_NOMMES_EXCLUSIFS).forEach(function (id) {
  var r = POSTES_NOMMES_EXCLUSIFS[id];
  sortie.push({ poste_id: id, label: r.label || id, nomme_par: r.nommePar || null,
                scope: r.scope || 'pays' });
});
sortie.sort(function (a, b) { return a.poste_id < b.poste_id ? -1 : 1; });
print(JSON.stringify(sortie));
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
    return json.loads(p.stdout.strip().splitlines()[-1])


def empreinte(regles):
    corpus = '\n'.join('%s|%s|%s' % (r['poste_id'], r['nomme_par'], r['scope']) for r in regles)
    return hashlib.md5(corpus.encode()).hexdigest()[:16]


def sql(regles):
    def q(v):
        return 'NULL' if v is None else "'" + str(v).replace("'", "''") + "'"
    lignes = ["  (%s, %s, %s, %s)" % (q(r['poste_id']), q(r['label']), q(r['nomme_par']), q(r['scope']))
              for r in regles]
    return ',\n'.join(lignes)


if __name__ == '__main__':
    regles = extraire()
    if '--sql' in sys.argv:
        print(sql(regles))
    elif '--empreinte' in sys.argv:
        print(empreinte(regles))
    else:
        print('postes nommes lus : %d' % len(regles))
        for r in regles:
            print('  %-24s nomme par %-14s scope %s' % (r['poste_id'], r['nomme_par'], r['scope']))
        print('empreinte : %s' % empreinte(regles))
