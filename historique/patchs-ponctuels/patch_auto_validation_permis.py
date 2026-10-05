#!/usr/bin/env python3
PATH = "api/cron-minuit.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """async function preleverLoyersLots() {"""
new = """// Validation automatique d'un permis en attente depuis 7 jours sans decision du maire —
// evite qu'une demande reste bloquee indefiniment si le poste est vacant ou inactif.
// Sans reponse = reputee positive.
async function autoValiderPermisEnAttente() {
  const resultats = { valides: 0 };
  const LIMITE_JOURS_MS = 7 * 24 * 60 * 60 * 1000;
  try {
    const terrains = await sbGet('terrains_etat', '');
    if (!terrains) return resultats;

    for (const row of terrains) {
      let etat;
      try { etat = JSON.parse(row.data); } catch(e) { continue; }
      if (!etat.permis || etat.permis.statut !== 'attente_validation') continue;
      if (!etat.permis.dateEntreeAttente) continue;
      if (Date.now() - etat.permis.dateEntreeAttente < LIMITE_JOURS_MS) continue;

      etat.permis.statut = 'valide';
      etat.permis.autoValide = true;
      etat.constructionAutorisee = true;
      await sbUpdate('terrains_etat', `id=eq.${encodeURIComponent(row.id)}`, { data: JSON.stringify(etat), updated_at: new Date().toISOString() }).catch(() => {});
      resultats.valides++;
    }
  } catch(e) { console.error('autoValiderPermisEnAttente error', e); }
  return resultats;
}

async function preleverLoyersLots() {"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

old_2 = """    // 5. Loyers des lots subdivises (locataire -> proprietaire directement)
    const loyersLots = await preleverLoyersLots();

    return res.status(200).json({ ok: true, traites: results.length, details: results, mailsSupprimes: mailsSuppres, fuites, taxeFonciere, loyersLots });"""
new_2 = """    // 5. Loyers des lots subdivises (locataire -> proprietaire directement)
    const loyersLots = await preleverLoyersLots();

    // 6. Validation automatique des permis en attente depuis 7 jours (sans reponse = positive)
    const permisAutoValides = await autoValiderPermisEnAttente();

    return res.status(200).json({ ok: true, traites: results.length, details: results, mailsSupprimes: mailsSuppres, fuites, taxeFonciere, loyersLots, permisAutoValides });"""
assert content.count(old_2) == 1, f"trouvé {content.count(old_2)} fois (attendu 1)"
content = content.replace(old_2, new_2)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Validation automatique du permis après 7 jours sans réponse du maire.")
