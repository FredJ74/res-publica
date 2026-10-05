#!/usr/bin/env python3
PATH = "plateau-politique.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """    data = {
      key,
      allocation: { commissariat: 20, multimodal: 15, stade: 15, marche: 15, dispensaire: 20, tribunal: 15 },
      caisse: 0,
      derniereDistribJour: state.day || 1
    };"""
new = """    data = {
      key,
      allocation: { commissariat: 20, multimodal: 15, stade: 15, marche: 15, dispensaire: 20, tribunal: 15 },
      caisse: 0,
      // Taxe fonciere : FR/m2/jour, prerogative du maire (min/max a definir dans le futur
      // tableau de bord municipal, pour eviter qu'un taux abusif ruine les proprietaires).
      tauxFoncier: 0.05,
      derniereDistribJour: state.day || 1
    };"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Taux foncier par défaut (0.05 FR/m²/jour) ajouté au budget municipal.")
