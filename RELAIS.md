
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

### Claude — clôture fonctionnelle de Luthécia, cinq anomalies (branche `claude/cloture-fonctionnelle-luthecia-20261101`, PR #327 vers `main`, CI 142/142 au SHA `dc06b42`, NE PAS FUSIONNER sans l'intégrateur)

Issue de `main` `df67186`. **Corrigé** : interview de Jodie (un double clic sur Envoyer ne lance plus deux rédactions ; une réponse tardive n'écrase plus l'écran ; les réponses survivent à une réouverture). **Déjà conformes, preuves à l'appui** : caisses à l'accueil des bâtiments communaux (#275), fontaine de SLAVA sur place uniquement (serveur + écran), journal des ventes (#96 ; les trois ventes de SLAVA antérieures au 23/10 n'y figurent pas et restent inchangées, décision de Fred du 01/11), multimodal de PSM (destinations nommées, plus d'ordre de Mireille). **F5** : non reproductible sur `main` ; dépendance #219/#318 inscrite comme test en attente. Aucune migration. Nouveaux bancs : `banc-jodie-interview-navigateur.cjs` (5/5, contre-épreuve), `banc-multimodal-psm-20261101.cjs` (4/4), `banc-position-f5-luthecia-20261101.cjs` (4/4 + 1 en attente). Rapport : `outils/audits/CLOTURE-FONCTIONNELLE-LUTHECIA-20261101.md`. Déploiement : écran seul (`plateau-communication.js`).

### Claude — ambassades « Bientôt disponible » (branche `claude/ambassades-bientot-disponible-20261101`)

Décision de Fred (01/11, 19 h 40) : ordres non raccordables visibles et grisés. Naturalisation (mairies, pop-up État civil qui sait désormais lire `bientot`), examen des naturalisations (ministre de l'Intérieur), nouveau « Demander le transfert d'un détenu » grisé dans les trois bureaux d'ambassadeur. Aucune migration, écran seul (`plateau-politique.js`, `data.js`). Banc `banc-ambassades-bientot-20261101.cjs` 4/4 (contre-épreuve 4 échecs). **À tester** : mairie → État civil → « Demander la naturalisation » grisé, un clic n'enlève ni PA ni FR.

### Claude — fonds et murs des commerces (#66), à suivre

Fred (01/11, 19 h 39) : reconstruire #66 depuis `main` (règles du 21/10, PR #71 périmée). Chantier suivant, branche à créer.

### PR #325 — quatre PNG des locaux commerciaux de Port-Sainte-Marie

Branche `fix/psm-quatre-images-commerces-20261101`. Les quatre PNG du ZIP fourni par Fred sont ajoutés sans transformation ; égalité octet pour octet vérifiée après extraction. Les quatre chemins déjà préparés dans `data.js` correspondent aux fichiers grand, moyen, petit et micro. Aucun moteur, prix, superficie ou autre fonctionnalité modifié. Syntaxe de `data.js`, décodage des quatre PNG et raccordements effectifs dans WORLD vérifiés. Contrôleur client : **139/139 bancs réussis**, après mise à disposition des dépendances déjà installées (premier essai incomplet : dépendances absentes). Fusion simulée avec le main récupéré : sans conflit. Contrôles GitHub et fusion encore à vérifier : accès API refusé dans cette session ; requête Vercel également bloquée par le proxy (403), aucun statut de déploiement déduit. Ne pas déclarer la production livrée avant fusion et vérification des ressources Vercel.


Rubrique nettoyée le 31/10 (Claude) : les chantiers livrés sont passés dans « Derniers chantiers » ; l'ancien texte détaillé reste dans l'historique Git de ce fichier (`git log -p RELAIS.md`).

### Migrations fusionnées, en attente d'application (ChatGPT)

**Vérification du registre par Fred (01/11, 18 h 50)** : `20261031130000`, `20261031140000` et `20261031220000` sont **déjà appliquées** ; ne jamais les rejouer. Parcours en jeu encore à constater.

Vérifier toujours une migration par son **NOM** dans `supabase_migrations.schema_migrations`, jamais par son numéro.

- ~~`20261031130000_reliquats_immobilier_accord_tacite_succession`~~ **appliquée** (registre `reliquats_immobilier_accord_tacite_succession_20261031130000`, version `20261031124014`) : accord tacite de nuit (permis de Jean Jaaj, terrain 5) et colonnes `proprietaire` / `coproprietaire` à la succession. Banc : `outils/bancs/banc-reliquats-immobilier.sql`.
- ~~`20261031140000_helvetia_caisse_argent_detenu`~~ **appliquée** (registre `helvetia_caisse_argent_detenu_20261031140000`, version `20261031124019`, #267) : la caisse d'Helvetia représente l'argent détenu. Banc : `outils/bancs/banc-caisse-helvetia.sql`.
- `20261031151000_placement_helvetia_gain_unique` (Claude, 31/10, suite de #267) : à la résolution d'un placement Helvetia, le gain net n'est plus ajouté à `arg` (argent total liquide + Banque nationale, où il apparaissait en double) et entre dans la caisse avec les frais. Indépendante de l'écran ; **déjà appliquée en production** sous le nom de registre `placement_helvetia_gain_unique_20261031151000` (version `20261031131427`, prévol Supabase du 31/10) ; ne pas réappliquer avant l'échéance du 6/11. Banc : `outils/bancs/banc-placement-helvetia.sql` (attendu sur ce placement : caisse +6 314, compte +83 340, `arg` +0).
- `20261029181000_squatteurs_issue_combat` : **attend le combat de groupe de Codex (#219)** ; ne pas appliquer avant.
- ~~`20261031220000_transfert_prime_signature_serveur`~~ **appliquée** (registre `transfert_prime_signature_serveur_20261031220000`, version `20261031211256`). Règle confirmée par Fred le 01/11 (`GAME-DESIGN-FOOTBALL.md`) : prix du transfert au club de départ, prime de signature facultative au joueur, les deux payés par le club qui recrute.
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
- **Prime de signature** : appliquée et confirmée par Fred (01/11, `GAME-DESIGN-FOOTBALL.md`). Saisie ajoutée à l'offre de transfert (01/11, demande de Fred) : champ « Prime de signature au joueur », entier ≥ 0, annoncé au président vendeur et au joueur ; banc `banc-prime-signature-saisie.cjs` 7/7 (contre-épreuve 7 échecs).
- **#299 (garde 13/14 de #219)** : les deux préparations immobilières sont **déjà en production** sous `construction_materiaux_prix_et_dons_94` et `compromis_financement_reel_135`, puis réécrites par `20261030210000` ; leurs gardes d'empreinte échouent contre la production. **Action Codex : supprimer `20261031113610_…` et `20261031113631_…` de #219.** Preuve : `outils/audits/CLASSEMENT-299-20261031.md` ; test `test-preparations-deja-appliquees.mjs` (la garde de la vue n'est pas touchée).
- **Organisations, fin de la double autorité** : inventaire figé par `test-organisations-ecritures-inventaire.mjs` (17 chemins avec commande #219 et repli, 16 sans commande). Étape A **préparée, non appliquée** : `20261031230000_organisations_champs_commandes_serveur` (se refuse sans les contrats #219 et sans feu vert explicite). Étape B (REVOKE INSERT/UPDATE) seulement après portage des 16 chemins. Détail : `outils/audits/ORGANISATIONS-ECRITURES-20261031.md`.

### Décisions attendues de Fred


- Aucune décision en attente au 01/11 au soir (hospitalisation déjà tranchée dans `GAME-DESIGN-HOSPITALISATION.md` ; ambassades et #66 tranchées le 01/11).

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
- `20261031130000` appliquée : à constater, le permis de Jean Jaaj (terrain 5) accordé tacitement à la fin de l'instruction, attestation et courrier reçus.
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
