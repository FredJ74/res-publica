#!/usr/bin/env python3
PATH_QA = "plateau-quete-accueil.js"
with open(PATH_QA, "r", encoding="utf-8") as f:
    qa = f.read()

old_check = """  if (state.char.queteAccueil && state.char.queteAccueil.etape) return false;"""
new_check = """  if (!state.char.queteAccueil || state.char.queteAccueil.etape !== 'non_commencee') return false;"""
assert qa.count(old_check) == 1, f"trouvé {qa.count(old_check)} fois (attendu 1)"
qa = qa.replace(old_check, new_check)

with open(PATH_QA, "w", encoding="utf-8") as f:
    f.write(qa)

print("✅ Condition de déclenchement corrigée dans plateau-quete-accueil.js")
