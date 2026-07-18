#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Correctif 3 - Hotel Republica, PNJ :
- suppression du "persons" piege dans buildingContext (qui ecrasait l'accueil)
- accueil : Gustave/Beatrice (jamais vus) remplaces par Nathalie Ondor (receptionniste)
  et Isidore Trebien (bagagiste)
- restaurant : ajout de Gaston Sauceblanche (requalifie Sommelier, garde sa vraie photo)
  et Yvette Gratinee (garde sa vraie photo) aux cotes de Paulo (placeholder photo retire)
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
# 1) Suppression du persons piege dans buildingContext
# ------------------------------------------------------------------
old_ctx = """        'hotel-republica': {
          name: "Hôtel-Restaurant La Républia",
          desc: "Le grand hôtel de Luthecia. Gaston Sauceblanche règne sur la salle avec un mépris souverain.",
          persons: [{"name": "Gaston Sauceblanche (PNJ)", "role": "Maître d'hôtel", "rel": "neutral", "job": "serveur", "photoUrl": "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/gaston-sauceblanche.png", "photoPos": "50% 15%"}, {"name": "Yvette Gratinée (PNJ)", "role": "Serveuse", "rel": "neutral", "job": "serveur", "photoUrl": "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/yvette-gratinee.png", "photoPos": "50% 15%"}]
        },"""

new_ctx = """        'hotel-republica': {
          name: "Hôtel-Restaurant La Républia",
          desc: "Le grand hôtel de Luthecia. Gaston Sauceblanche règne sur la salle avec un mépris souverain."
        },"""

ok &= apply_patch('data.js', old_ctx, new_ctx, "data.js - suppression persons piege (buildingContext)")

# ------------------------------------------------------------------
# 2) Accueil : nouveaux PNJ
# ------------------------------------------------------------------
old_accueil_persons = """        persons: [
          {name:'Gustave (Concierge)', role:'PNJ - Gestionnaire', rel:'neutral', job:'concierge'},
          {name:'Beatrice Aumont',     role:'Deputee - Parti Liberal', rel:'neutral', job:null}
        ],"""

new_accueil_persons = """        persons: [
          {name:'Nathalie Ondor (PNJ)', role:'Réceptionniste', rel:'neutral', job:'hotelier'},
          {name:'Isidore Trébien (PNJ)', role:'Bagagiste', rel:'neutral', job:'bagagiste'}
        ],"""

ok &= apply_patch('data.js', old_accueil_persons, new_accueil_persons, "data.js - accueil (Nathalie Ondor + Isidore Trebien)")

# ------------------------------------------------------------------
# 3) Restaurant : ajout Gaston (Sommelier) + Yvette, retrait placeholder Paulo
# ------------------------------------------------------------------
old_resto_persons = """        persons: [
          {name:'Paulo (Maitre d\\'hotel)', role:'PNJ - Service', rel:'neutral', job:'serveur', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/gaston-sauceblanche.png', photoPos:'50% 15%'},
          {name:'Jean Dupont (PNJ)',       role:'Depute - Parti du Centre', rel:'neutral', job:'commercant', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/jean-dupont-marie-leblanc.png', photoPos:'20% 30%'},
          {name:'Marie Leblanc (PNJ)',    role:'Journaliste - La Tribune', rel:'enemy',  job:'journaliste', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/jean-dupont-marie-leblanc.png', photoPos:'70% 30%'}
        ],"""

new_resto_persons = """        persons: [
          {name:'Paulo (Maitre d\\'hotel)', role:'PNJ - Service', rel:'neutral', job:'serveur'},
          {name:'Gaston Sauceblanche (PNJ)', role:'Sommelier', rel:'neutral', job:'serveur', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/gaston-sauceblanche.png', photoPos:'50% 15%'},
          {name:'Yvette Gratinée (PNJ)', role:'Serveuse', rel:'neutral', job:'serveur', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/yvette-gratinee.png', photoPos:'50% 15%'},
          {name:'Jean Dupont (PNJ)',       role:'Depute - Parti du Centre', rel:'neutral', job:'commercant', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/jean-dupont-marie-leblanc.png', photoPos:'20% 30%'},
          {name:'Marie Leblanc (PNJ)',    role:'Journaliste - La Tribune', rel:'enemy',  job:'journaliste', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/jean-dupont-marie-leblanc.png', photoPos:'70% 30%'}
        ],"""

ok &= apply_patch('data.js', old_resto_persons, new_resto_persons, "data.js - restaurant (Gaston sommelier + Yvette, Paulo sans placeholder)")

print()
if ok:
    print("TOUT EST OK.")
else:
    print("ECHEC. Ne rien committer, colle le detail a Claude.")
    sys.exit(1)
