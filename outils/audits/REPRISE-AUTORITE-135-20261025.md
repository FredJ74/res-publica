# #135 — Continuation et correction du contrôle Authority

25 octobre 2026. Reprise de `633aa38` sur `codex/stabilisation-luthecia-135-20261024`.

## Correction démontrée

L'invariant 12 refusait `acheter_produit_commerce_interne(text,text,text,text,integer)` dans la migration de fontaine #110. Pourtant celle-ci renomme explicitement une signature présente dans le baseline, puis retire ses droits. Le contrôleur ne suivait pas `ALTER FUNCTION … RENAME TO`.

`verifier-autorite.py` suit maintenant les renommages statiques dans l'ordre du fichier. Seule une source de signature exacte connue transmet son existence à la destination. Une source inconnue, une mauvaise surcharge ou une référence précédant le renommage restent des erreurs. Un commentaire, une chaîne ou un corps dollar-quote ne peut attester un renommage. Les références des blocs DO/EXECUTE restent examinées comme auparavant ; aucune référence historiquement contrôlée n'est rendue invisible. La règle existante des fonctions créées dans le fichier est conservée, avec reconnaissance de `CREATE FUNCTION` simple.

Le test inclut la migration réelle et une contre-épreuve : changer la cible du renommage fait réapparaître l'erreur. Il vérifie aussi les commentaires imbriqués, les chaînes échappées, l'ordre et les surcharges. La comparaison complète avant/après prouve que les **45 autres écarts RPC sont identiques**. L'invariant 13 n'est pas assoupli : une déclaration préparée ne prouve toujours pas une installation.

## Vérifications exécutées après correction

- Détecteurs Authority : **4/4 tests directs Node**, comprenant la contre-épreuve.
- Contrôleur client complet : **112/112 bancs**.
- PostgreSQL jetable de la fontaine : **8/8 assertions**. Il réutilise le banc existant, dont les corps commerciaux sont fictifs et dont la limite est documentée ; ce résultat ne valide pas les finances de production.
- Contrôles globaux : **6/12**. Authority reste rouge à cause du seul invariant 13 (45 écarts RPC). Classification, Baseline, Referential, Assemblage et Reconstruction restent également rouges.
- `baseline/` identique à `origin/main`. Aucun résultat, observation ou empreinte de référence corrigé artificiellement.
- Aucun changement distant de `main` au fetch de reprise : `c6aa8ec` reste intégré.

Les preuves de ce tour sont dans `luthecia-20261025/REPRISE-AUTORITE-135-*`, avec empreintes des sources et des fichiers de résultats. Les campagnes antérieures 61/61 PostgreSQL et 91/91 contre-épreuves concernent les sources applicatives inchangées ; elles ne sont pas présentées comme rejouées dans ce tour.

## Limites de clôture inchangées

Le recensement des outils confirme l'absence de connecteur Supabase, Vercel et de consultation GitHub Actions. Aucune session de joueur n'est utilisée. La lecture du catalogue vivant, les observations des données historiques et la recette authentifiée ne sont donc pas réalisables ici.

Les autres blocages ne sont pas de simples autorisations : compteur historique des déserteurs non attesté, garde financier vivant contre les sauvegardes anciennes non attesté, définition d'exécution judiciaire personnelle non archivée et arriéré des anciens vols inconnu. Les reconstruire arbitrairement pourrait effacer un droit acquis, interrompre une interception ou réécrire un solde. Le prévol existant `outils/bancs/prevol-benediction-135.sql` est prêt pour l'agent disposant du connecteur ; aucune manipulation technique n'est demandée au game designer.

**CHANTIER NON TERMINÉ.** Cette continuation corrige un défaut réel du contrôle, sans modifier les mécanismes du jeu, les données des joueurs ni les règles de conception. Aucune fusion, migration ou activation de production. Les conditions de clôture du rapport `CLOTURE-L09-135-20261025.md` restent applicables.
