#!/usr/bin/env python3
PATH = "plateau-router.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  if (fn === 'demander_juge_instruction') { doDemanderJugeInstruction(); return; }"""
new = """  if (fn === 'demander_juge_instruction') { doDemanderJugeInstruction(); return; }
  if (fn === 'presenter_autorisation_coffre') { doPresenterAutorisationCoffre(); return; }"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Ordre routé.")
