#!/usr/bin/env python3
PATH = "plateau.html"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """      <div id="quete-accueil-guidage" style="position:relative;width:100%;display:none;margin-bottom:.6rem;border-radius:8px;overflow:hidden"></div>
      <div id="quete-accueil-guidage" style="position:relative;width:100%;display:none;margin-bottom:.6rem;border-radius:8px;overflow:hidden"></div>"""
new = """      <div id="quete-accueil-guidage" style="position:relative;width:100%;display:none;margin-bottom:.6rem;border-radius:8px;overflow:hidden"></div>"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Doublon HTML retiré.")
