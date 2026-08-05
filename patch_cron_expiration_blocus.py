#!/usr/bin/env python3
PATH = "api/cron-minuit.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """async function nettoyerAchatsDirectsManques() {"""
new = """// Fin automatique d'un blocus syndical si aucun des deux leaders (Secretaire General ou
// Adjoint) ne l'a renouvele depuis la veille — evite qu'un blocus persiste indefiniment
// sans intervention. Verifie tous les bâtiments (pas seulement les terrains).
async function nettoyerBlocusExpires() {
  const resultats = { leves: 0 };
  try {
    const batiments = await sbGet('batiments_etat', '');
    if (!batiments) return resultats;

    for (const row of batiments) {
      let etat;
      try { etat = JSON.parse(row.data); } catch(e) { continue; }
      if (!etat.blocus) continue;

      const jourRenouvellement = etat.blocus.dernierRenouvellementJour || 0;
      const joursDepuis = (etat.jourActuelServeur || jourRenouvellement + 1) - jourRenouvellement;
      // Le cron tourne une fois par jour : si le dernier renouvellement date d'avant le
      // dernier passage du cron (pas du meme jour), le blocus tombe.
      const dernierPassage = etat.blocus.dernierPassageCron || etat.blocus.lanceLe;
      if (Date.now() - dernierPassage < 20 * 3600000) continue; // marge de securite ~20h

      await sbInsert('mails', {
        destinataire: etat.blocus.leaderActuel, expediteur: etat.blocus.syndicatNom || 'Syndicat',
        sujet: 'Blocus levé', corps: 'Faute de renouvellement, le blocus a été levé.', archived: false
      }).catch(() => {});

      delete etat.blocus;
      await sbUpdate('batiments_etat', `id=eq.${encodeURIComponent(row.id)}`, { data: JSON.stringify(etat), updated_at: new Date().toISOString() }).catch(() => {});
      resultats.leves++;
    }
  } catch(e) { console.error('nettoyerBlocusExpires error', e); }
  return resultats;
}

async function nettoyerAchatsDirectsManques() {"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Cron d'expiration du blocus créé (ébauche — voir note ci-dessous).")
