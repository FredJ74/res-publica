#!/usr/bin/env python3
PATH = "plateau-pnj.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  // Terrain verrouille pour les autres joueurs tant qu'un compromis est actif (non expire)
  const compromisActif = ts.compromis && ts.compromisExpireAt && Date.now() < ts.compromisExpireAt;
  if (compromisActif && ts.compromisPar !== state.char?.name) {
    if (fn === 'acheter_terrain' || fn === 'signer_compromis') {
      return { ok: false, raison: 'Un compromis de vente est déjà en cours sur ce terrain (détenu par ' + ts.compromisPar + ').' };
    }
  }

  return { ok: true };
}"""
new = """  // Terrain verrouille pour les autres joueurs tant qu'un compromis est actif (non expire)
  const compromisActif = ts.compromis && ts.compromisExpireAt && Date.now() < ts.compromisExpireAt;
  if (compromisActif && ts.compromisPar !== state.char?.name) {
    if (fn === 'acheter_terrain' || fn === 'signer_compromis') {
      return { ok: false, raison: 'Un compromis de vente est déjà en cours sur ce terrain (détenu par ' + ts.compromisPar + ').' };
    }
  }

  // Terrain verrouille pour les autres joueurs tant qu'un achat direct est en attente de
  // rendez-vous notarial (meme principe que le compromis)
  const achatDirectActif = ts.achatDirect && ts.achatDirect.dateLimite && Date.now() < ts.achatDirect.dateLimite;
  if (achatDirectActif && ts.achatDirect.demandeur !== state.char?.name) {
    if (fn === 'acheter_terrain' || fn === 'signer_compromis') {
      return { ok: false, raison: 'Un rendez-vous notarial est déjà en cours sur ce terrain (' + ts.achatDirect.demandeur + ').' };
    }
  }

  return { ok: true };
}"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Verrouillage du terrain étendu à l'achat direct en attente.")
