#!/usr/bin/env python3
PATH = "plateau-quete-accueil.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  if (typeof sbSendMail === 'function') {
    sbSendMail('Jérémy', state.char.name, sujetReponse, reply, heure).catch(function() {});
  }
  if (typeof getMails === 'function' && typeof saveMails === 'function') {
    const mails = getMails();
    mails.push({ id: 'mail-' + Date.now(), from: 'Jérémy', to: state.char.name, subject: sujetReponse, body: reply, time: heure, read: false });
    saveMails(mails);
  }
  if (typeof showToast === 'function') showToast('Nouveau mail', 'Jérémy vous a répondu !', true);"""
new = """  // Fix : le mail etait envoye deux fois, via deux systemes differents (sbSendMail — le
  // vrai systeme Supabase — ET un ancien systeme local getMails/saveMails, visiblement un
  // reliquat d'avant la migration, jamais retire). Bug remonte par l'audit ChatGPT du 5 aout
  // 2026 ("corriger le double envoi du courrier").
  if (typeof sbSendMail === 'function') {
    sbSendMail('Jérémy', state.char.name, sujetReponse, reply, heure).catch(function() {});
  }
  if (typeof showToast === 'function') showToast('Nouveau mail', 'Jérémy vous a répondu !', true);"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Double envoi de mail corrigé : seul sbSendMail (le vrai système) est conservé.")
