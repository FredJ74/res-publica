#!/usr/bin/env python3
PATH = "supabase.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """async function sbGetMariageActif(nom) {
  if (!nom) return null;
  const rows1 = await sbGet('mariages', `conjoint1=eq.${encodeURIComponent(nom)}&statut=eq.actif`).catch(() => []);
  if (rows1 && rows1.length > 0) return rows1[0];
  const rows2 = await sbGet('mariages', `conjoint2=eq.${encodeURIComponent(nom)}&statut=eq.actif`).catch(() => []);
  if (rows2 && rows2.length > 0) return rows2[0];
  return null;
}"""

new = """async function sbGetMariageActif(nom) {
  if (!nom) return null;
  const rows1 = await sbGet('mariages', `conjoint1=eq.${encodeURIComponent(nom)}&statut=eq.actif`).catch(() => []);
  if (rows1 && rows1.length > 0) return rows1[0];
  const rows2 = await sbGet('mariages', `conjoint2=eq.${encodeURIComponent(nom)}&statut=eq.actif`).catch(() => []);
  if (rows2 && rows2.length > 0) return rows2[0];
  return null;
}

// Dissout un mariage (divorce ou veuvage) sans jamais supprimer la ligne — la memoire de
// l'union reste consultable pour toujours (etat-civil).
async function sbDissoudreMariage(id, raison) {
  return sbUpdate('mariages', `id=eq.${encodeURIComponent(id)}`, { statut: 'dissous', raison_dissolution: raison || 'divorce' });
}

// Recense tous les mariages (actifs ou dissous) impliquant un nom donne, pour l'etat-civil.
async function sbGetMariagesPourNom(nom) {
  if (!nom) return [];
  const rows1 = await sbGet('mariages', `conjoint1=eq.${encodeURIComponent(nom)}`).catch(() => []);
  const rows2 = await sbGet('mariages', `conjoint2=eq.${encodeURIComponent(nom)}`).catch(() => []);
  return [...(rows1 || []), ...(rows2 || [])];
}

// Archive permanente d'un deces de PJ (le personnage lui-meme est supprime de 'personnages',
// donc c'est la seule trace qui persiste pour l'etat-civil).
async function sbEnregistrerDeces(nom, country) {
  return sbInsert('etat_civil_deces', { id: 'deces-' + Date.now(), nom, country });
}

async function sbGetDecesPourNom(nom) {
  if (!nom) return null;
  const rows = await sbGet('etat_civil_deces', `nom=eq.${encodeURIComponent(nom)}`).catch(() => []);
  return (rows && rows.length > 0) ? rows[0] : null;
}

async function sbGetTousLesDeces(country) {
  const rows = await sbGet('etat_civil_deces', `country=eq.${encodeURIComponent(country)}`).catch(() => []);
  return rows || [];
}

async function sbGetTousLesMariages(country) {
  const rows = await sbGet('mariages', `country=eq.${encodeURIComponent(country)}`).catch(() => []);
  return rows || [];
}"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Fonctions Supabase créées : dissolution de mariage, archivage des décès, recherches globales.")
