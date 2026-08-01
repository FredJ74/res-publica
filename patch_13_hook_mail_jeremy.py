#!/usr/bin/env python3
PATH = "forum.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  addJournalEntry(`Mail envoyé à ${to} : "${subject}".`, 'event-info');
  showToast('Mail envoyé', `À ${to} — "${subject}"`, true);
}"""
new = """  addJournalEntry(`Mail envoyé à ${to} : "${subject}".`, 'event-info');
  showToast('Mail envoyé', `À ${to} — "${subject}"`, true);

  if (to === 'Jérémy' && typeof queteAccueilGenererReponseMailJeremy === 'function') {
    queteAccueilGenererReponseMailJeremy(subject, body);
  }
}"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Hook ajouté dans sendMail pour détecter les mails envoyés à Jérémy.")
