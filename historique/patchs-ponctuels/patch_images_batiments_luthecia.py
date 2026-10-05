#!/usr/bin/env python3
PATH = "data.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

remplacements = [
    ("https://raw.githubusercontent.com/FredJ74/res-publica/main/images/entrepot-logistique-luthecia.png\",\n        desc: \"Le quai de chargement et la salle des ventes.",
     "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-ventes-entrepot-luthecia.png\",\n        desc: \"Le quai de chargement et la salle des ventes."),
    ("https://images.unsplash.com/photo-1497366216548-37526070297c?w=1200&q=80\",\n        desc: \"Le bureau du directeur de l'entrepôt.",
     "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/bureau-direction-entrepot-luthecia.png\",\n        desc: \"Le bureau du directeur de l'entrepôt."),
    ("https://raw.githubusercontent.com/FredJ74/res-publica/main/images/usine-pharmaceutique-luthecia.png\",\n        desc: \"L'accueil et la salle de vente directe des médicaments",
     "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-ventes-usine-pharma-luthecia.png\",\n        desc: \"L'accueil et la salle de vente directe des médicaments"),
    ("https://images.unsplash.com/photo-1497366216548-37526070297c?w=1200&q=80\",\n        desc: \"Le bureau du directeur de l'usine.",
     "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/bureau-direction-usine-pharma-luthecia.png\",\n        desc: \"Le bureau du directeur de l'usine."),
    ("https://images.unsplash.com/photo-1581093458791-9d42e3c9f2c1?w=1200&q=80\",\n        desc: \"Les lignes de production. Les plantes livrées",
     "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-production-usine-pharma-luthecia.png\",\n        desc: \"Les lignes de production. Les plantes livrées"),
]

for old, new in remplacements:
    nb = content.count(old)
    assert nb == 1, f"trouvé {nb} fois (attendu 1) pour : {old[:80]}..."
    content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Les 5 images intégrées dans l'Entrepôt Logistique et l'Usine Pharmaceutique de Luthécia.")
