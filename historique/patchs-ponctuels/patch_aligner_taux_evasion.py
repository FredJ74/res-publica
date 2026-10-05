#!/usr/bin/env python3
PATH = "data.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old_1 = """          {fn:'tentative_evasion',label:'Tenter de s\\'evader',               pa:3, cost:0,    type:'illegal', icon:'ti-run',        successRate:15,  desc:'Tres risque. Succes : liberte. Echec : transferement en prison.'}"""
new_1 = """          {fn:'tentative_evasion',label:'Tenter de s\\'evader',               pa:3, cost:0,    type:'illegal', icon:'ti-run',        successRate:10,  desc:'Tres risque, une tentative par jour. Succes : liberte. Echec : transferement en prison.'}"""
assert content.count(old_1) == 1, f"bloc 1 : trouvé {content.count(old_1)} fois (attendu 1)"
content = content.replace(old_1, new_1)

old_2 = """          {fn:'tentative_evasion',  label:'Tenter de s\\'evader',        pa:3, cost:0,    type:'illegal', icon:'ti-run',      successRate:5,   desc:'Quasi impossible. Echec = peine aggravee de 7 jours.'}"""
new_2 = """          {fn:'tentative_evasion',  label:'Tenter de s\\'evader',        pa:3, cost:0,    type:'illegal', icon:'ti-run',      successRate:10,   desc:'Quasi impossible, une tentative par jour. Echec = peine aggravee de 7 jours.'}"""
assert content.count(old_2) == 1, f"bloc 2 : trouvé {content.count(old_2)} fois (attendu 1)"
content = content.replace(old_2, new_2)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Taux affichés alignés sur 10% (cohérent avec le nouveau calcul), mention de la limite quotidienne ajoutée.")
