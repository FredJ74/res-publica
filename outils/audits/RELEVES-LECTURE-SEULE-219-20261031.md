# Relevé Supabase strictement en lecture seule — PR #219 (31/10/2026)

Projet interrogé : `jxpwoosmmhohoihxpbuc`, PostgreSQL 17.6.1.127.

Ce relevé constate les données **actuelles** des catalogues ; il ne remplace pas l'export canonique complet de structure ni le contrôle global. Aucune table d'état vivant de joueur n'a été lue. Ne pas utiliser les nombres ci-dessous comme seeds et ne pas les convertir en JavaScript Number pour construire le DDL.

## 42 séquences (source pg_sequence, texte décimal exact)

Les 42 lignes renvoient toutes type `bigint`, `start=1`, `increment=1`, `min=1`, `max=9223372036854775807`, `cache=1`, `cycle=false`. Les noms exacts :

- `admin_journal_rang_seq`
- `audience_messages_rang_seq`
- `batailles_engagements_id_seq`
- `batailles_id_seq`
- `batailles_rounds_id_seq`
- `batiments_fermes_id_seq`
- `caisses_mouvements_clients_id_seq`
- `calomnies_actes_id_seq`
- `catalogue_correspondance_legacy_id_seq`
- `championnat_tentatives_id_seq`
- `contacts_militaires_id_seq`
- `contributions_piete_id_seq`
- `corruptions_presse_id_seq`
- `decorations_militaires_id_seq`
- `defenses_demandes_rang_seq`
- `dons_en_attente_id_seq`
- `elections_tracts_pnj_id_seq`
- `entrepot_journal_id_seq`
- `evenements_globaux_id_seq`
- `fiche_hausses_observees_id_seq`
- `fiche_inventaire_observe_id_seq`
- `fonds_credits_uniques_id_seq`
- `fonds_en_transit_id_seq`
- `fuites_journalistiques_id_seq`
- `historique_deplacements_id_seq`
- `indices_diplomatiques_journal_id_seq`
- `inventaire_ecarts_observes_id_seq`
- `invitations_diner_id_seq`
- `justice_indemnites_rang_seq`
- `logements_loyers_historique_id_seq`
- `mails_envois_systeme_id_seq`
- `personnages_supprimes_archive_id_seq`
- `pnj_evenements_id_seq`
- `pnj_possessions_id_seq`
- `presidence_memoire_id_seq`
- `presse_membres_rang_seq`
- `purges_residus_bancs_id_seq`
- `registre_ventes_armes_id_seq`
- `retraits_materiel_militaire_id_seq`
- `scandales_presse_id_seq`
- `services_militaires_id_seq`
- `temoins_citations_rang_seq`

L'ancien export contenait `9223372036854776000` : **valeur fausse issue du transport de l'export**, ne pas la conserver ni corriger le JSON ancien à la main. Réextraire le lot canonique avec la requête mise à jour.

## Relevés de comptes des 12 référentiels

| Table | Compte exact au moment de la lecture |
|---|---:|
| `commerce_decors_sources` | 1 |
| `locaux_loyers_referentiel` | 19 |
| `objets_achetables` | 6 |
| `objets_modeles` | 54 |
| `ordres_generiques` | 5 |
| `publicites_premium_sources` | 0 |
| `rue_noeuds_serveur` | 44 |
| `rue_sorties_batiments` | 110 |
| `scandales_predefinis` | 10 |
| `terrain_actions_regles` | 1 |
| `terrains_referentiel` | 36 |
| `tracts_pnj_catalogue` | 189 |

Un compte de zéro est un **compte SQL constaté**, pas une supposition. Les 12 **contenus de lignes** ne sont pas encore exportés : il faut respecter la classification et valider que chaque ligne est un seed autorisé avant de les copier. Les relevés doivent être rattachés au point de coupe du nouvel export complet si le catalogue change.

## Requêtes exécutées (SELECT uniquement)

```sql
select c.relname as sequence, s.seqtypid::regtype::text as type,
       s.seqstart::text as start_exact, s.seqincrement::text as increment_exact,
       s.seqmin::text as min_exact, s.seqmax::text as max_exact,
       s.seqcache::text as cache_exact, s.seqcycle as cycle
from pg_sequence s
join pg_class c on c.oid=s.seqrelid
join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public'
order by c.relname;
```

Pour les comptes : douze `count(*)` individuels sur les tables du tableau, assemblés par `query_to_xml` à partir d'une liste fixe de leurs noms, sans écriture. Ne recopier aucun `count(*)` comme preuve d'extraction de lignes.

**Limites :** l'export de structure complet, le nouveau contrôle global, les seeds et la preuve des 88 migrations sur copie fidèle restent à produire. Aucune fusion ni livraison autorisée.
