#!/usr/bin/env python3
PATH = "plateau-enigme-portrait.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """function enigme1AfficherPopupCadreVide(roomId) {"""
new = """// =====================
// ARCHIVES DE PRESSE (L'AUTRUCHE ENTRAVEE) — articles d'Etienne Tintabin
// =====================

const ENIGME1_ARCHIVES_PRESSE = [
  {
    titre: "Un nouvel élan industriel pour Luthécia",
    auteur: 'Étienne Tintabin',
    annee: 1948,
    texte: "L'installation de la nouvelle usine de M. Jacques Moulin sur d'anciens terrains agricoles récemment aménagés, à l'est de la ville, marque un tournant pour l'emploi local. L'usine produira des frites surgelées, à partir de pommes de terre importées de Sovarka via le port industriel de Port-Sainte-Marie. Une trentaine de postes seront créés dès l'ouverture. Un beau succès pour le maire Marcel Torcieu, malgré l'opposition farouche du conseiller municipal Gaston Blanaz. Luthécia entre enfin dans l'ère moderne."
  },
  {
    titre: "L'affaire Caillon : un doute raisonnable ?",
    auteur: 'Étienne Tintabin',
    annee: 1949,
    texte: "Les éléments retenus contre M. Maurice Caillon, gardien du site industriel, apparaissent aujourd'hui bien minces. La victime, Gaston Blanaz, s'était fait de nombreux ennemis dans la commune — autant de suspects potentiels que M. Caillon. Rien ne prouve formellement sa présence sur les lieux au moment des faits. La justice, si elle veut rester juste, se doit d'examiner ce dossier avec la plus grande prudence."
  }
];

function doConsulterArchivesPresse() {
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.85rem;color:#8a8060;margin-bottom:.8rem">Articles archivés de L\\'Autruche Entravée.</div>';
  html += '<div style="display:flex;flex-direction:column;gap:.4rem">';
  ENIGME1_ARCHIVES_PRESSE.forEach(function(a, i) {
    html += '<div onclick="enigme1AfficherArticlePresse(' + i + ')" style="cursor:pointer;padding:.6rem;border:1px solid #2a2010;background:#0f0d05">';
    html += '<div style="display:flex;justify-content:space-between"><span style="font-family:Playfair Display,serif;font-size:.85rem;color:#c0b090">' + a.titre + '</span><span style="font-size:.7rem;color:#5a4030">' + a.annee + '</span></div>';
    html += '<div style="font-size:.72rem;color:#6a5a30">Par ' + a.auteur + '</div>';
    html += '</div>';
  });
  html += '</div>';
  html += '</div>';

  document.getElementById('postes-modal-title').textContent = "Archives de L'Autruche Entravée";
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function enigme1AfficherArticlePresse(idx) {
  const a = ENIGME1_ARCHIVES_PRESSE[idx];
  if (!a) return;

  let html = '<div style="padding:1.2rem">';
  html += '<div style="font-size:1rem;color:#C9A84C;font-family:Playfair Display,serif;font-style:italic;margin-bottom:.2rem">« ' + a.titre + ' »</div>';
  html += '<div style="font-size:.82rem;color:#8a8060;margin-bottom:.8rem">Par ' + a.auteur + ' — ' + a.annee + '</div>';
  html += '<div style="font-size:.85rem;color:#e0d8c0;line-height:1.6">' + a.texte + '</div>';
  html += '<button class="pnj-action-btn" onclick="doConsulterArchivesPresse()" style="margin-top:1rem;opacity:.8"><i class="ti ti-arrow-left" style="font-size:.85rem"></i> Retour</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;

  if (typeof enigme1DossierCocherCase === 'function') enigme1DossierCocherCase('presse');
}

function enigme1AfficherPopupCadreVide(roomId) {"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Archives de presse créées : les deux articles de Tintabin.")
