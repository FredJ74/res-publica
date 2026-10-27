# États de départ des bancs PostgreSQL jetables

Voir [WORKFLOW-SUPABASE.md](../../WORKFLOW-SUPABASE.md).

Ces sources de test ont été déplacées depuis `outils/bancs/fixtures/` le
28 octobre 2026, sans changer un octet de leur contenu SQL. Elles ne sont **ni des
migrations à appliquer, ni la preuve d'une application en production**.
Elles restent lues uniquement par les bancs qui montent une base PostgreSQL jetable.

- `ced-football-schema.sql` : schéma et identités fictifs du banc Céd/football.
- `historique-135/20261024072349_occupation_actions_et_echeances.sql` : ancien
  état d'occupation utilisé pour éprouver les évolutions immobilières.
- `historique-135/20261023090017_location_lot_legacy_avant_paiement.sql` : ancienne
  garde de location utilisée par la variante du banc bancaire.

Les deux anciens fichiers `terrain-*-avant-*.sql` de ce même sous-dossier étaient
des doublons exacts des corps déjà conservés sous
`outils/bancs/banc-fixture-terrain-permis-acte-avant-depot.sql` et
`outils/bancs/banc-fixture-terrain-chantier-acte-avant-commandes.sql`.
Les bancs lisent désormais ces fixtures existantes, entourées de `BEGIN/ROLLBACK`.
Aucune règle ni assertion n'a été changée.
