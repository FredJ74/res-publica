# #135 — Mesure de position initiale et validation des salaires actuels

## État réel reçu

Main repris : `348865998c8eede33ba18e32f3da9f8f27149117` (#167). Branche de reprise : `codex/recette-immobilier-135-20261025`. Les modifications d'ambassades et du Bureau de l'Emploi présentes sur main sont conservées, sans modification propre de leurs fichiers métier.

Le responsable a transmis les résultats de la [quatrième campagne](https://github.com/FredJ74/res-publica/actions/runs/40237138029) et indique que son analyse figure dans un commentaire de #167 : authentification fonctionnelle, serveur avant/après sur `quartier-ambassades / accueil_ambassades`, interface mesurée `null / null`, personnage inchangé. Cette information est utilisée comme un résultat réel **transmis**, pas comme un rapport téléchargé ou une campagne exécutée par Codex. L'accès API au rapport reste refusé. Aucune visite initiale n'a été validée par ce résultat.

## Défaut reproduit et correction

`consulterPositionExistante` conservait `s = await identite()` **avant** l'attente de visibilité, le chargement des images et la relecture serveur. Le champ `positionDiagnostic.interface` était construit à partir de cette ancienne capture. Il ne prouvait donc pas la position affichée au moment de la comparaison finale.

L'application restaure un bâtiment par `restaurerPositionApresChargement`, avec un callback différé de 300 ms. Le banc reproduit le rejet d'une position correctement restaurée pendant ces attentes. Il exerce aussi une lecture serveur asynchrone et le véritable callback dans Chromium, avec les lieux de la quatrième campagne et une identité strictement fictive.

Le correctif du pilote :

1. vérifie toujours l'identité avant la scène ;
2. reprend une mesure fraîche de l'interface après les attentes et la lecture serveur ;
3. si et seulement si le serveur est resté **exactement** au lieu du prévol, attend au plus 30 secondes la restauration locale ;
4. relit ensuite serveur et interface, et exige les mêmes égalités strictes ;
5. conserve le diagnostic #167 et précise si une attente locale a eu lieu et a expiré.

Ce n'est pas une navigation : aucun appel à `enterBuilding`, `enterRoom`, une RPC d'écriture, une sauvegarde ou une affectation de position n'est ajouté au pilote. Les écritures et mouvements restent bloqués par la garde réseau existante. Aucun sondage périodique Supabase ; seule une deuxième lecture bornée intervient après l'attente DOM. `null`, chaîne vide et identifiants de rue ne sont jamais assimilés. Une vraie divergence serveur, un changement de compte/personnage ou une interface toujours différente restent refusés.

**La course est démontrée et corrigée localement. La résolution effective du cas d'Arnie nécessite encore une campagne du testeur corrigé.** Le diagnostic transmis est compatible avec cette course, mais ne permet pas d'exclure à lui seul un autre défaut de restauration du client déployé. Aucun contrôle n'est supprimé pour conclure prématurément.

## Tests exécutés

| Vérification | Résultat |
| --- | --- |
| Pilote complet, dernière version | **97/97**, aucun test ignoré |
| Nouveaux cas de position, inclus ci-dessus | **9/9**, dont Chromium et callback réel à 300 ms |
| Bancs clients complets après reprise de main | **105/105** |
| Matériaux, prix configuré par le propriétaire, francs entiers, dons, concurrence, rollback | **Banc PostgreSQL jetable réussi**, pas de nombre d'assertions inventé |
| Progression, fonds, délais et commandes historiques | **62/62 assertions**, conservées par le banc étendu |
| Salaires actuels via la même commande | **15/15 assertions supplémentaires** |
| Cinq parcours complets avec la migration actuelle des salaires ajoutée à l'assemblage | **324 assertions réussies** ; acquisitions/banque : **61 assertions** également exécutées par ce banc |
| Contrôles globaux | **4/12**, mêmes lignes de verdict et mêmes écarts que sur main intact |

Les nouveaux tests SQL utilisent sans la modifier la migration de Claude `20261025070000_chantier_taux_horaire.sql`, jouée deux fois sur une base jetable. Ils vérifient le minimum de 50 FR, le refus des fractions, un taux de 90 FR donnant 180 FR pour deux heures, le paiement d'un ouvrier tiers, l'interdiction pour celui-ci de fixer le salaire, le plafonnement par la trésorerie, le rejeu, deux appels concurrents et l'annulation de toutes les contreparties sur panne finale. L'ancienne RPC non versionnée reste fermée. La CI appelle ce banc étendu, qui rejoue intégralement les 62 assertions historiques avant ses 15 cas supplémentaires.

Les tests de position refusent un serveur déplacé depuis le prévol sans attendre son éventuel retour ; ils refusent aussi une mutation serveur pendant l'attente, une interface réellement différente, des formes de lieu différentes et un changement d'identité. Les résultats bruts avant correction et après sont archivés. Aucun compte ni mot de passe réel n'est utilisé par ces tests.

## Limite indépendante identifiée sans toucher au BNE

Le lecteur actuel `bne_heures_chantiers` appelle `chantier_besoin_jour_interne(jsonb,integer)`. Sa définition n'est pas archivée dans le main examiné. Une tentative isolée de chargement du lecteur a donc échoué sur cette dépendance. Cela **ne prouve pas son absence en production**. Les salaires eux-mêmes sont testés avec leur moteur réel ; la cohérence de ce lecteur BNE n'est pas présentée comme validée.

Aucun helper fictif et aucune ancienne migration de réaménagement d'une autre branche ne sont importés pour obtenir un résultat vert. Il faut obtenir la définition et les droits réels de cette dépendance via le catalogue vivant avant une validation de ce raccordement. Le fichier de Claude n'est pas modifié.

## Ce qui est intégré et ce qui reste ouvert

| Élément du parcours | État vérifiable dans cette session |
| --- | --- |
| Cinq terrains, identités, superficies et prix individuels | Bancs conservés ; cinq parcours SQL réussis, pas de visite authentifiée des cinq scènes |
| Achat/compromis, conditions, plafonds, Banque nationale | Transferts et reçus éprouvés en isolation ; aucune transaction d'Arnie |
| Permis et instruction | Tests acquis et parcours complet isolé ; aucun dépôt réel avec Arnie |
| Lancement, matériaux, prix du propriétaire | Moteurs existants éprouvés en isolation, aucun tarif modifié |
| Salaires et travail | Migration actuelle testée sur commande commune, y compris ouvrier tiers et incidents |
| Vigiles et sécurité privée | Aucun contrôle vivant supplémentaire attesté ; pas de combat provoqué avec Arnie, ne pas déclarer cette partie intégralement validée |
| Progression/délais, appels de fonds, doubles opérations | 62 assertions de base et cinq parcours complets ; aucun nouveau pays P2W ou coefficient inventé |
| Achèvement, réception, persistance | Réception concurrente, rollback et relecture depuis une autre session éprouvés uniquement sur PostgreSQL jetable |
| Connexion réelle et affichage initial | Authentification signalée réussie sur la quatrième campagne, contrôle de position échoué ; correction locale en attente de confirmation réelle |

Les huit contrôles globaux rouges (Workflow, Classification, Baseline, Authority, Referential, Fonctions, Assemblage, Reconstruction) sont reproduits sur `3488659` intact. Aucune empreinte ni observation n'est ajustée pour les masquer. Ils ne sont pas présentés comme des régressions de ce correctif, ni comme des réussites.

## Livraison et opérations distantes

Le code principal est sauvegardé au commit `5b01ba4` ; les compléments et preuves suivent sur la même branche. La création d'une PR en brouillon a été tentée, mais `api.github.com/graphql` répond `Forbidden`. Aucune PR créée, aucun contrôle GitHub de cette nouvelle correction consulté, aucune fusion par cette session. La lecture du rapport Actions existant est également refusée ; les mêmes appels ne sont pas répétés indéfiniment.

La tentative réelle de lecture de `https://res-publica.vercel.app/plateau.html` est refusée au niveau du tunnel proxy (403). Le runner de la quatrième campagne a atteint le jeu selon les résultats transmis ; une panne générale de Vercel n'est donc pas déduite de notre refus réseau. La version effectivement servie n'est pas contrôlable ici. Le correctif du pilote ne nécessite aucune migration ni modification du jeu, mais doit être intégré dans main pour être utilisé par le workflow autorisé.

Après revue, contrôles GitHub et intégration du correctif : lancer **une seule** campagne sur [le workflow existant](https://github.com/FredJ74/res-publica/actions/workflows/beta-testeur-luthecia.yml), branche **main**, mode **consultation_seule**. Aucun secret à modifier. Lire l'artefact `luthecia-joueur-<run_id>`, même si le code 2 indique une consultation seulement partielle. Ne pas relancer encore l'ancien #167 en espérant qu'il contienne cette correction. Les mouvements et actes financiers d'Arnie restent interdits.

**CHANTIER NON TERMINÉ EN PRODUCTION.** Correction et vérifications isolées sauvegardées ; intégration, confirmation de position réelle, vérification du catalogue et sécurité privée vivante restent non attestées. Aucune donnée d'Arnie modifiée, aucune migration appliquée. Les preuves et leur manifeste sont dans `outils/audits/position-135-20261025/`.
