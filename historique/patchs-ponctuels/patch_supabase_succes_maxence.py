#!/usr/bin/env python3
PATH = "supabase.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old_save = """    maxence:          charState.char?.maxence || null,
    updated_at:       new Date().toISOString()"""
new_save = """    maxence:          charState.char?.maxence || null,
    succes_maxence:   charState.char?.succesMaxence || null,
    updated_at:       new Date().toISOString()"""
assert content.count(old_save) == 1, f"save : trouvé {content.count(old_save)} fois (attendu 1)"
content = content.replace(old_save, new_save)

old_load = """maxence: r.maxence || null },"""
new_load = """maxence: r.maxence || null, succesMaxence: r.succes_maxence || null },"""
assert content.count(old_load) == 1, f"load : trouvé {content.count(old_load)} fois (attendu 1)"
content = content.replace(old_load, new_load)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Champ succesMaxence ajouté à la sauvegarde/chargement Supabase.")
