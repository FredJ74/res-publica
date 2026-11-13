# #871 — recherche du personnage sur l’accueil

Cinq libellés de refus (propriété étrangère, compte déjà pourvu, vérification
indisponible, refus à motif variable et motif inconnu) : **40 nouvelles traductions
étrangères** dans `connectionUi`. Les six autres messages de recherche sont
réutilisés depuis `home` (**48 traductions existantes**, zéro copie).

Dix points d’affichage du vrai parcours reçoivent les marqueurs DOM du moteur
existant. La recherche en cours, les erreurs, refus et succès sont réactualisés
sans répéter de chargement, rattachement ou authentification. Aucun texte libre
n’est traduit automatiquement ; noms et motifs restent intégralement intacts.

Le moteur commun utilise l’option standard `replace` d’i18next pour fournir les
variables aux deux conventions existantes (`{{name}}` et `{{values.name}}`). Les
variables ne sont jamais fusionnées aux options du moteur : `lng` et `ns` restent
du texte, pas un choix de langue ou de catalogue. Aucun second moteur ni nouvel
écouteur de langue. Les anciennes traductions restent exactement identiques.

## Preuves

AST entier de `creation.js` identique hors annotations DOM/appels de présentation.
AST de `i18n-init.js` identique hors ajout des données d’interpolation. Aucune
condition, RPC, session, donnée, cache métier, PA, prix ou redirection modifié.
Les preuves sont figées sur le commit du lot, pour permettre les évolutions métier
ultérieures et exclure les migrations étrangères des merges temporaires de CI.

Chromium : **324 bascules sur douze chemins**, neuf langues, 320/390/1280,
allemand/russe/arabe RTL, nom vide, service absent, personnage absent, exception,
quatre types de refus, nom manquant dans la réponse, recherche en attente et succès.
Noms avec guillemets/HTML/caractères multilingues et motifs variables conservés sans
injection. Aucun nouvel appel, paiement, PA, cache, session, redirection, minuterie
ou perte de saisie/focus/sélection à la bascule. Réponse en attente résolue sans
résurrection d’un ancien refus. Repli français et noms d’options comme données testés.

Les confirmations d’adresse précédentes sont rejouées (108 arrivées / 972 bascules).
Banc de connexion existant : 12 tests verts. Suite finale : 34 tests Node verts.

## Mesure conservatrice

Même extracteur avant/après main `a2f43e0` : corpus inchangé (7 565 textes / 50 690 mots). Le raccordement reconnu automatiquement reste inchangé : anglais 998 textes / 12 125 mots (23,92 %). Une entrée du corpus retrouve une ressource (+19 mots) ; les autres refus assemblés et leurs annotations DOM ne sont pas reconnus comme correspondances par cet extracteur. Les cinq nouvelles clés / 40 traductions et les dix états sont pourtant vérifiés par les tests de rendu. Aucun gain de branchement statique non détecté n’est revendiqué. La reconnaissance des annotations DOM est une amélioration d’audit à traiter séparément, sans la compter comme une nouvelle traduction.

CI et production à compléter avant livraison.
Session PJ réelle, téléphone physique et revue native non réalisés.
