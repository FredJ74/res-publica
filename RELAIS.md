
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

- **Mairies des trois villes (Claude, 29/10, branche `claude/mairies-communes-20261029`, contient #243)** : décisions de Fred.
  - **Communs aux trois villes :** calendrier électoral, objets trouvés, demande d'acte officiel, résumés des mandats aux archives (bilans réels de la ville consultée ; la recherche historique de l'énigme reste à Luthécia).
  - **Retirés de Montrouge et PSM :** « Corrompre un employé », plus les vestiges « Postuler à un poste » et « Gérer les finances locales ».
  - **Logement social :** la demande est présente dans les trois mairies ; hors Montrouge, elle affiche « Il n'y a pas de logements sociaux dans la ville. » sans rien prélever.
  - **Bancs :** `banc-mairies-communes.cjs` (11 tests), `banc-nominations-municipales` mis à jour.
- **Terrain acheté par la commune (Claude, 29/10, branche `claude/mairie-acquereur-20261029`, contient #244 et #243)** : décision de Fred, « une mairie suit le même cheminement qu'un PJ particulier ».
  - **Question posée au maire :** au dépôt comme au compromis, dans sa ville, on lui demande s'il achète au titre de maire pour la commune ou en son nom propre.
  - **Achat pour la commune :** le serveur exige le maire élu de la ville du terrain, et refuse tout prêt. Le dépôt et le solde sont pris dans la caisse de la mairie (`salaire_caisse_de`). Le titre est `ville:<pays>:<ville>`, sans copropriétaire, et à l'acte le signataire doit encore être maire.
  - **Migration `20261029210000` (non appliquée, compatible) :** elle corrige au passage la caisse de Luthécia dans le moteur de chantier (`republic_mairie-capitale`).
  - **Répétition annulée sur le terrain 4 de Luthécia :** caisse 115 508 → 114 508 au dépôt, puis → 93 308 à l'acte ; francs du maire inchangés.
  - **Banc :** `banc-mairie-acquereur.cjs` (9 tests).
- **Logements sociaux communaux, socle (Claude, 29/10, branche `claude/logements-sociaux-20261029`, contient #246, #244 et #243)** : décisions de Fred.
  - **Trois bâtiments, réservés aux terrains de la commune :** petit (4 appartements, 12 j, 60 000 FR), moyen (6, 18 j, 90 000 FR, 2 000 m² et plus), barre (10, 24 j, 120 000 FR, plus de 2 200 m²). On peut toujours construire plus petit.
  - **Appartements :** générés à la réception, comme à Montrouge : moitié petits (30 FR, +3 moral / +4 santé), moitié grands (60 FR, +5 / +7). Les loyers vont à la caisse de la mairie (`recette_municipale`).
  - **Demande :** dans les trois mairies (résident, 1 PA, une seule en attente). Sans logements dans la ville : « Il n'y a pas de logements sociaux dans la ville. »
  - **Adjoint au maire :** son tableau de bord sert à attribuer un appartement (premier loyer payé par le bénéficiaire, courrier) et à fixer le loyer de chaque appartement. Un bail en cours est mis à jour, et chaque changement est inscrit dans l'historique du bâtiment. Le joueur ne loue jamais lui-même un logement social, et le titulaire des murs n'en fixe pas le loyer.
  - **Le maire élu** dépose le permis d'un terrain de la commune (titulaire_est_moi ne reconnaît jamais une commune).
  - **Migration `20261029220000`** (non appliquée, compatible, **après 210000**). Répétée à blanc sur le terrain 4 : 14 cas plus l'offre dans les trois villes.
  - **Banc :** `banc-logements-sociaux.cjs` (17 tests).
  - **Au passage :** le PNJ Commissaire Charbon est retiré du bureau de Montrouge, faute de profil de dialogue.
  - **Permis d'un terrain de la commune (décision de Fred) :** les 100 FR sont payés par la caisse de la mairie, le maire ne dépense que son PA ; si la caisse est insuffisante, rien n'est prélevé. Migration `20261029222000` (non appliquée, après 220000).
  - **Domiciliés seulement (décision de Fred, socle) :** dès que le domicile officiel change de ville, les baux sociaux hors de la nouvelle ville sont résiliés au serveur (déclencheur sur `personnages_donnees`), l'appartement est libéré et la résiliation historisée, avec un courrier ; l'adjoint ne peut plus attribuer à un non-résident. Migration `20261029223000` (non appliquée, après 220000).
  - **Restent à décider ou à faire :** les quatre appartements historiques de Montrouge gardent leur loyer fixe.

- **Commissariats de Montrouge et PSM (Claude, 29/10, branche `claude/commissariats-pouvoirs-20261029`)** : décision de Fred, « chaque commissaire dispose des mêmes pouvoirs ». Le gabarit `commissariat-local` reçoit les ordres de Luthécia : archives et arrestation d'urgence à l'accueil ; bureau du commissaire avec dossiers de plainte, enquête, filature, chasse à l'homme et commandement des effectifs. Les écrans et les portes serveur étaient déjà bornés à la ville du commissaire. Plainte rejouée dans les trois villes. PSM et Montrouge ne gardent que leur habillage. Banc : `banc-commissariats-pouvoirs.cjs`. Migration `20261029203500` (non appliquée, compatible) : le commissariat, le tribunal et la banque des villes deviennent des bâtiments sensibles pour l'incendie et les explosifs, comme à Luthécia.

- **Écritures de l'écran (Claude, 29/10, branche `claude/ecritures-ecran-20261029`)** : migration `20261029200000` préparée, non appliquée et compatible avec l'écran en ligne. Elle garde `prets` et `budgets_municipaux`. Mariage par le serveur (Fred : pas de mariage contre son gré) : `201000` tout de suite, `201100` après déploiement de l'écran. Restent ouverts et signalés : `budgets_clubs` et `organisations.caisse` (Codex), `budgets_nationaux`, `quetes_actives`. Bilan : `outils/bancs/ECRITURES-ECRAN-20261029.md`.

### Centres des trois villes et location par le serveur — Claude 29/10 soir (branche `claude/centres-villes-20261029`)

Mission de Fred : généraliser les raccordements métier à Montrouge et PSM, fermer les vestiges. **Constat** : les centres commercial, artisanal et d'affaires des trois villes utilisent UN gabarit (`BUILDINGS`) ; les villes ne surchargent que nom et images (banc). Les 11 fonctions serveur du commerce (fonds, références, production, vente, sur place, Premium, loyers) n'ont aucune ville en dur.

**Défaut reproduit (toutes villes)** : le bail d'un local à loyer fixe (centres, suites de La Republica, coffre) était écrit par l'écran ; un joueur absent de Montrouge s'est inscrit locataire de la Vitrine Principale à 1 FR/jour, +99 POP/INF, sans premier loyer. **Correctif** (`20261029190000`, PRÊTE, NON APPLIQUÉE — application par ChatGPT, compatible avec l'écran en ligne) : référentiel `locaux_loyers_referentiel` (équivalence avec data.js prouvée par `banc-locaux-loyers.cjs`), porte `local_louer` (lieu réel, local libre, organisation dont on est membre, 1 PA, premier loyer par `prelever_loyer_bail`, reçu), garde immédiate imposant prix et bonus du référentiel aux baux écrits par l'écran (box portuaire compris, 15 FR). Écran : `confirmerLocation` appelle `local_louer` ; rafraîchissement des ordres Premium après chargement des baux généralisé (était réservé au centre commercial de PSM). **Après livraison** : `20261029190100` (l'écran ne crée plus ces baux ; box exclu).
Répétition à blanc : hall refusé ; fonds insuffisants sans PA ni bail ; Montrouge vitrine 800 FR + organisation + reçu ; local occupé ; organisation d'autrui refusée ; PSM bureau prestige 1 000 FR ; open space de Luthécia refusé, poste B accepté ; bail forgé ramené au tarif ; box forgé ramené à 15 FR ; après fermeture, échoppe écrite par l'écran refusée.
**À vérifier en jeu** : louer un local dans chaque centre de Montrouge et de PSM, installer un commerce dans un local commercial ou artisanal, ouvrir l'Option Commerce (décoration) en titulaire, vérifier qu'un autre joueur ne la voit pas.


### Terrains, parcours immobilier, prêts, placements — Claude 29/10 (branche `claude/terrains-immobilier-20261029`)

Mission confiée par Fred le 29/10 (plan ChatGPT « finir Luthécia d'ici dimanche ») : **Claude reprend les terrains et le parcours immobilier** (cédés par Codex), plus prêts et placements. Codex garde le socle universel (déplacements, détection, combats, inventaire #213, groupes #219, sécurité privée).

**Méthode** : parcours rejoués sur la vraie base, au rôle authenticated, en transactions annulées (Arnie, Jean Jaaj ; aucun joueur réel modifié) : achat direct, compromis + prêt + permis, permis et accord tacite, chantiers hangar et commerce premium jour par jour, plan des lots au dernier tiers, réception, location, loyer de nuit, prêts consommation/travaux, placements.

**Fonctionne déjà** : achat direct et acte notarié, compromis avec prêt et permis joints, dépôt de permis (100 FR + 1 PA) et accord tacite, lancement, appels de fonds 35/70/100 %, journées de chantier, plan au dernier tiers, réception, location d'un lot, prêts nationaux, occupation des terrains redessinée à chaque visite, négociation.

**Défauts reproduits et corrigés (migrations APPLIQUÉES, compatibles avec l'écran en ligne)** :
- `20261029094119` : on pouvait **lancer un chantier avec un permis encore en instruction** (terrains 1-3 gardaient `constructionAutorisee` d'anciens essais) → lancement exige un permis `valide`, reliquat remis à faux. **Les lots nés du plan valaient 0 FR et rien ne permettait de fixer leur loyer** → porte `terrain_lot_loyer_fixer` (titulaire des murs, lot libre), un lot sans loyer ne se loue plus (`loyer_non_fixe`). **Toute location à loyer positif échouait** : `prelever_loyer_bail` créditait le propriétaire par la vue `personnages` (refus « personnage_non_possede » quand le locataire signe) → écrit la table.
- `20261029094135` : **rendement des placements dicté par l'écran** (intelligence et ville envoyées → +12 % garantis avec une intelligence forgée) → lues sur la fiche ; ancienne `creer_placement_national` fermée aux joueurs.
- `20261029094215` : **impossible d'avoir deux placements** malgré la règle #86 (index unique resté en base) → index retiré.
- `20261029095142` : **« Accélérer le rendez-vous (corruption) »** : l'écran envoyait la nouvelle date et payait à part → porte `terrain_rdv_notaire_accelerer` (paiement 2 PA + 800 FR, date calculée par le serveur, reçu).

**Écran (branche, non fusionnée)** : « Information sur les locaux » permet au titulaire de fixer le loyer de chaque lot libre ; la liste « Louer un lot » n'affiche que les lots à loyer fixé ; l'accélération du rendez-vous appelle la porte serveur. Caches : `plateau-politique.js`, `plateau-justice-economie.js`, `plateau-pnj.js` → `?v=terrains-20261029`. Banc `banc-etat-terrain.js` mis à jour (43/43). Bancs clients : mêmes 19 échecs d'environnement que main (dépendances npm indisponibles ici), aucun nouveau.

- `20261029122342` : **« Corrompre un fonctionnaire (accélérer) » le permis** : l'écran envoyait le permis entier ; un demandeur pouvait se poser lui-même `statut: valide` ou une instruction d'un jour, sans payer (reproduit) → porte `terrain_permis_corrompre` (2 PA + 800 FR, découverte 25 % tirée par le serveur avec détection pénale commune, durée divisée par deux sur le dossier enregistré). Écran raccordé.

- `20261029122748` : **décision du maire adjoint sur un permis** : l'acte fusionnait le permis entier envoyé par l'écran (palier, demandeur, durées modifiables), l'écran archivait et écrivait le courrier → porte `terrain_permis_decider` (décision + motif seulement ; statut, archive, arrêté remis, courrier et 1 PA dans une transaction). Éprouvé : refus à un non-adjoint, motif court refusé, dossier tranché une seule fois, lancement possible après accord. Écran raccordé.
- Le maire constate encore : aucune autre écriture cliente sur le permis n'est restée ouverte hors `permis_plan_modifier` (plan, autorité vérifiée).

**Réorganisation payante des lots (29/10 soir) : VALIDÉE**, essai annulé sur la base réelle : 10 FR/m² touché (200 m² → 2 000 FR = 600 matériaux + 1 400 travail), débit unique et atomique (banque puis espèces), refus nommés (fonds insuffisants, lot loué touché `local_occupe`, surface du terrain dépassée et lot sous le minimum `plan_invalide`, simple renommage `aucun_changement`, second réaménagement, construction ou loyer pendant les travaux), réception requise, nouveau découpage persistant, lot loué et son bail intacts. Ancienne porte `terrain_reamenagement_poser` déjà fermée. Aucun défaut.

**PRÊTES, NON APPLIQUÉES (à appliquer par ChatGPT, consigne de Fred du 29/10) :**
- `20261029180000` — **à appliquer tout de suite** (compatible avec l'écran en ligne) : raccorde les anciens actes `achat_direct_accelerer` et `permis_accelerer` à la règle serveur (plus de date ni de dossier venant de l'écran, délai enregistré divisé par deux, une seule fois, dossier du seul demandeur). Répétée à blanc : date forgée ignorée (48 h → 24 h, prix intact), permis « valide » forgé ignoré (7 → 3 jours, statut et palier intacts), second essai `deja_accelere`, autre joueur `pas_mon_dossier`.
- `20261029181000` — raccordement immobilier du **combat des squatteurs** : `terrain_squatteurs_issue_interne(terrain, acteur, issue, requete)`, serveur seulement, appelée par le moteur commun de Codex. **CONTRAT (Fred, 29/10) : l'issue réelle du combat remplace définitivement le score final de 0 à 100** — `defaite` (rien ne change), `neutralises` (terrain libéré, délit **agression** : 25 %, 1 j, 500 FR), `tues` (cadavres laissés, requalification en **meurtre** : 25 %, 2 j, 1 500 FR). Le combat ne cesse que lorsqu'un des deux camps tombe à 0 PA. Reçu idempotent. **Dépend de Codex** : la résolution d'un combat collectif PJ (+ gros bras) contre un groupe de PNJ rendant cette issue.

**État d'intégration (29/10, 19 h)** : #233 et #234 à jour avec main (#238 inclus et intact : aucun écart sur ses fichiers ; seul conflit `plateau.html`, cache de `plateau-justice-economie.js` renouvelé en `terrains-psm-20261029`). #231 : fiches PNJ et Jodie **déjà livrées par #232**, la PR ne porte plus qu'une note de relais → à fermer. Bancs ciblés : `banc-etat-terrain` 43/43, `banc-dialogue-pnj-republia` 43/43.

**À appliquer JUSTE APRÈS la livraison de cette branche** : `20261029160000` (ferme les anciens actes `achat_direct_accelerer`, `permis_accelerer` et `permis_decider`). Répétées à blanc : OK.

**Constats non corrigés (à arbitrer ou à raccorder)** :
- **#224 loyers non prélevés** : cause trouvée. Au passage à l'heure d'hiver (25/10), le cron Vercel est resté sur `0 22 * * *` UTC = 23 h à Paris : les passes des 26 et 27 ont tourné une heure AVANT minuit, et la journée du 28 n'a eu **aucune passe** (cron_journal : 25, 26, 27, 29). Le réglage est déjà rattrapé (`0 23 * * *`, commit 3a9b0c5). Pas de rattrapage rétroactif sans accord de Fred. Fragilité restante (transversal, ChatGPT) : une passe lancée avant minuit Paris se compte pour la veille.
- **Prêt immobilier national débloqué trop tôt** (règle #57-11 : versement seulement à la signature) : CORRIGÉ par `20261029121752` (appliquée) — l'échéance du compromis n'accorde plus que le statut, le prêt est créé et versé dans la transaction de l'acte notarié. Éprouvé : aucun prêt à l'accord, prêt de 60 000 FR créé et acte payé à la signature.
- **Neutralisation des squatteurs par le combat** (#57-5) : pas d'ordre ; dépend du combat commun (Codex). Les trois actions validées de « Gestion des intrus » (négocier, police, cadavre) existent.
- **Matériaux** : un commerce premium ou un immeuble consomme 33 métal/jour ; l'entrepôt de Luthécia en tient 200 et se réapprovisionne la nuit. Deux chantiers simultanés peuvent manquer de matériaux : **décision de Fred (29/10) : courrier au maître d'ouvrage**, comme pour le manque d'argent — fait par `20261029122005` (appliquée, un courrier par arrêt, marqueur retiré à la reprise).
- Le maire décide d'un permis avec un statut envoyé par l'écran (`terrain_permis_acte('permis_decider')`), autorité vérifiée mais contenu client : à passer au serveur.

**Parcours à vérifier en jeu** (Fred, Angie, Vince) : acheter un terrain (dépôt puis notaire), y déposer un permis à la mairie et vérifier que « Construire » reste refusé tant que le permis n'est pas accordé ; après réception d'un commerce premium, fixer le loyer d'un lot dans « Information sur les locaux », le faire louer par un autre joueur et vérifier le crédit du loyer ; souscrire deux placements à la Banque nationale ; accélérer un rendez-vous chez le notaire.


### Vérification commerces, électronique, premium, ventes, presse, PNJ, douanes — Claude 29/10 (branche `claude/verif-luthecia-20261029`)

Suite de la mission du 29/10 (le premier bloc, terrains/immobilier/prêts/placements, est sur `claude/terrains-immobilier-20261029`, PR #233). Même méthode : parcours rejoués sur la vraie base au rôle authenticated, en transactions annulées (Angie, Arnie, Jean Jaaj ; rien de conservé). **Piège de test** : sans `request.path` = `/rpc/...`, le garde `inventaire_revision_garder` annule toute écriture d'inventaire faite au rôle authenticated ; ce n'est pas un défaut du jeu.

**Défaut reproduit et corrigé (migration APPLIQUÉE, compatible avec l'écran en ligne)** : `20261029095808` — dans un commerce de joueur, **« Consommer sur place » refusait toute boisson, tout encas servi, tout plat et tout menu** (`generique_regime_indetermine` : le moteur d'achat commun refuse les génériques ni individualisés ni empilables, c'est-à-dire toute la restauration servie). La « Dégustation à notre fontaine de chocolat » d'Angie (sur place uniquement) ne se vendait donc pas du tout. Corrigé par un drapeau de transaction posé par la consommation sur place ; l'achat à emporter de ces génériques reste refusé.

**Vérifié, fonctionne** : achat à emporter (prix, taxes locale et nationale, caisse du commerce au net, livraison en « objets à recevoir », stock), consommation sur place des produits à emporter (effets PV/moral), refus de l'achat à emporter d'un produit « sur place uniquement », journal des ventes (bonne identité acheteur/enseigne/article/prix, réservé au propriétaire), production des références (refus de dépassement du stock maximum), chaîne électronique complète (composants → ordinateur et téléphone, prix plafonné au coût de revient, vente), plafonds premium de la bêta (3 types / 10 références pour tous), achat à l'entrepôt et vente directe d'usine.

**Presse (#221)** : même cause que les loyers (#224) — au passage à l'heure d'hiver la passe de minuit tournait à 23 h ; aucune passe, donc aucune édition, pour la journée du 28. Éditions du 29 présentes. Réglage déjà rattrapé.

**PNJ** : Marcel Silo, Bernard Piluler et Jean Bonde ont leur fiche (PR #231, empilée sur #227). Restent muets hors Luthécia : Yvon Paletier, Norbert Charton, deux avocats commis d'office.

**Douanes** : portes vérifiées gardées (paie des douaniers et convocations réservées au Chef des Douanes en exercice, ou au serveur). Le voyage entre empires n'existe pas encore (décision : raccordé avec les autres empires).

**Parcours à vérifier en jeu** : chez SLAVA (Angie), consommer la fontaine de chocolat et un chocolat chaud sur place, acheter un ballotin à emporter et le retrouver dans les objets à recevoir ; Angie consulte son journal des ventes.


### Stabilisation Luthécia cinq points — ChatGPT 28/10

- **Connexion/création PJ (nouveau correctif) :** dans `sbCreerPersonnageUnique`, un rejet réseau de `fetch` pouvait remonter comme exception non gérée plutôt que réponse métier. Gestion explicite `creation_incertaine`, sans rejeu d'INSERT (il peut avoir été effectué). Quatre scénarios sur fonction réelle ajoutés dans `banc-creation-personnage-reseau-20261028.cjs`, raccordés au workflow client. Vérification CI en attente à ce stade ; aucun compte réel touché.


- **CI du nouveau banc navigation :** `coherence-client.yml` lance désormais explicitement `node outils/bancs/banc-sortie-reponse-perdue-20261028.cjs` (commit `c0365a6`). Workflow GitHub #40725306741 déclenché, état initial `pending` ; ne pas présenter le banc comme réussi avant conclusion. Aucun déploiement ni donnée joueur modifiée.


- **Navigation (nouveau banc) :** corps vivants `rue_position_enregistrer`, `rue_position_lire`, `rue_sortie_batiment_lire` relus en lecture seule ; banc `banc-sortie-reponse-perdue-20261028.cjs` poussé commit `4fa955f` pour vérifier réponse perdue sans double mutation. Exécution CI du nouveau banc non encore confirmée ; recette authentifiée toujours à faire.


- **Nouveau rapprochement vivant banque, 28/10 :** `fonds_credits_uniques` enregistre une régularisation de 100 000 FR pour le prêt travaux de Jean Jaaj, le 18/10 à 20:27 UTC (`pret-1792353270892`). Un deuxième prêt de 10 000 FR existe aussi, distinct. Les soldes actuels ne prouvent pas le crédit initial ou son affichage. **Ne pas régulariser une seconde fois** ; audit dans `PREVOL-CINQ-POINTS-LUTHECIA-20261028.md`, commit `358aedb`. Aucun solde modifié.

- **Complément vérifié CI / banque (commit `fe952ac`) :** cinq workflows PR #218 au vert ; le journal confirme `OK banc-reception-rest-20261028.cjs`. Prêt travaux national de Jean Jaaj de 100 000 FR présent dans Supabase, restant 76 997 FR, deux comptes distincts ; versement initial non démontré. Rapport prévol enrichi. Aucune écriture en base ni déploiement.

- Branche isolée `chatgpt/fiabilisation-luthecia-20261028` issue de main, hors inventaire et groupes. Audit détaillé `outils/audits/PREVOL-CINQ-POINTS-LUTHECIA-20261028.md`.
- **Navigation :** sortie serveur `rue_sortie_batiment_lire` / `rue_position_enregistrer` vérifiée ; zéro noeud de sortie orphelin sur 36 sorties Luthécia, 33 PSM, 41 Montrouge. Les sorties manquantes et cas d'écran bloqué restent à tester authentifié.
- **Réception :** le transport REST transformait un HTTP 200 à JSON illisible en succès `donnees:true` ; correction dans `supabase.js` : `reponse_invalide`, pas de réessai aveugle d'écriture ; 204 conservé. Banc isolé `banc-reception-rest-20261028.cjs` ajouté, non exécuté ici. La panne remontée par les joueurs n'est pas déclarée résolue.
- **Banque :** contrôle agrégé, 2 prêts, 3 placements, aucun montant négatif ; versements / écarts de solde pas encore rapprochés. **Vercel :** production `READY` sur main `3a9b0c5d`, les previews Codex ne sont pas la production. Contrôle SQL réutilisable `banc-luthecia-controle-navigation-banque-20261028.sql` exécuté en lecture seule.
- **Recette générale** : priorités et défauts restants inscrits dans le rapport. Aucune migration ni déploiement production ; aucun personnage modifié.


### Fiabilisation GitHub / Vercel — 28/10, Codex

- **Complément demandé par Fred après création manuelle de la PR : Workflow corrigé.** Deux doublons SQL supprimés au profit des fixtures existantes `banc-fixture-*` (mêmes corps), trois sources déplacées octet pour octet dans `historique/fixtures-bancs/`, quatre bancs Python raccordés. Aucun SQL métier ni inventaire modifié. Le vérificateur `verifier-workflow.py` reste strictement inchangé ; les neuf familles passent. Nouveau banc de rangement : six tests dont trois refus explicites des mauvais rangements/enveloppes. PostgreSQL jetable : permis 56, Céd/football 45, construction 62 (et variante #112 : 62), banque 61 (et variante location : 61), parcours cinq terrains 324. Les variantes partagent leurs assertions : ne pas additionner comme des cas distincts. Contrôleur client complet après rangement : **107/107 bancs réussis**. Aucun accès production ni migration appliquée.

- Branche isolée **`codex/fiabilisation-ci-20261028`**, issue du main `da5ecc0`. Aucun fichier du jeu, de l'inventaire, des ambassades/BNE ou aucune migration modifié. L'inventaire reste confié à Claude ; Fred a ensuite autorisé explicitement la correction du seul rangement des cinq fixtures SQL (28/10), sans toucher à l'inventaire.
- Défaut reproduit du contrôleur : enfant encore actif après expiration du délai, diagnostics partiels jetés. Correction de l'arrêt du groupe privé, journaux conservés après timeout, distinction lancement/timeout/assertion et résultats JSON progressifs avec état complet/interrompu ; TERM nettoie aussi. Aucun verrou métier ni délai assoupli.
- Deux workflows coûteux rejoignent la politique existante d'annulation des seules anciennes exécutions d'une même PR (parcours immobilier et placements). Tests et noms de contrôles conservés ; main n'est pas annulé. Configuration distante et `vercel.json` inchangés.
- Vérifié localement : **106/106 bancs** avec le lanceur Linux du dépôt sans adaptateur externe ; **105/105 pilote local**, **7 régressions Python**, **24 tests ciblés**, **3 mutants détectés**, **3 passages Chromium (27/27 scénarios)**, **11 tests calendrier/placements**, **23 API** syntaxiquement valides ; payload **256,5/330 Mo**, 12 YAML analysés. Les comptes se recouvrent, ne pas les additionner.
- Rapport et preuves : `outils/vercel/FIABILISATION-20261028.md`, `outils/vercel/preuves-20261028/`. API GitHub runs/PR refusée ; HTTPS Vercel refusé par le proxy. Pas de résultat distant observé, pas de fusion/déploiement demandé ni effectué. Code et preuves poussés au commit `7777b42`. Création de PR réellement tentée après push : GraphQL `Forbidden`, aucun numéro créé. Branche prête pour revue, non fusionnée.


### Sécurité privée #135 — arbitrages du 27/10 (ChatGPT)

- Fred confirme : **seulement deux socles**, embauche/déplacement des PNJ et mécanique policière (malus actes illégaux, détection, interpellation, prison). « Vigile de chantier » est cosmétique. **Aucune affectation au chantier**, aucun moteur/table d'affectation propre aux vigiles. Le PJ employeur déplace librement son PNJ. En cas d'interpellation réussie, mécanisme carcéral policier existant et message RP « remis à la police, conduit en prison ».
- `AGENTS.md` a été corrigé pour lever l'ancien arbitrage contradictoire. La PR #196 `codex/vigiles-vol-135-20261027` est **ouverte, non fusionnable en l'état** : elle ajoute `chantier_vigiles_affectations` et un moteur privé de détection, en contradiction avec cette décision ; ne pas appliquer ses migrations.
- Vérification réelle Supabase en lecture seule : `pnj_position_effective(text)`, `police_detection_verifier(text,text,text)`, `combat_coup_resoudre(numeric,numeric,numeric,integer,integer)` existent. `police_detection_verifier` lit les effectifs policiers de `batiments_etat` ; il faut factoriser/utiliser son algorithme commun pour les agents PNJ sans faux policiers, sans nouvelle mécanique parallèle. Préserver les règles serveur de détection, les gardes anti-relance et le parcours d'incarcération.
- Codex traite actuellement **l'inventaire**, y compris le vol de matériaux ; ne pas toucher à ces fichiers ni aux migrations objets. Préparer séparément le raccordement de sécurité passive et la détection/interpellation avec tests en transaction annulée (`authenticated`), puis déployer seulement après tests complets.


### #135 — Recette de clôture du 27 octobre

- Branche `codex/cloture-immobilier-135-20261027`, issue de main `74128ee` : #174/#175/#178/#188 conservées, aucun ancien correctif réimporté. Aucun fichier métier ambassades/BNE ni socle transversal de Claude modifié.
- Défaut réel corrigé : `confirmerVolMateriaux` réaffectait une constante après réponse serveur. Quantité demandée distincte de la quantité accordée ; quatre tests réels sur fixtures dont contre-épreuve de l'exception, version du script actualisée.
- 105/105 pilote, 105/105 bancs clients, navigation 60/60 (incluse), occupation 30, négociation 59, permis 56, cinq parcours 324 + banque 61, progression/salaire 62+15, matériaux conformes. Assemblage des cinq parcours complété du taux horaire actuel. Trois mutants SQL détectés, preuves archivées.
- Globaux 4/12, résultats identiques au main courant : aucun contrôle maquillé. Le vol demeure un circuit historique non entièrement atomique et le raccordement des vigiles aux affectations/détection/combat communs n'est pas démontré ; ne pas déclarer ce volet fini.
- Audit du 26 : cinquième connexion Arnie et position initiale confirmées en lecture seule, résultat archivé, pas réexécuté ici. API GitHub Forbidden, HTTPS Vercel refusé par proxy, aucun outil Supabase exposé. Aucun joueur déplacé et aucune migration appliquée.
- Correctif et preuves poussés : `736ab07`. Tentative de PR en brouillon refusée par GraphQL (`Forbidden`), aucun numéro créé ni fusion.
- Rapport et preuves : `outils/audits/CLOTURE-IMMOBILIER-135-20261027.md`. PR/intégration/déploiement à vérifier par accès technique ; #135 reste ouvert. Intervention unique : fournir ces accès à une session exécutante, sans manipulation SQL ni compte/secret à recréer par Fred.


**Ambassades et Bureau de l'Emploi : chantiers de Claude seul** (Fred, 25/10). Ces
notes sont la trace du travail, pour reprendre l'historique. **Codex : ne pas toucher aux
ambassades ni au Bureau de l'Emploi.**
- **Nuit du 26 au 27/10 (Claude)** : `CONSTITUTION.md` et `ARCHITECTURE.md` ajoutés (à lire,
  `AGENTS.md` y renvoie ; tenir `ARCHITECTURE.md` à jour). Fusionnés : ordre générique par le
  serveur (`ordre_generique_executer`) ; couvre-feu et recherche militaire dans la passe de nuit
  (`minuit_couvre_feu_recherche`) ; code mort supprimé ; inventaire vérifié. Matin du 27 : objets
  abandonnés par le serveur (`20261027030000`) ; carrière religieuse de Républia par le serveur
  (`religion_agir`, `20261027040000`/`040100`) — `titulaires_pnj` et `contributions_piete` ne sont
  plus écrites par les joueurs. **Codex : pour la popularité ou l'influence rendues par une RPC,
  utiliser `adopterJaugeServeur('pop'|'inf', valeur)`, jamais `state.pop = v.pop`** (double
  comptage à la sauvegarde suivante). **Bancs SQL : se placer au rôle `authenticated`** (`set_config('role','authenticated',true)`),
  sinon `est_appel_serveur()` est vrai et masque les défauts (c'est ainsi que l'annulation des
  gains de popularité écrits par le serveur est passée inaperçue ; corrigé, `20261027050000`).
  Démenti et rumeurs politiques par le serveur (`dementi_executer`, `20261027060000`). **Scrutins fermés aux joueurs** (`cycles_electoraux`) : engendrement, dissolution et
  contestation par le serveur (`20261027070000`/`070100`) ; la passe de nuit pose
  `cycle.dernierScrutin` à chaque proclamation (ne pas le retirer : la contestation en dépend). Fraudes électorales par le serveur (`fraude_electorale_tenter`, `20261027080000`). Vote de confiance par le serveur (`20261027090000`). **Justice** (`20261027100000`-`100200`) : `recherche_retirer` refuse le retrait libre (seulement
  juste après un écrou, ou désertion éteinte) — **Codex : tout nouveau retrait de motif passe par
  une fonction serveur qui sait pourquoi** ; `enquete_garde_a_vue` n'est plus appelable ;
  convocations tenues par le serveur (`convocation_se_justifier`, `minuit_convocations`). **Crime** (`20261027110000`/`110100`) : socle pénal serveur (détection, trace, découverte de nuit) ; neutraliser, incendier, explosifs par le serveur ; `impact_deposer('hp_set')` refusé et `batiments_fermes` fermée aux joueurs — **Codex : un dégât ou une fermeture se pose dans la fonction serveur de l'acte**. Vol et empoisonnement par le serveur (`crime_voler`, `crime_empoisonner`, `20261027120000`/`120100`) ; `vols_en_attente` n'est plus écrite par les joueurs. Détection des ordres illégaux, corruptions, contrebande et falsification par le serveur (`20261027130000`) — **Codex : un nouvel acte illégal tire sa détection dans sa fonction serveur (`crime_detecter_interne`), jamais par `checkDetection` à l'écran**. Scandale de la nuit par le serveur (`minuit_scandale`, cron). **Codex : une réponse serveur qui change l'inventaire rend `inventory` et `revision`, et l'écran adopte la réponse elle-même (`sbAdopterInventaireServeur(v)`)**. Informateurs par le serveur (`informateur_recruter`/`_interroger`/`_congedier`, `minuit_informateurs` au cron) ; la colonne `informateurs` n'est plus écrite par l'écran ; interroger coûte 1 PA (Fred). Marché noir (armes, explosifs) et suites de la neutralisation d'un député par le serveur. **Codex : `corrompre_fonctionnaire_permis` (terrains) et le hooliganisme (organisations) écrivent encore leur trace de crime à l'écran ; à passer par `crime_tracer_interne` dans vos chantiers, après quoi la découverte cliente (`verifierDecouverteCrimesPasses`) pourra disparaître.** Rumeurs : `rumeur_lancer` ; les causes `rumeur_pj`/`rumeur_gouvernement` sont fermées aux joueurs. **Attention : `inventaire_sauver_revision` accepte encore tout inventaire du navigateur (voir l'audit) ; tout nouvel objet doit être déposé par le serveur.** **Chantier inventaire EN COURS (Claude, Fred : « Oui, maintenant », 27/10)** : lots 1 à 3 fusionnés (achats d'armes, gilet, poisons, relique, récolte, produits du marché, tracts ; dépôt serveur unique `inventaire_deposer_interne`, catalogue `objets_modeles`). Reste à faire, dans l'ordre : sels d'ammoniaque (`confirmerAcheterSels`, caisse `pays_usine-pharmaceutique-luthecia`), objets trouvés (`reclamerObjetTrouve`), fret (4 sites de `plateau-justice-economie.js`), employés (`plateau-multijoueur.js`), état civil, énigmes, missions de PNJ et escort, effort de guerre, acte d'entreprise et publications ; documents d'urbanisme et vol de matériaux (terrains), récompenses de quête et accessoires de club (organisations, championnat) = **Codex** ; puis, en dernier, le verrou : `inventaire_sauver_revision` ne doit plus accepter d'ajout venu du navigateur. Liste des sites : `grep -n "addToInventory(\|inventory.push(" plateau-*.js`.
- **Corrections « une seule vérité » (Fred, 26/10 : « fais dans l'ordre que tu veux »)** — Claude.
  Fait : caisses adossées (`fonds_en_transit`, `batiment_caisse_client_crediter`, primitives de
  caisse retirées au navigateur, `usine_virer_vers_ministere`, `ministere_virer_vers_usine`,
  `imprimerie_acheter_bois`). **Codex : tout nouveau crédit de caisse se fait dans la fonction
  serveur de l'action** ; un crédit demandé par le navigateur doit être adossé à un paiement.
  Suite prévue : tables ouvertes (hors successions, terrains, urbanisme, championnat), fiche,
  ordre générique.
- **Audit « une seule vérité » (26/10, nuit, branche `claude/audit-une-seule-verite-20261026`)** :
  `AUDIT_UNE_SEULE_VERITE.md` inventorie tout le jeu (tables ouvertes à tout joueur, RPC
  qui créent de l'argent sur demande, champs de fiche encore libres, ~95 tirages et l'ordre
  générique décidés par l'écran, passe de minuit cliente, échéances à l'horloge du
  navigateur, deux affichages, code mort). **Rien n'est corrigé hors ambassades et BNE** :
  l'ordre des chantiers est à décider par Fred. Corrigé côté ambassades : annonces publiques
  par le serveur, traités lus sur le serveur (migration `20261026010000`).
- **Décisions de la série de questions (25/10, branche
  `claude/decisions-ambassades-bne-20261025`)** : Indice Diplomatique réel, un par pays
  (`indices_diplomatiques` + journal, `indices_diplomatiques_lire`, seule écriture
  `indice_diplomatique_varier_interne`) ; toutes les variations par le serveur
  (`ambassade_ouvrir`, `ambassade_reception_organiser` avec présence,
  `ambassade_mecenat`, `ambassade_reserver_salle`, patchs de
  `communication_officielle_publier`, `guerre_cessez_le_feu_activer`, `guerre_declarer`,
  `indice_diplomatique_ordre` pour mobilisation / banquet / réception d'État,
  `diplomatie_repondre`). Le client ne modifie plus `INDICES_NATIONAUX[p].ID` : il la
  recharge (`chargerIndicesDiplomatiques`). Corruption d'un homologue supprimée ; Bureau de
  direction du BNE supprimé ; ouvriers PNJ payés au taux du propriétaire
  (`reliquatNPCServeur`) ; caisse du BNE ouverte au Ministre des Finances
  (`bne_caisse_lire`, `bne_caisse_prelever`, ordre `bne_caisse_prelever`). Migrations
  `20261025120000`, `120100`, `120200`.
- Contexte : objectif actuel = terminer Luthécia. Les ambassades ne seront
  raccordées aux autres empires que lorsqu'ils seront codés (arbitrage
  Fred, 24/10). Nouvelle règle de Fred : **une seule réalité, celle du
  serveur** (voir `AGENTS.md`).
- PR #142 (branche `claude/ambassadeurs-pnj-20261024`) : trois ambassadeurs
  PNJ reçus **sur audience seulement** — Valery Antonov (Sovarka, la
  rigidité), Guillermo Vasquez (El Estado, la corruption), Mohamed
  Al-Mansoori (Al-Khalija, le snobisme). Fenêtre à la charte ardoise et or.
  **Fusionnée le 24/10.** Son tirage de 70 % côté navigateur est remplacé par
  le parcours d'audience ci-dessous.
- PR #141 (branche `claude/audit-ambassades-20261024`, documentation) :
  `AUDIT_AMBASSADES.md` v2 (game design retrouvé, 12 écarts écran/serveur)
  et `AUDIT_BNE.md` (audit complet du Bureau). Chacun finit par les
  questions à trancher par Fred.
- **Audiences d'ambassade (nouveau parcours, arbitrage Fred 24/10)** — branche
  `claude/audiences-ambassades-20261024` : demande à l'accueil (1 PA, une par
  ambassade) → mail « transmise » → délai tiré par le serveur (0 à 3 jours,
  jamais de refus) → mail « accordée » → bureau ouvert 48 h pour ce joueur,
  ambassadeur PNJ dedans. Fonctions `ambassade_*` **appliquées en production**
  (registre 20261024185323 et 20261024185346), baseline pas encore
  réextrait. Passe de nuit ajoutée dans `api/cron-minuit.js`.
- 25/10 : voyants de la messagerie synchronisés (bouton « Messages/Forums »,
  « Boîte Mail », « Mails reçus » lisent la même copie de ce que rend le
  serveur), et règle commune : **l'agent fusionne lui-même** quand les
  contrôles passent (voir `AGENTS.md`).
- 25/10 : **`GAME-DESIGN-AMBASSADES.md`**, la référence des décisions de Fred
  (secrétaires PNJ, naturalisation, transfert de détenus, asile, valise,
  immunité, réceptions ; visas et dépêches écartés). Portes du hall
  cliquables et onglets avec infobulle « Accès limité : il faut avoir une
  invitation. » (branche `claude/portes-ambassades-20261025`, fonction
  `ambassade_acces_bureaux` appliquée, registre 20261025002311).
- 25/10 nuit : **asile politique** (branche `claude/asile-ambassades-20261025`) :
  demande à l'accueil (2 PA), décision de l'ambassadeur PNJ selon le dossier
  (recherché ou affaire vivante) sous 0 à 3 jours, mail ; le réfugié entre
  dans le bureau de son ambassade et ne peut pas être arrêté au Quartier des
  Ambassades (patch de `detention_ouvrir_interne` et `police_detection_verifier`,
  + déclencheur filet). Trois migrations appliquées (registre 20261025004912,
  20261025004941, 20261025005227).
- 25/10 nuit : **corrections du Bureau de l'Emploi** (branche
  `claude/bne-corrections-20261025`) : B1-B7, B9, B10 et un bug trouvé au banc
  (aucun emploi n'était payé). Migration appliquée (registre 20261025010423).
  Détail dans `AUDIT_BNE.md` § 6.
- 25/10 soir : **nouvelle formule du Bureau de l'Emploi** décidée par Fred,
  consignée dans **`GAME-DESIGN-BNE.md`** (recensement des postes réels tenus
  par des PNJ, candidature transmise au recruteur officiel avec décision le
  vendredi, annonces des joueurs, virement automatique, suppression des sept
  offres fictives et de l'inscription).
- 25/10 soir, **lot 1 livré** (branche `claude/bne-recensement-20261025`, registre
  20261025181516) : sept offres et inscription supprimées, mail aux titulaires,
  écran « Postes à pourvoir » lu sur `bne_postes_a_pourvoir` ; candidature par le
  circuit existant du 25 août (Fred : « on conserve l'ancien fonctionnement en
  entier ») ; capitaine/lieutenant postulables depuis le Bureau.
- 25/10 soir : **1 PA par candidature** (registre 20261025182135) et **lot 3,
  annonces des joueurs** (registre 20261025183757 : `bne_annonces`,
  `bne_annonce_publier/lister/retirer`, option Tribune 30 FR versés à la caisse
  `<pays>_bureau-national-emploi`).
- 25/10 soir : **taux horaire des chantiers** fixé par le titulaire, minimum 50 FR
  (registre 20261025193111) : action `taux` de `chantier_commande`,
  `chantier_taux_definir`, `chantier_travailler` paie au taux du chantier. **Codex :
  touche à tes fichiers construction** (`plateau-construction-commandes.js` : ordre
  dynamique `taux_chantier` ; `plateau-chantiers.js` : `tauxHoraireChantier`). Le
  travail PNJ (cron) reste au taux de référence de 70 FR.
- 25/10 soir : **virements entre joueurs** (registre 20261025194235 et
  20261025194255) : `banque_virement`, `banque_virement_automatique_creer`,
  `virements_automatiques_mes`, `virement_automatique_arreter`, passe de nuit
  `virements_automatiques_executer` (cron). Tous les lots de `GAME-DESIGN-BNE.md`
  sont livrés ; reste la question du Bureau de direction (fin de chantier).
- 25/10 soir : **trois référentes emploi** (Nathalie Boulot, Edwige Leroux, Pétra
  Vaillepas), fiches dans `api/_pnj-referents.js`, déclarées dans `pnj_referents`
  (registre 20261025201502).
- 25/10 nuit : **fin des chantiers**. BNE : restes retirés, heures de chantier et
  dossier de candidature par le serveur (#162). Ambassades : actions du ministre par
  le serveur, table en lecture seule pour les joueurs, asile tranché par
  l'ambassadeur joueur, secrétaires, valise (registre 20261025210049, …210208,
  …210344). Bloqués par l'absence de voyage entre empires : immunité, arrestation de
  l'expulsé, transfert de détenus, naturalisation (voir `GAME-DESIGN-AMBASSADES.md`).
- Prochaines étapes (Claude) : coder `GAME-DESIGN-BNE.md` par lots — 1. suppression
  des offres et de l'inscription + recensement ; 2. candidatures et décision du
  vendredi ; 3. annonces des joueurs (+ parution Tribune par le serveur, caisse du
  Bureau) ; 4. virement entre joueurs puis virement automatique ; 5. taux horaire
  des chantiers fixé par le propriétaire (minimum 50 FR).
  Ambassades : griser « Bientôt disponible » les ordres non raccordables (en
  attente de Fred).
- Bancs : 85/102 en local, les 17 échecs sont identiques sur `main`
  (bancs navigateur, environnement).
- Issue #143 : passer toutes les fenêtres à la charte (plus tard).

Travaux déjà ouverts avant la mise en place du relais (pull requests
existantes, à reprendre si Fred le demande) :
- #139 `integration/livraison-terrain-135-20261024` — terrains : occupation
  transactionnelle, réaménagement, protection des locaux (issue #135).
  Restent L11 acquisition/financement, L04 prêt conso, L09 bénédiction.
- Nombreuses PR WIP plus anciennes (construction #94, successions #95,
  interception policière…) : voir la liste des PR ouvertes.

## Derniers chantiers

- 24/10/2026 — Mise en place du relais Codex/Claude (`AGENTS.md`,
  `CLAUDE.md`, `RELAIS.md`).

### Intégration inventaire #213 — 29/10/2026

- PR #249 : branche dédiée, issue du `main` 27198955, sans importer les groupes inachevés #219. Les raccordements d'inventaire de #213 sont réconciliés avec le code récent des écrans. Aucun déploiement, aucune migration de fermeture à cette étape.
- Dix migrations métier déjà installées en base ; six fermetures différées au déploiement d'un client compatible : `20261028210000`, `20261028210500`, `20261028210600`, `20261028210700`, `20261028210800`, `20261028210900`. Ne pas activer le verrou final sans observation et accord du game designer.
- CI au SHA de la PR #249 et validation des chemins d'inventaire impératives avant fusion. La garde fret `hg_fret_contenu_source` demeure désactivée en attendant le nouveau client.
