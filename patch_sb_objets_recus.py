#!/usr/bin/env python3
PATH = "supabase.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """async function sbRamasserObjetAbandonne(objetId) {
  return sbDelete('objets_abandonnes', `id=eq.${encodeURIComponent(objetId)}`);
}"""

new = """async function sbRamasserObjetAbandonne(objetId) {
  return sbDelete('objets_abandonnes', `id=eq.${encodeURIComponent(objetId)}`);
}

// Don direct d'objet a un vrai joueur — reellement persiste (contrairement a l'ancien
// mecanisme purement local qui faisait juste disparaitre l'objet chez l'expediteur sans
// jamais l'ajouter chez le destinataire). Recupere a la prochaine connexion du destinataire.
async function sbDonnerObjetJoueur(objet, destinataire, expediteur) {
  const data = { id: 'objet-recu-' + Date.now() + '-' + Math.floor(Math.random()*1000), destinataire, expediteur, data: JSON.stringify(objet) };
  return sbInsert('objets_recus', data);
}

async function sbGetObjetsRecus(nom) {
  const rows = await sbGet('objets_recus', `destinataire=eq.${encodeURIComponent(nom)}`);
  if (!rows) return [];
  return rows.map(r => {
    try { return { id: r.id, expediteur: r.expediteur, objet: JSON.parse(r.data) }; }
    catch(e) { return null; }
  }).filter(Boolean);
}

async function sbSupprimerObjetRecu(objetId) {
  return sbDelete('objets_recus', `id=eq.${encodeURIComponent(objetId)}`);
}"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ sbDonnerObjetJoueur / sbGetObjetsRecus / sbSupprimerObjetRecu créées.")
