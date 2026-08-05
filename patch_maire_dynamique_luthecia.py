#!/usr/bin/env python3
PATH = "plateau-organisations-quetes.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """// Cas particulier du maire : le posteId varie selon la ville (maire_a, maire_b...), pas de poste 'maire' generique
async function getTitulaireMaire(pays, ville) {"""

new = """// Presence dynamique du PNJ "Le Maire" de Luthecia, selon que le poste est occupe par un
// PJ ou vacant. Bureau du Maire : le PNJ n'y est que si le poste est vacant (sinon, c'est le
// PJ qui l'occupe). Hall : le PNJ (retrograde en simple citoyen) n'y apparait QUE si le
// poste est occupe par un PJ (sinon, il est "au travail" dans son bureau).
async function verifierPresenceMaireLuthecia(buildingId, roomId) {
  if (buildingId !== 'mairie-capitale') return;
  if (roomId !== 'hall_mairie' && roomId !== 'bureau_maire') return;
  if (typeof getTitulaireMaire !== 'function' || typeof renderPersonsList !== 'function') return;

  const titulaire = await getTitulaireMaire(state.country, 'capitale');
  // Le joueur a change de piece entre-temps : on n'ecrase pas un affichage devenu obsolete
  if (state.currentBuilding !== buildingId || state.currentRoom !== roomId) return;

  const room = BUILDINGS[buildingId]?.rooms?.[roomId];
  if (!room) return;
  const autresPersonnes = (room.persons || []).filter(p => p.job !== 'maire');

  if (roomId === 'bureau_maire') {
    renderPersonsList(titulaire ? autresPersonnes : (room.persons || []));
  } else if (roomId === 'hall_mairie') {
    if (titulaire) {
      const ancienMaire = { name: 'Gaston Ferule', role: 'Ancien maire, simple citoyen désormais', rel: 'neutral', job: 'citoyen' };
      renderPersonsList([...autresPersonnes, ancienMaire]);
    } else {
      renderPersonsList(autresPersonnes);
    }
  }
}

// Cas particulier du maire : le posteId varie selon la ville (maire_a, maire_b...), pas de poste 'maire' generique
async function getTitulaireMaire(pays, ville) {"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Présence dynamique du maire de Luthécia créée (nom provisoire : Gaston Férule, à ajuster si besoin).")
