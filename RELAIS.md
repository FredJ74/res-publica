
### Priorité P0 explicite — affichage navigateur / vérité serveur (29/10)

**Responsable unique : ChatGPT (coordination avec Codex pour socle inventaire/groupes).** La clôture Luthécia exige : (1) cartographier les valeurs calculées, sauvegardées ou affichées localement sans confirmation serveur ; (2) supprimer/adapter les anciennes écritures qui écrasent positions, inventaire, soldes, santé, moral, sanctions et état du PJ ; (3) sécuriser chargement, autosauvegarde, perte de réponse, reconnexion, changement de version après déploiement ; (4) tester égalité état UI / état canonique après action, refresh, reconnexion et deux sessions, sans mutation d'un PJ réel lors de l'audit. **Ne pas confondre suppression d'une double autorité avec simple actualisation cosmétique.** Les six fermetures liées à #213 restent subordonnées à prévol et validation. Toute régression de cette catégorie bloque la promotion en production.

## Arbitrage du 29 octobre 2026 — clôture Luthécia au 1er novembre

**Décision explicite du game designer : Claude reprend les cinq terrains et l'intégralité du parcours immobilier.** Codex cesse les nouveaux changements sur ce périmètre (parcelles, occupation, compromis, notaire, permis, construction, approvisionnement, division, livraison, rénovation), y compris dans ses PR historiques ; il transmet à Claude les branches/PR, commits, migrations et résultats de tests existants. Claude repart du dernier main et incorpore les modifications vérifiées sans écraser les travaux du socle.

**Répartition sans chevauchement :**
- **Claude :** terrains, immobilier, prêts et placements fonctionnels ; revue/correction des défauts bloquants commerce, électronique, premium, presse, PNJ et douanes. Sur sécurité privée, il ne touche qu'au raccordement immobilier après livraison du socle commun.
- **Codex :** inventaire serveur, groupes PJ/PNJ, police/armée, sécurité privée universelle, combats par rounds, atomicité des déplacements, transports et anciennes écritures concurrentes propres à ce socle. Pas de modification immobilière, sauf transmission de correctifs déjà préparés.
- **ChatGPT :** inventaire réel SQL/ACL/RLS des autres écrivains, fiche personnage, orchestration PR #230, migration et fermeture des anciens accès inventaire après vérification, tests combinés, fusion et production. Les **six fermetures associées à #213** doivent être identifiées précisément avant exécution ; ne jamais les inventer ni les appliquer sur une livraison incomplète.

**Cadence de livraison :** une fenêtre de livraison quotidienne en fin de journée pour les lots **prêts et testés**, sans obligation de livrer si garde bloquante ; pas d'accumulation forcée jusqu'à dimanche. Avant chaque livraison, rebase/réconciliation sur main, tests de l'exact SHA, prévol SQL, migrations ordonnées, contrôle Vercel READY et recette. Les modifications communes (`data.js`, `plateau-*.js`, `supabase.js`) sont ciblées et les agents repartent du dernier main publié.

**Critère dimanche :** Luthécia jouable sans défaut bloquant, données des PJ protégées, parcours essentiels vérifiés. Les non-bloquants restent listés explicitement : ne pas les présenter comme terminés. Ne pas repousser un verrou de sécurité qui expose directement argent, inventaire, position ou sanctions si la voie reste exploitable.

---

# Relais entre agents

Passage de témoin entre Codex et Claude. Mis à jour à **chaque push**.
Règles : voir `AGENTS.md`.

## En cours

### PR #325 — quatre PNG des locaux commerciaux de Port-Sainte-Marie

Branche `fix/psm-quatre-images-commerces-20261101`. Les quatre PNG du ZIP fourni par Fred sont ajoutés sans transformation ; égalité octet pour octet vérifiée après extraction. Les quatre chemins déjà préparés dans `data.js` correspondent aux fichiers grand, moyen, petit et micro. Aucun moteur, prix, superficie ou autre fonctionnalité modifié. Syntaxe de `data.js`, décodage des quatre PNG et raccordements effectifs dans WORLD vérifiés. Contrôleur client : **139/139 bancs réussis**, après mise à disposition des dépendances déjà installées (premier essai incomplet : dépendances absentes). Fusion simulée avec le main récupéré : sans conflit. Contrôles GitHub et fusion encore à vérifier : accès API refusé dans cette session ; requête Vercel également bloquée par le proxy (403), aucun statut de déploiement déduit. Ne pas déclarer la production livrée avant fusion et vérification des ressources Vercel.


Rubrique nettoyée le 31/10 (Claude) : les chantiers livrés sont passés dans « Derniers chantiers » ; l'ancien texte détaillé reste dans l'historique Git de ce fichier (`git log -p RELAIS.md`).

### Codex — #219 : reconstruction réussie, livraison retenue

Branche `codex/groupes-universels-20261028`, PR #219, main intégré jusqu’à `3aa6ceef` (#290). Rapport de reprise : `outils/audits/RECONSTRUCTION-CANONIQUE-GROUPES-219-20261031.md`, preuves sous `preuves-canonique-219-20261031/`. PostgreSQL 17.6 natif, 88 migrations atomiques et 30 parcours sur catalogue entier validés ; 149 bancs clients et 105 Chromium passent. **Global 10/12, prérequis #233 et recette authentifiée isolée encore à valider : ne pas fusionner ni déployer.** Aucun nouvel export canonique à demander, aucune production modifiée par cette intervention. Ne pas ouvrir le chantier suivant.

### Claude — reprise #219 (Codex en panne), 01/11 : BLOQUÉ, paquet privé requis

Branche `claude/integration-219-main-20261101` (= `bf06a27` + `main` `b69be61b`, deux conflits résolus, **non poussée sur #219**). Défaut réel : sources de tarifs 452 → 457 (7 écarts, tous décisions de Fred du 01/11), le plan de tarifs du lot 95 doit être réexaminé contre un relevé frais de production. Blocages : JSON privé et SHA-256 non reçus ; PostgreSQL 17.6, GoTrue, PostgREST et pglast indisponibles ici. Pile #219+main+#318+#324 éprouvée sur PostgreSQL 16 (non certifiant) : #318 14/14, hospitalisation 25/25. Rapport : `outils/audits/REPRISE-CLAUDE-219-20261101.md`. Aucune fusion, aucun déploiement, aucune écriture en production.

### Migrations fusionnées, en attente d'application (ChatGPT)

**Prises en charge par ChatGPT (Fred, 31/10)** : `20261031130000` et `20261031140000`.

Vérifier toujours une migration par son **NOM** dans `supabase_migrations.schema_migrations`, jamais par son numéro.

- `20261031130000_reliquats_immobilier_accord_tacite_succession` (PR #284, fusionnée) : accord tacite de nuit (aujourd'hui toujours en échec : le permis de Jean Jaaj, terrain 5, en dépend dans environ 6 jours) et colonnes `proprietaire` / `coproprietaire` à la succession. Indépendante de l'écran. Banc : `outils/bancs/banc-reliquats-immobilier.sql`.
- `20261031140000_helvetia_caisse_argent_detenu` (PR #285, fusionnée, #267) : la caisse d'Helvetia représente l'argent détenu (prêt sans débit de caisse, sommes prises sur le compte Helvetia sans recrédit, dépôt d'ouverture crédité). Indépendante de l'écran. Banc : `outils/bancs/banc-caisse-helvetia.sql`.
- `20261031151000_placement_helvetia_gain_unique` (Claude, 31/10, suite de #267) : à la résolution d'un placement Helvetia, le gain net n'est plus ajouté à `arg` (argent total liquide + Banque nationale, où il apparaissait en double) et entre dans la caisse avec les frais. Indépendante de l'écran ; **déjà appliquée en production** sous le nom de registre `placement_helvetia_gain_unique_20261031151000` (version `20261031131427`, prévol Supabase du 31/10) ; ne pas réappliquer avant l'échéance du 6/11. Banc : `outils/bancs/banc-placement-helvetia.sql` (attendu sur ce placement : caisse +6 314, compte +83 340, `arg` +0).
- `20261031113650_squatteurs_issue_combat` (ancien préfixe `20261029181000`, rehorodatage #219) : **attend le combat de groupe de Codex (#219)** ; ne pas appliquer avant.
- `20261031220000_transfert_prime_signature_serveur` (Claude, purge Luthécia) : après Vercel READY ; préconditions d'empreinte dans la migration et dans `outils/bancs/prevol-299-prime-signature.sql`.
- `20261101121000_manifestation_spontanee` (Claude, 1/11) : **attend #219 installé** (la migration se refuse sans `groupes_pj_adhesions`). Banc : `bash outils/bancs/banc-manifestation-spontanee.sh` (base jetable, 29 épreuves). Règles : `GAME-DESIGN-MANIFESTATIONS.md`. Après application, l'ordre « Organiser une manifestation spontanée » des trois places fonctionne ; avant, il répond « pas encore installée », sans rien prélever.
- `20261031230000_organisations_champs_commandes_serveur` : **préparée, ne pas appliquer** avant #219 installé et recetté (feu vert requis dans la transaction).
- ~~`20261031190000_avis_personnels_expediteurs_declares`~~ **appliquée par Claude le 31/10 vers 20 h, registre `avis_personnels_expediteurs_declares_20261031190000`** (PR #297, fusionnée `c44f5c40`, Vercel READY) : neuf identités d'avis personnels (expulsion, libération, candidature, convocation douanière…) déclarées pour l'envoi **à soi seulement** ; sans elle ces courriers sont refusés en silence. Indépendante de l'écran. Banc annulé : `outils/bancs/banc-avis-personnels-expediteurs.sql` (joué le 31/10 : avant refus, après accepté pour soi, refusé vers un tiers).

### Audit des bâtiments de PSM et Montrouge (Claude, branche `claude/audit-psm-montrouge-20261101`, livrée par la livraison groupée #316 le 01/11)

- Rapport : `outils/audits/AUDIT-BATIMENTS-PSM-MONTROUGE-20261101.md` ; outil `outils/audits/auditer-socle-villes-republia.cjs` ; garde `outils/bancs/test-parcelles-republia-socle.mjs`.
- **Corrigé côté écran** : gabarit #135 sur toutes les parcelles (PSM avait 3 ordres anciens ; « Accélérer le chantier » mort retiré de Montrouge ; « Corrompre un fonctionnaire » sur toutes les parcelles) ; surfaces et prix décidés par Fred le 01/11 (PSM 1 500 m² à 18 000 FR ; lot 6 de Montrouge 2 100 m² à 25 200 FR) ; « Vendre des matières à l'usine » au pôle tabac-alcools et à la raffinerie.
- **Autres empires inchangés** (suite au prévol ChatGPT) : lot 6 de Montrouge par surcharge locale, migration restreinte à `republic` et qui le vérifie (`autres_empires_modifies`).
- **Migration `20261031234500_terrains_psm_montrouge_socle` (non appliquée)** : indépendante de l'écran. Sans elle, les dix parcelles de PSM et Montrouge restent « introuvables » (aucune ligne `terrains_etat`). Jouer d'abord le banc annulé (le canal Supabase a refusé faute de confirmation humaine), puis appliquer.
- **Banques locales = guichets de la Banque Nationale** (décision de Fred, 01/11) : mêmes ordres à l'écran ; **migration `20261031235500_banques_locales_guichets_nationaux` (non appliquée)**, patch en place des gardes de `banque_virement`, `banque_virement_automatique_creer` et `pret_national_contracter_versionne` (fragments vérifiés en lecture sur la production). À appliquer **après Vercel READY** (sans elle, le nouvel écran propose des virements et prêts que le serveur refuse « pas sur place »).
- **Dispensaires de province** (décision de Fred, 01/11) : centre antipoison et transfert en clinique privée, mêmes définitions qu'à Luthécia ; aucune migration (coûts déjà au miroir). Signalé : le jet de l'antipoison reste tiré par l'écran dans les trois villes.
- **Juge de l'énigme du musée** (décision de Fred, 01/11) : « Demander à parler à un juge » masqué hors enquête et après l'autorisation du coffre, refusé avant coût ; reste propre à Luthécia. Garde `test-juge-enigme-musee.mjs`.
- **Falsifier un document** (décision de Fred, 01/11) : au greffe des tribunaux municipaux de PSM et Montrouge, comme à Luthécia ; aucune migration.
- **Hôtels de province** (décision de Fred, 01/11) : rumeurs, informateur et tournée au hall ; service d'étage à 50 FR. Le triplet (service_etage, 0, 50) est ajouté par la migration `20261031234500` : sans elle, le service d'étage de province est refusé (coût non déclaré).
- **Hôtellerie et restauration séparées** (règle de Fred, 01/11) : dans chaque ville ce sont deux établissements distincts (PSM : Hôtel du Port / Capitaine Sauvage) ; seul La Républia (Luthécia) est hôtel et restaurant. Donc pas de dîner d'affaires dans les hôtels de province.
- **Marché noir** (décision de Fred, 01/11) : ordre « Marché Noir » (explosifs + poison local) dans toute la Républia, ajouté à l'armurerie de Montrouge et chez Chasse et Pêche (PSM) ; aucune migration (serveur indépendant de la ville).
- **Pouls populaire** ajouté au marché de PSM (socle commun, 01/11). **Personnalités des musées de province** (Fred, 01/11 : écrites par Claude, à sa relecture) : 8 salles de PSM, 6 de Montrouge ; rien sur l'énigme Le Goff ; audioguides de Montrouge non transcrits, cohérence à vérifier à l'écoute.
- **Rachat à PSM** (Fred, 01/11) : Capitaine Sauvage 120 000 FR, Hôtel du Port 80 000 FR ; **migration `20261101010000_rachat_capitaine_sauvage_hotel_port` (non appliquée, indépendante de l'écran)**, sans elle l'acte de rachat est refusé faute de prix.
- **Sécurité privée en province** (Fred, 01/11) : pas de duplication de Grobras Sécurité ; Grobras est l'exemple d'un commerce que les PJ pourront ouvrir : les PJ créeront leur propre agence de sécurité privée (à concevoir dans le socle #135, Codex).
- **Sorties de bâtiment de Montrouge** : migration `20261101020000_sorties_batiments_montrouge` **appliquée par Claude le 01/11 (registre `sorties_batiments_montrouge_20261101020000`)** : pérennise les six terrains insérés en urgence par ChatGPT et ajoute siège syndical, usine principale, zone de production (vers `montrouge-vue-2`) et tribunal municipal (vers `montrouge-vue-7`), qui n'avaient aucune sortie. PSM : tous ses bâtiments ont une sortie.
- **Catalogues de Montrouge (M-02, M-03)** : migration `20261101030000_catalogues_montrouge_marche_cafe` **(non appliquée, à appliquer APRÈS Vercel READY** : elle met à la carte la barquette de carbonade-frites, que l'ancien écran ne connaît pas). Dotation propre à une ville (`<clé>@<ville>`, lue avant la clé générale par `entreprise_assurer_existence`) ; marché de Montrouge limité à ses 6 produits (les 8 de Luthécia retirés, stocks et caisse intacts) ; bœuf bourguignon retiré de la carte du Café des Cheminots. Banc annulé joué le 01/11 : OK, le rattrapage ne réintroduit rien, Luthécia intact. Générateur des miroirs (`generer_miroirs_entreprises.py`) et seeds du baseline ignorent encore la clé `@ville` : à aligner au prochain relevé.
- **Jardins ouvriers (M-06)** : ordres « Travailler aux jardins » (1 PA, 5 fruits et légumes, une fois par jour), « Laisser des légumes » et « Se servir dans la réserve » ; migration `20261101040000_jardins_ouvriers_montrouge` **appliquée par Claude le 01/11 vers 12 h 20 (registre `jardins_ouvriers_montrouge_20261101040000`)**, indépendante de l'écran. Banc annulé `outils/bancs/banc-jardins-ouvriers.sql` joué juste avant sur Angie Porcelana : travail +5, rejeu sans double effet, second travail refusé (une fois par jour), laisser 3, refus au-delà du stock, prendre 2 ; rien conservé. PNJ **Marcel Demine** (nom choisi par Fred, 01/11), cheminot retraité, fiche dans `api/_pnj-personnalites.js` (don volontaire, renvoi au musée, trois « premières » de Montrouge), à la relecture de Fred.
- **Églises** (Fred, 01/11, `outils/audits/AUDIT-EGLISES-REPUBLIA-20261101.md`) : Église Progressiste de Montrouge ; +500 FR par église (`20261101060000`, appliquée) ; salaire religieux 50 FR/jour (`20261101061000`, appliquée).
- **Musée de Montrouge** : PNJ **Elsa Montbaron** (nom de Fred, 01/11) à l'accueil, portrait tiré de l'image de l'accueil, fiche de dialogue à la relecture de Fred.
- Toutes les questions de l'audit sont tranchées. **Livraison #316 (Claude, 01/11, autorisée par Fred)** : après Vercel READY, bancs annulés joués contre la production puis appliquées `20261031234500` (registre `terrains_psm_montrouge_socle_20261031234500`, 15 parcelles Républia), `20261101010000`, `20261031235500`, `20261101030000`, et `20261101123000` corrigée sous le nom `production_presence_proprietaire_salaries_20261101123000` : la présence **s'ajoute** aux droits du propriétaire et des salariés actifs (la première version les remplaçait, ce qui bloquait boutiques de PJ et armurerie, sans adresse dans leurs données ; banc 22/22 propriétaires). Les fichiers restent dans `migrations/` jusqu'au prochain relevé du baseline (ChatGPT, #262).

### Purge finale Luthécia (Claude, branche `claude/purge-luthecia-20261031`)

- **Caisses collectives #295 (PR #300)** : étapes 1 et 2 **appliquées par ChatGPT le 31/10** (registre `20261031195210` et `20261031200630`). Ne pas les rejouer.
- **Prime de signature** : migration `20261031220000_transfert_prime_signature_serveur` (**non appliquée**, indépendante de l'écran : l'ancien écran reste compatible). La prime `prixJoueur` de l'offre est payée par la caisse du club d'arrivée avec le prix, dans la même transaction, créditée au joueur dans `personnages_donnees`, une seule fois ; l'offre refuse une prime non entière ou négative. Écran : adopte la fiche rendue, verrou de double clic. Bancs : `banc-prime-signature-local.py --local-jetable` (21/21, contre-épreuve), `banc-prime-signature-client.cjs` (6/6 ; ancien code : 4 échecs). Prévol : `outils/bancs/prevol-299-prime-signature.sql` (section 3). **À appliquer après Vercel READY de la fusion.** Aucun écran ne propose de prime aujourd'hui (toujours 0) : question de design pour Fred, non bloquante.
- **#299 (garde 13/14 de #219)** : les deux préparations immobilières sont **déjà en production** sous `construction_materiaux_prix_et_dons_94` et `compromis_financement_reel_135`, puis réécrites par `20261030210000` ; leurs gardes d'empreinte échouent contre la production. **Action Codex : supprimer `20261031113610_…` et `20261031113631_…` de #219.** Preuve : `outils/audits/CLASSEMENT-299-20261031.md` ; test `test-preparations-deja-appliquees.mjs` (la garde de la vue n'est pas touchée).
- **Organisations, fin de la double autorité** : inventaire figé par `test-organisations-ecritures-inventaire.mjs` (17 chemins avec commande #219 et repli, 16 sans commande). Étape A **préparée, non appliquée** : `20261031230000_organisations_champs_commandes_serveur` (se refuse sans les contrats #219 et sans feu vert explicite). Étape B (REVOKE INSERT/UPDATE) seulement après portage des 16 chemins. Détail : `outils/audits/ORGANISATIONS-ECRITURES-20261031.md`.

### Décisions attendues de Fred

- **Hospitalisation (décision de Fred, 01/11)** : règles complètes dans `GAME-DESIGN-HOSPITALISATION.md` (déclencheur à 0 PA, J0/J1/J2, repas de l'hôpital, clinique ×3, transfert en ambulance dès J0). À implémenter ; une précision en attente sur le remplacement des anciennes durées par palier.

- **Fonds et murs des commerces (#66)** : règles décidées le 21/10 (murs à 150 FR/m², La Republica 1 200 m², fonds et murs indépendants, achat conjoint atomique, murs des commerces PNJ à la commune), **rien n'est en production**. La PR #71 qui les implémentait est périmée (laissée ouverte, commentaire du 31/10) : à reconstruire depuis main si Fred en fait une priorité.
- **Ambassades** : griser « Bientôt disponible » les ordres non raccordables tant que le voyage entre empires n'existe pas (immunité, arrestation de l'expulsé, transfert de détenus, naturalisation). Référence : `GAME-DESIGN-AMBASSADES.md`.

### Points ouverts transmis (non bloquants)

- **Codex (signalé par Claude, 31/10)** : `militaire_entree_zone` a répondu 404 une fois à 17 h 24 (fonction présente en base : probable cache de schéma pendant une migration ; à surveiller). `sbMarquerVolTraite` écrit `vols_en_attente` sans droit UPDATE (table vide, vols désormais immédiats : branche morte à retirer).

- **Refinancement BNR en trop d'Helvetia (#267)** : annulé par `20261031150000_helvetia_bnr_excedent_regulariser` (PR #288, appliquée) ; Fred a laissé le choix à Claude, qui garde l'annulation (la première note « remboursement normal » est caduque). Voir `GAME-DESIGN-BANQUES.md`.

- **Helvetia, même famille que #267 (examiné le 31/10)** : `finaliser_achat_bien_helvetia` est juste (acompte et solde viennent du liquide ou de la Banque nationale, jamais du compte Helvetia). `resoudre_placement_helvetia` corrigé par `20261031151000`. Le seul placement déjà résolu (Jean Jaaj, 25/10) a ajouté 3 920 FR fantômes à son `arg` ; non régularisé, car son `arg` s'écarte déjà de liquide + Banque nationale de bien plus (≈ 47 000 FR ; Angie aussi, en sens inverse) : écart général de `arg` à examiner côté fiche (ChatGPT).
- **Codex** : `minuit_decouverte_crimes` (police) retire des amendes de `arg` sans les verser nulle part ; il peut appeler `amende_imposer_interne`. Le hooliganisme (organisations) écrit encore sa trace de crime à l'écran (à passer par `crime_tracer_interne`). Écritures de l'écran encore ouvertes : `budgets_clubs`, `organisations.caisse` (bilan `outils/bancs/ECRITURES-ECRAN-20261029.md`).
- **Budget national (répété le 31/10, annulé)** : Jean Jaaj (min_fin) change le taux national 5 → 6, sa fausse réserve du Trésor glissée dans la même écriture est ignorée ; Arnie (min_def) ne change rien. La garde fonctionne ; seul bémol, le refus d'un non-titulaire est silencieux (valeur conservée), pas nommé.
- **Baseline (ChatGPT, #262)** : `payer_ordre`, `inventaire_place_restante` et `personnages_convocations_garder` diffèrent en production des migrations du dépôt (copie dans `jetable-ecarts-production-20261030.sql`) ; `acquisitions_transactions_internes` n'est créée par aucune migration rejouable.
- **PNJ encore muets (déclarés dans `banc-dialogue-pnj-republia.js`)** : Maître Ali Bihanbeton et Maître Henri Nossant (avocats commis d'office de PSM et Montrouge), huit députés.
- **Sécurité privée #135** : PR #196, #212, #216, #217 ouvertes ; décision de Fred du 27/10 dans `AGENTS.md` (deux socles seulement, aucune affectation au chantier). Le raccordement reste à tester en production.
- **Issue #143** : passer toutes les fenêtres à la charte ardoise et or.

### Consignes durables pour tous les agents (reprises des chantiers des 26-30/10)

- Popularité ou influence rendue par une RPC : `adopterJaugeServeur('pop'|'inf', valeur)`, jamais `state.pop = v.pop` (double comptage à la sauvegarde suivante).
- Réponse serveur qui change l'inventaire : elle rend `inventory` et `revision`, l'écran l'adopte par `sbAdopterInventaireServeur(v)`. Tout nouvel objet est déposé par le serveur (`inventaire_deposer_interne`).
- Acte illégal : détection tirée dans sa fonction serveur (`crime_detecter_interne`), trace par `crime_tracer_interne`, jamais `checkDetection` à l'écran. Un dégât ou une fermeture se pose dans la fonction serveur de l'acte.
- Tout retrait de motif de recherche passe par une fonction serveur qui sait pourquoi ; tout crédit de caisse se fait dans la fonction serveur de l'action.
- Une fonction serveur écrit `personnages_donnees`, jamais la vue `personnages` (voir `AGENTS.md`).
- Bancs SQL : se placer au rôle `authenticated` (sinon `est_appel_serveur()` est vrai et masque les défauts) ; poser `request.path` = `/rpc/...` pour les écritures d'inventaire (sinon `inventaire_revision_garder` les annule).
- La passe de nuit pose `cycle.dernierScrutin` à chaque proclamation : ne pas le retirer, la contestation en dépend.

### À vérifier en jeu (Fred, Angie, Vince)

- Terrain occupé par des squatteurs : « Appeler la police » propose l'intervention légale (1 PA, sans paiement) et la corruption (coût et taux annoncés par le serveur) ; « Faire disparaître le corps » sur un cadavre.
- Après application de `20261031130000` : le permis de Jean Jaaj (terrain 5) est accordé tacitement à la fin de l'instruction, attestation et courrier reçus.
- Chez Petit : « Monsieur le ministre » / « Madame la ministre » selon le genre du personnage (#281).
- Chez le notaire : « Officialiser une transaction » → « Vente de terrain » → « Confirmer » (#269).
- Louer un local dans les centres de Montrouge et de PSM ; acheter un terrain pour la commune en tant que maire ; attribuer un logement social en tant qu'adjoint.

## Derniers chantiers
- 01/11/2026 — **Centres d'affaires de Montrouge et PSM (Claude, livrée par #316 le 01/11)** : le trio du hall de Luthécia (Gretta, Moshe, Harry, gabarit partagé) n'apparaît plus en province ; une seule hôtesse par ville, Jeanne Terril (Montrouge) et Edith Legall (PSM) ; antennes de La Tribune : un journaliste propre à chaque ville, Arthur Lutte (Montrouge) et Annie Houininon (PSM), à la place du « Correspondant Local » générique. Contrôle du même jour : annexes BNE et antennes ont toutes les fonctions de Luthécia, caisses de rédaction présentes en base, fiches de dialogue écrites sur délégation, à la relecture de Fred. Banc dialogues PNJ 43/43.
- 01/11/2026 — **Manifestation spontanée sur les places (Claude, livrée par #316 le 01/11 ; migration en attente de #219)** : ordre commun aux trois places (Luthécia, PSM, Montrouge), décidé par Fred ; tout au serveur (`manif_spontanee_organiser`, `manif_spontanee_lire`) ; migration `20261101121000` en attente de #219.
- 31/10/2026 — **Clôture Luthécia, forum et messagerie (PR #297)** : sondage commandé jamais publié (arguments décalés, 403), affaire transmise au tribunal et retrait de projet refusés (signature institutionnelle sans `author_real`) ; avis personnels refusés faute d'expéditeur déclaré (migration `20261031190000`). Bancs `banc-forum-auteur-institutionnel.cjs`, `banc-avis-personnels-expediteurs.mjs`. Audit du même jour, sans défaut : routage des 266 ordres de Luthécia (aucun ne tombe sur un refus serveur), coûts des ordres payants identiques au miroir `ordres_couts`, écritures directes de l'écran toutes couvertes par une politique (sauf deux branches mortes), recettes électroniques et chocolat cohérentes, terrains 1-5 cohérents.
- 31/10/2026 — **Placement Helvetia (PR #289, fusionnée)** : gain net versé une seule fois, caisse créditée frais + gain ; migration `20261031151000` en attente d'application (avant le 6/11). Annulation BNR de #288 conservée (choix délégué par Fred).
- 31/10/2026 — **Quêtes (PR #290, fusionnée)** : écritures mortes de `quetes_actives` retirées de l'écran (déjà en lecture seule en base), baseline réaligné.
- 31/10/2026 — **PNJ Norbert Charton et Yvon Paletier (PR #291, fusionnée)** : fiches de personnalité écrites sur délégation, à la relecture de Fred.
- 31/10/2026 — **Reliquats immobiliers (PR #284, fusionnée `88a317b8`)** : revue des vieilles PR #139, #123, #118, #114, #113, #112, #71, #58 (49 de leurs 53 migrations en production ; sept PR fermées avec justification, #71 laissée ouverte). Police, corruption de l'inspecteur, expulsion légale et dissimulation d'un cadavre décidées par le serveur ; interventions échues traitées la nuit. Migration `20261031130000` en attente d'application.
- 31/10/2026 — **Caisse d'Helvetia = argent détenu (PR #285, fusionnée `05bbe5e4`, #267)** : migration `20261031140000` en attente d'application ; refinancement BNR en trop laissé à la décision de Fred.
- 31/10/2026 — **Genre du personnage dans les dialogues PNJ (PR #281, fusionnée, migration appliquée sous le nom `genre_personnage_serveur_20261031100000`)** : création refusée sans genre, civilité « Monsieur / Madame le ministre » dans les dialogues et la conférence de presse.
- 30/10/2026 — **Signature chez le notaire (PR #269, fusionnée)** : l'écran ne prélève plus le solde, le serveur encaisse à l'acte après avoir versé le prêt.
- 30/10/2026 — **Argent écrit par les fonctions serveur (PR #265, fusionnée, migrations `210000`, `211000`, `212000` appliquées)** : dix-neuf fonctions écrivent `personnages_donnees` ; la vue refuse bruyamment ; Jean Jaaj régularisé (150 000 FR).
- 30/10/2026 — **Capacité de l'Entrepôt (PR #261, fusionnée, `20261030200000` appliquée)** : place comptée par `inventaire_place_restante` ; achats simultanés éprouvés sur base jetable.
- 30/10/2026 — **Amendes au Trésor national (consolidée dans #255, migrations `20261030100000` et `110000` appliquées)** : dette prélevée chaque nuit, appel suspensif, fraude électorale par le même canal, garde du budget national.
- 29/10/2026 — **Mairies, terrain acheté par la commune, logements sociaux, commissariats (#243, #244, #246, #253, livrés par la PR consolidée #255, migrations appliquées)**.
- 29/10/2026 — **Centres des trois villes et location par le serveur (PR #240, fusionnée, migrations appliquées)** ; **écritures de l'écran et mariage par le serveur (PR #241, fusionnée)**.
- 29/10/2026 — **Terrains, parcours immobilier, prêts, placements (PR #233)** et **vérification commerces, électronique, premium, presse, PNJ, douanes (PR #234)** : fusionnées, toutes leurs migrations appliquées sauf `20261029181000` (squatteurs, attend #219). #224 (loyers) fermée avec preuve le 31/10.
- 28/10/2026 — Stabilisation Luthécia cinq points (ChatGPT, PR #218, fusionnée) ; fiabilisation GitHub / Vercel (Codex, PR #214, fusionnée) ; recette de clôture #135 (Codex, PR #194, fusionnée).
- 24-27/10/2026 — Ambassades et Bureau de l'Emploi (Claude, PR #141, #142, #144, #146, #147, #148, #150, #162, #168, #170, fusionnées) ; « une seule vérité » : ordre générique, religion, jauges, scrutins, justice, crime, informateurs par le serveur (migrations `20261027030000` à `130000` appliquées). Références : `GAME-DESIGN-AMBASSADES.md`, `GAME-DESIGN-BNE.md`, `AUDIT_UNE_SEULE_VERITE.md`.
- 31/10/2026 — **Caisses communales à l'accueil (PR #275, fusionnée `ecedfd97`, en production)** : consultation centralisée retirée ; caisse affichée à l'accueil des 21 bâtiments communaux des trois villes, mairies comprises (commissariat sous contrôle d'accès serveur) ; affichage isolé dans `afficherCaisseAccueilCommunal`, qui répare le contrôle « Cohérence client » rouge depuis #273 ; banc `banc-caisses-accueil-communal.cjs`. À constater en jeu : « Caisse : X FR » à chaque accueil, plus d'ordre à l'Hôtel de Ville.
- 30/10/2026 — #260 (Claude) fusionnée `888eb386`, migrations `20261030180000` puis `180100` appliquées par ChatGPT après déploiement READY : clé d'unicité sur neuf achats, anciennes portes sans clé fermées.

- 30/10/2026 — #258 (Claude) fusionnée `d5be7311`, migrations `20261030160000` et `161000` appliquées par ChatGPT : fiche PJ en fusion à trois voies, double clic, réponse perdue, fermetures fret et historique des terrains. Restent à faire en réel : création authentifiée, pertes de réponse et deux sessions.
- 30/10/2026 — #257 (Claude) fusionnée `d4ee7224`, migrations `20261030135000` et `140000` appliquées : crédits du budget national rétablis, sanctions financières communes au Trésor.

- 24/10/2026 — Mise en place du relais Codex/Claude (`AGENTS.md`,
  `CLAUDE.md`, `RELAIS.md`).

### Intégration inventaire #213 — 29/10/2026

- PR #249 : branche dédiée, issue du `main` 27198955, sans importer les groupes inachevés #219. Les raccordements d'inventaire de #213 sont réconciliés avec le code récent des écrans. Aucun déploiement, aucune migration de fermeture à cette étape.
- Dix migrations métier déjà installées en base ; six fermetures différées au déploiement d'un client compatible : `20261028210000`, `20261028210500`, `20261028210600`, `20261028210700`, `20261028210800`, `20261028210900`. Ne pas activer le verrou final sans observation et accord du game designer.
- CI au SHA de la PR #249 et validation des chemins d'inventaire impératives avant fusion. La garde fret `hg_fret_contenu_source` demeure désactivée en attendant le nouveau client.


### #219 — relais canonique complet reçu, #281 conservée (31/10)

Reprise sur `13bd120a`. Commentaire de relais 6542866046 lu ; quatorze fragments récupérés hors Git, sans publier leurs identifiants. Snapshot annoncé 345374:345374:, coupe UTC 2026-10-31 11:35:45.899473 et registre 1003 à vérifier intégralement. Main #281 intégré, y compris genre contrôlé serveur à la création, contexte PNJ et conférence, sans recréer la migration appliquée. Plus aucun export demandé à Fred ; poursuivre reconstruction, réconciliation et tests. Aucune production ni fusion de #219.

### #219 — reconstruction canonique et première installation réelle locale (31/10, EN COURS)

Relais complet validé hors dépôt (14 fragments, snapshot UTC 11:35:45, registre 1003), main #281 intégré dans 2175f16a. PostgreSQL **17.6 natif** : baseline rendu par les générateurs, 1199 fonctions recompilées, 10913 ordres avec seeds, comparaison sans écart dans le périmètre déclaré (371 tables publiques, cinq exclues documentées ; plateforme hors périmètre). Dix captures de seeds ajoutées ; provenance des 82 tables anciennes conservée, aucune prétendue réextraction. 33 tests outillage passent, dont rangs des colonnes supprimées, fermeture PUBLIC EXECUTE et contre-épreuve sur les bornes CHECK.

Les 88 préparations non appliquées sont rehorodatées après la nouvelle coupe, correspondance versionnée. Défaut réel de paiement corrigé : adaptation du corps examiné actuel, préservant les verrous acquisitions/permis et les fonds en transit. **Première installation atomique des 88 réussie sur cette copie locale**, après installation EXPLICITE du prérequis #233 (présent sur main, mais absent du registre et du catalogue reçus). Ce prérequis n'est pas déclaré déployé. Rapport local /tmp/hg219-lot-fidele-nouveau.json.

Ce n'est PAS la clôture : poursuivre recette sur schéma complet, bancs/contre-épreuves, classement des migrations déjà appliquées, contrôles globaux et cohérence des référentiels. Pas de production, pas de fusion, pas de Vercel, pas de compte réel utilisé. Les exports et identifiants des fragments restent privés hors Git.

### #219 — suite locale complète éprouvée, contrôles 10/12 (31/10, EN COURS)

379/379 scénarios de décors repassés, six mutations détectées (379 cas chacune), 105/105 tests Chromium, 147/147 bancs clients avant l'ultime raccord des coûts. Nouveau décor du catalogue entier : 29/29 scénarios sous les véritables fonctions, dont combats PJ/PJ et PJ/PNJ, rounds, rejeux, refus, radio, détecteur et écrou ; JWT SQL locaux, jamais GoTrue ni joueur réel. Avant/après installation : 12 incompatibilités RPC corrigées, zéro nouvelle ; 17 autres appels historiques/non déployés restent distingués dans le rapport, sans les effacer.

131 migrations attestées archivées avec leur version réelle du registre ; 65 autres conservées comme préparations non attestées et rehorodatées après la coupe, avant les 88 de #219. Aucun changement de leurs règles. Pré-requis #233 désormais `migrations/20261031113650_squatteurs_issue_combat.sql`, non appliqué en production. Workflow, Baseline, Assemblage, Reconstruction et pilote passent. Authority et Referential restent rouges, pas de faux 12/12. Référentiels du monde neuf raccordés aux huit générateurs existants ; les tarifs serveur de crimes sont relus de leur déclaration authored, pas réinventés.

Poursuivre les vérifications finales et l'enregistrement des preuves avant rapport. Production, fusion et Vercel toujours interdits.

### #219 — preuves finales sur main #286, livraison retenue (31/10)

Rapport courant : `outils/audits/RECONSTRUCTION-CANONIQUE-GROUPES-219-20261031.md`. Main intégré `9a821b1b` (#281/#284/#285/#286), sans perdre les adaptations des groupes. La reconstruction native 17.6 et l'installation atomique des 88 ne sont plus bloquées. **30/30 cas sur le catalogue entier** sans remplacement de moteurs, avec fiche fictive préexistante ; une panne après les 88 inscriptions annule les quatre catalogues, le registre et préserve la fiche. 379/379 cas de décors et six contre-épreuves, 148/148 bancs clients, 105/105 Chromium, 35/35 outillage, 19/19 relais et quatre régressions SQL passent. Preuves détaillées dans `preuves-canonique-219-20261031/`.

**NON LIVRABLE en production : global 10/12 (Authority, Referential rouges)** ; prérequis #233 absent du registre/capture, installé uniquement sur le décor ; aucun compte isolé de recette GoTrue. RPC : 29 incompatibilités statiques avant, 17 après, 12 corrigées et zéro nouvelle ; ne pas présenter les autres chemins historiques/non activés comme corrigés. Générateur des coûts 427 triples contre 438 mesurés en base : ne pas régénérer en production pour verdir la référence. Les mesures fraîches sont dans le rapport sans falsifier les anciennes observations. Aucune migration/fusion/commande Vercel de production. API GitHub GraphQL refusée ; Git push reste possible. **Ne pas redemander les exports canoniques, déjà complets et privés.** Ne pas ouvrir un autre chantier.

### #219 — intégration finale de main #290 (31/10)

Main `3aa6ceef` intégré dans `c129bc6c`, après sauvegarde des preuves dans `3e963bcd`. Les protections #283 du refus d'ajout inventaire et les suppressions d'écritures mortes de quêtes #290 sont préservées, ainsi que les changements bancaires #287–#289 (aucune migration appliquée par Codex). Les nouvelles étapes CI sont conservées avec celles de #219 ; caches index/plateau distincts, préfixés par `verrou-inventaire-20261031`. Sur cet arbre : **149/149 bancs clients, 105/105 Chromium, 30/30 sur catalogue entier, huit assertions du verrou #283**. Les 88 sources SQL restent identiques à celles de la dernière passe 379/379 + six mutants ; empreintes vérifiées. Global toujours **10/12**, jamais un feu vert de production. Rapport et preuves actualisés ; aucun nouveau chantier ouvert.

### #219 — nouvelle mission de clôture technique, CI et diagnostic Authority (31/10)

Reprise du vrai HEAD `1be8991b` (les dix fichiers annoncés sont déjà poussés), main #291/#292 intégré. Correction du lecteur SQL de bancs : morceaux générés, sources archivées, surcharges et séquences explicites ; réutilisé par immobilier et restaurant. Leurs anciennes transformations prennent des entrées historiques explicitement épinglées à `13bd120a`, pas un faux catalogue actuel ; gardes et assertions non retouchées. Résultats : **324 assertions immobilier, 94 restaurant**, tant sur 17.6 natif que sur le 16.2 du gestionnaire CI. Le rejet initial des définitions actuelles reste une limite de déploiement des anciens préparatifs, pas une compatibilité affirmée. 379 scénarios groupes repassés après changement du lecteur commun.

Authority : les cinq faux signalements de fonctions créées par CREATE FUNCTION/dans un DO sont corrigés par analyse PostgreSQL des déclarations et des listes VALUES reliées à EXECUTE format. Commentaires et fonctions simplement mentionnées ne comptent pas. Trois bancs de détecteur passent avec contre-exemples. Le parseur existant est installé avant les bancs clients dans la CI, sans second pipeline. Invariant 12 conforme ; **invariant 13 reste rouge (19 formes absentes ou incompatibles dans le catalogue capturé)**. Aucune migration, fusion ou production. Poursuivre Referential, raccordements et inventaire de clôture sans masquer ces écarts.

### #219 — paquet complet atomique et preuves après #292 (31/10, EN COURS)

Prérequis #233 et 88 migrations désormais préparables dans **une seule transaction** (`preparer-groupes-219.py --inclure-prerequis-233`). Épreuve native PostgreSQL 17.6 avec `--lot-219 --paquet-complet-219 --recette-219` : reconstruction fidèle dans le périmètre déclaré, 89 installations, 30 cas réels ; panne tardive annule aussi le prérequis, registre reste à 1003 et fiche fictive préservée. Aucun déploiement réel. 38 tests de l’outillage passent, dont refus de prérequis omis et de SHA altéré. Ne pas activer #233 séparément sur la production. Le canal distant capable d’exécuter cette transaction complète reste à valider ; la limite par appel MCP n’est pas une preuve de livraison possible.

Le diagnostic des cinq mesures est STRICTEMENT en lecture seule (`diagnostiquer-mesures-referentiels.py`) ; aucun changement de baseline, d’attentes ni d’observations. Une tentative d’actualisation a été refusée par la revue automatique pour risque de masquer Referential ; changements retirés, pas de contournement. Coûts : 427 générés contre 438 capturés ; postes et ressources concordent avec le contenu capturé, mais leurs sentinelles sont périmées. Global toujours **10/12**, Authority (19 formes RPC) et Referential rouges.

Mails : défilement déjà présent, testé dans Chromium avec rendu/CSS réels, deux largeurs et contre-épreuve de l’ancien défaut (3/3) ; aucun écran recodé. Caisses à l’accueil déjà intégrées #275 ; fonds/murs #71 non intégrés selon le relais actuel. API Actions refusée et ressources Vercel refusées (403) depuis cet environnement : aucun statut distant vert ni recette authentifiée revendiqué. Les exports restent privés hors Git.

Dernière passe complète après ces corrections : **150/150 bancs clients**, zéro échec, sockets locaux autorisés. Une première exécution confinée avait neuf échecs d’infrastructure navigateur/HTTP ; elle ne constitue pas le verdict fonctionnel. Preuves clients et complément du rapport enregistrés.

### #219 — correction de la CI réservation et inventaire des 19 écarts (31/10, EN COURS)

Le lecteur de la fixture restaurant substituait l’entrée historique `commerce_vendre_produit` même lorsqu’une migration explicite était demandée : contre-épreuve exécutée contre le mauvais moteur, retour sans `raison`. Substitution limitée au baseline ; versions historiques des deux fonctions de bonus épinglées au même commit public que le décor. **49/49 réservation** sur PostgreSQL 17.6 et sur le moteur 16.2 de CI, **94/94 restaurant**, **40/40 outillage** dont contre-épreuve de non-substitution. Aucun affaiblissement d’assertion.

`AUTHORITY-19-219-20261031.json` détaille les 19 : **12 résolus après installation locale des 89**, sept contrats d’organisations restent hors lot. Ne pas les masquer ni importer les 65 préparations. L’inventaire plus strict du catalogue après lot conserve 17 formes à examiner (dont arguments spread et anciens appels), distinctes de ces 19.

Le relais canonique contient cinq nombres/empreintes et dix tables de seeds, mais **aucun contenu des 438 triples `ordres_couts`**. Impossible d’attribuer les onze de différence nette à des clés sans ces lignes. `comparer-couts-captures.py` compare les ensembles réels, refuse doublons/types invalides, et fournit la requête strictement en lecture seule ; ne touche à aucun vérificateur ni référence. Contre-épreuve : +11 peut signifier +12/-1, pas forcément onze absences.

Main relu via le credential helper GitHub CLI existant : toujours `59ea6d90`, déjà intégré. API Actions encore Forbidden, pas de conclusion distante revendiquée. Aucun accès Supabase vivant exposé, aucune production modifiée. Continuer contrôles et preuves, puis pousser par le même helper ; pas de fusion.

### #219 — suite du workflow au-delà du premier arrêt (31/10)

La passe intégrale des commandes Python du workflow a trouvé 13 autres bancs bloqués par découpage/archives, séquences explicites et entrées de transformations devenues différentes. Lecteur existant réutilisé, chemins de migrations résolus par le classement, listes de versions explicites à la place des anciens globs vides. Les décors des transformations historiques épinglent leurs entrées publiques d’origine (SHA256), sans modifier une garde ni le SQL de production. Les assertions et contre-épreuves d’inventaire sont conservées ; aucun verrou d’inventaire modifié.

Les équipements collectifs restent incompatibles avec le payeur entier du catalogue capturé : refus des 5,50 FR vérifié sans débit dans le banc, avant chargement des entrées historiques cohérentes. Cette préparation d’organisations n’entre PAS dans les 89 migrations #219 ; son succès historique ne vaut pas feu vert de production. Continuer la passe complète du workflow et publier les résultats, sans prétendre 6/6 distants tant que l’API refuse l’accès.

### #219 — CI distante vérifiée par la page publique (31/10)

Alternative autorisée à l’API refusée : `https://github.com/FredJ74/res-publica/pull/219/checks`. **Six workflows réussis sur `6ef82a65dc3f8ecb5a18a874194109626ea85188`**, dont Cohérence client (run 41214656628). Les 43 commandes Python passent localement sur le moteur de CI ; 150 bancs clients et 105 tests Chromium repassés. Cette preuve ne vaut pas une livraison en production. PR toujours en brouillon.

Détecteur RPC ajusté pour les commentaires/accolades citées à l’intérieur des objets ; quatre tests et contre-exemples, notamment conservation des gestionnaires embarqués en HTML. Les 496 fonctions recensées sont conservées ; le paramètre `p_fn` des impôts est désormais correctement lu. Aucun appel propagé par spread n’est faussement déclaré complètement résolu. Les 19 écarts capture persistent (12 résolus après lot, sept organisations hors lot).

Les six mutations sont détectées, chacune sur 379 cas ; comparaison historique exacte : cinq listes identiques, une liste différente parce qu’un scénario additionnel dépend de l’issue du vrai combat. Le cas obligatoire `squatteurs_issue_reelle_obligatoire_tues` échoue toujours sous mutation. Le contrôle strict de listes a échoué et cette réserve est conservée, sans retirer ni modifier un scénario.

Rapport de reprise/livraison courant : `outils/audits/FINALISATION-LIVRAISON-219-20261031.md`. CI distante six succès confirmés sur 6ef82a65, reconstruction non recommencée, paquet inchangé, ordre de livraison suspendu pour les blocages détaillés. Ne pas redemander les quatre exports ; les contenus de coûts et des trois miroirs restent à lire par le connecteur disponible chez ChatGPT.

### #219 — capture 438 récupérée, premières causes corrigées (31/10, EN COURS)

Reprise de `4a8990a5`, main toujours `59ea6d90`. Deux derniers commentaires de ChatGPT lus sur la page publique. Capture publique des 438 tarifs récupérée du commit `4ec07923`, snapshot `346064:346064:` ; ne pas la redemander. Diff initial exhaustif : **388 communs, 50 seulement en base, 39 seulement générés**, pas onze simples absences.

Générateur raccordé à sept déclarations SQL authored appliquées et à leur projection tentative/réussite ; extraction AST des modules (ordre des propriétés, constantes locales, appel d’achat réel), aucun zéro fabriqué pour coût dynamique. Quatre contre-épreuves passent. **450 triples source, 411 communs avec la capture, 27 anciens couples restants, 39 nouvelles déclarations**. Aucune valeur de gameplay changée dans les écrans, aucun tarif copié depuis la capture comme canon. Seeds régénérés par l’outil existant. Diff individuel et origines dans `RECONCILIATION-COUTS-219-20261031.json`.

Poursuivre le nettoyage contrôlé des tarifs et les sept contrats : trois commandes actives ont leurs cinq migrations existantes sélectionnables ; quatre fonctions d’équipements doivent rester inaccessibles tant que leurs dépendances financières ne sont pas compatibles. Ne pas importer les 65 préparations en bloc, ne pas fusionner ni appliquer en production.

### #219 — trois commandes requises, quatre contrats futurs réellement désactivés (31/10)

Les trois RPC de commandes actives gardent leur moteur existant ; contrat absent = refus explicite, sans repli vers une sauvegarde générale (y compris dissolution). Sélection des cinq migrations existantes seulement dans `LIVRAISON-ORGANISATIONS-219-20261031.json`, pas d’import des 65 préparations. Installation encore à éprouver comme lot et à prévoler en production.

Équipements collectifs : les quatre appels absents ont été retirés des scripts chargés, bouton désactivé avec explication, aucun sondage automatique de contrat. Paiement collectif forgé refusé avant lecture du contexte ou paiement ; achat personnel inchangé. Code préparé original conservé hors chargement dans `historique/clients-prepares/`, ses anciens tests continuent ; quatre nouveaux tests protègent le client actif. Caches plateau et index montés. Authority passe de 19 à **15 écarts de capture** : douze du lot universel et trois de commandes à installer. Aucun écart supprimé par exception de vérificateur.

### #219 — compléments organisations et tarifs éprouvés (31/10, EN COURS)

Cinq migrations organisations sélectionnées et installées atomiquement sur PostgreSQL 17.6 jetable : **36 assertions**, dont rôle authenticated, rejeu, refus, rollback tardif et compatibilité du payeur protégé. Corps ou droits internes inconnus refusés ; aucune fonction financière remplacée.

Tarifs : 452 déclarations source, 413 communes avec les 438 capturées ; **25 anciens couples retirables, 39 ajouts justifiés**. Les couples gilet 0 PA/380 FR et 1 PA/600 FR restent distincts ; seul le mélange non déclaré 0 PA/600 FR est retiré. Migration préparée avec verrou, empreintes complètes avant/après et refus de dérive ; **29 assertions PostgreSQL 17.6**, aucun joueur réel. Seeds régénérés par l’outil existant ; export brut hors Git.

Composition **95 versions (5 + prérequis et 88 + tarifs)** préparée dans une transaction, mais NON exécutée intégralement ni validée contre les 1008 migrations désormais annoncées. Outillage **44/44**. Demande ciblée de métadonnées pour l’intégrateur dans `outils/audits/DEMANDE-PREVOL-ACTUALISE-219-20261031.md` : aucune donnée joueur ni nouveau compte demandé. Les garanties du catalogue 1003 ne prouvent pas celles du 1008. Pas de fusion, de migration réelle ou de déploiement. Poursuivre les bancs complets et la vérification Actions sur le SHA final.

### #219 — main #297 intégré, garde de rejeu corrigée (31/10)

Main `c44f5c40` intégré sans perdre les publications de Claude ni les étapes CI. La passe des 45 commandes Python a détecté un refus du propre rejeu de la migration événements après modification de sa garde de paiement. Garde limitée aux deux corps examinés (ancien et nouveau), corps tiers toujours refusé ; contre-épreuve ajoutée. Les 27 scénarios événements, 36 du paquet organisations et 44 d’outillage passent après correction sur PostgreSQL 17.6. Pas de modification de référence pour masquer Authority ou Referential ; prévol 1008 toujours nécessaire.

### #219 — preuves complémentaires et garde financière à transmettre (31/10)

Rapport courant : `outils/audits/COMPLEMENTS-LIVRAISON-219-20261031.md`. **45/45 commandes Python, 154/154 bancs clients, 105/105 pilote, 379/379 groupes, six mutants détectés**. Globaux **10/12**. Garde Node de push exécutée explicitement : **13/14** après réparation des chemins archivés ; deux préparations immobilières hors des 95 contiennent encore des écritures par la vue protégée (113610 et 113631), à reprendre avec Claude avant activation ; test non désactivé. Prévol actualisé 1008 et recette authentifiée toujours absents. Ne pas déclarer le lot prêt en production sur la seule CI de PR. Aucune production modifiée.

Précision de preuve : sortie détaillée des 14 assertions Node obtenue avec les sous-processus locaux autorisés (13 réussies, 1 refus de sécurité conservé). Sur le SHA `971cf43e`, cinq workflows distants déjà réussis, Cohérence encore en cours lors de la lecture ; ne pas convertir cette attente en succès. La preuve CI du dernier SHA doit être relue après ce complément documentaire.

### #219 — prévol 1009 reçu, incompatibilité réelle établie

Commentaires PR relus ; relevé ChatGPT `26a10c3b` récupéré de sa branche d’audit. Registre **1009** ; les 95 versions/noms absents, Helvetia et avis déjà enregistrés ailleurs. **Payeur vivant MD5 37eca91d6eb08c2a6ea97cbe717a216a, différent des corps examinés** : refus volontaire par le prévol organisations et l’adaptateur transport. Ne pas élargir la liste sans définition complète et test. Demande ciblée de catalogue existante désormais à exécuter contre 1009 (ou plus récent). Preuve dérivée `PREVOL-1009-BLOCAGE-219-20261031.json`. Blocage extérieur précis, aucune modification réelle ni ancien moteur imposé.

### #219 — rectification du prévol payeur (preuve ChatGPT 6548347589)

**Le blocage payeur annoncé ci-dessus est retiré.** La première capture donnait `md5(pg_get_functiondef)`, pas `md5(prosrc)` ; le corps vivant est bien `5cf45c19e4b9559f6b29e2b9207d3969`, déjà autorisé. Les internes 4/5 arguments sont absentes, état initial attendu. Aucune empreinte autorisée ni fonction financière modifiée. La preuve JSON conserve le diagnostic initial comme rétracté et distingue explicitement les deux objets hachés. Poursuite de l’épreuve intégrée des 95 et de la compatibilité #300, sans prétendre que ces seules métadonnées forment un export complet 1009.

### #219 — 95 migrations installées ensemble, compatibilité #300 éprouvée

Rapport : `outils/audits/INTEGRATION95-ET-CAISSES300-219-20261031.md`. PostgreSQL 17.6 : **95 versions en une transaction**, rollback tardif des quatre catalogues/registre/fiche, second passage refusé sans mutation, 30/30 recette catalogue + 3/3 commandes organisations. Après les deux migrations #300 : mêmes 30 + 3 réussites ; quatre bancs clients passent sur fusion simulée. Seul conflit textuel #300 : workflow CI (conserver les étapes des deux branches). Outillage **46/46**.

**Ne pas présenter ce décor comme 1009** : schéma privé 1003 + capture réelle tarifs 438, provenance explicite. Payeur inchangé et compatible, deux types d'empreintes reproduits. Pas de blocage payeur restant ; manquent catalogue/delta complets 1009 et référentiels statiques, recette GoTrue isolée, résolution #299 par Claude. Pas de production modifiée.

### #219 — vraie recette GoTrue/PostgREST locale, 26/26

Le banc intégré peut démarrer les binaires GoTrue v2.177.0 et PostgREST v12.2.12 sur loopback/socket Unix. Trois comptes entièrement fictifs créés/connectés dans la base jetable ; **26/26 scénarios HTTP réels** : identité/reconnexion, groupes/PNJ, radio même ville/hors ville, double clic concurrent/reçu unique, combat mixte/round/rejeux, refus fonds/coma/prison. Après 95 + #300, pas de moteur métier remplacé. Processus et bases nettoyés, aucun compte ni secret réel. Ce n'est ni une recette UI Chromium du jeu ni une validation production. Preuves et limites dans `INTEGRATION95-ET-CAISSES300-219-20261031.md`.

Nouvelle passe : 45/45 Python, 154/154 clients, 105/105 pilote, 48/48 outillage, six mutants détectés. Diagnostic strict post-95 : zéro fonction absente, huit chemins sans droit client et un spread incomplet conservés dans le rapport. Reste catalogue/delta 1009 complet et référentiels statiques, 12/12 non atteint ; #299 à Claude. Pas de fusion/déploiement.

### #219 — main #300 intégré réellement

Main `586ae9ea` intégré dans `ba4d0843`. Conflits CI/relais résolus en conservant tous les bancs, une seule installation des dépendances et les statuts réels Helvetia/courriers/caisses signalés par Claude. Les trois scripts partagés sont fusionnés sans retour des anciennes sauvegardes de secours ; caches index/plateau montés avec suffixe caisses300. #300 est déjà sur main, étape 1 annoncée appliquée par Claude : le prochain prévol doit viser l'état vivant **après cette étape**, pas supposer que la dernière coupe reste 1009. Pas d'application par Codex. Nouvelle passe en cours sur cet arbre combiné.

### #219 — garde finale des effectifs et relais réparés

L'élection ajoutée au catalogue intégré révèle le wrapper final du payeur après 115831 (protection recrutements) : `d5c9f4e8…`. La commande événement le reconnaît seulement avec ses deux internes exactes/fermées ; la garde initiale transport et le payeur ne changent pas. Origine dérivée des sources publiques, mutation tierce refusée. **30+5 cas avant et après #300, 26 HTTP authentifiés**, rollback tardif 95 et rejeu sans mutation.

Le banc des caisses passe 46/46 ; l'échec de workflow était le relais, trompé par les `.git` vides d'environnement. Détection des vrais dépôts/worktrees/liens conservée, **21/21 relais**, **49/49 outillage**, **155/155 bancs clients** après main #300. Relance complète des 46 commandes en cours, aucune référence falsifiée. Reste prévol complet après #300/données référentielles, #299 réservé à Claude, pas de certification production.

### #219 — validation finale de la reprise après #300

**46/46 commandes Python, 155/155 bancs clients, 105/105 pilote, 49/49 outillage, 21/21 relais.** Les 95 passent en une transaction sur le décor déclaré ; 30+5 scénarios avant et après #300 ; **27/27 HTTP authentifiés** avec GoTrue/PostgREST, dont JWT falsifié refusé (401), double clic concurrent/reçu unique et élection un PA/rejeu. Source initiale du payeur et garde 115805 inchangées. Six mutations détectées conservées. Services locaux nettoyés ; aucun compte réel touché.

Rapport courant `outils/audits/INTEGRATION95-ET-CAISSES300-219-20261031.md`, manifeste et preuves actualisés. **NON TERMINÉ : globaux 10/12, garde #299 13/14 maintenue, catalogue vivant complet après #300 absent de cet environnement**. Les exports privés locaux restent 1003 ; ne pas les baptiser 1009. La demande technique précise de métadonnées pour ChatGPT est prête ; aucune intervention de design requise. Pas de fusion de #219 ni de déploiement par Codex.

### #219 — nouveau relevé 1011 et refus réel du candidat

ChatGPT fournit neuf versions après 30193635 ; genre 31113025 est déjà dans 1003, donc huit entrées supplémentaires. Candidat local par sept sources de schéma + métadonnée de régularisation BNR (données jamais rejouées), provenance explicitement non canonique. Essai fonctionnel sources publiques : 95 + 27 HTTP passent. **Mais comparaison au relevé réel : quatre contrats financiers concordent, `club_transfert_conclure` diffère** (source ab4cb70e…, relevé 057d4b8e… ; définition complète locale 4db41e50…, donc ne pas reproduire la confusion de type de hash du payeur).

Le prévol candidat est désormais **refusé avant les 95**, échec conservé dans `hg219-candidat1011-diagnostic.json.gz`. Ne pas remplacer l'attente pour verdir. Besoin précis : définition vivante et empreintes typées de ce transfert, catalogue/delta canonique complet après #300 et référentiels statiques. Demande SELECT actualisée dans le dépôt. Les seuls exports complets disponibles ici restent 1003. Prévol production non conforme, pas de fusion/déploiement. Les 46/155/105/49/21 et 27 HTTP de la passe fonctionnelle ne valent pas validation du vivant 1011.

## Relais d'intégration consolidé #219 / #300 / #301 (31/10/2026, ChatGPT)

Cette section complète le relais de #219 sans écraser les travaux de Codex. L'état **de production** fait foi, et non les préparations historiques.
- Catalogue Supabase **1012 migrations**, dernière version `20261031211256`, `transfert_prime_signature_serveur_20261031220000`. La prime de transfert est payée côté serveur; `club_transfert_conclure(text)` a `md5(prosrc)=fdb85f2d8db7451aef4b65da6db9fd28`. Ne pas rejouer la migration.
- Les deux étapes #300 de protection des caisses sont **appliquées** (versions `20261031195210`, `20261031200630`). Les droits directs des clubs sont fermés; les triggers des organisations et transferts sont actifs. Les RPC d'organisation de #219 restent à installer.
- PR #301 **fusionnée**, écran Vercel READY. Son banc de prime et son inventaire d'écritures des organisations sont à conserver dans `.github/workflows/coherence-client.yml`, aux côtés des bancs #219.
- Les 2 préparations immobilières obsolètes #299 et les **50 copies rehorodatées déjà appliquées sous nom suffixé** du rapport #302 ont été retirées de la branche #219. Les **6 correspondances non prouvées** restent à examiner; les **6 migrations nouvelles** de ce classement qui appartiennent aux 95 sont conservées.
- `20261031230000_organisations_champs_commandes_serveur.sql` est **préparée mais non appliquée** : attendre les contrats #219 et l'autorisation de bascule. La fermeture totale INSERT/UPDATE attend le portage des 16 opérations historiques sans RPC.
- Les outils de certification #302 doivent rejoindre la livraison groupée. Les empreintes du catalogue vivant ne remplacent pas la preuve locale d'installation atomique sur un décor **1012 conforme**. Pas de fusion de #219 en production tant que ce prévol, les gardes et les CI ne sont pas verts.
- Les quatre RPC d'équipements collectifs sont absentes du serveur et hors paquet des 95; ne pas affirmer ce parcours activé. Aucun arbitrage de design n'a été présumé.

### #219 — reprise 01/11 : les six racines de schéma concordent, données statiques encore bloquantes

Reprise de `4dfeda89` sans perdre les apports de l'intégrateur ; main `ddb72dbd` déjà ancêtre. Rapport et preuve réduite : `outils/audits/RECONSTRUCTION-1012-219-20261101.{md,json}`. Clone PostgreSQL **17.6**, métadonnées seules des cinq tables hors monde neuf, restitution exacte de deux CHECK BETWEEN et locale locale explicitement enregistrée : **6/6 familles du schéma concordent**, collecteur/références inchangés. Générateur recettes corrigé (colonne inexistante `type_objet` retirée du seul INSERT SQL). **57/57 outillage** ; globaux **10/12**, Authority 17 contrats et Referential 5 déclarations toujours en échec.

**Le paquet 95 n'a PAS été exécuté sur ce nouveau clone** : sept référentiels conformes, cinq écarts conservés. Les essais des générateurs actuels sont annulés et ne reproduisent pas les données vivantes. Besoin extérieur réduit à quatre tables statiques (18 + 7 + 23 + 52 lignes) ; BNE vide déjà observé. Requête de lecture pour l'intégrateur : `EXPORT-REFERENTIELS-MANQUANTS-219-20261101.md`, résultat à garder hors Git. Supabase direct bloqué par le proxy, aucun connecteur disponible ici ; API commentaires GitHub `Forbidden`. Git reste accessible. Aucun joueur, schéma de production, compte ou secret modifié, aucune fusion/déploiement. Ne pas annoncer la PR livrable tant que 12/12 référentiels, 95 atomiques et recette intégrée sur ce décor ne passent pas.

Vérifications finales de cette reprise : **156/156 bancs clients, 105/105 pilote local, 379/379 groupes/combats sur le décor déclaré, 3/3 mutations de combat détectées** (issue falsifiée, double paiement, PNJ immobile). Premier passage clients 155/156 : pglast manquant dans l’environnement ; second passage complet réussi sans modification de test. Workflow recontrôlé conforme. Correction/preuve initiale poussée `87a735c1`. Aucun de ces succès ne remplace les référentiels manquants ou la recette des 95 sur le clone strict. API GitHub refusée : résultats CI du nouveau SHA non observables ici.

### #219 — suite du 01/11 : transfert privé prêt et fournisseur ICU réel pris en compte

Nouveau relevé transmis par Fred/ChatGPT : 1012 inchangé, quatre tables toujours non transmises, locale `en_US.UTF-8` fournisseur **ICU (`i`)**. Cette précision retire toute équivalence présumée entre le précédent clone libc et la locale réelle, même si ses six racines concordaient. `LOCALE-PRODUCTION-1012.json` consigne la provenance ; locale ICU interne et versions de collation restent à relever.

Chargeur `referentiels-prives-clone-219.py` raccordé au banc 95 : quatre tables uniquement, colonnes complètes, nombre décimal brut conservé par PostgreSQL, registre/locale/empreintes vérifiés, BNE vide attesté, upsert respectant les FK, annulation complète sur erreur et diagnostics sans valeurs privées. Capture hors dépôt obligatoire, aucune importation de joueur. Le garde initial des 12 tables et les 27 HTTP distincts restent obligatoires ; **la locale doit désormais être certifiée avant les 95**. Format et destination privés documentés dans `EXPORT-REFERENTIELS-MANQUANTS-219-20261101.md`.

**63/63 tests explicitement sur PostgreSQL 17.6**, version affichée dans le journal. Rectification de précision : le premier lancement des anciens 57 tests utilisait les binaires par défaut de pgserver (16.2), contrairement à la mention 17.6 de son rapport réduit ; la reconstruction intégrée des six empreintes utilisait bien 17.6. Aucun résultat antérieur n'est promu en preuve supplémentaire. Les nouveaux passages sélectionnent réellement le binaire.

Accès artefacts GitHub essayé une fois : `Forbidden`. Recherche des captures privées/seeds/archives locales : pas des 100 lignes exactes. Nouvelle compilation PostgreSQL 17.6 **avec ICU**, indépendante de l'installation précédente, disponible dans `/workspace/hg-postgresql-17-icu/bin` ; essai de reconstruction candidat en cours, non certifié sans la capture.

### #219 — preuve ICU terminée, 64 tests et qualification des contrôles

Binaire 17.6 ICU installé, candidat `en-US` : **6/6 racines conformes**, mais cinq référentiels toujours différents ; locale interne et version réelles encore non transmises. Rapport : `SUITE-ICU-ET-CAPTURES-219-20261101.{md,json}`. Le drapeau « catalogue certifié » exige désormais les racines **et** les références **et** la locale complète ; il reste faux dans la preuve. **64/64 outillage natif 17.6 ICU**, **10/12 globaux**, composition 95 intacte en une transaction (SHA dans la preuve), mais installation/rollback/rejeu et 27 HTTP NON relancés sur ce clone bloqué. Pas de mise à jour artificielle du baseline.

`PORTES-HISTORIQUES-219-20261101.md` distingue les deux contrats clubs déjà livrés, les 15 formes #219 préparées, le spread de tournée et les helpers anciens fermés/inutilisés. Travail horaire immobilier : appel d'écran encore observé, à coordonner avec Claude après comparaison sur le catalogue installé, aucun droit rouvert. La seule transmission encore nécessaire à l'intégrateur est **un fichier JSON privé** des quatre tables et de la locale complète ; requête, format, destination et chargeur prêts. Aucun compte joueur ni secret demandé. PR non fusionnée, pas de production touchée, pas de déploiement manuel, CI distante non observable via l'API refusée.

### #219 — précision de locale reçue, analyses avant installation renforcées

Nouveau relevé transmis le 01/11 : **ICU en-US, versions stockée/actuelle 153.121**, registre toujours 1012. `LOCALE-PRODUCTION-1012.json` complète ces observations réellement transmises, sans les remplacer par le 153.128 local. Le garde reste strict. Sources officielles ICU 74.2 récupérées pour tenter une reproduction physique, compilation en cours, pas encore une preuve de compatibilité.

Le pilote relève désormais les signatures et droits RPC **avant les 95**, dès les six empreintes de schéma conformes, et examine explicitement les quatre équipements collectifs. Cela permet de poursuivre l'analyse sans installer les migrations sur un décor aux référentiels incomplets. **65/65 outillage PostgreSQL 17.6**, dont une nouvelle contre-épreuve : une capture conforme au moteur local mais contraire à la version externe est refusée sans mutation. **14/14 tests équipements client**, dont le nouvel essai sur le fichier réellement chargé : aucune RPC, aucun paiement ni inventaire modifié tant que le service reste dormant. Le banc de préparation SQL équipements reste **33/33** sur tables fictives ; pas une activation.

Main reste `ddb72dbd`, déjà intégré. Aucun transfert privé des 100 lignes présent au chemin convenu. Aucune écriture production, fusion ni déploiement ; poursuite de la reproduction ICU et du prévol de métadonnées avant rapport final.

### #219 — ICU 153.121 reproduit physiquement ; 9/12 référentiels conformes

Bibliothèque officielle **ICU 74.2** compilée sans modifier ses données ni ses versions ; `ucol_getVersion(en-US)` renvoie `[153,121,0,0]`. PostgreSQL **17.6** lié à cette bibliothèque : fournisseur `i`, `en-US`, versions stockée/actuelle **153.121** ; le garde des six paramètres passe. Cela ne prouve pas que le paquet ICU de production est 74.2, seulement que la version de collation exposée correspond. Aucun REFRESH/UPDATE de version pour obtenir ce résultat. Binaires `/workspace/hg-postgresql-17-icu74/bin`, bibliothèques `/workspace/hg-icu74/lib` (LD_LIBRARY_PATH requis).

Six empreintes de schéma toujours conformes. Source identifiée et registre vérifié : l'unique INSERT statique des paliers communaux reconstitue les **7 lignes exactement conformes**, MD5 intégral `f9ebb4e7734e75b4672df82ed2c9a5b2` ; aucun autre SQL de cette migration historique rejoué. BNE remis à vide **dans le clone seulement**, d'après le relevé zéro inchangé. **9/12 référentiels concordent** ; restent postes nommés (18), constantes (23) et recettes (52). L'essai isolé du salaire minimum donne 23 constantes mais une empreinte différente : il est annulé et n'est pas retenu. Pas d'invention de valeurs.

**66/66 outillage** sur 17.6/ICU exact, **379/379 groupes/combats** sur décor fictif avec moteur mesuré dans le rapport. Sélection de binaire rendue persistante dans le banc commun via `HG219_POSTGRES_BIN`, réutilisant le configurateur existant ; pas de second moteur. Trois mutants en cours de vérification finale. Contrats avant 95 : **472/496 formes compatibles** ; 15 formes préparées, 8 anciens appels fermés et un spread non résolu. Les deux contrats clubs sont présents ; les quatre équipements sont absents sur le schéma conforme. Attention : leur mise en sommeil est préparée dans cette branche, pas démontrée déployée sur main/Vercel (main a encore l'interface antérieure). Les 14 tests client sont locaux ; les 33 cas SQL concernent les préparations isolées.

Aucune des **95 migrations** n'est installée sur ce clone, aucun des **27 HTTP** exécuté sur ce clone : le garde refuse encore les trois référentiels divergents. Transfert privé convenu toujours absent ; conserver le format des quatre tables (100 lignes, dont les sept paliers déjà reconstituables), sans publication dans Git. Pas de modification de production, de fusion ni de déploiement. Rapport final et preuve structurée à suivre après les derniers mutants.

### #219 — fin des opérations accessibles avant le transfert privé

Rapport et preuve finale : `ICU-153121-ET-REFERENTIELS-219-20261101.{md,json}`. **379/379 mixtes** et **3/3 mutants détectés** avec moteur 17.6/ICU 153.121 enregistré par le banc commun, **66/66 outillage**, **14/14 équipements client**, **33/33 préparations équipements SQL**. Globaux **10/12**, paquet 95 toujours intègre (même SHA256). Vérification finale de main : `ddb72dbd`, déjà ancêtre, aucun travail concurrent écrasé.

Le verrou de version ICU est levé, **9/12 référentiels** conformes, seules trois tables divergent. Les sept paliers archivés et BNE vide sont maintenant restaurés dans le clone sous empreintes inchangées. Le fichier privé convenu reste l'unique transfert nécessaire pour poursuivre ; garder son format quatre tables/100 lignes, pas de nouveau compte ni secret ni manipulation SQL de Fred. Les réserves de contrats ne sont pas réputées résolues par sa simple réception. Installation 95 et 27 HTTP sur le clone fidèle **non exécutés**. Pas de fusion, migration réelle, données joueur ni déploiement.

Complément final : la suite d’outillage passe aussi **66/66 sur le PostgreSQL 16.2 fourni par défaut en CI**, en plus de la passe native 17.6/ICU exact. Ces deux preuves sont distinctes. Workflow final conforme ; références générées et critères inchangés.

### #219 — mission 1015 reçue, mais pas la pièce JSON annoncée

Reprise `ce0ab297`, main toujours `ddb72dbd`. La nouvelle pièce contient uniquement la mission (`Texte collé.txt`, 8 121 octets) ; **`referentiels-prives-hg219-1015.json` n'est pas joint ni présent dans l'environnement**. Ne pas prétendre l'avoir lu. Registre 1015 / dernière `20261101113411` annoncé mais trois versions/noms et empreintes fraîches non transmis. Lecture API commentaires : Forbidden. Recherche des branches autorisées en lecture (dont dépendances Claude) : préparations et mentions d'applications, pas de registre 1015 certifié ; aucune intégration de PSM/Montrouge.

Banc adapté aux coupes nouvelles **sans renuméroter 1012** : concordance stricte des trois profils externes schéma/référentiels/locale et du registre local, six familles et douze tables obligatoires, option `--locale-reference`. Compteurs anciens ne deviennent vrais que pour 1012. **71/71 outillage natif 17.6/ICU 153.121** ; contre-épreuves du mélange de coupes et d'une référence incomplète, chargeur privé versionné sur fixtures. Non-régression 1012 : schéma/locale et neuf référentiels toujours conformes, certification complète toujours refusée. Aucun nouveau test de 1015 ni import des 100 lignes annoncé, pas de 95 ou 27 HTTP sur ce nouveau catalogue. Rapport et demande groupée à l'intégrateur : `REPRISE-1015-219-20261101.{md,json}`.

Aucune donnée réelle, migration de production, fusion ou déploiement. Ne pas faire passer les anciens relevés 1012 pour des observations 1015. Pour poursuivre : joindre réellement le JSON et transmettre les métadonnées de la coupe 1015 dans le même paquet privé, sans manipulation SQL de Fred.

Protection de reprise ajoutée : une coupe >1012 doit fournir un prévol frais des tarifs (`lignes`, MD5 complet, sentinelle) ; si le contenu a changé, la réconciliation reste refusée plutôt que de réinjecter silencieusement l’ancienne capture. Tests synthétiques explicites, aucune mesure 1015 inventée.

Vérifications finales de cette adaptation : **71/71** également sur le moteur CI fourni (16.2), Workflow conforme, globaux réexécutés **10/12**, sans mise à jour d’empreinte ni fausse coupe 1015.

### #219 — échec CI 41304385900 reproduit et corrigé localement

Journaux transmis par l'intégrateur après refus de l'API : les quatre cas civils échouaient sur un PNJ de fixture déjà mort ; le cas militaire avait perdu son effectif mixte. Reproduction déterministe obtenue avec le vrai `pnj_mourir` sur le roster fictif avant la suite civile : exactement les quatre échecs signalés, dont `pnj_mort_sans_leader` et `cible_non_referencee`. Trois erreurs reproduites aussi sur 17.6 : ce n'est pas une incompatibilité spécifique au 16.2 du runner. Le round concurrent parent committe des dégâts, alors que `pret` ne préparait pas à nouveau le statut de ses deux propres PNJ.

Correction limitée au banc : nouveau scénario civil = `ancre` et `autre` fictifs vivants/PA réinitialisés ; aucun métier, propriétaire, moteur ou contrainte de production modifié. Les 379 assertions/scénarios existants restent conservés et un 380e vérifie qu'une vraie mort rend toujours le PNJ non ciblable, sans débit, et interdit un leader. **380/380 sur 16.2 et 17.6 ICU 153.121**, même après mort de tout le roster parent. La contre-épreuve `--contre-reset-fixture` réintroduit exactement les quatre échecs sous 17.6. CI exécutera désormais cette précondition défavorable (`--fixture-roster-mort`), pas un scénario simplifié.

Diagnostics renforcés : trace/fichier/ligne des assertions vides, artefact JSON atomique dans l'artefact CI existant, code de sortie en échec conservé. **75/75 outillage natif** ; chaîne locale complète du workflow en cours, étapes après 43 incluses si réalisables.

Fichier privé toujours absent : recherche du SHA-256 attendu `b8998d8b97ff3709ecf5a2df48b7373052a5c5f1d8f61bef4d4cb0ae325adad0` parmi 62 fichiers de pièces/captures accessibles, aucune correspondance. Contrôle SHA obligatoire raccordé au pilote avant import, contre-épreuves sur fixtures. Aucun contenu 1015 reçu ou certifié, aucune des 95 installée sur ce catalogue, aucun 27 HTTP sur ce catalogue. Aucune donnée réelle, fusion ou livraison de production.

### #219 — validation transversale locale après correction CI

Rapport final de cette intervention : `CI-COMBATS-41304385900-219-20261101.{md,json}`. **61/61 étapes exécutables du workflow de PR réussies localement**, dont la suite civile avec roster mort et toutes les étapes auparavant ignorées. Installation/setup/actions GitHub non présentés comme exécutés ici. **380/380 sur 16.2 et 17.6**, **75/75 outillage**, reset retiré = mêmes quatre erreurs, trois mutants moteur toujours détectés, code 1 réellement conservé. Globaux réexécutés **10/12**, références non modifiées. Aucune modification de moteur métier ; correction limitée à la préparation de deux PNJ fictifs et aux diagnostics.

CI distante après push non observée : API toujours Forbidden. Hash privé attendu b8998d8b…325adad0 contrôlé par recherche sur 62 fichiers accessibles, aucun correspondant ; fichier 1015 toujours non reçu. SHA obligatoire ajouté au pilote avant import. Aucun 95/27 sur un clone 1015 prétendu conforme, aucune donnée PJ réelle touchée. Poursuite de la certification strictement conditionnée au transfert privé et aux métadonnées de la bonne coupe, pas à un nouveau compte ou une manipulation SQL de Fred.
