#!/usr/bin/env python3
PATH = "plateau-router.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  if (fn === 'consulter_organigramme_supporters') { doConsulterOrganigrammeSupporters(); return; }"""
new = """  if (fn === 'consulter_organigramme_supporters') { doConsulterOrganigrammeSupporters(); return; }
  if (fn === 'consulter_etat_civil') { doConsulterEtatCivil(); return; }"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Ordre 'consulter_etat_civil' routé.")
