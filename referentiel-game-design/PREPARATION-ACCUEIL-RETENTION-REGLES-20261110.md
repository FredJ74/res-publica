# Préparation — accueil, rétention, refonte des « Règles »
**10 novembre 2026 — document d'audit et de préparation, aucune activation UI.**
Responsable : ChatGPT. Codex reste chargé de l'i18n, Claude de Sovarka et du guidage Jérémy déjà traité. Aucun développement concurrent.

## 1. Première session : preuves et risques

**Sources consultées** : `referentiel-game-design/AUDIT-ACCUEIL-I18N-NUIT-DROITS.md`, `FICHES-PARCOURS-SOCIAUX-ET-FRICTIONS.md`, `EXPERIENCE-ET-RETENTION.md`, `plateau-quete-accueil.js`, `plateau-personnage.js`, `RELAIS.md`. La consultation de code ne prouve pas la jouabilité.

- **Accueil existant** : garde → carrefour → Hôtel de ville → Petit/Jérémy → élections → dispensaire/fiche → hôtel/bar/chambre → stade → choix de trajectoire. Il ne faut pas ajouter un deuxième tutoriel.
- **Signal testeur A** : confusion quant à l'enquête / calepin ; difficulté à savoir où aller et pourquoi ; Jérémy répétait l'instruction de consulter la fiche. **Correctif présent dans le code** : `queteAccueilFichePersonnageOuverte` valide l'étape `attente_fiche_personnage` dès l'ouverture de l'une des deux vues ; suite d'hôtel au retour. Vérification humaine sur la version courante restant nécessaire.
- **Signal testeur B** : PA mal compris, graphismes appréciés. Le code contient déjà une explication écrite des PA, des ordres et du sommeil dans `plateau-personnage.js`, et une scène de Jérémy sur la récupération. Hypothèse : explication trop tardive, peu visible ou trop dense ; **ne pas déclarer l'absence d'explication**.
- **Problème transversal** : réussir les étapes du tutoriel ne signifie pas savoir explorer ensuite librement ni distinguer l'enquête du tutoriel.
- **Variantes de ville** : le guidage observé est ancré à Luthécia ; ne pas prétendre qu'il vaut déjà pour tous les empires.
- **Frontière** : pas de PJ authentifié, donc ni reproduction du blocage mobile, ni constat de correction en jeu.

### Recette première session — matrice à faire exécuter

| Test | Parcours concret | Réussite attendue |
| --- | --- | --- |
| A1 | Création → garde → mairie → secrétaire Petit → Jérémy | Chaque étape a une consigne visible et un prochain geste compréhensible |
| A2 | Dispensaire → ouvrir fiche par carte du haut | Jérémy ne répète pas « consultez la fiche », annonce l'hôtel |
| A3 | Dispensaire → ouvrir fiche par raccourci Moi ; quitter autrement que « Sortir » | Même continuité, après refresh aussi |
| A4 | Fermer une popup Jérémy puis rouvrir l'aide | La consigne actuelle revient, sans repasser une étape payante |
| A5 | Recevoir le calepin/enquête (J+1 si conditions remplies) | Le joueur sait s'il s'agit d'une nouvelle enquête, qui l'a confiée, où commencer |
| A6 | Consulter PA avant, pendant et après un ordre | Signification, coût, solde, récupération et risque de 0 PA compris |
| A7 | Quitter guidage, explorer et revenir | Position/quête/soldes reflètent la vérité serveur |
| A8 | Smartphone réel | Bouton d'aide, objectifs, fermeture, nav accessibles sans zoom ni débordement |
| A9 | Choisir voie indécise/criminelle/politique/entrepreneuriale | Liberté de parcours préservée, première initiative réelle accessible |
| A10 | Expliquer sans assistance « que feras-tu ensuite ? » | Le testeur énonce spontanément son prochain geste et sa raison |

Prendre pour chaque essai : appareil, langue, version/SHA, étape, attendu, observé, capture consensuelle sans données privées. Ne pas attribuer le statut « validé en jeu » à un test automatisé.

## 2. Rétention : diagnostic de conception, sans chiffres inventés

**Atouts structurels identifiés, pas encore mesurés** : plusieurs trajectoires, interaction PJ↔PJ, recrutement et emploi, rivalités, forums territoriaux, PNJ sociaux persistants, monde qui évolue quotidiennement, marchés/ressources, carrières et élections. Le contact spontané des PNJ peut combler un silence initial, mais ne doit jamais remplacer les rapports humains.

**Fragilités probables à éprouver** :
1. L'enchaînement « tâche d'accueil accomplie → et maintenant ? » manque peut-être d'un projet personnel immédiatement lisible.
2. Une enquête reçue sans origine, enjeu et étape suivante identifiables peut devenir un objet incompris dans l'inventaire.
3. Les PA non compris risquent de provoquer la peur de cliquer (ou le zéro PA et l'hospitalisation).
4. Les villes et sorties difficiles à repérer aggravent la friction mobile.
5. Une communauté encore faible limite manifestations, recrutements, négociations et alliances.
6. Une promesse d'action réalisée puis non confirmée après reconnexion érode la confiance plus vite qu'une fonctionnalité manquante.

### Parcours de rétention à observer

- **D0, 15 premières minutes** : premier déplacement autonome, premier ordre confirmé, explication correcte des PA, identification d'un interlocuteur.
- **D0, fin de journée** : projet librement choisi (emploi, découverte, politique, commerce, crime, enquête) et prochaine action compréhensible.
- **D1** : retour motivé par un événement personnel, un message, une affaire, un rendez-vous ou une relation — **pas uniquement** par la récupération de PA. Exemple existant : l'appel de Jodie Moitout après J+1, sous conditions ; mécanisme documenté, effet sur D1 inconnu.
- **D7** : au moins un projet évolutif, une relation PJ/PNJ mémorable, une possibilité de bifurcation et des conséquences persistantes.

**Question qualitative essentielle au testeur** : « Qu'est-ce qui pourrait te donner envie de revenir demain ? » Réponse libre, non suggérée. Mesurer D1/D7 seulement avec des cohortes suffisantes, légitimes et sans collecte intrusive. Ne pas instrumenter le jeu sans décision.

**Pistes à discuter après preuves** : clarification du prochain pas sans parcours imposé, indication du donneur d'enquête, fenêtre de règles simple accessible à tout moment, pistes d'initiative sociale volontaires. Ne pas transformer « Mes objectifs » ni ajouter de récompenses artificielles sans arbitrage du game designer.

## 3. Préparation pour ce soir : refonte de l'onglet « Règles »

**Statut** : proposition rédactionnelle et plan technique uniquement ; aucune refonte graphique, aucun changement de mécanique, aucune fusion ni activation.

### Intentions UX
- Un seul écran simple, sans encyclopédie à l'ouverture : titre « Bien débuter », six rubriques courtes, une seule rubrique ouverte à la fois sur mobile ; possibilité de parcourir sans changer d'écran.
- Réutiliser la fenêtre existante et la charte (popup, typographies, boutons). Éviter un mur de boutons, éviter une carte générée approximative.
- Entrée disponible depuis « Règles du jeu » à tout moment, texte compréhensible pour un joueur qui n'a jamais vu les PA.
- Les détails avancés restent séparés de l'introduction, pas supprimés sans inventaire préalable.
- Toute traduction ultérieure utilise l'architecture 9 langues ; coordonner le périmètre avec Codex pour éviter les doublons.

### Premier texte proposé, à valider

**1. Le principe** : « Dans Human Gambit, tu incarnes un personnage dans un monde partagé avec d'autres joueurs. Tu choisis ta voie : travailler, entreprendre, enquêter, faire de la politique, prendre des risques ou simplement rencontrer du monde. Il n'y a pas une seule façon de réussir. »

**2. Les PA, c'est quoi ?** : « Les points d'action (PA) représentent ce que ton personnage peut accomplir. Certains ordres coûtent des PA : leur coût est indiqué avant l'action. Surveille ton solde ; tomber à 0 PA peut provoquer une hospitalisation. »

**3. Comment récupérer des PA ?** : « Tu peux te reposer en dormant une fois par journée réelle. Le sommeil restaure des PA et conditionne le versement des salaires quotidiens. Les journées manquées ne sont pas rattrapées. D'autres consommables ou soins peuvent aider selon les situations. »

**4. Se déplacer et agir** : « Navigue dans les rues, entre dans un bâtiment, choisis une pièce puis un ordre. Lis les conditions et le coût affichés. Si un ordre est impossible, consulte son motif de refus. »

**5. Argent, emploi, inventaire** : « Tes achats utilisent les fonds disponibles suivant les règles de paiement. Ton inventaire conserve tes objets ; les emplois, commerces et activités peuvent créer des revenus ou des obligations. »

**6. Jouer avec les autres** : « Parle aux personnages, consulte les forums et la messagerie. Tu peux rejoindre des groupes, coopérer ou entrer en rivalité. Le monde continue d'évoluer quand tu es déconnecté. »

**À placer en bas, discret** : « Besoin d'aide pour une étape ? Retrouve ta consigne actuelle dans ton parcours d'accueil. » Ce renvoi ne doit pas remplacer l'accès réel au suivi de quête.

### Prévol technique avant code
1. Identifier précisément le bloc de la fenêtre « Règles du jeu » dans `plateau.html`, son peuplement JS et ses styles ; ne pas supprimer des règles existantes sans inventaire.
2. Vérifier les sources serveur du plafond de PA, les récupérations, le cas de 0 PA, les revenus de sommeil, et adapter les formulations si nécessaire ; ne pas coder un montant par approximation.
3. Préparer une structure accessible au clavier et au tactile ; préserver les événements des fenêtres existantes.
4. Tester viewport mobile et français 1440 px, puis RTL arabe et neuf langues après intégration par le chantier i18n.
5. Ne modifier ni coûts, ni RPC, ni mutations personnage. Déployer uniquement après ton feu vert pour la refonte visuelle et les contrôles.

## 4. Suivi et état réel
- **Terminé :** lecture du référentiel et de code ciblé ; grille de tests D0/D1/D7 ; proposition d'architecture éditoriale « Règles ».
- **Non testé :** comportement authentifié, rendu mobile et compris par des joueurs, rétention mesurée.
- **Non engagé :** code UI, migrations, traduction, PR métier, fusion et production.
- **Décision réservée au game designer :** structure finale de l'onglet, texte affiché et éventuel raccourci d'aide contextuelle.
