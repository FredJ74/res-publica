# Mission de fin de soirée — 25/11/2026

Feu vert de Fred donné avec la consigne. Une case par point, cochée au moment où le point est poussé.
**Reprise** : « Reprends docs/mission-soir2-20261125.md au premier point non coché ».

## Étape zéro

- [x] 0.1 Vérifier que les cinq migrations de la mission du soir (20261125400000 à 700000) sont appliquées et contrôlées ;
  sinon les appliquer d'abord avec leur contrôle. → Appliquées et contrôlées le 25/11 en fin de soirée (ec3a7669).
- [x] 0.2 Copier cette mission ici, une case par point.

## Règles

- Migrations de cette mission : écrites, appliquées seulement si Fred est devant l'écran pour valider ; sinon listées dans le
  rapport avec leur contrôle. Le code fonctionne sans elles (repli propre, aucune erreur pour le joueur).
- Petits blocs, CI verte avant chaque fusion, une ligne par décision dans docs/suivi-decisions.md (décisions de Fred du 25/11,
  fin de soirée), RELAIS.md à jour, quota économe. Textes français nouveaux → « Pour Codex ». Pas d'arrêt entre les blocs ;
  une vraie question de game design se note dans le rapport.

## Bloc 1 — Réponses de Fred aux questions de la mission du soir

- [ ] 1.1 Remise à zéro du 19/12 : tous les personnages disparaissent, chacun recrée le sien comme au premier jour (choix gardé
  dans la procédure, toujours sans l'exécuter). blocus_ordres_batiments et climat_evenements vidées au lancement. Continuer la
  remise à l'état initial des 40 tables mixtes, table par table, dans la procédure.
- [x] 1.2 Fin d'abonnement : tout ce qui a été activé reste acquis (déjà codé). Seuls les renouvellements d'image hebdomadaires
  et les exclusivités s'arrêtent. Noter la décision.
- [ ] 1.3 Renouvellement d'image décompté avant la génération : si la génération échoue, il est rendu. Banc.
- [ ] 1.4 Contrebande : un échec repéré par la douane entraîne une amende égale au gain qu'aurait rapporté la contrebande, plus
  la recherche (au lieu de la saisie). Description fidèle. Banc.
- [ ] 1.5 Ticket du cinéma de Montrouge : vendu au cinéma par un caissier ou une caissière à créer s'il ou elle apparaît sur
  l'image du hall (portrait recadré depuis l'image, nom et caractère cohérents avec Montrouge, fiche DeepSeek). Si personne
  n'est visible, le ticket reste chez Josette Betterave, et le noter.
- [ ] 1.6 Médaille commémorative du Tractorisme : plus vendue au musée ; offerte à coup sûr au PREMIER chant de « Chanter l'hymne
  au Tracteur » à l'église de la Grange Sainte de Novomirsk, une seule fois par personnage, avec le message : « Votre voix
  angélique a touché les dieux du Tractorisme : ils vous offrent la médaille du Tractorisme en remerciement de ce moment
  d'intense émotion. » Serveur et banc (première fois oui, deuxième fois non).
- [x] 1.7 Souvenirs : prix 8 à 45 validés ; rôle « Vendeur de souvenirs » de Bastien Leroux et mention dans la bible du
  gouvernement gardés.
- [ ] 1.8 Visites en prison : QHS = tout avocat inscrit au barreau ; seul le conjoint marié compte comme famille ; une visite
  par jour par visiteur et par détenu ; ordre de visite ajouté dans les commissariats.
- [ ] 1.9 « Mobiliser les membres » : ouvre le syndicat du joueur où qu'il soit ; sans syndicat, l'ordre est refusé avec une
  explication claire.
- [ ] 1.10 Censure en Sovarka : agit sur l'indice serveur le plus proche de la popularité du régime ou de la confiance du
  peuple : hausse à court terme, baisse si un scandale éclate. Description fidèle. Banc.

## Bloc 2 — Choix techniques (tranchés par Claude)

- [ ] 2.1 Bonus de bénédiction (+5 aux jets du commissaire) lu au serveur, plus déclaré par l'écran.
- [ ] 2.2 Charisme : le serveur reste la seule source (bonus temporaires compris s'ils sont tenus au serveur ; sinon le noter).
- [ ] 2.3 Fuite d'information et soins sans trace : la chance du demi-effet s'affiche à côté de celle de l'effet complet.
- [ ] 2.4 Publicités de joueurs : une campagne à la fois par support, durée réglée par le MJ ; les formules « 5 / 10
  parutions » de l'atelier de presse disparaissent au profit de ce modèle.

## Bloc 3 — Chronique de l'empire : la rumeur en toutes lettres

- [ ] 3.1 Onglet « L'empire » : une rumeur est citée avec son texte (celui que rumeur_lancer enregistre, 600 caractères au
  plus), par exemple « Une rumeur circule au marché de Novomirsk : "…" ». Auteur anonyme tant qu'il n'est pas identifié.
  Texte de joueur : traduction automatique (api/_traduction.js) avec le lien « voir l'original ». Banc.

## Fin de mission

- [ ] CI verte, toutes les cases cochées.
- [ ] Rapport court en français : 1) en ligne ; 2) migrations à valider, dans l'ordre, avec leur contrôle ; 3) en attente et
  pourquoi ; 4) questions de game design, une par ligne.
