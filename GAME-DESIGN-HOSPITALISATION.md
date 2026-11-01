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

Correctif serveur : `outils/audits/hospitalisation-20261101/migration-a-integrer-hospitalisation.sql`
(à placer après celui de #318). Bancs : `outils/bancs/banc-hospitalisation.sh` (25 cas, contre-épreuve
`--contre`), `outils/bancs/banc-hospitalisation-client.cjs` (10 cas, contre-épreuve `CONTRE=<ref>`).

- **Règle décidée → implémentée** : chaque point des tableaux ci-dessus, côté serveur ; l'écran ne fait
  qu'afficher et relayer les refus nommés. Non déployé, non testé en jeu.
- **Lectures retenues par l'agent, à confirmer par Fred si elles ne lui conviennent pas** :
  - « 24 PA à J2 » en clinique = total cumulé (6 à J1, puis 18 à J2) : le ×3 s'applique à chaque nuit
    (2→6, 6→18, 12→36 plafonné à 30). Le repas de l'hôpital reste +2 PA, même en clinique.
  - Un PJ **arrêté** au moment où ses PA tombent à 0 (combat perdu contre la police) reste en détention :
    pas d'hospitalisation.
  - La sortie est un **ordre** (« Sortir de l'hôpital ») que le patient passe quand il le veut à partir
    de J2 et de 20 PA ; il sort alors dans la rue, par la porte du bâtiment. Jusque-là, aucun
    déplacement, ni à J1 ni dans l'hôpital (sauf transfert en clinique).
  - Le repas est possible chaque jour d'hospitalisation à partir de J1 (à J0, le patient n'a aucun PA).
  - Mails et forums : refusés à J0 pour tout ce que le PJ écrit lui-même, y compris au nom d'une
    organisation ; les avis institutionnels qu'il reçoit passent. Lire le forum reste bloqué à J0 comme avant.
  - Ville sans dispensaire référencé : hospitalisé sur place, immobilisé (motif noté dans la fiche).
  - L'ancienne règle « haut placé → clinique d'office » ne s'applique plus qu'à l'empoisonnement :
    la règle à 0 PA dit hôpital public.
- **Point ouvert non bloquant** : les chambres de la clinique ont déjà un ordre « Manger » (1 PA, 30 FR,
  ancien traitement à l'écran) ; le « Repas de l'hôpital » s'ajoute à côté. Faut-il retirer « Manger » ?

## Conséquences techniques retenues (choix techniques de l'agent)

- Le transfert à l'hôpital et en clinique est un déplacement **décidé par le serveur**
  (porte `hospitalisation_lieu_rejoindre`, PR #318 vers #219), jamais une navigation de l'écran.
- L'immobilisation J0/J1 est une interdiction serveur (la navigation commune de #219 refuse déjà
  un PJ hospitalisé ; la fin d'immobilisation doit coïncider avec le Dormir de J2).
