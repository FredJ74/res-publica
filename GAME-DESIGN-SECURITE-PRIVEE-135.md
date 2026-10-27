# #135 — Détection et confrontation : policiers et sécurité privée

## Arbitrages de Fred du 27 octobre 2026

1. La détection d'un PJ recherché est un **jet**, jamais automatique.
2. Les policiers interviennent en premier. La sécurité privée ne commence ses jets que si **tous** les jets policiers ont échoué.
3. Dans chaque catégorie : groupes **réellement constitués**, par taille décroissante ; à taille égale, ordre aléatoire. Les agents isolés constituent chacun une unité distincte. Plusieurs agents présents dans une salle ne deviennent jamais un groupe par simple co-présence.
4. Chaque unité passe son jet selon la formule de détection **déjà existante** (PER du groupe : moyenne + effectif moins un ; dilution en rue). Dès la première réussite, plus aucun autre jet n'est lancé.
5. L'unité ayant détecté le PJ est **la seule** à procéder à l'interpellation et, le cas échéant, au combat : agent isolé = combat 1 contre 1. Les autres policiers et agents privés restent hors de ce combat.
6. En cas de reddition ou de défaite, même circuit judiciaire et pénitentiaire que la police. Lorsqu'il s'agit d'un agent privé, le récit précise sa remise du PJ à la police.
7. Aucun statut ni placement « vigile de chantier » : la sécurité privée utilise les socles PNJ existants (embauche, groupe et déplacement) et police existants (détection, fuite, combat, détention).

## Implémentation de travail — PR #212 (non déployée)

- `securite_ordre_detection_interne` constitue les unités par appartenance explicite, puis les ordonne police avant privé, effectif décroissant et tirage aléatoire à égalité.
- Les PNJ privés utilisent `leader_pnj_id` ; les policiers sont isolés par matricule, sauf présence d'un `groupeId` explicite.
- `police_detection_verifier` exécute les jets successifs, puis enregistre le seul groupe retenu dans `police_interceptions.intervenants`.
- `police_fuite_resoudre` et `police_combat_resoudre` ne retiennent que ces intervenants pour cette rencontre ; les rencontres historiques sans cette information gardent leur contrat antérieur.
- Aucune table de vigiles affectés ni nouveau moteur de confrontation.

## Limites et validation restantes

- **Le catalogue actuel des policiers ne définit pas encore une opération de constitution de groupes ni ne renseigne `groupeId`**. Les policiers actuellement affectés individuellement se comportent donc comme des unités isolées. Un groupe explicitement constitué sera reconnu lorsqu'un dispositif métier existant fournira son identité ; ne surtout pas inférer un groupe à partir de la seule localisation.
- La PR #212 et la migration sont encore en brouillon, non fusionnées et non appliquées en production.
- Bancs : `banc-securite-privee-socle-135.sql`, `banc-securite-privee-issues-135.sql` et `banc-securite-privee-priorites-135.sql`, tous lancés après la migration dans `BEGIN/ROLLBACK` sur des données fictives.
- Vol de matériaux/inventaire : périmètre de Codex, à raccorder sans modifier ses fichiers concurrents.
