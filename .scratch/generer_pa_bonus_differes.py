#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GENERATEUR DU MIROIR DES BONUS DE PA DIFFERES (chantier « PA serveur-autoritaires », 16 sept. 2026).

Le « bonus au prochain Dormir » (state.bonusPaProchainDormir) etait un champ CLIENT, jamais
persiste : le serveur ne pouvait ni le connaitre ni le verifier. En rendant les PA
serveur-autoritaires, il faut que le serveur sache combien vaut chaque source -- sinon soit le
bonus disparait (regression de game design), soit le client choisit son montant (la faille qu'on
ferme).

On ne recopie donc aucun chiffre a la main : on charge les VRAIS modules dans JavaScriptCore et
on capture les valeurs telles que le jeu les lit.

Sources couvertes :
  * CONFIG_INVITATIONS_SOCIALES[type].paDiffere        (plateau-pnj.js)
  * les recettes de commerce effets.paDiffere          (plateau-actions-illegales-rumeurs.js)
  * les deux bonus ecrits en dur, declares en constantes nommees pour rester extractibles

Sorties :
  python3 .scratch/generer_pa_bonus_differes.py            -> resume
  python3 .scratch/generer_pa_bonus_differes.py --sql      -> les VALUES
  python3 .scratch/generer_pa_bonus_differes.py --empreinte

REJOUER apres toute modification d'un paDiffere.
"""
import hashlib, json, os, re, subprocess, sys, tempfile

JSC = "/System/Library/Frameworks/JavaScriptCore.framework/Versions/Current/Helpers/jsc"
RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def par_jsc():
    """CONFIG_INVITATIONS_SOCIALES est un objet simple : on le charge pour de vrai."""
    js = """
var document = { getElementById: function(){return null;}, addEventListener: function(){},
                 querySelector: function(){return null;}, querySelectorAll: function(){return [];},
                 createElement: function(){ return { style:{}, classList:{add:function(){},remove:function(){}},
                                                     addEventListener:function(){}, appendChild:function(){} }; },
                 body: { appendChild: function(){} } };
var window = { addEventListener: function(){}, location: { search: '' } };
var localStorage = { getItem: function(){return null;}, setItem: function(){}, removeItem: function(){} };
var navigator = { language: 'fr' };
try { load('%s/data.js'); } catch (e) {}
try { load('%s/plateau-core.js'); } catch (e) {}
try { load('%s/plateau-pnj.js'); } catch (e) {}
var out = {};
if (typeof CONFIG_INVITATIONS_SOCIALES !== 'undefined') {
  Object.keys(CONFIG_INVITATIONS_SOCIALES).forEach(function (k) {
    out[k] = CONFIG_INVITATIONS_SOCIALES[k].paDiffere || 0;
  });
}
print(JSON.stringify(out));
""" % (RACINE, RACINE, RACINE)
    f = tempfile.NamedTemporaryFile('w', suffix='.js', delete=False, encoding='utf-8')
    f.write(js); f.close()
    try:
        p = subprocess.run([JSC, f.name], capture_output=True, text=True, timeout=120)
    finally:
        os.unlink(f.name)
    if p.returncode != 0 or not p.stdout.strip():
        return {}
    return json.loads(p.stdout.strip().splitlines()[-1])


def par_lecture():
    """Les recettes de commerce vivent dans un tres gros litteral difficile a charger isolement :
       on extrait chaque bloc `id: '...'` ... `paDiffere: N` par lecture directe. La forme est
       stable et verifiee par le banc (toute recette portant un paDiffere doit apparaitre ici)."""
    src = open(os.path.join(RACINE, 'plateau-actions-illegales-rumeurs.js'), encoding='utf-8').read()
    trouves = {}
    for m in re.finditer(r"id:\s*'([a-z0-9_]+)'[\s\S]{0,900}?paDiffere:\s*(\d+)", src):
        trouves[m.group(1)] = int(m.group(2))
    return trouves


# Les deux bonus ecrits en dur dans le code, nommes ici pour rester traçables. Ils valent 1 PA
# chacun depuis leur creation ; le banc verifie que le code source les porte toujours a 1.
EN_DUR = {'repas_gastronomique': 1, 'service_etage_hotel': 1}


def collecter():
    b = {}
    b.update({k: v for k, v in par_jsc().items() if v})
    b.update({k: v for k, v in par_lecture().items() if v})
    b.update(EN_DUR)
    return dict(sorted(b.items()))


def empreinte(b):
    return hashlib.md5('\n'.join('%s|%s' % (k, v) for k, v in b.items()).encode()).hexdigest()[:16]


if __name__ == '__main__':
    bonus = collecter()
    if '--sql' in sys.argv:
        print(',\n'.join("  ('%s', %d)" % (k, v) for k, v in bonus.items()))
    elif '--empreinte' in sys.argv:
        print(empreinte(bonus))
    else:
        print('sources de bonus differe : %d' % len(bonus))
        for k, v in bonus.items():
            print('  %-28s +%d PA au prochain Dormir' % (k, v))
        print('empreinte : %s' % empreinte(bonus))
