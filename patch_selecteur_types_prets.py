#!/usr/bin/env python3
PATH = "plateau-justice-economie.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """async function ouvrirModalPretBancaire(typeBanque) {
  typeBanque = typeBanque || 'nationale';
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const taux = getTauxPret(typeBanque);
  const estPrivee = typeBanque === 'privee';

  document.getElementById('postes-modal-title').textContent = estPrivee ? 'Prêt — Banque Privée Helvetia' : 'Prêt — Banque Nationale';
  let html = '<div style="padding:1rem">';
  if (estPrivee) {
    html += '<div style="font-size:.78rem;color:#aa7a30;font-style:italic;margin-bottom:.8rem;padding:.5rem;background:#0f0d05;border:1px solid #3a2810">Aucune vérification. Discrétion garantie. En cas d\\'impayé prolongé, la méthode de recouvrement est... directe.</div>';
  }
  html += '<div style="font-size:.78rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Taux applicable : ' + taux.toFixed(1) + '% sur la durée totale du prêt.</div>';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.1em;color:#8a6a20;margin-bottom:.4rem">MONTANT EMPRUNTÉ</div>';
  html += '<input id="pret-montant" type="number" min="1000" step="1000" placeholder="Montant en ' + cur + '..." style="width:100%;padding:.4rem .6rem;background:#0a0a07;border:1px solid #3a2a10;color:#f0ead6;font-family:Crimson Pro,serif;font-size:.85rem;box-sizing:border-box;margin-bottom:.6rem"/>';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.1em;color:#8a6a20;margin-bottom:.4rem">DURÉE DE REMBOURSEMENT</div>';
  html += '<select id="pret-duree" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.8rem">';
  [10,15,20,25,30].forEach(d => { html += '<option value="' + d + '">' + d + ' jours</option>'; });
  html += '</select>';
  html += '<button onclick="confirmerPretBancaire(&quot;' + typeBanque + '&quot;)" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #4a6a8a;background:transparent;color:#6a9aca;cursor:pointer">Contracter le prêt</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}"""

new = """// Trois types de prets, chacun avec sa propre limite d'un seul actif a la fois (pas une
// limite globale — un joueur peut avoir un pret Travaux ET un pret Consommation en meme
// temps, mais pas deux Travaux). Immobilier reste exclusivement accessible via le compromis
// de vente de terrain (voir plateau-pnj.js, doConfirmerCompromis) — pas d'acces direct ici
// tant que la revente de biens entre joueurs n'existe pas.
const TYPES_PRET = {
  travaux:      { label: 'Travaux',      desc: 'Financer la construction sur un terrain possédé.' },
  consommation: { label: 'Consommation', desc: 'Petite somme, remboursement rapide, taux élevé.', montantMax: 10000, tauxFixe: 12, dureeMax: 30 }
};

async function ouvrirModalPretBancaire(typeBanque, typePret) {
  typeBanque = typeBanque || 'nationale';

  if (!typePret) {
    let html = '<div style="padding:1rem"><div style="display:flex;flex-direction:column;gap:.4rem">';
    Object.entries(TYPES_PRET).forEach(([key, t]) => {
      html += '<div onclick="ouvrirModalPretBancaire(\\'' + typeBanque + '\\',\\'' + key + '\\')" style="cursor:pointer;padding:.7rem;border:1px solid #2a2010;background:#0f0d05">';
      html += '<div style="font-size:.85rem;color:#c0b090">' + t.label + '</div>';
      html += '<div style="font-size:.7rem;color:#6a5a30;margin-top:.2rem">' + t.desc + '</div>';
      html += '</div>';
    });
    html += '</div></div>';
    document.getElementById('postes-modal-title').textContent = typeBanque === 'privee' ? 'Prêt — Banque Privée Helvetia' : 'Prêt — Banque Nationale';
    document.getElementById('postes-body').innerHTML = html;
    document.getElementById('modal-postes').classList.add('open');
    return;
  }

  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const infosType = TYPES_PRET[typePret];
  const estPrivee = typeBanque === 'privee';
  const estConso = typePret === 'consommation';
  const taux = estConso ? infosType.tauxFixe : getTauxPret(typeBanque);

  document.getElementById('postes-modal-title').textContent = (estPrivee ? 'Prêt — Banque Privée Helvetia' : 'Prêt — Banque Nationale') + ' · ' + infosType.label;
  let html = '<div style="padding:1rem">';
  if (estPrivee) {
    html += '<div style="font-size:.78rem;color:#aa7a30;font-style:italic;margin-bottom:.8rem;padding:.5rem;background:#0f0d05;border:1px solid #3a2810">Aucune vérification. Discrétion garantie. En cas d\\'impayé prolongé, la méthode de recouvrement est... directe.</div>';
  }
  html += '<div style="font-size:.78rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Taux applicable : ' + taux.toFixed(1) + '% sur la durée totale du prêt.' + (estConso ? ' Montant max ' + infosType.montantMax.toLocaleString('fr-FR') + ' ' + cur + ', durée max ' + infosType.dureeMax + ' jours.' : '') + '</div>';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.1em;color:#8a6a20;margin-bottom:.4rem">MONTANT EMPRUNTÉ</div>';
  html += '<input id="pret-montant" type="number" min="1000" ' + (estConso ? 'max="' + infosType.montantMax + '"' : '') + ' step="1000" placeholder="Montant en ' + cur + '..." style="width:100%;padding:.4rem .6rem;background:#0a0a07;border:1px solid #3a2a10;color:#f0ead6;font-family:Crimson Pro,serif;font-size:.85rem;box-sizing:border-box;margin-bottom:.6rem"/>';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.1em;color:#8a6a20;margin-bottom:.4rem">DURÉE DE REMBOURSEMENT</div>';
  html += '<select id="pret-duree" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.8rem">';
  const dureesDispo = estConso ? [5,10,15,20,25,30] : [10,15,20,25,30];
  dureesDispo.forEach(d => { html += '<option value="' + d + '">' + d + ' jours</option>'; });
  html += '</select>';
  html += '<button onclick="confirmerPretBancaire(&quot;' + typeBanque + '&quot;,&quot;' + typePret + '&quot;)" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #4a6a8a;background:transparent;color:#6a9aca;cursor:pointer">Contracter le prêt</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Sélecteur de types de prêts créé (Travaux/Consommation), avec plafonds spécifiques pour le prêt conso.")
