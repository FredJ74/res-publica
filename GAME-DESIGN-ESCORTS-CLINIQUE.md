# Cliniques privées : escorts et chambres

Décisions de Fred du 13/11/2026 (tour de Novomirsk). Migration `migrations/20261113013000_clinique_escorts_nuitee_serveur.sql`.

## Escorts en clinique

- L'ordre « Appel à un(e) escort » est proposé dans les chambres de **toutes les cliniques privées**, en Républia comme en Sovarka.
- Il est ouvert à l'**occupant de la chambre** : le client d'une nuit (réservation à 150) **et** le patient hospitalisé. Un visiteur autorisé ne peut pas appeler.
- **Même mécanisme et mêmes barèmes que les résidences de Novomirsk** : standard de l'agence internationale Roxane Velours (Rebecca), réponse libre, validation, refus, 800 par escort et par jour (FR en Républia, PSK en Sovarka), rumeur et projet d'article, « Faire l'amour ». Les gains s'ajoutent à ceux de la nuit en clinique. L'idée d'une ligne « soins de confort » sur la facture a été écartée : pas assez explicite.
- En clinique, le tirage ne propose **que les deux escorts des cliniques** : **Irina** (infirmière) et **Boris** (infirmier). Elles n'apparaissent nulle part ailleurs. Il y a donc au plus une femme et un homme par appel.
- Portraits : `images/personnages/Clinique_escort_Irina.webp` et `Clinique_escort_Boris.webp`, avec leurs vignettes.

## Escorts de Sovarka (correctif)

Ludmilla Bonaskova et Boris Kostof (ajoutés le 12/11, « uniquement en Sovarka ») n'étaient jamais tirés : le tirage ne lisait que le catalogue de Républia. Ils le sont désormais pour un personnage en Sovarka, en plus de l'agence de Républia, comme avant.

## Boutons des chambres de clinique

| Bouton | Client d'une nuit | Patient hospitalisé |
|---|---|---|
| Autoriser / Interdire les visites | oui | oui |
| Soins (standard, accélérés, sans trace), centre anti-poison | oui (« pas d'état d'âme dans une clinique privée ») | oui |
| Appel à un(e) escort | oui | oui |
| Dormir dans la chambre | oui | oui |
| Prendre le repas de la clinique | oui (chantier ChatGPT du 13/11) | oui |
| Sortir de l'hôpital | non | oui |
| Fouiller ou voler | oui | oui |

Retirés : « Installer un commerce » et « Option Commerce » (une chambre n'est pas un local commercial ; le serveur refusait déjà), « Vérifier les bonus de la nuit » (la nuit est créditée par le serveur au moment du sommeil).
