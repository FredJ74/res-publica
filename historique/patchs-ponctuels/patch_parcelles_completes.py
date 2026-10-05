#!/usr/bin/env python3
PATH = "plateau-enigme-portrait.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """const ENIGME1_REGISTRE_PARCELLES = [
  {
    parcelle: 'B-127',
    historique: [
      "Jusqu'en 1947 : propriété de Pierre Thibault (terrain agricole, 2ha10).",
      "1947 : expropriée par la Mairie de Luthécia (voir résumé du mandat de Marcel Torcieu).",
      "1948 : revendue à l'entrepreneur Jacques Moulin, reclassée terrain à bâtir en zone industrielle."
    ]
  }
];"""

new = """const ENIGME1_REGISTRE_PARCELLES = [
  {
    parcelle: 'B-127',
    historique: [
      "Jusqu'en 1947 : propriété de Pierre Thibault (terrain agricole, 2ha10).",
      "1947 : expropriée par la Mairie de Luthécia (voir résumé du mandat de Marcel Torcieu).",
      "1948 : revendue à l'entrepreneur Jacques Moulin, reclassée terrain à bâtir en zone industrielle.",
      "Suite à l'arrêt de l'usine, la parcelle a été rachetée pour l'aménagement du Centre Multimodal (aéroport)."
    ]
  },
  {
    parcelle: 'A-095',
    historique: [
      "1943 : permis de construire accordé par la Mairie de Luthécia pour le Tabernacle des Impôts (voir résumé du mandat de Marcel Torcieu)."
    ]
  },
  {
    parcelle: 'B-231',
    historique: [
      "Ancienne parcelle communale de type bois, d'une surface de 1ha78.",
      "Vendue par la Mairie de Luthécia pour la somme de 39 580 FR (voir résumé du mandat de Marcel Torcieu)."
    ]
  }
];"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Parcelles B-127 (devenir actuel), A-095 et B-231 ajoutées aux archives notariales.")
