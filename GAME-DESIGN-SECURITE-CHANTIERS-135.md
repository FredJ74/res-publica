# Sécurité privée des chantiers — décisions de référence (#135)

Source : décisions antérieures rappelées explicitement par Fred dans cette conversation le 27 octobre 2026 ; principe également conservé dans `AGENTS.md` par la PR #195 (`051e6ad`). Cette référence distingue les décisions du jeu de leur degré d'implémentation.

## Décidé

- Les vigiles de chantier sont des agents de sécurité privée. Recrutement, emploi, affectation, présence et combat réutilisent les socles communs ; aucun moteur parallèle.
- Leur employeur et leur affectation déterminent leurs prérogatives. Un nombre dans le JSON d'un chantier ne représente pas un agent réel.
- Ils peuvent intervenir face à un PJ recherché, **uniquement après sa détection effective**. La détection précède obligatoirement toute tentative d'interception ou d'arrestation.
- Cela ne leur confère aucun poste ou pouvoir institutionnel de policier et n'autorise aucune détention privée nouvelle.
- Les cinq terrains partagent les mêmes mécanismes et conservent leurs caractéristiques individuelles.
- Les coûts, probabilités, pénalités et récompenses existants du vol sont conservés ; le navigateur ne décide plus du résultat. Les contreparties doivent être atomiques et couvertes par un reçu unique.
- Les malus existants sont inchangés : 20 pour le premier vigile, puis 10 par vigile supplémentaire (`malusVigiles`, `plateau-chantiers.js`).
- Les tests dangereux restent isolés ; Arnie n'est ni déplacé, ni engagé dans un vol, une arrestation ou un combat.

## Implémentation préparée, non déployée

Le lot du 27 octobre relie les affectations aux membres du socle PNJ, détache les employés avec `pnj_quitter_groupe`, lit `pnj_position_effective` et filtre les agents réellement présents. Le vol est une action de `chantier_commande`, avec son reçu existant.

Le détecteur commun retrouvé dans l'historique Git est factorisé sur ses fragments exacts : police et agents privés partagent perception de groupe, calcul et tirage. Les preuves privées étendent le registre commun des tentatives ; aucune rencontre policière n'est fabriquée. Une porte interne vérifie à nouveau la preuve, la présence, le mandat et les recherches avant toute future intervention. La primitive `combat_coup_resoudre` existante est réutilisable, sans nouveaux taux ou dégâts.

**Ces éléments ne constituent pas encore un parcours d'interception/combat/remise en police terminé.** Les tests des primitives ne prouvent pas cette orchestration terminale.

## Modalité terminale à établir

Les sources accessibles ne décrivent pas la modalité précise de retenue puis remise à la police après neutralisation par un agent privé. Une question ciblée a été envoyée à Fred sur la réutilisation du délai d'intervention du circuit de signalement existant et l'attente sur place. En l'absence de réponse ou de référence retrouvée, ne pas inventer de prison privée, de transfert automatique ou d'arrestation institutionnelle par les vigiles.

Ce point ne remet pas en question leur droit d'intervenir, déjà décidé. L'absence de son implémentation n'est pas une interdiction de game design.

## Vérifié et restant

Voir `outils/audits/VIGILES-VOL-ATOMIQUE-135-20261027.md` pour les preuves isolées, le prévol vivant, la dépendance du bonus de bénédiction et les limites authentifiées. Ne pas confondre règle décidée, code préparé, test local et fonctionnalité effectivement installée.
