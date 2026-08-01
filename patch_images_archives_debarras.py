#!/usr/bin/env python3
PATH = "data.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old_1 = '''        desc: "L'état-civil, le cadastre et les résumés de mandats des maires successifs. Poussiéreux, mais tout y est.",
        imageUrl: "https://images.unsplash.com/photo-1568667256549-094345857aff?w=1200&q=80",'''
new_1 = '''        desc: "L'état-civil, le cadastre et les résumés de mandats des maires successifs. Poussiéreux, mais tout y est.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-archives-mairie-luthecia.png",'''
assert content.count(old_1) == 1, f"bloc 1 (archives) : trouvé {content.count(old_1)} fois (attendu 1)"
content = content.replace(old_1, new_1)

old_2 = '''        desc: "Une porte fermée à clé, discrète, au fond du musée. Personne ne semble jamais y entrer.",
        imageUrl: "https://images.unsplash.com/photo-1558959357-d7a08d1f7e13?w=1200&q=80",'''
new_2 = '''        desc: "Une porte fermée à clé, discrète, au fond du musée. Personne ne semble jamais y entrer.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/porte-debarras-musee-luthecia.png",'''
assert content.count(old_2) == 1, f"bloc 2 (debarras) : trouvé {content.count(old_2)} fois (attendu 1)"
content = content.replace(old_2, new_2)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Images Salle des Archives et Débarras branchées.")
