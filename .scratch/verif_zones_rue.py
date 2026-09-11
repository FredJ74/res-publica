#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Controle statique des zones cliquables de plateau-rue-centrale.js.

Extrait les tableaux `zones` des noeuds RUE_CENTRALE_NOEUDS et verifie, pour des points
representatifs, quel batiment (s'il y en a un) s'ouvre au clic. Reproduit exactement la regle de
rendu d'afficherNoeudRue : left = xPct[0] %, width = xPct[1]-xPct[0], et si yPct est absent la zone
couvre toute la hauteur (.rc-zone { top:0; height:100% }).
"""
import json
import re
import sys

SRC = 'plateau-rue-centrale.js'
src = open(SRC, encoding='utf-8').read()


def zones_du_noeud(noeud_id):
    """Retourne la liste des zones (dict) declarees pour ce noeud."""
    i = src.index("'" + noeud_id + "': {")
    j = src.index('zones: [', i)
    # Fin du tableau : premier ']' au meme niveau d'imbrication.
    k, prof = j + len('zones: ['), 1
    while prof:
        if src[k] == '[':
            prof += 1
        elif src[k] == ']':
            prof -= 1
        k += 1
    corps = src[j + len('zones: '):k]
    corps = re.sub(r'//[^\n]*', '', corps)
    corps = re.sub(r'(\w+):', r'"\1":', corps)
    corps = corps.replace("'", '"')
    corps = re.sub(r',\s*([\]}])', r'\1', corps)
    return json.loads(corps)


def clic(zones, x, y):
    """Batiment ouvert par un clic en (x, y) exprimes en % de l'image, ou None."""
    touchees = []
    for z in zones:
        x0, x1 = z['xPct']
        y0, y1 = z.get('yPct', [0, 100])
        if x0 <= x <= x1 and y0 <= y <= y1:
            touchees.append(z.get('buildingId') or z.get('nom'))
    return touchees[-1] if touchees else None


CAS = [
    # (noeud, x%, y%, batiment attendu ou None, libelle)
    ('luthecia-entrepot-logistique', 70, 60, 'entrepot-logistique-luthecia', "centre du hangar"),
    ('luthecia-entrepot-logistique', 65, 55, 'entrepot-logistique-luthecia', "enseigne ENTREPOT LOGISTIQUE"),
    ('luthecia-entrepot-logistique', 55, 72, 'entrepot-logistique-luthecia', "portes/quais 01-02"),
    ('luthecia-entrepot-logistique', 78, 78, 'entrepot-logistique-luthecia', "quai de chargement droit"),
    ('luthecia-entrepot-logistique', 92, 60, 'entrepot-logistique-luthecia', "aile droite du hangar"),
    ('luthecia-entrepot-logistique', 20, 33, None, "facade du Centre Multimodal"),
    ('luthecia-entrepot-logistique', 35, 30, None, "verriere CENTRE MULTIMODAL"),
    ('luthecia-entrepot-logistique', 50, 42, None, "aile droite vitree du multimodal"),
    ('luthecia-entrepot-logistique', 25, 55, None, "quai des bus (gare routiere)"),
    ('luthecia-entrepot-logistique', 35, 62, None, "bus en manoeuvre"),
    ('luthecia-entrepot-logistique', 15, 80, None, "route et voitures"),
    ('luthecia-entrepot-logistique', 60, 93, None, "trottoir / grille en bas de cadre"),
    ('luthecia-entrepot-logistique', 50, 8, None, "ciel"),
    ('luthecia-entrepot-logistique', 98, 20, None, "ville a l'arriere-plan droit"),
    # Non-regression : les noeuds voisins gardent leur comportement.
    ('luthecia-centre-multimodal', 50, 50, 'centre-multinodal-luthecia', "multimodal depuis SON noeud"),
    ('psm-pole-tabac-entrepot', 20, 50, 'pole-tabac-alcools-psm', "PSM : pole tabac"),
    ('psm-pole-tabac-entrepot', 80, 50, 'entrepot-logistique-psm', "PSM : entrepot"),
    ('psm-pole-tabac-entrepot', 50, 50, None, "PSM : bande morte entre les deux"),
]

cache, echecs = {}, 0
for noeud, x, y, attendu, libelle in CAS:
    if noeud not in cache:
        cache[noeud] = zones_du_noeud(noeud)
    obtenu = clic(cache[noeud], x, y)
    ok = obtenu == attendu
    if not ok:
        echecs += 1
    print('%s  %-34s (%3d%%, %3d%%) %-24s -> %s' % (
        'OK  ' if ok else 'ECHEC', libelle, x, y, noeud, obtenu or 'aucun'))

# La zone de l'entrepot ne doit plus couvrir toute l'image.
z = cache['luthecia-entrepot-logistique']
pleine = [q for q in z if q['xPct'] == [0, 100] and q.get('yPct', [0, 100]) == [0, 100]]
if pleine:
    echecs += 1
    print('ECHEC  une zone couvre encore toute l\'image')
else:
    print('OK    aucune zone [0,100]x[0,100] sur le noeud entrepot')

surface = sum((q['xPct'][1] - q['xPct'][0]) * (q.get('yPct', [0, 100])[1] - q.get('yPct', [0, 100])[0])
              for q in z) / 100.0
print('      surface cliquable du noeud entrepot : %.1f %% de l\'image' % surface)
if surface > 60:
    echecs += 1
    print('ECHEC  surface cliquable trop large')

print('\n%d cas, %d echec(s)' % (len(CAS) + 1, echecs))
sys.exit(1 if echecs else 0)
