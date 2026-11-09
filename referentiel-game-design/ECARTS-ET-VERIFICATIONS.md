# Registre des contradictions, lacunes et vérifications

**Instantané : main `a8bd5e26` du 9 novembre 2026.** Il s'agit d'un registre **d'incertitudes argumentées** ; aucun de ces constats n'autorise de correction de game design sans arbitrage. Les déclarations du relais sont des sources historiques, à recouper avec le code, le registre SQL, la CI et la bêta.

## Écarts de nature documentaire / temporelle

### E-01 — Les chiffres de l'architecture ne décrivent pas nécessairement le jeu actuel
`ARCHITECTURE.md` annonce 93 bâtiments, 249 pièces, 846 ordres, 346 actions, 357 tables et 1 058 fonctions, pour un relevé du **26–27 octobre**. L'arbre Git du 9 novembre inclut une importante extension de Sovarka et 300 migrations actives. **Écart : chiffres figés / périmètre évolutif, pas contradiction prouvée sur une mécanique précise.** Recalculer à partir des référentiels actifs puis comparer au schéma réel ; ne pas écraser l'historique.

### E-02 — Publication et jouabilité confondues dans certains relais historiques
`RELAIS.md` utilise « livré » avec diverses preuves (PR fusionnée, Vercel READY, migration exécutée, banc SQL), et demande séparément « à constater en jeu », notamment pour le palais présidentiel et la justice de Sovarka du 8 novembre. **Écart : livraison technique ne prouve pas recette utilisateur.** Créer des colonnes séparées MIG-R / P-R / J ; fournir URL, version et testeur isolé.

### E-03 — Référentiel naval : deux modèles concordants ; mobilité encore distincte
`GAME-DESIGN-CHANTIER-NAVAL.md` définit deux modèles à 90 000 FR (3 places, 300 fret) et 150 000 FR (5 places, 500 fret) ; `plateau-naval.js` référence les deux et lit les tarifs par RPC. **Le 9 novembre, `chantier_naval_modeles` en production confirme exactement ces deux modèles, leurs durées et matières** (voir `ETAT-SUPABASE-LECTURE-SEULE.md`). **Aucune contradiction document/code/SQL établie** sur les valeurs actuelles. La navigation privée, distincte de la construction, est explicitement déclarée désactivée dans le document de design et reste à vérifier. Ne pas supposer une règle alternative sans source datée.


### E-04 — PNJ sociaux : perspective de sept supplémentaires ≠ déploiement
`plateau-social-pnj.js` dit qu'il serait possible d'ajouter « sept autres PNJ sociaux » ; les lieux recensés dans ce fichier sont le bar des pêcheurs et Capitaine Sauvage, et `baseline/seeds/90_socle/pnj_social_jalons_regles.sql` porte **deux jalons**. **Écart : ambition / corpus réellement inspecté.** Il faut recenser séparément tous les profils, règles SQL et déclencheurs éventuels hors de ce fichier, puis confirmer une entrée spontanée et la continuité de mémoire sur un compte isolé. Ne pas prétendre que seulement deux PNJ de toute nature peuvent mémoriser leurs échanges : `api/chat.js` appelle aussi d'autres mémoires contextuelles.

### E-05 — Mobile : certification automatisée versus expérience sur appareil
`RELAIS.md` attribue à la PR #633 une fusion du 8 novembre ; `CERTIFICATION-MOBILE-20261108.md` rapporte 203/203 au contrôleur, 17/17 au nouveau banc et 119/119 au pilote sur fixtures. `RECETTE-PHYSIQUE-MOBILE-20261108.md` dit explicitement qu'aucun iPhone / Android réel n'a été testé lors de cette session. **Pas de contradiction de code, mais risque de surdéclaration de disponibilité.** Valider Safari réel, Chrome Android, petit clavier, reconnexion, changement d'onglet et deux appareils sur compte isolé.

### E-06 — Multilingue : PR #377 fusionnée, activation intégrale non démontrée
**Vérification directe GitHub le 9 novembre : la PR #377 est FUSIONNÉE** le 8 novembre 2026 (`3151c5b6`), sous le titre « i18n accueil : afficher les 9 langues, sans activation du jeu multilingue ». Son corps est un **journal historique** dont les phrases « encore en brouillon » sont désormais périmées : il annonce jusqu'à 392 libellés d'ordres × neuf langues, des variantes et des titres de pièces, sans autoriser l'activation multilingue générale. `i18n/resources.js` et `i18n/i18n-init.js` sont présents sur main. **État établi : une PR contenant de la traduction a été fusionnée ; le titre et la portée de cette livraison excluent l'activation générale.** Ce n'est ni la preuve d'une couverture complète des 517 tarifs ou 1 072 occurrences client, ni une certification des parcours PJ dans neuf langues. Vérifier le flag actif, la couverture et les traductions natives avant toute conclusion.


### E-07 — Portée de l'audit d'autorité du 26 octobre
`AUDIT_UNE_SEULE_VERITE.md` relevait des permissions SQL, des écritures du client et des tirages locaux problématiques ; `AGENTS.md` décrit des protections postérieures (ex. refus d'écriture RPC par la vue `personnages`). **Écart temporel** : on ne peut ni déclarer tous les défauts actifs ni les considérer tous résolus. Vérifier auteur / contexte / RLS / RPC / version production pour chaque risque.

### E-08 — Géographie interempire et commerce
`ARCHITECTURE.md` (octobre) donne les ambassades, diplomatie et import/export dans les couches, mais indique que le **voyage entre empires n'existe pas**. Les nouveaux bâtiments de Sovarka peuvent montrer bureaux d'ambassade et douanes sans ouvrir le voyage du PJ. **Écart de visibilité** potentiel : tester le clic et l'ordre réel, distinguer économie interempire et mobilité personnelle.

### E-09 — Travail simultané et documents périmés
`RELAIS.md` contient des sections explicitement remplacées par une note plus récente (ex. certification mobile) et des décisions de 4–8 novembre déjà intégrées dans `GAME-DESIGN-NOVOMIRSK.md`. **Risque :** un agent qui lit une mention historique isolée réintroduit une règle dépassée. En cas de contradiction : dernier arbitrage explicite du game designer > projet d'agent ; le code est constaté, pas arbitre de design. Garder la source historique intacte et ajouter lien vers règle courante.


### E-10 — Mémoire des PNJ sociaux : relation persistée, pas récit de dialogue persisté
Les fonctions SQL **réellement lues** (`pnj_social_entrer`, `pnj_social_contexte`, `pnj_social_noter`) suivent rencontres, conversations et familiarité, ainsi que des faits sûrs d'identité. La fonction `pnj_social_entrer` exclut explicitement la sauvegarde du contenu et de son résumé dans la V1. `api/_pnj-profils.js` exploite les compteurs dans le prompt ; `api/chat.js` accepte un historique court transmis lors de la conversation courante. **Une mémoire relationnelle existe ; une mémoire sémantique à long terme de ces dialogues n'a pas été démontrée pour ces PNJ.** Voir `PNJ-IA-MEMOIRES-INTERACTIONS.md`. Ne pas extrapoler ce résultat à toutes les mémoires institutionnelles ou pédagogiques.

### E-11 — Graphes de rues : intégrité globale et un trajet unidirectionnel
Les six graphes de villes de Républia/Sovarka sont chacun connexes au sens non orienté, sans arc vers un nœud manquant. La base contient pourtant un arc `novomirsk-vue-15 → novomirsk-vue-16` sans retour direct. **Possible itinéraire voulu ou défaut à caractériser**, et non bogue confirmé. Les sorties explicites de bâtiments n'enregistrent que trois bâtiments à Starovka et cinq à Krasnov ; la disponibilité effective des autres dépend des voies d'entrée alternatives ou du contenu encore manquant. Voir `NAVIGATION-ET-ACCESSIBILITE.md`.

**Suivi du 9 novembre (Claude, PR #647, migrations appliquées le matin)** : onze façades ajoutées (Starovka : hôtel, terrain, stade, mairie, commissariat, centre d'affaires ; Krasnov : terrain, centre artisanal, centre commercial, mairie, centre d'affaires) ; 19 sorties de bâtiments au total dans les deux villes. Restent sans façade : banque, dispensaire, tribunal, siège syndical, usine, zone de production (question de design ouverte).

### E-12 — Traitement nocturne : six passes incomplètes attestées, retour au vert

Le journal **vivant** `cron_journal` consulté le 9 novembre indique **six états `_passe=echec` consécutifs du 1er au 6 novembre**, tous portant l'étape `sbRpc:traiter_prets_helvetia_quotidien`, et **trois `_passe=ok` du 7 au 9 novembre**. Le relevé ne prouve ni perte de fonds, ni rattrapage des échéances des nuits défaillantes. L'investigation opérationnelle de cette période reste distincte de la clôture du référentiel de conception. Source et requêtes décrites dans [l'audit ciblé](AUDIT-ACCUEIL-I18N-NUIT-DROITS.md).

**Cause et impact établis (Claude, 9 novembre)** : erreur SQL « column reference "pret_id" is ambiguous » dans `traiter_prets_helvetia_quotidien`, qui annulait toute la transaction ; corrigée par la migration `20261106030500_prets_helvetia_pret_id_ambigu` (appliquée le 06/11 vers 3 h, voir `RELAIS.md`). Un seul prêt Helvetia existe (compte de test Jean Jaaj, 150 000, 5 600 par jour). Le remboursement est un décompte de mensualités jusqu'à solde nul, sans échéance datée (la fonction n'utilise ni `created_at` ni `duree_jours`) : les six nuits manquées ont **décalé le calendrier de six jours, sans perte d'argent ni pénalité indue**. Pas de rattrapage : prélever six mensualités d'un coup ferait payer au joueur une panne du serveur et pourrait le pousser en contentieux. Statut : clos côté données.

### E-13 — « Minuit » et expérience temporelle réelle

`vercel.json` lance le cron à `23:00 UTC` : minuit à Paris en hiver, **01:00 en été** ; les trois dernières passes rapportées commencent vers **00:40** en heure de Paris. Le calcul journalier du backend est explicitement `Europe/Paris`, mais programmation, moment d'exécution et date de l'effet ne sont pas trois concepts identiques. **Ne pas annoncer un bug de date/débit sans test**, ni garantir une activation à la seconde de minuit. Voir [audit ciblé](AUDIT-ACCUEIL-I18N-NUIT-DROITS.md).

### E-14 — Audit statique des permissions des fonctions à prolonger

Sur 1 605 fonctions publiques observées, 1 401 sont `SECURITY DEFINER`, dont 26 exécutables par `anon` et 750 par `authenticated`. **Ce comptage ne démontre aucune vulnérabilité** sans lecture des contrôles d'identité internes. Toute certification d'autorité serveur devra vérifier la protection des fonctions actionnelles plutôt que seulement la RLS des 444 tables. Voir [audit ciblé](AUDIT-ACCUEIL-I18N-NUIT-DROITS.md).

**Revue des 26 fonctions DEFINER exécutables par `anon` (Claude, 9 novembre)** : 24 sûres (gardées par `exiger_acteur`, `mon_personnage` ou `acteur_poste_courant`, neutralisées comme `calomnie_distribuer`, ou lectures publiques voulues : journal publié, sièges de l'assemblée, catalogue d'un commerce, rumeurs anonymisées, empreintes de configuration). Deux helpers internes sans garde laissaient sonder l'inventaire et la position d'un PJ nommé (`militaire_terminal_liaison`) et l'arme d'un PNJ (`militaire_arme_operationnelle`) : droits client retirés, migration `20261109094500_fonctions_militaires_internes` appliquée (banc annulé vert : client refusé, appelants DEFINER intacts). Les 36 fonctions INVOKER exécutables par `anon` sont des calculs et lectures soumis à la RLS. Les 750 DEFINER exécutables par `authenticated` restent hors de cette revue.

## Zones encore non vérifiées

| Identifiant | Ce qu'il faut démontrer | Moyen de preuve | Sévérité pour la compréhension |
|---|---|---|---|
| V-01 | Nombre exact d'ordres, visibilité par empire, rôle et pièce | extraction du catalogue actif + parcours du routeur | Critique |
| V-02 | Règle finale de chaque ordre, coûts PA, PSK/FR, objets, délai | jointure décisions / handler / RPC / SQL | Critique |
| V-03 | Existence et autorité de chaque RPC en production | catalogue SQL lecture seule, RLS, tests négatifs | Critique |
| V-04 | Tests reproductibles au SHA main du 9/11 | CI et bancs ciblés, compte rendu exact | Haute |
| V-05 | Correspondance code ↔ déploiement public | SHA Vercel READY, URL, vérification sans écriture | Critique |
| V-06 | Parcours humains après création | sessions enregistrées avec consentement, zéro mutation non autorisée | Critique |
| V-07 | Boucles de retour (sommeil, tâches, salaire, interactions) | cohorte et sessions consenties, observation sur plusieurs jours | Critique |
| V-08 | Lisibilité des cartes, retour ville, changement bâtiment | essais nouveaux joueurs et appareils réels | Critique |
| V-09 | PNJ spontanés, mémoire persistée et qualité conversationnelle | session isolée de 1re/2e visite, actualisation, fournisseur réel | Haute |
| V-10 | Ouverture réelle de l'i18n et stabilité des neuf langues | état du flag + rapports de couverture par écran et recette | Haute |
| V-11 | Absence de cul-de-sac économique, judiciaire, hospitalier | parcours d'échec et sortie avec position et ressources cohérentes | Critique |
| V-12 | Effet d'une faible population sur politique / économie / sport | simulation de dépendances PJ / PNJ sans automatiser les choix humains | Critique |
| V-13 | Matériaux, navire, stock et tarifs navals exacts | devis RPC lecture seule + SQL + décision récente | Haute |
| V-14 | Justice et pouvoir de Sovarka réellement utilisables | banc SQL sur version active + recette sur compte isolé | Haute |
| V-15 | Prix premium, droits et absence de P2W | matrice entitlement, règles de bêta et parcours | Haute |
| V-16 | Cadence des crons à l'heure d'été/d'hiver | journaux Vercel + événement de minuit + dates réelles | Haute |

## Ce que le présent audit ne peut pas affirmer
- **Preuves directes obtenues en lecture seule dans Supabase :** nombre de tables/fonctions/RLS, registre des migrations, catalogue de coûts et configurations des bateaux et PNJ sociaux. Les autres données, droits et effets serveur n'ont pas été audités exhaustivement.
- Aucun journal CI du commit de référence n'a été rejoué ni inspecté au-delà des comptes rendus lus.
- Aucun parcours navigateur authentifié, achat, interaction entre PJ ou dialogue DeepSeek n'a été exécuté.
- Le **déploiement Vercel READY** du commit étudié a été vérifié auprès de Vercel (voir `ETAT-VERCEL-PUBLICATION.md`), mais aucune recette authentifiée n'a été effectuée.
- Aucune statistique de conversion, d'activation, d'abandon ou de rétention joueur n'a été fournie.
- Aucune conclusion sur « ce qui est effectivement jouable » ne peut être certifiée pour **tous** les ordres sans ces preuves.

**Conséquence :** registre ouvert ; l'audit n'est pas clos et ne doit pas être utilisé comme approbation de déploiement.
