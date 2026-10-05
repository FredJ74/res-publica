#!/usr/bin/env python3
PATH = "api/cron-minuit.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """async function nettoyerBlocusExpires() {"""
new = """// Effet quotidien d'un blocus actif : malus sur la popularite du maire de la ville
// concernee, proportionnel a l'intensite du blocus. NOTE : le malus prevu sur les indices
// de ville n'est pas encore possible — INDICES_VILLES (cote client, plateau-divers.js) n'a
// aucune persistance serveur ; c'est le futur chantier dedie deja identifie le 4 aout 2026.
async function appliquerEffetsBlocusActifs() {
  const resultats = { appliques: 0 };
  try {
    const batiments = await sbGet('batiments_etat', '');
    if (!batiments) return resultats;

    for (const row of batiments) {
      let etat;
      try { etat = JSON.parse(row.data); } catch(e) { continue; }
      if (!etat.blocus) continue;

      const malusPop = Math.max(1, Math.round((etat.blocus.intensite || 40) / 15));
      const maireRows = await sbGet('personnages', `country=eq.${encodeURIComponent(row.country)}&poste->>id=like.maire*`);
      const maire = maireRows && maireRows[0];
      if (maire) {
        await sbUpdate('personnages', `name=eq.${encodeURIComponent(maire.name)}`, { pop: Math.max(0, (maire.pop || 50) - malusPop) }).catch(() => {});
        resultats.appliques++;
      }
    }
  } catch(e) { console.error('appliquerEffetsBlocusActifs error', e); }
  return resultats;
}

async function nettoyerBlocusExpires() {"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

old_2 = """    // 10. Expiration des blocus syndicaux non renouveles
    const blocusExpires = await nettoyerBlocusExpires();

    return res.status(200).json({ ok: true, traites: results.length, details: results, mailsSupprimes: mailsSuppres, fuites, taxeFonciere, loyersLots, compromisResolus, achatsDirectsManques, chantiers, prets, blocusExpires });"""
new_2 = """    // 10. Expiration des blocus syndicaux non renouveles
    const blocusExpires = await nettoyerBlocusExpires();

    // 11. Effets quotidiens des blocus actifs (malus popularite du maire)
    const effetsBlocus = await appliquerEffetsBlocusActifs();

    return res.status(200).json({ ok: true, traites: results.length, details: results, mailsSupprimes: mailsSuppres, fuites, taxeFonciere, loyersLots, compromisResolus, achatsDirectsManques, chantiers, prets, blocusExpires, effetsBlocus });"""
assert content.count(old_2) == 1, f"trouvé {content.count(old_2)} fois (attendu 1)"
content = content.replace(old_2, new_2)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Malus quotidien sur la popularité du maire créé (indices de ville en attente du futur chantier de persistance).")
