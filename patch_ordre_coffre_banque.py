#!/usr/bin/env python3
PATH = "data.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """        orders: [
          {fn:'gerer_finances', label:'Gerer mon compte',    pa:0, cost:0,    type:'legal', icon:'ti-chart-bar',   successRate:100, desc:'Deposer ou retirer de l\\'argent. Voir son solde.'},
          {fn:'investir',       label:'Investir',            pa:2, cost:500,  type:'legal', icon:'ti-trending-up', successRate:75,  desc:'Placer des fonds. Rendement dans 24h.'},
          {fn:'emprunter',      label:'Emprunter',           pa:1, cost:0,    type:'legal', icon:'ti-credit-card', successRate:70,  desc:'Contracter un pret. Taux selon dossier.'},
          {fn:'fiscal',         label:'Optimisation fiscale',pa:1, cost:200,  type:'grey',  icon:'ti-calculator',  successRate:85,  desc:'Reduire sa fiscalite. Semi-legal.'}
        ]"""
new = """        orders: [
          {fn:'gerer_finances', label:'Gerer mon compte',    pa:0, cost:0,    type:'legal', icon:'ti-chart-bar',   successRate:100, desc:'Deposer ou retirer de l\\'argent. Voir son solde.'},
          {fn:'investir',       label:'Investir',            pa:2, cost:500,  type:'legal', icon:'ti-trending-up', successRate:75,  desc:'Placer des fonds. Rendement dans 24h.'},
          {fn:'emprunter',      label:'Emprunter',           pa:1, cost:0,    type:'legal', icon:'ti-credit-card', successRate:70,  desc:'Contracter un pret. Taux selon dossier.'},
          {fn:'fiscal',         label:'Optimisation fiscale',pa:1, cost:200,  type:'grey',  icon:'ti-calculator',  successRate:85,  desc:'Reduire sa fiscalite. Semi-legal.'},
          {fn:'presenter_autorisation_coffre', label:'Présenter une autorisation judiciaire', pa:1, cost:0, type:'legal', icon:'ti-key', successRate:100, desc:'Accéder à un coffre grâce à une autorisation du juge.'}
        ]"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Ordre 'Présenter une autorisation judiciaire' ajouté à l'Accueil de la Banque Nationale.")
