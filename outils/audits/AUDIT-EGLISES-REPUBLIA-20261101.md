# Audit des églises de Républia — 01/11/2026 (Claude, PR #304)

Comparaison du Tabernacle des Impôts (Luthécia), de Notre-Dame de la Mer (PSM) et de l'Église
de Montrouge. Lecture seule (code et production) ; aucune donnée modifiée.

## Identique dans les trois villes (socle commun)

| Point | Constat |
|---|---|
| Ordres de salle | « Prier le Formulaire Sacré » (1 PA) et « Faire un don à l'Église » (1 PA, 200 FR), mêmes définitions |
| Serveur | `religion_agir` accepte les trois églises ; le don est encaissé par la caisse de l'église de la ville (`vente_structure_encaisser`, `republic_<église>`) |
| Services du religieux présent | se confesser, demander une bénédiction, consulter la règle, excommunier / lever une excommunication (Grand Prêtre), habilités dans les trois églises (`EGLISES_REPUBLIA_HABILITEES`) |
| Titulaires PNJ | Père Ception (Luthécia, aussi Grand Prêtre national), Père Iscope (PSM), Abbé Tonnière (Montrouge) ; fiches de dialogue présentes pour les trois |
| Salaire religieux | 100 FR/jour pour chaque prêtre, payés par la caisse de son église ; +100 FR pour le Grand Prêtre, par le Tabernacle (`salaires_religieux_declares`) |
| Caisses | 200 FR chacune (`caisses_batiments`) |
| Sortie vers la rue, images | présentes |

## Différences (de décor, aucune défaillance)

| | Luthécia | PSM | Montrouge |
|---|---|---|---|
| Pièces | Nef des Formulaires, Sacristie administrative | Accueil, Nef, Tombe de Yann Le Goff | Nef seule |
| PNJ | Père Ception + un enfant de chœur (clerc) | Père Iscope (accueil vide) | Abbé Tonnière |
| Nom du lieu | Le Tabernacle des Impôts | Notre-Dame de la Mer & Cimetière Marin | « Église » (sans nom propre) |

## Points à signaler

1. **L'église de Montrouge n'a pas de nom propre** (« Église ») alors que les deux autres en ont un : question de ton pour Fred.
2. **Accueil de Notre-Dame de la Mer vide** (ni PNJ ni ordre) : pièce de passage vers la nef et la tombe, sans défaut.
3. **Caisses très basses** : 200 FR par église pour un salaire de 100 FR/jour ; aucun salaire religieux n'a encore été versé (aucun PJ prêtre), mais un PJ prêtre viderait la caisse en deux jours si les dons ne suivent pas. Commun aux trois villes.

## Décisions de Fred (01/11/2026)

- Nom : **Église Progressiste de Montrouge** (écran, vue de rue, fiche de l'Abbé Tonnière, libellé du salaire).
- **+500 FR** dans la caisse de chaque église : migration `20261101060000` **appliquée par Claude le 01/11** (caisses à 700 FR, marque `dotation_20261101`).
- Salaire religieux ramené à **50 FR/jour** (prêtre et supplément du Grand Prêtre) : migration `20261101061000` **appliquée par Claude le 01/11** ; texte des règles mis à jour. Rappel : il rémunère la charge (prêtre, Grand Prêtre), versé une fois par jour, sans tâche ; « Prier le Formulaire Sacré » ne rapporte rien en FR (moral et piété seulement).
- À développer plus tard (idée de Fred) : dons en nourriture à l'église pour que le prêtre mange gratuitement (issue GitHub ouverte le 01/11).
