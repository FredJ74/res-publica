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
- Les PNJ privés utilisent `leader_pnj_id` ; les policiers sont isolés par matricule, sauf présence d'un `groupe_id` explicite issu du socle militaire (ancien alias `groupeId` accepté).
- `police_detection_verifier` exécute les jets successifs, puis enregistre le seul groupe retenu dans `police_interceptions.intervenants`.
- `police_fuite_resoudre` et `police_combat_resoudre` ne retiennent que ces intervenants pour cette rencontre ; les rencontres historiques sans cette information gardent leur contrat antérieur.
- Aucune table de vigiles affectés ni nouveau moteur de confrontation.

## Limites et validation restantes

- **Le catalogue actuel des policiers ne définit pas encore une opération de constitution de groupes ni ne renseigne `groupeId`**. Les policiers actuellement affectés individuellement se comportent donc comme des unités isolées. Un groupe explicitement constitué sera reconnu lorsqu'un dispositif métier existant fournira son identité ; ne surtout pas inférer un groupe à partir de la seule localisation.
- La PR #212 et la migration sont encore en brouillon, non fusionnées et non appliquées en production.
- Bancs : `banc-securite-privee-socle-135.sql`, `banc-securite-privee-issues-135.sql` et `banc-securite-privee-priorites-135.sql`, tous lancés après la migration dans `BEGIN/ROLLBACK` sur des données fictives.
- Vol de matériaux/inventaire : périmètre de Codex, à raccorder sans modifier ses fichiers concurrents.

## Vérification du socle militaire (28/10)

La fonction existante `militaire_bataille_groupes_constituer(bigint)` regroupe les `batailles_engagements` par `groupe_id`, en conservant compagnie, section, chef et effectif initial dans `batailles_groupes`. Cette mécanique concerne les **engagements dans une bataille** : elle ne constitue pas directement une patrouille dans une rue. Le raccordement de sécurité reconnaît désormais le même identifiant `groupe_id` pour des policiers déjà groupés, au lieu d'introduire un format concurrent. Les policiers sans identifiant explicite restent isolés. Les agents privés conservent le lien PNJ existant `leader_pnj_id`.

**Reste à confirmer** le chemin existant entre les unités militaires constituées et les effectifs policiers affichés dans `effectifsPolice` ; ne pas affirmer que le regroupement policier est entièrement opérationnel avant cette preuve.

## Socle universel des groupes — précision de Fred du 28/10/2026

**Règle applicable à tous les PJ et PNJ, indépendamment de leur métier.** Le groupe n'est ni un dispositif propre aux militaires ni une affectation spécifique de la police ou de la sécurité privée.

- Tout groupe a un **PJ chef de groupe**. D'autres PJ peuvent le rejoindre, ainsi que des PNJ suivant les ordres de leur employeur ou les règles existantes du jeu.
- **Seul le chef déplace le groupe** : les membres suivent le déplacement du chef. Un membre non-chef ne déplace pas le groupe de manière autonome.
- Le chef peut **déployer sur sa position actuelle la totalité ou une partie des membres** : seuls les membres non déployés continuent à le suivre. Les membres déployés deviennent des unités présentes à cet endroit, et ne doivent pas être automatiquement agrégés à un groupe d'autres agents présents.
- En matière de détection et de combat, il faut distinguer les groupes réellement conservés ensemble des unités isolées ou déployées individuellement. Priorités : police d'abord, sécurité privée ensuite, groupes les plus importants d'abord, tirage aléatoire en cas d'effectifs égaux ; seul le groupe qui réussit le jet intervient.
- Le texte de règles de Kraland fourni par Fred le 28/10 est une **inspiration d'esprit** (rejoindre/quitter, commandement, déplacement collectif, participation au combat), **pas une spécification à recopier**. Ne pas reprendre sans arbitrage la formule de capacité, les dépenses de CT, les interdictions d'ordres, la capture ou les règles de coma/ligotage/équipement.

### État vérifié et lacune technique

Dans la base existante, `pnj_membres.leader_pj` et `pnj_membres.leader_pnj_id` représentent déjà des liens de suivi PNJ ; `militaire_bataille_groupes_constituer(bigint)` et `batailles_engagements.groupe_id` représentent des groupes au cours d'une bataille. **Ces deux constatations ne prouvent pas que les PJ disposent déjà d'un groupe universel opérationnel.** Le schéma inspecté de `personnages_donnees` ne comporte pas de colonne explicite `leader/groupe/chef`. Il faut identifier l'implémentation du groupe PJ, ses règles de déplacement et de déploiement avant de prétendre finaliser le raccordement.

Conséquence : **ne pas confondre** `groupe_id` d'un engagement militaire (éphémère et lié à une bataille) avec l'identité persistante d'un groupe PJ/PNJ en exploration. Ne pas créer un moteur concurrent, une table ad hoc de vigiles, ni déduire un groupe de la seule co-présence.
