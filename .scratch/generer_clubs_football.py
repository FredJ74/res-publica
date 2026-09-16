#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GENERATEUR DU MIROIR SERVEUR DES CLUBS (chantier « phases finales », 16 septembre 2026).

Le serveur doit pouvoir ECRIRE lui-meme les communiques officiels de la Ligue -- « X est sacre
champion », « finale au stade de Y ». Or les noms des clubs n'existaient qu'en memoire du
navigateur (CLUBS_SPORTIFS, data.js) : les accepter du client reviendrait a lui laisser signer le
communique, ce que ce chantier ferme precisement.

On ne recopie donc aucun nom a la main -- le depot en contient deja deux copies manuelles
(api/cron-minuit.js, api/_journal-collecte.js), et c'est exactement ce qu'on evite ici. Le VRAI
data.js est charge dans JavaScriptCore et les clubs sont captures tels que le jeu les lit.

Sorties :
  python3 .scratch/generer_clubs_football.py            -> resume
  python3 .scratch/generer_clubs_football.py --sql      -> les VALUES
  python3 .scratch/generer_clubs_football.py --empreinte

REJOUER apres toute modification de CLUBS_SPORTIFS (nom, ajout ou retrait d'un club).
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
CLUBS_SPORTIFS.forEach(function (c) {
  out.push({ id: c.id, nom: c.nom, pays: c.country, ville: c.city });
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
    return json.loads(p.stdout.strip().splitlines()[-1])


def echapper(t):
    return t.replace("'", "''")


def empreinte(clubs):
    return hashlib.md5('\n'.join('%s|%s|%s|%s' % (c['id'], c['nom'], c['pays'], c['ville'])
                                 for c in clubs).encode()).hexdigest()[:16]


if __name__ == '__main__':
    clubs = collecter()
    if '--sql' in sys.argv:
        print(',\n'.join("  ('%s', '%s', '%s', '%s')"
                         % (echapper(c['id']), echapper(c['nom']),
                            echapper(c['pays']), echapper(c['ville'])) for c in clubs))
    elif '--empreinte' in sys.argv:
        print(empreinte(clubs))
    else:
        print('clubs : %d' % len(clubs))
        for c in clubs:
            print('  %-24s %-36s %s/%s' % (c['id'], c['nom'], c['pays'], c['ville']))
        print('empreinte : %s' % empreinte(clubs))
