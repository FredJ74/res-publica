# Audit global Républia — 2 novembre 2026

## A. Synthèse générale et méthode

Branche : `codex/audit-global-republia-20261102`. Base réellement auditée :
`a99c406928ec7449f7dc11f5a447177c59b5452b` (`main`, #351 et #352 incluses).
`AGENTS.md`, `RELAIS.md`, `ARCHITECTURE.md`, `CONSTITUTION.md`, les audits PSM/Montrouge,
églises, clôture fonctionnelle et rapports de livraison ont été lus. Les travaux #219
sont conservés ; aucune migration, aucun changement d'un joueur, aucune fusion ni
modification de production dans ce chantier.

Le script réutilise **les vraies fonctions** `getBuildingContext`,
`ordresDeclaresDeLaPiece`, `personnesNormalesDeLaPiece` et le catalogue
`PIECE_VARIANTES`. Les surcharges, pièces supplémentaires, exclusions et images
par état sont prises en compte. Les ordres dynamiques, personnages mobiles et
permissions effectives de la base ne se déduisent pas de ce catalogue.

| Ville | Bâtiments déclarés | Pièces effectives | Occurrences PNJ | Ordres déclarés (occurrences) |
|---|---:|---:|---:|---:|
| Luthécia | 36 | 138 | 118 | 497 |
| Port-Sainte-Marie | 31 | 84 | 60 | 305 |
| Montrouge | 35 | 83 | 41 | 339 |

Total : **102 bâtiments, 305 pièces, 219 occurrences PNJ (188 noms),
1 141 occurrences d'ordres (308 identifiants distincts)**. Ce sont des déclarations
examinées, **pas 305 visites authentifiées**. Caserne/QHS : leurs scènes de rue
présentes dans Républia sont inventoriées, mais leurs intérieurs et les autres
empires ne font pas partie de la recette des trois villes.

**585 références d'images** contrôlées, dont 423 URL/chemins distincts :
305 fonds de pièces, 34 variantes, 110 portraits explicites, 50 images de scènes
(variantes d'arrivée incluses), trois fonds de ville et 83 replis masqués.
Le dossier contient **679 médias : 677 images raster et deux vidéos**.
Pillow a ouvert et vérifié les 677 images : **544 WebP, 102 JPEG, 31 PNG,
aucun fichier illisible** ; dimensions et formats sont dans l'annexe JSON.
Les 109 occurrences PNJ sans portrait explicite utilisent l'icône prévue :
ce ne sont pas automatiquement 109 images manquantes.

### Les trois catégories d'images

1. **Introuvables ou mal raccordées** : aucun fichier absent ni erreur de casse
   après décodage des URL (le PNG de salle de presse avec `%20` existe bien).
   Quatre images PSM présentes mais masquées par les variantes : **corrigé**.
2. **Provisoires** : **19 fonds de pièces Unsplash** et **six pièces sans image**,
   détaillés ci-dessous. Le vieux fond de ville Unsplash de Luthécia est un repli
   de l'ancien plan, pas une nouvelle illustration nécessaire aux scènes actuelles.
   Les 44 références Unsplash de replis déjà remplacés ne sont pas comptées comme
   44 commandes d'images supplémentaires.
3. **Locales présentes** : 515 occurrences (dont 39 replis masqués). Leur présence,
   format et sélection déclarative sont contrôlés ; cela ne certifie pas à soi
   seul la pertinence artistique de chaque image ou le bon cadrage en jeu.

Les quatre vues contextuelles du carrefour PSM sont **volontairement différentes**
(images, zones et directions). Elles sont conservées et testées à 1280 et 390 px.
Les images partagées de locaux occupés, les guides de musée, les fonds communs et
les icônes ne sont pas arbitrairement transformés en anomalies.

## B. Inventaire des illustrations à préparer

**25 emplacements** : 19 fonds web à remplacer, six absences à traiter si une
illustration dédiée est souhaitée. Cela n'impose pas 25 fichiers distincts :
une illustration commune peut rester volontaire. Aucun dessin produit ou retouché.
Pour les sources exactes, l'annexe JSON conserve chaque URL et la priorité de rendu.

| Ville | Bâtiment / pièce | Image actuelle | Pourquoi | Description précise à préparer |
|---|---|---|---|---|
| Luthécia | Palais de l'Elysee de Republia — `salle_reception` (Salle de Reception) | `https://images.unsplash.com/photo-1519167758481-83f550bb49b3?w=1200&q=80` | Photo web provisoire, non locale | Salle de réception officielle du palais républicain de Luthécia : salon d'apparat, tables de réception et protocole, sans emblème d'une autre ville ni personnage imposé. |
| Luthécia | Hôtel-Restaurant La Républia — `bar` (Bar) | `https://images.unsplash.com/photo-1572116469696-31de0f17cc34?w=1200&q=80` | Photo web provisoire, non locale | Bar intérieur du grand hôtel La Républia à Luthécia, comptoir et places assises ; même standing et palette que les autres vues locales de l'hôtel. |
| Luthécia | Hôtel-Restaurant La Républia — `chambres` (Chambres) | `https://images.unsplash.com/photo-1631049307264-da0ec9d70304?w=1200&q=80` | Photo web provisoire, non locale | Chambre standard de l'hôtel La Républia : lit, mobilier hôtelier et fenêtre ; ne pas la représenter comme la suite présidentielle déjà illustrée. |
| Luthécia | Assemblee Nationale — `hemicycle` (Hemicycle) | `https://images.unsplash.com/photo-1529107386315-e1a2ed48a620?w=1200&q=80` | Photo web provisoire, non locale | Hémicycle de l'Assemblée nationale de Républia, neuf sièges (trois par ville), tribune et organisation lisible ; aucune nouvelle fonction politique inventée. |
| Luthécia | Dispensaire Public de Luthecia — `salle_attente` (Salle d'attente) | `https://images.unsplash.com/photo-1584515933487-779824d29309?w=1200&q=80` | Photo web provisoire, non locale | Salle d'attente du dispensaire public de Luthécia : accueil médical, sièges et circulation vers les soins, cohérente avec les illustrations médicales locales. |
| Luthécia | Loge Maçonnique de Luthecia — `hall_loge` (Hall d'accueil) | `https://images.unsplash.com/photo-1578662996442-48f60103fc96?w=1200&q=80` | Photo web provisoire, non locale | Hall intérieur de la loge de Luthécia, accueil discret et symboles maçonniques ; ne pas utiliser une photo d'extérieur comme intérieur. |
| Luthécia | Loge Maçonnique de Luthecia — `bureau_venerable` (Bureau du Venerable Maitre) | `https://images.unsplash.com/photo-1497366216548-37526070297c?w=1200&q=80` | Photo web provisoire, non locale | Bureau du Vénérable Maître, dans la ville indiquée : bureau de travail, archives et symboles de loge. Un visuel commun est possible si volontaire, sans mention d'une autre ville. |
| Luthécia | Loge Maçonnique de Luthecia — `salle_reunion_loge` (Salle de Reunion) | `https://images.unsplash.com/photo-1541339907198-e08756dedf3f?w=1200&q=80` | Photo web provisoire, non locale | Salle de réunion de la loge de Luthécia : disposition de réunion et symboles maçonniques, cohérente avec le hall et le bureau ; pas de salle universitaire générique. |
| Luthécia | Université de Luthecia — `salle_reunion` (Salle de Réunion) | `https://images.unsplash.com/photo-1517502884422-41eaead166d4?w=1200&q=80` | Photo web provisoire, non locale | Salle de réunion de l'université de Luthécia : table de travail, bibliothèque et mobilier universitaire, même architecture que les pièces existantes. |
| Luthécia | Le Tabernacle des Impôts — `sacristie` (Sacristie Administrative) | `https://images.unsplash.com/photo-1568667256549-094345857aff?w=1200&q=80` | Photo web provisoire, non locale | Sacristie administrative du Tabernacle des Impôts : archives de confessions, formulaires et tampons, dans un décor religieux administratif ; aucun nouveau service. |
| Port-Sainte-Marie | Hôtel de Ville de Port-Sainte-Marie — `bureau_maire_local` (Bureau du Maire) | `https://images.unsplash.com/photo-1555848962-6e79363ec58f?w=1200&q=80` | Photo web provisoire, non locale | Bureau du maire de Port-Sainte-Marie, ambiance municipale portuaire, bureau et dossiers ; identité visuelle propre à PSM, sans inscription Luthécia. |
| Port-Sainte-Marie | Hôtel de Ville de Port-Sainte-Marie — `bureau_maire_adjoint` (Bureau du Maire Adjoint) | `https://images.unsplash.com/photo-1555848962-6e79363ec58f?w=1200&q=80` | Photo web provisoire, non locale | Bureau du maire adjoint de Port-Sainte-Marie, distinct du bureau du maire, dossiers et mobilier municipal ; même bâtiment et palette locale. |
| Port-Sainte-Marie | Port Industriel de Port-Sainte-Marie — `box_a_louer` (Box à louer) | Aucune (fond CSS) | Pas de décor illustré déclaré — à confirmer comme besoin graphique | Rangée de box de stockage individuels grillagés du port industriel de PSM, cadenas et accès portuaire ; ni logement ni entrepôt municipal, aucun bonus suggéré. |
| Port-Sainte-Marie | Pôle Tabac & Alcools Sainte-Mariannaise — `bureau_direction` (Bureau de Direction) | `https://images.unsplash.com/photo-1497366216548-37526070297c?w=1200&q=80` | Photo web provisoire, non locale | Bureau de direction du Pôle Tabac & Alcools Sainte-Mariannaise, dossiers de production et vue d'établissement industriel portuaire ; pas un ministère. |
| Port-Sainte-Marie | Pôle Tabac & Alcools Sainte-Mariannaise — `distillerie` (Distillerie) | `https://images.unsplash.com/photo-1569529465841-dfecdab7503b?w=1200&q=80` | Photo web provisoire, non locale | Atelier de distillation du pôle de PSM, alambics, cuves et conduites, cohérent avec l'établissement ; pas une simple bouteille en gros plan. |
| Port-Sainte-Marie | Pôle Tabac & Alcools Sainte-Mariannaise — `manufacture_tabac` (Manufacture de Tabac) | `https://images.unsplash.com/photo-1519669417670-68775a50919f?w=1200&q=80` | Photo web provisoire, non locale | Manufacture de tabac du pôle de PSM : lignes de transformation, feuilles et conditionnement, espace industriel lisible. |
| Port-Sainte-Marie | Entrepôt Logistique de Sainte-Marie — `bureau_direction` (Bureau de Direction) | `https://images.unsplash.com/photo-1497366216548-37526070297c?w=1200&q=80` | Photo web provisoire, non locale | Bureau du directeur de l'entrepôt logistique de PSM : planning, documents de stock et environnement de magasin logistique ; ne pas copier le nom de Luthécia. |
| Montrouge | Siege Syndical — `bureau_syndical` (Bureau syndical) | `https://images.unsplash.com/photo-1497366811353-6870744d04b2?w=1200&q=80` | Photo web provisoire, non locale | Bureau du siège syndical de Montrouge : réunions, affiches militantes et archives ouvrières, identité cheminote locale ; accès de rue à définir séparément. |
| Montrouge | Usine Principale — `direction_usine` (Direction) | `https://images.unsplash.com/photo-1565793298595-6a879b1d9492?w=1200&q=80` | Photo web provisoire, non locale | Bureau de direction de l'usine principale de Montrouge, dans son environnement ouvrier ; ne pas le confondre avec le bureau déjà illustré de la raffinerie. |
| Montrouge | Stade Marcel Cazenave — `vestiaires` (Vestiaire — Union Cheminote de Montrouge) | Aucune (fond CSS) | Pas de décor illustré déclaré — à confirmer comme besoin graphique | Vestiaire de l'Union Cheminote de Montrouge au stade Marcel Cazenave : bancs, casiers et équipement sportif, sans enseigne des clubs de Luthécia ou PSM. |
| Montrouge | Stade Marcel Cazenave — `buvette` (Buvette) | Aucune (fond CSS) | Pas de décor illustré déclaré — à confirmer comme besoin graphique | Buvette du stade Marcel Cazenave à Montrouge : comptoir de stade et accès supporters, distincte du Café des Cheminots en ville. |
| Montrouge | Stade Marcel Cazenave — `guichet_paris` (Guichet de Paris) | Aucune (fond CSS) | Pas de décor illustré déclaré — à confirmer comme besoin graphique | Guichet des paris du stade Marcel Cazenave : comptoir et affichage lié aux paris sportifs, sans inventer cotes ni règles de gain. |
| Montrouge | Stade Marcel Cazenave — `siege_supporters` (Siège des Supporters — Union Cheminote de Montrouge) | Aucune (fond CSS) | Pas de décor illustré déclaré — à confirmer comme besoin graphique | Siège des supporters de l'Union Cheminote de Montrouge : local collectif et culture de tribune cheminote, sans reproduire l'identité d'un autre club. |
| Montrouge | Zone de Production — `zone_recolte` (Zone de Récolte) | Aucune (fond CSS) | Pas de décor illustré déclaré — à confirmer comme besoin graphique | Zone de récolte de Montrouge : vocation exacte à confirmer avant création (le gabarit dit encore champs, mines ou forêts). Ne pas inventer une ressource ou un paysage productif. |
| Montrouge | Loge maçonnique de Montrouge — `bureau_venerable` (Bureau du Venerable Maitre) | `https://images.unsplash.com/photo-1497366216548-37526070297c?w=1200&q=80` | Photo web provisoire, non locale | Bureau du Vénérable Maître, dans la ville indiquée : bureau de travail, archives et symboles de loge. Un visuel commun est possible si volontaire, sans mention d'une autre ville. |

### Images déjà présentes mais sans référence littérale dans les scripts racine

Le détecteur relève **59 fichiers**, dont 16 images PJ sous `images/personnages/`
(non recopiées ici) et deux vidéos. Les **43 autres chemins** sont listés dans
l'annexe JSON. Ce n'est **pas une liste de fichiers à supprimer** : les escortes,
objets et médias peuvent avoir un chemin construit, un raccordement SQL ou une
référence en base. Aucun de ces contenus n'a été supprimé.

Cas résolus ou expliqués :

- Les quatre PNG du centre commercial PSM sont désormais sélectionnés à l'état
  libre par le moteur de variantes : ils étaient ajoutés et déclarés mais masqués.
- `images/montrouge/Montrouge_raffinerie_salle_ventes.png` est bien raccordée
  depuis #352 ; le bureau du commissaire `.jpg.png` existe et est un vrai PNG.
  Ne pas renommer un fichier correct parce que son extension est inhabituelle.
- `montrouge-musee-memoire-ouvriere.jpg` est **explicitement laissée en réserve**
  dans le commentaire de `data.js` : planche à plusieurs concepts, pas une septième salle.
- Le fichier de salle de presse avec espaces n'est ni absent ni orphelin :
  `%20` est décodé comme dans une URL de navigateur.
- Les médias récents de #325 et du commissariat/raffinerie sont présents ; aucun
  nouveau contenu de jeu raccordé arbitrairement à une illustration de réserve.

## C. Anomalies techniques, gravité et preuves

Aucun **P0 nouveau démontré** par cet audit. L'absence de test authentifié interdit
une conclusion générale sur les risques de production.

| ID | Gravité | Constat et preuve | État / clôture nécessaire |
|---|---|---|---|
| C01 | P1 | #351 : les trois directions passent au menu ministériel mais `coutActionPosteNomme` ne connaît pas leurs actes ; le débit peut retomber sur l'ordre d'ouverture du menu. Les six triples ont disparu du générateur. | **Corrigé** dans le dictionnaire commun existant : nommer 3 PA, révoquer 1 PA, 0 FR, identité de chaque ordre explicite. Consultation des candidatures inchangée. |
| C02 | P2 | #325 : la variante `libre` du centre commercial PSM pointe vers Luthécia et prime sur le PNG local. Quatre cas reproduits sur le vrai sélecteur. | **Corrigé** : seul le visuel libre local est remplacé. État occupé, nom, enseigne, loyers et moteur commun conservés. |
| C03 | P2 | Les profils de Marie Leblanc et Romain Castel nommaient respectivement l'hôtel La Républia et l'ancienne enseigne La Tribune ; leurs occurrences sont dans des rédactions. | **Corrigé** : « la rédaction du journal local », identité et profil existants conservés. Aucun personnage ni personnalité inventé. |
| C04 | P1 à confirmer en jeu | À Montrouge, aucune zone de scène ne mène à `tribunal-local`, `siege-syndical`, `usine-principale`, `zone-production`. La minimap est masquée lorsque les scènes sont actives. | Le raccordement de rue paraît incomplet. Confirmer sur serveur la liste des accès et arrêter les scènes/positions graphiques ; ne pas placer de zones au hasard ni contourner le déplacement serveur. |
| C05 | P1, préexistant | Le centre antipoison tire encore la réussite avec `Math.random` dans `doCentreAntiPoison` puis supprime l'empoisonnement à l'écran, après paiement. Déjà signalé par l'audit PSM/Montrouge. | À porter dans l'acte médical serveur existant et tester paiement/guérison/rejeu ensemble, avec le responsable santé/fiche. Aucune réécriture médicale improvisée dans cet audit. |
| C06 | P2 | 19 fonds web et six fonds CSS, inventaire B. | Préparer les illustrations réellement souhaitées, puis raccorder et vérifier le cadrage. Pas de génération approximative. |

### Constatations qui ne sont pas des suppressions à faire

- **Deux avocats volontairement non implantés** : Ali Bihanbéton et Henri Nossant.
  Le banc `banc-dialogue-pnj-republia.js` les déclare muets en attente de personnalité
  validée. La tentative d'un profil ordinaire a été retirée après relecture ; le
  diff final ne leur ajoute rien. Ils restent des PNJ de décor, sans statistique
  d'avocat ni avantage mécanique créé.
- **215 occurrences de dialogue** ont un identifiant trouvé dans la table serveur ;
  deux comptoirs d'agence sont interceptés avant l'écran PNJ et deux avocats sont
  volontairement muets. Le banc historique inclut aussi Jean Bonde, les PNJ de quête,
  les députés et les candidats Grobras : **43 épreuves réussies**. Huit députés et
  douze candidats Grobras sont encore déclarés sans dialogue ; pas de personnalité
  inventée pour remplir une liste.
- Sept noms fixes sont réutilisés entre villes : Romain Castel, Marie Leblanc,
  Frère Gardien, Vénérable Maître Duval, Sabri Coledur, Céd' Labone, Henrico Stot.
  Ce réemploi du gabarit est constaté, **pas une preuve d'un doublon de personnage
  en base**. Décider si ces identités sont communes ou doivent devenir locales
  avant de les renommer ou de changer leur mémoire.
- Les noms génériques (maire, guichetier, brigadier…) ne prouvent pas une identité
  commune. La présence PNJ n'est pas utilisée ici pour attribuer un poste PJ.
- Les occurrences multiples de Jodie, du guide de musée, du religieux, d'une
  secrétaire ou de gardes ne sont pas retirées sans règle explicite : certains
  personnages accompagnent une visite ou ont un profil/contextualisation de lieu.
- Dix anciens `buildingContext` concernent des identifiants hors liste locale
  (anciens hôtel, commissariat, banque, dispensaire ; presse/marché à PSM). Ils
  ne sont pas des pièces accessibles supplémentaires. Pas de purge sans preuve
  qu'aucun circuit de compatibilité ne les lit.

## D. Corrections, fichiers, commits et vérifications

Corrections de jeu limitées à :

- `plateau-variantes-pieces.js` : PSM libre, sélection via le moteur existant.
- `plateau-politique.js` : six coûts d'actes dans `ACTIONS_POSTE_NOMME`, conservation
  des contrats municipaux et du coût de consultation des candidatures.
- `api/_pnj-personnalites.js` : lieu des deux journalistes, aucune identité changée.
- `plateau.html` : versions de cache des deux scripts JS modifiés montées.

Outils et preuves :

- `auditer-republia-complet.cjs` : inventaire fusionné des pièces/images/PNJ/ordres.
- `auditer-raccordements-republia.cjs` : vrais slugs/profils, routes littérales,
  expressions régulières, route directe et génériques ; graphe des rues.
- `contre-audit-republia.cjs` : sur le SHA initial, les **dix défauts** sont reproduits
  sans modification de fichier (quatre variantes, six contrats de paiement).
- `test-audit-global-republia.mjs` : chemins encodés/casse/absence, variantes par état,
  choix de ne pas inventer de PNJ, raccordements, coûts et non-régression #352,
  contexte des journalistes.
- Banc locations renforcé et banc Chromium existant étendu ; aucun test retiré.

Commits de travail déjà poussés : `1fd5c48f`, `36781b09`. La branche conserve
l'historique de correction ; c'est le **diff final contre main** qui doit être revu,
notamment le retrait des profils d'avocats provisoirement ajoutés.

### Résultats

| Contrôle | Résultat et portée |
|---|---|
| Audit de toutes les déclarations | 102 bâtiments / 305 pièces / 219 occurrences PNJ / 308 ordres uniques |
| Images du dossier | 677 images raster décodables, zéro erreur ; deux vidéos non décodées comme images |
| Raccordements des images sélectionnées | Zéro fichier absent / erreur de casse ; quatre raccordements PSM réparés |
| Routes | 297 littérales, trois par expressions régulières, une directe au rendu (`postuler`), quatre génériques présents dans le seed, trois volontairement grisées ; zéro route déclarative non identifiée |
| Appels du routeur | 430 identifiants de fonctions appelées ; aucune déclaration manquante dans les scripts chargés, builtins exclus ; pas une preuve de succès de chaque action |
| Graphe de rue | 46 nœuds, zéro lien vers un nœud inexistant ; quatre vues PSM conservées |
| Chromium réel, environnement local | 2/2 (1280 et 390 px) : retours Luthécia/PSM, quatre arrivées PSM, décodage des quatre locaux dans leurs deux états |
| Banc locations PSM | Réussi : mêmes pièces, ordres, loyers et enseignes ; vérification de l'image effectivement sélectionnée |
| Dialogue PNJ historique | 43/43 ; secrets/auth/prompts protégés, muets déclarés conservés |
| Tests ciblés de cet audit | 8/8 sur le code final |
| Contre-épreuves | Dix défauts du main initial effectivement reproduits |
| Contrôles globaux | **12/12 sur la branche** ; main initial **10/12**, échecs Baseline/Referential expliqués par les six tarifs supprimés de la source. Ni baseline, ni référence, ni mesure modifiés pour obtenir ce résultat |

Le contrôleur client a été exécuté plusieurs fois : une première erreur a détecté
le raccordement non autorisé des avocats ; il a été annulé. Un autre passage a
révélé un test exigeant le préfixe de cache historique : ce préfixe a été conservé
et la nouvelle version ajoutée en suffixe, sans désactiver le test. Le résultat
final de la chaîne et les contrôles distants sont consignés à la fin du rapport.

## E. Travaux restant à clôturer

1. **Accès des quatre bâtiments de Montrouge** : confirmer la carte serveur actuelle,
   choisir les scènes/positions réelles et fournir si besoin les vues de rue adaptées.
   Ne pas inventer une position graphique sur une façade sans rapport.
2. **Illustrations du tableau B** : remplacer les 19 photos web ; confirmer les six
   besoins de décor absents. La vocation de la zone de production doit être précisée
   avant création. Les images communes restent possibles si voulues.
3. **Identités PNJ réemployées** : vérifier l'intention pour les sept noms ci-dessus ;
   si une identité locale est souhaitée, définir son nom et son corpus sans réinitialiser
   un PNJ existant. Personnalités des deux avocats et des autres muets déclarés à
   valider avant implantation. Les icônes ne sont pas des erreurs de fichier.
4. **Antipoison** : reprise coordonnée du traitement serveur, sans nouveau moteur.
5. **Lecture réelle Supabase / sessions** : aucun outil Supabase exposé ici ; aucune
   nouvelle lecture des titulaires, PNJ vivants, stocks, catalogues ou droits/RLS.
   Les quatre routes génériques sont attestées dans le seed, pas recertifiées sur
   la base vivante. Nominations/révocations, recrutements, achats/ventes, production,
   transports et candidatures n'ont pas été exécutés avec un joueur réel.
6. **Recette authentifiée** : Arnie n'a pas été connecté dans cette intervention.
   Le workflow existant et ses secrets ne sont pas accessibles via l'API GitHub
   (`Forbidden`). Les contrôles locaux ne prouvent pas que tous les bâtiments sont
   fonctionnels en jeu. Aucun élargissement de l'autorisation du personnage.
7. **Diffusion et relecture** : comparer le SHA final au main le plus récent, faire
   passer la CI distante et relire le petit lot ; pas de fusion si une garde échoue.
   Aucun déploiement Vercel de test demandé. Une lecture des ressources publiques
   Vercel a été tentée : tunnel réseau refusé HTTP 403, pas une panne Vercel établie.
8. **Candidats sans référence littérale** : les 43 chemins publics hors portraits PJ
   restent à confronter aux chemins construits et à la base avant toute suppression.
   La réserve du musée est déjà expliquée ; ne pas créer de salle supplémentaire.

## F. État distinct par ville

### Luthécia

36 bâtiments et 138 pièces examinés. Dix fonds de pièces Unsplash à remplacer.
Tous les bâtiments ont au moins une zone dans les scènes ; cela ne remplace pas
le contrôle des restrictions serveur. Les sous-pièces d'open space sont masquées
par choix et accessibles par les zones de l'open space ; les chambres de clinique
ont leur entrée dédiée. Le PNG de presse avec espaces est valide. Le ministère
conserve #351, avec ses six tarifs maintenant raccordés au paiement existant.
Les deux métadonnées journalistiques sont corrigées ; aucune identité ni mémoire
n'est supprimée. Immobilier et socle #219 non modifiés.

### Port-Sainte-Marie

31 bâtiments et 84 pièces examinés. Six fonds web et le box portuaire sans fond
illustré sont listés. Tous les bâtiments ont une zone déclarée. Les quatre vues
contextuelles du carrefour sont conservées. Les locaux libres affichent leurs PNG
locaux au lieu du décor de Luthécia ; les états occupés communs sont conservés,
sans enseigne déplacée sur une illustration incompatible. L'avocat Ali Bihanbéton
reste volontairement non implanté pour le dialogue.

### Montrouge

35 bâtiments et 83 pièces examinés. Trois fonds web et cinq pièces sans image.
La salle des ventes de #352 et le bureau du commissaire sont bien raccordés.
Les six terrains ont un sélecteur existant ; ils ne sont pas classés comme six
bâtiments privés d'accès. Quatre autres bâtiments n'ont pas de zone de rue repérée.
Les six salles du musée sont illustrées et sa planche de réserve reste en réserve.
L'avocat Henri Nossant reste volontairement non implanté pour le dialogue.

## Annexe — couverture bâtiment par bâtiment

Le fichier `AUDIT-GLOBAL-REPUBLIA-20261102.json` contient les **305 lignes de pièces**
(avec surcharges et variantes), 219 occurrences PNJ, les ordres et leurs conditions,
les chemins d'images exacts, les formats/dimensions et les diagnostics de routes.
Aucune donnée privée, aucun export Supabase n'y figure : seulement des déclarations
et fichiers déjà présents dans le dépôt.

| Ville | ID / bâtiment | Pièces examinées | Accès repéré en code |
|---|---|---:|---|
| Luthécia | `palais-presidentiel` — Palais de l'Elysee de Republia | 4 | Zone de rue déclarée |
| Luthécia | `hotel-republica` — Hôtel-Restaurant La Républia | 6 | Zone de rue déclarée |
| Luthécia | `palais-gouvernement` — Palais du Gouvernement | 11 | Zone de rue déclarée |
| Luthécia | `assemblee` — Assemblee Nationale | 4 | Zone de rue déclarée |
| Luthécia | `tribunal` — Tribunal de Luthecia | 3 | Zone de rue déclarée |
| Luthécia | `banque-nationale` — Banque Nationale de Republia | 2 | Zone de rue déclarée |
| Luthécia | `banque-privee` — Banque Privée Helvetia | 1 | Zone de rue déclarée |
| Luthécia | `clinique-privee` — Clinique Privée Saint-Luc | 11 | Zone de rue déclarée |
| Luthécia | `dispensaire-public` — Dispensaire Public de Luthecia | 2 | Zone de rue déclarée |
| Luthécia | `commissariat` — Commissariat Central de Luthecia | 3 | Zone de rue déclarée |
| Luthécia | `la-tribune` — L'Autruche Entravée | 2 | Zone de rue déclarée |
| Luthécia | `loge-maconnique` — Loge Maçonnique de Luthecia | 4 | Zone de rue déclarée |
| Luthécia | `universite` — Université de Luthecia | 2 | Zone de rue déclarée |
| Luthécia | `armurerie` — Armurerie Martinon | 1 | Zone de rue déclarée |
| Luthécia | `marche` — Marché Central de Luthecia | 1 | Zone de rue déclarée |
| Luthécia | `mairie-capitale` — Hotel de Ville de Luthecia | 5 | Zone de rue déclarée |
| Luthécia | `tabernacle-impots` — Le Tabernacle des Impôts | 2 | Zone de rue déclarée |
| Luthécia | `centre-multinodal-luthecia` — Centre Multinodal de Luthecia | 3 | Zone de rue déclarée |
| Luthécia | `centre-commercial` — Centre Commercial | 5 | Zone de rue déclarée |
| Luthécia | `centre-artisanal` — Centre Artisanal | 4 | Zone de rue déclarée |
| Luthécia | `centre-affaires` — Centre d'Affaires | 9 | Zone de rue déclarée |
| Luthécia | `terrain-a-batir-1` — Terrain a batir - Lot 1 (La Châtaigneraie) | 1 | Zone de rue déclarée |
| Luthécia | `terrain-a-batir-2` — Terrain a batir - Lot 2 (La Châtaigneraie) | 1 | Zone de rue déclarée |
| Luthécia | `terrain-a-batir-3` — Terrain a batir - Lot 3 (La Châtaigneraie) | 1 | Zone de rue déclarée |
| Luthécia | `terrain-a-batir-4` — Terrain a batir - Lot 4 (La Châtaigneraie) | 1 | Zone de rue déclarée |
| Luthécia | `terrain-a-batir-5` — Terrain a batir - Lot 5 (La Châtaigneraie) | 1 | Zone de rue déclarée |
| Luthécia | `office-notarial` — Office Notarial — Maître Dubois & Associés | 4 | Zone de rue déclarée |
| Luthécia | `stade` — Stade Gourgeot — Olympique de Luthécia | 6 | Zone de rue déclarée |
| Luthécia | `quartier-ambassades` — Quartier des Ambassades | 5 | Zone de rue déclarée |
| Luthécia | `place-formulaire-liberte` — Place du Formulaire de la Liberté | 1 | Zone de rue déclarée |
| Luthécia | `musee-ville-luthecia` — Musée de la Ville de Luthécia | 12 | Zone de rue déclarée |
| Luthécia | `musee-national-republia` — Musée National de Republia | 12 | Zone de rue déclarée |
| Luthécia | `parc-botanique-national` — Parc Botanique National de Républia | 2 | Zone de rue déclarée |
| Luthécia | `entrepot-logistique-luthecia` — Entrepôt Logistique de Luthécia | 2 | Zone de rue déclarée |
| Luthécia | `usine-pharmaceutique-luthecia` — Usine Pharmaceutique Impériale de Républia | 3 | Zone de rue déclarée |
| Luthécia | `bureau-national-emploi` — Bureau National de l'Emploi | 1 | Zone de rue déclarée |
| Port-Sainte-Marie | `hotel-port` — Hotel du Port | 2 | Zone de rue déclarée |
| Port-Sainte-Marie | `mairie` — Hôtel de Ville de Port-Sainte-Marie | 5 | Zone de rue déclarée |
| Port-Sainte-Marie | `banque-locale` — Banque Locale | 2 | Zone de rue déclarée |
| Port-Sainte-Marie | `dispensaire-public-v` — Dispensaire Public | 2 | Zone de rue déclarée |
| Port-Sainte-Marie | `commissariat-local` — Commissariat Local | 3 | Zone de rue déclarée |
| Port-Sainte-Marie | `tribunal-local` — Tribunal Municipal | 3 | Zone de rue déclarée |
| Port-Sainte-Marie | `bar-des-pecheurs` — Bar des Pecheurs | 1 | Zone de rue déclarée |
| Port-Sainte-Marie | `imprimerie-librairie` — Imprimerie-Librairie Gutenberg | 2 | Zone de rue déclarée |
| Port-Sainte-Marie | `centre-multinodal-port-sainte-marie` — Centre Multinodal de Port-Sainte-Marie | 1 | Zone de rue déclarée |
| Port-Sainte-Marie | `port-sainte-marie` — Port Industriel de Port-Sainte-Marie | 7 | Zone de rue déclarée |
| Port-Sainte-Marie | `port-plaisance-psm` — Port de Plaisance de Port-Sainte-Marie | 2 | Zone de rue déclarée |
| Port-Sainte-Marie | `centre-commercial` — Centre Commercial | 5 | Zone de rue déclarée |
| Port-Sainte-Marie | `centre-artisanal` — Centre Artisanal | 4 | Zone de rue déclarée |
| Port-Sainte-Marie | `centre-affaires` — Centre d'Affaires | 6 | Zone de rue déclarée |
| Port-Sainte-Marie | `terrain-a-batir-8` — Terrain a batir - Lot 8 | 1 | Zone de rue déclarée |
| Port-Sainte-Marie | `terrain-a-batir-9` — Terrain a batir - Lot 9 | 1 | Zone de rue déclarée |
| Port-Sainte-Marie | `terrain-a-batir-10` — Terrain a batir - Lot 10 | 1 | Zone de rue déclarée |
| Port-Sainte-Marie | `terrain-a-batir-11` — Terrain a batir - Lot 11 | 1 | Zone de rue déclarée |
| Port-Sainte-Marie | `stade` — Stade de La Brise Mariannaise | 6 | Zone de rue déclarée |
| Port-Sainte-Marie | `zone-production` — Scierie Guy Tarembois | 1 | Zone de rue déclarée |
| Port-Sainte-Marie | `capitaine-sauvage` — Le Capitaine Sauvage | 1 | Zone de rue déclarée |
| Port-Sainte-Marie | `chasse-peche-psm` — Maison Le Gall — Chasse et Pêche | 1 | Zone de rue déclarée |
| Port-Sainte-Marie | `place-armes-psm` — Place d'Armes de Port-Sainte-Marie | 1 | Zone de rue déclarée |
| Port-Sainte-Marie | `ecole-marine` — Ecole de Marine de Port-Sainte-Marie | 2 | Zone de rue déclarée |
| Port-Sainte-Marie | `chantier-naval` — Chantier Naval de Port-Sainte-Marie | 2 | Zone de rue déclarée |
| Port-Sainte-Marie | `notre-dame-mer` — Notre-Dame de la Mer & Cimetière Marin | 3 | Zone de rue déclarée |
| Port-Sainte-Marie | `phare-psm` — Phare de Port-Sainte-Marie | 1 | Zone de rue déclarée |
| Port-Sainte-Marie | `marche-psm` — Marche de Port-Sainte-Marie | 1 | Zone de rue déclarée |
| Port-Sainte-Marie | `musee-port-sainte-marie` — Musée de Port Sainte Marie | 10 | Zone de rue déclarée |
| Port-Sainte-Marie | `pole-tabac-alcools-psm` — Pôle Tabac & Alcools Sainte-Mariannaise | 4 | Zone de rue déclarée |
| Port-Sainte-Marie | `entrepot-logistique-psm` — Entrepôt Logistique de Sainte-Marie | 2 | Zone de rue déclarée |
| Montrouge | `hotel-mineur` — Hôtel de la Victoire | 2 | Zone de rue déclarée |
| Montrouge | `mairie` — Hôtel de Ville de Montrouge | 5 | Zone de rue déclarée |
| Montrouge | `banque-locale` — Banque Cheminote de Montrouge | 2 | Zone de rue déclarée |
| Montrouge | `dispensaire-public-v` — Hôpital de Montrouge | 2 | Zone de rue déclarée |
| Montrouge | `commissariat-local` — Commissariat de Montrouge | 3 | Zone de rue déclarée |
| Montrouge | `tribunal-local` — Tribunal Municipal | 3 | **Aucune zone repérée** |
| Montrouge | `siege-syndical` — Siege Syndical | 1 | **Aucune zone repérée** |
| Montrouge | `usine-principale` — Usine Principale | 1 | **Aucune zone repérée** |
| Montrouge | `centre-multinodal-montrouge` — Gare de Montrouge | 1 | Zone de rue déclarée |
| Montrouge | `centre-commercial` — Centre commercial de Montrouge | 5 | Zone de rue déclarée |
| Montrouge | `centre-artisanal` — Centre artisanal de Montrouge | 4 | Zone de rue déclarée |
| Montrouge | `centre-affaires` — Centre d'affaires de Montrouge | 6 | Zone de rue déclarée |
| Montrouge | `terrain-a-batir-6` — Terrains à vendre | 1 | Sélecteur existant des terrains |
| Montrouge | `terrain-a-batir-montrouge-3` — Terrain a batir - Lot 3 (Montrouge) | 1 | Sélecteur existant des terrains |
| Montrouge | `terrain-a-batir-montrouge-7` — Terrain a batir - Lot 7 (Montrouge) | 1 | Sélecteur existant des terrains |
| Montrouge | `terrain-a-batir-montrouge-8` — Terrain a batir - Lot 8 (Montrouge) | 1 | Sélecteur existant des terrains |
| Montrouge | `terrain-a-batir-montrouge-9` — Terrain a batir - Lot 9 (Montrouge) | 1 | Sélecteur existant des terrains |
| Montrouge | `terrain-a-batir-montrouge-12` — Terrain a batir - Lot 12 (Montrouge) | 1 | Sélecteur existant des terrains |
| Montrouge | `stade` — Stade Marcel Cazenave | 6 | Zone de rue déclarée |
| Montrouge | `zone-production` — Zone de Production | 1 | **Aucune zone repérée** |
| Montrouge | `entrepot-logistique-montrouge` — Entrepôt logistique de Montrouge | 2 | Zone de rue déclarée |
| Montrouge | `raffinerie-montrouge` — Raffinerie de Montrouge | 3 | Zone de rue déclarée |
| Montrouge | `armurerie` — Armurerie-Quincaillerie de Montrouge | 1 | Zone de rue déclarée |
| Montrouge | `loge-maconnique` — Loge maçonnique de Montrouge | 4 | Zone de rue déclarée |
| Montrouge | `la-tribune` — Le Cheminot Informé (LCI) | 3 | Zone de rue déclarée |
| Montrouge | `marche` — Marché de Montrouge | 1 | Zone de rue déclarée |
| Montrouge | `cafe-gare-montrouge` — Café de la Gare | 1 | Zone de rue déclarée |
| Montrouge | `brasserie-voyageurs-montrouge` — Brasserie des Voyageurs | 1 | Zone de rue déclarée |
| Montrouge | `musee-histoire-montrouge` — Musée de l'Histoire de Montrouge — Autour du Rail | 7 | Zone de rue déclarée |
| Montrouge | `eglise-montrouge` — Église Progressiste de Montrouge | 1 | Zone de rue déclarée |
| Montrouge | `cinema-montrouge` — Cinéma de Montrouge | 3 | Zone de rue déclarée |
| Montrouge | `jardins-ouvriers-montrouge` — Jardins ouvriers | 1 | Zone de rue déclarée |
| Montrouge | `logements-montrouge` — Logements | 5 | Zone de rue déclarée |
| Montrouge | `cafe-tabac-cheminots-montrouge` — Café des Cheminots — Bar-Tabac | 1 | Zone de rue déclarée |
| Montrouge | `place-du-rail-montrouge` — Place du Rail | 1 | Zone de rue déclarée |
