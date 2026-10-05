#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Correctif escort 2/2 :
- data.js : le bar a maintenant 2 escorts (Natacha F / Julien H), agence Roxane Velours
- plateau-pnj.js : bouton "Recruter comme escort" transmet le genre, nouveau bouton
  "Faire l'amour" (300 FR, +15 Moral +5 Sante +2 ENT, recit IA flatteur avec doute,
  trace pour les rumeurs vraies doublee si marie(e))
- plateau-actions-illegales-rumeurs.js : formulation de rumeur pour nuit_escort
"""
import sys

def apply_patch(path, old, new, label):
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    count = content.count(old)
    if count == 0:
        print(f"[ECHEC] {label} : ancre introuvable dans {path}")
        return False
    if count > 1:
        print(f"[ECHEC] {label} : ancre trouvee {count} fois dans {path} (doit etre unique)")
        return False
    content = content.replace(old, new, 1)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"[OK] {label}")
    return True

ok = True

# ------------------------------------------------------------------
# 1) data.js -- deux escorts au bar
# ------------------------------------------------------------------
old_data = """        persons: [
          {name:'Marco (Barman)', role:'PNJ - Barman', rel:'neutral', job:'barman', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/marco-barman.png', photoPos:'50% 20%'},
          {name:'Roxane Velours (PNJ)', role:'Escort de luxe', rel:'neutral', job:'escort'},
          {name:'Un lobbyiste',   role:'Inconnu - Discretion de mise', rel:'neutral', job:null}
        ],"""
new_data = """        persons: [
          {name:'Marco (Barman)', role:'PNJ - Barman', rel:'neutral', job:'barman', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/marco-barman.png', photoPos:'50% 20%'},
          {name:'Natacha (PNJ)', role:'Escort — Agence Roxane Velours', rel:'neutral', job:'escort', genre:'F'},
          {name:'Julien (PNJ)', role:'Escort — Agence Roxane Velours', rel:'neutral', job:'escort', genre:'H'},
          {name:'Un lobbyiste',   role:'Inconnu - Discretion de mise', rel:'neutral', job:null}
        ],"""
ok &= apply_patch('data.js', old_data, new_data, "data.js - bar : deux escorts (Natacha/Julien, Agence Roxane Velours)")

# ------------------------------------------------------------------
# 2) plateau-pnj.js -- bouton (genre + Faire l'amour)
# ------------------------------------------------------------------
old_btn = """  // Recruter escort
  if (pnj.job === 'escort') {
    const escortNom = pnj.name.replace(' (PNJ)', '').replace(/'/g, '');
    actionBtns += '<button class="pnj-action-btn" onclick="ouvrirRecrutementEscort(\\'' + escortNom + '\\')"><i class="ti ti-heart" style="font-size:.85rem"></i> Recruter comme escort</button>';
    actionBtns += '<button class="pnj-action-btn" onclick="ouvrirModalFabriquerKompromat(\\'' + escortNom + '\\')"><i class="ti ti-file-shredder" style="font-size:.85rem"></i> Fabriquer un kompromat (300 FR)</button>';
  }"""
new_btn = """  // Recruter escort
  if (pnj.job === 'escort') {
    const escortNom = pnj.name.replace(' (PNJ)', '').replace(/'/g, '');
    const escortGenre = pnj.genre || 'F';
    actionBtns += '<button class="pnj-action-btn" onclick="ouvrirRecrutementEscort(\\'' + escortNom + '\\',\\'' + escortGenre + '\\')"><i class="ti ti-heart" style="font-size:.85rem"></i> Recruter comme escort</button>';
    actionBtns += '<button class="pnj-action-btn" onclick="ouvrirModalFabriquerKompromat(\\'' + escortNom + '\\')"><i class="ti ti-file-shredder" style="font-size:.85rem"></i> Fabriquer un kompromat (300 FR)</button>';
    actionBtns += '<button class="pnj-action-btn" style="color:#cc6699;border-color:#4a1a30" onclick="ouvrirModalFaireLAmour(\\'' + escortNom + '\\')"><i class="ti ti-heart-filled" style="font-size:.85rem"></i> Faire l\\'amour (300 FR)</button>';
  }"""
ok &= apply_patch('plateau-pnj.js', old_btn, new_btn, "plateau-pnj.js - bouton escort (genre + Faire l'amour)")

# ------------------------------------------------------------------
# 3) plateau-pnj.js -- fonctions Faire l'amour
# ------------------------------------------------------------------
old_fn = """function doEscortPiege() {"""
new_fn = """function ouvrirModalFaireLAmour(nomEscort) {
  const co = COUNTRIES[state.country];
  const cur = co?.cur || 'FR';
  const cost = 300;
  if (state.arg < cost) { showToast('Fonds insuffisants', cost + ' ' + cur + ' requis.', false); return; }

  document.getElementById('postes-modal-title').textContent = '💗 Un moment avec ' + nomEscort;
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:1rem">' +
    '<div style="font-size:.82rem;color:#a09060;margin-bottom:1rem">Coût : ' + cost + ' ' + cur + '. Gain immédiat : +15 Moral, +5 Santé, +2 ENT.</div>' +
    '<button onclick="confirmerFaireLAmour(\\'' + nomEscort.replace(/'/g,'') + '\\')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem;border:1px solid #cc6699;background:transparent;color:#cc6699;cursor:pointer">Confirmer</button>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerFaireLAmour(nomEscort) {
  document.getElementById('modal-postes').classList.remove('open');
  const co = COUNTRIES[state.country];
  const cur = co?.cur || 'FR';
  const cost = 300;
  if (state.arg < cost) { showToast('Fonds insuffisants', cost + ' ' + cur + ' requis.', false); return; }
  state.arg -= cost;

  state.moral = Math.min(100, (state.moral || 0) + 15);
  state.hp = Math.min(100, (state.hp || 0) + 5);
  if (state.char?.stats) state.char.stats.ENT = (state.char.stats.ENT || 0) + 2;

  const prompt = `Tu es le narrateur de Res Publica, jeu politique parodique et satirique. Le joueur vient de passer un moment intime avec ${nomEscort}, une escort de l'Agence Roxane Velours. Rédige UN court récit (2-3 phrases max) qui flatte et valorise le joueur, lui donnant un sentiment de plénitude et de supériorité — mais glisse à la toute fin un doute subtil sur l'authenticité du plaisir ressenti par l'escort (professionnelle avant tout). Ton élégant, un peu ironique, jamais vulgaire ni explicite. Réponds en texte brut uniquement, sans markdown (pas de #, pas de **).`;

  let recit = 'Vous passez un moment agréable avec ' + nomEscort + '.';
  try {
    const resp = await fetch('/api/chat', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({ model: 'claude-haiku-4-5-20251001', max_tokens: 150, messages: [{ role: 'user', content: prompt }] })
    });
    const data = await resp.json();
    recit = data.content?.[0]?.text?.trim() || recit;
  } catch(e) {}

  updateUI();
  document.getElementById('postes-modal-title').textContent = '💗 ' + nomEscort;
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:1.2rem">' +
    '<div style="font-size:.85rem;color:#c0b090;font-style:italic;line-height:1.7;font-family:Crimson Pro,serif">' + recit + '</div>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');

  addJournalEntry('Moment privé avec ' + nomEscort + '. +15 Moral, +5 Santé, +2 ENT. -' + cost + ' ' + cur + '.', 'event-good');

  if (typeof tracerActionPourRumeur === 'function') {
    tracerActionPourRumeur('nuit_escort', null);
    try {
      if (typeof sbGetMariageActif === 'function') {
        const mariage = await sbGetMariageActif(state.char?.name);
        if (mariage) tracerActionPourRumeur('nuit_escort', null);
      }
    } catch(e) {}
  }
}

function doEscortPiege() {"""
ok &= apply_patch('plateau-pnj.js', old_fn, new_fn, "plateau-pnj.js - ouvrirModalFaireLAmour + confirmerFaireLAmour")

# ------------------------------------------------------------------
# 4) plateau-actions-illegales-rumeurs.js -- formulation
# ------------------------------------------------------------------
old_form = """  boire_verre_refuse:     (a, c) => a + ' aurait tenté d\\'offrir un verre à ' + c + ', qui a décliné sans un mot.'
};"""
new_form = """  boire_verre_refuse:     (a, c) => a + ' aurait tenté d\\'offrir un verre à ' + c + ', qui a décliné sans un mot.',
  nuit_escort:            (a, c) => 'Des mauvaises langues jurent avoir vu ' + a + ' quitter discrètement une chambre en compagnie d\\'une professionnelle de l\\'Agence Roxane Velours.'
};"""
ok &= apply_patch('plateau-actions-illegales-rumeurs.js', old_form, new_form, "plateau-actions-illegales-rumeurs.js - formulation nuit_escort")

print()
if ok:
    print("TOUT EST OK.")
else:
    print("ECHEC. Ne rien committer, colle le detail a Claude.")
    sys.exit(1)
