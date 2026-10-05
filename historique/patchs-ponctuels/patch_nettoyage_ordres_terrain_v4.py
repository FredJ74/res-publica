#!/usr/bin/env python3
PATH = "data.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

# --- 1. Retirer le doublon du lot 1 ---
old_1 = """          {fn:'emprunter_construction', label:'Faire un prêt (Banque Nationale)', pa:0, cost:0, type:'legal', icon:'ti-bank', successRate:100},
          {fn:'diviser_construction', label:'Diviser / gérer les lots', pa:0, cost:0, type:'legal', icon:'ti-grid-dots', successRate:100, desc:'Réservé aux Commerces Premium et Buildings construits.'},
          {fn:'louer_lot_ici', label:'Louer un lot ici', pa:1, cost:0, type:'legal', icon:'ti-key', successRate:100, desc:'Louer un lot disponible, si ce terrain a été divisé par son propriétaire.'},
          {fn:'gerer_lot_loue', label:'Gérer mon local loué', pa:0, cost:0, type:'legal', icon:'ti-home-cog', successRate:100, desc:'Voir/accepter les propositions du propriétaire concernant votre lot loué ici.'},
          {fn:'racheter_terrain', label:'Offre de rachat', pa:2, cost:0, type:'legal', icon:'ti-arrows-exchange', successRate:100}"""
new_1 = """          {fn:'emprunter_construction', label:'Faire un prêt (Banque Nationale)', pa:0, cost:0, type:'legal', icon:'ti-bank', successRate:100},
          {fn:'racheter_terrain', label:'Offre de rachat', pa:2, cost:0, type:'legal', icon:'ti-arrows-exchange', successRate:100}"""
assert content.count(old_1) == 1, f"bloc 1 (doublon lot 1) : trouvé {content.count(old_1)} fois (attendu 1)"
content = content.replace(old_1, new_1)

# --- 2. Prix affiche du compromis : 500 -> 1000, sur les 5 occurrences ---
old_2 = """{fn:'signer_compromis', label:'Signer un compromis', pa:2, cost:500, type:'legal', icon:'ti-file-certificate', successRate:100},"""
new_2 = """{fn:'signer_compromis', label:'Signer un compromis', pa:2, cost:1000, type:'legal', icon:'ti-file-certificate', successRate:100},"""
nb2 = content.count(old_2)
assert nb2 == 5, f"bloc 2 (prix compromis) : trouvé {nb2} fois (attendu 5)"
content = content.replace(old_2, new_2)

# --- 3a. Retirer les ordres redondants, format compact (4 lots : 2, 3, 4, 5) ---
old_3a = """{fn:'deposer_demande_permis', label:'Déposer une demande de permis', pa:2, cost:0, type:'legal', icon:'ti-file-text', successRate:100, desc:'Toujours obtenu a terme -- seule la duree d\\'instruction varie selon le palier choisi.'},{fn:'corrompre_fonctionnaire_permis', label:'Corrompre un fonctionnaire (accélérer)', pa:2, cost:800, type:'illegal', icon:'ti-coins', successRate:100, desc:'Reduit de moitie la duree d\\'instruction restante. Risque de decouverte.'},"""
new_3a = """"""
nb3a = content.count(old_3a)
assert nb3a == 4, f"bloc 3a (format compact) : trouvé {nb3a} fois (attendu 4)"
content = content.replace(old_3a, new_3a)

# --- 3b. Retirer les ordres redondants du lot 1 uniquement (repere unique : donner_argent_pnj) ---
old_3b = """          {fn:'donner_argent_pnj', label:'Donner de l\\'argent', pa:1, cost:0, type:'legal', icon:'ti-coins', successRate:0, desc:'Offrir une somme a un PNJ present. Effet immediat selon sa personnalite.'},
          {fn:'signer_compromis', label:'Signer un compromis', pa:2, cost:1000, type:'legal', icon:'ti-file-certificate', successRate:100},
          {fn:'deposer_demande_permis', label:'Déposer une demande de permis', pa:2, cost:0, type:'legal', icon:'ti-file-text', successRate:100, desc:'Toujours obtenu a terme -- seule la duree d\\'instruction varie selon le palier choisi.'},
          {fn:'corrompre_fonctionnaire_permis', label:'Corrompre un fonctionnaire (accélérer)', pa:2, cost:800, type:'illegal', icon:'ti-coins', successRate:100, desc:'Reduit de moitie la duree d\\'instruction restante. Risque de decouverte.'},
          {fn:'plainte_obstruction_permis',"""
new_3b = """          {fn:'donner_argent_pnj', label:'Donner de l\\'argent', pa:1, cost:0, type:'legal', icon:'ti-coins', successRate:0, desc:'Offrir une somme a un PNJ present. Effet immediat selon sa personnalite.'},
          {fn:'signer_compromis', label:'Signer un compromis', pa:2, cost:1000, type:'legal', icon:'ti-file-certificate', successRate:100},
          {fn:'plainte_obstruction_permis',"""
assert content.count(old_3b) == 1, f"bloc 3b (lot 1 uniquement) : trouvé {content.count(old_3b)} fois (attendu 1)"
content = content.replace(old_3b, new_3b)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print(f"✅ Nettoyage terminé : doublon lot 1 retiré, prix compromis (5x) corrigé à 1000 FR, ordres redondants (5 lots au total) supprimés.")
