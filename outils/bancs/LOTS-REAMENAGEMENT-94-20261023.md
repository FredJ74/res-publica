# Lots et reamenagement #94 — preparation, fusion interdite

Base PR114 04dd178 ; main 33910be integre. Aucune application SQL ou modification de donnees reelles.

Defauts confirmes et corriges : le travailleur tiers etait soumis au droit du proprietaire ; l'interface appelait chantier_travailler alors que la migration lui retirait EXECUTE. Le client utilise desormais chantier_commande, avec son intention persistante et ses controles de contexte. Le travailleur ne verrouille pas le financeur, dont il ne depense pas les fonds personnels. La gestion reste reservee au proprietaire/representant.

Le reamenagement rejoint les commandes, recus, financeurs, approvisionnements, journees et reception existants. Son prix et sa duree sont derives du plan serveur. Les lots touches sous bail ou vendus sont refuses ; les metadonnees des autres lots sont preservees, y compris les modifications legitimes intervenues pendant les travaux. L'ancienne RPC de pose est fermee, les anciennes RPC de lots ne peuvent plus remplacer prix, geometrie et titres. Un miroir de location exige un bail canonique ; sa liberation ne resilie jamais un bail existant.

## Blocage reproductible, ne pas deployer

Arbitrage recu : prix total fixe, arrondis absorbes dans le panier sans depasser les quantites. La migration `20261023161856_chantier_panier_budget_fixe.sql` borne chaque tiers quotidien vers le bas. Pour 100 m2 : materiaux 290 FR, travail 700 FR, reliquat 10 FR, progression 100 %. Client et miroir cron raccordes. La migration `20261023095517_chantier_quotas_pnj_francs_entiers.sql` solde aussi les fractions finales de travail PNJ des nouveaux reamenagements, avec paiements entiers et sans acceleration. Aucun ancien historique salarial reconstitue artificiellement. Tests : 1006 superficies en parite JS/SQL et sous le budget ; parcours reception/rejeu de 1 a 601 m2, quotas 102/301 m2 et remplacement par travail PJ. Le workflow PostgreSQL passe 25/25.

## Verification et dependances

- Banc construction original : 62 assertions conservees.
- Travailleur tiers : 9 assertions PostgreSQL ; client 3 tests.
- Reamenagement a 90 m2 : 23 assertions PostgreSQL (dont concurrence et rollback).
- Miroirs lots : 14 assertions PostgreSQL.
- Authentification, identites et services annexes de fixture : aucune preuve de fonctionnement authentifie en production.

Installer la PR114 entiere, dependances comprises, puis les migrations 20261023090008 a 20261023090017 dans l'ordre puis 20261023095517 et 20261023161856, seulement APRES le prevol vivant et les autres raccordements. Verifier md5(prosrc), definitions, droits, RLS et triggers reels avant toute application. Les nouvelles definitions refusent le remplacement d'un corps inconnu. L'application repetee est testee.

Restent explicitement : vols et securite commune du chantier ; financement d'acquisition #65. Les conditions des prets immobiliers ne sont pas definies par #65 ; le pret travaux ne doit pas leur etre substitue. Le rapport n'assimile pas ces lacunes a un simple manque d'acces Supabase.

Retour arriere : ne pas supprimer les chantiers, baux ou recus. Conserver les protections serveur et le client compatible ; toute restauration de fonction exige l'examen des transactions intervenues. Aucun retour automatique aux portes permissives.

Verification apres integration de main 33910be : 95/95 bancs client ; prevol SQL en lecture seule dans `outils/bancs/prevol-cloture-construction-94.sql`. Reprise F5 du plan et identifiants conserves dans le recu commun, sans nouveau stockage. Les fixtures PostgreSQL commitent explicitement chaque RPC pour distinguer son rollback de celui de leur preparation.


## Location raccordee au moteur commun

`chantier_commande('louer')` reunit desormais bail canonique `locations_actives`, premier loyer via `prelever_loyer_bail`, PA et recu. Aucun second moteur bancaire ou de location. Le prelevement des lots utilise la banque nationale puis le liquide, sans debit partiel. Les autres types de baux gardent leur circuit. Le prix et les identifiants viennent du lot serveur. Les gardes des payeurs #112 et urbanisme sont conservees (variantes exactes testees), et l'ancien navigateur est refuse avant sa depense de PA. Le recu prive sert de capacite transactionnelle ; aucun nouveau stockage d'autorisation.

Les INSERT et modifications financieres brutes d'un bail dynamique sont refuses. L'option de visibilite reste utilisable. Le client relit les baux avant de lever son intention de reprise ; une panne conserve le registre precedent, les reponses tardives ou destinees a un autre contexte sont ecartees. La location ne recopie aucun delta financier client.

Tests : 30 assertions PostgreSQL additionnelles, 4 tests client. Succes, manque de fonds/PA, presence, concurrence, rejeu, rollback apres contrepartie, interdiction d'ecriture brute, garde des permis et absence de deuxieme loyer au cron du jour. Identite et session restent des fixtures, pas une authentification Supabase reelle. Les identifiants de migration ont ete remis a l'heure UTC de leur ecriture, avant toute application ; aucun registre ou baseline modifie.

Limites restantes de ce sous-parcours : controle complet des ecritures historiques de fin de bail/domiciliation, raccordement des lots vendus au futur registre de titres, preuve de compatibilite des triggers financiers vivants, et tarification des nouveaux lots dont le loyer initial est actuellement zero dans le moteur commun. Aucun ancien bail n'est modifie automatiquement.


## Approvisionnement et compatibilite des fonds

20261023090710 raccorde les ventes, dons et tarifs au reamenagement dans les fonctions existantes, sans ajouter de RPC ou de moteur d'inventaire. 12 assertions PostgreSQL additionnelles : prix serveur, don, coma, territoire, rejeu, concurrence et rollback. L'identite et le service de reception de la fixture restent simules.

20261023091701 conserve les liens et transferts de baux des fonds existants, attestes par `entreprises` (table en lecture seule pour les clients dans le catalogue archive). Le bail ne peut pas inventer son fonds ou modifier son prix au passage. Le test execute le moteur de vente deja present, a prix nul sur des fixtures ; il ne valide pas tout le financement des ventes.

20261023092229 corrige une perte reproductible : `creer_fonds_commerce` debitait l'apport avant de retourner `local_non_commercial`. Les controles precedents sont maintenant termines avant le debit, dans le meme moteur. Aucun tarif ni condition d'octroi ajoute. Les fonctions dynamiques de fonds restent a raccorder : le resolveur archive ne reconnait que les trois centres statiques, et les references typees/finances historiques doivent etre rapprochees des definitions vivantes avant activation. Ne pas confondre preservation des fonds existants et validation de l'exploitation commerciale de tous les nouveaux lots.

Ordre obligatoire du paquet complet : PR112, puis PR114, puis la serie urbanisme 20261023071739..20261023071900, puis les migrations de cette branche 20261023090008..20261023092229 (ordre lexical interne). Les depots/instructions ne se reappliquent pas aveuglement par ordre de nom : la garde de PR112 precede le garde de plan PR114. Conserver le registre effectif et stopper au moindre corps inconnu. Les tests couvrent les variantes ciblees, pas une extraction integrale de la production.
