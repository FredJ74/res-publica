#!/usr/bin/env python3
PATH = "plateau-personnage.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """    html += '<button onclick="doOrder(\\'organiser_blocus\\',3,0,\\'Organiser un blocus\\',\\'Le groupe bloque l\\\\\\'acces.\\','+tauxBlocus+');closeSelfView()" style="display:flex;justify-content:space-between;align-items:center;padding:.5rem .8rem;border:1px solid #3a1a1a;background:#0d0808;color:#9a6a4a;cursor:pointer;font-family:Crimson Pro,serif;font-size:.82rem">';
    html += '<span><i class="ti ti-ban" style="font-size:.85rem"></i> Organiser un blocus</span><span style="font-family:Bebas Neue,sans-serif;font-size:.68rem;color:#6a3a20">' + tauxBlocus + '% · 1 PA · groupe:' + groupSize + '</span></button>';"""

new = """    html += '<button onclick="doOrder(\\'organiser_blocus\\',3,0,\\'Organiser un blocus\\',\\'Le groupe bloque l\\\\\\'acces.\\','+tauxBlocus+');closeSelfView()" style="display:flex;justify-content:space-between;align-items:center;padding:.5rem .8rem;border:1px solid #3a1a1a;background:#0d0808;color:#9a6a4a;cursor:pointer;font-family:Crimson Pro,serif;font-size:.82rem">';
    html += '<span><i class="ti ti-ban" style="font-size:.85rem"></i> Organiser un blocus</span><span style="font-family:Bebas Neue,sans-serif;font-size:.68rem;color:#6a3a20">' + tauxBlocus + '% · 1 PA · groupe:' + groupSize + '</span></button>';

    // Blocus syndical reel — reserve au Secretaire General / Adjoint (voir
    // getMonSyndicatEtGrade, plateau-organisations-quetes.js). Contrairement au blocus
    // generique ci-dessus (roleplay leger), celui-ci bloque reellement les ordres du
    // batiment ou l'on se trouve.
    if (typeof getMonSyndicatEtGrade === 'function') {
      const infosSyndicat = getMonSyndicatEtGrade();
      if (infosSyndicat && infosSyndicat.gradeIdx >= 1 && infosSyndicat.gradeIdx <= 2) {
        html += '<button onclick="closeSelfView();doOrganiserBlocusSyndical()" style="display:flex;justify-content:space-between;align-items:center;padding:.5rem .8rem;border:1px solid #3a2a1a;background:#0d0a08;color:#C9A84C;cursor:pointer;font-family:Crimson Pro,serif;font-size:.82rem">';
        html += '<span><i class="ti ti-flag" style="font-size:.85rem"></i> Organiser un blocus syndical (ici)</span></button>';
        html += '<button onclick="closeSelfView();doRenouvelerBlocusSyndical()" style="display:flex;justify-content:space-between;align-items:center;padding:.5rem .8rem;border:1px solid #3a2a1a;background:#0d0a08;color:#C9A84C;cursor:pointer;font-family:Crimson Pro,serif;font-size:.82rem">';
        html += '<span><i class="ti ti-refresh" style="font-size:.85rem"></i> Renouveler le blocus syndical (ici)</span></button>';
      }
    }"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Boutons du blocus syndical ajoutés à la fiche personnage.")
