#!/usr/bin/env python3
PATH = "forum.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """function submitMail() {
  // Prendre toujours le dernier élément en cas de doublons dans le DOM
  const toEls = document.querySelectorAll('#mail-to');
  const subjectEls = document.querySelectorAll('#mail-subject');
  const bodyEls = document.querySelectorAll('#compose-body');
  const to = toEls[toEls.length - 1]?.value?.trim();
  const subject = subjectEls[subjectEls.length - 1]?.value?.trim();
  const bodyEl = bodyEls[bodyEls.length - 1];
  const body = bodyEl?.innerHTML?.trim();
  const bodyText = bodyEl?.innerText?.trim();
  if (!to || !subject || !bodyText) { showToast('Champs requis','Remplissez tous les champs.',false); return; }
  sendMail(to, subject, body);
  mailFromOverride = null;
  mailDefaultTo = '';
  mailView = 'inbox';
  renderForumModal();
}"""
new = """let _mailEnvoiEnCours = false;
function submitMail() {
  // Verrou anti-double-envoi : quelle que soit la cause (double-clic, doublon DOM du
  // formulaire), on ignore tout appel suivant tant que le premier n'est pas termine.
  if (_mailEnvoiEnCours) return;
  _mailEnvoiEnCours = true;

  // Prendre toujours le dernier élément en cas de doublons dans le DOM
  const toEls = document.querySelectorAll('#mail-to');
  const subjectEls = document.querySelectorAll('#mail-subject');
  const bodyEls = document.querySelectorAll('#compose-body');
  const to = toEls[toEls.length - 1]?.value?.trim();
  const subject = subjectEls[subjectEls.length - 1]?.value?.trim();
  const bodyEl = bodyEls[bodyEls.length - 1];
  const body = bodyEl?.innerHTML?.trim();
  const bodyText = bodyEl?.innerText?.trim();
  if (!to || !subject || !bodyText) {
    showToast('Champs requis','Remplissez tous les champs.',false);
    _mailEnvoiEnCours = false;
    return;
  }
  sendMail(to, subject, body);
  mailFromOverride = null;
  mailDefaultTo = '';
  mailView = 'inbox';
  renderForumModal();
  setTimeout(function() { _mailEnvoiEnCours = false; }, 1500);
}"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Verrou anti-double-envoi ajouté sur submitMail.")
