#!/usr/bin/env python3
PATH = "supabase.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old_save = """    enigme1:          charState.char?.enigme1 || null,
    updated_at:       new Date().toISOString()"""
new_save = """    enigme1:          charState.char?.enigme1 || null,
    maxence:          charState.char?.maxence || null,
    updated_at:       new Date().toISOString()"""
assert content.count(old_save) == 1, f"save : trouvé {content.count(old_save)} fois (attendu 1)"
content = content.replace(old_save, new_save)

old_load = """queteAccueil: r.quete_accueil || null, enigme1: r.enigme1 || null },"""
new_load = """queteAccueil: r.quete_accueil || null, enigme1: r.enigme1 || null, maxence: r.maxence || null },"""
assert content.count(old_load) == 1, f"load : trouvé {content.count(old_load)} fois (attendu 1)"
content = content.replace(old_load, new_load)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Champ maxence ajouté à la sauvegarde/chargement Supabase.")
