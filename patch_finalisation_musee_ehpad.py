#!/usr/bin/env python3
PATH = "data.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

# --- 1. Vraie image de l'EHPAD ---
old_1 = '''        imageUrl: "https://images.unsplash.com/photo-1573497491765-dccce02b29df?w=1200&q=80",
        persons: [
          {name:'Jeanine Dubois (PNJ)', role:'Ancienne institutrice', rel:'neutral', job:'pensionnaire_ehpad', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/jeanine-dubois-ehpad.png', photoPos:'50% 15%'},'''
new_1 = '''        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/ehpad-residence-tilleuls.png",
        persons: [
          {name:'Jeanine Dubois (PNJ)', role:'Ancienne institutrice', rel:'neutral', job:'pensionnaire_ehpad', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/jeanine-dubois-ehpad.png', photoPos:'50% 15%'},'''
assert content.count(old_1) == 1, f"bloc 1 (image EHPAD) : trouvé {content.count(old_1)} fois (attendu 1)"
content = content.replace(old_1, new_1)

# --- 2. Retirer le debarras de sa position actuelle (juste apres le hall) ---
old_2 = """      debarras: {
        name: "Débarras",
        imageBg: "linear-gradient(135deg,#0a0806,#100c08)",
        desc: "Une porte fermée à clé, discrète, au fond du musée. Personne ne semble jamais y entrer.",
        imageUrl: "https://images.unsplash.com/photo-1558959357-d7a08d1f7e13?w=1200&q=80",
        locked: true,
        persons: [],
        orders: []
      },
      salle_criminels: {"""
new_2 = """      salle_criminels: {"""
assert content.count(old_2) == 1, f"bloc 2 (retrait debarras) : trouvé {content.count(old_2)} fois (attendu 1)"
content = content.replace(old_2, new_2)

# --- 3. Ajouter Valerie Loisillon au hall (photo recadree sur l'image du hall) ---
old_3 = """      hall: {
        name: "Hall d'accueil",
        imageBg: "linear-gradient(135deg,#1c160c,#241c10)",
        desc: "Le hall d'accueil du musee de la ville de Luthecia.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/hall-musee-ville-luthecia.png",
        persons: [
          {name:'Gérard Poinçon (PNJ)', role:'Gardien du musée', rel:'neutral', job:'gardien_musee', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/gerard-poincon-gardien-musee.png', photoPos:'50% 15%'}
        ],
        orders: []
      },"""
new_3 = """      hall: {
        name: "Hall d'accueil",
        imageBg: "linear-gradient(135deg,#1c160c,#241c10)",
        desc: "Le hall d'accueil du musee de la ville de Luthecia.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/hall-musee-ville-luthecia.png",
        persons: [
          {name:'Gérard Poinçon (PNJ)', role:'Gardien du musée', rel:'neutral', job:'gardien_musee', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/gerard-poincon-gardien-musee.png', photoPos:'50% 15%'},
          {name:'Valérie Loisillon (PNJ)', role:'Hôtesse d\\'accueil', rel:'neutral', job:'hotesse', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/hall-musee-ville-luthecia.png', photoPos:'20% 30%'}
        ],
        orders: []
      },"""
assert content.count(old_3) == 1, f"bloc 3 (Valerie) : trouvé {content.count(old_3)} fois (attendu 1)"
content = content.replace(old_3, new_3)

# --- 4. Re-ajouter le debarras a la toute fin de la liste des salles du musee (apres salle_scandales) ---
old_4 = """      salle_scandales: {
        name: "Salle des Scandales et Affaires",
        imageBg: "linear-gradient(135deg,#100c10,#181018)",
        desc: "Les grandes crises politiques et affaires qui ont secoue Luthecia. Classement a venir.",
        persons: [],
        orders: []
      }
    }
  },

  // =====================
  // MUSEE NATIONAL DE REPUBLIA"""
new_4 = """      salle_scandales: {
        name: "Salle des Scandales et Affaires",
        imageBg: "linear-gradient(135deg,#100c10,#181018)",
        desc: "Les grandes crises politiques et affaires qui ont secoue Luthecia. Classement a venir.",
        persons: [],
        orders: []
      },
      debarras: {
        name: "Débarras",
        imageBg: "linear-gradient(135deg,#0a0806,#100c08)",
        desc: "Une porte fermée à clé, discrète, au fond du musée. Personne ne semble jamais y entrer.",
        imageUrl: "https://images.unsplash.com/photo-1558959357-d7a08d1f7e13?w=1200&q=80",
        locked: true,
        persons: [],
        orders: []
      }
    }
  },

  // =====================
  // MUSEE NATIONAL DE REPUBLIA"""
assert content.count(old_4) == 1, f"bloc 4 (re-ajout debarras) : trouvé {content.count(old_4)} fois (attendu 1)"
content = content.replace(old_4, new_4)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ EHPAD (vraie image), Débarras (déplacé en dernier), Valérie Loisillon ajoutée.")
