#!/usr/bin/env python3
PATH = "plateau-etat-civil.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

# --- 1. Charger aussi mariages et deces en meme temps que les joueurs ---
old_1 = """async function etatCivilChargerJoueurs() {
  if (ETAT_CIVIL_CACHE_JOUEURS) return ETAT_CIVIL_CACHE_JOUEURS;
  try {
    const rows = (typeof sbGet === 'function') ? await sbGet('personnages', 'select=name,country,created_at') : [];
    ETAT_CIVIL_CACHE_JOUEURS = rows || [];
  } catch (e) {
    ETAT_CIVIL_CACHE_JOUEURS = [];
  }
  return ETAT_CIVIL_CACHE_JOUEURS;
}"""

new_1 = """let ETAT_CIVIL_CACHE_MARIAGES = null;
let ETAT_CIVIL_CACHE_DECES = null;

async function etatCivilChargerJoueurs() {
  if (ETAT_CIVIL_CACHE_JOUEURS) return ETAT_CIVIL_CACHE_JOUEURS;
  try {
    const rows = (typeof sbGet === 'function') ? await sbGet('personnages', 'select=name,country,created_at') : [];
    ETAT_CIVIL_CACHE_JOUEURS = rows || [];
  } catch (e) {
    ETAT_CIVIL_CACHE_JOUEURS = [];
  }
  try {
    ETAT_CIVIL_CACHE_MARIAGES = (typeof sbGetTousLesMariages === 'function') ? await sbGetTousLesMariages(state.country) : [];
  } catch (e) {
    ETAT_CIVIL_CACHE_MARIAGES = [];
  }
  try {
    ETAT_CIVIL_CACHE_DECES = (typeof sbGetTousLesDeces === 'function') ? await sbGetTousLesDeces(state.country) : [];
  } catch (e) {
    ETAT_CIVIL_CACHE_DECES = [];
  }
  return ETAT_CIVIL_CACHE_JOUEURS;
}"""
assert content.count(old_1) == 1, f"bloc 1 : trouvé {content.count(old_1)} fois (attendu 1)"
content = content.replace(old_1, new_1)

# --- 2. Ajouter mariage/divorce/deces a la fiche d'un vrai joueur ---
old_2 = """    const joueur = (ETAT_CIVIL_CACHE_JOUEURS || []).find(function(j) { return j.name === nomPersonne; });
    if (joueur && joueur.created_at) {
      const d = new Date(joueur.created_at);
      const texte = d.getDate() + ' ' + ETAT_CIVIL_MOIS[d.getMonth()] + ' ' + d.getFullYear() + ' : naissance de ' + joueur.name + '.';
      return { nom: joueur.name, evenements: [{ annee: d.getFullYear(), texte: texte }] };
    }
    return null;
  }"""

new_2 = """    const joueur = (ETAT_CIVIL_CACHE_JOUEURS || []).find(function(j) { return j.name === nomPersonne; });
    if (!joueur) return null;

    const evenementsJoueur = [];
    if (joueur.created_at) {
      const d = new Date(joueur.created_at);
      evenementsJoueur.push({ annee: d.getFullYear(), texte: d.getDate() + ' ' + ETAT_CIVIL_MOIS[d.getMonth()] + ' ' + d.getFullYear() + ' : naissance de ' + joueur.name + '.' });
    }

    (ETAT_CIVIL_CACHE_MARIAGES || []).forEach(function(m) {
      if (m.conjoint1 !== nomPersonne && m.conjoint2 !== nomPersonne) return;
      const conjoint = m.conjoint1 === nomPersonne ? m.conjoint2 : m.conjoint1;
      if (!m.created_at) return;
      const dm = new Date(m.created_at);
      const dateTxt = dm.getDate() + ' ' + ETAT_CIVIL_MOIS[dm.getMonth()] + ' ' + dm.getFullYear();
      evenementsJoueur.push({ annee: dm.getFullYear(), texte: dateTxt + ' : mariage de ' + nomPersonne + ' avec ' + conjoint + '.' });
      if (m.statut === 'dissous') {
        const motif = m.raison_dissolution === 'veuvage' ? 'veuvage' : 'divorce';
        evenementsJoueur.push({ annee: dm.getFullYear(), texte: 'Union avec ' + conjoint + ' dissoute (' + motif + ').' });
      }
    });

    const deces = (ETAT_CIVIL_CACHE_DECES || []).find(function(x) { return x.nom === nomPersonne; });
    if (deces && deces.created_at) {
      const dd = new Date(deces.created_at);
      evenementsJoueur.push({ annee: dd.getFullYear(), texte: dd.getDate() + ' ' + ETAT_CIVIL_MOIS[dd.getMonth()] + ' ' + dd.getFullYear() + ' : décès de ' + joueur.name + '.' });
    }

    evenementsJoueur.sort(function(a, b) { return a.annee - b.annee; });
    return { nom: joueur.name, evenements: evenementsJoueur };
  }"""
assert content.count(old_2) == 1, f"bloc 2 : trouvé {content.count(old_2)} fois (attendu 1)"
content = content.replace(old_2, new_2)

# --- 3. Recherche par decennie pour les vrais joueurs : verifier TOUS leurs evenements (via la fiche), pas juste la naissance ---
old_3 = """  // Vrais joueurs (meme empire uniquement)
  (ETAT_CIVIL_CACHE_JOUEURS || []).forEach(function(j) {
    if (j.country !== state.country) return;
    if (nomLower && j.name.toLowerCase().indexOf(nomLower) === -1) return;
    if (decDebut !== null) {
      if (!j.created_at) return;
      const annee = new Date(j.created_at).getFullYear();
      if (annee < decDebut || annee > decFin) return;
    }
    if (resultats.indexOf(j.name) === -1) resultats.push(j.name);
  });"""
new_3 = """  // Vrais joueurs (meme empire uniquement) — verifie tous les evenements (naissance,
  // mariage/divorce, deces), pas seulement la naissance, pour la recherche par decennie.
  (ETAT_CIVIL_CACHE_JOUEURS || []).forEach(function(j) {
    if (j.country !== state.country) return;
    if (nomLower && j.name.toLowerCase().indexOf(nomLower) === -1) return;
    if (decDebut !== null) {
      const fiche = etatCivilConstruireFiche(j.name);
      const ok = fiche && fiche.evenements.some(function(e) { return e.annee >= decDebut && e.annee <= decFin; });
      if (!ok) return;
    }
    if (resultats.indexOf(j.name) === -1) resultats.push(j.name);
  });"""
assert content.count(old_3) == 1, f"bloc 3 : trouvé {content.count(old_3)} fois (attendu 1)"
content = content.replace(old_3, new_3)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Mariage, divorce/veuvage et décès intégrés à l'état-civil des vrais joueurs.")
