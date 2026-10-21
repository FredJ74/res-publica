# PR56 — suite depuis 714c7b3, effets serveur immédiats

État : préparation locale, **ni fusion ni déploiement**. Les garanties de tous les ordres ne sont pas encore démontrées ; ce document remplace le verdict technique de l'étape précédente sans effacer son contre-exemple historique.

## Corrections réalisées

- Le même `impact_deposer` verrouille les personnages, conserve les contrôles d'identité, de coprésence et d'indice, puis applique les conséquences dans sa transaction. Santé, PA nuls, convalescence civile Europe/Paris (barèmes clinique/dispensaire existants), deux statistiques affaiblies, repère de régénération et journal sont écrits ensemble. Pas de déplacement SQL inventé : l'arrivée médicale continue de réutiliser la navigation historique à la prochaine interaction.
- La même ligne d'impact sert de reçu : auteur et paramètres sont liés à l'identifiant ; un rejeu après réponse perdue ne rejoue aucun effet, tirage ou événement, même après déplacement. La lecture de notification reste distincte de l'application. La colonne d’auteur est privée : droits SELECT limités aux colonnes de notification et projection REST explicite, afin de préserver les agressions non identifiées. La carte postale utilise le même canal, avec plafond quotidien serveur et gain de dix Moral inchangé.
- `impacts_realites_synchroniser` reprend les seules anciennes lignes physiques/cartes non appliquées, sous verrou, avec le même applicateur privé. Aucun rattrapage dans la migration. Les lignes anciennes sont aussi appliquées avant un nouvel impact, pour qu'une connexion tardive ne réapplique pas ensuite un état antérieur.
- Une fiche antérieure à l'agression ne peut effacer sa convalescence active : refus SQL `40001` de l'ensemble de l'écriture. Les soins gardant l'identité de l'impact restent possibles ; le contrôle n'est pas présenté comme une protection générale contre toutes les sauvegardes périmées. Les déplacements propres du patient vers la rue sont aussi refusés à la table, en conservant l'arrivée médicale et le transfert existants. Les actes serveur et les déplacements imposés par un autre acteur ne sont pas remplacés par cette garde.
- Le point public `rue_position_enregistrer` verrouille la fiche et refuse l'incapacité **avant** d'appeler le moteur existant. Celui-ci est conservé par renommage privé, sans recopier les interceptions ou la détention. Installation impossible sans lecture préalable du catalogue et empreinte fournie par l'agent de déploiement. Le banc utilise un moteur simulé : il ne certifie pas les règles de la rue réelle.
- `payer_ordre` lit la santé sous son verrou et refuse un débit d'effort/argent en cas de Santé nulle, en préservant les soins déclarés sur place et les consultations gratuites. Prix, ordre liquide/banque, formules et contrôles de fonds restent identiques. Cela ne rend pas transactionnels les anciens actes dont le débit et l'effet passent par des appels séparés.
- Le navigateur reprend le lecteur de fiche commun avant toute notification d'impact appliqué SQL. Il ne recalcule ni santé, ni dates, ni statistiques, ni bonus ni journal. Un échec de lecture bloque l'ordre ; aucun minuteur réseau ajouté. L'arrivée médicale est extraite de la fonction existante pour être réutilisée sans rejouer le traitement.
- Le panneau de combat collectif affiche tous les rapports de rounds déjà autorisés et renvoyés par sa RPC, au lieu du dernier seulement. Aucun rapport n'est fabriqué pour les neutralisations historiques, dont le jet reste client.

## Migrations préparées, jamais appliquées

1. `migrations/20261020233501_presences_realites_sans_battement.sql` — étape précédente.
2. `migrations/20261021115429_impacts_realites_immediates.sql` — canal, applicateur, rattrapage, protection de convalescence.
3. `migrations/20261021120231_rue_garde_realites.sql` — enveloppe du moteur vivant, exige `hg.prevol.rue_position_md5` issu de sa définition examinée.
4. `migrations/20261021120540_payer_ordre_garde_incapacite.sql` — garde du débit commun.

Les définitions connues sont épinglées ; une définition différente provoque un arrêt, pas un écrasement. Rejeu des migrations testé sur PostgreSQL jetable. Le baseline et les archives générées restent intacts.

## Limites restant bloquantes

- Catalogue, triggers, droits, RLS et dépendances réellement déployés non accessibles. Aucun outil Supabase disponible dans cette session. La définition vivante de la rue est indispensable avant validation de l'enveloppe et de ses appels internes : renommer conserve les dépendances PostgreSQL sur le moteur privé, donc d'autres RPC le référençant doivent être auditées.
- Tous les ordres ne passent pas par `payer_ordre`. Plusieurs producteurs historiques débitent avant une seconde RPC ; leur transaction complète n'est pas démontrée par les gardes ajoutées. Le jet et les armes de Neutraliser restent notamment clients, dette antérieure explicitement documentée dans l'archive. On ne prétend pas avoir sécurisé l'intégralité des combats ou des finances par une lecture navigateur.
- La position d'arrivée médicale utilise encore le moteur client historique, après acquisition du statut serveur. Sa prise en charge entièrement serveur et le lien entre événement et rapport réel doivent être raccordés aux définitions vivantes, sans contourner détention/interceptions ni inventer des rounds.
- Les crons existants élections, loyers et constructions ne sont pas modifiés. Le championnat conserve aussi des fonctions d'avancement clientes ; aucune preuve d'un ordonnanceur serveur équivalent n'est disponible. Retirer le sondage ne prouve pas cette autonomie. Cela reste une condition de clôture, pas une réussite déclarée.
- Les effets anciennement déjà marqués traités ne sont jamais réappliqués. Les anciennes lignes `pop/inf/dis/poison_start` sans producteur autorisé restent sur le consommateur historique ; aucun nouveau canal permettant d'en créer n'est ouvert.

## Validation et déploiement ultérieurs

Le prévol `outils/bancs/prevol-realites-56.sql` reste en lecture seule. Après accès autorisé, examiner les définitions et les tâches autonomes, les dépendances au moteur de rue, ainsi que les circuits de soins et d'effets séparés ; confronter les préconditions aux migrations. Tests authentifiés isolés obligatoires, y compris coma pendant inactivité, refus avant mutation, F5, soins/transfert, calendrier sans navigateur et accès aux rapports. Le propriétaire n'a aucune commande SQL à exécuter.

Aucune application en production, aucune donnée réelle modifiée. Mesures facturées absentes : compter aussi le nouveau rattrapage avant lecture, les octets par interaction et les anciennes versions de client. Zéro sondage inactif en fixture n'est pas une mesure de facture ni de toute la production.

## Résultats exécutés

- **95/95 bancs client**, **33/33 tests ciblés réalités**, **90/90 contre-épreuves existantes**, **5/5 tests calendrier** réussis. Lanceurs historiques exécutés via l'adaptateur local Node 24 ; JavaScriptCore natif indisponible. Un premier passage des contrôles globaux sans adaptateur s'est abstenu sur deux axes faute de moteur (9/12), puis leur exécution avec adaptateur a donné le résultat réel ci-dessous.
- **17/17 bancs PostgreSQL du workflow** réussis, y compris commerce, réservation, tournée, réception atomique, organisations, assemblages, rues et présences. Les trois nouveaux bancs couvrent **34 scénarios d'impacts**, **11 de garde de rue** (moteur simulé) et **8 du débit commun** (fonction réelle, dépendances annexes simulées). Ils ne certifient pas toutes les interactions avec les triggers vivants.
- Le **même audit d'agression**, sans changement de son assertion, échoue sur l'archive (code 1) et réussit après migration locale (code 0) : Santé 0, PA 0, hospitalisation acquise, zéro effet différé et une notification restant à lire. Le résultat historique rouge n'a pas été effacé. Nouvelle preuve : `PREUVE-REALITES-AGRESSION-CORRIGEE.json` ; reproduction `python outils/audits/auditer-realites-agression-local.py [--avec-correctif]`.
- Contrôles globaux : **10/12**. Authority : **30 RPC absentes du baseline**, dont les deux préparées de cette PR, et une signature privée créée par renommage non reconnue par l'inventaire statique. Le moteur de rue d'origine est absent de l'archive : prévol vivant toujours requis, aucune déclaration SQL fictive ajoutée pour verdir le contrôle. Referential : les trois empreintes `ordres_couts`, `postes_nommes_regles`, `miroirs_entreprises` restent divergentes. Aucun baseline ni seuil ajusté.
- Syntaxes SQL (pglast), YAML, API et inventaire syntaxique des minuteurs contrôlés. Toujours quatre intervalles : trois affichages locaux et un compte à rebours policier fini lié à un ordre.
- Nouvelle tentative HTTPS Supabase : **CONNECT 403 du proxy, avant le service**. Vérification CI distante via `gh pr checks 56` : **API GraphQL Forbidden**. Git push fonctionne ; `main` est resté à `baa9cb7e2b7f89db66cf268d21382deb0be2a3a2` lors du contrôle. Aucun lancement de déploiement, aucun compte réel utilisé.

Implémentation sauvegardée : `62085d1345b19ebbd159501ad28cdfab24540ce5`. Résultats structurés : `RESULTATS-REALITES-PR56-SUITE-20261021.json`.

**Verdict : chantier non terminé, PR non fusionnable.** L'anomalie immédiate d'`impact_deposer` est corrigée et éprouvée localement. La totalité des ordres et le calendrier autonome nécessitent encore le raccordement des circuits historiques et la confrontation au catalogue vivant ; les limitations sont techniques, pas des arbitrages de game design. Les migrations restent préparées, non appliquées.

Dernière revue de confidentialité : le nouveau lien auteur/reçu ne doit pas dévoiler l’agresseur à la victime. Les tests SQL vérifient le refus réel de `SELECT auteur` pour authenticated et le succès de la projection autorisée. L’ancien client utilisant `SELECT *` doit être remplacé lors de la bascule ; conserver la garde de sauvegarde et le lecteur compatible avec `applique_serveur` lors d’un retour arrière. Ne jamais annuler les effets réels ni restaurer de vieilles fiches pour revenir sur un déploiement.

La nouvelle description de PR est sauvegardée dans `PR-OPTIMISATION-SUPABASE-20261020.md` ; sa publication a de nouveau été refusée par l’API GitHub (`Forbidden`).
