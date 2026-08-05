#!/usr/bin/env python3
PATH = "api/cron-minuit.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """    // 9. Mensualites des prets bancaires (a heure fixe, que le joueur dorme ou non)
    const prets = await preleverPretsBancairesServeur();

    return res.status(200).json({ ok: true, traites: results.length, details: results, mailsSupprimes: mailsSuppres, fuites, taxeFonciere, loyersLots, compromisResolus, achatsDirectsManques, chantiers, prets });"""
new = """    // 9. Mensualites des prets bancaires (a heure fixe, que le joueur dorme ou non)
    const prets = await preleverPretsBancairesServeur();

    // 10. Expiration des blocus syndicaux non renouveles
    const blocusExpires = await nettoyerBlocusExpires();

    return res.status(200).json({ ok: true, traites: results.length, details: results, mailsSupprimes: mailsSuppres, fuites, taxeFonciere, loyersLots, compromisResolus, achatsDirectsManques, chantiers, prets, blocusExpires });"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Appel de nettoyerBlocusExpires() branché dans le cron principal.")
