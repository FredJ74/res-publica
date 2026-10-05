#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Correctif Hotel Republica :
- accueil : "Reserver une chambre" corrigee (fn) + nouvel ordre "Louer une suite"
- chambres : nouvel ordre "Dormir (chambre reservee)"
- suite_privee : nettoyee (louer_local deplace, escort_infos supprime), tag suiteChoice
- nouvelle suite_presidentielle
- plateau-personnage.js : bonus confortMap aligne sur PSM (+2 PA / +3 Moral)
- plateau-router.js : route "choisir_suite"
- plateau-justice-economie.js : nouvelles fonctions ouvrirModalChoixSuite / entrerEtLouerSuite
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
# 1) data.js -- accueil de l'hotel-republica
# ------------------------------------------------------------------
old_accueil = """        orders: [
          {fn:'parler_pnj',    label:'Parler au concierge',  pa:0, cost:0,   type:'legal',   icon:'ti-message', successRate:100},
          {fn:'se_renseigner', label:'Se renseigner',        pa:0, cost:0,   type:'legal',   icon:'ti-info-circle', successRate:100},
          {fn:'reserver',      label:'Reserver une chambre', pa:1, cost:80,  type:'legal',   icon:'ti-key', successRate:100}
        ]
      },
      restaurant: {"""

new_accueil = """        orders: [
          {fn:'parler_pnj',    label:'Parler au concierge',  pa:0, cost:0,   type:'legal',   icon:'ti-message', successRate:100},
          {fn:'se_renseigner', label:'Se renseigner',        pa:0, cost:0,   type:'legal',   icon:'ti-info-circle', successRate:100},
          {fn:'reserver_chambre_hotel', label:'Reserver une chambre', pa:1, cost:80,  type:'legal',   icon:'ti-key', successRate:100, desc:'Bonus de +2 PA et +3 Moral au prochain Dormir passe dans cette chambre.'},
          {fn:'choisir_suite', label:'Louer une suite', pa:1, cost:0, type:'legal', icon:'ti-crown', successRate:100, desc:'Choisir parmi les suites disponibles de l\\'hotel.'}
        ]
      },
      restaurant: {"""

ok &= apply_patch('data.js', old_accueil, new_accueil, "data.js - accueil (reserver_chambre_hotel + choisir_suite)")

# ------------------------------------------------------------------
# 2) data.js -- chambres (ajout dormir_chambre)
# ------------------------------------------------------------------
old_chambres = """        orders: [
          {fn:'dormir',         label:'Dormir (nuit complete)', pa:0, cost:80,  type:'legal', icon:'ti-moon',     successRate:100, desc:'Recuperation complete. +5 PA bonus demain.', paBonus:5},
          {fn:'se_reposer',     label:'Se reposer (sieste)',    pa:0, cost:0,   type:'legal', icon:'ti-zzz',      successRate:100, desc:'+2 Moral.'},
          {fn:'reunion_privee', label:'Reunion privee',         pa:2, cost:50,  type:'grey',  icon:'ti-lock',     successRate:100, desc:'Rencontre discrete sans temoins.'}
        ]
      },"""

new_chambres = """        orders: [
          {fn:'dormir',         label:'Dormir (nuit complete)', pa:0, cost:80,  type:'legal', icon:'ti-moon',     successRate:100, desc:'Recuperation complete. +5 PA bonus demain.', paBonus:5},
          {fn:'dormir_chambre', label:'Dormir (chambre reservee)', pa:0, cost:0, type:'legal', icon:'ti-moon', successRate:100, desc:'Necessite une chambre reservee a l\\'accueil pour beneficier du bonus.'},
          {fn:'se_reposer',     label:'Se reposer (sieste)',    pa:0, cost:0,   type:'legal', icon:'ti-zzz',      successRate:100, desc:'+2 Moral.'},
          {fn:'reunion_privee', label:'Reunion privee',         pa:2, cost:50,  type:'grey',  icon:'ti-lock',     successRate:100, desc:'Rencontre discrete sans temoins.'}
        ]
      },"""

ok &= apply_patch('data.js', old_chambres, new_chambres, "data.js - chambres (dormir_chambre)")

# ------------------------------------------------------------------
# 3) data.js -- suite_privee (nettoyage) + nouvelle suite_presidentielle
# ------------------------------------------------------------------
old_suite = """      suite_privee: {
        name: "Suite Privée — Local à louer",
        imageBg: "linear-gradient(135deg,#1a0d10,#250f18)",
        desc: "📋 À LOUER — Suite luxueuse et très discrète. Roxane y reçoit une clientèle triée sur le volet. Informations exclusives garanties.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/hotel-republica-suite-privee.png",
        isLocationRoom: true,
        locationData: { prix: 500, bonusPOP: 0, bonusINF: 8, bonusDIS: 10, label: 'Suite Privée', tier: 1 },
        persons: [
          {name:'Roxane Velours (PNJ)', role:'Escort de luxe', rel:'neutral', job:'escort', photoUrl:'', trait:'Son carnet d\\'adresses vaut plus que celui du Premier Ministre.'}
        ],
        orders: [
          {fn:'louer_local', label:'Louer cette suite (500 FR/jour)', pa:1, cost:0, type:'grey', icon:'ti-key', successRate:100, desc:'+8 INF +10 DIS. Clients très discrets, informations très utiles.'},
          {fn:'escort_infos', label:'Recueillir des informations', pa:2, cost:300, type:'grey', icon:'ti-ear', successRate:75, desc:'Roxane collecte des confidences. Génère un kompromat.'},
          {fn:'gerer_local', label:'Gérer mon local', pa:1, cost:0, type:'legal', icon:'ti-settings', successRate:100}
        ]
      }
    }
  },"""

new_suite = """      suite_privee: {
        name: "Suite Privée — Local à louer",
        imageBg: "linear-gradient(135deg,#1a0d10,#250f18)",
        desc: "📋 À LOUER — Suite luxueuse et très discrète. Roxane y reçoit une clientèle triée sur le volet. Informations exclusives garanties.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/hotel-republica-suite-privee.png",
        isLocationRoom: true,
        locationData: { prix: 500, bonusPOP: 0, bonusINF: 8, bonusDIS: 10, label: 'Suite Privée', tier: 1, suiteChoice: true },
        persons: [
          {name:'Roxane Velours (PNJ)', role:'Escort de luxe', rel:'neutral', job:'escort', photoUrl:'', trait:'Son carnet d\\'adresses vaut plus que celui du Premier Ministre.'}
        ],
        orders: [
          {fn:'gerer_local', label:'Gérer mon local', pa:1, cost:0, type:'legal', icon:'ti-settings', successRate:100}
        ]
      },
      suite_presidentielle: {
        name: "Suite Présidentielle — Local à louer",
        imageBg: "linear-gradient(135deg,#181008,#20140a)",
        desc: "📋 À LOUER — Suite d'apparat au décor XIXe, vue sur les toits de la Capitale. Le nec plus ultra pour recevoir en grande pompe.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/hotel-republica-suite-presidentielle.png",
        isLocationRoom: true,
        locationData: { prix: 500, bonusPOP: 8, bonusINF: 8, bonusDIS: 2, label: 'Suite Présidentielle', tier: 1, suiteChoice: true },
        persons: [],
        orders: [
          {fn:'gerer_local', label:'Gérer mon local', pa:1, cost:0, type:'legal', icon:'ti-settings', successRate:100}
        ]
      }
    }
  },"""

ok &= apply_patch('data.js', old_suite, new_suite, "data.js - suite_privee nettoyee + suite_presidentielle ajoutee")

# ------------------------------------------------------------------
# 4) plateau-personnage.js -- confortMap
# ------------------------------------------------------------------
old_confort = """  const confortMap = {
    'hotel-republica': { moral: 5, paBonus: 5 },
    'hotel-port':      { moral: 3, paBonus: 2 },
    'hotel-mineur':    { moral: 3, paBonus: 2 },
    'palais-presidentiel': { moral: 8, paBonus: 8 }
  };"""

new_confort = """  const confortMap = {
    'hotel-republica': { moral: 3, paBonus: 2 },
    'hotel-port':      { moral: 3, paBonus: 2 },
    'hotel-mineur':    { moral: 3, paBonus: 2 },
    'palais-presidentiel': { moral: 8, paBonus: 8 }
  };"""

ok &= apply_patch('plateau-personnage.js', old_confort, new_confort, "plateau-personnage.js - confortMap hotel-republica")

# ------------------------------------------------------------------
# 5) plateau-router.js -- route choisir_suite
# ------------------------------------------------------------------
old_router = """  if (fn === 'louer_local')              { ouvrirModalLouerLocal(); return; }
  if (fn === 'gerer_local')              { ouvrirModalGererLocal(); return; }"""

new_router = """  if (fn === 'louer_local')              { ouvrirModalLouerLocal(); return; }
  if (fn === 'gerer_local')              { ouvrirModalGererLocal(); return; }
  if (fn === 'choisir_suite')            { ouvrirModalChoixSuite(); return; }"""

ok &= apply_patch('plateau-router.js', old_router, new_router, "plateau-router.js - route choisir_suite")

# ------------------------------------------------------------------
# 6) plateau-justice-economie.js -- nouvelles fonctions
# ------------------------------------------------------------------
old_justice = """function ouvrirModalGererLocal() {"""

new_justice = """function ouvrirModalChoixSuite() {
  const buildingId = state.currentBuilding;
  const b = BUILDINGS[buildingId];
  if (!b) return;

  const suites = Object.entries(b.rooms || {}).filter(([, r]) => r.isLocationRoom && r.locationData?.suiteChoice);
  if (suites.length === 0) { showToast('Aucune suite', 'Aucune suite disponible ici.', false); return; }

  const cur = COUNTRIES[state.country]?.cur || 'FR';

  document.getElementById('postes-modal-title').textContent = '👑 Louer une suite';
  let html = '<div style="padding:.8rem 1rem">';
  suites.forEach(([roomId, room]) => {
    const loc = room.locationData;
    const dejaLoue = getLocationPourRoom(buildingId, roomId);
    const bonusParts = [];
    if (loc.bonusPOP > 0) bonusParts.push('+' + loc.bonusPOP + ' POP');
    if (loc.bonusINF > 0) bonusParts.push('+' + loc.bonusINF + ' INF');
    if (loc.bonusDIS > 0) bonusParts.push('+' + loc.bonusDIS + ' DIS');

    html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.6rem;margin-bottom:.5rem">';
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.9rem;color:#C9A84C">' + loc.label + '</div>';
    html += '<div style="font-size:.75rem;color:#a09060;margin:.2rem 0">' + (room.desc || '') + '</div>';
    html += '<div style="font-size:.78rem;color:#9a8a68">' + loc.prix.toLocaleString('fr-FR') + ' ' + cur + '/jour \\u00b7 ' + (bonusParts.join(' \\u00b7 ') || 'Aucun bonus') + '</div>';
    if (dejaLoue) {
      html += '<div style="font-size:.72rem;color:#8a6a20;margin-top:.4rem">D\\u00e9j\\u00e0 lou\\u00e9e' + (dejaLoue.locataire === state.char?.name ? ' (par vous)' : '') + '.</div>';
    } else {
      html += '<button onclick="entrerEtLouerSuite(\\'' + buildingId + '\\',\\'' + roomId + '\\')" style="margin-top:.4rem;width:100%;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.4rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">\\ud83d\\udd11 Louer cette suite</button>';
    }
    html += '</div>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function entrerEtLouerSuite(buildingId, roomId) {
  document.getElementById('modal-postes').classList.remove('open');
  enterRoom(buildingId, roomId, null);
  ouvrirModalLouerLocal();
}

function ouvrirModalGererLocal() {"""

ok &= apply_patch('plateau-justice-economie.js', old_justice, new_justice, "plateau-justice-economie.js - ouvrirModalChoixSuite + entrerEtLouerSuite")

print()
if ok:
    print("TOUT EST OK. Verifie avec les commandes grep -c donnees ensuite.")
else:
    print("AU MOINS UN CORRECTIF A ECHOUE. Ne rien committer, copie-colle le detail a Claude.")
    sys.exit(1)
