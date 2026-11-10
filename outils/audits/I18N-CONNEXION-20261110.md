# Connexion — neuf langues, 10 novembre 2026

## Périmètre et reprise

Main vérifié `02319679` (#680), après les traductions déjà intégrées #671–675.
Lot empilé sur `codex/i18n-premiers-parcours-20261110` (`9bf2b633`) : aucune
réécriture de l’inventaire. Branche `codex/i18n-connexion-20261110`.

Le formulaire initial était traduit ; ses neuf messages dynamiques dans
`connecterAvecMotDePasse` restaient français. Ce lot raccorde ces messages au
même i18next, avec une ressource dédiée chargée dans index.html avant init.
Les clés et libellés français reprennent exactement l’ancien code. Aucun coût,
ordre, permission, RPC, délai, donnée de cache ou mode d’authentification changé.

## Réalisation

- Adresse invalide, mot de passe absent, service indisponible, attente, limite de
  tentatives, identifiants incorrects, compte sans personnage, personnage
  indisponible, bienvenue avec le nom **canonique** du serveur : neuf langues.
- Une bascule pendant une requête ou après sa réponse retraduit le message,
  conserve les saisies et n’exécute aucune nouvelle demande d’authentification.
- Le nom reste un texte littéral, jamais du HTML ; la langue ne change ni le nom
  sauvegardé, ni le cache, ni le personnage choisi.
- Le helper de création existant accepte les paramètres du moteur. Le point
  d’entrée d’accueil existant lit des variables primitives dans un espace `values`
  distinct des options i18next. Format invalide ou variable absente : français
  canonique. Pas de moteur ou service HTTP supplémentaire.
- Adresse inconnue et mauvais mot de passe restent le même message générique.
  Aucune raison brute, aucun jeton, mot de passe ou identifiant réel dans les tests.
- Caches des deux scripts modifiés mis à jour dans index.html. Aucun changement
  CSS, plateau.html, API, SQL, mécanique Sovarka ou moteur PNJ.

## Preuves automatiques

`banc-i18n-connexion-ui.cjs` : **12/12**. Les neuf locales parcourent chacune
11 cas comparés au code réel de main : mêmes arguments et séquences d’appels,
cache, propriétaire, bouton, redirection et délai 700 ms. Le témoin compressé ne
contient que trois fonctions publiques, vérifiées SHA-256, et ne dépend pas de
l’historique Git du runner.

Chromium charge le vrai formulaire et ses ressources, avec une authentification
**fictive** : requête retardée, bascule vers AR en cours, échec uniforme, nouvelles
bascules sans nouvelle requête, succès, nom multilingue avec caractères HTML
littéraux. Neuf langues aux largeurs 360/390/768 sans débordement horizontal.
Les paramètres absents/invalides retombent sur le français. Comparaison PNG du
panneau français **strictement identique à 1440 px** : aucune tolérance ajoutée.
Le test fixe explicitement la langue de départ, indépendamment de celle du
navigateur. Ce sont des émulations, pas des appareils physiques.

Cibles accueil + éditorial + connexion : **28/28**. Mesure éditoriale : **1 212 clés
françaises de référence**, zéro clé/paramètre manquant dans les neuf langues ;
ce chiffre ne prouve pas une couverture complète des écrans. Les deux mutations
de l’auditeur du lot précédent sont toujours détectées. Workflow : conforme.
Le contrôleur a révélé une extraction incomplète dans le banc mobile : ajout du
helper réel `rpMessageIdentifiants`, puis **17/17** scénarios verts, avec garde
pageerror et sans suppression de cas. Contrôleur complet : résultat final dans
le relais et les preuves JSON : **265/265** sur `83abd4bb`, zéro échec.
La première passe était à 264/265 avant correction du banc mobile ; tous les
bancs ont été rejoués après cette correction.

## Contrôles globaux et distinction avec main

Contrôleur global réellement exécuté : **10/12**, Authority vert. Baseline et
Referential rouges : définition `club_accessoire_acheter`, seeds usines/entreprises
et empreintes ordres/PA/entreprises. Rejoué sur un worktree intact de main
`02319679`, avec les mêmes dépendances : **sortie intégralement identique, octet
pour octet**. Les deux journaux sont archivés sous `i18n-connexion-20261110/`.
Aucune référence, empreinte ou règle métier modifiée pour masquer ces écarts.
Une première tentative du témoin sans ses dépendances Node a été corrigée par
leur installation locale ; ce résultat incomplet n’est pas utilisé comme preuve.
Ces deux échecs hérités restent ouverts et doivent être traités par l’intégrateur,
sans prétendre que le lot a certifié le catalogue Supabase vivant.

## Livraison préparée et limites

Titre PR : **Connexion : messages dynamiques et changements de langue sans
relancer l’authentification**.
Base initiale : `codex/i18n-premiers-parcours-20261110`, à rediriger vers main
après intégration du lot inventaire. Ne pas présenter deux fois les mêmes commits.
Description prête : « Neuf messages dans neuf langues, paramètres et fallback
français, saisies et contrat d’authentification inchangés. Tests de contrat,
Chromium retardé/RTL/mobile et comparaison stricte FR 1440. Aucun SQL ni état
joueur modifié. » Contrôles attendus : bancs clients, Workflow, éditorial et CI.

API GitHub lecture/création de PR refusée 403 lors de ce chantier : aucune PR,
fusion, CI distante ou version Vercel attestée ici. Publication autorisée par Fred
mais à effectuer par l’intégrateur après contrôles, sans manipulation de secrets.
Aucun compte réel connecté. Aucune réponse IA/traduction payante utilisée.
Validation linguistique humaine et iPhone Safari/Android Chrome restent distincts.

Limite **préexistante**, conservée : l’ancien `sbRpc(mon_personnage)` peut ramener
null pour plusieurs motifs ; ce lot ne prétend pas diagnostiquer une panne réseau
ni réparer ce contrat. Il traduit la décision actuelle sans modifier son sens.

## Suite de couverture

La capture du premier lot recense les sites candidats, pas seulement des manques.
Les professions, organisations, nombreux formulaires économiques/institutionnels,
les contenus libres et des notifications restent à inventorier contexte par
contexte. Les noms/description RP et les valeurs serveur ne doivent pas être
retraduits arbitrairement. Aucun service de traduction dynamique n’est activé.
Le chantier global n’est pas déclaré terminé par la seule parité des catalogues.
