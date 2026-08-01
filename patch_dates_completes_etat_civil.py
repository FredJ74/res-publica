#!/usr/bin/env python3
PATH = "plateau-etat-civil.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

# --- 1. Registre : remplacer les annees seules par des dates completes (jour/mois/annee) ---
old_registre = """const ETAT_CIVIL_REGISTRE = {
  republic: [
    { nom: 'Pierre Thibault',     naissanceAnnee: 1898, parents: [],                                  mariageAnnee: 1920, conjoint: 'Marie Ravichoux',   decesAnnee: 1949 },
    { nom: 'Marie Ravichoux',     naissanceAnnee: null, parents: [],                                  mariageAnnee: 1920, conjoint: 'Pierre Thibault',    decesAnnee: null },
    { nom: 'Élise Thibault',      naissanceAnnee: 1929, parents: ['Pierre Thibault', 'Marie Ravichoux'], mariageAnnee: 1950, conjoint: 'Bernard Poinçon', decesAnnee: 1991 },
    { nom: 'Bernard Poinçon',     naissanceAnnee: null, parents: [],                                  mariageAnnee: 1950, conjoint: 'Élise Thibault',     decesAnnee: null },
    { nom: 'Gérard Poinçon',      naissanceAnnee: 1960, parents: ['Bernard Poinçon', 'Élise Thibault'], mariageAnnee: null, conjoint: null,               decesAnnee: null },
    { nom: 'Marcel Torcieu',      naissanceAnnee: 1895, parents: [],                                  mariageAnnee: 1915, conjoint: 'Mathilde Bijoux',    decesAnnee: 1958 },
    { nom: 'Mathilde Bijoux',     naissanceAnnee: null, parents: [],                                  mariageAnnee: 1915, conjoint: 'Marcel Torcieu',     decesAnnee: null },
    { nom: 'Maurice Caillon',     naissanceAnnee: 1901, parents: [],                                  mariageAnnee: 1920, conjoint: 'Lucienne Balrasse',  decesAnnee: 1954 },
    { nom: 'Lucienne Balrasse',   naissanceAnnee: null, parents: [],                                  mariageAnnee: 1920, conjoint: 'Maurice Caillon',    decesAnnee: null },
    { nom: 'Jacques Moulin',      naissanceAnnee: 1897, parents: [],                                  mariageAnnee: 1923, conjoint: 'Raymonde Charcot',   decesAnnee: 1965 },
    { nom: 'Raymonde Charcot',    naissanceAnnee: null, parents: [],                                  mariageAnnee: 1923, conjoint: 'Jacques Moulin',     decesAnnee: null },
    { nom: 'Étienne Tintabin',    naissanceAnnee: 1898, parents: [],                                  mariageAnnee: 1921, conjoint: 'Ludivine Girard',    decesAnnee: 1969 },
    { nom: 'Ludivine Girard',     naissanceAnnee: null, parents: [],                                  mariageAnnee: 1921, conjoint: 'Étienne Tintabin',   decesAnnee: null }
  ]
};"""

new_registre = """const ETAT_CIVIL_MOIS = ['janvier','février','mars','avril','mai','juin','juillet','août','septembre','octobre','novembre','décembre'];

const ETAT_CIVIL_REGISTRE = {
  republic: [
    { nom: 'Pierre Thibault',     naissanceAnnee: 1898, naissanceJour: 12, naissanceMois: 3,  parents: [],                                  mariageAnnee: 1920, mariageJour: 4,  mariageMois: 6,  conjoint: 'Marie Ravichoux',   decesAnnee: 1949, decesJour: 17, decesMois: 11 },
    { nom: 'Marie Ravichoux',     naissanceAnnee: null, naissanceJour: null, naissanceMois: null, parents: [],                              mariageAnnee: 1920, mariageJour: 4,  mariageMois: 6,  conjoint: 'Pierre Thibault',    decesAnnee: null, decesJour: null, decesMois: null },
    { nom: 'Élise Thibault',      naissanceAnnee: 1929, naissanceJour: 8,  naissanceMois: 8,  parents: ['Pierre Thibault', 'Marie Ravichoux'], mariageAnnee: 1950, mariageJour: 22, mariageMois: 5,  conjoint: 'Bernard Poinçon', decesAnnee: 1991, decesJour: 3, decesMois: 1 },
    { nom: 'Bernard Poinçon',     naissanceAnnee: null, naissanceJour: null, naissanceMois: null, parents: [],                              mariageAnnee: 1950, mariageJour: 22, mariageMois: 5,  conjoint: 'Élise Thibault',     decesAnnee: null, decesJour: null, decesMois: null },
    { nom: 'Gérard Poinçon',      naissanceAnnee: 1960, naissanceJour: 14, naissanceMois: 9,  parents: ['Bernard Poinçon', 'Élise Thibault'], mariageAnnee: null, mariageJour: null, mariageMois: null, conjoint: null,               decesAnnee: null, decesJour: null, decesMois: null },
    { nom: 'Marcel Torcieu',      naissanceAnnee: 1895, naissanceJour: 5,  naissanceMois: 2,  parents: [],                                  mariageAnnee: 1915, mariageJour: 19, mariageMois: 6,  conjoint: 'Mathilde Bijoux',    decesAnnee: 1958, decesJour: 30, decesMois: 10 },
    { nom: 'Mathilde Bijoux',     naissanceAnnee: null, naissanceJour: null, naissanceMois: null, parents: [],                              mariageAnnee: 1915, mariageJour: 19, mariageMois: 6,  conjoint: 'Marcel Torcieu',     decesAnnee: null, decesJour: null, decesMois: null },
    { nom: 'Maurice Caillon',     naissanceAnnee: 1901, naissanceJour: 21, naissanceMois: 7,  parents: [],                                  mariageAnnee: 1920, mariageJour: 9,  mariageMois: 4,  conjoint: 'Lucienne Balrasse',  decesAnnee: 1954, decesJour: 2, decesMois: 12 },
    { nom: 'Lucienne Balrasse',   naissanceAnnee: null, naissanceJour: null, naissanceMois: null, parents: [],                              mariageAnnee: 1920, mariageJour: 9,  mariageMois: 4,  conjoint: 'Maurice Caillon',    decesAnnee: null, decesJour: null, decesMois: null },
    { nom: 'Jacques Moulin',      naissanceAnnee: 1897, naissanceJour: 16, naissanceMois: 1,  parents: [],                                  mariageAnnee: 1923, mariageJour: 27, mariageMois: 3,  conjoint: 'Raymonde Charcot',   decesAnnee: 1965, decesJour: 8, decesMois: 6 },
    { nom: 'Raymonde Charcot',    naissanceAnnee: null, naissanceJour: null, naissanceMois: null, parents: [],                              mariageAnnee: 1923, mariageJour: 27, mariageMois: 3,  conjoint: 'Jacques Moulin',     decesAnnee: null, decesJour: null, decesMois: null },
    { nom: 'Étienne Tintabin',    naissanceAnnee: 1898, naissanceJour: 11, naissanceMois: 5,  parents: [],                                  mariageAnnee: 1921, mariageJour: 14, mariageMois: 9,  conjoint: 'Ludivine Girard',    decesAnnee: 1969, decesJour: 25, decesMois: 4 },
    { nom: 'Ludivine Girard',     naissanceAnnee: null, naissanceJour: null, naissanceMois: null, parents: [],                              mariageAnnee: 1921, mariageJour: 14, mariageMois: 9,  conjoint: 'Étienne Tintabin',   decesAnnee: null, decesJour: null, decesMois: null }
  ]
};

function etatCivilFormaterDate(jour, mois, annee) {
  if (!annee) return '';
  if (jour && mois) return jour + ' ' + ETAT_CIVIL_MOIS[mois - 1] + ' ' + annee;
  return String(annee);
}"""

assert content.count(old_registre) == 1, f"registre : trouvé {content.count(old_registre)} fois (attendu 1)"
content = content.replace(old_registre, new_registre)

# --- 2. Fonction de construction de fiche : utiliser les dates completes ---
old_fiche = """  if (p.naissanceAnnee) {
    const parentsTxt = (p.parents && p.parents.length === 2)
      ? ', fils/fille de ' + p.parents[0] + ' et ' + p.parents[1]
      : '';
    evenements.push({ annee: p.naissanceAnnee, texte: p.naissanceAnnee + ' : naissance de ' + p.nom + parentsTxt + '.' });
  }
  if (p.mariageAnnee && p.conjoint) {
    evenements.push({ annee: p.mariageAnnee, texte: p.mariageAnnee + ' : mariage de ' + p.nom + ' avec ' + p.conjoint + '.' });
  }
  // Enfants : toute personne du registre dont p.nom figure dans ses parents.
  registre.forEach(function(autre) {
    if (autre.parents && autre.parents.indexOf(p.nom) !== -1 && autre.naissanceAnnee) {
      const parentsEnfantTxt = autre.parents.join(' et ');
      evenements.push({ annee: autre.naissanceAnnee, texte: autre.naissanceAnnee + ' : naissance de ' + autre.nom + ', fils/fille de ' + parentsEnfantTxt + '.' });
    }
  });
  if (p.decesAnnee) {
    evenements.push({ annee: p.decesAnnee, texte: p.decesAnnee + ' : décès de ' + p.nom + '.' });
  }"""

new_fiche = """  if (p.naissanceAnnee) {
    const parentsTxt = (p.parents && p.parents.length === 2)
      ? ', fils/fille de ' + p.parents[0] + ' et ' + p.parents[1]
      : '';
    const dateTxt = etatCivilFormaterDate(p.naissanceJour, p.naissanceMois, p.naissanceAnnee);
    evenements.push({ annee: p.naissanceAnnee, texte: dateTxt + ' : naissance de ' + p.nom + parentsTxt + '.' });
  }
  if (p.mariageAnnee && p.conjoint) {
    const dateTxt = etatCivilFormaterDate(p.mariageJour, p.mariageMois, p.mariageAnnee);
    evenements.push({ annee: p.mariageAnnee, texte: dateTxt + ' : mariage de ' + p.nom + ' avec ' + p.conjoint + '.' });
  }
  // Enfants : toute personne du registre dont p.nom figure dans ses parents.
  registre.forEach(function(autre) {
    if (autre.parents && autre.parents.indexOf(p.nom) !== -1 && autre.naissanceAnnee) {
      const parentsEnfantTxt = autre.parents.join(' et ');
      const dateTxt = etatCivilFormaterDate(autre.naissanceJour, autre.naissanceMois, autre.naissanceAnnee);
      evenements.push({ annee: autre.naissanceAnnee, texte: dateTxt + ' : naissance de ' + autre.nom + ', fils/fille de ' + parentsEnfantTxt + '.' });
    }
  });
  if (p.decesAnnee) {
    const dateTxt = etatCivilFormaterDate(p.decesJour, p.decesMois, p.decesAnnee);
    evenements.push({ annee: p.decesAnnee, texte: dateTxt + ' : décès de ' + p.nom + '.' });
  }"""

assert content.count(old_fiche) == 1, f"fiche : trouvé {content.count(old_fiche)} fois (attendu 1)"
content = content.replace(old_fiche, new_fiche)

# --- 3. Impression : utiliser <br><br> au lieu du \\n litteral (rendu HTML, pas texte brut) ---
old_join = """  const texteComplet = fiche.evenements.map(function(e) { return e.texte; }).join('\\\\n');"""
new_join = """  const texteComplet = fiche.evenements.map(function(e) { return e.texte; }).join('<br><br>');"""
assert content.count(old_join) == 1, f"join : trouvé {content.count(old_join)} fois (attendu 1)"
content = content.replace(old_join, new_join)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Dates complètes (jour/mois/année) + retours à la ligne réels dans la fiche imprimée.")
