#!/usr/bin/env python3
PATH = "plateau.html"
with open(PATH, "r", encoding="utf-8") as f:
    html = f.read()

old = """      <img id="quete-accueil-image" src="" style="width:100%;border-radius:8px;margin-bottom:.6rem;display:none" />"""
new = """      <div id="quete-accueil-guidage" style="position:relative;width:100%;display:none;margin-bottom:.6rem;border-radius:8px;overflow:hidden"></div>
      <img id="quete-accueil-image" src="" style="width:100%;border-radius:8px;margin-bottom:.6rem;display:none" />"""
assert html.count(old) == 1, f"trouvé {html.count(old)} fois (attendu 1)"
html = html.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(html)

print("✅ Conteneur de guidage ajouté à la modale.")
