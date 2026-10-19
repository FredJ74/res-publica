# Commerces unifiés et « Offrir à boire » — 19 octobre 2026

## Verdict

**Codé et testé localement ; activation serveur NON TERMINÉE.** Aucun connecteur Supabase/Vercel exposé, aucune liaison SQL ou clé Supabase/Vercel disponible dans cet environnement. L'API GitHub refuse également la lecture des statuts (Forbidden), bien que Git fonctionne. Aucune migration ni donnée réelle modifiée.

Le client vérifie `tournee_contrat_lire()` avant de proposer la nouvelle tournée. Sans contrat version 1, il annonce son indisponibilité et ne débite rien. **Après publication du client, « Offrir à boire » restera indisponible tant que la migration n'est pas appliquée.** Ce verrou évite d'exécuter discrètement l'ancienne tarification ou d'appliquer des bonus depuis le navigateur. Les restrictions serveur de production sont également préparées, pas confirmées installées.

## Changements

- `plateau-politique.js` : retrait des ordres séparés de production commerciale et d'armurerie ; gestion historique affichée seulement après lecture du propriétaire serveur. Le coût de 1 PA de l'ordre social est visible.
- `plateau-commerce-pj.js` : le bail identifie le fonds, mais son locataire ne prouve plus la propriété du fonds. Lecture de `sbGetFonds`/`sbGetEntreprise`, avec garde de personnage/session/pièce avant réaffichage. Catalogue avec achat/commande, production et fiche ; stocks nuls conservés. Les clients ne produisent pas. Le parcours historique et le parcours multi-lots revalident aussi le droit. La restauration PJ emploie « Consulter la carte ». Relecture sociale via le mécanisme de rafraîchissement du personnage existant.
- `plateau-actions-illegales-rumeurs.js` : actions communes aux cartes et aux produits de marché ; les anciennes entrées de production redirigent vers le catalogue. Armurerie : ajout production et fiche, sans retirer achat légal, marché noir ou restrictions d'effort de guerre. Production et achats continuent d'utiliser leurs RPC et calculs existants. Aucun prix de catalogue modifié.
- `plateau-objets.js` : palette commune des deux panneaux de fiche (commercial et officiel), conservant description, prix, stock, effets, capacités et propriétés. Les fiches historiques, PJ et d'armes réutilisent ces panneaux.
- `data.js` : quatre déclarations d'« Offrir à boire », retrait des deux anciens ordres `boire_verre` de salle. Les interactions sentimentales PNJ et les dîners d'affaires ne sont pas modifiés.
- `supabase.js` : le sondage des invitations inclut les acceptations à relire après service ; aucune nouvelle boucle de polling. `plateau.html` invalide les caches des scripts modifiés.

### Autorisation de production

Les fonctions examinées autorisaient auparavant le travail public rémunéré. La consigne nouvelle interdit à un simple client de produire. L'audit a retrouvé le registre `entreprises.data.salaries`, écrit par `employer_fonds` sous contrôle du propriétaire. Le droit de production reconnaît donc le propriétaire **ou un salarié actif enregistré dans ce commerce** (`ref` personnelle et `actif:true`). Un rôle libre, un bail ou un emploi dans un autre commerce n'accorde rien. Les mêmes contrôles sont partagés par les deux RPC de production. Le salarié ne reçoit aucun droit de gestion du fonds. Le prévol vivant doit confirmer cette définition et l'intégrité de ce registre avant activation.

## Serveur préparé, NON appliqué

`migrations/20261019213444_catalogue_et_offrir_a_boire.sql` :

1. Garde sur les définitions examinées des quatre fonctions modifiées. Une définition différente ou absente bloque la migration. Rejeu de la même migration autorisé et éprouvé localement.
2. Contrôles de propriétaire ou de salarié actif enregistrés ajoutés aux deux moteurs de production, en conservant leurs recettes, composants, matières, salaires, PA et autres conditions.
3. Une seule économie de vente : corps existant déplacé dans une primitive privée, signature publique conservée comme relais. Seule la clôture serveur peut utiliser le tarif de tournée à 25 FR. Pas de modification temporaire du prix commercial et pas de second calcul fiscal.
4. Tables `tournees` et `invitations_diner` existantes conservées. Colonnes de contrat, entreprise, intention initiale et reçu ajoutées, sans transformer les anciennes lignes.
5. Création atomique des invitations, authenticité de l'organisateur, présence réelle des PJ, déduplication des invités et reçu de création par identifiant. L'organisateur n'est pas une cible à sélectionner : son verre est ajouté côté serveur.
6. Réponse individuelle verrouillée ; une deuxième réponse identique rejoue, une réponse opposée ou close est refusée. Les écritures REST ne peuvent pas fabriquer/modifier une tournée v1, ni créer de nouvelles tournées legacy pour contourner le nouveau contrat.
7. `tournee_cloturer(text,boolean)` reste la porte existante. Pour v1, elle effectue vente, PA, taxe, caisse, stock, bonus et reçu dans la même transaction. Les refus intermédiaires du moteur historique sont annulés par sous-transaction, y compris ses PA éventuellement déjà débités.
8. Nombre de verres = acceptants encore présents + organisateur. Un PA unique et 25 FR par verre. Avec acceptants : +5 Santé, +2 INF, +2 ENT par participant, une fois, plafonds existants conservés. Sans acceptant, y compris à expiration : un verre pour l'organisateur, 25 FR, 1 PA, −5 Moral, aucun bonus. Ressources insuffisantes : refus total. Organisateur parti : acte obsolète annulé sans débit.
9. Le reçu bloque les répétitions après réponse perdue ou accès concurrents. Le navigateur conserve la clé d'une création incertaine, même en cas d'échec du stockage (mémoire de la modale). Une réponse de clôture perdue peut être réconciliée par lecture du reçu serveur. Les bonus sont relus, jamais calculés localement ; les acceptants acquittent la lecture de leur résultat sans recevoir de second crédit.
10. Les anciennes tournées déjà engagées restent clôturables selon leur contrat précédent. Leur ancienne séparation vente/clôture reste une limite historique : aucune sécurité nouvelle n'est revendiquée pour cette fenêtre des actes legacy.

## Vérifications réalisées

- Contrôleur client complet : **89/89 bancs réussis**, incluant les nouveaux bancs. Après les derniers ajustements de libellé/reprise, relance ciblée : **53/53 tests** (catalogue, transactions et Chromium).
- Nouveau banc client : **28 tests**, interfaces PJ/historiques, restaurant/bar/café/marché, trois actions, stocks nuls, propriété serveur, clients interdits de production, anciennes données de présentation non utilisées pour accorder la gestion, contrat absent, double clic, réponse perdue, stockage indisponible, changement de personnage, réponses refusées, relecture des bonus et reçus.
- Chromium réel, 390 et 1280 px : **2/2**. Trois types de catalogue, clic client bloqué, production propriétaire raccordée, informations des fiches conservées, nouvelle palette, absence de débordement horizontal. Identités et RPC simulées : pas un parcours Supabase authentifié.
- PostgreSQL jetable : **60/60 assertions**, avec les vrais corps SQL et services bancaires/fiscaux de fixture. Succès, refus/mélange, expiration, plafonds, tarif fixe sans changer le prix de carte, reçu rejoué, doubles réponses, concurrence sur un acte et sur deux actes partageant les fonds, rollback PA après débit refusé, panne injectée, absence/tiers, stocks insuffisants, gardes propriétaire, droits privés, écritures REST bloquées, ancienne tournée, migration rejouée et définition inconnue refusée. Aucun compte réel utilisé.
- Bancs PostgreSQL existants : achat **12 groupes** ; réception atomique **31 groupes**.
- Contre-épreuves : **90/90** ; calendrier Node : **5/5**. Syntaxe API/scripts, analyse SQL (migration 35 instructions, prévol 11), garde payload et diff conformes.
- Contrôles globaux : **10/12**, sans changement de baseline. **Authority : 23 RPC non retrouvées dans le baseline**, dont les trois nouvelles déclarées dans la migration préparée (20 écarts avant ce chantier). Cela ne prouve pas leur présence ni leur absence dans la base réelle. **Referential : deux empreintes en écart**, `ordres_couts` et `postes_nommes_regles`. Le retrait des ordres de verre rend attendue une évolution du miroir des ordres ; aucune empreinte n'a été remplacée pour masquer la divergence.
- Le cas de sauvegarde/transactions modifié conserve toutes ses assertions : la fixture de production réussie est désormais celle d'un propriétaire, et un cas supplémentaire démontre le refus du client.
- Le nouveau banc PostgreSQL est raccordé au workflow CI existant, sans pipeline parallèle. Son résultat distant reste non observé.

## Activation contrôlée — opérations réservées à l'agent technique

1. Exécuter le prévol **en lecture seule** `outils/bancs/prevol-catalogue-boire.sql`. Relire définitions, propriétaires des fonctions, droits, RLS, triggers, contraintes, types, dépendances et constante `pa_tournee=1`. Vérifier toute habilitation de production vivante absente du baseline. Comparer aux quatre empreintes attendues ; en cas de divergence, adapter et retester le code réel, jamais seulement changer une empreinte.
2. Prendre une empreinte des lignes métier susceptibles d'être touchées : personnages, entreprises, comptes/caisses/taxes, tournées et invitations ; relever les actes legacy en cours. Aucun achat, tournée ou production témoin sur des joueurs réels.
3. Appliquer uniquement cette migration par le canal MCP autorisé, avec enregistrement dans le registre. Aucune migration d'organisation ou d'équipement collectif à activer.
4. Vérifier que l'application structurelle n'a modifié aucune ligne métier existante, puis contrôler droits et contrat. Tester les parcours authentifiés avec comptes isolés autorisés. Les services annexes réels, triggers financiers et sauvegardes ne sont pas reproduits intégralement par les fixtures locales.
5. Réextraire les quatre exports canoniques, régénérer baseline/seeds et miroir des ordres avec les outils du dépôt, examiner les différences ; archiver la migration après application prouvée, conformément à WORKFLOW-SUPABASE.md. Ne pas présenter les deux contrôles globaux rouges comme satisfaits avant ce travail réel.
6. Contrôler le SHA effectivement servi par Vercel et les parcours catalogue/fiche/gestion/tournée en jeu. Le push Git seul n'est pas cette vérification.

### Repli

Avant application, le contrat absent bloque l'ordre sans débit. Après application, suspendre les nouvelles créations via le contrat serveur si nécessaire, puis laisser les actes v1 déjà engagés se résoudre avec leur reçu. Privilégier une correction en avant. Ne pas supprimer les colonnes, invitations, tournées, reçus ou inventaires, et ne pas rétablir aveuglément une vente séparée de la clôture. Tout retour des définitions doit être préparé à partir des sources vivantes sauvegardées et tenir compte des actes en cours ; aucun remboursement automatique ou réinitialisation de joueur.

## Publication

Main de départ : `dff8960bfedd7a809bd636a0fddbe1a13be2cf5f`. Les fetchs effectués pendant le chantier n'ont révélé aucun nouveau commit concurrent. Modifications graphiques/image existantes et migrations d'organisations préservées. Commit et push du code et de la migration préparée : voir l'historique Git. Succès de build/déploiement Vercel et tests authentifiés non observables ici ; aucune clôture de production revendiquée.
