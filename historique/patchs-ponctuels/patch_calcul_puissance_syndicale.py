#!/usr/bin/env python3
PATH = "plateau-organisations-quetes.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """function getMonSyndicatEtGrade() {"""

new = """// Puissance syndicale (0-100) : militants recrutes + demonstration de force en cours +
// palmares de blocus reussis + sympathie gagnee en cas de repression violente subie.
// Utilisee pour ameliorer les futurs blocus, et pour peser sur les indices de ville et la
// popularite du maire tant qu'un blocus est actif (voir cron serveur).
function calculerPuissanceSyndicale(syndicat, blocusActifQuelquePart) {
  if (!syndicat) return 0;
  const militants = (syndicat.membres || []).filter(m => m.estPnj).length;
  let puissance = militants * 3;
  if (blocusActifQuelquePart) puissance += 15;
  puissance += (syndicat.blocusReussis || 0) * 5;
  puissance += (syndicat.repressionsSubies || 0) * 8;
  return Math.max(0, Math.min(100, Math.round(puissance)));
}

function getMonSyndicatEtGrade() {"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Calcul de la puissance syndicale créé.")
