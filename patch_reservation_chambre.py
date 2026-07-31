#!/usr/bin/env python3

# --- 1. Hook dans doReserverChambreHotel (plateau-personnage.js) ---
PATH_P = "plateau-personnage.js"
with open(PATH_P, "r", encoding="utf-8") as f:
    p = f.read()

old_p = """  addJournalEntry('Vous avez reserve une chambre d\\'hotel. Vous obtiendrez un bonus de ' + bonus.paBonus + ' PA + ' + bonus.moral + ' moral en passant l\\'ordre dormir <strong>dans cette chambre</strong>.', 'event-good');
}"""
new_p = """  addJournalEntry('Vous avez reserve une chambre d\\'hotel. Vous obtiendrez un bonus de ' + bonus.paBonus + ' PA + ' + bonus.moral + ' moral en passant l\\'ordre dormir <strong>dans cette chambre</strong>.', 'event-good');
  if (typeof queteAccueilApresReservationChambre === 'function') queteAccueilApresReservationChambre();
}"""
assert p.count(old_p) == 1, f"plateau-personnage.js : trouvé {p.count(old_p)} fois (attendu 1)"
p = p.replace(old_p, new_p)

with open(PATH_P, "w", encoding="utf-8") as f:
    f.write(p)

# --- 2. plateau-quete-accueil.js : nouvelle fonction + acceptation des deux etapes au bar ---
PATH_Q = "plateau-quete-accueil.js"
with open(PATH_Q, "r", encoding="utf-8") as f:
    q = f.read()

old_q1 = """  if (etape === 'attente_bar' && buildingId === 'hotel-republica' && roomId === 'bar') {"""
new_q1 = """  if ((etape === 'attente_bar' || etape === 'attente_bar_apres_chambre') && buildingId === 'hotel-republica' && roomId === 'bar') {"""
assert q.count(old_q1) == 1, f"plateau-quete-accueil.js bloc 1 : trouvé {q.count(old_q1)} fois (attendu 1)"
q = q.replace(old_q1, new_q1)

old_q2 = """function afficherRepriseContactJeremy() {"""
new_q2 = """// Declenchee depuis le hook ajoute dans doReserverChambreHotel() (plateau-personnage.js).
function queteAccueilApresReservationChambre() {
  if (typeof state === 'undefined' || !state.char || !state.char.queteAccueil) return;
  if (state.char.queteAccueil.etape !== 'attente_bar') return; // deja reagi, ou etape non concernee

  state.char.queteAccueil = { etape: 'attente_bar_apres_chambre' };
  if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});

  afficherPopupQueteAccueil({
    image: QUETE_ACCUEIL_IMAGES.jeremy,
    titre: 'Jérémy',
    texte: "Parfait ! Maintenant, dès que vous passerez l'ordre Dormir dans cette chambre réservée, vous récupérerez plus de PA et de Moral que si vous dormiez n'importe où. Bon, en attendant, allons faire un tour au bar, juste à côté.",
    suivant: null
  });
}

function afficherRepriseContactJeremy() {"""
assert q.count(old_q2) == 1, f"plateau-quete-accueil.js bloc 2 : trouvé {q.count(old_q2)} fois (attendu 1)"
q = q.replace(old_q2, new_q2)

with open(PATH_Q, "w", encoding="utf-8") as f:
    f.write(q)

print("✅ Réaction de Jérémy après la réservation de chambre ajoutée.")
