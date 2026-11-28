# Al Madina, capitale d'Al-Khalija — teaser (décisions de Fred, 28/11/2026)

Décision 17 de `GAME-DESIGN-LANCEMENT.md`, codée le 28/11/2026. Migrations : `20261128020000` (frontière, rue, accès
réservés), `20261128030000` (gestes, PNJ, secrets, backgammon), `20261128040000` (tarifs doublés).

## Ouverture

- Seule Al Madina est ouverte dans Al-Khalija (`frontieres_fermees` garde ville_a et ville_b) ; dans la capitale, seuls
  le **centre multimodal** et l'**Hôtel Royal d'Al-Khalija** sont ouverts (`navigation_lieux_regles.ferme`).
- Une vue de rue (`al-madina-rue`, image `Al_Madina_centre_multimodal_exterieur.webp`) avec deux bâtiments cliquables :
  le centre multimodal (à gauche) et l'hôtel (à droite). La flèche du bas affiche « Accès interdit ! » et le « ? » du
  compteur d'ouverture (mêmes conditions et même texte qu'à Ciudad Roja, voir `GAME-DESIGN-CIUDAD-ROJA.md`).
- Centre multimodal : règles du teaser (seul l'avion vers les autres capitales fonctionne), sans PNJ nommés ni ordre
  exclusif pour l'instant.

## Hôtel Royal d'Al-Khalija

- Ancien « Hôtel Al-Nour Palace » ; les anciens PNJ (Hassan Marchandage, Yasmine Épices…) ne sont plus à l'hôtel.
- Monnaie : **dinar royal (DR)**. **Tous les prix de l'hôtel sont le double de l'équivalent en Républia** (chiffres
  ci-dessous déjà doublés ; ordres habituels : réserver une chambre 160 DR, dîner d'affaires 600 DR, service d'étage
  300 DR).
- Pièces : réception (`accueil`), suite (`chambres`), restaurant, salon de thé (pièce serveur `bar`, mixte), salon des
  gentlemen (hommes), hammam des hommes, hammam des femmes. Images dans `images/Al-Khalija/Al Madina/`
  (`Al_Madina_hotel_reception`, `_suite`, `_restaurant`, `_salon_the`, `_salon_gentlemen`, `_hammam_hommes`,
  `_hammam_femmes`, en `.webp`).

### Accès réservés (moteur du Pavillon)

- Salon des gentlemen et hammam des hommes : personnages de genre « H » ; hammam des femmes : genre « F ».
- L'onglet affiche « Accès strictement réservé aux hommes » (ou « aux femmes ») ; le serveur refuse l'entrée
  (`acces_reserve_raison_interne`, raisons `reserve_hommes` / `reserve_femmes`).
- **Forcer le passage** : 2 PA ; chance 60 % + 4 % par point de VOL au-dessus de 13 (− 4 % par point en dessous).
  - Échec : **1 jour de prison**, sans combat ni amende.
  - Réussite : libre circulation dans les pièces réservées **jusqu'à la sortie de l'hôtel**, sans être recherché.

### Salon de thé

| Geste | Coût | Effet |
|---|---|---|
| Thé à la menthe | 1 PA, 60 DR | +2 Santé |
| Pâtisseries orientales | 1 PA, 150 DR | repas léger (catégorie « snack ») |
| Jus de fruits frais | 1 PA, 50 DR | +1 Santé, protège de la chaleur pour 12 heures |
| Demander un thé spécial (à Nabil Naana) | 1 PA, 150 DR (3 fois le prix d'un verre au bar de l'hôtel) | alcool servi dans une théière, effets habituels de l'alcool ; 10 % de chances par commande d'être signalé à la police des mœurs : 1 000 DR d'amende, sans prison ; sans limite quotidienne |

### Salon des gentlemen

| Geste | Coût | Effet | Limite |
|---|---|---|---|
| Narguilé | 1 PA, 250 DR | +4 influence, −2 Santé ; dès la 2e pipe de la journée, un vrai secret sur le fumeur échappe à tous les joueurs présents et part dans le circuit des rumeurs | 3 par jour |
| Backgammon | mise choisie par celui qui défie | défi lancé à un joueur présent, qui accepte ou refuse ; chacun mise le même montant ; chance 50 % + 2 % par point d'INT d'écart ; le gagnant prend les mises et +2 popularité | — |
| Café arabe | 2 PA, 80 DR | +2 VOL pendant 6 heures | non cumulable |
| Secret contre secret | 1 PA | voir les hammams | 1 par jour et par cible |

### Hammams

| Geste | Coût | Effet | Limite |
|---|---|---|---|
| Bain de vapeur | 1 PA, 300 DR | +6 Santé, guérit la gueule de bois | 1 par jour |
| Secret contre secret | 1 PA | voir ci-dessous | 1 par jour et par cible |

**Secret contre secret** : on vise un joueur de la même pièce, sans son accord.
- Chance : 50 % + 3 % par point de CHA de l'auteur au-dessus de 8 − 3 % par point de VOL de la cible au-dessus de 8,
  bornée entre 10 et 90 %.
- Réussite : chacun apprend un vrai secret de l'autre.
- Échec : personne n'apprend rien et la cible n'est pas prévenue ; **un échec sur dix est critique** : seule la cible
  apprend alors un secret de l'auteur.
- Les « vrais secrets » sont tirés comme ceux des maisons de Sovarka : poste, argent liquide, domicile, actions
  récentes.

### PNJ

- **Réception** : Amira Miftah (référente de l'hôtel), Saïd Chanta (bagagiste, référent des douanes d'Al-Khalija).
- **Restaurant** : Karim Sahn (référent des habitués, d'après les passages réels).
- **Salon de thé** : Nabil Naana (thé spécial).
- **Salon des gentlemen** : Faris Dukhan (serveur de narguilé, référent de ceux qui fréquentent le salon), Jabbar Bawwab
  (gardien géant et laconique, à l'entrée).
- **Hammam des hommes** : Hamid Bukhar (gardien placide). **Hammam des femmes** : Oum Saboun (matrone inflexible).
- Les portraits n'existent pas encore : les cartes de PNJ s'affichent sans image.

## Ce qui n'est pas codé

- Aucun commerce à louer, aucun poste à prendre, aucune domiciliation à Al Madina (décision 17).
- Pas de PNJ nommés ni d'ordre exclusif au centre multimodal d'Al Madina.
