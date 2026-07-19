#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Correctif "Se nourrir" au restaurant de l'Hotel Republica :
- nouveau fn dedie 'repas_gastronomique' (ne touche pas aux 6 autres usages
  generiques de fn:'se_nourrir' ailleurs dans le jeu)
- 120 FR, +10 Sante et +1 Moral immediats
- +1 PA differe : applique automatiquement au prochain ordre Dormir (peu
  importe ou il a lieu), via state.bonusPaProchainDormir
"""
import sys

def apply_patch(path, old, new, label):
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    count = content.count(old)
    if count == 0:
        print(f"[ECHEC] {label} : ancre introuvable dans {path}")
        return False
    if count > 1:
        print(f"[ECHEC] {label} : ancre trouvee {count} fois dans {path} (doit etre unique)")
        return False
    content = content.replace(old, new, 1)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"[OK] {label}")
    return True

ok = True

# ------------------------------------------------------------------
# 1) data.js -- nouvel ordre au restaurant
# ------------------------------------------------------------------
old_data = """{fn:'se_nourrir',   label:'Se nourrir',          pa:0, cost:25,  type:'legal',  icon:'ti-soup',     successRate:100, desc:'Repas standard. Sante maintenue.'},"""
new_data = """{fn:'repas_gastronomique', label:'Se nourrir', pa:0, cost:120, type:'legal', icon:'ti-soup', successRate:100, desc:'Repas gastronomique. +10 Sante, +1 Moral immediats. +1 PA au prochain Dormir.'},"""
ok &= apply_patch('data.js', old_data, new_data, "data.js - restaurant : repas gastronomique (120 FR)")

# ------------------------------------------------------------------
# 2) data.js -- nouvelle entree ORDER_EFFECTS
# ------------------------------------------------------------------
old_effects = """  se_nourrir:         {hp:5,   moral:1,  successRate:100},"""
new_effects = """  se_nourrir:         {hp:5,   moral:1,  successRate:100},
  repas_gastronomique: {hp:10,  moral:1,  successRate:100},"""
ok &= apply_patch('data.js', old_effects, new_effects, "data.js - ORDER_EFFECTS repas_gastronomique")

# ------------------------------------------------------------------
# 3) plateau-router.js -- differer le PA (meme bloc special que 'dormir'/'organiser_blocus')
# ------------------------------------------------------------------
old_router = """  if (fn === 'acheter_terrain') addToInventory({name:'Terrain (terrain en jeu)', icon:'ti-fence', type:'bien'});"""
new_router = """  if (fn === 'acheter_terrain') addToInventory({name:'Terrain (terrain en jeu)', icon:'ti-fence', type:'bien'});
  if (fn === 'repas_gastronomique' && resultType !== 'fail' && resultType !== 'crit-fail') {
    state.bonusPaProchainDormir = (state.bonusPaProchainDormir || 0) + 1;
  }"""
ok &= apply_patch('plateau-router.js', old_router, new_router, "plateau-router.js - differe +1 PA au prochain Dormir")

# ------------------------------------------------------------------
# 4) plateau-personnage.js -- consommer le bonus differe dans doDormir()
# ------------------------------------------------------------------
old_dormir = """  state.pa = plafondPA;
  state.paMax = plafondPA;"""
new_dormir = """  state.pa = plafondPA;
  state.paMax = plafondPA;
  if (state.bonusPaProchainDormir) {
    state.pa += state.bonusPaProchainDormir;
    addJournalEntry('Bonus de repas applique : +' + state.bonusPaProchainDormir + ' PA.', 'event-good');
    state.bonusPaProchainDormir = 0;
  }"""
ok &= apply_patch('plateau-personnage.js', old_dormir, new_dormir, "plateau-personnage.js - consomme bonusPaProchainDormir dans doDormir")

print()
if ok:
    print("TOUT EST OK.")
else:
    print("ECHEC. Ne rien committer, colle le detail a Claude.")
    sys.exit(1)
