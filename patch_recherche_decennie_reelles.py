#!/usr/bin/env python3
PATH = "plateau-communication.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  const historiques = ENIGME1_ARCHIVES_HISTORIQUES.filter(function(a) {
    if (nomLower && a.nom.toLowerCase().indexOf(nomLower) === -1) return false;
    if (decDebut !== null) {
      const chevauche = a.anneeFin >= decDebut && a.anneeDebut <= decFin;
      if (!chevauche) return false;
    }
    return true;
  });

  const reels = (decDebut !== null) ? [] : (state._detentionsReelles || []).filter(function(d) {
    if (nomLower && d.nom.toLowerCase().indexOf(nomLower) === -1) return false;
    return true;
  });"""

new = """  const historiques = ENIGME1_ARCHIVES_HISTORIQUES.filter(function(a) {
    if (nomLower && a.nom.toLowerCase().indexOf(nomLower) === -1) return false;
    if (decDebut !== null) {
      const chevauche = a.anneeFin >= decDebut && a.anneeDebut <= decFin;
      if (!chevauche) return false;
    }
    return true;
  });

  const reels = (state._detentionsReelles || []).filter(function(d) {
    if (nomLower && d.nom.toLowerCase().indexOf(nomLower) === -1) return false;
    if (decDebut !== null) {
      if (!d.created_at) return false; // pas de date connue, exclu d'une recherche par decennie
      const annee = new Date(d.created_at).getFullYear();
      if (annee < decDebut || annee > decFin) return false;
    }
    return true;
  });"""
assert content.count(old) == 1, f"filtre : trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

old_2 = """  reels.forEach(function(d, i) {
    html += '<div onclick="ouvrirDetailDetention(' + i + ')" style="cursor:pointer;padding:.6rem;border:1px solid #2a2010;background:#0f0d05">';
    html += '<div style="display:flex;justify-content:space-between"><span style="font-family:Playfair Display,serif;font-size:.82rem;color:#c0b090">' + d.nom + (d.qhs ? ' <span style="color:#8a3a2a">(QHS)</span>' : '') + '</span><span style="font-size:.7rem;color:#5a4030">Jour ' + d.jour_debut + '</span></div>';
    html += '<div style="font-size:.72rem;color:#6a5a30">' + d.raison + (d.jour_fin ? ' (fin prevue Jour ' + d.jour_fin + ')' : '') + '</div>';
    html += '</div>';
  });"""
new_2 = """  reels.forEach(function(d, i) {
    const annee = d.created_at ? new Date(d.created_at).getFullYear() : '?';
    const duree = (d.jour_fin && d.jour_debut) ? (d.jour_fin - d.jour_debut) + ' jour(s)' : 'en cours';
    html += '<div onclick="ouvrirDetailDetention(' + i + ')" style="cursor:pointer;padding:.6rem;border:1px solid #2a2010;background:#0f0d05">';
    html += '<div style="display:flex;justify-content:space-between"><span style="font-family:Playfair Display,serif;font-size:.82rem;color:#c0b090">' + d.nom + (d.qhs ? ' <span style="color:#8a3a2a">(QHS)</span>' : '') + '</span><span style="font-size:.7rem;color:#5a4030">' + annee + ' · ' + duree + '</span></div>';
    html += '<div style="font-size:.72rem;color:#6a5a30">' + d.raison + '</div>';
    html += '</div>';
  });"""
assert content.count(old_2) == 1, f"affichage : trouvé {content.count(old_2)} fois (attendu 1)"
content = content.replace(old_2, new_2)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Recherche par décennie et affichage unifiés (nom, durée, motif) pour les deux sources.")
