# Lots et reamenagement #94 — preparation, fusion interdite

Base PR114 04dd178 + main 12c0e05. Aucune application SQL ou modification de donnees reelles.

Defauts confirmes et corriges : le travailleur tiers etait soumis au droit du proprietaire ; l'interface appelait chantier_travailler alors que la migration lui retirait EXECUTE. Le client utilise desormais chantier_commande, avec son intention persistante et ses controles de contexte. Le travailleur ne verrouille pas le financeur, dont il ne depense pas les fonds personnels. La gestion reste reservee au proprietaire/representant.

Le reamenagement rejoint les commandes, recus, financeurs, approvisionnements, journees et reception existants. Son prix et sa duree sont derives du plan serveur. Les lots touches sous bail ou vendus sont refuses ; les metadonnees des autres lots sont preservees, y compris les modifications legitimes intervenues pendant les travaux. L'ancienne RPC de pose est fermee, les anciennes RPC de lots ne peuvent plus remplacer prix, geometrie et titres. Un miroir de location exige un bail canonique ; sa liberation ne resilie jamais un bail existant.

## Blocage reproductible, ne pas deployer

Pour 100 m2 : prix total 1000 FR, materiaux 300 FR, travail 700 FR. Le panier existant arrondi donne 20 bois, 10 minerai, 7 metal, soit 305 FR. Il reste 695 FR, donc seulement 9 heures payables sur les 10 necessaires ; progression 0,9. Le financement est plafonne au prix total. Ne pas modifier silencieusement le panier, le salaire ou le tarif. Une question de conception ciblee est en attente : panier respecte-budget ou apport complementaire. banc-reamenagement-budget-local.py conserve cette exigence comme CONTROLE ROUGE BLOQUANT, inclus dans le workflow. Les scenarios a 90 m2 passent ; cela ne valide pas tous les dimensionnements.

## Verification et dependances

- Banc construction original : 62 assertions conservees.
- Travailleur tiers : 9 assertions PostgreSQL ; client 3 tests.
- Reamenagement a 90 m2 : 17 assertions PostgreSQL.
- Miroirs lots : 13 assertions PostgreSQL.
- Authentification, identites et services annexes de fixture : aucune preuve de fonctionnement authentifie en production.

Installer la PR114 entiere, dependances comprises, puis 20261023083000, 84000, 84001, 84002, 85000, 85001 dans l'ordre seulement APRES resolution du controle budget, du prevol vivant et des autres raccordements. Verifier md5(prosrc), definitions, droits, RLS et triggers reels avant toute application. Les nouvelles definitions refusent le remplacement d'un corps inconnu. L'application repetee est testee.

Restent explicitement : signature initiale d'un bail et premier loyer encore dans l'ancien circuit multi-appels ; raccordements des ventes/dons/prix/vols au reamenagement ; concurrence et rollback approfondis du nouveau parcours ; financement d'acquisition #65. Les conditions des prets immobiliers ne sont pas definies par #65 ; le pret travaux ne doit pas leur etre substitue. Le rapport n'assimile pas ces lacunes a un simple manque d'acces Supabase.

Retour arriere : ne pas supprimer les chantiers, baux ou recus. Conserver les protections serveur et le client compatible ; toute restauration de fonction exige l'examen des transactions intervenues. Aucun retour automatique aux portes permissives.
