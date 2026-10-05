with open("plateau-multijoueur.js", encoding="utf-8") as f:
    m = f.read()

old = "    republic: { F: ['Natacha', 'Éléonore', 'Sabine', 'Camille', 'Laure', 'Nina', 'Clara'], H: ['Julien', 'Antoine', 'Maxime', 'Thibault', 'Victor', 'Hugo', 'Nathan'] },"
new = "    republic: { F: ['Natacha', 'Marlène', 'Sabine', 'Camille', 'Laure', 'Nina', 'Clara'], H: ['Julien', 'Antoine', 'Maxime', 'Thibault', 'Victor', 'Hugo', 'Nathan'] },"
assert m.count(old) == 1, m.count(old)
m = m.replace(old, new)

assert m.count("{") == m.count("}")
assert m.count("[") == m.count("]")

with open("plateau-multijoueur.js", "w", encoding="utf-8") as f:
    f.write(m)
print("OK plateau-multijoueur.js")
