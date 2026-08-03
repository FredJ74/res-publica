#!/usr/bin/env python3
PATH = "plateau-pnj.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  if (typeof enigme1EtapeActive === 'function' && enigme1EtapeActive()) {
    if (nomCourtEhpad === 'Jeanine Dubois') {"""
new = """  if (typeof enigme1EtapeActive === 'function' && enigme1EtapeActive()) {
    if (nomCourtEhpad === 'Jeanine Dubois' && /thibault|élise|elise/i.test(action)) {"""
assert content.count(old) == 1, f"bloc jeanine : trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

old_2 = """    if (nomCourtEhpad === 'Louis Chevillard') {"""
new_2 = """    if (nomCourtEhpad === 'Louis Chevillard' && /caillon/i.test(action)) {"""
assert content.count(old_2) == 1, f"bloc louis : trouvé {content.count(old_2)} fois (attendu 1)"
content = content.replace(old_2, new_2)

old_3 = """    if (nomCourtEhpad === 'Noël Chauchay') {"""
new_3 = """    if (nomCourtEhpad === 'Noël Chauchay' && /thibault/i.test(action)) {"""
assert content.count(old_3) == 1, f"bloc noel : trouvé {content.count(old_3)} fois (attendu 1)"
content = content.replace(old_3, new_3)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Mots-clés ajoutés : les 3 pensionnaires ne répondent qu'à des questions ciblées.")
