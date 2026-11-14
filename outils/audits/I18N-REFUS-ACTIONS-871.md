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

## Vérifications en cours

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

Compatibilité avec le vrai catalogue #924, autres bancs, mesures, CI et production
à terminer. Pas de session PJ authentifiée, téléphone physique ou revue native.
Aucune migration, fonction serveur ou mécanique des Tsars modifiée.
