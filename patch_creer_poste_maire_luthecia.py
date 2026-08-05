#!/usr/bin/env python3
PATH = "data.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """    ville_a: [
      {id:'maire_a',    name:'Maire de Port-Sainte-Marie', niveau:3, unique:true, holder:'PNJ-Maire-A'},
      {id:'adj_maire_a',name:'Maire Adjoint',              niveau:2, unique:true, holder:'PNJ-Adj-A'}
    ],"""
new = """    ville_capitale: [
      {id:'maire_capitale',    name:'Maire de Luthécia', niveau:3, unique:true, holder:'PNJ-Maire-Luthecia'},
      {id:'adj_maire_capitale',name:'Maire Adjoint',      niveau:2, unique:true, holder:'PNJ-Adj-Luthecia'}
    ],
    ville_a: [
      {id:'maire_a',    name:'Maire de Port-Sainte-Marie', niveau:3, unique:true, holder:'PNJ-Maire-A'},
      {id:'adj_maire_a',name:'Maire Adjoint',              niveau:2, unique:true, holder:'PNJ-Adj-A'}
    ],"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Poste de Maire de Luthécia (+ Adjoint) créé dans POSTES.")
