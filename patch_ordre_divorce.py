#!/usr/bin/env python3
PATH = "data.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """        orders: [
          {fn:'acte_vente_terrain', label:'Officialiser une vente de terrain', pa:1, cost:300, type:'legal', icon:'ti-home-check', successRate:100, desc:'Le notaire authentifie la transaction. Acte de propriete delivre.'},
          {fn:'contrat_mariage', label:'Negocier un contrat de mariage', pa:2, cost:400, type:'legal', icon:'ti-heart-handshake', successRate:100, desc:'Choisir le regime matrimonial (communaute, separation de biens) plutot que la copropriete par defaut.'}
        ]"""
new = """        orders: [
          {fn:'acte_vente_terrain', label:'Officialiser une vente de terrain', pa:1, cost:300, type:'legal', icon:'ti-home-check', successRate:100, desc:'Le notaire authentifie la transaction. Acte de propriete delivre.'},
          {fn:'contrat_mariage', label:'Negocier un contrat de mariage', pa:2, cost:400, type:'legal', icon:'ti-heart-handshake', successRate:100, desc:'Choisir le regime matrimonial (communaute, separation de biens) plutot que la copropriete par defaut.'},
          {fn:'demander_divorce', label:'Demander le divorce', pa:1, cost:200, type:'legal', icon:'ti-heart-broken', successRate:100, desc:'Dissout votre mariage actuel. Votre conjoint en sera informé par mail.'}
        ]"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Ordre 'Demander le divorce' ajouté au Bureau des Contrats.")
