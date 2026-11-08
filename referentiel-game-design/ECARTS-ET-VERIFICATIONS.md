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

### E-06 — Multilingue : architecture présente ≠ couverture publiquement autorisée
`i18n/resources.js` et `i18n/i18n-init.js` exposent l'infrastructure de langues et le choix. Le chantier de traduction fait l'objet de la PR **#377** (historique de travail en brouillon et activation générale non autorisée). **Écart de périmètre :** la présence de ressources i18n sur main ne démontre pas la traduction de tous les ordres, PNJ et messages ni une activation publique ; il faut une matrice par écran, langue, test, activation. Ne fusionner/activer aucun travail i18n au titre de cet audit.

### E-07 — Portée de l'audit d'autorité du 26 octobre
`AUDIT_UNE_SEULE_VERITE.md` relevait des permissions SQL, des écritures du client et des tirages locaux problématiques ; `AGENTS.md` décrit des protections postérieures (ex. refus d'écriture RPC par la vue `personnages`). **Écart temporel** : on ne peut ni déclarer tous les défauts actifs ni les considérer tous résolus. Vérifier auteur / contexte / RLS / RPC / version production pour chaque risque.

### E-08 — Géographie interempire et commerce
`ARCHITECTURE.md` (octobre) donne les ambassades, diplomatie et import/export dans les couches, mais indique que le **voyage entre empires n'existe pas**. Les nouveaux bâtiments de Sovarka peuvent montrer bureaux d'ambassade et douanes sans ouvrir le voyage du PJ. **Écart de visibilité** potentiel : tester le clic et l'ordre réel, distinguer économie interempire et mobilité personnelle.

### E-09 — Travail simultané et documents périmés
`RELAIS.md` contient des sections explicitement remplacées par une note plus récente (ex. certification mobile) et des décisions de 4–8 novembre déjà intégrées dans `GAME-DESIGN-NOVOMIRSK.md`. **Risque :** un agent qui lit une mention historique isolée réintroduit une règle dépassée. En cas de contradiction : dernier arbitrage explicite du game designer > projet d'agent ; le code est constaté, pas arbitre de design. Garder la source historique intacte et ajouter lien vers règle courante.

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
