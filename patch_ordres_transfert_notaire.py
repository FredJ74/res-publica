#!/usr/bin/env python3
PATH = "data.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """{fn:'acte_vente_terrain', label:'Officialiser une vente de terrain', pa:1, cost:300, type:'legal', icon:'ti-home-check', successRate:100, desc:'Le notaire authentifie la transaction. Acte de propriete delivre.'},"""
new = """{fn:'acte_vente_terrain', label:'Officialiser une vente de terrain', pa:1, cost:300, type:'legal', icon:'ti-home-check', successRate:100, desc:'Le notaire authentifie la transaction. Acte de propriete delivre.'},
          {fn:'transferer_compromis', label:'Transférer un compromis', pa:1, cost:0, type:'legal', icon:'ti-transfer', successRate:100, desc:'Céder votre compromis en cours à un autre joueur, qui devra venir valider.'},
          {fn:'valider_transfert_compromis', label:'Valider un compromis reçu', pa:1, cost:0, type:'legal', icon:'ti-checkbox', successRate:100, desc:'Accepter un compromis qu\\'un autre joueur vous a proposé de reprendre.'},"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Ordres de transfert de compromis ajoutés au Bureau des Contrats.")
