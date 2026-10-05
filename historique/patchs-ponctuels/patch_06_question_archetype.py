#!/usr/bin/env python3
PATH = "plateau-quete-accueil.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """function afficherConseilArchetypeJeremy() {
  const archetype = state.char && state.char.archetype;
  const conseil = QUETE_ACCUEIL_CONSEILS_ARCHETYPE[archetype] || QUETE_ACCUEIL_CONSEIL_DEFAUT;
  afficherPopupQueteAccueil({
    image: QUETE_ACCUEIL_IMAGES.jeremy,
    titre: 'Jérémy',
    texte: conseil,
    suivant: function() {
      afficherPopupQueteAccueil({
        image: QUETE_ACCUEIL_IMAGES.jeremy,
        titre: 'Jérémy',
        texte: "Je vous laisse découvrir. Si vous avez des questions pendant la visite, n'hésitez pas à me les poser.",
        suivant: queteAccueilArmerMinuteurStade
      });
    }
  });
}"""

new = """// Remplace l'ancien systeme de conseil fixe par archetype : Jeremy pose desormais une
// question ouverte, et une IA reagit a la reponse libre du joueur (loufoque, vague ou
// determinee), en orientant vers les organisations pertinentes si la reponse s'y prete.
function afficherConseilArchetypeJeremy() {
  afficherPopupQueteAccueil({
    image: QUETE_ACCUEIL_IMAGES.jeremy,
    titre: 'Jérémy',
    texte: "Sans indiscrétion, vous voulez devenir quoi dans cette ville ?<br><br>Vous pouvez me parler franchement, ça restera entre nous.<br><br>Alors quoi ? Politicien ? Militaire ? Criminel ? Religieux ? Autre chose ?",
    suivant: null,
    actionsHtml:
      '<div style="display:flex;gap:.4rem;margin-top:.4rem">' +
      '<input id="quete-accueil-reponse-archetype" type="text" style="flex:1;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem .6rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none" placeholder="Votre réponse..." onkeydown="if(event.key===\\'Enter\\') queteAccueilEnvoyerReponseArchetype();" />' +
      '<button class="pnj-action-btn" onclick="queteAccueilEnvoyerReponseArchetype()"><i class="ti ti-send" style="font-size:.85rem"></i></button>' +
      '</div>'
  });
}

async function queteAccueilEnvoyerReponseArchetype() {
  const input = document.getElementById('quete-accueil-reponse-archetype');
  const reponse = (input && input.value ? input.value : '').trim();
  if (!reponse) return;

  const texteEl = document.getElementById('quete-accueil-texte');
  const actionsEl = document.getElementById('quete-accueil-actions');
  if (texteEl) texteEl.innerHTML = '<span style="font-style:italic;color:#9a8a68">Jérémy réfléchit...</span>';
  if (actionsEl) actionsEl.innerHTML = '';

  const prompt = "Tu es Jeremy, jeune stagiaire un peu maladroit mais serviable a l'Hotel de Ville de Luthecia, dans le jeu Res Publica (jeu de role politique parodique et satirique). Tu vouvoies toujours le joueur.\\n" +
    "Tu viens de demander au joueur ce qu'il aimerait devenir dans la ville. Il te repond : \\"" + reponse.replace(/"/g, "'") + "\\".\\n" +
    "Reagis en 2 a 3 phrases maximum, dans ton personnage (gentil, un peu naif, honnete), en restant coherent avec sa reponse meme si elle est loufoque, vague ou indecise. Si sa reponse correspond a une orientation credible (politique, militaire, criminelle, religieuse, economique, syndicale, secrete...), oriente-le vers le type d'organisation correspondant en ville. Si sa reponse est trop vague ou farfelue, reste bienveillant et rassurant, sans te moquer de lui. Ne parle jamais d'un lieu ou tu ne te trouves pas actuellement. Reponds UNIQUEMENT avec ta replique, sans guillemets ni introduction.";

  let reply = "Eh bien... intéressant ! Je suis sûr que vous trouverez votre voie en ville.";
  try {
    const resp = await fetch('/api/chat', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ model: 'claude-sonnet-4-20250514', max_tokens: 300, messages: [{ role: 'user', content: prompt }] })
    });
    const data = await resp.json();
    if (data.content && data.content[0] && data.content[0].text) reply = data.content[0].text;
  } catch (e) { /* on garde la reponse de secours */ }

  if (texteEl) texteEl.textContent = reply;

  const closeBtn = document.getElementById('quete-accueil-close');
  if (closeBtn) {
    closeBtn.onclick = function() {
      document.getElementById('modal-quete-accueil').classList.remove('open');
      afficherPopupQueteAccueil({
        image: QUETE_ACCUEIL_IMAGES.jeremy,
        titre: 'Jérémy',
        texte: "Je vous laisse découvrir. Si vous avez des questions pendant la visite, n'hésitez pas à me les poser.",
        suivant: queteAccueilArmerMinuteurStade
      });
    };
  }
}"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Question ouverte + réponse IA à l'archétype mise en place.")
