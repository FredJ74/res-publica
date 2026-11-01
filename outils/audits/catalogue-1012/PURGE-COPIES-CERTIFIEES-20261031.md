# Copies rehorodatées certifiées par comparaison du SQL enregistré (31/10/2026)

Lecture seule du registre `supabase_migrations.schema_migrations.statements` et comparaison aux sources de #219 après retrait des commentaires, enveloppes transactionnelles et blancs.

- `20261031113554_assemblage_electronique.sql` : corps normalisé identique au SQL enregistré à la version `20261018214911`.
- `20261031113556_jodie_portraits_forum_journal.sql` : corps normalisé identique au SQL enregistré à la version `20261018223916`.
- `20261031113557_fortune_serveur_diagnostic.sql` : corps normalisé identique au SQL enregistré à la version `20261018224645`.

Les trois sources sont conservées hors `migrations/` dans `historique/migrations-appliquees/rehorodatees-219/`.

**Non supprimées, preuve insuffisante :** `20261031113551_composants_electroniques_catalogue.sql`, `20261031113555_catalogue_informatique_dix_articles.sql`, `20261031113648_inventaire_kompromats_vol_materiaux.sql`. Leurs corps diffèrent des versions candidates du registre, et une réécriture ne doit pas être assimilée à une identité sans examen métier.

Aucune migration ni écriture de joueur effectuée en production. Le manifeste des 95 demeure inchangé.
