# Delta Supabase pour la reconstruction #219 — 31 octobre 2026

**Relevé réel par SQL en lecture seule**, projet `jxpwoosmmhohoihxpbuc`. Registre actuel : **1011** entrées. Ce document ne comporte aucune donnée de PJ.

## Neuf migrations présentes après la coupe source 1003

| Version registre | Nom |
|---|---|
| 20261031113025 | genre_personnage_serveur_20261031100000 |
| 20261031123713 | verrou_ajouts_inventaire_20261031124000 |
| 20261031124014 | reliquats_immobilier_accord_tacite_succession_20261031130000 |
| 20261031124019 | helvetia_caisse_argent_detenu_20261031140000 |
| 20261031125200 | regularisation_bnr_helvetia_excedent_20261031150000 |
| 20261031131427 | placement_helvetia_gain_unique_20261031151000 |
| 20261031190352 | avis_personnels_expediteurs_declares_20261031190000 |
| 20261031195210 | caisses_collectives_portes_serveur_20261031200000 |
| 20261031200630 | caisses_collectives_fermer_ecran_20261031201000 |

## Contrats vivants relevés (empreintes `md5(prosrc)`)

| Fonction | Empreinte |
|---|---|
| payer_ordre(text,text,integer,integer) | 5cf45c19e4b9559f6b29e2b9207d3969 |
| organisation_ordre_financier(text,text,text) | 73b9d936361d5c158b0bdfae44cf0db8 |
| organisation_adhesion_payante(text,text,text) | f47b4e550f62fe6e1cfbf6c1d0c10cb7 |
| club_supporters_cotiser(text,text) | b9324e4f910534fa6f03056bf91da5a7 |
| club_sponsoriser(text,text,integer) | d5a1250fbf53e53a32169bbbc8245b12 |
| club_transfert_conclure(text) | 057d4b8e51e41eae3bc59d615a4df391 |
| resoudre_placement_helvetia(text) | 143ce2357e533df73cf91e38861a1ff4 |

Les fonctions financières des clubs et organisations listées sont exécutables par `authenticated`, contrairement à la fonction interne de résolution Helvetia. Les deux triggers `trg_organisations_finances_garder` et `trg_transferts_clubs_garder` sont présents et actifs.

Les commandes `organisation_commande_administrative`, `organisation_commande_evenement` et `organisation_commande_membres` n'existent pas encore en production.

**Limite** : empreintes et registre ne remplacent pas les définitions complètes, ACL/RLS et référentiels exigés pour une reconstruction fidèle. Ne pas prétendre avoir testé le paquet de 95 migrations contre le catalogue 1011 à partir de ce document seul.

Aucune écriture en production.
