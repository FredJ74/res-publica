#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Correctif 2 - Hotel Republica, accueil :
- suppression de "Parler au concierge" (parler_pnj) : redondant, le contact PNJ se fait au clic sur la fiche.
- suppression de "Se renseigner" (se_renseigner) : redondant avec "Louer une suite".
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

old_accueil = """        orders: [
          {fn:'parler_pnj',    label:'Parler au concierge',  pa:0, cost:0,   type:'legal',   icon:'ti-message', successRate:100},
          {fn:'se_renseigner', label:'Se renseigner',        pa:0, cost:0,   type:'legal',   icon:'ti-info-circle', successRate:100},
          {fn:'reserver_chambre_hotel', label:'Reserver une chambre', pa:1, cost:80,  type:'legal',   icon:'ti-key', successRate:100, desc:'Bonus de +2 PA et +3 Moral au prochain Dormir passe dans cette chambre.'},
          {fn:'choisir_suite', label:'Louer une suite', pa:1, cost:0, type:'legal', icon:'ti-crown', successRate:100, desc:'Choisir parmi les suites disponibles de l\\'hotel.'}
        ]
      },
      restaurant: {"""

new_accueil = """        orders: [
          {fn:'reserver_chambre_hotel', label:'Reserver une chambre', pa:1, cost:80,  type:'legal',   icon:'ti-key', successRate:100, desc:'Bonus de +2 PA et +3 Moral au prochain Dormir passe dans cette chambre.'},
          {fn:'choisir_suite', label:'Louer une suite', pa:1, cost:0, type:'legal', icon:'ti-crown', successRate:100, desc:'Choisir parmi les suites disponibles de l\\'hotel.'}
        ]
      },
      restaurant: {"""

ok &= apply_patch('data.js', old_accueil, new_accueil, "data.js - accueil (suppression parler_pnj + se_renseigner)")

print()
if ok:
    print("TOUT EST OK.")
else:
    print("ECHEC. Ne rien committer, colle le detail a Claude a ton retour.")
    sys.exit(1)
