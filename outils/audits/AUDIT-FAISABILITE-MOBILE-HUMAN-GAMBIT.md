# Faisabilité mobile de Human Gambit

**Audit du 6 novembre 2026 — aucun développement applicatif, aucune écriture Supabase, aucun déploiement.**

Source examinée : `main` **304633e0**, dans une branche documentaire isolée
`codex/audit-mobile-20261106`. Lecture d'`AGENTS.md`, `RELAIS.md`, de l'architecture
et des composants existants ; aucun chevauchement avec le raccordement de Sovarka.

## Synthèse pour Fred

**Le jeu peut devenir jouable sur Android et iPhone sans refaire son moteur.**
L'essentiel du travail concerne la place disponible, les fenêtres, les gestes tactiles
et la reprise de session. Un simple ajout de quelques règles CSS ne suffira pas :
le plateau en portrait ne laisse actuellement presque aucune largeur à la scène,
plusieurs boutons du bandeau sont hors écran, et l'éditeur de forum ne déplace pas
ses objets au doigt.

Estimation de préparation au développement, pas engagement de délai :

- **Première journée de jeu mobile réellement praticable : 18 à 30 jours-personne**,
  en privilégiant navigation, consultation, transactions ordinaires et messages simples.
- **Couverture complète et agréable des fonctions existantes : 36 à 61 jours-personne**,
  marge de recette comprise ; environ 7 à 12 semaines pour une personne à temps plein.
- Une PWA installable peut ensuite demander **2 à 4 jours-personne supplémentaires**.
  Elle n'est pas nécessaire pour commencer à jouer sur téléphone et ne corrige aucun
  problème de disposition à elle seule.

Ces fourchettes supposent les moteurs actuels fonctionnels et un environnement de
recette isolé disponible. Elles excluent les réparations métier indépendantes, le
travail de Sovarka, une application native et la création de nouvelles illustrations.
La première tranche de mesures sur vrais appareils doit affiner l'estimation.

**Recommandation : une seule application web responsive, puis éventuellement une PWA.
Aucun second moteur, aucune nouvelle règle de jeu.**

## 1. Méthode, preuves et limites

### Essais réellement exécutés

Playwright avec Chromium **local**, HTML/CSS du dépôt, six formats CSS :

| Format | Largeur × hauteur | Entrée |
|---|---:|---|
| iPhone compact simulé | 375 × 667 | tactile Chromium |
| iPhone récent simulé | 393 × 852 | tactile Chromium |
| Grand Android simulé | 412 × 915 | tactile Chromium |
| Paysage smartphone | 852 × 393 | tactile Chromium |
| Tablette portrait | 768 × 1024 | tactile Chromium |
| Ordinateur témoin | 1440 × 900 | souris Chromium |

**120 états mesurés** : 20 par format (accueil, connexion, huit étapes de création,
plateau brut, rue illustrée, bâtiment, cinq fenêtres, chat/journal, hauteur réduite).
**22 captures**, aucune erreur JavaScript dans ces parcours de mesure. Ce nombre
n'est ni un nombre de tests métier réussis ni une preuve de jouabilité intégrale.

- Création : vrais scripts `data.js`, i18n et `creation.js`, passage par `goTo()` et
  ses rendus ; pays et nom fictifs injectés en mémoire. Ni authentification ni validation
  finale de création. Aucun compte créé.
- Plateau : HTML/CSS réels ; scripts métier neutralisés afin de ne démarrer aucune
  synchronisation ou sauvegarde. Les personnes, intitulés de pièces, données des modales
  et listes de forum sont des **fixtures**, pas un personnage connecté.
- La rue illustrée reprend la structure et les changements d'affichage du chemin
  `updateRueView` et une vraie image du dépôt. Les flèches restent inertes.
- **Contre-épreuve tactile exécutée sur le vrai contrôleur `rpCanvasCreateController`** :
  un glissement tactile laisse l'objet à `(20,20)`, le même déplacement à la souris
  le mène à `(80,80)`. Aucun sujet de forum créé ni publié.
- Réduction à 350 px de haut et focus dans le mail : mesure d'un espace réduit,
  **pas ouverture d'un véritable clavier Android/iOS**.
- Toutes les requêtes extérieures sont bloquées ; seuls les fichiers locaux peuvent
  être lus. Les polices Google et les icônes CDN ne sont donc pas chargées : leurs
  métriques finales peuvent varier. Les colonnes fixes et les gestes souris restent,
  eux, directement vérifiables. Les captures sont des reproductions locales signalées.

### Ce qui n'a pas été vérifié

**Aucun Safari iOS réel, aucun Chrome Android sur appareil physique, aucun compte PJ,
aucune transaction, aucun combat et aucun ordre exécuté en production.** La continuité
métier est examinée dans le code, pas certifiée par ces captures. Le serveur n'est pas
audité ni déclaré conforme par cette mission.

Accès public à `https://res-publica.vercel.app/plateau.html` tenté : refus du proxy
`CONNECT 403 / Envoy`. Cela ne signifie pas que le site est en panne. La version de
production n'est pas vérifiée ; l'audit porte sur le SHA source indiqué.

Les PNG et JSON cités sont dans l’[archive vérifiée](mobile-20261106/PREUVES.md#archive-vérifiée) ; leurs noms sont conservés dans son index.

Les relevés `horsCadre`/`ciblesPetites` sont des diagnostics géométriques limités à
quelques occurrences. Ils peuvent inclure des éléments derrière une modale ; ne pas
les interpréter comme un compteur exhaustif de défauts accessibles au joueur.

Preuves : [mesures JSON](mobile-20261106/PREUVES.md#archive-vérifiée),
[contre-épreuve tactile](mobile-20261106/PREUVES.md#archive-vérifiée),
[dispositif de reproduction](mobile-20261106/README.md).

## 2. État actuel

### Fondations réutilisables

- HTML/CSS/JavaScript communs, pas de rendu dépendant d'une application native.
- Métadonnée viewport dans les deux pages ; accueil déjà adapté aux petits écrans,
  `100dvh`, marges de sécurité sur son panneau et règles portrait/paysage
  ([style.css:101](../../style.css#L101), [425](../../style.css#L425)).
- Modales communes à largeur relative, hauteur maximale dynamique et défilement ;
  champs plafonnés à 100 % ; classes `cpj-dialogue`, `cpj-champ`, `cpj-touche`.
- Commerce et militaire possèdent déjà des règles de repli
  ([style.css:1813](../../style.css#L1813), [2000](../../style.css#L2000)).
- Les flèches de rue ont déjà une boîte de **46 × 46 px** : ne pas les remplacer ni
  diminuer leurs cibles ([rue-centrale.css:49](../../rue-centrale.css#L49)).
- Les moteurs serveur, confirmations, révisions et intentions de transaction sont
  réutilisables tels quels ; l'adaptation ne doit pas déplacer leur autorité vers l'écran.

### Mesures qui empêchent une journée complète aujourd'hui

| Format | Largeur centrale après colonne personnage | Scène rue illustrée | Image de pièce avec fixture de quatre onglets |
|---|---:|---:|---:|
| 375 × 667 | 175 px | 0 px | 0 px |
| 393 × 852 | 193 px | 0 px | 0 px |
| 412 × 915 | 212 px | 0 px | 12 px |
| 852 × 393 | 652 px | 412 px | 452 px, minimum 280 px de haut |
| 768 × 1024 | 568 px | 328 px | 368 px |
| 1440 × 900 | 1240 px | 1000 px | 1040 px |

L'absence de débordement du **document** n'est pas un succès : `overflow:hidden`
masque une partie de l'interface. À 375 px, « Messages/Forums » commence à environ
436 px et est inaccessible visuellement dans la coque testée. En paysage, « Plan »
commence vers 895 px pour une largeur disponible de 852 px.

## 3. Inventaire hiérarchisé des problèmes

Les solutions ci-dessous sont **proposées, non implémentées**. « Risque » décrit
le risque de la future modification sur ordinateur, pas une régression introduite ici.

| ID / gravité | Écran et source précise | Défaut / reproduction | Solution envisagée | Risque ordinateur |
|---|---|---|---|---|
| M01 **Bloquant** | Plateau — [style.css:611](../../style.css#L611), [663](../../style.css#L663), [703](../../style.css#L703) | Colonnes 200 + 240/200 px ; scène nulle ou minuscule en portrait. Ouvrir les fixtures 375–412. | Replier les **mêmes** panneaux personnage/personnes en tiroirs ou pop-ups ; scène pleine largeur sous seuil mesuré ; conserver le layout large. | Élevé si règles globales ; limiter les surcharges aux petits écrans et comparer à 1440. |
| M02 **Bloquant** | Bandeau — [plateau.html:182](../../plateau.html#L182), [style.css:586](../../style.css#L586) | Flex sans retour, commandes coupées jusqu'en tablette ; pas de défilement utile de page. | Regrouper les accès existants dans un menu tactile, en gardant états/badges et destinations ; aucun ordre supprimé. | Moyen, tester badges, clics et largeur 1024/1440. |
| M03 **Important** | Rues — [plateau-navigation.js:201](../../plateau-navigation.js#L201), [plateau-rue-centrale.js:1600](../../plateau-rue-centrale.js#L1600), [rue-centrale.css:30](../../rue-centrale.css#L30) | Au retour de la largeur, risque de flèches superposées et zones trop étroites ; `max-height:78vh` à comparer au ratio réel. | Conserver image/zones/directions ; mesurer rectangles réels, cibles ≥44 px quand possible et accès équivalent au bâtiment par liste existante. Jamais étirer indépendamment image et hotspots. | Élevé : régression géométrique possible, tester chaque provenance PSM. |
| M04 **Important** | Info-bulles — [plateau-navigation.js:112](../../plateau-navigation.js#L112), [plateau-rue-centrale.js:1693](../../plateau-rue-centrale.js#L1693) | Descriptions attachées à `mouseenter`/`mousemove`, sans garantie d'équivalent tactile. Le clic d'entrée existe : ne pas prétendre que toute navigation exige le survol. | Rendre nom et description accessibles au focus/toucher, sans déclencher une seconde commande et sans modifier les zones. | Moyen ; vérifier souris, doigt et nettoyage de la bulle. |
| M05 **Important** | Pièces — [plateau.html:421](../../plateau.html#L421), [style.css:691](../../style.css#L691) | Quatre onglets gonflent l'en-tête ; minimum image 280 px coupé en paysage, actions en bas masquées par le conteneur. | En-tête compact, onglets accessibles/défilants, zone centrale flexible et un défilement principal maîtrisé. | Moyen ; ne pas intervertir les pièces ni leurs droits. |
| M06 **Important** | Modales — [style.css:1047](../../style.css#L1047), [2115](../../style.css#L2115), [2196](../../style.css#L2196) | Coques plutôt adaptées, mais défilements imbriqués et fermeture haute à certifier sur longues fiches ; petite hauteur et clavier non garantis. | Réutiliser modales, en-tête/fermeture stables, contenu défilant, restauration focus/scroll et viewport dynamique. | Moyen, mutualiser avant de corriger chaque écran. |
| M07 **Important** | Toucher — bandeau, création, fermetures : [style.css:573](../../style.css#L573), [605](../../style.css#L605), [2203](../../style.css#L2203) | Boutons de bandeau mesurés à 33 px de haut, plusieurs contrôles de création <44 ; `cpj-*` minimum 36 seulement. | Cible indicative 44 × 44 CSS px (pas une garantie de conformité WCAG), espacement et focus visibles ; icône inchangée dans une cible plus grande. | Faible à moyen, éviter de densifier les tableaux larges. |
| M08 **Important, risque iOS** | Saisie — [plateau.html:621](../../plateau.html#L621), [629](../../plateau.html#L629), [style.css:1090](../../style.css#L1090) | Mail/PNJ autour de .85/.95rem, soit 13.6/15.2 px avec racine 16 ; zoom de focus Safari possible, clavier et barre URL non simulés fidèlement. | Champs ≥16 px sur téléphone, `dvh` avec repli, focus dans zone visible ; étudier `visualViewport` seulement si nécessaire. Ne pas interdire le zoom. | Faible si limité aux champs en petit écran. |
| M09 **Bloquant pour forum complet** | Forum — [style.css:1208](../../style.css#L1208), [1254](../../style.css#L1254), [1261](../../style.css#L1261), [forum.js:966](../../forum.js#L966) | Sidebar 200 px ; sujet sur grille à quatre colonnes fixes totalisant 430 px + titre ; fixture 375 : main 155 px, contenu 489 px. | Même forum et contrôles d'accès ; navigation de rubrique repliable, lignes en cartes sous seuil, réponses lisibles. | Moyen, tester anciens et nouveaux posts, compteurs et changement de territoire. |
| M10 **Bloquant pour édition complète** | Compositeur — [forum-canvas.js:76](../../forum-canvas.js#L76), [238](../../forum-canvas.js#L238), [329](../../forum-canvas.js#L329) | Lecture 680 px par défaut avec scroll horizontal ; drag/resize `mousedown/mousemove`. Glissement tactile réellement sans effet, souris efficace. | Adapter le **contrôleur existant** aux Pointer Events, arbitrer scroll/drag par poignée, maintenir sérialisation ; mode de lecture adapté sans réécrire les anciens posts. | Élevé ; contre-épreuves souris, texte, image, resize, ordre des couches, posts historiques. |
| M11 **Important** | Chat et journal — [plateau.html:473](../../plateau.html#L473), [861](../../plateau.html#L861) | Journal 300 px/100vh, chat 300 × 380 px à bottom 80 ; chat commence à y≈−67 en paysage 393 px (hors écran). Recouvrement possible des commandes. | Dimensionner dans espace visible, gérer une seule couche active et le retour au contexte ; conserver messages et journal. | Moyen ; z-index, toast et badges à vérifier. |
| M12 **Important** | Création — [creation.js:383](../../creation.js#L383), [708](../../creation.js#L708), [style.css:483](../../style.css#L483), [521](../../style.css#L521) | Création parcourable par scroll local mais grilles 2/3 colonnes et lignes stats serrées ; à 375 l'étape stats atteint ≈1618 px. Ce long scroll n'est pas à lui seul un blocage. | Repli des choix, contrôles ± accessibles, explications gardées, boutons suivant/précédent visibles sans écraser la saisie. | Faible, avec tests six langues et bureau. |
| M13 **Important, périmètre à tester** | Gestion — [style.css:1768](../../style.css#L1768), [1950](../../style.css#L1950), [plateau-commerce-pj.js:382](../../plateau-commerce-pj.js#L382) | Écrans cpj/mil disposent de replis ; anciens tableaux métier et styles inline restent hétérogènes. Pas de preuve que tous débordent. | Inventorier rendus encore exécutables, préférer classes communes et cartes ou scroll de tableau explicite ; confirmer achats/banque avec mêmes RPC. | Élevé côté interaction : double clic, mauvaise ligne ou perte de nonce. |
| M14 **Important, risque à certifier** | Reprise — [plateau-core.js:1003](../../plateau-core.js#L1003), [1542](../../plateau-core.js#L1542), [supabase.js:2142](../../supabase.js#L2142), [5397](../../supabase.js#L5397) | Reprise d'app, réseau mobile et destruction d'onglet ne garantissent pas `beforeunload`. Le filet `pagehide/keepalive` existe déjà : ne pas le recréer. | Éprouver reprise/expiration/réponse perdue avec mécanismes actuels ; resynchroniser avant ordre, aucune dépense ou navigation optimiste hors verdict serveur. | Élevé pour données ; aucun changement sans bancs atomiques et tests isolés. |
| M15 **Important** | Chargement — [plateau.html:656](../../plateau.html#L656), [index.html:268](../../index.html#L268) | 62 scripts locaux déclarés, **7 260 760 octets bruts** au plateau ; 7 scripts/1 426 184 octets à l'entrée. Cela n'est pas le poids HTTP compressé ni le trafic facturé. | Mesurer traces réseau/parse/interaction ; charger par domaine seulement après inventaire des dépendances et préserver ordre/cache. Optimiser images par variantes sans toucher les originaux. | Élevé si découpage prématuré des globals ; faire après shell. |
| M16 **Important, risque à mesurer** | Illustrations — `images/`, [style.css:664](../../style.css#L664), [704](../../style.css#L704) | Bibliothèque 750 fichiers ; certains PNG proches de 3 Mo. Pas tous chargés simultanément. `cover` de pièces peut cacher un sujet en portrait. | Mesurer images réellement demandées, formats/dimensions et `srcset` quand pertinent ; conserver raccord image/zones, identité visuelle et pas de préchargement global. | Moyen, régressions de cadrage et de textes peints. |
| M17 **Mineur / confort ultérieur** | Installation | Aucune déclaration de manifest/service worker trouvée dans les points d'entrée examinés. | PWA après stabilisation ; installation, icônes et mise à jour contrôlée. Ne pas faire croire à un mode jeu hors connexion. | Moyen si cache mal ciblé ; aucune réponse privée ou RPC mise en cache. |

## 4. Continuité des treize parcours

« Examiné » ne signifie pas « joué sur un compte ». Aucun essai final d'un ordre ici.

| Parcours | Chaîne existante examinée | État et recette future de bout en bout |
|---|---|---|
| Connexion / création | `index.html` → `creation.js` (`ouvrirConnexionCompte`, `goTo`, rendus) → auth/Supabase | Accueil et étapes rendus localement, non authentifiés. Tester vrai clavier, erreur identifiants, email confirmé et fin de création sur compte isolé. |
| Plateau | `plateau.html` → `plateau-core.js` (`state`, updateUI) | Bloqué en portrait ; ouvrir menus, lire PA/liquide/statut, accéder à tous panneaux sans perte de scène. |
| Rues | `updateRueView` → `plateau-rue-centrale.js` → position serveur | Géométrie inspectée, pas de déplacement exécuté. Tester allers/retours et quatre provenances PSM, toucher sans survol, annulation/refus. |
| Entrée / sortie | `enterBuilding` et `sortirBatiment` dans `plateau-navigation.js:366/1575` | Même flux serveur à garder ; vérifier sortie à faible hauteur, réponse perdue, personnage changé et refus policier. |
| Pièces | `plateau.html:421`, onglets et rendu pièce dans `plateau-navigation.js` | Fixture de quatre onglets mesurée. Tester retour, onglet courant et accès privé sans contourner restrictions. |
| Ordres | `plateau-router.js:895` → coûts/verdict dans `plateau-core.js:2483/2521` | Fenêtre commune mesurée. Tests futurs succès/refus/double tap/confirmer-annuler ; jamais déduire PA/argent localement pour mobile. |
| PNJ | `plateau-pnj.js:732` (`openPnjModal`) → dialogue serveur `/api/chat` | Longue réponse fixture dans vraie modale. Conversation IA, clavier, défilement et reprise non testés sur serveur. |
| Inventaire / fiche | `plateau-personnage.js:9/392/4017` → consultations et commandes inventaire existantes | Panneau gauche et coque fiche inspectés ; contenu réel non injecté. Déplier, défiler 100 objets, ouvrir fiche/action puis retour, adopter réponse révisée. |
| Banque / commerce | `plateau-justice-economie.js`, `plateau-commerce-pj.js:382/2162` → RPC existantes | Grilles communes analysées, aucune opération financière. Tester espèces/banque séparées, fonds insuffisants, replay, mauvaise connexion ; rester même propriétaire/ligne après rotation. |
| Forum / mails / journal | `forum.js:966`, `forum-canvas.js`, `plateau-communication.js:1232/1245`, journal flottant | Fixture de liste, mail réel HTML, vrai drag testé. Lire/répondre/composer puis revenir, anciennes publications, comptes et caches territoriaux non certifiés ici. |
| Organisations / institutions | `plateau-organisations-quetes.js`, `plateau-politique.js`, modale postes commune | Chaînes et tableaux inspectés ; tous rôles non joués. Tester membre/dirigeant/non-membre avec fixtures autorisées, sans modifier POP/INF ni pouvoirs. |
| Groupes / police / combats | `supabase.js` (contexte groupe/verdict), `plateau-politique.js:11821` (`ouvrirPanneauCombat`) → RPC | Source et rapport de rounds examinés ; aucun affrontement exécuté. Tester engagements/refus, round long, détection, indisponibilité, recharge et rapport historique sur base isolée. |
| Sommeil / récupération / notifications | `plateau-personnage.js:1953/3216` (`doDormir`, chambre), lifecycle core, journal | Réponses/identité protégées dans le chemin existant à conserver. Tester repos unique, retour d'app et journal d'événements serveur ; aucune notification push promise. |

Un portrait de téléphone doit permettre **toutes** ces transitions sans obligation
de tourner l'appareil, de zoomer à l'extrême ou d'actualiser pour retrouver un bouton.
L'écran paysage doit rester utilisable, pas être proposé comme palliatif obligatoire.

## 5. Architecture cible et compatibilité

| Option | Apport | Coût / limites | Conclusion |
|---|---|---|---|
| Web responsive commun | Même HTML, composants, transactions et déploiement ; accès par URL sur iOS/Android/ordinateur. | Adapter shell, tableaux et gestes ; recette réelle nécessaire. | **Choix recommandé d'abord.** |
| Responsive + PWA | Même jeu avec lancement depuis l'écran d'accueil et mode fenêtre installé. | Manifest/icônes, politique de mise à jour et validation iOS ; aucun bénéfice automatique pour clavier ou tactile. | **Option de confort après MVP**, sans promesse de jeu hors ligne. |
| Application native | Possibilité d'intégrations système spécifiques. | Deux chaînes de livraison, stores, maintenance et risque de recréer des écrans/états divergents ; moteur serveur reste nécessaire. | Non justifiée par les défauts observés ; aucune estimation native ferme sans besoin supplémentaire. |

### Faire évoluer l'existant

1. Garder `style.css`, `rue-centrale.css`, `plateau.html` et les modales communes.
   Définir des seuils d'après la largeur utile du **contenu**, pas un modèle de téléphone.
   Pas de `/mobile` avec copie des fonctions, pas de routeur métier distinct, pas de
   détection iPhone/Android pour les permissions.
2. Replier les panneaux du plateau tout en conservant leur DOM/état et les destinations
   existantes. Les sous-menus restent dans des pop-ups de la charte bleu-gris.
3. Ajouter les comportements tactiles **au contrôleur commun** ; les gestes ne doivent
   ni doubler les clics ni empêcher le défilement de toute la page. `touch-action`
   doit être limité aux poignées qui en ont besoin, avec gestion `pointercancel`.
4. Tous les ordres gardent les mêmes RPC, contrôles d'identité/contexte, autorité de
   position, révisions et clés d'idempotence. Désactiver un bouton en attente ne
   remplace pas le refus transactionnel serveur. Ne pas envoyer de commandes lors
   d'un simple changement d'orientation, de focus ou de disposition.
5. Ne pas changer les données, économies, pouvoirs ou échéances pour simplifier un écran.
   Aucune consultation périodique supplémentaire ; les échéances autonomes restent
   côté serveur et la reprise utilise les mécanismes existants.
6. La performance se traite par mesures et chargement ciblé **après** inventaire des
   globals et des dépendances. Pas de conversion vers un framework obligatoire.

### Safari iOS / Chrome Android : exigences de recette

- Chromium à dimensions iPhone ne simule pas WebKit. Utiliser au moins un iPhone
  physique, puis un Android physique, y compris clavier ouvert et navigateur installé
  si PWA retenue. Playwright WebKit serait un complément, pas un substitut de l'iPhone.
- `dvh` existe dans les navigateurs modernes (iOS 15.4+, Chrome 108+) ; fixer une
  matrice de versions de test lors du lot 0. Les replis `vh` doivent rester lisibles.
  Ne pas promettre le support de tous les anciens appareils sans mesure.
- Barres d'URL ouvertes/fermées, encoche et safe areas, rotation pendant modale,
  zoom à 200 %, taille de texte système, focus et copier/coller doivent être éprouvés.
- `:has()` présent dans l'éditeur : amélioration visuelle à traiter comme telle pour
  versions anciennes ; ne pas en faire une condition métier.
- App mise en arrière-plan, processus supprimé, retour après expiration, deux appareils,
  réseau coupé et réponse perdue : jamais rejouer une dépense sous une nouvelle clé.
- Les notifications actuelles sont d'abord des informations dans le jeu. Des push
  système seraient un sujet distinct ; une PWA ne doit pas s'arroger ce périmètre.

### PWA et données sensibles

Si décidée ultérieurement : manifest et icônes, `display` et lancement revus, puis
éventuellement cache des **seules ressources publiques versionnées**. Ne pas stocker
les réponses auth/RPC, soldes, fiches, inventaires, forums privés ou données de session
dans un cache hors ligne. Ne pas ajouter de file d'ordres différés. L'absence de réseau
reste un refus/une confirmation incertaine avec la réconciliation existante.
Une mise à jour ne doit pas recharger brutalement une page pendant un paiement.

## 6. Plan de réalisation proposé

Effort en jours-personne techniques, code + tests de lot. Aucun lot n'est autorisé
par ce rapport ; une mission d'implémentation distincte sera nécessaire.

| Lot / priorité | Objectif et composants | Dépendances | Tests et critères d'acceptation | Effort |
|---|---|---|---|---:|
| L0 / P0 | Figer matrice appareils, scénarios et contrats communs ; inventorier rendus actifs et mesures de référence. | Aucun | Captures bureau/téléphone et parcours listés, comptes isolés autorisés, règles de hauteur/focus documentées. | 1–2 j |
| L1 / P0 | Shell responsive, bandeau, personnage/personnes, accès inventaire et journal (`plateau.html`, CSS). | L0 | À 375/393/412 et paysage : aucune commande essentielle coupée, scène utile pleine largeur, retour au même contexte ; témoin 1440 inchangé. | 3–5 j |
| L2 / P0 | Rues, flèches, hotspots, entrée/sortie, pièces, équivalent des info-bulles. | L1 | Toucher/souris, quatre provenances PSM, image/zones concordantes, refus serveur et réponse perdue sans déplacement fictif. | 2–4 j |
| L3 / P0 | Coques modales, clavier, focus, scroll, confirmations, chat. | L0 ; finalisation avec L1 | Long contenu puis fermeture/retour accessibles en portrait/paysage et clavier réel ; pas de double action après tap/rotation. | 3–5 j |
| L4 / P1 | Connexion et création, caractéristiques, six langues (`creation.js`, index/CSS). | L0 et conventions L3 | Étapes complètes sur compte isolé, lecture des choix, saisie/photo, erreurs sans perte ; aucun changement du calcul des caractéristiques. | 2–3 j |
| L5 / P0 | Inventaire, fiche, commerce, banque et tableaux transactionnels. | L1/L3 | Achat/vente/don/dépôt/retrait sur fixtures, 100 objets, solde nul, fonds insuffisants, double tap, réponse tardive/replay ; serveur seul fait foi. | 3–5 j |
| L6 / P1 | Forums/messages : navigation, lecture des posts, composition et gestes du même moteur. | L3 ; mise en page L1 | Lecture/réponse/création, privé/local/national, post historique 680 px, souris et vrai toucher, clavier et retour sans perdre le brouillon. | 5–8 j |
| L7 / P1 | Organisations, institutions, groupes/police/combat : adaptations des écrans métier restants. | L3 ; fixtures L0 | Tableaux longs, participants, rapports de rounds, permissions et interceptions inchangées ; compte isolé pour actions à effets. | 3–5 j |
| L8 / P0 | Reprise/session, calendrier, sommeil et notifications dans l'UI. | L1/L3 et bancs existants | Verrouillage téléphone, expiration, perte réseau, retour d'app, deux appareils ; aucun paiement/PA/objet doublé et aucune perte de notification. | 2–4 j |
| L9 / P1 | Images et chargement par domaine après mesures. | L0 ; stabilisation L1 | Comparer réseau/CPU/temps d'interaction cache froid/chaud sur appareils cibles ; pas d'ordre perdu ou de fonction absente ; budgets fixés après mesure. | 2–4 j |
| L10 / P0 sortie | Recette croisée appareils et bureau, corrections et marge de régression. | Lots couvrant périmètre livré | Une journée complète sans refresh de secours, toutes fenêtres critiques, zéro régression argent/inventaire/position ; preuves sur SHA livré. | 4–6 j |

Total brut : **30 à 51 jours-personne**. Provision d'incertitude d'environ 20 %
(appareils réels, états métier nombreux, styles inline) : **36 à 61 jours-personne**.
La somme suppose un développeur connaissant le projet ; multiplier les agents ne
réduit pas linéairement le délai, en particulier sur `style.css` et les composants partagés.

**Travail parallélisable sans collisions :** après L0 et accord sur la coque, L4
peut avancer séparément ; L6 peut travailler sur les contrôleurs forum pendant L5
sur les tableaux commerciaux ; L9 peut relever les poids pendant L1–L3.
Un propriétaire unique de la coque/CSS communs doit intégrer les modifications.
L2 dépend de la géométrie L1 ; L7 réutilise L3 ; L10 ne se remplace pas par des tests
isolés réussis. Réconcilier chaque lot au `main` courant et préserver Sovarka.

Pas de migration Supabase attendue pour une adaptation visuelle. Si un défaut de
transaction réel est découvert pendant la recette, l'isoler, ne pas le « réparer »
par une écriture du navigateur et réestimer son coût hors lot visuel.

## 7. Première version mobile jouable

### Journée minimale à démontrer sur un compte isolé

1. Se connecter, reprendre le même personnage, lire PA/liquide/état et événements.
2. Parcourir une rue illustrée, choisir une façade, entrer, changer de pièce et sortir.
3. Lire une réponse PNJ et saisir une question, sans clavier qui bloque la fermeture.
4. Ouvrir inventaire/fiche, consulter puis réaliser une action existante autorisée.
5. Acheter/vendre un article, consulter banque et faire une opération autorisée dans
   l'environnement isolé ; refuser fonds insuffisants et répéter sans double débit.
6. Lire forums/messages/journal et envoyer une réponse textuelle avec les composants
   existants ; les mises en page avancées restent un confort à finaliser, pas un moteur bis.
7. Consulter groupe/institution et lire un rapport de combat ; un état serveur interdit
   doit empêcher l'ordre sans dépense même si l'écran était resté inactif.
8. Se reposer selon les règles existantes, mettre le téléphone en veille, reprendre puis
   se reconnecter sans perdre le personnage ni appliquer deux fois une action.

Le périmètre **18–30 jours-personne** correspond à L0–L5 essentiels, partie simple de
L6/L7, L8 et une recette ciblée L10. Ce n'est pas une promesse d'édition avancée,
de gestion exhaustive de toutes les institutions ou d'optimisation de chaque illustration.
Les fonctions non adaptées doivent être recensées explicitement avant d'appeler la
version « pleinement mobile » ; ne pas les supprimer ou masquer comme si elles n'existaient pas.

### Confort ultérieur

PWA, gestes avancés et édition libre confortable, réglages fins des grandes tables,
optimisation complète de la bibliothèque graphique, davantage de tailles/appareils.
Le support des commandes essentielles au doigt, les refus explicites, le clavier et
l'absence de pertes/doubles opérations ne sont **pas** du confort optionnel.

## 8. Captures et état de livraison de l'audit

Toutes les images suivantes sont **locales, sans compte connecté** :

- [Plateau compact — bandeau coupé](mobile-20261106/PREUVES.md#archive-vérifiée)
- [Rue illustrée compact — scène réduite à zéro](mobile-20261106/PREUVES.md#archive-vérifiée)
- [Bâtiment compact — onglets et scène](mobile-20261106/PREUVES.md#archive-vérifiée)
- [Forum compact — colonnes](mobile-20261106/PREUVES.md#archive-vérifiée)
- [PNJ compact — longue réponse fixture](mobile-20261106/PREUVES.md#archive-vérifiée)
- [Création — caractéristiques](mobile-20261106/PREUVES.md#archive-vérifiée)
- [Ordre — coque commune longue](mobile-20261106/PREUVES.md#archive-vérifiée)
- [Mail avec hauteur réduite, pas un clavier réel](mobile-20261106/PREUVES.md#archive-vérifiée)
- [Paysage — chat et journal](mobile-20261106/PREUVES.md#archive-vérifiée)
- [Bureau témoin](mobile-20261106/PREUVES.md#archive-vérifiée)

Le dossier de preuves fournit une archive ZIP encodée dans `PREUVES.md` avec les
captures, mesures, scripts de collecte **d’audit uniquement** et leurs SHA-256.
Ce conditionnement exclusivement Markdown respecte le garde-fou Vercel sans le modifier.
Son application distante dépend du SHA précédent et des paramètres du projet ;
aucune absence de Preview distante n’est certifiée par un contrôle local.
Les liens ci-dessus renvoient au paquet ; les noms des PNG identifient chaque capture. Aucun fichier applicatif n'est modifié.
Les essais sont locaux ; aucun état de CI, de Supabase ou de Vercel n'est déclaré vert
sur la base de ces mesures. Aucune PR ne doit être fusionnée par cette mission.

**Conclusion de faisabilité : favorable, avec un chantier d'interface substantiel.
Le moteur unique peut être conservé ; le jeu actuel n'est pas certifié jouable sur
smartphone. L'implémentation reste à autoriser.**
