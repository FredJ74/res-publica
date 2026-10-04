/* ===========================================================================
   VARIANTES GRAPHIQUES DES PIECES — moteur generique
   ===========================================================================

   Une piece peut changer d'apparence selon son etat, et afficher une enseigne
   portant un texte calcule par le jeu (le nom d'un commerce, par exemple).

   CE FICHIER NE CONTIENT AUCUNE REGLE DE JEU ET AUCUN CAS PARTICULIER.
   Il ne connait ni Luthecia, ni le centre commercial, ni la location. Il ne
   sait que trois choses :

     1. lire une DECLARATION (PIECE_VARIANTES) : pays > ville > batiment >
        piece ;
     2. demander son etat courant a une FAMILLE (PIECE_FAMILLES_ETAT), qui est
        le seul endroit ou vit la logique metier ;
     3. peindre l'image correspondante et, si la declaration le demande, une
        enseigne par-dessus.

   Pour habiller un nouveau batiment -- un centre commercial d'une autre ville,
   d'un autre pays, un centre artisanal, un hotel, un entrepot, un logement --
   il suffit d'AJOUTER UNE ENTREE DE DONNEE dans PIECE_VARIANTES. Aucune ligne
   de code n'est a ecrire, et aucune ligne de ce fichier n'est a modifier.
   Une ligne de code n'est necessaire que pour inventer une NATURE d'etat qui
   n'existe pas encore (jour/nuit, ouvert/ferme...) : c'est alors une famille
   de plus dans PIECE_FAMILLES_ETAT, et elle sert aussitot a tous les batiments.

   --------------------------------------------------------------------------
   FORME D'UNE DECLARATION
   --------------------------------------------------------------------------

   PIECE_VARIANTES[pays][ville][batiment][piece] = {
     famille: 'location',          // quelle famille sait repondre "quel etat ?"
     ancrage: 'haut',              // 'haut' | 'centre' (defaut) — voir plus bas
     images: {
       libre:   'images/....png',  // une image par etat rendu par la famille
       occupee: 'images/....png'
     },
     nom: {                        // facultatif : nom de la piece selon l'etat
       occupee: { sansSuffixe: ' — Local à louer' }
     },
     desc: {                       // facultatif : description selon l'etat
       occupee: 'Le local est occupé.'
     },
     enseigne: {                   // facultatif : aucune enseigne si absent
       mode:  'texte',             // 'aucune' | 'texte' | 'image' — defaut du lieu
       etats: ['occupee'],         // etats ou l'enseigne s'affiche
       libelles: {                 // facultatif : texte FIXE pour certains etats
         libre: 'À LOUER'          // la famille n'est alors pas consultee
       },
       zone:  { x:.20, y:.07, w:.57, h:.095 },  // fractions de l'IMAGE SOURCE
       texte: {                    // habillage du mode texte
         align: 'center',          // 'left' | 'center' | 'right'
         casse: 'majuscules',      // 'majuscules' | 'aucune'
         couleur: '#f3e3b4',
         ombre: true,
         graisse: 700,
         police: "'Playfair Display',serif",
         tailleMax: 30             // px, plafond quelle que soit la fenetre
       },
       image: {                    // habillage du mode image
         ajustement: 'contain'     // 'contain' (defaut) | 'cover'
       }
     }
   };

   --------------------------------------------------------------------------
   LES TEXTES DE LA PIECE SELON L'ETAT — `nom` ET `desc`
   --------------------------------------------------------------------------

   Un local libre fait sa publicite : il s'appelle « Vitrine Principale — Local
   a louer » et se decrit « 📋 À LOUER — Emplacement premium en facade... ». Une
   fois pris, ces deux textes mentent : le local n'est plus a louer.

   Les deux champs obeissent donc a UNE SEULE ET MEME regle, et c'est voulu --
   un troisieme champ, demain, ne coutera qu'une ligne. Trois formes :

     'Un texte complet'                     // remplacement
     { sansPrefixe: '📋 À LOUER — ' }        // retrait en tete
     { sansSuffixe: ' — Local à louer' }     // retrait en queue

   Les RETRAITS sont la forme a preferer partout ou le fragment est partage :
   une seule regle, ecrite une fois, couvre les quatre locaux -- et les centres
   commerciaux, artisanaux et d'affaires des autres villes le jour venu, sans
   retaper un seul texte. C'est le chemin de reutilisation immediate.

   Le REMPLACEMENT sert quand le texte restant continuerait de vendre. C'est le
   cas des descriptions du centre commercial : retirer « 📋 À LOUER — » laisse
   « ... Prix eleve, impact fort sur la reputation de votre organisation », qui
   parle encore de louer. Un local occupe decrit l'endroit, pas l'offre.

   Un retrait n'opere que si le texte commence (ou finit) vraiment par le
   fragment declare ; sinon le texte d'origine est conserve tel quel, sans
   message et sans degat.

   La regle de `nom` s'applique AUX TROIS endroits ou le nom paraît -- le titre
   de la piece, l'onglet et le fil d'Ariane -- pour qu'ils ne se contredisent
   jamais entre eux.

   --------------------------------------------------------------------------
   LES TROIS MODES D'ENSEIGNE
   --------------------------------------------------------------------------

   'aucune' -- rien n'est dessine, meme si la famille a quelque chose a dire.
   'texte'  -- le libelle rendu par la famille, calibre pour tenir dans la zone.
   'image'  -- un visuel rendu par la famille, place dans la meme zone.

   Le mode de la DECLARATION est le mode par defaut du lieu. La FAMILLE peut en
   decider autrement pour une occupation donnee, en rendant un objet a mode :

     { mode:'texte', texte:'Aux Souvenirs d'Arnie' }
     { mode:'image', image:'images/enseigne-du-joueur.png' }

   Un etat peut aussi porter un libelle FIXE, declare dans `libelles` : la plaque
   d'un bureau libre affiche « À LOUER », et il n'y a aucune raison d'aller le
   demander au serveur. Quand un etat a un libelle fixe, la famille n'est pas
   consultee du tout -- l'affichage est alors immediat, sans aller-retour.

   C'est tout ce qu'il faudra a l'option premium « Personnaliser mon commerce » :
   deux boutiques voisines pourront porter l'une un nom compose par le jeu,
   l'autre un visuel fourni par son proprietaire, dans la meme piece, la meme
   zone et sans une ligne de moteur de plus. Le mode image est deja implemente
   et verifie par le banc DOM, bien qu'aucun fonds n'en porte encore.

   --------------------------------------------------------------------------
   POURQUOI LA ZONE EST EN FRACTIONS DE L'IMAGE, ET NON DU CADRE
   --------------------------------------------------------------------------

   #piece-image affiche le fond en `cover` : l'image est AGRANDIE puis ROGNEE
   pour remplir le cadre, et le rognage depend de la fenetre du joueur. Une
   enseigne positionnee en pourcentage du CADRE se decalerait donc du fronton
   des qu'on redimensionne -- elle glisserait sur la vitrine, ou sortirait du
   cadre.

   La zone est donc exprimee en fractions de l'IMAGE SOURCE, et ce fichier
   refait le calcul de `cover` pour la convertir en pixels du cadre :

       echelle = max(cadreL/imgL, cadreH/imgH)        // c'est la regle `cover`
       dessin  = imgL*echelle x imgH*echelle
       origine = (cadreL - dessinL)/2, selon l'ancrage vertical

   C'est la seule arithmetique de ce fichier, et elle est verifiee par
   .scratch/banc_variantes_pieces.js.

   --------------------------------------------------------------------------
   POURQUOI L'ANCRAGE EXISTE
   --------------------------------------------------------------------------

   Mesure faite sur la vraie cascade CSS (.scratch/banc_geometrie_piece.html) :
   le cadre #piece-image prend un rapport largeur/hauteur de 0,48 a 2,03 selon
   la fenetre, pour des images de rapport 1,834. Centre verticalement, le haut
   de l'image est donc rogne des que le cadre depasse le rapport 2,047 -- et la
   mesure donne deja 2,030 en 1280x800, soit le fronton a DEUX pixels du bord.
   Un ecran un peu plus large, ou une barre de favoris, et l'enseigne sort du
   cadre.

   Une piece declare donc son ancrage vertical. `ancrage:'haut'` colle le haut
   de l'image au haut du cadre (origine verticale = 0) : ce qui est rogne est le
   sol, jamais le fronton, et ce quel que soit le rapport du cadre. C'est aussi
   la bonne direction artistique -- sur une devanture, l'enseigne compte, le
   carrelage non.

   L'ancrage est pose par un ATTRIBUT sur le cadre (data-ancrage), lu par une
   regle CSS dediee, et non par le style inline : .piece-image porte un
   background-position:center!important que l'inline ne peut pas surcharger.
   C'est exactement le motif deja utilise par l'affichage integral des musees
   (data-musee), pour la meme raison.

   --------------------------------------------------------------------------
   LIBELLE ASYNCHRONE
   --------------------------------------------------------------------------

   Le nom d'un commerce ne vit pas en memoire : il faut aller le lire. Une
   famille peut donc rendre son libelle sous forme de promesse. L'image, elle,
   est toujours posee immediatement -- le joueur ne voit jamais de pieces vides
   en attendant le reseau. Quand le texte arrive, il n'est peint que si le
   joueur est TOUJOURS dans la meme piece (jeton de fraicheur) : sans cette
   garde, une reponse en retard viendrait ecrire l'enseigne d'une boutique sur
   la piece suivante.
   =========================================================================== */


/* ---------------------------------------------------------------------------
   1. LES FAMILLES D'ETAT — le seul endroit ou il y a de la logique metier
   --------------------------------------------------------------------------- */

const PIECE_FAMILLES_ETAT = {

  /* Un local qu'on loue : centres commerciaux, artisanaux, d'affaires, bureaux,
     ateliers, logements, chambres... Toute piece dont l'occupation est portee
     par un bail dans state.locationsActives.

     L'etat se lit SANS RESEAU : les baux du pays entier sont deja en memoire
     (chargerLocations() au demarrage). C'est ce qui permet de poser la bonne
     image des la premiere image affichee. */
  location: {
    etat: function (buildingId, roomId, ville) {
      if (typeof getLocationPourRoom !== 'function') return 'libre';
      return getLocationPourRoom(buildingId, roomId, ville) ? 'occupee' : 'libre';
    },

    /* CE QUE PORTE L'ENSEIGNE. Le bail designe un fonds ; le nom du commerce vit
       dans ce fonds, cote serveur, et aucun cache client ne l'expose. On rend
       donc une promesse -- et on memorise le resultat, pour qu'un aller-retour
       dans la piece soit instantane.

       La reponse n'est pas une chaine mais un OBJET A MODE :
         { mode:'texte', texte:'Aux Souvenirs d'Arnie' }
         { mode:'image', image:'images/....png' }
         null  -- rien a afficher
       C'est ce qui permettra a l'option premium « Personnaliser mon commerce »
       d'exister sans toucher au moteur : deux boutiques voisines pourront porter
       l'une un nom compose par le jeu, l'autre un visuel fourni par son
       proprietaire, dans la meme piece et la meme zone de fronton.

       LE POINT D'EXTENSION EST CI-DESSOUS, signale et unique : le jour ou un
       fonds portera un visuel d'enseigne, il suffira de le rendre ici. Aucune
       autre ligne du moteur n'est a modifier.

       Un local loue sans commerce installe (bail sans fondsId) n'a rien a
       montrer : on rend null, et le moteur n'affiche rien. */
    enseigne: function (buildingId, roomId, ville) {
      if (typeof getLocationPourRoom !== 'function') return null;
      const bail = getLocationPourRoom(buildingId, roomId, ville);
      if (!bail || !bail.fondsId) return null;

      const memo = PIECE_VARIANTES_MEMO_ENSEIGNE;
      if (Object.prototype.hasOwnProperty.call(memo, bail.fondsId)) return memo[bail.fondsId];
      if (typeof sbGetFonds !== 'function') return null;

      return sbGetFonds(bail.fondsId).then(function (fonds) {
        // Un fonds abandonne (bail termine cote serveur, miroir client en
        // retard) ne doit pas laisser son enseigne au mur.
        const actif = (typeof fondsEstActif === 'function') ? fondsEstActif(fonds) : !!fonds;
        if (!fonds || !actif) return null;

        // ---- POINT D'EXTENSION « Personnaliser mon commerce » -------------
        // Quand l'option premium existera, le fonds portera un visuel. La seule
        // ligne a ecrire est celle-ci ; elle est deja branchee, et le banc DOM
        // verifie que le mode image fonctionne de bout en bout.
        if (fonds.enseigneVisuel) {
          const v = { mode: 'image', image: fonds.enseigneVisuel };
          memo[bail.fondsId] = v;
          return v;
        }
        // -------------------------------------------------------------------

        if (!fonds.enseigne) return null;
        const v = { mode: 'texte', texte: fonds.enseigne };
        memo[bail.fondsId] = v;    // jamais de null memorise : voir ci-dessous
        return v;
      }).catch(function () { return null; });
    }
  }
};

/* Noms d'enseigne deja lus, par fondsId. Ce cache n'a jamais besoin d'etre vide,
   et c'est voulu :
   - un identifiant de fonds n'est jamais reattribue (fonds-republic-<horodatage>
     -<alea>), donc une entree ne peut pas designer deux commerces differents ;
   - a la resiliation le bail disparait, donc plus de fondsId, donc plus
     d'enseigne -- le cache n'est meme pas consulte ;
   - seuls les noms NON VIDES sont memorises : un fonds momentanement illisible
     (reseau coupe) sera relu a la prochaine visite au lieu de rester muet.
   Il n'y a donc aucun crochet a poser dans la logique de location, qui reste
   strictement inchangee. */
const PIECE_VARIANTES_MEMO_ENSEIGNE = {};


/* ---------------------------------------------------------------------------
   2. LES DECLARATIONS — de la donnee pure, extensible sans toucher au code
   --------------------------------------------------------------------------- */

/* Gabarit d'enseigne du centre commercial de Luthecia. Les quatre locaux
   partagent la meme police et le meme traitement ; seule la ZONE change, parce
   que le fronton n'a pas la meme largeur d'un local a l'autre. Ecrit une fois
   ici, reutilise quatre fois plus bas. */
const ENSEIGNE_FRONTON_LUTHECIA = {
  mode: 'texte',
  etats: ['occupee'],
  texte: {
    align: 'center',
    casse: 'majuscules',
    couleur: '#f3e3b4',
    ombre: true,
    graisse: 700,
    police: "'Playfair Display',Georgia,serif",
    interLettre: '.10em',
    tailleMax: 30
  },
  // Un visuel de joueur ne doit jamais etre deforme ni deborder du fronton :
  // 'contain' le fait entrer en entier dans la zone, en conservant ses
  // proportions. Declare des maintenant, pour que le jour ou un commerce
  // premium arrive, il n'y ait rien a ajouter ici non plus.
  image: { ajustement: 'contain' }
};

/* Un local libre porte une petite annonce dans son nom ; occupe, elle tombe.
   Une seule regle pour les quatre locaux -- et pour tous les centres commerciaux
   des autres villes le jour ou ils seront habilles. */
const NOM_LOCAL_LOUABLE = {
  occupee: { sansSuffixe: ' — Local à louer' }
};

/* Plaque doree vissee sur le montant de porte des bureaux du centre d'affaires.
   Gravure sombre sur laiton : ni ombre portee, ni majuscules forcees -- le mot
   « Cabinet : » est deja imprime sur l'image, et le nom se pose a sa suite. */
const ENSEIGNE_PLAQUE_MURALE = {
  mode: 'texte',
  etats: ['occupee'],
  texte: {
    align: 'center',
    casse: 'aucune',
    couleur: '#3b2d12',
    ombre: false,
    graisse: 600,
    police: "'Playfair Display',Georgia,serif",
    tailleMax: 15
  },
  image: { ajustement: 'contain' }
};

/* Plaque posee sur le plateau du bureau, dans l'Open Space. Vierge sur l'image :
   elle porte le nom du cabinet, ou « À LOUER » quand le poste est libre. */
const ENSEIGNE_PLAQUE_BUREAU = {
  mode: 'texte',
  etats: ['libre', 'occupee'],
  libelles: { libre: 'À LOUER' },
  texte: {
    align: 'center',
    casse: 'aucune',
    couleur: '#2e2208',
    ombre: false,
    graisse: 700,
    police: "'Playfair Display',Georgia,serif",
    interLettre: '.04em',
    tailleMax: 17
  },
  image: { ajustement: 'contain' }
};

/* Les quatre postes de l'Open Space de Luthecia. Meme image, meme plaque, meme
   zone : seule l'identite de la piece change. Ecrit une fois, et c'est deja la
   forme qu'aura n'importe quel autre open space du jeu. */
const OPEN_SPACE_LUTHECIA = ['a', 'b', 'c', 'd'];

function bureauxOpenSpaceLuthecia() {
  const sortie = {};
  OPEN_SPACE_LUTHECIA.forEach(function (lettre) {
    sortie['open_space_' + lettre] = {
      famille: 'location',
      ancrage: 'centre',
      nom: NOM_LOCAL_LOUABLE,
      desc: { occupee: "Poste de travail de l'open space. Le plateau est partagé, la plaque ne l'est pas." },
      images: {
        libre:   'images/luthecia-centre-affaires-bureau-open-space.png',
        occupee: 'images/luthecia-centre-affaires-bureau-open-space.png'
      },
      enseigne: Object.assign({}, ENSEIGNE_PLAQUE_BUREAU, {
        zone: { x: 0.452, y: 0.482, w: 0.117, h: 0.030 }
      })
    };
  });
  return sortie;
}

const PIECE_VARIANTES = {
  republic: {
    capitale: {
      'centre-commercial': {
        // Les quatre locaux, du plus cher au moins cher. Le nom de fichier dit
        // la taille du local (grand/moyen/petit/mini), la cle dit la piece.
        vitrine_principale: {
          famille: 'location',
          ancrage: 'haut',
          nom: NOM_LOCAL_LOUABLE,
          desc: { occupee: "Emplacement premium en façade, sur le flux principal de la galerie. Ce qui s'y installe se voit de loin." },
          images: {
            libre:   'images/luthecia-centre-commercial-grand-local-vide.png',
            occupee: 'images/luthecia-centre-commercial-grand-local-loue.png'
          },
          enseigne: Object.assign({}, ENSEIGNE_FRONTON_LUTHECIA, {
            zone: { x: 0.202, y: 0.172, w: 0.598, h: 0.057 }
          })
        },
        boutique_milieu: {
          famille: 'location',
          ancrage: 'haut',
          nom: NOM_LOCAL_LOUABLE,
          desc: { occupee: "Boutique de plain-pied, bon passage, à mi-chemin entre l'entrée et le fond de la galerie." },
          images: {
            libre:   'images/luthecia-centre-commercial-moyen-local-vide.png',
            occupee: 'images/luthecia-centre-commercial-moyen-local-loue.png'
          },
          enseigne: Object.assign({}, ENSEIGNE_FRONTON_LUTHECIA, {
            zone: { x: 0.226, y: 0.200, w: 0.547, h: 0.043 }
          })
        },
        arriere_boutique: {
          famille: 'location',
          ancrage: 'haut',
          nom: NOM_LOCAL_LOUABLE,
          desc: { occupee: "Arrière-boutique à l'écart du flux. On y entre sans être remarqué depuis la galerie." },
          images: {
            libre:   'images/luthecia-centre-commercial-petit-local-vide.png',
            occupee: 'images/luthecia-centre-commercial-petit-local-loue.png'
          },
          enseigne: Object.assign({}, ENSEIGNE_FRONTON_LUTHECIA, {
            zone: { x: 0.219, y: 0.183, w: 0.574, h: 0.059 }
          })
        },
        cave_reserve: {
          famille: 'location',
          ancrage: 'haut',
          nom: NOM_LOCAL_LOUABLE,
          desc: { occupee: "Sous-sol sans fenêtre, sous la galerie. Ce qui s'y passe ne se voit pas d'en haut." },
          images: {
            libre:   'images/luthecia-centre-commercial-mini-local-vide.png',
            occupee: 'images/luthecia-centre-commercial-mini-local-loue.png'
          },
          enseigne: Object.assign({}, ENSEIGNE_FRONTON_LUTHECIA, {
            zone: { x: 0.282, y: 0.179, w: 0.386, h: 0.064 }
          })
        }
      },

      /* ---- CENTRE D'AFFAIRES DE LUTHECIA (4 octobre 2026) ----------------
         Trois sortes de plaques, un seul mecanisme.

         Bureau Prestige et Bureau Standard portent une plaque doree sur le
         montant de porte. Les images « vide » ont deja « À LOUER » grave
         dessus : aucune incrustation n'y est donc declaree, l'etat libre ne
         figure pas dans `etats`. Les images « loue » portent « Cabinet : » et
         des lignes vierges : c'est la que le nom s'inscrit.

         Les quatre bureaux de l'Open Space partagent EXACTEMENT la meme image
         de poste de travail, dont la plaque posee sur le plateau est vierge.
         Celle-ci recoit donc soit le nom du cabinet, soit « À LOUER » quand le
         poste est libre -- un libelle fixe, sans aller-retour reseau.
         Ces quatre declarations sont identiques au nom pres : c'est precisement
         ce que la decision de game design demandait, et le moteur n'a rien eu
         a apprendre pour cela. */
      'centre-affaires': Object.assign({

        bureau_prestige: {
          famille: 'location',
          ancrage: 'haut',
          nom: NOM_LOCAL_LOUABLE,
          desc: { occupee: "Bureau d'angle, vue sur la ville. Le cabinet qui s'y installe reçoit ici." },
          images: {
            libre:   'images/luthecia-centre-affaires-bureau-prestige-vide.png',
            occupee: 'images/luthecia-centre-affaires-bureau-prestige-loue.png'
          },
          enseigne: Object.assign({}, ENSEIGNE_PLAQUE_MURALE, {
            zone: { x: 0.040, y: 0.345, w: 0.140, h: 0.055 }
          })
        },

        bureau_standard: {
          famille: 'location',
          ancrage: 'haut',
          nom: NOM_LOCAL_LOUABLE,
          desc: { occupee: "Bureau fermé donnant sur la salle de réunion. Discret, sans être caché." },
          images: {
            libre:   'images/luthecia-centre-affaires-bureau-standard-vide.png',
            occupee: 'images/luthecia-centre-affaires-bureau-standard-loue.png'
          },
          enseigne: Object.assign({}, ENSEIGNE_PLAQUE_MURALE, {
            zone: { x: 0.044, y: 0.348, w: 0.140, h: 0.055 }
          })
        },

        /* L'Open Space lui-meme n'est plus un local : c'est le PLAN des quatre
           postes. Pas de variante d'etat, pas d'enseigne -- juste une image
           fixe, posee par roomOverrides dans data.js, et des zones cliquables
           posees par plateau-open-space.js. */

      }, bureauxOpenSpaceLuthecia())
    }
  }
};


/* ---------------------------------------------------------------------------
   3. LE MOTEUR
   --------------------------------------------------------------------------- */

/* La declaration qui s'applique a cette piece, ou null. */
function varianteDePiece(buildingId, roomId, ville) {
  if (typeof state === 'undefined') return null;
  const pays = state.country;
  const cite = ville || state.currentCity;
  return PIECE_VARIANTES?.[pays]?.[cite]?.[buildingId]?.[roomId] || null;
}

/* L'etat courant d'une piece declaree, ou null si rien ne la declare. */
function varianteEtatPiece(buildingId, roomId, ville) {
  const decl = varianteDePiece(buildingId, roomId, ville);
  if (!decl) return null;
  const famille = PIECE_FAMILLES_ETAT[decl.famille];
  if (!famille || typeof famille.etat !== 'function') return null;
  return famille.etat(buildingId, roomId, ville || state.currentCity);
}

/* L'URL a afficher, ou null — c'est le seul point d'entree qu'appelle
   enterRoom pour l'image. Si l'etat rendu n'a pas d'image declaree, on ne
   force rien : la chaine habituelle reprend la main, donc jamais de trou. */
function varianteImagePiece(buildingId, roomId, ville) {
  const decl = varianteDePiece(buildingId, roomId, ville);
  if (!decl || !decl.images) return null;
  const etat = varianteEtatPiece(buildingId, roomId, ville);
  return (etat && decl.images[etat]) || null;
}


/* L'ancrage vertical declare pour cette piece, ou null si rien ne la declare.
   Lu par enterRoom, qui le pose en attribut sur le cadre. */
function varianteAncragePiece(buildingId, roomId, ville) {
  const decl = varianteDePiece(buildingId, roomId, ville);
  return (decl && decl.ancrage) || null;
}


/* LES TEXTES DE LA PIECE SELON SON ETAT — une seule regle, deux champs.

   Le nom et la description obeissent exactement au meme mecanisme : c'est
   volontaire, et c'est ce qui fait qu'un troisieme champ, demain, ne coutera
   qu'une ligne. Trois formes de regle, decrites en tete de fichier :

     'Un texte complet'            -> remplacement
     { sansPrefixe: '📋 À LOUER — ' } -> retrait en tete
     { sansSuffixe: ' — Local à louer' } -> retrait en queue

   Un retrait n'opere que si le texte commence (ou finit) VRAIMENT par le
   fragment declare. Si le libelle de base change un jour, la regle cesse
   d'agir au lieu de couper au mauvais endroit. */
function varianteRegleTexte(regle, base) {
  if (!regle || !base) return null;
  if (typeof regle === 'string') return regle;

  if (regle.sansPrefixe && base.startsWith(regle.sansPrefixe)) {
    return base.slice(regle.sansPrefixe.length).trim();
  }
  if (regle.sansSuffixe && base.endsWith(regle.sansSuffixe)) {
    return base.slice(0, base.length - regle.sansSuffixe.length).trim();
  }
  return null;
}

/* Resout un champ texte declare (`nom` ou `desc`) pour l'etat courant.
   Rend null si rien n'est declare -- auquel cas l'appelant garde son texte
   d'origine, donc une piece non declaree est inchangee au caractere pres.

   Le texte de base est PASSE plutot que relu ici : l'appelant a deja resolu la
   surcharge de ville, et le moteur n'a ni a refaire ce calcul ni a risquer d'en
   diverger. */
function varianteTextePiece(champ, buildingId, roomId, ville, base) {
  const decl = varianteDePiece(buildingId, roomId, ville);
  if (!decl || !decl[champ] || !base) return null;
  const etat = varianteEtatPiece(buildingId, roomId, ville);
  return varianteRegleTexte(etat && decl[champ][etat], base);
}

/* LE NOM DE LA PIECE. Appele a TROIS endroits -- le titre, l'onglet et le fil
   d'Ariane -- pour qu'ils ne se contredisent jamais. */
function varianteNomPiece(buildingId, roomId, ville, nomBase) {
  return varianteTextePiece('nom', buildingId, roomId, ville, nomBase);
}

/* LA DESCRIPTION DE LA PIECE. Un local libre fait sa publicite ; occupe, il
   decrit simplement l'endroit. Meme mecanisme que le nom, au mot pres. */
function varianteDescPiece(buildingId, roomId, ville, descBase) {
  return varianteTextePiece('desc', buildingId, roomId, ville, descBase);
}


/* --- Tailles naturelles des images, mesurees une fois puis memorisees ------ */

const PIECE_VARIANTES_TAILLES = {};

function varianteTailleNaturelle(url) {
  if (PIECE_VARIANTES_TAILLES[url]) return Promise.resolve(PIECE_VARIANTES_TAILLES[url]);
  return new Promise(function (resolve) {
    const img = new Image();
    img.onload = function () {
      const t = { l: img.naturalWidth, h: img.naturalHeight };
      if (t.l > 0 && t.h > 0) PIECE_VARIANTES_TAILLES[url] = t;
      resolve(PIECE_VARIANTES_TAILLES[url] || null);
    };
    img.onerror = function () { resolve(null); };
    img.src = url;
  });
}

/* Convertit une zone exprimee en fractions de l'image source en pixels du
   cadre, en refaisant le calcul de `background-size:cover` + `center`.
   Rend null si le cadre ou l'image n'ont pas encore de dimensions. */
function varianteZoneEnPixels(zone, cadre, taille, ancrage) {
  const cl = cadre.clientWidth, ch = cadre.clientHeight;
  if (!cl || !ch || !taille || !taille.l || !taille.h) return null;

  const echelle = Math.max(cl / taille.l, ch / taille.h);
  const dessinL = taille.l * echelle;
  const dessinH = taille.h * echelle;
  const origineX = (cl - dessinL) / 2;
  // Doit refleter EXACTEMENT le background-position applique par le CSS, sans
  // quoi le texte se decalerait du fronton : 'haut' => 0, 'centre' => centre.
  const origineY = (ancrage === 'haut') ? 0 : (ch - dessinH) / 2;

  return {
    gauche: origineX + zone.x * dessinL,
    haut:   origineY + zone.y * dessinH,
    largeur: zone.w * dessinL,
    hauteur: zone.h * dessinH
  };
}


/* --- L'enseigne ----------------------------------------------------------- */

/* Jeton de fraicheur : identifie la piece pour laquelle le dernier affichage a
   ete demande. Toute reponse asynchrone portant un autre jeton est ignoree. */
let varianteJetonCourant = '';

function varianteJeton(buildingId, roomId, ville) {
  return (state?.country || '') + '|' + (ville || state?.currentCity || '') + '|' + buildingId + '|' + roomId;
}

function varianteRetirerEnseigne(cadre) {
  const vieille = cadre.querySelector('.piece-enseigne');
  if (vieille) vieille.remove();
}

/* Normalise ce que rend une famille. Trois formes acceptees, pour que la
   famille reste simple a ecrire :
     null / ''            -> rien
     'Aux Souvenirs'      -> traite comme le mode par defaut du lieu
     {mode, texte|image}  -> forme complete
   Rend null quand il n'y a rien a montrer. */
function varianteNormaliserEnseigne(brut, modeParDefaut) {
  if (!brut) return null;
  if (typeof brut === 'string') {
    return brut.trim() ? { mode: modeParDefaut || 'texte', texte: brut } : null;
  }
  const mode = brut.mode || modeParDefaut || 'texte';
  if (mode === 'texte') return brut.texte ? { mode: 'texte', texte: brut.texte } : null;
  if (mode === 'image') return brut.image ? { mode: 'image', image: brut.image } : null;
  return null;                                   // mode 'aucune', ou inconnu
}

/* Pose (ou repositionne) l'element d'enseigne, selon le mode retenu. */
function varianteDessinerEnseigne(cadre, decl, contenu) {
  const conf = decl.enseigne;
  varianteRetirerEnseigne(cadre);
  if (!conf || !contenu) return;
  if (conf.mode === 'aucune') return;            // le lieu refuse toute enseigne

  const url = decl.images[varianteEtatPiece(cadre.dataset.varBat, cadre.dataset.varPiece)];
  if (!url) return;

  const el = document.createElement('div');
  el.className = 'piece-enseigne';
  el.classList.add('mode-' + contenu.mode);

  if (contenu.mode === 'image') {
    /* MODE IMAGE — l'enseigne est un visuel fourni par le jeu (demain : par le
       proprietaire du commerce, option « Personnaliser mon commerce »). Il entre
       dans la zone du fronton sans etre deforme ni la deborder ; aucun calibrage
       de police n'a lieu de ce cote. */
    const img = document.createElement('img');
    img.src = contenu.image;
    img.alt = '';
    img.style.maxWidth = '100%';
    img.style.maxHeight = '100%';
    img.style.objectFit = (conf.image && conf.image.ajustement) || 'contain';
    el.appendChild(img);
  } else {
    /* MODE TEXTE — le texte vit dans un SPAN interieur, et ce n'est pas
       cosmetique : c'est lui qu'on mesure. Sur le div lui-meme -- conteneur
       flex, contenu centre, overflow:hidden -- scrollWidth est toujours egal a
       clientWidth, parce qu'un debordement centre deborde des DEUX cotes et
       qu'aucun des deux n'est atteignable par defilement. Mesure a l'appui :
       842 contre 842, 783 contre 783. Calibrer le texte sur cette valeur
       revenait a comparer la boite a elle-meme, et la reduction se declenchait
       au hasard des arrondis au pixel (deux locaux sur quatre tombaient au
       plancher avec un nom de vingt caracteres qui tenait tres largement). Un
       span est un element de flex : il prend la largeur de son contenu, et
       offsetWidth la rapporte vraiment. */
    const t = conf.texte || {};
    const txt = document.createElement('span');
    txt.textContent = (t.casse === 'majuscules')
      ? String(contenu.texte).toLocaleUpperCase('fr-FR')
      : String(contenu.texte);
    el.appendChild(txt);
    el.style.textAlign = t.align || 'center';
    el.style.color = t.couleur || '#f3e3b4';
    el.style.fontFamily = t.police || "'Playfair Display',Georgia,serif";
    el.style.fontWeight = String(t.graisse || 700);
    if (t.interLettre) el.style.letterSpacing = t.interLettre;
    if (t.ombre) el.style.textShadow = '0 1px 2px rgba(0,0,0,.75), 0 0 10px rgba(0,0,0,.45)';
    el.title = String(contenu.texte);
  }

  cadre.appendChild(el);
  variantePositionnerEnseigne(cadre, conf, url, el, decl.ancrage);
}

/* Place l'enseigne sur le fronton, et -- en mode texte seulement -- calibre la
   police. Rappele a chaque changement de dimensions du cadre. */
function variantePositionnerEnseigne(cadre, conf, url, el, ancrage) {
  varianteTailleNaturelle(url).then(function (taille) {
    if (!el.isConnected) return;
    const px = varianteZoneEnPixels(conf.zone, cadre, taille, ancrage);
    if (!px) { el.style.display = 'none'; return; }

    const t = conf.texte || {};
    el.style.display = 'flex';
    el.style.left   = px.gauche + 'px';
    el.style.top    = px.haut + 'px';
    el.style.width  = px.largeur + 'px';
    el.style.height = px.hauteur + 'px';
    el.style.justifyContent = (t.align === 'left') ? 'flex-start'
                            : (t.align === 'right') ? 'flex-end' : 'center';

    // Le mode image n'a rien a calibrer : objectFit fait entrer le visuel.
    if (el.classList.contains('mode-image')) return;

    /* La taille du texte suit la hauteur du fronton, puis retrecit encore si le
       nom est trop long -- un nom de dix lettres et un nom de quarante doivent
       tous deux tenir dans le meme cartouche.

       La largeur visee n'est PAS celle du fronton, mais la plus petite des deux
       entre le fronton et le cadre : en fenetre etroite (telephone, colonne), le
       rognage horizontal de `cover` rend le fronton plus large que le cadre
       lui-meme -- mesure : fronton de 945 px dans un cadre de 620. Sans ce
       plafond, un nom long serait calibre sur une largeur dont la moitie est
       hors champ, et le joueur n'en verrait que le milieu. */
    const largeurUtile = Math.min(px.largeur, cadre.clientWidth);
    const txt = el.firstChild;
    let taillePolice = Math.min(px.hauteur * 0.62, t.tailleMax || 30);
    el.style.fontSize = taillePolice + 'px';
    let garde = 0;
    while (txt && txt.offsetWidth > largeurUtile && taillePolice > 9 && garde++ < 60) {
      taillePolice -= 0.5;
      el.style.fontSize = taillePolice + 'px';
    }
  });
}

/* Observateur unique : quand le cadre change de dimensions (fenetre, barre
   laterale, orientation), l'enseigne est repositionnee. Un seul observateur
   pour toute la partie, installe a la premiere utilisation. */
let varianteObservateur = null;

function varianteInstallerObservateur(cadre) {
  if (varianteObservateur || typeof ResizeObserver === 'undefined') return;
  varianteObservateur = new ResizeObserver(function () {
    const el = cadre.querySelector('.piece-enseigne');
    if (!el) return;
    const decl = varianteDePiece(cadre.dataset.varBat, cadre.dataset.varPiece);
    if (!decl || !decl.enseigne) return;
    const url = decl.images[varianteEtatPiece(cadre.dataset.varBat, cadre.dataset.varPiece)];
    if (url) variantePositionnerEnseigne(cadre, decl.enseigne, url, el, decl.ancrage);
  });
  varianteObservateur.observe(cadre);
}

/* POINT D'ENTREE appele par enterRoom apres la pose de l'image.
   Retire toujours l'enseigne precedente -- y compris quand la piece n'en a pas,
   sans quoi l'enseigne d'une boutique resterait affichee sur la piece suivante. */
function varianteAppliquerEnseigne(buildingId, roomId, ville) {
  const cadre = document.getElementById('piece-image');
  if (!cadre) return;

  const jeton = varianteJeton(buildingId, roomId, ville);
  varianteJetonCourant = jeton;
  cadre.dataset.varBat = buildingId;
  cadre.dataset.varPiece = roomId;
  varianteRetirerEnseigne(cadre);

  const decl = varianteDePiece(buildingId, roomId, ville);
  if (!decl || !decl.enseigne) return;

  const etat = varianteEtatPiece(buildingId, roomId, ville);
  const etatsAffiches = decl.enseigne.etats || [];
  if (etatsAffiches.indexOf(etat) === -1) return;

  varianteInstallerObservateur(cadre);

  if (decl.enseigne.mode === 'aucune') return;   // le lieu refuse toute enseigne

  /* LIBELLE FIXE. Certains etats n'ont rien a demander a personne : la plaque
     d'un bureau libre affiche « À LOUER », point. On court-circuite alors la
     famille, et l'affichage est immediat -- aucun aller-retour reseau pour un
     texte connu d'avance. */
  const fixe = decl.enseigne.libelles && decl.enseigne.libelles[etat];
  if (fixe) {
    varianteDessinerEnseigne(cadre, decl,
      varianteNormaliserEnseigne(fixe, decl.enseigne.mode));
    return;
  }

  const famille = PIECE_FAMILLES_ETAT[decl.famille];
  const brut = (famille && typeof famille.enseigne === 'function')
    ? famille.enseigne(buildingId, roomId, ville || state.currentCity)
    : null;

  const poser = function (valeur) {
    varianteDessinerEnseigne(cadre, decl,
      varianteNormaliserEnseigne(valeur, decl.enseigne.mode));
  };

  if (brut && typeof brut.then === 'function') {
    brut.then(function (valeur) {
      // Le joueur a-t-il change de piece pendant l'aller-retour ?
      if (varianteJetonCourant !== jeton) return;
      poser(valeur);
    }).catch(function () {});
  } else {
    poser(brut);
  }
}
