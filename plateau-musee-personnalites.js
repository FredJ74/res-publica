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
  const liste = personnalitesMuseeCourantes();
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
  const liste = personnalitesMuseeCourantes();
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

// Musees de province (decision de Fred, 01/11/2026 : Claude ecrit les figures, a la relecture
// de Fred). Indexees par batiment PUIS par salle : plusieurs salles portent le meme identifiant
// qu'au musee national (salle_organisations...). Aucune figure ne touche a l'enigme premium de
// PSM (Yann Le Goff et les fondateurs de la ville) ; la Salle des Plumes reste aux joueurs.
// Faits canoniques de Montrouge repris : premier cinema, premiers logements sociaux, premiers
// jardins ouvriers de Republia ; Patrick Lemaitre figure aussi au musee national.
const MUSEE_PROVINCE_PERSONNALITES = {
  'musee-port-sainte-marie': {
    salle_criminels: [
      { nom: '« Le Naufrageur de la Pointe »', dates: 'années 1880', bio: "Allumait de faux feux sur la côte pour attirer les navires sur les récifs. Jamais identifié." },
      { nom: 'Anne-Marie Quéré', dates: '1902–1971', bio: "Contrebandière de rhum pendant trente ans ; ses barils voyageaient dans des cercueils bénis." },
      { nom: 'Gwendal Riou', dates: '1931–1999', bio: "Vendit le même chalutier à trois armateurs différents, la même semaine." },
      { nom: 'Loïc « La Murène » Penven', dates: '1958–', bio: "Racketteur des pontons du port de plaisance. Dit avoir pris sa retraite ; personne ne le croit." },
      { nom: 'Ronan Tanguy', dates: '1990–', bio: "Voleur de casiers à homards, condamné quatorze fois. Prétend que les homards le suivent." }
    ],
    salle_maires: [
      { nom: 'Hervé Kerjean', dates: '1859–1931', bio: "Maire de 1898 à 1925. Fit paver le quai avant la place de la mairie, « parce que les bateaux arrivent avant les électeurs »." },
      { nom: 'Josiane Le Bihan', dates: '1921–2004', bio: "Maire pendant vingt-huit ans. On lui doit le port de plaisance, que les pêcheurs ne lui ont jamais pardonné." },
      { nom: 'Albert Moal', dates: '1935–2010', bio: "Maire pendant onze jours en 1977, démissionnaire après avoir confondu le budget municipal avec la caisse de la fête de la sardine." },
      { nom: 'Yannick Le Duff', dates: '1948–', bio: "Élu trois fois en promettant un pont vers l'île d'en face. Il n'y a pas d'île en face." }
    ],
    salle_personnalites: [
      { nom: 'Mère Jeanne Kerboul', dates: '1870–1958', bio: "Tenait la cantine des marins ; nourrit gratuitement tous les équipages pendant la grande tempête de 1911." },
      { nom: "Erwan Le Floc'h", dates: '1925–1996', bio: "Chanteur de complaintes de marins : quarante disques, une seule chanson." },
      { nom: 'Docteure Maëlle Cozic', dates: '1938–2012', bio: "Médecin du dispensaire pendant quarante ans ; a recousu la moitié de la ville, parfois deux fois." },
      { nom: "Tugdual « Tutu » Guivarc'h", dates: '1972–', bio: "Champion régional du lancer de bigorneau. Record de 41 mètres, jamais homologué." }
    ],
    salle_entrepreneurs: [
      { nom: 'Armand Prigent', dates: '1862–1939', bio: "Fondateur de la première conserverie de sardines, qui employa la moitié des femmes du port." },
      { nom: 'Corentine Le Roux', dates: '1899–1977', bio: "Armatrice de quarante chalutiers. N'est jamais montée sur un seul : elle avait le mal de mer." },
      { nom: 'Hubert Daniélou', dates: '1940–2008', bio: "Sauva le chantier naval en y construisant des yachts pour les fortunes de la capitale." },
      { nom: 'Kévin Lostanlen', dates: '1994–', bio: "Inventeur d'une application qui prévient quand le poisson mord. Elle sonne en permanence." }
    ],
    salle_organisations: [
      { nom: 'Abbé Yves Le Meur', dates: '1855–1929', bio: "Fonda la confrérie des Marins de Notre-Dame-de-la-Mer, qui bénit encore la flotte chaque printemps." },
      { nom: 'Germaine Rospars', dates: '1908–1983', bio: "Meneuse de la grève des sardinières de 1924, qui fit plier les conserveurs en six semaines." },
      { nom: 'Paul Kervella', dates: '1930–2001', bio: "Président de la société de sauvetage en mer pendant trente ans : 212 vies sauvées." },
      { nom: 'Gaëlle Morvan', dates: '1966–', bio: "Présidente du club des supporters du stade, interdite de stade depuis 2004. Préside depuis le parking." }
    ],
    salle_honneur_militaire: [
      { nom: 'Capitaine de vaisseau Alain Kerguélen', dates: '1868–1934', bio: "Commanda la flottille de Port-Sainte-Marie pendant la Guerre d'Unification des trois villes." },
      { nom: 'Quartier-maître Fañch Le Bris', dates: '1921–1944', bio: "Resta à la barre de sa vedette en flammes pour ramener tout son équipage au port." },
      { nom: 'Matelot Jean-Pierre Coat', dates: '1952–', bio: "Médaille du mérite pour trente ans de service sans jamais quitter le quai." },
      { nom: 'Lieutenante Nolwenn Abgrall', dates: '1981–', bio: "Première femme à commander un patrouilleur basé à Port-Sainte-Marie." }
    ],
    salle_unions: [
      { nom: 'Pierrick Le Gac et Marie-Anne Calvez', dates: 'mariés en 1903', bio: "Leur mariage réconcilia les deux grandes familles de pêcheurs rivales. La noce dura onze jours." },
      { nom: 'Bernard et Odette Quillien', dates: 'mariés en 1950', bio: "Soixante-deux ans de mariage, soixante-deux ans de dispute sur le meilleur coin de pêche." },
      { nom: 'Fabrice Le Corre et Sandrine Nédélec', dates: 'mariés en 1988, 1989 et 1991', bio: "Trois mariages, deux divorces, toujours ensemble. Record local." }
    ],
    salle_scandales: [
      { nom: "L'affaire des sardines d'or", dates: '1912', bio: "Des conserves vendues comme « sardines à la feuille d'or ». Elles contenaient du maquereau." },
      { nom: 'Le scandale du phare', dates: '1958', bio: "Le budget de rénovation du phare disparut. La lumière du phare aussi, trois semaines, faute d'ampoule." },
      { nom: "L'affaire du port de plaisance", dates: '1979', bio: "Des terrains municipaux cédés au franc symbolique au beau-frère du premier adjoint." },
      { nom: 'La criée truquée', dates: '2015', bio: "Le même thon vendu sept fois dans la même matinée, à sept acheteurs ravis." }
    ]
  },
  'musee-histoire-montrouge': {
    salle_terre: [
      { nom: 'Abbé Hippolyte Ferrand', dates: '1790–1861', bio: "Géologue amateur, découvrit le charbon du bassin en creusant un puits pour son presbytère." },
      { nom: 'Rose Brugère', dates: '1845–1920', bio: "Bergère. Ses moutons aux pattes rouges furent le premier indice du minerai de fer." },
      { nom: 'Professeur Edmond Valadier', dates: '1833–1902', bio: "Montra que la roche ferrugineuse donne sa couleur à la colline, et son nom à Montrouge." },
      { nom: 'Gilbert Pélissier', dates: '1960–', bio: "Collectionneur, a légué au musée 4 000 pierres, dont 3 998 identiques." }
    ],
    salle_industrie: [
      { nom: 'Henri Montagnac', dates: '1818–1888', bio: "Ouvrit le premier puits de charbon industriel du bassin." },
      { nom: 'Louise Fabre', dates: '1871–1943', bio: "Trieuse de charbon devenue la première femme à diriger un atelier de l'usine." },
      { nom: 'Ernest Coudert', dates: '1890–1966', bio: "Ingénieur du haut-fourneau, fit de l'usine principale la plus grande de Républia." },
      { nom: 'Jacky Roumégous', dates: '1955–', bio: "Dernier mineur de fond de Montrouge. Redescend chaque dimanche « pour garder la main »." }
    ],
    salle_rail: [
      { nom: 'Léonce Barthélemy', dates: '1825–1897', bio: "Fit venir le chemin de fer à Montrouge, pour sortir le charbon et, disait-il, faire entrer les idées." },
      { nom: 'Augustin Rivière', dates: '1880–1951', bio: "Mécanicien de la ligne Montrouge–Luthécia : pas un seul retard en trente ans de service." },
      { nom: 'Marie-Thérèse Lacombe', dates: '1912–1990', bio: "Première femme cheffe de gare de Républia." },
      { nom: 'Didier Castan', dates: '1968–', bio: "Contrôleur. A verbalisé son propre père pour défaut de compostage." }
    ],
    salle_ville: [
      { nom: 'Victor Delmas', dates: '1850–1921', bio: "Maire qui fit bâtir à Montrouge les premiers logements sociaux de Républia." },
      { nom: 'Antoinette Serres', dates: '1862–1938', bio: "Créa les premiers jardins ouvriers du pays, « pour que l'ouvrier mange autre chose que de la poussière »." },
      { nom: 'Albin et Firmin Combes', dates: '1868–1940 et 1871–1945', bio: "Les deux frères ouvrirent le premier cinéma de Républia, dans un ancien hangar à locomotives." },
      { nom: 'Mémé Paulette Vidal', dates: '1931–', bio: "Doyenne des cités ouvrières : connaît le nom de chaque habitant, et le secret de chacun." }
    ],
    salle_luttes: [
      { nom: 'Jules Cazals', dates: '1849–1909', bio: "Mena la première grève des mineurs : soixante-trois jours pour la journée de dix heures." },
      { nom: 'Émilie Roques', dates: '1880–1960', bio: "Fonda la caisse de solidarité qui nourrit les familles de grévistes pendant la grande grève de 1920." },
      { nom: 'Raymond Escande', dates: '1925–1999', bio: "Secrétaire du syndicat cheminot pendant vingt-cinq ans, arracha les congés payés du rail." },
      { nom: 'Solange Bories', dates: '1970–', bio: "Déléguée syndicale. A fait grève contre la grève, puis contre la grève contre la grève." }
    ],
    salle_loisirs: [
      { nom: 'Fernand Gaubert', dates: '1872–1950', bio: "Patron du café de la gare, où se décidaient les grèves, les mariages et la composition de l'équipe." },
      { nom: 'Achille Pujol', dates: '1878–1946', bio: "Fondateur de l'Union Cheminote de Montrouge, avec onze cheminots et un ballon de cuir." },
      { nom: 'René « La Locomotive » Batut', dates: '1934–2001', bio: "Avant-centre de l'UCM : 214 buts, tous à domicile." },
      { nom: 'Patrick Lemaître', dates: '1959–', bio: "Chef des supporters de l'UCM, organisateur de la grande manifestation de trois semaines contre le maire de Montrouge en 1993." }
    ]
  }
};

// Liste de la salle courante : musee de province d'abord (par batiment), sinon musee national.
function personnalitesMuseeCourantes() {
  const province = MUSEE_PROVINCE_PERSONNALITES[state.currentBuilding];
  if (province) return province[state.currentRoom] || [];
  return MUSEE_NATIONAL_PERSONNALITES[state.currentRoom] || [];
}
