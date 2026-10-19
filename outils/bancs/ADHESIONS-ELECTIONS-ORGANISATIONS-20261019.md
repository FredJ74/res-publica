# Organisations : adhésions, grades et dépouillement — 19 octobre 2026

**CHANTIER PRINCIPAL NON TERMINÉ.** Deux lots supplémentaires sont codés et testés localement. La fermeture des écritures générales et l'activation des équipements ne sont pas effectuées. Aucun déploiement SQL ni parcours authentifié Supabase n'est revendiqué.

## État repris

Reprise propre de `260e3a6`, dont le propriétaire confirme le déploiement Vercel READY en production. Rapports `SECURISATION-ORGANISATIONS-20261019.md`, `LIVRAISON-ORGANISATIONS-20261019.md` et `SESSION-NOCTURNE-20261019.md` relus. Les lots déjà testés ne sont pas redéveloppés. Dernier fetch avant livraison : aucun changement distant concurrent à intégrer.

Le jeu, l'API GitHub Actions et le REST Supabase restent inaccessibles depuis cette session : tunnel HTTP rejeté, 403 avant réponse de l'application. Aucun connecteur Supabase/Vercel exposé. Git fonctionne. Il ne s'agit pas d'une preuve de panne ou de quota Vercel ; la confirmation indépendante READY de `260e3a6` reste valable.

## Nouveaux mécanismes

### Adhésions et grades

Migration préparée `migrations/20261019130213_organisations_adhesions_grades.sql`.

La nouvelle commande `organisation_commande_membres` utilise le registre de reçus administratif existant. Identité authentifiée, ligne verrouillée, autorisations actuelles et intention restreinte : aucun blob de remplacement fourni par le client.

Actions couvertes : demander une adhésion publique, accepter/refuser une demande par le chef, accepter/refuser sa propre invitation enregistrée, promouvoir/rétrograder un membre par le chef. Ni auto-invitation ni adhésion sans demande/invitation réelle. Une organisation secrète reste accessible par invitation, sans candidature spontanée.

Les échelles de grades et `maxAdhesion` des **neuf types** sont chargés depuis le vrai `data.js` par `outils/generateurs/generer_organisations_regles.cjs`, puis produits en fonction SQL privée. Aucun grade ni plafond ressaisi manuellement. La CI compare la génération complète à la migration. Les neuf types et leurs quatre échelles nationales sont éprouvés. La caisse, l'élection et les clés historiques inconnues restent intactes.

Les admissions sont sérialisées par personnage, y compris entre deux organisations : deux admissions simultanées de même type et pays ne peuvent contourner la limite existante d'une adhésion. Les requêtes strictement identiques sont rejouables ; réutilisation de nonce avec une autre commande refusée. Une erreur tardive de reçu annule l'admission et la disparition de la demande.

### Progression et dépouillement des élections

Migration préparée `migrations/20261019130951_organisations_progression_elections.sql`, dépendante du lot précédent.

Elle étend la même commande, sans créer un moteur par type d'organisation. Le jour provient du personnage authentifié en base. La phase candidatures passe en vote à l'échéance ; le vote est dépouillé à son échéance. Le nombre de voix départage les candidats ; à égalité, l'ordre des candidatures est conservé, y compris lorsqu'il n'y a aucune voix. Aucun candidat : direction conservée, élection close. Le gagnant reçoit le grade supérieur correspondant au type et au pays.

Passage de phase, choix du dirigeant, grades, clôture et reçu font partie de la même transaction. Le passage intermédiaire en phase vote permet à la garde de direction déjà développée de reconnaître un dépouillement légitime ; une erreur ultérieure annule aussi cette étape. Le test d'intégration utilise la vraie garde et l'inventaire collectif : le matériel reste propriétaire `orga:`, le gagnant obtient l'accès et l'ancien dirigeant le perd.

La migration accepte uniquement la définition précédente examinée et sa propre définition. Elle ne remplace aucune source vivante inconnue. Le fichier a d'abord été sauvegardé sous le nom `20261019133500_organisations_progression_elections.sql` dans `1a5dc20`, puis renommé avec l'heure UTC réelle de rédaction ; son contenu SQL est identique. Ne pas appliquer les deux noms depuis des checkouts historiques : lire le registre et la définition effective avant toute opération.

Le déclenchement PAYANT d'une nouvelle élection n'est pas migré par ce lot. Aucun coût en PA/argent changé ou supprimé.

## Navigateur et anciens chemins

Sept actions de membres et la progression électorale utilisent les intentions serveur lorsqu'elles sont disponibles. Pas de sauvegarde générale après refus ou panne. Le seul repli transitoire reste l'absence explicitement confirmée du contrat (404/PGRST202), pour préserver la production où les nouvelles migrations ne sont pas appliquées.

Les succès, journaux et notifications d'adhésion attendent la confirmation. Les annonces de résultat électoral réutilisent la même fonction pour le chemin serveur et le chemin ancien. La liste est relue depuis le serveur, sans réappliquer le solde d'un ancien reçu. Un changement de personnage pendant la progression interrompt toute la boucle, pas seulement la première réponse.

**Aucun chemin global n'est définitivement supprimé et aucun droit général n'est révoqué.** Les sauvegardes directes correspondantes sont évitées lorsque le nouveau contrat traite l'intention, mais restent disponibles uniquement dans la transition explicitement documentée. Ce n'est pas une fermeture d'autorité côté Supabase.

L'envoi initial d'une invitation et ses contreparties mail ne sont pas encore migrés ; seuls acceptation/refus d'invitations déjà enregistrées sont couverts. Les courriers de notification après acceptation/refus restent ceux du mécanisme existant, non un nouveau système transactionnel de messagerie.

## Vérifications

- Banc membres/élections PostgreSQL jetable : **61/61 groupes**, dont les 36 combinaisons type/pays, admissions concurrentes, refus, crédits récents conservés, rejeu, injection de paramètres, rollback, ACL et refus de définition inconnue.
- Banc client membres/élections : **27/27 tests**, dont le miroir complet depuis `data.js`, chaque parcours en succès/refus/absence de contrat et l'arrêt sur changement de personnage.
- Banc équipements PostgreSQL : **33/33 groupes**, avec garde de direction réelle et continuité après dépouillement.
- Banc administratif PostgreSQL précédent : **41/41 groupes**.
- Réception : **31 groupes réussis** ; achat : **12** ; assemblage : **20/20** ; Jodie : **6/6**. SQL réel dans des bases jetables, identité et services annexes de fixture ; pas Supabase.
- Contre-épreuves existantes : **90/90**.
- Contrôleur client complet, après stabilisation des fichiers : **83/83 bancs réussis**, zéro échec.
- Syntaxe API : **23/23** ; calendrier : **5/5** ; payload simulé : **315,2 Mo / 330 Mo**.
- Contrôle global : **10/12**. Authority : **20** RPC utilisées absentes du baseline, contre 19 auparavant (nouvelle commande membres). Referential : mêmes deux divergences `ordres_couts` et `postes_nommes_regles`. Aucune référence observée ni empreinte changée pour masquer les écarts.

La CI existante inclut le nouveau banc PostgreSQL ; aucun pipeline de déploiement parallèle ajouté. Les contrôles historiques utilisent le venv PostgreSQL/pglast et le pont JSC/Node déjà disponibles ici, assertions conservées.

## Migrations et production

Aucune migration appliquée à Supabase par cette session. Les protections supplémentaires sont préparées, pas installées dans la base distante. Ordre de dépendance du nouveau lot : administratif `20261019094425`, membres `20261019130213`, progression `20261019130951`. Ne pas rejouer une ancienne version du corps après une évolution : les gardes doivent refuser cette régression.

Avant application : obtenir le catalogue vivant et le registre via les accès autorisés, utiliser les quatre extractions canoniques du workflow et le prévol en lecture seule (étendu aux nouvelles fonctions), comparer signatures, sources, triggers et ACL. Tester sous transaction annulée, puis appliquer suivant WORKFLOW-SUPABASE.md. Le garde d'empreinte ne remplace pas cette inspection.

Les migrations d'équipement `20261019064000` et `20261019064500` restent bloquées par les droits d'écriture générale. Réception, assemblage et Jodie restent préparés/testés sans application confirmée ici. Aucun baseline SQL généré modifié.

GitHub Actions et déploiement des nouveaux SHA : non observables par les API bloquées. Dernière production confirmée par le propriétaire : `260e3a6`. Aucun parcours authentifié ni fonctionnalité nouvelle vérifiée en production.

Aucune donnée réelle modifiée. Aucun solde, inventaire, livraison, poste ou personnage réinitialisé. Avoirs d'Angie, ses 2 000 FR et son placement bloqué de 500 FR avec échéance : aucune modification.

## Point de reprise exact

Restent réellement à implémenter avant fermeture :

1. Fondation/domiciliation générale, en préservant `syndicat_etudiant_domicilier` déjà serveur ; envoi initial d'invitations et contreparties de messagerie.
2. Déclenchement payant d'élections et publication associée dans une transaction cohérente. La progression/dépouillement est désormais préparée et testée : ne pas la reconstruire.
3. Actions métier, adhésions particulières dockers/supporters, grèves et actions collectives, coûts/PA/ressources et toutes contreparties financières.
4. Écritures de caisse, transferts/subventions, rumeurs et successions ; surtout sauvegardes globales `service_role` de minuit. Un service privilégié peut encore écraser un état récent même après fermeture des droits navigateur.
5. Migrer tous ces appelants, retirer alors les sauvegardes globales et replis, fermer effectivement INSERT/UPSERT/UPDATE/DELETE directs et examiner vues/RPC/tâches. Tester les fonctions légitimes après cette fermeture.
6. Appliquer les équipements uniquement une fois ces préconditions réunies et vérifiées en base ; ensuite raccorder les moteurs informatiques existants. Aucun raccordement métier déclaré réalisé par ce lot.

Le blocage de lecture/déploiement nécessite un accès technique de session aux services ; aucune manipulation SQL ou GitHub n'est demandée au game designer. Les développements encore manquants ne sont pas imputés au seul réseau : ils restent du travail de code et de tests.

## Sauvegardes

`bc22945` : adhésions/grades, générateur et tests, poussé sur main.
`1a5dc20` : dépouillement serveur et continuité des équipements, poussé sur main.
Le commit accompagnant ce rapport conserve le nom UTC corrigé, les vérifications de garde et l'arrêt de boucle lors d'un changement de personnage.
