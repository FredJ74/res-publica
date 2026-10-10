# Migrations — les évolutions futures du schéma

Une évolution = **un fichier**, nommé :

```
<AAAAMMJJHHMMSS>_<nom_en_minuscules_avec_soulignes>.sql
```

L'horodatage est celui du moment où la migration est écrite, en UTC. Il donne
l'ordre d'application, et il doit être **postérieur au point de coupe du
baseline** — `baseline/CONTROLE-GLOBAL.json`, clé `releve_le`.

## Aucune migration en attente

**La caserne de Républia est close.**
Deux migrations le 10 octobre 2026, registre **636 → 637**, archivées dans
`../historique/migrations-appliquees/` et vérifiées par empreinte.

| Registre | Nom | Ce qu'elle ferme |
|---|---|---|
| **636** | `caserne_autorite_caisse_inspection_et_ordre_de_bataille` | quatre choses d'un coup : le ministre de la Défense **ne débite plus** la caisse de la caserne, le Commandant peut lui **reverser** de l'argent (ce flux n'existait pas), l'**ordre de bataille** cesse d'être lisible par tout joueur du pays, et l'**inspection des troupes** est gardée au serveur avec son périmètre |
| **637** | `caserne_tom_hawak_rejoint_la_liste_des_referents` | une seule ligne, et pas décorative : `pnj_referents` est la liste fermée qui **autorise la mémoire pédagogique**. Sans elle, le Commandant aurait eu une voix et aucun souvenir |

> **Ce que ce lot ajoute à la doctrine** : une **policy et son `GRANT` tombent
> ensemble**. Retirer la policy de lecture sans révoquer le `SELECT` laisserait la
> table ouverte le jour où une policy permissive reviendrait — et ce jour-là,
> personne ne chercherait la cause dans un `GRANT` oublié.
>
> Et une **fermeture n'est pas un filtre** : fermer `compagnies_militaires` à un
> civil aurait aussi supprimé sa capacité à voir qu'un détachement tient une
> pièce, c'est-à-dire une observation légitime du monde et le déclencheur des
> missions d'entrée. La porte **projette** donc au lieu de filtrer : le blob
> entier pour la chaîne militaire, la présence seule pour les autres.

**Le chantier 7 n'a produit aucune migration, et c'est normal.** Les fonctions
recopiees entre `api/` et le navigateur vivent entierement dans le depot : la base
n'a rien a y voir, le baseline est donc inchange. Ce que ce chantier a ajoute est
un **onzieme controle**, `verifier-fonctions.py`, et sa declaration
`outils/baseline/fonctions.json`. Voir
`../baseline/arbitrages/AUDIT-CHANTIER-7-FONCTIONS-RECOPIEES.md`.

**La purge : les chantiers 5 et 6 sont clos.**
Vingt-quatre migrations le 10 octobre 2026, registre **600 → 623**. Toutes
archivées dans `../historique/migrations-appliquees/`, corps exacts relus depuis
le registre Supabase et **vérifiés par empreinte MD5 par un outil**, pas à la
main : `python3 outils/baseline/verifier-archives-migrations.py`.

| Registre | Nom | Ce qu'elle ferme |
|---|---|---|
| **600** | `souvenir_accueil_la_fuite_a_sa_cle_de_journee` | la frontière anti-rejeu devient **le souvenir** (`jour_tirage`), plus la passe ; le tirage, le marquage et le SCANDALE nominatif dans une transaction |
| **601** | `deux_contraintes_qui_rendent_l_anti_rejeu_structurel` | les deux `UNIQUE` réclamés par le §5 de l'audit — et l'inspection a trouvé **pourquoi la première manquait** : un second écrivain avec un `Date.now()` dans l'identifiant |
| **602** | `achat_direct_manque_une_consignation_et_une_purge` | un rendez-vous notarial manqué pouvait être consigné sans être purgé, puis reconsigné la nuit suivante |
| **603** | `recherche_un_ajout_atomique_et_un_retrait_cible` | l'avis de recherche : **18 sites**, pas 1, et un dernier-écrivain-gagnant sur un tableau sans clé |
| **604** | `recherche_est_serveur_autoritaire` | la colonne `recherche` cesse d'être écrivable depuis un navigateur |
| **605** | `recherche_les_deux_portes_existantes_declarent_leur_laissez_passer` | les deux écritures légitimes déclarent leur laissez-passer |
| **606** | `recherche_le_laissez_passer_ne_dure_que_son_ecriture` | **c'est le banc qui a trouvé ce défaut** : `set_config(..., true)` vaut pour toute la transaction, donc chaque porte doit REFERMER son laissez-passer |
| **607** | `candidature_la_table_et_le_scrutin_dans_une_transaction` | le blob du cycle n'était **pas** un cache : le dépouillement ne lit QUE lui |
| **608** | `dissolution_la_revocation_des_deputes_est_une_porte` | supersédée par la 611 |
| **609** | `bne_le_miroir_genere_des_offres` | le plafond de places ne vient plus du navigateur : miroir généré depuis `data.js` |
| **610** | `bne_quatre_actes_une_transaction_chacun` | quatre lectures-modifications-écritures d'un blob **partagé** → une porte, cinq actes |
| **611** | `dissolution_le_drapeau_et_la_revocation_sont_indivisibles` | **la dissolution n'avait JAMAIS révoqué personne**, alors que le drapeau était consommé et les scrutins relancés |
| **612** | `affaire_la_transmission_au_tribunal_est_une_porte` | `'affaire-' + Date.now()` : la même enquête rejouée créait deux affaires contre la même personne |
| **613** | `plaintes_defense_et_classement_ministeriel_portes` | la défense de l'accusé et le classement du Ministre de la Justice |
| **614** | `verdict_le_trigger_reconnait_les_portes_du_cycle` | **la mesure a renversé l'audit** : un trigger préexistant annulait la défense SYSTÉMATIQUEMENT — et il aurait neutralisé les deux portes neuves |
| **615** | `terrain_un_seul_ecrivain_interne_et_la_porte_du_compromis` | le socle des terrains : un écrivain interne unique, et la porte du compromis (6 actes) |
| **616** | `terrain_la_porte_du_permis_et_sa_liste_de_cles` | `traiterPermis` ne vérifiait **rien** : n'importe qui tranchait n'importe quel permis |
| **617** | `terrain_la_porte_du_chantier_calcule_sa_progression` | le navigateur n'envoie plus aucun nombre : la porte recalcule, et l'accord est prouvé sur **184 chantiers** |
| **618** | `titulaire_est_moi_et_rectification_de_deux_affirmations` | **une régression que j'avais introduite** (un propriétaire `pj:Nom` aurait été refusé) et **une affirmation non établie** rectifiée |
| **619** | `terrain_la_porte_du_decoupage_en_lots` | trois acteurs réécrivaient le MÊME tableau de lots : fusion par `lot.id` |
| **620** | `terrain_chaque_acte_declare_ses_cles` | « signer un compromis » n'a jamais eu à écrire un chantier |
| **621** | `terrain_le_gel_successoral_a_enfin_son_jumeau` | le défaut fermé sur l'**entreprise** au chantier C était resté ouvert sur le **terrain** — et un gel inventé paralysait le bien d'autrui |
| **622** | `terrain_reamenagement_et_le_proprietaire_du_depot` | les deux derniers actes ; `sbSetTerrainState` n'a plus aucun appelant |
| **623** | `purge_des_residus_de_banc_archivee_et_bornee` | **71 lignes de banc dans 19 tables**, archivées puis supprimées — dont le terrain que la passe de minuit traitait chaque nuit |

> **Ce que ce lot ajoute à la doctrine** : le **laissez-passer refermé**, trouvé
> par un banc et non par une relecture ; la **liste de clés par acte**, qui ferme
> l'écrasement par cache périmé sans énoncer aucune règle de jeu ; la **fusion
> par clé d'élément** dans un tableau partagé ; et la **preuve
> ancien-contre-nouveau par grille**, où le banc JS exécute le code de production
> pour produire les valeurs attendues du banc SQL — aucune valeur recopiée à la
> main.
>
> **Et deux de mes propres affirmations ont été corrigées par la mesure** (voir
> 618). Quand une hypothèse est fausse, les faits gagnent — y compris quand
> l'hypothèse est la mienne.

**Les chantiers 5 et 6 ferment leurs reliquats.**
Seize migrations le 10 octobre 2026, registre **583 → 599**. Toutes archivées
dans `../historique/migrations-appliquees/`, corps exacts relus depuis le
registre Supabase et vérifiés par empreinte MD5.

| Registre | Nom | Ce qu'elle ferme |
|---|---|---|
| **584** | `droits_clients_retires_apres_deploiement` | les quatre surfaces d'écriture clientes devenues inutiles — **après** avoir prouvé octet par octet que le code du lot précédent est bien celui déployé |
| **585** | `detention_moteur_de_cloture_et_motifs_eteints` | les quatre écritures d'une sortie de geôle dans une transaction, et la porte des deux motifs éteints par la désertion |
| **586** | `detention_quatre_portes_sur_le_moteur_de_cloture_et_la_grace` | cinq clôtures, une seule implémentation — et la grâce présidentielle, **troisième** instance du défaut du drapeau QHS |
| **587** | `taxe_fonciere_un_terrain_une_journee_une_transaction` | un rejeu faisait avancer de **deux** crans la progression avertissement → pénalité → saisie |
| **588** | `vote_confiance_le_tirage_entre_dans_la_transaction` | le tirage des députés absents se faisait dans le navigateur du cron, **avant** l'écriture du résultat |
| **589** | `election_resultats_une_proclamation_par_scrutin` | l'annonce publique partait avant le drapeau du cycle ; le dépouillement, lui, **n'est pas aléatoire** — l'audit se trompait |
| **590** | `cotisation_une_adhesion_un_debit_une_transaction` | la dette que le code consignait lui-même : débiter un personnage et marquer son adhésion étaient deux écritures |
| **591** | `cotisation_horodatage_du_courrier_identique_a_l_original` | un horodatage local introduit par mégarde en déplaçant l'autorité — patch en place d'un seul fragment |
| **592** | `cotisation_le_club_se_resout_sur_le_miroir_genere` | la porte lisait un **doublon sans générateur** au lieu du miroir de `data.js` |
| **593** | `succession_le_reglement_et_son_marqueur_sont_indivisibles` | la fenêtre de deux requêtes entre le crédit d'un héritage et son marqueur — **une sous-transaction par étape**, pour ne pas détruire l'indépendance des dispositions |
| **594** | `taux_imposition_une_cle_un_paiement_une_transaction` | read-modify-write sans version, **clé du budget venue du client**, et toast inconditionnel après un paiement déjà prélevé |
| **595** | `tournee_la_cloture_et_ses_credits_sont_un_seul_acte` | le crédit social des invités, qui **levait** `personnage_non_possede` depuis le chantier B et n'est donc jamais arrivé |
| **596** | `tournee_cloturer_preuves_structurelles` | les preuves de la précédente, séparées pour cause de **limite de transport** du canal de migration |
| **597** | `terrain_un_seul_point_de_mutation_de_propriete` | trois portes d'entrée pour un seul acte, dont celle où **l'acheteur payait et ne recevait rien** |
| **598** | `terrain_proprietaire_muter_preuves_structurelles` | les preuves de la précédente, séparées pour la même raison |
| **599** | `chantier_l_approvisionnement_lit_la_tresorerie_en_base` | la marchandise détruite quand la contrepartie se perdait — et le `p_tresorerie` **dicté par le client**, qui bornait le pouvoir d'achat |

> **Ce que ce lot ajoute à la doctrine** (écrit dans `../WORKFLOW-SUPABASE.md`) :
> la **sous-transaction par étape**, qui rend chaque étape atomique sans détruire
> l'indépendance des autres ; le **patch fusionné au serveur**, qui remplace le
> blob entier relu dans un cache client ; et la règle « un paramètre que le
> client dicte et qui **borne** une autorisation est une faille, même derrière
> une RPC ».

**Les chaînes sensibles sont passées derrière des portes serveur.**
Quinze migrations le 9 octobre 2026, registre **568 → 583**. Toutes archivées
dans `../historique/migrations-appliquees/`, corps exacts vérifiés par empreinte.

| Registre | Nom | Ce qu'elle ferme |
|---|---|---|
| **569** | `election_voter_porte_atomique` | le bulletin **et** le blob du cycle dans une transaction, sous verrou. C'était le seul acte du jeu annoncé sans qu'aucune table ne le confirme |
| **570** | `detention_moteur_partage_et_drapeau_qhs` | un moteur de prolongation, deux portes d'autorité — elles avaient divergé. Et le drapeau QHS n'a plus qu'un seul écrivain |
| **571** | `detention_porte_du_detenu_sur_lui_meme` | la septième porte de `detention_ouvrir_interne`, qui existait **sans appelant** ; `p_extras` lui apporte les six métadonnées judiciaires du client |
| **572** | `detention_clore_et_transferer_au_qhs` | la fin de peine et la bascule au QHS ; `est_emprisonne` est enfin vidé **en base** |
| **573** | `justice_rendre_sentence_porte_atomique` | jugement et affaire ensemble, sous `affaire_autorite_de`, et le magistrat nommé par le serveur |
| **574** | `candidature_poste_tirage_appartient_au_serveur` | le tirage au sort **dans** la transaction qui l'applique, revendiquée par `actes_nocturnes` |
| **575** | `compromis_expire_une_transaction_deux_familles` | une seule fonction pour terrains et entreprises, tirage du prêt inclus, identifiants datés |
| **576** | `mail_systeme_un_seul_ecrivain_et_son_poseur_interne` | `mail_systeme_poser_interne`, l'unique écriture de `public.mails`, injoignable depuis le réseau |
| **577** → **581** | `mails_routes_*` (5) | quinze `INSERT` de courrier routés **par patch en place**, sans qu'un libellé bouge |
| **582** | `mails_routes_placement_helvetia_et_arete_assemblee` | la onzième fonction, que `INSERT INTO` manquait parce qu'elle écrivait en minuscules ; et l'arête d'autorité que le routage avait créée |
| **583** | `detention_reduction_avocat_et_evasion_atomiques` | deux chaînes de détention que l'inventaire avait manquées, portant le même défaut que la fin de peine |

> **La règle d'architecture que ce lot a dégagée trois fois** : quand deux chemins
> font le même acte sous deux autorités différentes, ils partagent un **moteur**
> et portent chacun leur **porte**. Le moteur fait l'acte et n'a aucun contrôle ;
> la porte vérifie qui agit et délègue. Et le moteur n'est pas « à ne pas appeler
> directement » : il est **injoignable** depuis le réseau. Détention, courriers,
> prolongation de peine — la même forme chaque fois, pour la même raison : deux
> copies d'une séquence divergent toujours, et le jour où elles divergent,
> personne ne le remarque.

**L'idempotence nocturne a enfin sa brique, et un vrai consommateur.**
Quatre migrations le 9 octobre 2026, registre **565 → 568** :

| Registre | Nom | Ce qu'elle fait |
|---|---|---|
| **565** | `restitution_arg_arnie_effet_de_bord_des_preuves` | rend 1 000 FR au personnage témoin de la nuit — **une donnée de joueur, modifiée exprès et par le canal normal** |
| **566** | `actes_nocturnes_brique` | `actes_nocturnes(pays, mecanisme, sujet, jour)` en clé primaire, et sa liste blanche de mécanismes |
| **567** | `preemption_mensualite_atomique` | débit de caisse **et** réduction de dette dans une seule transaction |
| **568** | `notification_ne_casse_plus_l_acte` | un courrier qui ne part pas n'annule plus l'acte, et ne se perd plus en silence |

> **Le choix d'architecture qui porte tout le reste** : `acte_nocturne_revendiquer()`
> n'est **appelable par personne d'autre que son propriétaire** — `EXECUTE` retiré
> à `anon`, `authenticated` **et** `service_role`. Seules les fonctions
> `SECURITY DEFINER` du serveur peuvent la joindre, donc il est *structurellement
> impossible* de revendiquer une journée dans une requête HTTP distincte de celle
> qui porte l'effet. C'était le défaut commun aux dix familles de tâches
> nocturnes. L'architecture n'est pas une convention qu'on documente, c'est un
> droit qu'on retire.

**Une ardoise d'impayé ne double plus à chaque rejeu du cron.**
`ardoise_impaye_atomique` est passée le 9 octobre 2026, registre
**20261009005012**, qui porte le registre de 563 à **564** entrées. La branche
« locataire déjà averti et toujours insolvable » de `prelever_loyer_bail` était
**la seule sortie à effet** à ne pas poser son marqueur de journée : un second
passage la même nuit rajoutait un jour et un loyer à la dette. Et poser le
marqueur n'aurait pas suffi — l'appelant réécrivait le blob entier depuis une
lecture **antérieure** à la RPC, et l'aurait effacé dans la foulée. Le calcul de
l'ardoise est donc descendu **dans** la RPC, où revendication et effet sont
atomiques.

> **Deux refus avant l'application, et les deux étaient des preuves qui font
> leur travail.** La preuve 1 interdisait une séquence que le code *neuf*
> contient aussi ; la preuve 3 annonçait quatre poses du marqueur alors qu'il y
> en avait cinq. Chaque refus a laissé la base intacte — registre à 563,
> fonction inchangée, bail inchangé. Une assertion fausse est une assertion qui
> marche.

**Un mail porte son identité.** `mails_portent_leur_identite` est passée le
9 octobre 2026, registre **20261009003201**, qui porte le registre de 562 à
**563** entrées. `mails.id` est clé primaire `text NOT NULL` et n'avait aucune
valeur par défaut : **neuf sites d'écriture, dans deux fonctions**, insèrent sans
le fournir et levaient `23502`. Une RPC étant une seule transaction, la passe
nocturne des prêts Helvetia mourait **entière** au premier emprunteur insolvable.
Le défaut posé est, au caractère près, celui que la porte générique
`mail_systeme_envoyer` produit depuis toujours — et sa preuve 2 lève si les deux
divergent un jour.

> **Première migration écrite sous la règle 3**, et elle montre ce que la règle
> change : ses cinq preuves ne lisent que le catalogue, et les quatre empreintes
> de données relevées **avant et après** l'application sont identiques. L'épreuve
> comportementale — la branche « débiteur à sec » qui traverse enfin — est restée
> au banc, en transaction annulée.

**L'échéancier Helvetia ne s'exécute plus qu'une fois par jour.**
`idempotence_prets_helvetia` est passée le 9 octobre 2026, registre
**20261008235521**, qui porte le registre de 561 à **562** entrées — première
migration du chantier 6. `traiter_prets_helvetia_quotidien` n'avait aucun
marqueur de journée : un second appel le même soir prélevait une **seconde
mensualité entière** et faisait avancer l'escalade du contentieux de deux crans
en une nuit. Elle vit maintenant dans `../historique/migrations-appliquees/`.

> **Elle a coûté un incident de données, et c'est la leçon à retenir d'elle.**
> Ses preuves faisaient tourner la RPC pour de vrai sur un prêt témoin. Or cette
> RPC crédite aussi la caisse de la banque privée à chaque prélèvement : 1 000 FR
> sont restés dans `republic_banque-privee` après la suppression du témoin.
> Détectés par l'empreinte des caisses, restitués dans la minute. **Une
> migration commite, y compris les effets de bord de ses propres preuves** —
> voir la règle 3 ci-dessous.

**Le défaut des privilèges de fonction est fermé.**
`defaut_des_privileges_de_fonction_ferme` est passée le 9 octobre 2026, registre
**20261008221846**, qui porte le registre de 560 à **561** entrées. Une fonction
créée dans `public` n'accorde plus `EXECUTE` qu'à `postgres` et `service_role` :
celle qui doit être appelable par un client reçoit désormais son `GRANT`
**explicite** dans sa propre migration.

> **Deux mécanismes, et il fallait les deux.** `authenticated` venait de
> l'entrée `pg_default_acl` posée par `postgres` **pour le schéma** `public`.
> Mais `PUBLIC` venait du **défaut natif de PostgreSQL** — et une entrée par
> schéma **s'ajoute** à ce défaut au lieu de le remplacer, si bien qu'un
> `REVOKE … IN SCHEMA public … FROM PUBLIC` est purement **inopérant** : il ne
> modifie même pas la ligne stockée. Seule une entrée **sans `IN SCHEMA`**, au
> niveau du rôle, retire le `PUBLIC` natif. Et comme `PUBLIC` englobe `anon` et
> `authenticated`, la correction par schéma seule n'aurait rien fermé du tout.
>
> **Troisième piège : fermer trop rouvre.** Révoquer aussi `service_role` ne
> laisse que le propriétaire, PostgreSQL **supprime** la ligne, et l'ACL d'une
> fonction neuve repasse à `proacl = NULL` — donc au défaut natif, `PUBLIC`
> compris.
>
> **Un default privilege ne se lit pas, il s'observe.** La preuve crée une
> fonction témoin, lit son ACL réelle, puis la détruit — dans la transaction de
> la migration.

**Le chantier 4G est appliqué.** `pays_declare_et_retrait_des_defauts_republic`
est passée le 8 octobre 2026 au soir, registre **20261008214206**, qui porte le
registre de 559 à **560** entrées. Elle vit maintenant dans
`../historique/migrations-appliquees/`, et son en-tête y dit ce qui a été prouvé.

> **Ce que son banc a attrapé, et qui valait le détour.** Sa première version
> retirait les onze défauts par `CREATE OR REPLACE FUNCTION`. PostgreSQL le
> refuse : *cannot remove parameter defaults from existing function*. `CREATE OR
> REPLACE` peut **ajouter** un défaut et le **changer** ; il ne peut pas le
> **retirer**. La migration reposait sur une hypothèse jamais éprouvée contre une
> vraie base — et c'est précisément ce qu'un banc sert à attraper.
>
> Le détour par `DROP FUNCTION` a révélé deux pertes silencieuses qu'il fallait
> payer explicitement : le schéma `public` porte un **privilège par défaut** qui
> ouvre à `authenticated` toute fonction neuve (sept fonctions de cron
> concernées), et un `DROP` **perd le commentaire** de la fonction (trois des
> onze en portaient un). Aucun `REVOKE ... FROM PUBLIC` n'aurait suffi : ce sont
> les rôles **nommés** qui s'ajoutent.
>
> **Leçon de méthode, à ne pas réapprendre :** `pglast` valide la grammaire SQL
> de l'**enveloppe**, pas l'intérieur d'un bloc `DO $$ ... $$`. Une grammaire
> validée localement ne dit donc rien du PL/pgSQL qu'elle contient — seul un banc
> en transaction annulée le dit.

Les dix migrations des chantiers 4E, 4F, 4G et des budgets municipaux ont toutes
été appliquées et vivent dans `../historique/migrations-appliquees/`, chacune
avec, en tête, **la version du registre Supabase** et **ce qui a été vérifié
après coup**.

> **Les noms de fichiers gardent leur horodatage de rédaction.** Cinq d'entre
> eux commencent par `20261008`, alors que l'horloge du projet et le registre
> disent le 7 octobre 2026. Ce sont les noms sous lesquels ces migrations ont été
> **réellement appliquées** : les renommer réécrirait l'historique pour corriger
> une faute de date, et un historique qui se corrige ne prouve plus rien. La
> prose du dépôt, elle, a été alignée sur le 7 octobre — c'est purement
> documentaire. Et les textes déjà **en base** (un `COMMENT`, une `note` de
> référentiel) gardent le 8 octobre, parce que c'est ce que la base contient :
> les fichiers générés de `baseline/` doivent dire la vérité sur elle, pas sur
> nos intentions.

### Ce que la prochaine migration doit respecter

Cinq règles, apprises à ces chantiers :

1. **Être postérieure au point de coupe du baseline**
   (`../baseline/CONTROLE-GLOBAL.json`, clé `releve_le`). L'invariant 4 du
   garde-fou refuse l'inverse, à raison : l'effet d'une migration antérieure est
   censé être déjà dans le baseline. Si une réextraction a lieu entre l'écriture
   et l'application, **redater le fichier** est la seule réponse juste.
2. **Porter ses propres contrôles dans sa transaction.** Un bloc `DO` qui lève
   plutôt que de laisser croire que la migration a fait ce qu'elle annonce.
   C'est ce qui a sauvé le chantier de la Justice : la première version sommait
   trois tiers par division et obtenait `0,99999999999999999999` ; son assertion
   l'a refusée, et **rien n'a été appliqué**.
3. **Ne prouver que du structurel dans la migration.** Une migration **commite**.
   Si ses contrôles font *tourner* le mécanisme qu'elle corrige, ils en commitent
   aussi les effets — et un mécanisme touche presque toujours plus de tables que
   celles qu'on surveille. Dans la migration : lire le corps d'une fonction,
   compter des droits, vérifier une contrainte, un ordre d'instructions. La
   démonstration **comportementale** — « trois appels ne prélèvent qu'une fois »
   — appartient au banc en transaction annulée, avant application. Cette règle
   est née de `idempotence_prets_helvetia`, qui a laissé 1 000 FR en bêta.
4. **Ne jamais retaper le corps d'une fonction qu'on modifie.** Le canal
   d'application refuse au-delà d'environ 12 500 caractères, et
   `traiter_prets_helvetia_quotidien` en fait 16 039 à elle seule. La migration
   ne porte alors que le **patch** : `pg_get_functiondef` → `replace()` →
   `EXECUTE`, avec un `RAISE EXCEPTION` si la substitution n'a pas eu lieu. Un
   fragment inexact fait donc échouer la migration **bruyamment**, là où un corps
   retapé applique la faute de frappe sans broncher. Dix-sept `INSERT` de
   courrier ont été routés ainsi le 9 octobre 2026, sans qu'un libellé bouge. Le
   patron complet est dans `../WORKFLOW-SUPABASE.md`.
5. **Dans une porte, un refus rendu après une écriture laisse l'écriture.** Ce
   n'est pas une règle de migration mais de *porte*, et elle a sa place ici
   parce qu'elle décide de l'ordre des instructions qu'une migration dépose. Une
   fonction appelée par PostgREST qui **retourne** normalement voit sa
   transaction **commiter** : rendre `{ok: false}` après avoir inséré une ligne
   la laisse en base. Trois réponses, et une seule par cas :
   - **ordonner** pour que les refus probables tombent avant la première
     écriture — c'est pour cela que la porte des subventions insère la
     proposition *avant* de facturer les 2 PA : un rejeu est ainsi refusé sans
     rien coûter ;
   - **défaire explicitement** avant de refuser, comme
     `budget_repartition_fixer` restaure l'ancienne part avant de rendre
     `somme_depasse_cent`, ou comme la porte des subventions supprime la
     proposition qu'elle vient de créer si le paiement échoue ;
   - **lever** quand le refus ne serait pas un refus métier mais une
     incohérence : un débit d'enveloppe refusé alors que la réserve le
     garantissait annule toute la transaction, parce qu'une proposition acceptée
     sans transfert serait pire qu'une erreur affichée.

   Le symptôme à reconnaître : une porte qui rend un refus *après* un `INSERT`,
   un `UPDATE` ou un `PERFORM` d'écriture, sans `DELETE` compensatoire ni
   `RAISE`. Elle a l'air prudente et elle écrit quand même.

## Les trois règles

1. **Idempotente.** `CREATE ... IF NOT EXISTS`, `CREATE OR REPLACE FUNCTION`,
   `DROP POLICY IF EXISTS` avant `CREATE POLICY`. Rejouée, elle ne casse rien.
2. **Éprouvée avant d'être appliquée**, par DDL transactionnel ou dans un schéma
   jetable. Voir `../WORKFLOW-SUPABASE.md`, temps 3.
3. **Commitée avec le baseline réextrait**, dans le même commit. Séparés, ils
   laisseraient un instant où le dépôt dit autre chose que la base.

## Ce qui n'a pas sa place ici

Ni brouillon, ni banc d'essai, ni proposition non appliquée : ce répertoire ne
contient que des migrations destinées à être appliquées. Les anciennes
migrations dispersées sont archivées dans `../historique/sql-racine/`, et elles
ne sont pas rejouables.

`../outils/baseline/verifier-workflow.py` vérifie la convention de nommage,
l'absence de doublon d'horodatage, et que chaque migration est bien postérieure
au point de coupe.
