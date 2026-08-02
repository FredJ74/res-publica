// plateau-musee-personnalites.js
// Bios des personnalites du Musee National de Republia, consultables via un ordre generique
// dans chaque salle concernee. Reutilise le modal generique #modal-postes.

const MUSEE_NATIONAL_PERSONNALITES = {
  salle_politiques: [
    { nom: 'Antoine Ferréol', dates: '1888–1962', bio: "Premier ministre, artisan de la réforme fiscale de 1934." },
    { nom: 'Solange Vernier', dates: '1920–1998', bio: "Première femme ministre de Républia, portefeuille de l'Intérieur." },
    { nom: 'Gustave Ombreval', dates: '1901–1975', bio: "Député historique, 40 ans de mandat ininterrompu." },
    { nom: 'Blaise Corentin', dates: '1945–', bio: "Ministre des Affaires étrangères, artisan du traité avec El Estado." }
  ],
  salle_civils_intellectuels: [
    { nom: 'Professeure Adèle Rocheval', dates: '1878–1951', bio: "Fondatrice de l'Université de Républia." },
    { nom: 'Jean-Baptiste Lherminier', dates: '1902–1980', bio: "Philosophe, penseur de la doctrine républicaine." },
    { nom: 'Marthe Aubignac', dates: '1930–2015', bio: "Journaliste d'investigation et lanceuse d'alerte, plusieurs affaires d'État révélées." },
    { nom: 'Thierry Munster', dates: '1951–', bio: "Découvreur de la maladie dégénérative de l'ongle, inventeur du vernis thérapeutique." }
  ],
  salle_organisations: [
    { nom: 'Cardinal Théodore Passerand', dates: '1860–1935', bio: "Figure religieuse la plus influente du siècle dernier." },
    { nom: 'Lucien Farge', dates: '1899–1968', bio: "Fondateur du premier grand syndicat ouvrier du pays." },
    { nom: 'Grande Maîtresse Odile Vasseur', dates: '1910–1990', bio: "Dirigeante historique d'une loge influente." },
    { nom: 'Patrick Lemaître', dates: '1959–', bio: "Chef des supporters de l'Union Cheminote de Montrouge, organisateur de la grande manifestation de 3 semaines contre le maire de Montrouge en 1993." }
  ],
  salle_artistes_sportifs: [
    { nom: 'Camille Ardant', dates: '1885–1960', bio: "Compositrice, hymne national encore joué aujourd'hui." },
    { nom: 'Marcel « Le Foudre » Rambert', dates: '1922–1978', bio: "Champion national de boxe, trois titres consécutifs." },
    { nom: 'Yvonne Chastel', dates: '1940–2019', bio: "Sculptrice, statues visibles sur les places publiques du pays." },
    { nom: 'Didier Després', dates: '1965–', bio: "Joueur de la Brise Mariannaise, meilleur buteur du championnat de 1989 à 1992." },
    { nom: 'Michel Torchon', dates: '1950–2011', bio: "Champion d'essuyage d'assiettes au concours de plonge de 1975 à 1985 (unique participant)." }
  ],
  salle_reussites_economiques: [
    { nom: 'Baptiste Cordonnier', dates: '1870–1940', bio: "Fondateur de la première grande banque nationale." },
    { nom: 'Émilienne Trouvère', dates: '1895–1958', bio: "Pionnière de l'industrie textile, employait 10 000 ouvriers." },
    { nom: 'Roger Sillage', dates: '1920–1995', bio: "Magnat des transports ferroviaires nationaux." },
    { nom: 'Bertrand Salace', dates: '1977–', bio: "Créateur du premier site de vente en ligne d'accessoires coquins (Coquin&Co)." },
    { nom: 'Killian Sauveur dit « Kissa »', dates: '2001–', bio: "Influenceur dans le milieu du combat de position de yoga." }
  ],
  salle_honneur_militaire_nationale: [
    { nom: 'Général Auguste Verneuil', dates: '1850–1920', bio: "Héros de la Guerre d'Unification des trois villes." },
    { nom: 'Colonelle Isabeau Franchet', dates: '1915–1978', bio: "Première femme officier supérieur de l'armée." },
    { nom: 'Maréchal Théodule Bracquemont', dates: '1880–1955', bio: "Stratège légendaire, jamais vaincu en bataille." },
    { nom: 'Amiral Jacques Derien', dates: '1969–', bio: "Héros de la fuite la plus rapide d'un champ de bataille en 2016." }
  ],
  salle_criminels_pays: [
    { nom: '« Le Boucher de la Capitale »', dates: 'années 1920', bio: "Identité jamais formellement établie." },
    { nom: 'Hortense Delacroix', dates: '1888–1934', bio: "Cheffe d'un réseau de contrebande national." },
    { nom: 'Fabien Roquemaure', dates: '1910–1962', bio: "Escroc financier, ruina plusieurs banques régionales." },
    { nom: 'Maxence Monfils', dates: '2017–', bio: "Plus grand arracheur d'ailes de mouches et de pattes d'araignée, recherché par les organisations environnementales." }
  ]
};

function doConsulterPersonnalitesMusee() {
  const liste = MUSEE_NATIONAL_PERSONNALITES[state.currentRoom] || [];
  const room = (typeof BUILDINGS !== 'undefined' && BUILDINGS[state.currentBuilding]) ? BUILDINGS[state.currentBuilding].rooms?.[state.currentRoom] : null;
  document.getElementById('postes-modal-title').textContent = (room && room.name) ? room.name : 'Personnalités';

  let html = '<div style="padding:1rem">';
  if (liste.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Rien à consulter ici pour l\'instant.</div>';
  } else {
    html += '<div style="display:flex;flex-direction:column;gap:.4rem">';
    liste.forEach(function(p, i) {
      html += '<div onclick="afficherFichePersonnaliteMusee(' + i + ')" style="cursor:pointer;padding:.5rem .6rem;border:1px solid #2a2010;font-size:.88rem;color:#c0b090">' + p.nom + ' <span style="color:#8a8060;font-size:.8rem">(' + p.dates + ')</span></div>';
    });
    html += '</div>';
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function afficherFichePersonnaliteMusee(idx) {
  const liste = MUSEE_NATIONAL_PERSONNALITES[state.currentRoom] || [];
  const p = liste[idx];
  if (!p) return;

  let html = '<div style="padding:1.2rem">';
  html += '<div style="font-size:1rem;color:#C9A84C;font-family:Bebas Neue,sans-serif;letter-spacing:.05em;margin-bottom:.2rem">' + p.nom + '</div>';
  html += '<div style="font-size:.82rem;color:#8a8060;margin-bottom:.8rem">' + p.dates + '</div>';
  html += '<div style="font-size:.88rem;color:#e0d8c0;line-height:1.5">' + p.bio + '</div>';
  html += '<button class="pnj-action-btn" onclick="doConsulterPersonnalitesMusee()" style="margin-top:1rem;opacity:.8"><i class="ti ti-arrow-left" style="font-size:.85rem"></i> Retour à la liste</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}
