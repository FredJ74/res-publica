#!/usr/bin/env python3
PATH = "plateau.html"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """      <div class="pnj-speech" id="quete-accueil-texte"></div>
    </div>
  </div>
</div>

<!-- MODAL FICHE PERSONNAGE -->"""
new = """      <div class="pnj-speech" id="quete-accueil-texte"></div>
      <div id="quete-accueil-actions" style="margin-top:.6rem"></div>
    </div>
  </div>
</div>

<!-- MODAL FICHE PERSONNAGE -->"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Conteneur d'actions ajouté à la modale de quête.")
