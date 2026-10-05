#!/usr/bin/env python3
PATH = "plateau-etat-civil.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

# --- 1. Cache + chargement des vrais joueurs depuis Supabase ---
old_1 = """function etatCivilFormaterDate(jour, mois, annee) {
  if (!annee) return '';
  if (jour && mois) return jour + ' ' + ETAT_CIVIL_MOIS[mois - 1] + ' ' + annee;
  return String(annee);
}"""
new_1 = """function etatCivilFormaterDate(jour, mois, annee) {
  if (!annee) return '';
  if (jour && mois) return jour + ' ' + ETAT_CIVIL_MOIS[mois - 1] + ' ' + annee;
  return String(annee);
}

// Cache des vrais joueurs (naissance = date de creation du personnage), charge une seule
// fois par session depuis Supabase. Permet au registre de recenser aussi les PJ, pas
// seulement les personnages historiques de l'enigme.
let ETAT_CIVIL_CACHE_JOUEURS = null;

async function etatCivilChargerJoueurs() {
  if (ETAT_CIVIL_CACHE_JOUEURS) return ETAT_CIVIL_CACHE_JOUEURS;
  try {
    const rows = (typeof sbGet === 'function') ? await sbGet('personnages', 'select=name,country,created_at') : [];
    ETAT_CIVIL_CACHE_JOUEURS = rows || [];
  } catch (e) {
    ETAT_CIVIL_CACHE_JOUEURS = [];
  }
  return ETAT_CIVIL_CACHE_JOUEURS;
}"""
assert content.count(old_1) == 1, f"bloc 1 : trouvé {content.count(old_1)} fois (attendu 1)"
content = content.replace(old_1, new_1)

# --- 2. etatCivilConstruireFiche : chercher aussi parmi les vrais joueurs si pas trouve dans le registre historique ---
old_2 = """function etatCivilConstruireFiche(nomPersonne) {
  const registre = ETAT_CIVIL_REGISTRE[state.country] || [];
  const p = registre.find(function(x) { return x.nom === nomPersonne; });
  if (!p) return null;"""
new_2 = """function etatCivilConstruireFiche(nomPersonne) {
  const registre = ETAT_CIVIL_REGISTRE[state.country] || [];
  const p = registre.find(function(x) { return x.nom === nomPersonne; });

  if (!p) {
    // Pas un personnage historique : peut-etre un vrai joueur (naissance = creation du perso).
    const joueur = (ETAT_CIVIL_CACHE_JOUEURS || []).find(function(j) { return j.name === nomPersonne; });
    if (joueur && joueur.created_at) {
      const d = new Date(joueur.created_at);
      const texte = d.getDate() + ' ' + ETAT_CIVIL_MOIS[d.getMonth()] + ' ' + d.getFullYear() + ' : naissance de ' + joueur.name + '.';
      return { nom: joueur.name, evenements: [{ annee: d.getFullYear(), texte: texte }] };
    }
    return null;
  }"""
assert content.count(old_2) == 1, f"bloc 2 : trouvé {content.count(old_2)} fois (attendu 1)"
content = content.replace(old_2, new_2)

# --- 3. etatCivilRechercher : inclure aussi les vrais joueurs dans les resultats ---
old_3 = """    if (resultats.indexOf(p.nom) === -1) resultats.push(p.nom);
  });
  return resultats;
}"""
new_3 = """    if (resultats.indexOf(p.nom) === -1) resultats.push(p.nom);
  });

  // Vrais joueurs (meme empire uniquement)
  (ETAT_CIVIL_CACHE_JOUEURS || []).forEach(function(j) {
    if (j.country !== state.country) return;
    if (nomLower && j.name.toLowerCase().indexOf(nomLower) === -1) return;
    if (decDebut !== null) {
      if (!j.created_at) return;
      const annee = new Date(j.created_at).getFullYear();
      if (annee < decDebut || annee > decFin) return;
    }
    if (resultats.indexOf(j.name) === -1) resultats.push(j.name);
  });

  return resultats;
}"""
assert content.count(old_3) == 1, f"bloc 3 : trouvé {content.count(old_3)} fois (attendu 1)"
content = content.replace(old_3, new_3)

# --- 4. etatCivilLancerRecherche devient async : on charge les joueurs avant de chercher ---
old_4 = """function etatCivilLancerRecherche() {
  const nomInput = document.getElementById('etat-civil-nom');"""
new_4 = """async function etatCivilLancerRecherche() {
  await etatCivilChargerJoueurs();
  const nomInput = document.getElementById('etat-civil-nom');"""
assert content.count(old_4) == 1, f"bloc 4 : trouvé {content.count(old_4)} fois (attendu 1)"
content = content.replace(old_4, new_4)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Le registre d'état-civil recense désormais aussi les vrais joueurs (naissance = date de création).")
