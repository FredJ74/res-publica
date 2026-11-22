# Mission de la nuit du 22/11/2026 — texte de Fred, mot pour mot

```text
MISSION SUIVANTE – HUMAN GAMBIT (22/11/2026, nuit)

0. RÈGLES ET COORDINATION
- Relire RELAIS.md et AGENTS.md avant de commencer. Ne jamais toucher au goulag (sovarka_goulag_*, configuration active=false à conserver). Contrôle en lecture après chaque migration. Tenir RELAIS.md et AGENTS.md à jour.
- Codex reprend en parallèle, UNIQUEMENT côté navigateur et tests, sur sa propre branche : logo du plateau (« RES PUBLICA » → « HUMAN GAMBIT ») et son test au pixel, courrier de bienvenue et ses traductions, fenêtres qui ne se chevauchent pas, recette isolée de la PR #1176. Ne touche pas à ces quatre sujets. Toi seul appliques des migrations. Note dans RELAIS.md, au fur et à mesure, les fichiers du navigateur que tu modifies, pour que Codex puisse rebaser proprement. La réconciliation du baseline par Codex attendra ton rapport final.
- Exception à la règle « simple appel ajouté » : Codex ne touchant pas à la base, tu es autorisé à modifier entièrement les fonctions communes nécessaires au point 6, avec un contrôle en lecture et un rejeu des tests après chacune.
- Principe de toutes les interfaces : « codons comme pour un enfant ». Chaque fenêtre comprise au premier coup d'œil, jamais de formulaire qu'on ne peut pas envoyer, jamais d'action sans issue, un maximum de pédagogie dans les messages, mise à jour en direct sans recharger la page.
- Chaque fois que tu changes un catalogue de traduction, relance compresser-catalogues-i18n.cjs.

1. IMAGES DÉPOSÉES PAR FRED (dossier « images » glissé dans cette conversation)
- Le dossier contient, déjà nommés et convertis en .webp :
  images/chantiers/psm/ : PSM_chantier_demarrage_petit, PSM_chantier_demarrage_grand, PSM_chantier_fondations, PSM_chantier_gros_oeuvre, PSM_chantier_facade, PSM_batiment_hangar, PSM_batiment_commerce_standard, PSM_batiment_commerce_premium, PSM_batiment_logement, PSM_batiment_building, rue-terrains-lots-detail-psm, rue-terrains-psm-etat2, rue-terrains-psm-etat3
  images/Sovarka/Krasnov/Krasnov_place_ours_fontaine.webp
- Range chaque fichier là où le code l'attend. Les trois images de rue vont dans le dossier des vues de rue des terrains de Port-Sainte-Marie ; rue-terrains-lots-detail-psm remplace l'ancienne image à 5 lots. Retire les replis provisoires devenus inutiles. Renseigne l'image du point d'eau krasnov-fontaine-ours. Déploie en bêta sans attendre le contrôle long (images seules).

2. CHANTIER – HEURES ET MATÉRIAUX
- Les heures de travail du jour sont TOUJOURS ouvertes en totalité (environ 50 h par jour pour un building), quel que soit le stock de matériaux.
- La nuit, à la clôture du jour : le chantier consomme ce qu'il a pour le jour écoulé, puis commande immédiatement à l'entrepôt de sa ville les matériaux de la journée SUIVANTE (dans la limite du stock de l'entrepôt et de la trésorerie du chantier). Le stock est donc plein dès le matin. Même chose quand le jour suivant s'ouvre en avance grâce aux joueurs : la commande pour ce jour part aussitôt.
- Si l'entrepôt ne peut pas tout fournir, ce qui manque reste à acheter aux joueurs pendant la journée (vente ou don dans l'onglet Stock de matériaux) ; la petite jauge du matériau est rouge.
- Remplacer le courrier « Chantier à l'arrêt : matériaux manquants » par une entrée au journal du chantier, visible dans l'onglet État, qui invite les passants à vendre ce qui manque.
- Pas de bouton de commande manuelle. Dans l'onglet Gestion, afficher : « Commande automatique chaque nuit à l'entrepôt de <ville> », suivi du résultat de la dernière commande (quantités livrées, quantités manquantes, coût).
- Vérifier sur le chantier d'Arnie (terrain 3 de Luthécia) que la prochaine nuit remplit bien le stock et que les heures sont ouvertes ; le noter dans le rapport.

3. IMAGES DES ÉTAPES DE CHANTIER – RÈGLE À APPLIQUER
- Démarrage : photo commune à toute la Républia, sauf Port-Sainte-Marie (deux images : petit chantier pour hangar et commerce standard ; grand chantier pour commerce premium, logement et building).
- Fondations : une image par ville, la même pour tous les types. Luthécia a la sienne (rue haussmannienne sous la pluie). Montrouge : à produire.
- Gros œuvre et façade : deux gabarits par ville, bas et haut. À Port-Sainte-Marie seulement : une image par étape quelle que soit la taille.
- Donner dans le rapport la liste exacte des images encore manquantes selon cette règle.

4. FORÊT DE KRASNOV
- Égarement au retour vers la clairière : 50 % au lieu de 80 % (paramètre foret_egarement_pct).
- Rencontres : en plus de la seconde coupe, 15 % de chance de rencontre en arrivant dans une vue profonde (vues 1 à 4), même sans couper. Mêmes créatures et mêmes règles (combat de groupe si le chef a un groupe). Texte pédagogique à l'arrivée.

5. CLIMAT
- Les événements déjà annoncés aux joueurs sont maintenus, même avec un préavis inférieur à 48 h. La règle des 48 h ne vaut que pour les nouvelles annonces.
- Le pictogramme d'alerte (« ATTENTION : ORAGE », et tous les autres événements) est déplacé dans le coin supérieur gauche de l'image, en plus compact. Règle générale : aucune alerte, étiquette ou bouton ne doit couvrir une flèche de déplacement, dans aucune vue.

6. REFONTE DES TYPES DE BÂTIMENTS (7 types en base → 5)
- Hangar : 30 000, 6 jours, 300 h ; aucune subdivision.
- Commerce standard : 60 000, 12 jours, 600 h ; aucune subdivision.
- Commerce premium : 90 000, 18 jours, 900 h ; boutiques de 600 m² minimum.
- Logement : 90 000, 18 jours, 900 h ; 6 appartements (3 petits de 45 m², 3 grands de 75 m²).
- Building (mixte logements et commerces) : 120 000, 24 jours, 1 200 h ; commerces de 300 m² minimum, appartements de 150 m² minimum, au plus 6 commerces et 14 appartements ; la somme des lots ne dépasse pas la surface du terrain (pas d'étages). Remplace la barre : un building peut avoir peu ou pas de commerces.
- Supprimés : logements sociaux petit et barre (l'ancien moyen devient le type Logement unique).
- Catégorie selon le donneur d'ordre, pour Logement comme pour Building : mairie = logements sociaux (attribués par le maire, loyer bas fixé par le jeu, bonus de moral et de santé au sommeil) ; joueur = logements classiques (loyer et attribution libres).
- Le chantier d'Arnie (building, terrain 3 de Luthécia) ne doit pas être modifié.
- Mettre à jour toutes les fonctions qui citent les 7 anciens types : dépôt et décision du permis, acquisition de terrain, valeur des biens pour les prêts d'Helvetia (qui doit désormais compter les logements), découpage des lots, libellés côté navigateur.

7. FORUM – IMAGES
- Coller une image (presse-papiers) ou glisser un fichier dans l'éditeur de message.
- Stockage : Supabase Storage, envoi direct depuis le navigateur, sans nouvelle fonction Vercel. Lecture publique ; écriture réservée au joueur connecté, dans un chemin à son nom, par règles d'accès ; images uniquement, 5 Mo au plus, message clair si le fichier est refusé.
- Les images extérieures déjà présentes dans les messages (dont le message de Peter Kropotkine du 21/11 à 03:33) sont recopiées dans ce stockage et les liens remplacés.

8. ÉTAPES H, I, J, K (plans déjà écrits dans RELAIS)
- H : interview d'accueil.
- I : reste du lot de Krasnov, points 2-3 et 9. Ne pas toucher aux points 5-6 (textes à réécrire plus tard) ni au point 7.
- J : terrains à bâtir (plan en vignettes, rue en trois états), en branchant les images de Port-Sainte-Marie du point 1. Fred testera le rendu avant de valider.
- K : refonte des informateurs.

9. NAVIGATION – PLACE DE L'OURS
- La sortie de la place de l'Ours vers krasnov-rue-mairie-place passe de « arrière » à « droite », dans la base (rue_noeuds_serveur) comme à l'affichage : la flèche est à droite et non plus en bas.
- Vérifier les autres places et culs-de-sac de Sovarka : quand on y entre par la gauche ou la droite, le retour doit se faire par le côté opposé. Corriger et lister dans le rapport.

10. RAPPORT FINAL (un seul)
- Ce qui est fait, point par point, et ce qui ne l'est pas avec la raison.
- Migrations appliquées (numéro, nom) et contrôles effectués.
- Fichiers du navigateur modifiés (aussi dans RELAIS.md pour Codex).
- Images encore manquantes selon la règle du point 3.
- Vérification du chantier d'Arnie après la nuit.
- Ce que Codex doit savoir pour la réconciliation du baseline.
```
