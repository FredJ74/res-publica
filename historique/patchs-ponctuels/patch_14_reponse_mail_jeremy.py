#!/usr/bin/env python3
PATH = "plateau-quete-accueil.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """function afficherPopupQueteAccueil(opts) {"""
new = """// Declenchee depuis le hook ajoute dans sendMail() (forum.js) quand le joueur ecrit a Jeremy.
// Genere une reponse IA, et fait "reapparaitre" Jeremy hors groupe au Marche : le joueur devra
// s'y rendre et cliquer sur "Rejoindre le groupe" comme pour n'importe quel employe retrouve.
async function queteAccueilGenererReponseMailJeremy(subjectRecu, bodyRecu) {
  if (typeof state === 'undefined' || !state.char) return;

  // Le fait de re-proposer Jeremy au Marche
  if (!state.employes) state.employes = [];
  const dejaLa = state.employes.find(function(e) { return e.nom === 'Jérémy'; });
  if (!dejaLa) {
    state.employes.push({
      nom: 'Jérémy',
      nomComplet: 'Jérémy (PNJ)',
      role: 'Stagiaire pistonné - Hôtel de Ville',
      job: 'stagiaire',
      photoUrl: (typeof QUETE_ACCUEIL_IMAGES !== 'undefined' && QUETE_ACCUEIL_IMAGES.jeremy) || null,
      photoPos: '50% 20%',
      inGroupe: false,
      cout: 0,
      buildingId: 'marche',
      roomId: 'marche_ext'
    });
  } else if (!dejaLa.inGroupe) {
    dejaLa.buildingId = 'marche';
    dejaLa.roomId = 'marche_ext';
  }

  const prompt = "Tu es Jeremy, jeune stagiaire un peu maladroit mais serviable de l'Hotel de Ville de Luthecia, dans le jeu Res Publica. Tu vouvoies toujours le joueur.\\n" +
    "Le joueur, que tu as guide dans la ville il y a quelque temps, vient de t'envoyer un mail. Sujet : \\"" + subjectRecu.replace(/"/g, "'") + "\\". Message : \\"" + bodyRecu.replace(/"/g, "'") + "\\".\\n" +
    "Reponds en 2 a 3 phrases, dans ton personnage, de facon coherente avec sa demande. Termine TOUJOURS ta reponse en indiquant que tu te trouves actuellement sur la Place du Marche Central de Luthecia, et que le joueur peut venir t'y retrouver puis cliquer sur \\"Rejoindre le groupe\\" pour que tu l'accompagnes de nouveau. Reponds UNIQUEMENT avec ta replique, sans guillemets ni introduction.";

  let reply = "Oh, vous avez besoin de moi ? Je suis sur la Place du Marché, venez me chercher !";
  try {
    const resp = await fetch('/api/chat', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ model: 'claude-sonnet-4-20250514', max_tokens: 300, messages: [{ role: 'user', content: prompt }] })
    });
    const data = await resp.json();
    if (data.content && data.content[0] && data.content[0].text) reply = data.content[0].text;
  } catch (e) { /* on garde la reponse de secours */ }

  const sujetReponse = 'Re: ' + subjectRecu;
  const heure = (typeof formatDateHeureJeu === 'function') ? formatDateHeureJeu() : new Date().toISOString();

  if (typeof sbSendMail === 'function') {
    sbSendMail('Jérémy', state.char.name, sujetReponse, reply, heure).catch(function() {});
  }
  if (typeof getMails === 'function' && typeof saveMails === 'function') {
    const mails = getMails();
    mails.push({ id: 'mail-' + Date.now(), from: 'Jérémy', to: state.char.name, subject: sujetReponse, body: reply, time: heure, read: false });
    saveMails(mails);
  }
  if (typeof showToast === 'function') showToast('Nouveau mail', 'Jérémy vous a répondu !', true);
}

function afficherPopupQueteAccueil(opts) {"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Réponse par mail de Jérémy + réapparition au Marché ajoutées.")
