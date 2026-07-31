#!/usr/bin/env python3
PATH = "plateau-pnj.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """      </div>`;
    return;
  }

  // Actions predefinies
  const actionMap = {"""
new = """      </div>`;
    return;
  }

  // Quete d'accueil : reponse scriptee du Secretaire Municipal Petit quand un nouveau joueur se presente.
  // Reponse fixe (pas d'IA) pour garantir la progression de la quete a ce moment charniere.
  if (pnj.name === 'Secretaire Municipal Petit'
      && typeof state !== 'undefined' && state.char && state.char.queteAccueil
      && state.char.queteAccueil.etape === 'attente_entree_mairie'
      && /nouveau|nouvelle|nouvellement/i.test(action)) {
    speech.textContent = "Ah, un petit nouveau ! Vous allez avoir besoin d'aide pour découvrir la ville, j'imagine. Ça tombe bien, on a un jeune stagiaire ici qu'on ne sait pas comment occuper. En plus il ne sait pas faire un bon café, mais par contre, il est de la ville. En fait... (en parlant tout bas) c'est le neveu du Maire, on n'a pas eu d'autre choix que de le prendre... Jérémy ! Viens par ici, on a une mission pour toi ! Tu vas accompagner " + (state.char.name || 'vous') + " dans la ville. (se tournant vers vous) Enfin si vous êtes d'accord bien sûr. Vous voulez l'aide de Jérémy ?";
    document.getElementById('pnj-actions').innerHTML = `
      <div style="margin-top:.8rem;border-top:1px solid #2a2010;padding-top:.8rem">
        <button class="pnj-action-btn" onclick="closePnjModal(); queteAccueilAccepterJeremy();">
          <i class="ti ti-check" style="font-size:.85rem"></i> Oui, j'accepte l'aide de Jérémy
        </button>
        <button class="pnj-action-btn" onclick="closePnjModal(); queteAccueilRefuserJeremy();">
          <i class="ti ti-x" style="font-size:.85rem"></i> Non merci
        </button>
      </div>`;
    return;
  }

  // Actions predefinies
  const actionMap = {"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Détection 'je suis nouveau' ajoutée pour Petit.")
