# Hospitalisation — règles du game designer

Décision de Fred, 1er novembre 2026. Référence pour tout agent : ne pas redemander ce qui est
tranché ici.

## Déclencheur

- Un PJ dont les **PA tombent à 0** est transféré **automatiquement** à l'hôpital public de
  l'endroit où il se trouve. Deux cas :
  - il a consommé tous ses PA en passant des ordres ;
  - il a perdu un combat.
- **L'empoisonnement fonctionne différemment** : il n'entre pas dans cette règle.
- Cette règle **remplace les anciennes durées par palier** de l'agression et de l'assassinat
  (dispensaire 6/4/2 jours, clinique 3/2/1 jour) — précision de Fred, 01/11.

## Condition de sortie (modification de Fred, 01/11)

- **On ne peut pas sortir de l'hôpital tant qu'on n'a pas atteint 20 PA.** À l'hôpital public,
  cela ajoute une nuit de plus ; en clinique (24 PA à J2), la sortie reste à J2.
- **À partir de J3, le Dormir rend la récupération classique : 12 PA** (plus le repas de la
  veille s'il a été pris). Exemple à l'hôpital public : J1 2 PA (repas −1), J2 +6 +2 ≈ 9,
  J3 +12 (+2) ≈ 21 à 23 → sortie à J3.

## Hôpital public (dispensaire de la ville)

| Jour | Ce qui se passe |
|---|---|
| J0 (jour du transfert) | Ne peut pas bouger de la journée. Ne peut pas passer l'ordre Dormir. Ne peut ni écrire de mail ni poster sur les forums. |
| J1 | En passant Dormir, ne récupère que **2 PA** : très faible. Peut consommer **un repas servi par l'hôpital (1 PA)**, qui donne **+2 PA le lendemain**. Ne peut pas sortir de l'hôpital, mais peut écrire des mails et sur les forums. |
| J2 | En passant Dormir, récupère **6 PA**, plus les **2 PA du repas** de la veille s'il l'a pris. Sortie seulement à partir de 20 PA (voir plus bas). |

## Clinique privée

- Sur demande du PJ (transfert payant, 1 000 FR aujourd'hui).
- **Même fonctionnement**, seule différence : les PA récupérés sont **multipliés par trois** —
  **6 PA** à J1, **24 PA** à J2.
- Le transfert est possible **dès J0** : c'est une ambulance qui transporte le patient (RP), pas
  le patient qui se déplace par l'interface. Il n'est donc pas soumis à l'immobilisation.

## Implémentation (Claude, 01/11/2026 — chantier hospitalisation, PR dédiée vers #318)

Correctif serveur : `migrations/20261101171000_hospitalisation_pa0.sql`
(à placer après celui de #318). Bancs : `outils/bancs/banc-hospitalisation.sh` (30 cas, contre-épreuve
`--contre`), `outils/bancs/banc-hospitalisation-client.cjs` (12 cas, contre-épreuve `CONTRE=<ref>`).

- **Règle décidée → implémentée** : chaque point des tableaux ci-dessus, côté serveur ; l'écran ne fait
  qu'afficher et relayer les refus nommés. Non déployé, non testé en jeu.
- **Précisions de Fred (01/11, 16 h 50)** :
  - Clinique : la sortie intervient après deux ordres Dormir (6 puis 18 PA, ×3 à chaque nuit) : conforme.
  - **Rébellion** : un suspect tombé à 0 PA au terme d'un combat contre les policiers, et arrêté, passe J0
    à l'hôpital (sous écrou). Le lendemain, son Dormir lui rend 2 PA, puis il est reconduit dans la foulée
    dans sa cellule pour purger sa peine. **Pendant toute cette détention, chaque Dormir ne lui rend que
    4 PA** : sanction de la rébellion.
  - **Repas** : l'ancien « Manger » des chambres de la clinique est supprimé. À la clinique, le repas est
    plus cher et rapporte **4 PA** au lieu de 2 (repas de la clinique : 1 PA et 30 FR, le prix de l'ancien
    « Manger » ; hôpital public : 1 PA, gratuit, +2 PA).
- **Lectures techniques de l'agent** (sans incidence de game design) :
  - La sortie est un ordre (« Sortir de l'hôpital ») ; le patient sort dans la rue, par la porte du bâtiment.
  - Le repas est possible chaque jour d'hospitalisation à partir de J1 (à J0, le patient n'a aucun PA).
  - Mails et forums : refusés à J0 pour tout ce que le PJ écrit lui-même, y compris au nom d'une
    organisation ; lire le forum reste bloqué à J0 comme avant.
  - Ville sans dispensaire référencé : hospitalisé sur place, immobilisé.
  - Un PJ **déjà détenu** dont les PA tombent à 0 dans sa cellule y reste (la règle de rébellion ne vise que
    l'arrestation au terme du combat) ; un rebelle libéré avant J1 reste un patient ordinaire.
  - L'ancienne règle « haut placé → clinique d'office » ne s'applique plus qu'à l'empoisonnement.

## Conséquences techniques retenues (choix techniques de l'agent)

- Le transfert à l'hôpital et en clinique est un déplacement **décidé par le serveur**
  (porte `hospitalisation_lieu_rejoindre`, PR #318 vers #219), jamais une navigation de l'écran.
- L'immobilisation J0/J1 est une interdiction serveur (la navigation commune de #219 refuse déjà
  un PJ hospitalisé ; la fin d'immobilisation doit coïncider avec le Dormir de J2).
