#!/usr/bin/env python3
PATH = "plateau-router.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  if (fn === 'consulter_etat_civil') { doConsulterEtatCivil(); return; }"""
new = """  if (fn === 'consulter_etat_civil') { doConsulterEtatCivil(); return; }
  if (fn === 'consulter_personnalites_musee') { doConsulterPersonnalitesMusee(); return; }"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Ordre 'consulter_personnalites_musee' routé.")
