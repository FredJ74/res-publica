# #871 — explications des refus d’action, complément de #924

Le premier audit recensait vingt corps et seize notifications dans trois fonctions
de présentation : `showPostRequired`, `signalerRefusCout`, `signalerRefusPa`.
La reprise révèle que la PR #924 de Claude traduit déjà quinze de ces corps.
Leurs copies ont donc été retirées avant publication du code.

Ce lot ajoute **cinq corps manquants et un titre, 48 traductions étrangères** :
poste nommé, fonds chiffrés, caisse chiffrée, action non enregistrée et PA chiffrés,
plus « Action réservée ». Il réutilise quinze titres existants. Les quinze autres
corps référencent les clés stables de #924 sans copier de traduction ; leur
français reste affiché si ce catalogue n’est pas encore présent.

Le manifeste des vingt français et le fichier de réutilisation distinguent ces
périmètres. Aucun texte français de référence n’est changé, aucun récit simplifié,
aucun montant ou nom propre ajouté, aucune donnée de personnage modifiée.

## Présentation et compatibilité

Seize annotations `markToast` suivent les appels existants. Le moteur i18next et
les notifications communs restent utilisés. Aucun nouveau moteur de traduction.
Les montants déjà formatés, devises, noms et nombres restent des valeurs de
présentation. La langue ne réexécute ni refus, ni lecture de fonds, ni paiement.

Le marquage accepte le protocole de corps déjà traduit de #924 seulement lorsque
la source française mémorisée, la clé et le texte courant correspondent. Une clé
explicite différente doit produire exactement le même français avec ses variables.
Un texte périmé, une source remplacée ou une clé incompatible sont refusés. Le
corps marqué est laissé à l’application commune ; le repeint automatique de #924
s’abstient lorsqu’un marqueur est présent. Sans #924, le repli français habituel
continue de fonctionner, jamais une clé technique visible.

## Vérifications

- AST entier de `plateau-core.js` inchangé hors seize annotations. Reste du moteur
  commun inchangé hors fonction de présentation `markToast`.
- Neuf langues et variables vérifiées ; trente-deux cas simulés comparés au
  français et aux lectures de fonds antérieures, avec ou sans API de présentation.
- Chromium : 1 728 bascules (32 cas × 9 langues × 3 largeurs × 2 protocoles),
  320/390/1280, RTL, montants/devises/noms exacts, absence de débordement du corps
  et du titre, brouillon/focus/sélection/position conservés, aucune nouvelle
  action/RPC/PA. Protocole #924 simulé pour une CI indépendante de sa branche.
- Ancien banc coûts+forum : 9/10 sur la base et la branche ; même fixture de forum
  échoue faute de `window`. Les trois tests de refus de coût et cinq tests de
  générateur passent. Aucun échec nouveau masqué, aucun test étranger modifié.

46 tests Node et quatre bancs Chromium passent (refus, chantiers, reprise et forum).
Le vrai catalogue de #924 a aussi été vérifié : 1 728 bascules réussies,
blob `e0043ea02bb70cd435c317cf4c5917851d20f5b9` au commit
`db7cc52676d3aebb20f1878bc4d9d6d3434fb7a1`. Ce test de compatibilité
ne certifie pas la qualité linguistique des traductions de cette autre PR.

## Mesure à méthode identique

Base `e9757bc`, code `4bd3e75` : même extracteur, même corpus de 7 582 textes
et 50 865 mots. Chaque langue étrangère gagne six raccordements prouvés et
56 mots source raccordés ; six ressources supplémentaires représentent 55 mots
source (les représentations dynamiques de la source et du catalogue diffèrent).
En anglais : 1 019 textes / 12 375 mots raccordés, soit 24,33 % des mots du
corpus statique identifié. Ce plancher ne mesure pas l’ensemble du jeu. Les
quinze corps de #924 ne sont pas comptés comme traduits dans cette livraison.
Zéro erreur d’extraction. Mesures complètes dans le JSON associé.

## Contrôles de livraison

La CI dédiée et les tests de non-régression du moteur passent. Les contrôles
`republia`, `socle` et `descriptions-tactiles` retrouvent deux inventaires devenus
périmés après les nouveaux ordres d’hôpital arrivés sur main pendant les essais
(247 au lieu de 246, 153 au lieu de 151). Reproduction indépendante sur main
`406d578` : 21/23, mêmes deux échecs. Le contrôle SSM habituel retrouve ses trois
échecs connus ; le banc tribunal supplémentaire ajoute une attente PNG alors
que main utilise WebP : ensemble 14/18 sur main comme sur la branche.
Ces chantiers étrangers ne sont pas modifiés pour rendre la CI verte.
Aucune régression nouvelle identifiée. Main 406d578 intégré sans modifier ses
fichiers métier ; les preuves de périmètre restent figées au commit propre fa52c5e.

PR #914 fusionnée : `fb25f0ec4608e7fda14d36ba1edcfbd235dc5ce9`.
46 contrôles verts ; quatre rouges étrangers reproduits sur main (voir ci-dessus).
Vercel `dpl_76YccY2EtsYzfM9dFFi3QcwZ5B6n` READY sur ce commit ; alias
confirmé, neuf fichiers publics identiques, 1 728 bascules rejouées vertes sur ces
fichiers. Les quinze corps de #924 gardent leur français de repli avant sa livraison. Pas de session PJ authentifiée, téléphone physique ou revue native.
Aucune migration, fonction serveur ou mécanique des Tsars modifiée.
