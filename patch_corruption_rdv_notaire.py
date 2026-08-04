#!/usr/bin/env python3
PATH = "plateau-pnj.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """function initSimulation() {"""
new = """// Accelere (reduit de moitie le delai restant) le rendez-vous notarial d'un achat direct en
// attente, contre corruption — meme principe que corrompre_fonctionnaire_permis.
async function doCorrompreRdvNotaire() {
  const id = state.currentBuilding;
  const ts = getTerrainState(id);
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  if (!ts.achatDirect || ts.achatDirect.demandeur !== state.char?.name) {
    showToast('Impossible', "Vous n'avez pas de rendez-vous en attente ici.", false);
    return;
  }
  const cout = 800;
  if (state.arg < cout) { showToast('Fonds insuffisants', cout + ' ' + cur + ' requis.', false); return; }

  const maintenant = Date.now();
  const restant = ts.achatDirect.dateAchat - maintenant;
  if (restant <= 0) { showToast('Inutile', 'Le rendez-vous est déjà arrivé.', false); return; }

  state.arg -= cout;
  const nouvelleDateAchat = maintenant + Math.floor(restant / 2);
  const achatDirect = { ...ts.achatDirect, dateAchat: nouvelleDateAchat, dateLimite: nouvelleDateAchat + 24 * 3600000 };
  const nouvelEtat = setTerrainState(id, { achatDirect });
  if (typeof sbSetTerrainState === 'function') await sbSetTerrainState(state.country, id, nouvelEtat).catch(() => {});

  const dateTxt = new Date(nouvelleDateAchat).toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'long' });
  updateUI();
  addJournalEntry('Rendez-vous accéléré par corruption (-' + cout + ' ' + cur + '). Nouveau rendez-vous : ' + dateTxt + '.', 'event-info');
  showToast('Délai réduit', 'Nouveau rendez-vous : ' + dateTxt + '.', true);
}

function initSimulation() {"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Accélération par corruption du rendez-vous notarial créée.")
