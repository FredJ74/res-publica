import re, glob

total = 0
non_proteges = []
for path in glob.glob("*.js"):
    with open(path, encoding="utf-8") as f:
        content = f.read()
    for m in re.finditer(r"localStorage\.setItem\('respublica_char", content):
        total += 1
        before = content[:m.start()]
        # cherche le dernier "try {" ou "}" avant cette occurrence
        last_try = before.rfind("try {")
        last_close = before.rfind("\n  }\n")  # fermeture de bloc grossiere
        protege = last_try != -1 and last_try > before.rfind("catch")
        if not protege or (last_close != -1 and last_close > last_try):
            non_proteges.append((path, content[:m.start()].count("\n")+1))

print(f"Total occurrences : {total}")
if non_proteges:
    print("Potentiellement non protégées :")
    for p, line in non_proteges:
        print(f"  {p}:{line}")
else:
    print("Toutes semblent protégées (dernier 'try {' trouvé avant chaque occurrence).")
