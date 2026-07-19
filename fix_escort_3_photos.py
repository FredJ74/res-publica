#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Correctif escort 3/3 -- integration des photos :
- plateau-multijoueur.js : banque de 3 photos F + 3 photos H, tirage aleatoire
  independant du prenom a chaque recrutement ET a chaque generation de
  remplacante ; appliquerRemplacantesEscort copie desormais aussi la photo
  (avant, seuls le nom et le role etaient repris, la photo restait figee)
- data.js : Natacha et Julien (les 2 escorts de depart au bar) ont maintenant
  une photo initiale au lieu d'un champ vide

A lancer APRES fix_escort_1_multijoueur.py et fix_escort_2_reste.py.
"""
import sys

def apply_patch(path, old, new, label):
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    count = content.count(old)
    if count == 0:
        print(f"[ECHEC] {label} : ancre introuvable dans {path}")
        return False
    if count > 1:
        print(f"[ECHEC] {label} : ancre trouvee {count} fois dans {path} (doit etre unique)")
        return False
    content = content.replace(old, new, 1)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"[OK] {label}")
    return True

ok = True

# ------------------------------------------------------------------
# 1) plateau-multijoueur.js -- photo au recrutement
# ------------------------------------------------------------------
old1 = """  if (!state.escortActive) state.escortActive = [];
  state.escortActive.push({ nom: nomEscort, tarif, depuis: state.day || 1, genre });

  if (!state.employes) state.employes = [];
  state.employes.push({
    nom: nomEscort, role: 'Escort — Agence Roxane Velours', job: 'escort', genre,
    photoUrl: '', photoPos: '50% 10%',
    cout: tarif, inGroupe: true,
    buildingId: state.currentBuilding,
    roomId: state.currentRoom,
    city: state.currentCity,
    depuis: state.day || 1,
    stats: statsEscort
  });"""

new1 = """  if (!state.escortActive) state.escortActive = [];
  state.escortActive.push({ nom: nomEscort, tarif, depuis: state.day || 1, genre });

  // Banque de photos Agence Roxane Velours (independante du prenom, tiree au hasard par genre)
  const PHOTOS_ESCORT = {
    F: [
      'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/escort-f-1-robe-verte.png',
      'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/escort-f-2-robe-or.png',
      'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/escort-f-3-robe-marine.png'
    ],
    H: [
      'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/escort-h-1-costume-beige.png',
      'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/escort-h-2-chemise-noire.png',
      'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/escort-h-3-chemise-ouverte.png'
    ]
  };
  const poolPhotos = PHOTOS_ESCORT[genre] || PHOTOS_ESCORT.F;
  const photoChoisie = poolPhotos[Math.floor(Math.random() * poolPhotos.length)];

  if (!state.employes) state.employes = [];
  state.employes.push({
    nom: nomEscort, role: 'Escort — Agence Roxane Velours', job: 'escort', genre,
    photoUrl: photoChoisie, photoPos: '50% 15%',
    cout: tarif, inGroupe: true,
    buildingId: state.currentBuilding,
    roomId: state.currentRoom,
    city: state.currentCity,
    depuis: state.day || 1,
    stats: statsEscort
  });"""

ok &= apply_patch('plateau-multijoueur.js', old1, new1, "plateau-multijoueur.js - photo aleatoire au recrutement")

# ------------------------------------------------------------------
# 2) plateau-multijoueur.js -- photo sur la remplacante
# ------------------------------------------------------------------
old2 = """  if (!state.escortRemplacante) state.escortRemplacante = {};
  const cleSlot = state.currentBuilding + '_' + state.currentRoom + '_' + genre;
  state.escortRemplacante[cleSlot] = {
    name: remplacante + ' (PNJ)',
    role: 'Escort — Agence Roxane Velours',
    job: 'escort',
    rel: 'neutral',
    genre
  };"""
new2 = """  const photoRemplacante = poolPhotos[Math.floor(Math.random() * poolPhotos.length)];
  if (!state.escortRemplacante) state.escortRemplacante = {};
  const cleSlot = state.currentBuilding + '_' + state.currentRoom + '_' + genre;
  state.escortRemplacante[cleSlot] = {
    name: remplacante + ' (PNJ)',
    role: 'Escort — Agence Roxane Velours',
    job: 'escort',
    rel: 'neutral',
    genre,
    photoUrl: photoRemplacante,
    photoPos: '50% 15%'
  };"""
ok &= apply_patch('plateau-multijoueur.js', old2, new2, "plateau-multijoueur.js - photo aleatoire sur la remplacante")

# ------------------------------------------------------------------
# 3) plateau-multijoueur.js -- appliquerRemplacantesEscort copie la photo
# ------------------------------------------------------------------
old3 = """function appliquerRemplacantesEscort(persons) {
  if (!state.escortRemplacante || !state.currentBuilding || !state.currentRoom) return persons;
  return persons.map(p => {
    if (p.job !== 'escort' || !p.genre) return p;
    const cle = state.currentBuilding + '_' + state.currentRoom + '_' + p.genre;
    const remp = state.escortRemplacante[cle];
    if (!remp) return p;
    return { ...p, name: remp.name, role: remp.role };
  });
}"""
new3 = """function appliquerRemplacantesEscort(persons) {
  if (!state.escortRemplacante || !state.currentBuilding || !state.currentRoom) return persons;
  return persons.map(p => {
    if (p.job !== 'escort' || !p.genre) return p;
    const cle = state.currentBuilding + '_' + state.currentRoom + '_' + p.genre;
    const remp = state.escortRemplacante[cle];
    if (!remp) return p;
    return { ...p, name: remp.name, role: remp.role, photoUrl: remp.photoUrl || p.photoUrl, photoPos: remp.photoPos || p.photoPos };
  });
}"""
ok &= apply_patch('plateau-multijoueur.js', old3, new3, "plateau-multijoueur.js - appliquerRemplacantesEscort copie la photo")

# ------------------------------------------------------------------
# 4) data.js -- photos initiales de Natacha et Julien
# ------------------------------------------------------------------
old4 = """          {name:'Natacha (PNJ)', role:'Escort — Agence Roxane Velours', rel:'neutral', job:'escort', genre:'F'},
          {name:'Julien (PNJ)', role:'Escort — Agence Roxane Velours', rel:'neutral', job:'escort', genre:'H'},"""
new4 = """          {name:'Natacha (PNJ)', role:'Escort — Agence Roxane Velours', rel:'neutral', job:'escort', genre:'F', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/escort-f-1-robe-verte.png', photoPos:'50% 15%'},
          {name:'Julien (PNJ)', role:'Escort — Agence Roxane Velours', rel:'neutral', job:'escort', genre:'H', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/escort-h-1-costume-beige.png', photoPos:'50% 15%'},"""
ok &= apply_patch('data.js', old4, new4, "data.js - photos initiales Natacha/Julien")

print()
if ok:
    print("TOUT EST OK.")
else:
    print("ECHEC. Ne rien committer, colle le detail a Claude.")
    sys.exit(1)
