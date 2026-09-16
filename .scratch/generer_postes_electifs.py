#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GENERATEUR DU MIROIR DES POSTES ELECTIFS (chantier « candidature depuis le calendrier »,
16 septembre 2026).

Le serveur doit pouvoir refuser lui-meme une candidature inegible -- influence insuffisante,
poste inconnu -- sans croire le navigateur. Or ces regles n'existaient qu'en memoire du client
(POSTES_ELECTIFS, data.js). On ne recopie aucun chiffre a la main : le VRAI data.js est charge
dans JavaScriptCore et les postes sont captures tels que le jeu les lit.

Sorties :
  python3 .scratch/generer_postes_electifs.py            -> resume
  python3 .scratch/generer_postes_electifs.py --sql      -> les VALUES
  python3 .scratch/generer_postes_electifs.py --empreinte

REJOUER apres toute modification de POSTES_ELECTIFS (minInf, ajout ou retrait d'un poste).
"""
import hashlib, json, os, subprocess, sys, tempfile

JSC = "/System/Library/Frameworks/JavaScriptCore.framework/Versions/Current/Helpers/jsc"
RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


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
['national', 'departemental', 'local'].forEach(function (scope) {
  (POSTES_ELECTIFS[scope] || []).forEach(function (p) {
    out.push({ id: p.id, nom: p.name, scope: scope, niveau: p.niveau,
               min_inf: p.minInf || 0, nb_par_ville: p.nbParVille || null });
  });
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
        print('ECHEC DU CHARGEMENT :', (p.stdout + p.stderr)[-600:]); sys.exit(2)
    return json.loads(p.stdout.strip().splitlines()[-1])


def empreinte(postes):
    return hashlib.md5('\n'.join('%s|%s|%s|%s' % (p['id'], p['scope'], p['niveau'], p['min_inf'])
                                 for p in postes).encode()).hexdigest()[:16]


if __name__ == '__main__':
    postes = collecter()
    if '--sql' in sys.argv:
        print(',\n'.join("  ('%s', '%s', '%s', '%s', %d, %s)"
                         % (p['id'], p['nom'].replace("'", "''"), p['scope'], p['niveau'],
                            p['min_inf'], p['nb_par_ville'] if p['nb_par_ville'] else 'NULL')
                         for p in postes))
    elif '--empreinte' in sys.argv:
        print(empreinte(postes))
    else:
        for p in postes:
            print('  %-14s %-16s %-14s niveau=%-8s INF>=%d' % (p['id'], p['nom'], p['scope'],
                                                               p['niveau'], p['min_inf']))
        print('empreinte : %s' % empreinte(postes))
