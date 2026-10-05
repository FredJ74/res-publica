#!/usr/bin/env python3
PATH = "plateau-politique.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """        else needsPost = posteId !== reqPost;"""
new = """        else if (reqPost === 'maire') needsPost = !posteId.startsWith('maire'); // maire_capitale/maire_a/maire_b — jamais litteralement 'maire'. Bug remonte le 5 aout 2026.
        else needsPost = posteId !== reqPost;"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Fix critique : requiresPost:'maire' reconnaît maintenant maire_capitale/maire_a/maire_b (auparavant, aucun maire ne pouvait utiliser ses propres ordres).")
