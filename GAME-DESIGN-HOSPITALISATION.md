# Hospitalisation — règles du game designer

Décision de Fred, 1er novembre 2026. Référence pour tout agent : ne pas redemander ce qui est
tranché ici.

## Déclencheur

- Un PJ dont les **PA tombent à 0** est transféré **automatiquement** à l'hôpital public de
  l'endroit où il se trouve. Deux cas :
  - il a consommé tous ses PA en passant des ordres ;
  - il a perdu un combat.
- **L'empoisonnement fonctionne différemment** : il n'entre pas dans cette règle.

## Hôpital public (dispensaire de la ville)

| Jour | Ce qui se passe |
|---|---|
| J0 (jour du transfert) | Ne peut pas bouger de la journée. Ne peut pas passer l'ordre Dormir. Ne peut ni écrire de mail ni poster sur les forums. |
| J1 | En passant Dormir, ne récupère que **2 PA** : très faible. Peut consommer **un repas servi par l'hôpital (1 PA)**, qui donne **+2 PA le lendemain**. Ne peut pas sortir de l'hôpital, mais peut écrire des mails et sur les forums. |
| J2 | En passant Dormir, récupère **6 PA**, plus les **2 PA du repas** de la veille s'il l'a pris. Peut sortir. |

## Clinique privée

- Sur demande du PJ (transfert payant, 1 000 FR aujourd'hui).
- **Même fonctionnement**, seule différence : les PA récupérés sont **multipliés par trois** —
  **6 PA** à J1, **24 PA** à J2.
- Le transfert est possible **dès J0** : c'est une ambulance qui transporte le patient (RP), pas
  le patient qui se déplace par l'interface. Il n'est donc pas soumis à l'immobilisation.

## Conséquences techniques retenues (choix techniques de l'agent)

- Le transfert à l'hôpital et en clinique est un déplacement **décidé par le serveur**
  (porte `hospitalisation_lieu_rejoindre`, PR #318 vers #219), jamais une navigation de l'écran.
- L'immobilisation J0/J1 est une interdiction serveur (la navigation commune de #219 refuse déjà
  un PJ hospitalisé ; la fin d'immobilisation doit coïncider avec le Dormir de J2).
