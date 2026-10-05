#!/usr/bin/env python3
PATH = "plateau-personnage.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """async function confirmerDestructionPersonnage() {"""
new = """async function doDemanderDivorce() {
  const nom = state.char?.name;
  if (typeof sbGetMariageActif !== 'function') return;

  const mariage = await sbGetMariageActif(nom);
  if (!mariage) {
    showToast('Non marié(e)', "Vous n'êtes pas marié(e) actuellement.", false);
    return;
  }
  const conjoint = mariage.conjoint1 === nom ? mariage.conjoint2 : mariage.conjoint1;

  if (typeof sbDissoudreMariage === 'function') {
    await sbDissoudreMariage(mariage.id, 'divorce').catch(() => {});
  }

  updateUI();
  showToast('Divorce prononcé', 'Vous êtes désormais divorcé(e) de ' + conjoint + '.', true, true);
  addJournalEntry('💔 Divorce prononcé avec ' + conjoint + '.', 'event-info');
  if (typeof addExternalEvent === 'function') {
    addExternalEvent('💔 ' + nom + ' et ' + conjoint + ' ont divorcé.', 'local');
  }

  if (typeof sbSendMail === 'function') {
    const h = String(state.hour || 8).padStart(2, '0');
    const time = 'Jour ' + (state.day || 1) + ' · ' + h + 'h';
    sbSendMail(nom, conjoint, 'Divorce', nom + ' a demandé le divorce devant notaire. Votre mariage est désormais dissous.', time).catch(() => {});
  }
}

async function confirmerDestructionPersonnage() {"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Fonction doDemanderDivorce créée.")
