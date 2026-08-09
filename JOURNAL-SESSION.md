# Journal de session — Res Publica (9 août 2026)

## État du dépôt
- Toutes les modifications ont été committées et poussées sur `main`.
- Session reprise après la clôture de 3h : mécanique "moyenne de groupe" conçue et déployée partout, `distribuer_tract` construit de zéro dessus, économie du bois de l'imprimerie La Tribune ajoutée en prérequis, quête carrière complétée (aiguillage + 3 mini-missions des référents), refonte complète du système de postes, main d'œuvre de production pilotée sur l'Armurerie, découverte et résolution d'un vrai bug d'infrastructure Supabase (RLS) qui bloquait silencieusement `batiments_etat` depuis le début, correction des 2 bugs confirmés par le test en jeu, 12 images branchées, une série de 6 points remontés par un nouveau test en jeu, peaufinage de l'UX Armurerie, 2 correctifs post-refonte électorale (reset de l'argent au F5, victoire d'Arnie rétablie), 2 ajustements au Notaire (rachat d'entreprise généralisé, renommage compromis), phase de compromis pour le rachat d'entreprise sur le modèle du terrain, puis fix de la clause prêt bancaire du compromis (terrain + adaptation entreprise), tous deux vérifiés par test isolé contre Supabase (voir sections dédiées ci-dessous).

## 🏦 Fix clause "prêt bancaire" du compromis (terrain) + adaptation entreprise
- **Point de départ** : avant de concevoir un nouveau système de prêt pour l'entreprise, vérification de la clause prêt déjà existante sur le compromis de terrain — bug réel trouvé en traçant le code : un prêt **accordé** par le cron (`resoudreCompromisExpires`) créditait bien l'argent et créait bien une vraie ligne `prets`, mais le compromis était wipé **dans la même passe** (seule la branche "refusé" était censée déclencher un remboursement+wipe ; "accordé" tombait par défaut dans le même bloc que "perdu"). Un contrôle existant (`pretOk` dans `traiterActeVente`) attendait manifestement ce cas mais n'était jamais atteignable — mort depuis l'écriture de ce système.
- **Corrigé** (`ca1d5de`) : un prêt accordé gèle désormais le compromis indéfiniment (pas de nouvelle échéance), en attente que le joueur finalise via `acte_vente_terrain`. Sans garde-fou en tête de boucle, la ligne aurait été réexaminée et re-wipée chaque nuit — ajouté. `pretDemande` aussi effacé dans les branches de wipe existantes (fuite adjacente : un `{statut:'refuse'}` resté accroché aurait bloqué à tort un futur compromis n'ayant rien demandé).
- **Vérifié par test isolé** (demande explicite de Fred — "la relecture ne suffit pas, on l'a vu plusieurs fois cette nuit") : 4 scénarios rejoués contre le vrai Supabase avec des données `ZZTEST_` clairement taguées (prêt déjà accordé → inchangé ; prêt accordé à l'instant → gelé + argent crédité + ligne `prets` créée ; pas de prêt → wipe normal ; prêt refusé → remboursé + wipe), toutes données de test nettoyées après coup.
- **Adapté à l'entreprise** : même clause optionnelle à la signature du compromis (`doSignerCompromisEntreprise`), même contrôle `pretOk` à la finalisation (`traiterActeRachatEntreprise`), même correctif côté cron (`resoudreCompromisEntreprisesExpires`). Saisie sur impayé (`preleverPretsBancairesServeur`) étendue : quand `building_id` ne correspond à aucun terrain, repli sur la table `entreprises` par `id` (`proprietaire` repassé à `'PNJ'`) — pas de remise "prix soldé" comme pour un terrain saisi, ce mécanisme n'existe pas dans le modèle entreprise. Vérifié pareillement par test isolé (prêt accordé sur entreprise, pas de prêt, prêt refusé, repli de saisie).
- **Découverte annexe, même famille que le bug `batiments_etat` de la nuit** : RLS bloquait silencieusement `prets` (insert), `compromis_historique` (insert) et `entreprises` (delete) — découverts un par un pendant les tests, désactivés au fur et à mesure avec Fred sur le dashboard. Item ajouté au backlog pour un audit systématique plutôt que de continuer à les découvrir par accident (voir backlog en bas de journal).

## 📝 Compromis de rachat d'entreprise (modèle terrain, sans "emprunter")
- **Constat avant de coder** : `signer_compromis`/`acte_vente_terrain` (terrain) : acompte fixe 1000 FR, compromis valable 7 jours stocké sur `terrains_etat`, verrouille le bien aux autres joueurs, clauses optionnelles (permis/prêt) tranchées par le cron à l'échéance — remboursé si refus explicite, sinon perdu. Rien d'équivalent aux clauses n'existe pour une entreprise.
- **Adapté** (`7c37ca9`) : `doRachatEntreprise()` (Notaire) ouvre désormais un compromis (`doSignerCompromisEntreprise`/`confirmerSignerCompromisEntreprise`) au lieu d'acheter directement — mêmes noms de champs que le terrain (`compromis`/`compromisPar`/`acompte`/`compromisAt`/`compromisExpireAt`), mais stockés sur l'objet entreprise lui-même (table `entreprises`) plutôt que sur une table dédiée. Exclut désormais aussi de la liste toute entreprise déjà sous compromis actif (le mien ou celui d'un autre — demande explicite de Fred, pour ne pas payer un 2e acompte par erreur). Nouvel acte "Officialiser le rachat d'une entreprise" (`doActeRachatEntreprise`/`traiterActeRachatEntreprise`) finalise en payant le solde, sur le modèle exact de `traiterActeVente`.
- **Bug trouvé et corrigé en cours de route** : l'ordre "Racheter une entreprise" avait `cost:130000` — un pré-filtre de `doOrder()` qui bloque le clic *avant même d'ouvrir l'écran* si `state.arg < cost`. Aurait empêché tout joueur avec moins de 130 000 FR d'accéder au compromis à 1000 FR, annulant l'intérêt même de la fonctionnalité ("signer avec peu d'argent, rassembler le solde ensuite"). Corrigé en `cost:0` (le vrai contrôle de fonds se fait dans le handler, sur le montant réel dû à chaque étape).
- **Expiration sans finalisation** : aucune clause à trancher pour une entreprise (contrairement au terrain) → l'acompte est **toujours perdu**, jamais remboursé. Nouvelle fonction cron `resoudreCompromisEntreprisesExpires()`, qui balaie **toute** la table `entreprises` plutôt qu'une liste figée par type — couvrira donc automatiquement les futures entreprises rachetables sans toucher au cron.

## 🏛️ Deux ajustements au Notaire (généralisation du rachat d'entreprise)
- **Rachat d'entreprise généralisé** : "Officialiser le rachat de l'armurerie" devient "Racheter une entreprise" — nouveau registre `ENTREPRISES_RACHETABLES` (`plateau-actions-illegales-rumeurs.js`, une seule entrée aujourd'hui : Armurerie). Liste les entreprises encore PNJ dans l'empire du joueur, saute directement à l'action s'il n'y en a qu'une (même logique que `traiterActeVente` pour les compromis de terrain — demande explicite de Fred, cohérence avec l'existant), sinon affiche une liste. *(Le lendemain, ce flux d'achat direct a lui-même été remplacé par un compromis — voir section ci-dessus.)*
- **Prêt pour la suite, avec une limite explicite documentée en commentaire** : ajouter une future entreprise rachetable sera une ligne de config — mais uniquement le jour où elle suivra le même modèle propriétaire/PNJ (table `entreprises`) que l'Armurerie. Les entrepôts/usines actuels (Usine Pharmaceutique, Pôle Tabac & Alcools, Raffinerie, Entrepôts Logistiques) utilisent un modèle différent — directeur nommé par le Maire (`titulaires_pnj`, table `batiments_etat`, aucun champ `proprietaire`) — donc ne rejoignent pas cette liste automatiquement tant qu'ils n'auront pas eux-mêmes basculé de modèle.
- **Renommage compromis** : "Valider un compromis reçu" → "Valider un transfert de compromis" (`data.js`), pur changement de libellé — plus explicite sur ce que fait réellement l'ordre (accepter la cession d'un compromis de terrain venant d'un autre joueur).

## 💰🗳️ Deux correctifs post-refonte électorale (retour de test de Fred)
- **Bug urgent — argent réinitialisé à chaque F5** : diagnostiqué avant correction (demande explicite de Fred). `loadCharacter()` (`plateau-core.js`) fusionne l'état Supabase (`Object.assign(state, sbState)`, argent correct à ce stade), puis rappelle `applyCharToState(state.char)` pour recalculer inf/pop/dis à partir de `char.resources` — un fix déjà fait *pour inf/pop/dis* une nuit précédente ("gains perdus au F5"), jamais étendu à `arg`. Or l'objet `char` renvoyé par `sbLoadPersonnage()` (`supabase.js`) n'a **jamais** de champ `arg` (l'argent vit en top-level de l'état, pas sur `char`) — `applyCharToState()` relit donc `char.arg` `undefined` et retombe sur le défaut codé en dur `4250`, écrasant la vraie valeur. Fix (`91908f6`) : `state.char.arg = state.arg;` ajouté au même endroit que le fix inf/pop/dis existant.
- **"Gaston Intérim prend les rênes de Président à Republia"** : diagnostic croisé avec une requête directe sur `cycles_electoraux` (republic/president) — deux bugs superposés, indépendants de la refonte des postes de ce soir.
  - Le cycle présidentiel avait été traité **avant** le fix du comptage de votes du 9 août (`calculerResultatsServer` lisait `votes_pj`/`votes_pnj`, des champs qui n'ont jamais existé) : Arnie, seul candidat avec 3/3 votes PNJ (unanimité), avait été déclaré "vacant" (`eluId:null`) faute de voix comptées. `resultatsTraites:true` étant déjà posé, le cron ne retraite jamais une ligne déjà "traitée" — la victoire d'Arnie ne pouvait donc jamais être recalculée automatiquement, même avec le comptage réparé.
  - "Gaston Intérim" ne vient pas de la nouvelle cascade auto-pourvoi (`titulaires_pnj` vérifié vide pour republic — le président n'y est de toute façon jamais stocké) : c'est un système cosmétique **pré-existant et indépendant**, `nommerAdministrateurSiVacant()` (`plateau-politique.js`), qui nomme un PNJ "régent" dès qu'un cycle est détecté vacant au chargement/réveil d'un personnage — sans jamais sauvegarder sur Supabase (ligne inchangée depuis le 25 juillet, confirmé par requête directe). Aucun pouvoir réel accordé à personne.
  - **Corrigé en base directement** (demande explicite de Fred, avant le prochain passage du cron qui aurait posé un PNJ générique définitif via la cascade) : `cycles_electoraux` republic/president mis à jour manuellement — `eluId:'Arnie'`, `phase:'mandat'`, `dateFinMandat` recalculée à 5 semaines à partir de maintenant. `reconcilierPosteElu('president', null)` (appelée par `appliquerVictoireElectorale`, déjà câblée au chargement du personnage depuis la refonte des postes) accordera automatiquement le vrai `state.poste` à Arnie à sa prochaine connexion — aucune autre intervention nécessaire.

## 🔫 Peaufinage UX Armurerie (pilote avant duplication sur entrepôts/usines)
- **Point de départ** : avant de dupliquer le patron de l'Armurerie sur les autres bâtiments à entreprise (usines, entrepôts), Fred a demandé un état des lieux complet (structure `racheter_armurerie`/`gerer_armurerie`, pattern déjà utilisé par le Notaire pour les ventes de terrain, structure des achats prohibés dans les 4 empires) avant tout code — fait et montré avant de coder quoi que ce soit.
- **Découverte notable de l'état des lieux** : `acheter_bombe_illegale` était un ordre unique et identique, partagé par les 4 empires (même prix, même texte) dans le template Armurerie commun — pas de variante par empire, contrairement au catalogue d'armes légales (`RECETTES_PRODUCTION`/`getRecettesPays`). Le poison, lui, était déjà correctement cloisonné par empire (`POISON_OBJETS[...].empire`) mais son emplacement était incohérent : Armurerie pour Republia/Sovarka, **Marché** pour El Estado/Al-Khalija — pas l'Armurerie comme supposé au départ.
- **Racheter l'entreprise** : ordre `racheter_armurerie` déplacé de l'Armurerie vers le Bureau des Contrats du Notaire (même room que `acte_vente_terrain`), libellé adapté ("Officialiser le rachat de l'armurerie"). Logique de `doRachatArmurerie()` inchangée — pas de compromis/acompte comme pour les terrains, l'armurerie s'achète toujours cash en un seul acte, il n'y avait donc rien à répliquer sur ce point du pattern terrain.
- **Gérer mon armurerie / Vendre des matières premières** : retirés de la liste d'ordres visible. Accessibles désormais en cliquant sur la caisse/le stock affichés en en-tête du bâtiment (`enterBuilding`, `plateau-navigation.js`) — caisse cliquable seulement pour le propriétaire (`data.proprietaire === state.char?.name`), stock ouvert à tout joueur (comme avant). Curseur/`onclick` bien remis à zéro en sortant de l'Armurerie pour ne pas laisser un gestionnaire résiduel sur la caisse d'un entrepôt/usine visité ensuite.
- **Marché Noir cloisonné par empire, sans déplacement de lieu** (correction de Fred sur ma proposition initiale — pas de regroupement systématique à l'Armurerie) : nouvelle fonction `doMarcheNoir()` (`plateau-actions-illegales-rumeurs.js`), un seul ordre `marche_noir` par empire qui ouvre un popup listant Explosifs + le poison local, **à l'endroit où le poison était déjà vendu** — Armurerie pour Republia (Roger Détente) et Sovarka (Camarade Kalachnikov), Marché pour El Estado (Carlos) et Al-Khalija (Hassan). Le même vendeur propose donc les deux, pas de nouveau PNJ ni de nouveau lieu. `acheter_bombe_illegale` autonome retiré du template Armurerie partagé (reste inchangé à l'Armurerie Militaire, `fn` identique mais contexte "subtiliser" distinct, hors périmètre).
- **Prochaine étape, une fois validé en jeu** : dupliquer ce même patron (acte notarié + accès sur place via en-tête) sur les autres entreprises à racheter (Usine Pharmaceutique, Pôle Tabac & Alcools, Raffinerie, Entrepôts Logistiques) — pas fait ce soir, périmètre volontairement limité à l'Armurerie pour validation d'abord, comme pour la main d'œuvre de production.

## 🧭 Série de 6 points remontés par test en jeu (diagnostic complet avant toute correction, puis corrections)
1. **Bouton mort "Parler à..."** (`fn:'parler_pnj'`) : le routeur ne fait qu'afficher "Cliquez directement sur le personnage pour interagir." Retiré aux 3 endroits où il traînait (La Tribune, Centre d'Affaires, Clinique Privée) — un seul introduit par moi (La Tribune, la veille), les deux autres préexistants.
2. **Image Banque Privée Helvétia** : débranchement d'un mois, pas un partage de chemin comme le bug BNE. `banque-privee-helvetia-bureau.png` (bureau bancaire suisse sans ambiguïté) avait été câblée par erreur sur la salle du restaurant de l'Hôtel Republica le temps d'un commit, corrigé le 2 juillet — mais jamais rebranchée sur sa vraie destination (`banque-privee` → `bureau_prive`). Fait maintenant.
3. **Centre Multimodal Luthécia** : bouton "Prendre le bateau" retiré du Hall Principal (Luthécia n'a pas de port — seule Port-Sainte-Marie en a un). Nouveau bouton "Prendre l'avion" au Hall Principal (`aller_douanes_aeroport`) qui conduit au Hall des Douanes ; une fois `passer_douanes_aeroport` réussi, redirection automatique vers la Zone d'Embarquement (remplace l'ancien bricolage qui se contentait de déverrouiller visuellement un onglet sans y entrer). Le verrou réel (`state.douanePassee`, déjà fonctionnel) n'a pas changé — seul le confort de navigation est ajouté.
4. **Popups fermées par un clic n'importe où sur l'écran** : mécanisme partagé par les 9+ modals du jeu (`document.querySelectorAll('.modal-overlay')`, `plateau-politique.js`). Corrigé **uniquement sur `modal-quete-accueil`** (décision de Fred) — les autres modals gardent le clic-extérieur, pratique et sans risque de perte de progression pour eux.
5. **Mécanisme de reprise jamais raccordé à la quête carrière** : `queteAccueilRappel()` existait déjà (déclenché en tapant une phrase comme "où en étions-nous" à Jérémy — pas via le journal d'événements visible comme supposé), mais ne couvrait que l'ancien tutoriel. La séquence de clôture carrière (proposition d'ambition, orientation, répertoire, recontact, conclusion) enregistre désormais sa propre étape à chaque écran, avec une entrée de rappel correspondante — fermer la popup à n'importe quel moment de la séquence redevient récupérable en reparlant à Jérémy.
6. **"Je veux être président" tapé en texte libre n'a rien fait** : confirmé non lié à un bug de saisie — Jérémy propose bien les 4 boutons prévus (Criminelle/Politique/Entrepreneuriale/Indécis), mais le chat libre n'a jamais eu de lien avec `queteCarriere` (seuls 2 cas spéciaux existent pour Jérémy : "bonjour" et les phrases de rappel du point 5). Very probablement le même incident que les points 4 et 5 : popup fermée par le bug de clic, tentative de rattrapage par le texte libre, qui ne pouvait pas aboutir. Résolu indirectement par les fixes 4 et 5 — plus besoin de deviner un texte libre, la popup ne se ferme plus par accident et reste récupérable sinon.
- **Oubli corrigé au passage** : les 12 images branchées plus tôt ce soir n'avaient jamais été réellement committées (seules les références dans `data.js` l'avaient été) — les fichiers eux-mêmes traînaient non trackés depuis. Ajoutés au dépôt avec ce lot de corrections.

## 🔒 Bug d'infrastructure trouvé et résolu : RLS bloquait `batiments_etat` depuis le début
- **Point de départ** : retour de test de Fred — l'entrepôt de Luthécia affichait toujours caisse et stock à zéro malgré le fix caisse/stock de l'Armurerie fait juste avant. Hypothèse initiale (cron pas encore repassé) écartée par l'investigation : `cycles_electoraux` n'avait plus été modifié depuis le 25 juillet, mais surtout **`batiments_etat` était totalement vide, zéro ligne, pour absolument tous les bâtiments** (entrepôts, usines, BNE) — pas seulement Luthécia.
- **Cause réelle trouvée** en tentant l'injection manuelle demandée par Fred : Supabase a refusé avec `"new row violates row-level security policy"`. RLS (Row-Level Security) était activé sur cette table — probablement parce qu'elle est plus récente (créée pendant le chantier "économie V1") et que Supabase active RLS par défaut sur les tables créées depuis le dashboard, contrairement aux tables plus anciennes du jeu (`personnages`, `cycles_electoraux`, `titulaires_pnj`, `entreprises`) qui n'en ont pas. **Ni le cron, ni aucun achat joueur, ni aucune écriture n'a donc jamais pu créer la moindre ligne dans cette table depuis sa création** — indépendamment de tout bug de code déjà corrigé ou à corriger.
- **Résolution en plusieurs passes avec Fred sur le dashboard Supabase** (aucun accès SQL/dashboard de mon côté, uniquement la clé anon REST) : policy INSERT ajoutée → policy SELECT ajoutée mais toujours invisible en lecture (policy mal configurée, cause exacte non identifiable sans accès SQL) → **RLS désactivé entièrement sur `batiments_etat`**, seule solution qui a fonctionné, cohérente avec l'absence de RLS sur les autres tables du jeu (pas de notion d'utilisateur authentifié par ligne ici, une seule clé anon partagée pour tous les joueurs).
- **Vérification finale** : injection de test confirmée lisible en base après désactivation de RLS (voir section Armurerie ci-dessous pour les valeurs exactes). Un résidu de ligne de test (`test-diag-insert`) qui n'avait jamais pu être réellement supprimée à cause de la même RLS a été nettoyé au passage.
- **Portée** : ce déblocage profite à *tout* ce qui utilise `batiments_etat` — entrepôts, usines/pôles, BNE, cron de livraison quotidienne — pas seulement à l'Armurerie ou à ce test ponctuel. À surveiller la prochaine fois que le cron passe (23h UTC) : les livraisons quotidiennes des entrepôts devraient enfin pouvoir s'écrire.
- **Injection de test réalisée** (ponctuelle, pas une mécanique automatique, à la demande de Fred) : Entrepôt Logistique de Luthécia — **caisse : 8 500 FR**, **stock : 300 bois, 100 métal**. L'Armurerie n'a pas eu besoin d'injection : déjà 24 904 FR en caisse et un peu de stock existant (10 bois/20 métal), largement suffisant pour tester `produire_arme`.

## 🔨 Main d'œuvre de production — pilote sur l'Armurerie
- **Constat avant de coder** : `produire_arme` avait en fait déjà un vrai mécanisme de main d'œuvre (PA/matières/caisse vérifiés, salaire versé au joueur, arme créditée au stock de vente) — contrairement à ce que ce journal indiquait hier soir (erreur de ma part, pas vérifié en détail à l'époque). Le seul écart avec la demande de Fred : le barème. Le système existant faisait varier le coût en PA et le salaire selon la complexité de l'arme (`recette.ut × PA_PAR_UT` en coût, `recette.ut × tarifHoraire` réglable par le propriétaire en salaire) ; Fred voulait un tarif plat identique pour toutes les recettes.
- **Changé** (`c0f9b02`) : `PA_PRODUCTION_ARMURERIE=2`, `SALAIRE_PRODUCTION_ARMURERIE=100`, quelle que soit l'arme produite — le coût en matières (`RECETTES_PRODUCTION[id].materiaux`, propre à chaque recette, ex. Revolver = 2 métal + 1 bois) reste inchangé. Le champ `tarifHoraire`, réglable par le propriétaire de l'armurerie, retiré de "Gérer mon armurerie" (n'a plus d'effet avec un tarif plat) plutôt que laissé en contrôle mort.
- **Gardé tel quel, par choix explicite de Fred** : le plafond de stock par produit (`stockMax`) continue de bloquer la production une fois atteint — 4e cas de blocage en plus des 3 demandés (PA / matière / caisse).
- **Bonus UX** : le modal ne se ferme plus après une production réussie, il se rafraîchit — permet d'enchaîner sans le rouvrir à chaque fois, en cohérence avec l'absence de limite quotidienne.
- **Retour de test en jeu** : ni la caisse ni le stock de matières ne s'affichaient dans l'en-tête du bâtiment Armurerie. `BATIMENTS_CAISSE_VISIBLE` (construit le 8 août pour entrepôts/usines) ne la couvrait pas — et ne pouvait pas la couvrir telle quelle : l'Armurerie a son propre stock/caisse de longue date, mais stocké sur une table Supabase différente (`entreprises`, via `chargerArmurerieLocale`) de celle des entrepôts/usines (`batiments_etat`, via `sbGetBatimentEtat`). Nouvelle branche dédiée ajoutée dans `enterBuilding` (`5f182a4`), plus un nouvel élément d'en-tête pour le stock de matières (`bat-stock`, `plateau.html`) — c'était la seule des 3 ressources limitant `produire_arme` invisible avant de cliquer sur "Produire".
- **Prochaine étape, une fois validé en jeu** : dupliquer le même principe sur les autres bâtiments à stock/caisse (Usine Pharmaceutique, Pôle Tabac & Alcools, Raffinerie, Entrepôts Logistiques) — pas fait ce soir, périmètre volontairement limité à l'Armurerie pour validation d'abord.

## 🏛️ Refonte complète du système de postes (dette technique des 3 systèmes parallèles)
- **Point de départ** : `POSTES` (table statique, holders codés en dur, jamais persistée ni synchronisée entre joueurs), `POSTES_ELECTIFS`/`cycles_electoraux` (élections) et `POSTES_NOMMES_EXCLUSIFS`/`titulaires_pnj` (nominations) coexistaient sans jamais vraiment communiquer, pour les 19 postes du jeu (Président, PM, 6 ministères, Maire ×3, Maire Adjoint ×3, Député, Chef Syndical, Juge, Commissaire, Commandant, 4 Directeurs).
- **Audit préalable (avant tout code)** : inventaire poste par poste, interrogation directe de Supabase pour voir l'occupation réelle (résultat : un seul poste réellement occupé sur toute la base — le siège de député d'Arnie — tout le reste vacant, PJ comme PNJ), estimation d'ampleur/risque. Fred a tranché : refonte complète plutôt qu'un correctif ciblé, le risque de casse étant nul vu l'occupation quasi inexistante et la bêta pas encore publique.
- **Découverte la plus sévère de l'audit** : gagner une élection (Président, Maire, Député, Chef Syndical) n'a **jamais** donné le moindre pouvoir réel en jeu — le cron n'écrivait que `cycle.eluId`, jamais `state.poste` sur la fiche du vainqueur. Les élections étaient cosmétiques.
- **Déploiement en 5 étapes, un commit par étape** (`d8f10e5`, `3e23767`, `dfb0276`, `1ba17b0`, `ec322e0`) :
  1. **Suppression du système mort** — `POSTES` et ses 5 fonctions dupliquées (dont une paire routée mais jamais réellement atteignable, court-circuitée par un cas spécial ailleurs) retirées, remplacées par un écran unique (`ouvrirEcranPostes`) qui renvoie vers le calendrier électoral pour les postes élus et généralise la candidature par mail à *tous* les postes nommés — jusque-là réservée à PM/ministres. Règle de priorité PJ enfin codée : un PJ qui postule auprès d'une autorité PNJ générique est désormais accepté directement (un PNJ ne prend jamais de vraie décision). 3 bugs indépendants trouvés en nettoyant les références à `POSTES` (deux fonctions lisaient une forme de données — `.titulaire` — qui n'a jamais existé dans la vraie structure, mortes depuis leur création).
  2. **Fonction de lookup unique** (`getTitulaireActuel`, remplace `getTitulairePoste`/`getTitulaireMaire`/`getTitulairePosteNomme`) — 25 appelants migrés un par un à travers 5 fichiers, jamais en masse. Trouve au passage : `getJugeActuel` ignorait les vrais titulaires PNJ enregistrés par la cascade ; deux flux d'acceptation de nomination ne nettoyaient jamais l'ancien titulaire PNJ périmé.
  3. **Le pont élection → pouvoir réel** (`appliquerVictoireElectorale`, appelée au chargement du personnage comme la nomination-en-attente déjà existante) — corrige la découverte la plus sévère ci-dessus.
  4. **Corrections ponctuelles** : révocation d'un commissaire/directeur par le maire (comparaison stricte cassée, jamais vraie pour un vrai maire), vote des lois par un député (lisait le mauvais champ, `state.poste` au lieu de `state.posteDepute`), migration ponctuelle du siège d'Arnie vers le nouveau modèle.
  5. **Ajustement du cron** pour la cohérence future (`poste_depute` désormais pris en compte par la cascade d'auto-provisionnement).
- **Corrections de mon propre audit d'hier**, faites en toute transparence pendant le travail : le cycle électoral présidentiel que j'avais annoncé "bloqué à jamais" ne l'était en fait pas (relecture attentive de la logique cron) — aucune intervention nécessaire, contrairement à ce qui était prévu.
- **Gap découvert mais volontairement hors périmètre** (pré-existant depuis la construction de la cascade le 8 août, pas introduit ce soir) : Commandant et les 4 Directeurs n'ont aucun repli PNJ dans la cascade d'auto-provisionnement — resteront vacants indéfiniment si aucun joueur ne postule, contrairement aux autres postes nommés. Noté en chantier ci-dessous.
- **Maire Adjoint** (×3 villes) disparaît — n'existait que dans l'ancienne table `POSTES`, jamais lu nulle part ailleurs dans le code, poste orphelin depuis toujours. À réintroduire explicitement dans `POSTES_NOMMES_EXCLUSIFS` si un vrai rôle est voulu pour lui un jour.

## ⚖️ Nouvelle mécanique : moyenne de groupe sur les caractéristiques
- **Idée** : la caractéristique du joueur utilisée dans un calcul de taux de réussite (défense, corruption, filature, débauchage, blocus...) est désormais remplacée par la **moyenne de cette caractéristique sur le groupe** (le joueur + ses employés `inGroupe`), pas juste sa propre valeur. Un groupe bien composé fait monter le taux, un groupe mal composé le fait baisser — pas une simple somme.
- **Constat de départ** : la mécanique était déjà *promise* dans la description de `recruter_informateur_pnj` ("sa PER enrichit la moyenne de PER de votre groupe") mais **jamais codée** — aucun consommateur nulle part. Un point d'accès central bien conçu existait déjà (`getStatEffective(stat)`, `plateau-organisations-quetes.js`) mais n'avait que 2 vrais appelants ; le reste du code lisait `state.char.stats.X` en dur, dispersé dans 6 fichiers.
- **Cœur du système** (`4b56232`) : nouvelle fonction `getMembresGroupeAvecStat(stat)` — un employé sans valeur pour la stat demandée (les PNJ n'ont que FOR/CHA/DUP/INT via `PNJ_STATS_PAR_JOB`, jamais VOL/ENT sauf override explicite comme le PER d'un informateur) est simplement absent du calcul, jamais traité comme 0. `getStatEffective` en fait la moyenne puis applique par-dessus le bonus de formation et l'affaiblissement HP comme avant. Rétrocompatible : joueur seul = comportement strictement identique à avant.
- **Déploiement complet** (décision de Fred : la bêta approche, un principe qui ne s'appliquerait qu'à 3 ordres sur 344 serait trompeur) — 38 sites migrés au total sur 6 fichiers, un commit par fichier : `plateau-justice-economie.js` (18), `plateau-pnj.js` (6), `plateau-actions-illegales-rumeurs.js` (5), `plateau-navigation.js` (7), `plateau-organisations-quetes.js` (1), `plateau-multijoueur.js` (1). Balayage final : plus aucune lecture directe des 6 vraies stats du joueur en dehors de `getStatEffective` (une lecture de la cible d'une filature, `supabase.js`, volontairement non touchée — ce n'est pas la stat du joueur qui agit).
- **Prochaine étape** : ancrer les 3 mini-missions de la quête carrière sur cette mécanique désormais réelle et partout active.

---

## 📰 `distribuer_tract` construit de zéro (référent politique Jean-Lou Zeure)
- Choix retenu avec Fred pour la branche politique de la quête carrière : plutôt que d'utiliser `doBlocusPortuaire` tel quel, injecter un vrai bonus CHA+ENT (via `getStatEffective`, donc conscient de la moyenne de groupe) dans `distribuer_tract` — qui était jusque-là à **taux fixe** et surtout **jamais implémenté** (`doDistribuerTract()` appelé par le routeur mais aucune définition nulle part → `ReferenceError` silencieuse au clic ; `requiresTract:true` sur sa déclaration `data.js` était donc mort deux fois).
- Construit intégralement ce soir (`69f06cb`) : `doDistribuerTract()`/`confirmerDistribuerTract(cible, tractType)` — taux `25 + CHA×3 + ENT×3` plafonné 10-90%, consomme un lot de tracts en inventaire (choix du lot si plusieurs), effet réel à la réussite (+/-POP sur la cible via `sbAjusterPopJoueur`).
- **Bug trouvé et corrigé en dépendance** : `sbAjusterPopJoueur` lisait/écrivait une colonne `personnages.pop` **qui n'existe pas** (vérifié en direct contre Supabase REST) au lieu du vrai champ JSON `resources.pop`. Corrigé — répare au passage `lancer_rumeur_cible`, qui utilisait le même helper cassé sans que personne ne l'ait remarqué.
- Fix confirmé fait comme convenu la fois précédente : `getGroupSize()` lisait `state.employees` (jamais rempli, faute de frappe) au lieu de `state.employes` — le bonus de taille de groupe (`organiser_blocus` etc.) ne comptait quasiment jamais les employés recrutés (`6f1a3f2`).

## 🖨️ Économie du bois à l'imprimerie La Tribune (approvisionnement de `distribuer_tract`)
- Investigation demandée avant tout code : la fabrication de tracts n'était reliée à **aucune** consommation de matière première. Le pattern "commerce possédé par un joueur + stock de matière vendable" existait déjà et fonctionnait (Armurerie : `vendre_matiere_armurerie`/`acheter_produit_stock`), sur le même modèle que les entrepôts/usines construits plus tôt cette session. Confirmé aussi : Luthécia n'a aucune matière première récoltable localement (`MATIERES_PREMIERES_VILLE` ne couvre que PSM/Montrouge) — l'Entrepôt Logistique est donc la seule source de bois pour un joueur de la capitale.
- Scénario complet demandé par Fred et codé tel quel (`a414969`) :
  - Gustave Rotative (La Tribune) a désormais son propre stock de bois et sa propre caisse (`batiments_etat`, même pattern que les entrepôts/usines).
  - `imprimer_tracts` existe pour la première fois à La Tribune (Luthécia) — jusque-là l'ordre n'existait qu'à l'imprimerie-librairie de PSM (Gutenberg), qui reste inchangée (argent seul, pas de bois). `confirmerImpression()` est devenue building-aware.
  - Si Gustave manque de bois pour le lot demandé, il le dit en personnage et invite le joueur à lui en vendre — pas d'échec silencieux, pas de facturation sans effet.
  - Nouvel ordre `vendre_bois_imprimerie` (sur le modèle de `vendre_matiere_armurerie`) : le joueur revend à Gustave le bois acheté à l'entrepôt, prix = cours actuel de l'entrepôt +10% (dynamique), paiement plafonné par la caisse de l'imprimerie (jamais de négatif, vente partielle si la caisse ne suit pas). Utilise la forme d'inventaire empilable (`stackKey:'bois'`) produite par l'entrepôt — distincte de la forme `matiere_premiere` de la récolte/armurerie, piège repéré avant de coder.
  - Recette dynamique de consommation : `boisParLot = 75 FR / prix du bois`, garantissant que le coût en bois ne dépasse jamais 50% du prix de vente du lot (150 FR/10 tracts) quel que soit le cours fluctuant du bois. Pas de coût de main d'œuvre modélisé.
  - `requiresTract:true` (mort jusque-là) est désormais satisfait fonctionnellement : `distribuer_tract` exige un vrai lot de tracts en inventaire, qui ne peut désormais exister qu'après un passage par ce circuit d'approvisionnement.
- **Principe de conception à garder pour la suite** : les 3 référents (Pat Hounette, Jean-Lou Zeure, Laurent Barre) doivent rester des PNJ consultables en permanence, pas des points de contact à usage unique — dialogue à structurer en dispatcher extensible plus tard, pas encore construit.
- **Suite et fin (même session, `e4bd7e2`)** : les 3 mini-missions et la scène de clôture sont maintenant codées et poussées.
  - **Scène de clôture** (`plateau-quete-accueil.js`) : chaînée à la toute fin des deux sorties existantes de la quête d'accueil (avec aide et sans aide). Jérémy demande l'ambition (criminel/politique/entrepreneurial/indécis), oriente vers le référent, explique répertoire puis recontact, conclut, puis quitte réellement le groupe à la fermeture (réutilise `quitterJeremy()` tel quel).
  - **Dispatcher des 3 référents** (`plateau-pnj.js`), indépendant du système de quête/enquête générique existant : nouvel état `state.char.queteCarriere` (ambition/étape/résultat/debriefVu). Zone d'action dédiée dans `openPnjModal` : brief à la rencontre, rappel si mission en cours, débrief une seule fois à la résolution (succès **ou** échec — les deux valent leçon), puis le référent redevient un PNJ consultable normal, prêt à recevoir d'autres mécaniques plus tard (pas un mécanisme jetable, comme demandé).
  - **Pat Hounette → `contrebande_port`** (DUP). **Jean-Lou Zeure → `distribuer_tract`** (CHA+ENT) : remet directement un lot de tracts POUR le joueur lui-même (cible toujours une vraie ligne Supabase valide), contourne volontairement le circuit d'impression/bois de La Tribune — hors sujet de cette leçon précise. **Laurent Barre → `negocier_squatteurs`** (CHA) : nouvelle fonction `demarrerMissionLaurentBarre()` qui place un squatteur garanti (profil sympathique, pas de minimum imposé) sur le Lot 4 de la Châtaigneraie, plutôt que de compter sur la génération aléatoire.
  - **Modal de négociation avec squatteurs rendu lisible** : affichage en direct du taux de réussite calculé (même formule que la résolution, jamais divergente), mis à jour à chaque frappe du montant — rend la moyenne de groupe (CHA) visible avant même de valider, pas juste subie comme un jet invisible.
  - **Bug bloquant découvert et corrigé en cours de route, sans rapport avec le travail du soir** : `calculerBonusOrga()` était appelée par `confirmerNegociation` **et** `doFaireDisparaitreCadavre` mais n'a jamais été définie nulle part — `ReferenceError` garantie à chaque appel, donc `negocier_squatteurs` et `faire_disparaitre_cadavre` plantaient systématiquement, depuis toujours. Les données de bonus par grade existaient déjà intégralement dans `ORGANISATIONS_DEF` (`nego_cha`, `dis`, `terrain_discount`...), juste jamais lues : fonction écrite dans `plateau-organisations-quetes.js` (meilleur palier par organisation, cumul entre organisations différentes).

---

## 🕍 Clarification Tabernacle des Impôts (religion vs fiscalité)
- Inventaire du bâtiment `tabernacle-impots` (Luthécia) : tout son contenu (2 salles, 8 ordres) est en réalité **100% religieux** (mécanique de l'indice IP, Moral, POP) — le vocabulaire fiscal ("Formulaire Sacré", "Percepteur Suprême") n'est qu'un habillage. Aucun doublon avec les vrais ordres fiscaux (mairie : `fixer_impots_locaux`/`repartition_budget_local` ; Ministère des Finances : `fixer_impots_nationaux`/`redressement_fiscal`/`fiscal`).
- Confirmé : le nom "Tabernacle des Impôts" est **canonique et volontaire** (objet `RELIGIONS`, `plateau-divers.js:248`) — la religion de Republia s'appelle le **Papyrusisme**, son temple s'appelle bien "Tabernacle des Impôts". C'est la fusion assumée religion/bureaucratie qui fait la blague (comme le Cocaïsme à El Estado, le Tractorisme à Sovarka, le Loukoumisme à Al-Khalija). **Décision : on garde le nom tel quel.**
- Bug annexe corrigé au passage : `EMPIRE_STYLES.republic.religion` valait `"le Tabernacle des Impôts"` (nom du temple) au lieu de `"le Papyrusisme"` (nom de la religion) — incohérent avec `RELIGIONS`. Corrigé (`ac8ebc7`).

---

## 🔍 Audit Ordres — inventaire des 344 ordres de Luthécia (préparatoire, avant le grand audit de la semaine prochaine)
- Classement des 344 ordres des 36 bâtiments de Luthécia en 4 catégories : **Fonction** (92, `requiresPost` renseigné), **Lieu** (212), **Rencontre** (23, cible un individu précis choisi/cliqué), **Autres** (17, actions méta ou cibles collectives). Critères détaillés et cas limites calibrés avec Fred avant classement.
- Au passage, **7 ordres trouvés sans aucun effet mécanique réel** malgré une description ou un coût qui en promettait un (jusqu'à 500 FR facturés pour rien) — voir section suivante.
- Niveau de vérification obtenu ce soir : seuls les **21 ordres au chemin générique** (pas de handler dédié) ont pu être vérifiés avec certitude contre `ORDER_EFFECTS`. Les **318 ordres routés vers un handler dédié** (`doOrder` → fonction spécifique) n'ont **pas** été vérifiés un par un — leur taux affiché vient de la déclaration dans `data.js`, pas d'une lecture du code réel.
- Résultat livré à Fred sous forme d'un inventaire interactif (tableau filtrable/triable, catégorie/difficulté/statut de vérification) plutôt que dans ce journal — trop volumineux pour être utile ici.

### 🐛 7 ordres sans effet réel — corrigés ce soir (`7df6a28`)
| Ordre | Bâtiment | Correctif appliqué |
|---|---|---|
| `investir` | Banque Nationale | Coût remis à 0 FR (était 500 FR pour un "rendement dans 24h" qui n'existe nulle part dans le code — aucun cron ne le traite) |
| `redaction_testament` | Office Notarial | Coût remis à 0 FR (était 500 FR — le code de succession applique toujours la dévolution par défaut, jamais un héritier désigné) |
| `contrat_mariage` | Office Notarial | Coût remis à 0 FR (était 400 FR — même souci, le régime matrimonial choisi n'est jamais lu) |
| `emprunter_prive` | Banque Privée | Routé vers le vrai système de prêt existant (`ouvrirModalPretBancaire('privee','consommation')`) — n'avait aucun handler avant |
| `consulter_succession` | Office Notarial | Routé vers `doConsulterArchivesNotariales()` — doublon orphelin d'un ordre déjà fonctionnel dans la même zone |
| `demander_adhesion` | Loge Maçonnique | Bouton retiré (`orders: []`) — aucun système de membres/parrain n'existe dans le code, le clic ne faisait jamais rien |
| `construire_sur_terrain` (×3, terrains 1/4/5) | Terrains à bâtir | **Non touché** — coût déjà nul (0 PA, 0 FR), donc aucun joueur lésé. Pas trouvé où/si la construction démarre réellement ailleurs — à investiguer lors de l'audit Ordres plutôt que de toucher un flux mal compris. |

---

## 🧭 Fix navigation PSM (Pôle Tabac/Entrepôt + carrefour Scierie/Artisanal)
- 3 rounds successifs, corrigés au fur et à mesure des retours de test en jeu réel :
  1. Image manquante sur `psm-pole-tabac-entrepot` (fichier jamais commité) + `flechesStyle` ajouté après inspection de l'image réelle.
  2. Retour arrière de `psm-carrefour-artisanal-scierie` d'abord "corrigé" via `liensParArrivee` — ne se déclenchait quasiment jamais en jeu (voir cause racine ci-dessous).
  3. **Cause racine trouvée et corrigée** : `rueCentraleDepuisNoeud` (la provenance, nécessaire à `imagesParArrivee`/`zonesParArrivee`/`liensParArrivee`) était perdue à **chaque sortie de bâtiment** (`showVueRue()` → `initialiserRueCentrale()` ne la transmettait jamais). Corrigé à la racine en propageant la provenance de bout en bout (`memoriserNoeudRueCentrale`/`obtenirNoeudRueCentraleMemorise` stockent désormais `{noeudId, depuisNoeudId}`). Bénéfice général au-delà de PSM : `psm-carrefour-musee` (3 bâtiments, 4 vues différentes selon provenance) et `psm-eglise-cimetiere` en profitent aussi. Rétrocompatible avec les anciennes sauvegardes localStorage.

---

## 🗳️ Bug électoral corrigé : le cas Arnie/Gaston Intérim expliqué
- Investigation demandée par Fred (candidature Arnie à la présidentielle, remplacée par le PNJ "Gaston Intérim faute de candidat"). Données Supabase réelles retrouvées : Arnie était bien seul candidat, élu à l'unanimité (3/3 votes PNJ), mais `eluId` n'a jamais été renseigné.
- **Cause racine, différente du fix d'hier sur `cycle.phase`** : `calculerResultatsServer` (`api/cron-minuit.js`) lisait `cycle.votes_pj`/`cycle.votes_pnj` — des champs qui n'existent nulle part ailleurs dans le jeu (toujours `undefined`). Résultat : `totalVoix` valait systématiquement 0, donc **aucune élection traitée par le cron n'a jamais pu déclarer d'élu**, quel que soit le nombre réel de votes. Corrigé pour lire les vrais champs `cycle.votes`/`cycle.votesPNJ`.
- Rejoué contre les vraies données Arnie après correctif (en Python, hors jeu) : élection bien déclarée à l'unanimité. **Ne réécrit pas rétroactivement l'historique Supabase** — Arnie reste non-élu dans l'archive, seules les prochaines élections sont concernées.

---

## 💼 Bureau National de l'Emploi (BNE) — nouveau, complet ce soir
- Revenu régulier pour un PJ sans poste politique : inscription volontaire → consultation d'offres → candidature, sur les 3 guichets existants (Luthécia, Montrouge, annexe PSM dans le Centre d'Affaires — trouvée par Fred, pas créée ce soir).
- **Catalogue** `OFFRES_EMPLOI_BNE` (`data.js`) : 7 offres de départ, jobs repris de `PNJ_STATS_PAR_JOB` (serveur, docker, hôtelier, secrétaire, commerçant, banquier, hôtesse), 3 portées (locale par ville / nationale / internationale — cette dernière juste étiquetée pour l'instant, pas de vraie mécanique inter-empire), salaire 200-450 FR/jour selon le poste (au-dessus du plancher universel de 150 FR/jour, en dessous des salaires politiques).
- **Pas de nouvelle table Supabase** (impossible en DDL avec la clé anon) : réutilise la table générique `batiments_etat` déjà existante, une seule entrée partagée par pays. `state.emploiBNE` n'est qu'un cache local, rafraîchi au chargement du personnage et après chaque action.
- **Règle de conflit** (demandée par Fred) : aucune situation active n'est jamais écrasée automatiquement. Postuler en ayant déjà un emploi BNE réserve la nouvelle offre et envoie un mail d'arbitrage (garder / prendre le nouveau) au lieu de trancher. Obtenir un poste politique en gardant un emploi BNE (possible via les 3 systèmes de postes parallèles, voir dette technique) est détecté par un nouveau passage du cron nocturne (`verifierConflitsEmploiBNE`), même mécanique de mail, rien n'est jamais tranché automatiquement.
- Incompatible avec un poste politique (vérifié à la candidature). Démission immédiate et gratuite.
- **Bug distinct repéré au passage** (voir chantiers en attente ci-dessous) : plusieurs mails envoyés par le cron utilisent probablement les mauvais noms de colonnes.
- **Image d'accueil mise à jour** (`bureau-national-emploi-luthecia.png`) — Fred a signalé que plusieurs images semblaient avoir disparu de l'affichage. Vérifié via `git log -p`/`git diff` sur les commits de ce soir touchant `data.js` (fix `buildingContext`, création de Jean-Lou Zeure) : **aucun des deux n'a touché la moindre ligne `imageUrl`**, et sur l'ensemble de la session une seule `imageUrl` a été retirée, volontairement (le remplacement Centre Multimodal PSM demandé en tout début de soirée). **Correction ultérieure (voir plus haut dans ce journal, fix `ba422bd`) : ma conclusion initiale ("pas une régression") était incomplète.** La scène de rue et la salle d'accueil du BNE partageaient le même fichier depuis la création du bâtiment ; la mise à jour d'hier soir (photo d'intérieur pour l'accueil) a bien silencieusement écrasé la photo de rue qui s'y trouvait avant — Fred avait raison de la signaler comme régression. Corrigé : ancienne photo de façade restaurée depuis l'historique git, sur un fichier séparé dédié à la rue.

---

## 🖼️ Pat Hounette (photo) + 🏦 Laurent Barre (invisible) — deux corrections PNJ
- **Pat Hounette** (Place du Formulaire de la Liberté) : n'avait en réalité **jamais** eu de `photoUrl` dans le code (vérifié sur tout l'historique git) — pas le même bug que les photos du Palais, juste jamais branchée. Fichier déjà présent sur le disque, jamais commité. Ajouté (`photoUrl` + `photoPos`).
- **Laurent Barre** (Directeur d'agence, Banque Nationale) : Fred ne le trouvait plus en jeu. Cause trouvée — un `buildingContext` obsolète (`WORLD.republic.capitale.buildingContext['banque-nationale']`, avec Bernard Coffre-Fort/Simone Intérêt) écrasait silencieusement le vrai contenu de la salle via la règle de priorité sur la première salle (`plateau-navigation.js:565` et `:91` pour la minimap). Entrée obsolète supprimée, Laurent Barre redevient visible sans rien déplacer — reste cohérent avec son rôle déjà établi dans l'énigme du portrait (coffre lié à la succession Thibault, situé à la Banque Nationale). Photo branchée dans la foulée (`photoUrl`, n'en avait pas non plus).
- **Même bug repéré ailleurs, pas corrigé** : `banque-privee` (Hans Von Discret masque M. Fischer), et potentiellement `commissariat`/`tribunal` (même bloc `buildingContext`, mêmes personnes issues de `PNJ_PERSONALITIES` jamais nettoyées après l'ajout des vraies salles/PNJ). À auditer.

---

## 🎯 Quête carrière (aiguillage par Jérémy) — script reçu et validé par Fred, pas encore codé
Extension de la quête d'accueil : après le tour actuel, Jérémy demande au joueur ce qu'il aimerait devenir et l'oriente vers un référent selon son ambition (Criminelle / Politique / Entrepreneuriale / Indécis), chaque référent proposant une mini-mission qui fait *expérimenter* sa logique plutôt que réciter les règles.
- **Investigation faite ce soir** : le squelette FSM de `plateau-quete-accueil.js` (`state.char.queteAccueil = {etape}`, `queteAccueilVerifierEtapeBatiment`, `afficherPopupQueteAccueil`) est directement réutilisable, y compris le motif `reprise_contact`/`choix_destination` (popup à boutons multiples) qui correspond presque exactement à l'aiguillage à 3 branches + indécis. Le "revenir plus tard" a aussi déjà un vrai précédent (`queteAccueilGenererReponseMailJeremy`, réponse IA + réapparition au Marché). Rien d'existant en revanche pour la mécanique "mini-mission avec objet à livrer" — mais `addToInventory`/`state.inventory` et le motif de `state.char.enigme1` (marqueurs de possession d'objet) donnent tout ce qu'il faut pour la construire.
- **Noms vérifiés, les 3 référents ont maintenant leur fiche PNJ + portrait, prêts pour coder les mini-missions** :
  - **Pat Hounette** (branche criminelle) — existait déjà, Place du Formulaire de la Liberté. Photo branchée ce soir (`photoUrl`, n'en avait jamais eu).
  - **Laurent Barre** (branche entrepreneuriale) — existait déjà, **Banque Nationale** confirmé (pas "banque d'affaires" du script initial — bâtiment inexistant). Était invisible en jeu à cause du bug `buildingContext` ci-dessus (corrigé), et n'avait pas non plus de photo — les deux corrigés ce soir.
  - **Jean-Lou Zeure** (branche politique) — n'existait nulle part (vérifié deux fois, y compris une re-vérification suite à une remontée de Fred). **Créé ce soir** : Bureau National de l'Emploi de Luthécia (`bureau-national-emploi`, salle `accueil`), rôle "Ancien Maire de Luthécia", avec photo. Juste la fiche PNJ pour l'instant — pas de dialogue ni de mini-mission, ça reste pour la session dédiée à la quête carrière.
- **2 décisions de conception à trancher avant de coder les mini-missions** (voir chantiers en attente) : le déclenchement de l'aiguillage, et ce que "le référent reste disponible comme point de repère durable" veut dire concrètement.

---

## 📝 Chantiers en attente (mis à jour — priorité aux 2 premiers points pour la prochaine session)

**Résolu depuis la première rédaction de cette liste ce soir :**
- ~~Quête carrière — 2 décisions de conception à trancher~~ → tranchées et codées (aiguillage chaîné à la fin des deux sorties existantes, référents consultables en permanence via un dispatcher dédié). Voir section dédiée plus haut.
- ~~Point 2 du chantier "priorité PJ"~~ → codé dans le cadre de la refonte des postes (étape 1, `demanderNominationPoste`) : un PJ qui postule auprès d'une autorité PNJ générique est désormais accepté directement.
- ~~Dette technique — 3 systèmes de postes parallèles~~ → refonte complète effectuée ce soir, voir section dédiée plus haut. Le bug `postulerPoste`/`getTitulairePoste` cité ici a disparu avec le reste du système.

**Résolu depuis (même session, reprise après la clôture) :**
- ~~Bouton `produire_arme` affiche "gratuit"~~ → corrigé (`e8380c2`) : cas spécial dans `renderRoomActions` (`plateau-politique.js`) qui affiche désormais le vrai tarif (2 PA, +100 FR) depuis `PA_PRODUCTION_ARMURERIE`/`SALAIRE_PRODUCTION_ARMURERIE`, source de vérité unique.
- ~~`vendre_matiere_armurerie` cassé~~ → corrigé (`e8380c2`), même principe que `vendre_bois_imprimerie` : lit désormais la forme d'inventaire empilable (`stackKey`) produite par un achat à l'entrepôt, plus l'ancienne forme "récolte" jamais atteignable à Luthécia.

**À reprendre en premier :**
1. ~~Détection douanière des objets prohibés~~ → **fait pour armes/poisons** (`possession_illegale_douane`, `plateau-navigation.js`/`plateau-core.js`/`plateau-justice-economie.js`) : contrôle déterministe (pas de jet de chance, une fouille physique trouve systématiquement) à `passer_douanes_aeroport`, confiscation des objets `type:'arme'`/`type:'poison'` avec `legal:false`, convocation au commissariat sous 24h (réutilise exactement le mécanisme existant de l'achat d'arme illégale raté — `state.convocations`/`se_justifier`/`traiterConvocations`).
   **Reste à faire, pas hypothétique** : la détection de la **drogue** — aucun type d'objet drogue n'existe encore dans le jeu, donc rien à filtrer ce soir. Mais ce n'est pas une idée lointaine : l'**Usine Pharmaceutique de Luthécia** peut déjà produire ce type de produit sensible, et **El Estado (narco-État)** est prévu comme gros producteur de drogue dans le jeu — la détection douanière de la drogue est un vrai chantier à court terme, à cadrer dès qu'un système d'objets "drogue" existera (production, inventaire, légalité selon l'empire).
2. **Main d'œuvre de production — pilote Armurerie fait le 9 août, reste à dupliquer** sur Usine Pharmaceutique/Pôle Tabac & Alcools/Raffinerie/Entrepôts Logistiques une fois validé en jeu (voir section dédiée plus haut).
3. **Gap découvert le 9 août en refaisant les postes, volontairement pas traité** : Commandant et les 4 Directeurs (pharma, tabac/alcools, raffinerie, entrepôt) n'ont aucun repli PNJ dans la cascade d'auto-provisionnement (`PNJ_PAR_DEFAUT_POSTE`/`CASCADE_NATIONALE`, `api/cron-minuit.js`) — resteront vacants indéfiniment si aucun joueur ne postule, contrairement à Président/PM/6 ministères/Juge/Maire/Commissaire. Pré-existant depuis la construction de la cascade le 8 août.
4. **Maire Adjoint (×3 villes) disparu** avec le retrait de l'ancienne table `POSTES` le 9 août — poste orphelin qui n'était lu nulle part ailleurs. À réintroduire explicitement dans `POSTES_NOMMES_EXCLUSIFS` si un vrai rôle est voulu.

**Backlog déjà connu, pas prioritaire :**
4. **Grand audit Ordres, prévu la semaine prochaine** — portée précisée le 9 août : vérifier un par un les **318 handlers dédiés** non couverts par la vérification du 9 août (confirmer que chacun applique bien un effet cohérent avec sa description), plus élucider le cas `construire_sur_terrain` (flux de démarrage de chantier non identifié). Bons candidats à y intégrer : le bug des mails `destinataire`/`expediteur` (point 6 ci-dessous) et l'audit `buildingContext` (point 7).
6. **Audit PNJ** — prévu avant la bêta, pas encore fait (état des ~18 points d'appel IA hors périmètre de la fondation `PNJ_PROFILS` posée le 8 août).
7. **Tâche optionnelle** : décrets automatiques du PNJ Président (à décider si prioritaire).
8. **Tableau Excel PNJ** à mettre à jour avec les nouveaux PNJ créés le 8 août (cascade de nomination automatique, postes de Directeur usine/entrepôt), plus Jean-Lou Zeure une fois créé pour la quête carrière.
9. **Idée backlog (session future)** : annonces d'emploi **entre joueurs**, notamment pour des jobs illégaux (ex: un PJ recrute un autre PJ pour un coup précis), en complément du Bureau National de l'Emploi (offres officielles/légales, codé le 9 août).
10. **Bug probable, pas corrigé** : dans `api/cron-minuit.js`, plusieurs envois de mail existants (relances de chantier impayé, avertissements de prêt...) utilisent des noms de colonnes (`destinataire`/`expediteur`/`sujet`/`corps`) différents de ceux relus par le client (`to_player`/`from_player`/`subject`/`body`, voir `sbGetMailsFor`/`plateau-communication.js`). Vraisemblablement le même type de bug que celui du cycle électoral corrigé le 9 août (`votes_pj`/`votes_pnj`) — ces mails ne doivent jamais arriver dans la boîte de réception des joueurs concernés.
11. **Bug `buildingContext` vestige, corrigé seulement pour `banque-nationale`** : `WORLD.<pays>.<ville>.buildingContext[<batimentId>].persons` écrase silencieusement le vrai contenu de la première salle d'un bâtiment (`plateau-navigation.js:565` + minimap `:91`), avec des noms de `PNJ_PERSONALITIES` jamais nettoyés après l'ajout des vraies salles/PNJ dans `BUILDINGS`. Repéré aussi sur `banque-privee` (Hans Von Discret masque M. Fischer) — probablement `commissariat`/`tribunal` aussi (même bloc). À auditer entièrement (tous pays/villes) plutôt que de corriger bâtiment par bâtiment au fil des demandes de Fred.
12. **Images "disparues" signalées par Fred en toute fin de session** : un cas concret vérifié et **corrigé** (nœud de rue du BNE Luthécia — régression confirmée, voir section BNE ci-dessus et fix `ba422bd`). Fred a parlé de **plusieurs** images au pluriel ; je n'ai vérifié que celle-là. Le mécanisme identifié (deux endroits différents — salle de bâtiment / nœud de rue — partageant silencieusement le même fichier image, l'un des deux se faisant écraser dès que l'autre est mis à jour) est un piège structurel à garder en tête : si d'autres images semblent avoir "disparu", vérifier en priorité si le fichier concerné est référencé à plus d'un endroit avant de conclure à une suppression.
13. **Bug `getGroupSize()` repéré en construisant la mécanique de moyenne de groupe, pas corrigé** : cette fonction (`plateau-multijoueur.js:1343`) lit `state.employees` (avec un "s", au pluriel) comme repli quand `state.group` n'est pas défini — un champ qui n'est **jamais rempli nulle part** dans le code (seul `state.employes`, sans "s", existe réellement). Conséquence : `organiser_blocus` (et tout ce qui utiliserait `getGroupSize()`) ne compte quasiment jamais les employés recrutés dans la taille du groupe, seulement le joueur seul. Adjacent au chantier "moyenne de groupe" de ce soir mais volontairement pas touché — à traiter séparément. **(Corrigé depuis — voir plus haut dans ce même journal.)**
14. ~~Main d'œuvre absente du système de production~~ → **pilote fait ce soir sur l'Armurerie** (voir section dédiée en haut de journal, point 3 ci-dessus). Reste à dupliquer sur les autres bâtiments à stock/caisse.
15. **Refonte du forum** : interface/design jugés peu accueillants ou confus par Fred. Sujet UX/design pur, à creuser en détail lors d'une session dédiée (pas de diagnostic technique fait ce soir).
16. **Audit RLS systématique de toutes les tables Supabase** (demande explicite de Fred, 9-10 août) : `batiments_etat`, `prets`, `compromis_historique` et `entreprises` avaient chacune un problème RLS latent (insert et/ou delete silencieusement bloqués selon la table), découverts un par un par accident au fil de la nuit plutôt que détectés proactivement. Faire l'inventaire complet des tables du projet et vérifier l'état RLS + les policies de chacune, plutôt que d'attendre qu'un nouveau chantier tombe dessus par hasard.

---

# Journal de session — Res Publica (8 août 2026)

## État du dépôt
- Toutes les modifications ont été committées et poussées sur `main` (7 commits).
- Reste des fichiers `patch_*.py` non trackés dans le dépôt (scripts ponctuels utilisés pour appliquer certains correctifs) — sans impact, cohérent avec la pratique habituelle de la session.

---

## 🐛 Fix critique : cron entrepôt (bug de fond, corrigé en premier)
- **Cause racine** : `sbGetBatimentEtat`/`sbSetBatimentEtat` manquaient dans le cron nocturne → le stock des entrepôts n'était jamais réellement alimenté malgré les livraisons programmées.
- Corrigé (`d2a451e`). Ce bug bloquait silencieusement toute la mécanique entrepôt/production en aval — corrigé avant tout le reste de la session car les tableaux de bord Directeur en dépendaient.

---

## 💰 Affichage des caisses entrepôts/usines
- Caisse (solde) désormais visible dans l'en-tête du bâtiment, pour tous les joueurs présents (`8b803c0`).

---

## 🏭 Tableau de bord Directeur d'usine (mode PJ, V1 complet)
- Poste de Directeur PJ sur les 3 usines stratégiques : prix de vente directe réglable (±40% du prix de base), répartition production entrepôts/vente directe réglable, salaire quotidien plafonné (500 FR/j) par la caisse de l'usine.
- Présence PNJ par défaut masquée dès qu'un PJ est nommé au poste (`1c0f537`).

## 🏬 Tableau de bord Directeur d'entrepôt
- Poste nommé par le Maire (local, `scope:'ville'`) : prix d'achat réglable ±40%, salaire quotidien 500 FR/j plafonné par la caisse — caisse désormais réellement alimentée par les achats des joueurs (le bug corrigé plus haut : l'argent disparaissait sans jamais créditer la caisse).
- Affichage du directeur en poste (PJ ou PNJ) dans l'en-tête du bâtiment, appliqué aussi rétroactivement aux 3 usines.
- Au passage, correction de 3 fonctions maire cassées depuis l'élection du maire (comparaison exacte au lieu de `startsWith`) : `nommer_commissaire`, `financer_communal`, `traiter_demandes_permis` (`ccefa84`).

---

## 🧠 Fondation de la fiche PNJ enrichie
- Suite à l'audit du système de dialogue IA : nouvelle table `PNJ_PROFILS` (traits, savoirs, fonction pédagogique, secrets, objectifs, rumeurs, notes), même clé que `PNJ_PERSONALITIES`.
- Remplissage partiel assumé — un seul PNJ enrichi pour l'instant en exemple : **Gérard Poinçon** (gardien du musée).
- `talkToPnj` lit désormais ce profil quand il existe et l'injecte dans le prompt, avec repli gracieux total pour les PNJ non enrichis (comportement inchangé pour tous les autres). Les ~18 autres points d'appel IA restent volontairement hors périmètre pour cette session (`ea8f8b8`).

---

## 🖼️ Images restaurées / branchées
- **5 images du Palais Présidentiel/Gouvernement** jamais commitées depuis le 22 juillet (chef de cabinet, protocole, garde républicain, secrétaire générale, porte-parole) — laissaient ces photos cassées en production.
- 2 images PSM déjà existantes mais jamais reliées : Port Industriel (`quai_principal`, remplace un placeholder générique) et Port de Plaisance (`quai`, n'avait aucune image du tout) (`a18ee30`).

---

## 🗳️ Renouvellement du calendrier électoral + cascade de nomination automatique
*(bugs remontés par Fred le 8 août 2026)*
- Les mandats (5 semaines, déjà prévu dans `POSTES_ELECTIFS` mais jamais branché) déclenchent désormais un nouveau cycle de candidatures à échéance, PJ ou PNJ.
- Bug connexe corrigé : `cycle.phase` était mis à `'vacant'` même en cas de victoire, ce qui empêchait le calendrier d'afficher correctement "Mandat en cours" ou "Campagne 2nd tour".
- Quand un cycle conclut à "vacant" (0 candidat), un **PNJ générique prend immédiatement le poste** (résolution en un seul passage du cron), sur le périmètre président → PM → 6 ministères → juge et maire → commissaire par ville — évite qu'un poste vacant bloque indéfiniment les nominations en cascade en dessous.
- Périmètre volontairement restreint (hors commandant/directeurs, déjà fonctionnels sans titulaire), scope Republia uniquement comme le reste du système électoral/fiscal (`43c4f1b`).

---

## 🧭 Fix navigation retour Luthécia/PSM (bug 3)
- **Cause racine** : `getBuildingIdCentreMultimodal` utilisait `'port-sainte-marie'`/`'montrouge'` comme clés alors que les appelants passent toujours `'ville_a'`/`'ville_b'` — un voyage vers PSM ou Montrouge générait un id de bâtiment inexistant et `enterBuilding` échouait silencieusement (**Montrouge était donc cassé aussi, pas seulement PSM**).
- Fonction rendue consciente de l'empire pour éviter qu'un joueur d'un autre empire entre dans un bâtiment Republia par erreur.
- Nouvelle fonction `trouverNoeudRueCentralePourBatiment`, appelée à l'arrivée d'un voyage pour repositionner le souvenir de rue centrale sur la scène du Centre Multimodal réellement atteint, au lieu de laisser le joueur retomber sur la dernière scène visitée dans cette ville en sortant du bâtiment — parfois périmée de plusieurs jours.
- Ajout d'un repli vers la rue si le bâtiment d'arrivée n'existe pas (`confirmerTransport` n'en avait aucun) (`8117d0d`).

---

## 📝 Chantiers en attente
1. **Audit PNJ** — prévu avant la bêta, pas encore fait (état des ~18 points d'appel IA hors périmètre de la fondation `PNJ_PROFILS` posée ce soir).
2. **Audit Ordres** — prévu avant la bêta, pas encore fait.
3. **Tâche optionnelle** : décrets automatiques du PNJ Président (à décider si prioritaire).
4. **Tableau Excel PNJ** à mettre à jour avec les nouveaux PNJ créés aujourd'hui (notamment ceux générés par la cascade de nomination automatique et les postes de Directeur usine/entrepôt).

---

# Journal de session — Res Publica (30 juillet 2026)

## État du dépôt
- Toutes les modifications ont été committées et poussées sur `main`.
- **Changement de session prévu à la fin de ce journal** : la prochaine session reprend directement sur Luthécia (voir priorités en fin de journal).

---

## 🐛 Corrections diverses (poursuite du debug d'hier, sur Luthécia cette fois)

1. **Voile sombre trop fort sur les images de pièces** : deux couches d'assombrissement se cumulaient — un dégradé JS dans `plateau-navigation.js` (ligne ~454, corrigé de 50% à 15% de noir en bas) ET un second voile CSS `::before` sur `.piece-image` dans `style.css` (allant jusqu'à 88% de noir, la vraie cause principale, réduit à 35% et concentré sur les 35% inférieurs de l'image). **Les deux fixes sont en place et validés par Fred ("bien mieux !").**
2. **Image de la Place du Formulaire de la Liberté** : depuis sa création le 15 juillet, le fichier `place-formulaire-liberte.png` contenait en fait une image d'autruche entravée (erreur de `mv` à l'origine, jamais un écrasement ultérieur — un seul commit a touché ce fichier). Fred a retrouvé la vraie image dans ses téléchargements (14 juillet 22h31) et on l'a remise en place.

### Leçon générale sur les erreurs de fichiers
Deux catégories de bugs récurrents identifiées sur toute la session : (1) noms de fichiers dans `~/Downloads` qui utilisent espaces/accents/casse différents de ce que Claude suppose — toujours vérifier avec `ls | grep` avant un `mv` s'il n'a pas été confirmé explicitement ; (2) `git add` avec plusieurs fichiers échoue **intégralement** si un seul chemin n'existe pas — même les fichiers valides de la commande ne sont alors pas committés.

---

## 🏛️ Luthécia — Création des deux Musées (nouveau grand morceau de contenu)

- **Nouvelle scène de rue** `luthecia-musees`, insérée entre le carrefour `luthecia-intersection-stade-commercial` et `luthecia-quartier-ambassades` (liens recâblés dans les deux sens). Les deux musées sont face à face sur la même rue.
- **Musée de la Ville de Luthécia** : structure identique au Musée de Port-Sainte-Marie (hall + 10 salles thématiques : Criminels, Maires, Personnalités, Entrepreneurs, Organisations, Plumes, Honneur Militaire, Unions Célèbres, Dynasties, Scandales). Images du hall intégrées.
- **Musée National de Republia** : structure complète également (hall + 10 salles), avec deux salles supplémentaires spécifiques au niveau national par rapport au modèle de ville :
  - **Salle des Grandes Villes de Republia** : les maires des différentes villes du pays entrent en compétition pour la reconnaissance nationale de leur cité (méta-classement inter-villes).
  - **Salle des Plus Grands Criminels du Pays** : même logique de compétition inter-villes côté criminalité.
  - Plus : Salle des Présidents, Salle des Pères Fondateurs, Panthéon National, Salle d'Honneur Militaire Nationale, Salle des Relations Diplomatiques (clin d'œil : juste à côté du Quartier des Ambassades), Salle du Trésor National, Salle des Grandes Réussites Économiques, Salle des Scandales d'État.
- Positions ajoutées à `PLAN_LAYOUTS.capitale` (entre Quartier des Ambassades et Stade, coordonnées estimées à ajuster si besoin) + icônes `PLAN_ICONS`.
- **Aucune mécanique de classement/vote n'est codée** pour l'instant — uniquement la structure et les noms des salles, comme convenu (placeholders "Contenu à venir" / "Classement à venir").

---

## 🔄 GROS PIVOT ANNONCÉ EN FIN DE SESSION

Fred a annoncé vouloir **terminer complètement le codage de Luthécia**, ce qui implique nécessairement de coder le **système économique complet** (production/marchés/jauges PJ/géopolitique, voir détail dans l'entrée du 29-30 juillet précédente) — bien plus large que le simple "reprendre le tour des bâtiments" évoqué initialement.

**Ordre de priorité entre i18n et système économique NON tranché** — Fred avait dit vouloir faire l'i18n avant l'économie (pour éviter d'avoir à retraduire), mais n'a pas reconfirmé cet ordre au moment du pivot. **Point à trancher explicitement en début de prochaine session.**

---

## 📝 Chantiers en attente (mis à jour, ordre indicatif à revalider)
1. **Décider l'ordre : i18n d'abord, ou système économique d'abord** (voir pivot ci-dessus).
2. **Terminer Luthécia** : finir le tour des bâtiments restants (état exact non ré-audité ce soir — repartir de l'audit du 27 juillet si besoin, plusieurs sessions ont pu faire avancer les choses depuis).
3. **Système économique de production** complet (voir détail 29-30 juillet : production par ville, marchés, jauges PJ, dimension géopolitique eau/pétrole, inspiration parodique par empire).
4. **Système i18n** (`t("clé")` + fichiers `fr.json`/`en.json`, audit d'ampleur non fait, potentiellement des milliers de chaînes en dur).
5. Vrai fix JS pour le mode plein écran de la navigation de rue (PSM) — fix CSS temporaire en place (`max-height: 78vh`), imparfait.
6. Auditer les autres scènes PSM à risque de chevauchement zones/flèches (yPct) — non fait systématiquement.
7. Quête Yann Le Goff (calendrier, mécanique de communication, récompense) — contours posés uniquement.
8. Contenu réel des salles vides : Musée PSM (7/10 sans image), Musée National Republia (10/10 sans image), Musée Ville Luthécia (9/10 sans image), Port Industriel PSM (5 salles placeholders).
9. Mécanique de classement/vote des musées (stats + votes, historique des anciens détenteurs) — jamais développée, juste évoquée en principe.
10. Calendrier électoral pas à jour, photo du Chef de Cabinet qui ne charge pas, réorganisation du dossier `images/` en sous-dossiers.

# Journal de session — Res Publica (28-29 juillet 2026, nuit)

## État du dépôt
- Toutes les modifications ont été committées et poussées sur `main`.
- **Régression identifiée en fin de session, non résolue** : positionnement des flèches directionnelles cassé sur plusieurs scènes de rue PSM, et certaines flèches ne déclenchent plus le déplacement. Semble lié à une confusion entre le système de flèches rondes (`rc-fleche`, géré par `flechesStyle`/`stylesParDefaut` dans `plateau-rue-centrale.js`) et des panneaux directionnels visibles différemment sur la capture (voir `bug.jpg` fourni par Fred). **À investiguer en priorité à la prochaine session**, potentiellement côté CSS (feuille de style qui gère `.rc-fleche` ou un système de panneaux plus récent non repéré ce soir).

---

## 🗺️ Navigation rue par rue de PSM — TERMINÉE (12/12 scènes)

Toutes les scènes suivantes ont été codées dans `plateau-rue-centrale.js` cette nuit :
1. `psm-carrefour-musee` (Musée/Centre Commercial/Centre d'Affaires, 4 images selon arrivée)
2. `psm-carrefour-artisanal-scierie`
3. `psm-centre-multimodal` (point de départ officiel `RUE_CENTRALE_DEPART.republic.ville_a`)
4. `psm-ecole-phare`
5. `psm-dispensaire-port-plaisance`
6. `psm-tribunal-banque`
7. `psm-bar-imprimerie-commissariat`
8. `psm-marche-resto-chasse` (zone Marché → bâtiment `marche-psm`, pas une scène de rue)
9. `psm-hotel-mairie-place`
10. `psm-eglise-cimetiere` (zone unique → bâtiment fusionné, voir ci-dessous)
11. `psm-chantier-naval`
12. `psm-terrains-vente` → sous-scène `psm-terrains-lots` (5 lots, sur le modèle de `luthecia-terrains-lots`)

### Bugs corrigés en cours de route
- Zones Hôtel du Port / Place d'Armes inversées : corrigé.
- Zone Marché qui menait à tort vers la scène de rue Église/Cimetière au lieu d'ouvrir le bâtiment `marche-psm` (déjà existant avec son propre contenu) : corrigé.
- `notre-dame-mer` et `cimetiere-marin` étaient deux bâtiments séparés sans hall commun ; fusionnés en un seul bâtiment `notre-dame-mer` avec un hall d'accueil (nouvelle image), la salle `nef` existante, et une nouvelle salle `tombe` (placeholder, contenu à venir). `cimetiere-marin` retiré de la liste des bâtiments PSM.
- Plusieurs `flechesStyle` ajoutés pour corriger des positions par défaut inadaptées (voir régression ci-dessus : correction possiblement incomplète ou en conflit avec autre chose).

### Reste à faire
- **Régression flèches à corriger en priorité** (voir en tête de journal).
- Vérifier le carrefour Centre Artisanal/Scierie : accepté avec un seul retour fixe à l'origine (une seule entrée connue), mais a maintenant 2 entrées (Terrains à vendre + Musée) — vérifier la cohérence de navigation en jouant.
- Contenu de la salle "Tombe" (cimetière) à concevoir.
- Sous-scène des 5 lots PSM : xPct des lots posés à l'oeil, à vérifier/ajuster en jouant.

---

## 🏛️ Musée de Port Sainte Marie — création + contenu

- Bâtiment complet créé (`musee-port-sainte-marie`) : hall d'accueil (PNJ Soizic Le Gall à l'accueil, Yvon Le Gall conservateur) + 10 salles thématiques (Criminels, Maires, Personnalités, Entrepreneurs, Organisations, Plumes, Honneur Militaire, Unions Célèbres, Dynasties, Scandales).
- **Contexte narratif acté avec Fred** : Port-Sainte-Marie appartient historiquement à deux familles rivales, les **Le Gall** et les **Le Roux** — traité de façon parodique. Gentilé des habitants : **"Mariannais"**.
- **Principe du musée** : immortaliser/classer les meilleurs (et pires) joueurs par catégorie, mélange de stats et de votes (mécanique de calcul à détailler plus tard, différente selon les catégories — ex: un rôliste ne se juge pas aux mêmes critères qu'un min-maxer). Historique des anciens détenteurs de chaque titre à conserver (mémoire du jeu).
- **Images de salles reçues et intégrées ce soir** : Maires, Criminels, Personnalités. Il reste 7 salles sans image (Entrepreneurs, Organisations, Plumes, Honneur Militaire, Unions Célèbres, Dynasties, Scandales) + l'image du hall (reçue et intégrée en toute fin de session).
- **Prévu pour plus tard** : dupliquer ce même principe de musée à Luthécia, avec deux musées distincts (ville + pays).

---

## 🖼️ Méthode de travail Blender — bilan de la session précédente, confirmé validé cette nuit

- Décision actée : Blender n'est utilisé que ponctuellement, pour les scènes où le générateur d'images échoue à produire une composition cohérente — pas systématiquement. Confirmé efficace cette nuit : plusieurs scènes de rue PSM ont été générées directement par IA sans passer par Blender, avec de très bons résultats (ex. église/place d'armes/fortifications, carrefour Musée sous 4 angles).
- Workflow qui fonctionne bien : donner au générateur d'images une image de référence existante + des instructions précises de repositionnement/correction, plutôt que de tout décrire depuis un prompt texte vierge à chaque fois.
- **Piège récurrent identifié cette nuit** : les noms de fichiers réels dans `~/Downloads` de Fred diffèrent souvent de ce qu'on suppose (espaces vs underscores, accents, casse) — **toujours vérifier avec un `ls | grep` avant de lancer un `mv`** si le nom n'a pas été confirmé explicitement.
- Autre piège identifié : une image simplement affichée dans une conversation ChatGPT (URL `blob:...`) n'est pas automatiquement enregistrée sur le disque — il faut un vrai clic droit "Enregistrer l'image sous..." avant de pouvoir la déplacer/committer.

---

## 📝 Chantiers en attente (rappel)
- **Régression flèches de navigation PSM (priorité absolue prochaine session)**.
- Calendrier électoral pas à jour.
- Photo du Chef de Cabinet qui ne charge pas.
- Réorganiser le dossier `images/` en sous-dossiers (pays/ville/PNJ/bâtiments) — session dédiée à prévoir.
- Terminer les 7 salles du Musée restantes (images + éventuel contenu).
- Concevoir le centre frigorifique de PSM (matières périssables, poisson).
- Une fois PSM stabilisé : retour prioritaire sur **Luthécia** pour finir le tour des bâtiments (objectif principal de Fred), avant de revenir sur PSM par petites touches.
# Journal de session — Res Publica (28 juillet 2026)

## État du dépôt
- Session consacrée exclusivement au blockout 3D Blender pour PSM (pas de code touché, rien à committer côté `plateau.html`).

---

## 🎥 Blender — apprentissage et méthode validée

### Interface et raccourcis clavier
- Le clavier Mac de Fred n'a pas de pavé numérique, et plusieurs raccourcis standards (G, E, Tab pour mode édition) ne répondent pas dans son environnement. **Toujours passer par les menus** (Vue, Objet, Maillage) plutôt que par les raccourcis clavier tant que la cause n'est pas identifiée.
- Navigation viewport au trackpad : pincement à deux doigts pour zoomer (fonctionne bien). "Cadrer sur tout" redézoome sur toute la scène (normal) ; préférer "Voir la sélection" pour rester zoomé sur un objet précis.
- Positionner le curseur 3D : avec l'outil "Curseur 3D" actif dans la colonne d'outils à gauche, un simple clic gauche sur le viewport suffit (pas besoin de Maj+clic droit).
- "Sélection vers curseur" (Maj+S) copie X, Y **et Z** du curseur — penser à rectifier le Z ensuite si le curseur était au sol.
- Une caméra sélectionnée n'est pas forcément la caméra **active** de la scène (celle affichée en vue caméra) : utiliser Vue → Caméras → "Définir l'objet actif comme caméra".

### Plan de ville PSM importé
- Le plan (image de référence PSM) est un **Objet vide de type Image**, donc sans géométrie éditable (pas de mode édition possible, pas d'extrusion).
- Échelle réelle du plan : **Taille = 6.3m** pour l'ensemble de la carte (~30 bâtiments) → chaque bâtiment individuel ne fait que 0.2 à 0.5m de large dans la scène. Point de repère essentiel pour toute la suite (échelles caméras, cubes, etc.).

### Rues de PSM — nommées et tracées
Sept rues ont été définies et tracées sur un schéma de principe (à corriger/compléter librement si besoin en avançant) :
1. **Rue de la Corniche** — axe nord-sud, est de Notre-Dame de la Mer / Cimetière Marin
2. **Rue Tanguy Le Roux** — axe nord-sud, sépare quartiers ouest/est
3. **Rue des Quais** — bordure est, dessert Port Industriel et Port de Plaisance
4. **Rue des Artisans** — axe est-ouest, sépare nord/sud
5. **Rue de la Mairie** — quartier sud-ouest, dessert Place d'Armes/HDV
6. **Rue du Palais** — quartier sud-est, dessert Tribunal/Banque
7. **Rue du Marché** — diagonale, de Capitaine Sauvage/Chasse&Pêche à l'arrière de la Place d'Armes

### Méthode de caméra validée — vue "place publique" (plongée)
Pour une place avec plusieurs bâtiments cliquables à identifier (ex. Place d'Armes/HDV/Hôtel du Port), sur plan 2D plat, sans volume :
- Position Z ≈ 4-9m, Rotation X ≈ 40-65° (plongée douce), Rotation Z ajustée à l'orientation voulue, focale à ajuster au jugé (essais de 24mm à 100mm selon le cadrage voulu).
- **Valeurs qui ont fonctionné pour `Cam_RueMairie_01`** : Position (X=-4.5, Y=-1, Z=4), Rotation (X=40°, Y=0°, Z=285°), Focale=100mm.
- Méthode : dupliquer une caméra existante déjà bien réglée plutôt que repartir de zéro, positionner via curseur 3D + "Sélection vers curseur", puis ajuster à la main par tâtonnement en vue caméra (plus fiable que de calculer des coordonnées a priori).

### Test de vue "piéton" (corridor de rue) — en cours
- Sur un plan 2D plat, **impossible d'obtenir une vraie vue horizontale de type corridor** (façades qui encadrent la vue) : la caméra regarde par-dessus le plan et voit l'horizon à perte de vue. Ce n'est pas un bug, c'est une conséquence de l'absence de volume.
- Premier test de solution : ajout de deux cubes bruts (sans texture) représentant les volumes de Capitaine Sauvage et Chasse&Pêche, à l'échelle du plan (env. 0.3-0.5m de large, 8m de haut → Échelle Z=4 sur cube standard 2m).
- Caméra piéton `Camera_RueMarche.002` positionnée entre les deux cubes, Z=1.7m (hauteur d'yeux). Premiers essais concluants pour voir les bâtiments encadrer l'espace, mais réglage encore à peaufiner (distance/reculs, angle pour voir les bâtiments "en pied" du sol jusqu'en haut) — **non finalisé, à reprendre**.

### ⚠️ Décision importante sur l'usage de Blender
Blender ne doit **pas être utilisé systématiquement** pour chaque rue/scène. Principe retenu :
- Si le générateur d'images produit déjà un résultat satisfaisant directement (sans passer par Blender), **on garde ce résultat tel quel**, sans perdre de temps à reconstruire la géométrie dans Blender.
- Blender n'est utile que pour les cas où le générateur d'images échoue à produire une composition cohérente (comme la Rue du Marché), ou pour garantir une géométrie stable réutilisable dans le temps (plusieurs angles/moments d'une même rue).
- **Workflow prévu** : fournir au générateur d'images à la fois (1) le rendu Blender basique (composition/perspective/géométrie) et (2) une photo de référence de style (ambiance, architecture, lumière) pour guider le rendu final. Pas de reproduction pixel-perfect attendue, mais une approximation stylistique cohérente.

---

## 📝 Chantiers en attente (rappel, non traités cette session)
- Calendrier électoral pas à jour.
- Photo du Chef de Cabinet qui ne charge pas.
- Réorganiser le dossier `images/` en sous-dossiers (pays/ville/PNJ/bâtiments) — actuellement tout à plat.
- Concevoir le système de musée (local + national) plus en détail.
- Concevoir le centre frigorifique de PSM (matières périssables, poisson).
- Navigation rue par rue de PSM : coder tous les nœuds dans `plateau-rue-centrale.js` une fois les images prêtes (voir détail complet dans l'entrée du 27 juillet ci-dessous).
- Rue du Marché : finaliser le test de caméra piéton avec volumes (distance, angle "en pied"), ou abandonner cette rue au profit d'un rendu direct par générateur d'images si le résultat Blender ne progresse pas rapidement.

# Journal de session — Res Publica (27 juillet 2026)

## État du dépôt
- Toutes les modifications de cette session ont été committées et poussées sur `main`.
- Dernière version dans `plateau.html` : `v=85`

---

## 🔨 Chantiers livrés cette session

### Bugs de fond corrigés
- **Indices (INF/HP/etc.) qui retombaient au rafraîchissement** : cause racine trouvée — `applyCharToState()` recalculait `state.inf/pop/dis` à partir de `char.resources`, jamais synchronisé après la fusion Supabase. Corrigé (synchronisation ajoutée avant le second appel).
- **Sauvegarde automatique périodique** ajoutée (toutes les 30s) comme filet de sécurité général.
- **Mauvais bâtiment affiché au rafraîchissement lors d'un changement de ville** (ex: "Centre Multimodal de Luthécia" alors qu'on est à PSM) : cause racine trouvée — un `fallback` bugué (`state.currentBuilding || state.char.currentBuilding || null`) empêchait `null` (= dans la rue) d'être jamais réellement sauvegardé. Corrigé à 3 endroits (`updateUI` x2, taxi). Idem pour les voyages train/bus/avion/bateau (`executerVoyage`, `confirmerTransport` dans `plateau-navigation.js`).
- **Repli "nouveau personnage" qui plaçait à tort un joueur existant dans la mairie** au lieu de le laisser dans la rue : corrigé (vérifie aussi l'absence de `currentCity` connue).
- **Arrivée par transport** : le joueur entre désormais directement dans le hall du centre multimodal de la ville de destination (via `enterBuilding`), au lieu d'atterrir dans la rue. Un bug de superposition de scène (l'ancienne scène de rue restait affichée en fond) a aussi été corrigé dans `enterBuilding()`.
- **Candidature au poste de Maire cassée** (`buildingId is not defined`) : corrigée dans `plateau-router.js`.
- **Poste de Député écrasait le poste principal** (PM/Ministre/Président/Maire) au lieu de se cumuler : Député vit désormais dans un champ séparé (`state.posteDepute`), persisté et affiché indépendamment.
- **`escortActive` n'était jamais sauvegardé dans Supabase** (contrairement à `employes`) : corrigé — prérequis pour le débauchage entre joueurs.

### PNJ employés désormais contactables + débauchage fonctionnel
- Fiche d'un PNJ employé par un autre joueur : bouton **Contacter** (réponse IA en personnage) + **Tenter de débaucher**.
- Débauchage : taux basé sur la vraie loyauté du métier (`PNJ_STATS_PAR_JOB[job].loyaute`) + DUP du joueur + pot-de-vin. Succès = transfert réel entre joueurs via Supabase (retiré de l'employeur actuel, ajouté au débaucheur).
- Renommage escort "Éléonore" → "Marlène" dans le catalogue (et sur le personnage de Fred).

### Port-Sainte-Marie (PSM) — extension et plan
- **9 nouveaux bâtiments créés** : Capitaine Sauvage, Chasse & Pêche (Maison Le Gall), Place d'Armes, École de Marine, Chantier Naval, Notre-Dame de la Mer, Cimetière Marin, Phare, Port de Plaisance. Plus le **Marché** (créé après coup, manquait initialement).
- **Port PSM renommé en "Port Industriel"** pour éviter la confusion avec le nouveau Port de Plaisance.
- **4 nouveaux terrains à bâtir** (total 5, comme Luthécia).
- Images branchées pour : Capitaine Sauvage, Chasse & Pêche, Place d'Armes, Marché, Notre-Dame de la Mer (nef).
- **Plan de ville en grille (PLAN_LAYOUTS.ville_a)** entièrement reconstruit à partir du vrai fichier Excalidraw de Fred (30 bâtiments positionnés fidèlement).
- **Rendu du plan de ville rendu générique** : le cadre/périmètre est calculé dynamiquement selon l'étendue réelle des bâtiments (au lieu d'un cadre fixe calibré pour Luthécia). Luthécia inchangée.
- **Route en croix générique** pour les autres villes (cherche le couloir le plus libre). **PSM a un tracé de rue spécifique dessiné à la main** (segment est-ouest Dispensaire/École de Marine → nord de Place d'Armes, puis nord-sud à l'est du Cimetière/Notre-Dame/Chantier Naval), qui remplace la croix générique pour cette ville.
- **Support technique ajouté** : un nœud de navigation par rue peut désormais avoir plusieurs images selon la direction d'arrivée (`imagesParArrivee`), pour varier l'angle de vue selon d'où vient le joueur. Rétrocompatible avec Luthécia.

### Réflexion économique (pas encore codée)
- **Zone de Production de PSM** : le poisson qu'elle produisait ne servait à rien (aucune recette d'arme n'utilise le poisson ; aucune ville de Republia ne produisait de bois, pourtant nécessaire aux recettes). **Décision de Fred : remplacer la Zone de Production par une Scierie (Guy Tarembois)**, qui comble ce trou (bois → recettes d'armes, et cohérent avec le Chantier Naval qui a besoin de bois). Le poisson sera géré plus tard via un **centre frigorifique** à construire près du Port Industriel (matières périssables).
- **Idée de musée** (local + national) pour évaluer et immortaliser les mandats des joueurs (bien ou en mal), à concevoir plus en détail plus tard — potentiel levier premium. Le "Musée de la ville" apparaît déjà sur le plan Excalidraw de PSM mais n'existe pas encore comme vrai bâtiment.

---

## 🗺️ Navigation rue par rue de PSM — état d'avancement

Toute la **périphérie** du plan a été définie avec Fred (nœuds, zones cliquables, liens), mais **RIEN N'EST ENCORE CODÉ** dans `plateau-rue-centrale.js` — seul le moteur générique (images multiples par direction) a été préparé. Fred a dit : "on prépare tout, et on lance l'ensemble d'un coup pour écraser le système actuel."

### Scènes définies (dans l'ordre du tour, en partant du Centre Multimodal) :

1. **Sortie Centre Multimodal** (image reçue : `port-sainte-marie-centre-multimodal (1).png`) — bâtiments cliquables : aucun mentionné (juste un carrefour). Flèches : gauche→Stade, droite→Port Industriel, bas→scène Dispensaire/École de Marine.
2. **Dispensaire + École de Marine** (image reçue, montre Stade/Port Industriel/Phare au loin) — cliquables : École de Marine, Phare. Flèches : haut→Centre Multimodal, gauche→Musée de la ville (pas encore créé), bas→Dispensaire/Port de Plaisance.
3. **Dispensaire + Port de Plaisance** (image reçue, avec panneaux École de Marine/Notre-Dame/Cimetière) — cliquables : Dispensaire, Port de Plaisance (PAS la banque, décor seulement). Flèches : haut→École de Marine/Phare, gauche→Tribunal/Banque.
4. **Tribunal + Banque** (image reçue) — cliquables : Tribunal, Banque (PAS le commissariat, décor). Flèches : droite→Dispensaire/Port de Plaisance, gauche→Commissariat/Bar des Pêcheurs, haut→carrefour Musée/Centre Commercial/Centre d'Affaires.
5. **Bar des Pêcheurs + Imprimerie + Commissariat** (image reçue) — cliquables : les 3. Flèches : droite→Tribunal/Banque, gauche→Capitaine Sauvage/Marché/Chasse&Pêche.
6. **Capitaine Sauvage + Marché (ruelle) + Chasse&Pêche** (image reçue) — cliquables : les 3 (le Marché = ruelle qui mène à une sous-scène). Flèches : droite→Bar des Pêcheurs/Imprimerie/Commissariat, gauche→Place d'Armes/Mairie/Hôtel du Port.
7. **Place d'Armes + Mairie + Hôtel du Port** (image reçue) — cliquables : les 3. Flèches : droite→Capitaine Sauvage, gauche→Église/Cimetière.
8. **Notre-Dame de la Mer + Cimetière Marin** (image reçue) — cliquables : les 2. Flèches : droite→Chantier Naval, gauche→Place d'Armes, arrière/bas→carrefour Musée/Centre Commercial/Centre d'Affaires.
9. **Chantier Naval** (image reçue) — cliquable : le chantier. Flèches : haut→Terrains à vendre, bas→Église/Cimetière.
10. **Terrains à vendre** (image reçue, montre 5 lots numérotés au loin via sous-scène) — cliquable : les terrains (sous-scène avec les 5 lots, image reçue aussi). Flèches : droite→Centre Artisanal/Scierie, bas→Chantier Naval.
11. **Carrefour Centre Artisanal + Scierie** (image reçue) — cliquables : les 2. Flèches : haut→Centre Multimodal, droite→Musée (carrefour central), bas→Terrains à vendre.
12. **Carrefour Musée + Centre d'Affaires + Centre Commercial** (2 variantes d'image reçues, vue "en provenance du Centre Artisanal") — cliquables : les 3. Flèches : haut→Tribunal, bas→Centre Artisanal, droite→Église, gauche→Phare.

### ⚠️ Reste à faire pour la navigation
- Le **carrefour central (Musée/Centre Commercial/Centre d'Affaires)** a plusieurs entrées (depuis Tribunal, depuis Chantier Naval/Église, depuis Centre Artisanal) — il faudra définir les flèches pour CHAQUE direction d'arrivée (utiliser le nouveau système `imagesParArrivee` qu'on vient de construire).
- Certaines images manquent encore (Fred génère au fur et à mesure).
- Une fois toutes les images prêtes : coder tous les nœuds dans `plateau-rue-centrale.js` (`RUE_CENTRALE_NOEUDS.republic`, sur le modèle de Luthécia), ajouter l'entrée dans `RUE_CENTRALE_DEPART.republic.ville_a`, et "lancer l'ensemble d'un coup".
- Remettre à jour le plan Excalidraw de PSM à la fin (les bâtiments ont bougé par rapport à la dernière version envoyée).

---

## 🖼️ Autre chantier en cours (hors code)
Fred construit un **blockout 3D dans Blender** (3.6 LTS, version Intel — son Mac est sous macOS Monterey 12.7.6, incompatible avec les versions récentes de Blender) pour positionner une caméra et générer des vues cohérentes entre elles à chaque carrefour de PSM, plutôt que de dépendre entièrement des générateurs d'images (qui produisent des résultats peu cohérents géométriquement d'une image à l'autre). Session en cours d'apprentissage de l'interface (import d'image de référence, positionnement de caméra). Pas un chantier de code.

---

## 📝 Chantiers en attente (rappel, non traités cette session)
- Calendrier électoral pas à jour.
- Photo du Chef de Cabinet qui ne charge pas.
- Réorganiser le dossier `images/` en sous-dossiers (pays/ville/PNJ/bâtiments) — actuellement tout à plat.
- Concevoir le système de musée (local + national) plus en détail.
- Concevoir le centre frigorifique de PSM (matières périssables, poisson).
