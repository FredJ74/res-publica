#!/usr/bin/env python3
PATH = "data.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old_1 = """        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/entrepot-logistique-luthecia.png",
        desc: "Le quai de chargement et la salle des ventes."""
new_1 = """        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-ventes-entrepot-luthecia.png",
        desc: "Le quai de chargement et la salle des ventes."""
assert content.count(old_1) == 1, f"1 : trouvé {content.count(old_1)}"
content = content.replace(old_1, new_1)

old_2 = """        imageUrl: "https://images.unsplash.com/photo-1497366216548-37526070297c?w=1200&q=80",
        desc: "Le bureau du directeur de l'entrepôt."""
new_2 = """        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/bureau-direction-entrepot-luthecia.png",
        desc: "Le bureau du directeur de l'entrepôt."""
assert content.count(old_2) == 1, f"2 : trouvé {content.count(old_2)}"
content = content.replace(old_2, new_2)

old_3 = """        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/usine-pharmaceutique-luthecia.png",
        desc: "L'accueil et la salle de vente directe des médicaments"""
new_3 = """        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-ventes-usine-pharma-luthecia.png",
        desc: "L'accueil et la salle de vente directe des médicaments"""
assert content.count(old_3) == 1, f"3 : trouvé {content.count(old_3)}"
content = content.replace(old_3, new_3)

old_4 = """        imageUrl: "https://images.unsplash.com/photo-1497366216548-37526070297c?w=1200&q=80",
        desc: "Le bureau du directeur de l'usine."""
new_4 = """        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/bureau-direction-usine-pharma-luthecia.png",
        desc: "Le bureau du directeur de l'usine."""
assert content.count(old_4) == 1, f"4 : trouvé {content.count(old_4)}"
content = content.replace(old_4, new_4)

old_5 = """        imageUrl: "https://images.unsplash.com/photo-1581093458791-9d42e3c9f2c1?w=1200&q=80",
        desc: "Les lignes de production. Les plantes livrées"""
new_5 = """        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-production-usine-pharma-luthecia.png",
        desc: "Les lignes de production. Les plantes livrées"""
assert content.count(old_5) == 1, f"5 : trouvé {content.count(old_5)}"
content = content.replace(old_5, new_5)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Les 5 images intégrées dans l'Entrepôt Logistique et l'Usine Pharmaceutique de Luthécia.")
