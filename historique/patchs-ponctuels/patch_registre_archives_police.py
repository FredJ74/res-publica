#!/usr/bin/env python3
PATH = "plateau-communication.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """async function doArchivesPolice() {
  document.getElementById('postes-modal-title').textContent = 'Archives de Police';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  let detentions = [];
  if (typeof sbLoadDetentions === 'function') {
    try {
      detentions = await sbLoadDetentions(state.country) || [];
    } catch(e) {}
  }
  state._detentionsAffichees = detentions;

  let html = '<div style="padding:1rem">';
  if (detentions.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucune detention enregistree pour le moment.</div>';
  } else {
    detentions.forEach((d, i) => {
      html += '<div onclick="ouvrirDetailDetention(' + i + ')" style="padding:.6rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem;cursor:pointer">';
      html += '<div style="display:flex;justify-content:space-between">';
      html += '<div style="font-family:Playfair Display,serif;font-size:.82rem;color:#c0b090">' + d.nom + (d.qhs ? ' <span style="color:#8a3a2a">(QHS)</span>' : '') + '</div>';
      html += '<div style="font-size:.7rem;color:#5a4030">Jour ' + d.jour_debut + '</div>';
      html += '</div>';
      html += '<div style="font-size:.72rem;color:#6a5a30">' + d.raison + (d.jour_fin ? ' (fin prevue Jour ' + d.jour_fin + ')' : '') + '</div>';
      html += '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}"""

new = """// Registre unique des archives de police : fusionne les vraies detentions de PJ (en direct,
// depuis Supabase) et les affaires historiques anterieures au lancement du jeu (definies en
// code, extensibles). Recherche par nom (les deux sources) ou par decennie (les deux sources,
// grace au champ created_at desormais fiable sur les vraies detentions).
const ENIGME1_ARCHIVES_HISTORIQUES = [
  {
    nom: 'Maurice Caillon',
    anneeDebut: 1948,
    anneeFin: 1949,
    motif: "Assassinat d'un conseiller municipal, opposant déclaré au projet industriel sur la parcelle B-127. Le corps de la victime a été découvert enterré sur le site, alors en construction pour le compte de l'entrepreneur Jacques Moulin. Caillon résidait sur place, dans la maison de gardien du site industriel.",
    issue: 'Acquitté en appel en 1949.'
  }
];

async function doArchivesPolice() {
  document.getElementById('postes-modal-title').textContent = 'Archives de Police';
  document.getElementById('postes-body').innerHTML = enigme1HtmlRechercheArchivesPolice();
  document.getElementById('modal-postes').classList.add('open');

  if (typeof sbLoadDetentions === 'function') {
    try {
      state._detentionsReelles = await sbLoadDetentions(state.country) || [];
    } catch(e) { state._detentionsReelles = []; }
  } else {
    state._detentionsReelles = [];
  }
}

function enigme1HtmlRechercheArchivesPolice() {
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.85rem;color:#8a8060;margin-bottom:.8rem">Recherchez par nom ou par décennie (arrestations passées, en cours, et affaires historiques).</div>';
  html += '<div style="display:flex;gap:.4rem;margin-bottom:.4rem">';
  html += '<input id="archives-police-nom" type="text" placeholder="Nom..." style="flex:1;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem .6rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none" />';
  html += '<input id="archives-police-decennie" type="text" placeholder="Décennie (ex: 1940)" style="width:150px;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem .6rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none" />';
  html += '</div>';
  html += '<button class="pnj-action-btn" onclick="enigme1LancerRechercheArchivesPolice()"><i class="ti ti-search" style="font-size:.85rem"></i> Rechercher</button>';
  html += '<div id="archives-police-resultats" style="margin-top:.9rem"></div>';
  html += '</div>';
  return html;
}

function enigme1LancerRechercheArchivesPolice() {
  const nomInput = document.getElementById('archives-police-nom');
  const decennieInput = document.getElementById('archives-police-decennie');
  const nom = nomInput ? nomInput.value : '';
  const decennie = decennieInput ? decennieInput.value : '';
  const resultatsEl = document.getElementById('archives-police-resultats');
  if (!resultatsEl) return;

  if (!nom.trim() && !decennie.trim()) {
    resultatsEl.innerHTML = '<div style="font-size:.8rem;color:#8a3a20;font-style:italic">Indiquez au moins un nom ou une décennie.</div>';
    return;
  }

  const nomLower = nom.trim().toLowerCase();
  const decDebut = decennie.trim() ? parseInt(decennie.trim(), 10) : null;
  const decFin = decDebut !== null ? decDebut + 9 : null;

  const historiques = ENIGME1_ARCHIVES_HISTORIQUES.filter(function(a) {
    if (nomLower && a.nom.toLowerCase().indexOf(nomLower) === -1) return false;
    if (decDebut !== null) {
      const chevauche = a.anneeFin >= decDebut && a.anneeDebut <= decFin;
      if (!chevauche) return false;
    }
    return true;
  });

  const reels = (state._detentionsReelles || []).filter(function(d) {
    if (nomLower && d.nom.toLowerCase().indexOf(nomLower) === -1) return false;
    if (decDebut !== null) {
      if (!d.created_at) return false;
      const annee = new Date(d.created_at).getFullYear();
      if (annee < decDebut || annee > decFin) return false;
    }
    return true;
  });

  if (historiques.length === 0 && reels.length === 0) {
    resultatsEl.innerHTML = '<div style="font-size:.8rem;color:#8a3a20;font-style:italic">Aucun résultat.</div>';
    return;
  }

  let html = '<div style="display:flex;flex-direction:column;gap:.4rem">';
  historiques.forEach(function(a) {
    const nomEchap = a.nom.replace(/'/g, "\\'");
    html += '<div onclick="enigme1AfficherArchiveHistorique(\\'' + nomEchap + '\\')" style="cursor:pointer;padding:.6rem;border:1px solid #2a2010;background:#0f0d05">';
    html += '<div style="display:flex;justify-content:space-between"><span style="font-family:Playfair Display,serif;font-size:.82rem;color:#c0b090">' + a.nom + '</span><span style="font-size:.7rem;color:#5a4030">' + a.anneeDebut + '–' + a.anneeFin + '</span></div>';
    html += '<div style="font-size:.72rem;color:#6a5a30">Affaire historique</div>';
    html += '</div>';
  });
  reels.forEach(function(d, i) {
    const annee = d.created_at ? new Date(d.created_at).getFullYear() : '?';
    const duree = (d.jour_fin && d.jour_debut) ? (d.jour_fin - d.jour_debut) + ' jour(s)' : 'en cours';
    html += '<div onclick="ouvrirDetailDetention(' + i + ')" style="cursor:pointer;padding:.6rem;border:1px solid #2a2010;background:#0f0d05">';
    html += '<div style="display:flex;justify-content:space-between"><span style="font-family:Playfair Display,serif;font-size:.82rem;color:#c0b090">' + d.nom + (d.qhs ? ' <span style="color:#8a3a2a">(QHS)</span>' : '') + '</span><span style="font-size:.7rem;color:#5a4030">' + annee + ' · ' + duree + '</span></div>';
    html += '<div style="font-size:.72rem;color:#6a5a30">' + d.raison + '</div>';
    html += '</div>';
  });
  html += '</div>';
  resultatsEl.innerHTML = html;
}

function enigme1AfficherArchiveHistorique(nom) {
  const a = ENIGME1_ARCHIVES_HISTORIQUES.find(function(x) { return x.nom === nom; });
  if (!a) return;

  let html = '<div style="padding:1.2rem">';
  html += '<div style="font-size:1rem;color:#C9A84C;font-family:Bebas Neue,sans-serif;letter-spacing:.05em;margin-bottom:.2rem">' + a.nom + '</div>';
  html += '<div style="font-size:.82rem;color:#8a8060;margin-bottom:.8rem">Arrêté en ' + a.anneeDebut + '</div>';
  html += '<div style="font-size:.85rem;color:#e0d8c0;line-height:1.5;margin-bottom:.6rem">' + a.motif + '</div>';
  html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">' + a.issue + '</div>';
  html += '<button class="pnj-action-btn" onclick="doArchivesPolice()" style="margin-top:1rem;opacity:.8"><i class="ti ti-arrow-left" style="font-size:.85rem"></i> Nouvelle recherche</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;

  if (a.nom === 'Maurice Caillon' && typeof enigme1DossierCocherCase === 'function') {
    enigme1DossierCocherCase('commissariat');
  }
}"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Registre unique des archives de police créé (recherche par nom et décennie, historique + temps réel).")
