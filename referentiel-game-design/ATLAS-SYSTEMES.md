# Atlas des systèmes et de leurs interactions

**État de départ : 9 novembre 2026, main `a8bd5e26`.** Cet atlas décrit le **design** et pointe ses manifestations dans le dépôt ; aucun renvoi ne vaut certification de jouabilité. Les états probatoires figurent dans la matrice. Lire la [Constitution](../CONSTITUTION.md) avant toute interprétation.

## 1. Le jeu réel : une société de PJ
**Human Gambit n'est pas un jeu à victoire unique.** Ses moteurs servent les interactions humaines : alliances, rivalités, négociations, trahisons, gestion de biens, conquête et perte de charges, religion, sport, médias et crime. Un joueur peut viser la fortune, le pouvoir, la réputation, la foi, le sport ou la clandestinité ; les réussites ne sont pas subordonnées au parcours politique (Constitution, articles 1–3, 8–11). Les PNJ entretiennent le fonctionnement en l'absence de PJ mais ne doivent pas remplacer leur intérêt ni leurs choix (article 5).

**Boucle sociale structurante :** choisir un objectif → identifier une institution / un autre acteur → obtenir des ressources, un statut, des preuves ou des alliés → négocier / rivaliser / coopérer → résultat persistant et observable → réactions des autres PJ → nouvel objectif. La qualité du jeu ne se réduit donc pas au nombre d'ordres ou de bâtiments.

## 2. Infrastructure commune et limites d'autorité
- **Client** : `index.html`, `creation.js`, `plateau.html`, `data.js`, les modules `plateau-*.js`, `supabase.js`, `forum.js`. La présentation est commune, mais les droits et effets doivent être serveur.
- **Supabase** : identités, propriétés, inventaires, banques, positions, autorités, actes et règles de minuit ; `baseline/` comme état de référence, `migrations/` comme évolutions, fonctions RPC et politiques RLS. Interdiction fondamentale d'écrire directement la fiche canonique via la vue `personnages` (voir `AGENTS.md`).
- **Vercel** : `api/chat.js` (PNJ via DeepSeek), autres services journal/conférences ; `api/cron-minuit.js` et `api/cron-assemblee.js` ; `vercel.json` contient leurs horaires UTC, lesquels demandent contrôle de la bascule heure de Paris en changement d'heure.
- **Horloge** : une seule, heure de Paris ; effets quotidiens à minuit, délais entre humains en temps réel. `jour_de_jeu_pays` gère des numéros de jour, pas une horloge distincte (architecture, Constitution art. 12).
- **Sécurité** : les conséquences, les coûts, la réussite, la position et les autorisations ne doivent jamais dépendre d'un état local non confirmé. Les erreurs réseau ne doivent pas entraîner de rejeu aveugle.

## 3. Parcours d'arrivée et de personnage
Accueil → langue éventuelle → création (origine, pays, archétype, formation/carrière, caractéristiques, identité) → présence dans une ville / première scène → quête d'accueil et journal → première activité → relations. Les ressources `i18n/resources.js` et `i18n/i18n-init.js` montrent une architecture N langues ; **ne pas confondre sélecteur d'accueil et internationalisation intégrale ni supposer l'activation publique générale**. `plateau-quete-accueil.js`, `plateau-organisations-quetes.js`, `plateau-personnage.js` exposent les systèmes d'orientation/progression. Les gains de POP/INF dus aux objectifs relèvent des règles `GAME-DESIGN-JAUGES-379.md` ; les objectifs secret ne sont pas des récompenses à chaque ouverture de panneau.

**Dépendances :** bonne localisation initiale, découverte des lieux pertinents, actions accessibles avec PA de départ, explication des règles et premier contact humain. Risque de rétention : quantité d'options sans chemin lisible ; à mesurer, non présumer.

## 4. Activité quotidienne et ressources
Sommeil, salaires, PA, alimentation, santé, moral, emploi, hôpital, emprisonnement, logement et dépenses fixes structurent la boucle de retour. Les règles de compensation doivent respecter l'horloge universelle et ne pas accorder plusieurs journées d'un coup. Sources : `ARCHITECTURE.md`, `GAME-DESIGN-HOSPITALISATION.md`, `GAME-DESIGN-BNE.md`, `api/cron-minuit.js`, `plateau-personnage.js`, `plateau-logements-sociaux.js`, `plateau-alimentaire.js`.

**Interactions :** les salariés dépendent de recruteurs, les commerçants de fournisseurs et de clients, les locataires de propriétaires ou municipalités, les malades de soins et de secours. Les contraintes de PA, nourriture et santé doivent générer des choix, non un blocage total (Constitution art. 14).

## 5. Économie, production, commerce et propriété
- **Monnaie et circulation** : liquide, comptes, caisses commerciales/institutionnelles, banques, prêts, placements, fiscalité, transferts. Documents `GAME-DESIGN-BANQUES.md`, `GAME-DESIGN-FONDS-MURS.md` ; UI `plateau-commerce.js`, `plateau-commerce-pj.js`, `plateau-fonds.js`, `plateau-entrepots.js`.
- **Chaîne de valeur** : matières premières → entrepôts et importations → usines / ateliers / commerces → produits et services → achats et usages / chantiers. Transport et douanes introduisent friction et opportunités de trading. `GAME-DESIGN-TRADING.md`, `GAME-DESIGN-DOUANES.md` et `plateau-entrepots.js`.
- **Immobilier de Républia** : terrain, compromis, permis, financement, construction, occupation et propriété du fonds/murs ; `GAME-DESIGN-TERRAINS.md`, `GAME-DESIGN-FONDS-MURS.md`, `plateau-immobilier.js`, `plateau-chantiers.js`.
- **Sovarka** : différence constitutionnelle majeure, propriété collective des murs et fonds par l'État ; les PJ obtiennent et cèdent un **droit d'exploiter** ; attribution publique et actes notariés (voir `GAME-DESIGN-NOVOMIRSK.md`, `plateau-sovarka-droits.js`). **Ne pas importer mécaniquement les règles foncières de Républia.**
- **Naval** : construction au chantier de PSM avec modèles, devis, fonds séquestrés et matières consommées sur jours effectifs ; navigation privée explicitement séparée et désactivée dans le document de chantier. `plateau-naval.js`.
- **Véhicules routiers** : acquisition/fabrication, carburant, clé, maintenance, déplacements entre villes permises par le réseau, coût PA ; `GAME-DESIGN-VEHICULES.md`, `plateau-vehicules.js`, `plateau-navigation.js`.

**Dépendances croisées** : politique douanière → prix importés → coût de production → concurrence entre industriels, traders, constructeurs et clients ; pénurie → blocage du chantier → négociation / logistique → reprise. Les transferts bancaires, inventaires et caisses doivent rester atomiques.

## 6. Pouvoir et contre-pouvoirs
- **Accès au pouvoir** : création de partis, adhésion, candidature, élections, fraudes et contestations ; nomination à une fonction, remplacement des PNJ, protection et révocation ; sources `GAME-DESIGN-ELECTIONS.md`, `plateau-politique.js`, `plateau-assemblee*.js`.
- **Exercice** : président, ministères, municipalités, assemblée, lois et décisions administratives ; budget, nominations, fiscalité, sécurité et économie.
- **Opposition** : médias et journal, contestations juridiques, syndicats, grèves, manifestations, blocus, corruption, opposition, action clandestine et influence religieuse. Documents `GAME-DESIGN-MANIFESTATIONS.md`, `GAME-DESIGN-BLOCUS.md`.
- **Variantes souveraines** : Sovarka utilise un président du Conseil et ses propres règles de partis/députés, tandis que ses bâtiments et fonctions héritent du socle selon des exceptions explicites (`GAME-DESIGN-NOVOMIRSK.md`, `plateau-sovarka-pouvoir.js`, `plateau-sovarka-partis.js`).

**Dépendances sociales :** un candidat a besoin d'électeurs ; un élu de fonctionnaires, financiers, journalistes et opposants ; les contre-pouvoirs doivent rester accessibles autrement que par la même élection (Constitution art. 10).

## 7. Justice, crime, sécurité, force et secrets
Actes illégaux → détection / traces → avis de recherche / enquête → arrestation, fuite ou affrontement → garde à vue / détention / procès / sanction, éventuelle évasion ou grâce. Les personnes et les forces doivent être **présentes** ; pas d'arrestation sans règle de détection. Police, agents privés et armée réutilisent des socles de présence, groupes, interception et combat ; ne pas recréer des moteurs par pays. Voir `GAME-DESIGN-SECURITE-PRIVEE-135.md`, `GAME-DESIGN-ARMEE.md`, `GAME-DESIGN-DOUANES.md`, `GAME-DESIGN-DROGUES.md`, `plateau-justice-economie.js`, `plateau-actions-illegales-rumeurs.js`, `plateau-militaire-terminal.js`.

**Sovarka** : circuit d'instruction sans procureur, rôle du commissaire / ministre / juge et greffe spécifiques ; migration et bancs déclarés appliqués le 8 novembre dans `RELAIS.md`, observation en jeu distinctement demandée. Les archives et décisions sont dans `GAME-DESIGN-NOVOMIRSK.md`.

**Principe social :** le crime demeure une voie de jeu ; le contrôle protège les autres PJ, pas un chemin moral obligatoire. Le joueur incarcéré doit conserver des possibilités de participation (Constitution art. 14).

## 8. Organisations et sociabilité
Partis, syndicats, entreprises, clubs, réseaux criminels, loge, Église, groupes mobiles et forums. Ces structures portent statut, salaire, droits, réunions, solidarité, secrets et rivalités. `plateau-organisations-quetes.js`, `plateau-contact-organisation.js`, `plateau-reunions-evenements.js`, `plateau-multijoueur.js`, `GAME-DESIGN-FORUMS.md`.

**Forums** : local = ville **actuelle**, national = pays actuel, privé = adhésion ; contrôle du pays côté serveur et absence de fuite entre empires. Discussions, messages, annonces et presse alimentent la mémoire partagée.

**PNJ classiques et PNJ sociaux** : `api/chat.js` construit les prompts serveur, valide le profil et lit les mémoires sous identité du joueur. `plateau-social-pnj.js` décrit l'abordage spontané de Jean-Lou Demer à la **deuxième entrée** au bar des pêcheurs et l'accueil de Marine Leroux au restaurant ; la seed `baseline/seeds/90_socle/pnj_social_jalons_regles.sql` contient **exactement deux lignes de règles** au SHA examiné. La mention « sept autres PNJ sociaux » dans le commentaire du code décrit un potentiel, **pas sept PNJ actifs certifiés**. La mémoire de conversation et le contact spontané doivent être vérifiés par RPC et test connecté, distinctement de l'ouverture de la fenêtre.

## 9. Sport, religion, culture, réputation
Football (clubs, supporters présents, matches, transferts, blessures, revenus), foi et pouvoirs religieux, musées, presses, publicité, bureaux et lieux de prestige. Les gains de POP/INF/Moral deviennent des leviers de réputation, et les clubs/religions des contre-pouvoirs. Sources : `GAME-DESIGN-FOOTBALL.md`, `GAME-DESIGN-JAUGES-379.md`, `plateau-ced.js`, `plateau-musee-personnalites.js`, `plateau-publicite-premium.js`.

**Prémisse de validation :** il faut documenter, pour chaque activité, la dépendance à au moins une décision ou présence d'un autre PJ ; les sports et les lieux culturels ne doivent pas devenir de simples distributeurs de jauges.

## 10. Géographie, empires et international
Républia (Luthécia, Montrouge, Port-Sainte-Marie) ; Sovarka (Novomirsk, Krasnov, Starovka) ; El Estado, Al-Khalija et autres horizons de contenu. Le socle moteur est commun, les biographies, institutions et cultures sont particulières. `world-map.js`, `data.js`, `GAME-DESIGN-NOVOMIRSK.md`.

Le passage entre empires est déclaré **non existant** dans la description des couches d'`ARCHITECTURE.md` du 26 octobre, tandis que l'interdépendance économique / douanière et des bâtiments diplomatiques existent en divers états. **La présence d'ambassades et d'importations ne démontre pas un voyage personnel interempire opérationnel.** Les villes de Sovarka n'ont pas toutes une liaison routière ; toujours consulter le graphe réel.

## 11. Premium, langues, supports
Bêta gratuite ; personnalisation et prestige plutôt que puissance ; conditions de monétisation à dater par option. Localisation : catalogue de ressources et bancs i18n présents mais couverture réelle de chaque écran et langue à calculer. Mobile : `plateau-mobile.js` et CSS du socle présents ; `outils/audits/CERTIFICATION-MOBILE-20261108.md` rapporte des bancs Chromium, mais `RECETTE-PHYSIQUE-MOBILE-20261108.md` constate qu'iPhone/Android et deux appareils réels **restent à essayer**. Ces distinctions sont structurantes pour l'acquisition et la rétention.


## 12. Parcours narratif et rétention — évolution du 9 novembre au soir

**Le point 3 décrit la situation de l'audit initial.** Les premiers retours mobiles montrent qu'un calepin et un stagiaire peuvent être présents sans que la finalité soit comprise. Le design adopté lie désormais l'onboarding à une **sollicitation incarnée** : Jérémy pour l'accueil, puis Jodie Moitout pour l'enquête « Le Portrait disparu » à Luthécia.

À **J+1 (24 heures réelles)** et après conclusion de l'accueil, le serveur déclenche la remise du calepin et l'appel illustré et interactif de Jodie. Elle nomme le **Musée de la Ville de Luthécia** et adapte son introduction à une rencontre antérieure au marché ou à L'Autruche Entravée. Refuser son invitation ne bloque pas l'exploration ; une seconde proposition est possible si le dossier demeure vide ; à la résolution, elle reprend contact. Sa mémoire est commune aux trois canaux mais ne vaut ni omniscience ni preuve des paroles du PJ. Le principe est **un PNJ qui propose sans contraindre**.

**Extension décidée, non codée à l'échelle du monde** : chaque ville aura sa propre quête d'accueil et sa propre enquête, donnant envie de se repérer et d'entretenir une relation ; PSM reste à redéfinir à partir de ses contours connus du game designer. **Sovarka est prioritaire avant l'extension narrative**. La réorganisation de « Mes objectifs » en missions/questions courtes en pop-up et les cartes de villes plus lisibles sont encore des intentions.

Sources et statuts probatoires précis : [expérience et rétention](EXPERIENCE-ET-RETENTION.md), [PNJ sociaux](PNJ-IA-MEMOIRES-INTERACTIONS.md), [matrice](MATRICE-COUVERTURE.md), PR #664 et #666. **Aucune amélioration mesurée de D1/D7 ni recette réelle de ce parcours ne peut être affirmée.**

## Sovarka — lot des provinces (10/11/2026, Claude, PR #681 puis #686)

Règles : `GAME-DESIGN-NOVOMIRSK.md`, « Réponses de Fred », « Fermes : production » et « Forêt profonde de Krasnov : ce qui est codé ». Statut commun : **D+C, banc annulé vert sur la production (T), migrations déclarées appliquées (M déclarée), fusionné (P) ; non vérifié en jeu (pas de J)**.

| Système | Serveur | Écran | Reste |
|---|---|---|---|
| Extraction (pétrole Starovka, bois Krasnov) | `recolte_effectuer` (patch `sovarka_extraction_v1`) | `MATIERES_PREMIERES_VILLE` | — |
| Bons d'État | `sovarka_bon_etat_souscrire`, `sovarka_bons_etat_lire`, `sovarka_bons_etat_passe` (minuit) | `plateau-sovarka-provinces.js` | banques sans façade dans les rues |
| Centres d'écoute | `sovarka_ecoutes_passe` (minuit), `sovarka_ecoutes_lire`, `sovarka_ecoute_rapport_demander`, `sovarka_ecoute_archives_voler` | idem, bureau du ministre de la Défense | images ; vol d'archives 2 PA / 45 % = choix de Claude à relire par Fred |
| Maisons (hospitalité, trinquer, ragots) | `sovarka_maison_lire`, `sovarka_maison_agir`, nuitée par `hotel_nuitees` | idem | réaction IA de l'habitant ; noms des maisons (Dolgor, Stepan) à valider par Fred |
| Fermes (Ferme de Starovka, Kolkhoze S. M. Kirov à Krasnov) | `sovarka_ferme_travailler` (travail en PA, sans matière d'entrée, produit à qui travaille) | idem | noms des deux fermiers à valider par Fred |
| Œufs (matière locale `oeufs`, hors entrepôts et trading) | `sovarka_oeufs_manger` (+2 PA au prochain Dormir, source `oeufs`) | bouton « Manger 3 œufs » de la fiche d'objet (`plateau-personnage.js`) | bouton perdu par #688 puis rétabli le 10/11 après-midi |
| Distillerie de Krasnov, fourreur « La Fourrure chaude » (Starovka) | locaux de Sovarka puis commerce classique ; type « Distillerie » (vodka, slivovitz, samogon, sucre) ; fourreur = type « Vêtements » | commerces | plafond de loyer 30 PSK, 1 PA par recette, revente œufs ×5 / sucre ×10 = choix de Claude à relire |
| Forêt profonde de Krasnov (4 vues, coupes, loup / meute / ours, Olga) | `sovarka_foret_aller`, `sovarka_foret_couper`, `sovarka_foret_rencontre`, `sovarka_foret_issue_combat_interne` ; seconde coupe : migration `20261110144500_sovarka_foret_seconde_coupe` (1re coupe acquise, victoire et Olga rapportent le bois de la 2e) | idem, « Fuir » | images des 4 vues (Fred) ; 2 PA par coupe, force des créatures (9 / 13 / 16), « Dent d'ours » = choix de Claude à relire |

**À constater en jeu** : récolte de pétrole et de bois ; travail aux fermes et « Manger 3 œufs » ; commande à la distillerie ; forêt (fuir sur la vue 3 sans perdre la première coupe, victoire et Olga rapportent du bois) ; maisons ; centres d'écoute après une première nuit.
