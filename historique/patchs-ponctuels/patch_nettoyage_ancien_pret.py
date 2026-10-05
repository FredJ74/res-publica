#!/usr/bin/env python3
PATH = "plateau-justice-economie.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old_start = "async function preleverPretsBancaires() {"
old_end = "  } catch(e) { console.warn('preleverPretsBancaires error', e); }\n}"

start_idx = content.find(old_start)
assert start_idx != -1, "fonction introuvable"
end_idx = content.find(old_end, start_idx)
assert end_idx != -1, "fin de fonction introuvable"
end_idx += len(old_end)

old_full = content[start_idx:end_idx]
new_full = "// NOTE : preleverPretsBancaires a ete retiree — le prelevement se fait desormais cote\n// serveur (preleverPretsBancairesServeur, api/cron-minuit.js), a heure fixe, que le joueur\n// dorme ou non. Voir patch du 5 aout 2026."

content = content.replace(old_full, new_full)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Ancienne fonction client retirée (jamais appelée, remplacée par le cron).")
