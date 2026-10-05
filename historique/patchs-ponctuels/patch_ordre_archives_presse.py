#!/usr/bin/env python3
PATH = "data.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """        orders: [
          {fn:'parler_pnj',    label:'Parler à la standardiste', pa:0, cost:0, type:'legal', icon:'ti-message', successRate:100},
          {fn:'se_renseigner', label:'Se renseigner',            pa:0, cost:0, type:'legal', icon:'ti-info-circle', successRate:100}
        ]"""
new = """        orders: [
          {fn:'parler_pnj',    label:'Parler à la standardiste', pa:0, cost:0, type:'legal', icon:'ti-message', successRate:100},
          {fn:'se_renseigner', label:'Se renseigner',            pa:0, cost:0, type:'legal', icon:'ti-info-circle', successRate:100},
          {fn:'consulter_archives_presse', label:'Consulter les archives de presse', pa:0, cost:0, type:'legal', icon:'ti-news', successRate:100, desc:'Articles archivés publiés par le journal au fil des décennies.'}
        ]"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Ordre 'Consulter les archives de presse' ajouté à L'Autruche Entravée.")
