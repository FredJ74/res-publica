#!/usr/bin/env python3
PATH = "plateau-quete-accueil.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  let reply = "Eh bien... intéressant ! Je suis sûr que vous trouverez votre voie en ville.";
  try {
    const resp = await fetch('/api/chat', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ model: 'claude-sonnet-4-20250514', max_tokens: 300, messages: [{ role: 'user', content: prompt }] })
    });
    const data = await resp.json();
    if (data.content && data.content[0] && data.content[0].text) reply = data.content[0].text;
  } catch (e) { /* on garde la reponse de secours */ }

  if (texteEl) texteEl.textContent = reply;"""

new = """  // Reponse de secours si l'IA est indisponible : conseil concret par archetype, pas un
  // texte generique creux. Base sur QUETE_ACCUEIL_CONSEILS_ARCHETYPE (voir plus haut).
  const archetypeJoueur = state.char && state.char.archetype;
  let reply = QUETE_ACCUEIL_CONSEILS_ARCHETYPE[archetypeJoueur] || QUETE_ACCUEIL_CONSEIL_DEFAUT;
  let appelReussi = false;
  try {
    const resp = await fetch('/api/chat', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ model: 'claude-sonnet-4-20250514', max_tokens: 300, messages: [{ role: 'user', content: prompt }] })
    });
    const data = await resp.json();
    if (data.content && data.content[0] && data.content[0].text) {
      reply = data.content[0].text;
      appelReussi = true;
    }
  } catch (e) { /* on garde la reponse de secours par archetype */ }

  // Dans tous les cas (IA ou secours), on oriente vers le Musee de la Ville pour approfondir.
  reply += " Si vous voulez en savoir plus sur ce genre de carrière, faites donc un tour au Musée de la Ville — il y a plein d'informations utiles là-bas.";

  if (texteEl) texteEl.textContent = reply;"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Conseil de secours par archétype + mention du Musée de la Ville ajoutés.")
