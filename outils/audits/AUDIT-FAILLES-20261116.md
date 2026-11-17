# Audit des failles — Human Gambit, 16/11/2026 au soir (Claude)

Demande de Fred : « teste un maximum du jeu pour en trouver les failles ».

**Méthode.** Les essais ont porté sur la base de production Supabase (`res-publica`), dans le rôle d'un joueur connecté (`authenticated`), avec un vrai personnage (Arnie, puis Ben). Chaque essai s'est déroulé dans une transaction **annulée** : un bloc qui se termine par une erreur volontaire, donc **rien n'a été modifié en production**. S'y ajoutent le conseiller de sécurité Supabase et une lecture du code des fonctions `api/`.

**Non testé ici** : parcours à l'écran, téléphone et traductions. Il faudrait un navigateur et un compte de test.

---

## Ce qui est solide (vérifié)

Un joueur qui écrit directement dans la vue `personnages` **ne peut pas** modifier :
- ses PA, son argent (liquide, banque, `arg`), ses caractéristiques (`stats`) ou ses points libres ;
- sa popularité et son influence (`pop`, `inf`) ;
- son casier, ses motifs de recherche, sa détention ou sa prison ;
- son poste. Essai fait : Ben se déclare président ou ministre de la Justice ; le serveur garde son poste vide, et les contrôles de poste répondent non.

Les fonctions d'IA (`chat`, `redaction`, `conference`) exigent toutes une session. Les fonctions accessibles sans connexion vérifient presque toutes l'identité de l'appelant.

---

## Failles critiques — à corriger avant la bêta élargie

### 1. La discrétion se modifie librement — immunité contre la détection
Le joueur peut écrire `resources.dis`, la discrétion. Essai : Arnie passe de 95 à 9 999 et la valeur est acceptée.

Or cette valeur est lue par une trentaine de fonctions du serveur, dont :
- `crime_detecter_interne` (détection des crimes) ;
- `fraude_electorale_tenter` (fraude électorale) ;
- `police_fuite_personnage_interne` (fuite face à la police) ;
- `douane_controle_groupe_interne` (contrôles de douane) ;
- `arrestation_flagrant_choisir` (flagrants délits) ;
- `se_cacher`, `crime_contrebande`, `sovarka_ecoute_archives_voler`.

Un tricheur peut donc voler, frauder une élection ou passer la douane sans jamais être repéré. Les clés `pop` et `inf`, rangées au même endroit, sont bien protégées : `dis` a simplement été oubliée.

### 2. Comptes anonymes illimités qui peuvent voter
Le jeu ouvre une session anonyme avant l'inscription. La base compte **453 comptes anonymes pour 9 comptes inscrits**, et 6 personnages appartiennent à des comptes anonymes. Aucune fonction de jeu ne distingue ces comptes : seules `admin_moi` et `admin_se_declarer` le font. `election_voter` ne le fait pas.

Un script peut donc créer des dizaines de comptes, chacun avec un personnage, et faire élire qui il veut. Le même procédé permet de fabriquer un parti ou de se faire des dons à soi-même.

### 3. Employés fabriqués
Le joueur peut écrire `employes` : la liste de ses employés PNJ est acceptée telle quelle. Elle est lue entre autres par :
- `detention_se_rebeller` (la rébellion en détention, avec ses employés) ;
- `pnj_objet_transferer` (transfert d'objets par un PNJ) ;
- `employes_payer_jour` (paie quotidienne des employés).

Un joueur peut s'inventer une équipe d'agents sans les embaucher ni les payer.

---

## Failles importantes

### 4. Le domicile se modifie librement
`domicile` est accepté tel quel. Il est lu par :
- `election_voter`, `candidature_deposer` et `candidature_publier` : on peut voter ou se présenter dans **n'importe quelle ville** ;
- `logement_social_demander` : on accède aux logements réservés aux domiciliés, par exemple à Novomirsk ;
- `fraude_electorale_tenter` et les paris de football.

### 5. Les points de vie se modifient librement
Arnie passe de 100 à 999 PV et la valeur est acceptée. Une hausse de PV est **seulement notée** dans `fiche_hausses_observees` (1 544 lignes à ce jour, sur les PV, l'argent, `arg` et le jour), mais elle n'est pas bloquée. Les combats contre la police, les groupes et les agressions lisent les PV : un tricheur devient presque invincible.

### 6. Effets actifs et bonus du lobbyiste fabriqués
- `effets_actifs` est écrit tel quel. Ce sont les bonus temporaires (guide des baies, coupe de cheveux, drogues, réunions de Sovarka), et un joueur peut s'en attribuer sans les gagner.
- `bonus_lobbyiste` est écrit tel quel. Il est lu par le marchandage à l'Assemblée (`assemblee_taux_marchandage`, `assemblee_marchander`).

### 7. Coût de l'IA ouvert aux abus
- `api/redaction.js` envoie à DeepSeek **le texte fourni par le navigateur** comme instruction complète. N'importe quel compte, anonyme compris, s'en sert donc comme d'une IA gratuite (jusqu'à 500 jetons par appel). Le même texte libre permet aussi de fabriquer un décret, un scandale ou une réaction de journaliste qui dit n'importe quoi.
- Aucune **limite d'appels par joueur** dans `chat.js`, `redaction.js` et `conference.js`. Combinée à la faille 2, une boucle de requêtes peut faire monter la facture DeepSeek sans plafond.

---

## Failles moyennes

### 8. `api/renseignements.js` sans authentification
L'en-tête du fichier le reconnaît lui-même : n'importe qui peut écrire un renseignement au nom de n'importe quel titulaire. La lecture reste fermée.

### 9. Fuite des organisations criminelles
`rumeurs_organisations_cibles()` peut être appelée **sans connexion**. Elle renvoie le nom et le pays de toutes les organisations criminelles, même celles qui ne sont pas visibles. Le secret fait partie des domaines que le code doit tenir (Constitution, article 4).

### 10. Football et quêtes
Le joueur peut écrire :
- `licence_sportive` et `performance_sportive`, lues par les primes de match et le choix du capitaine ;
- `quete_carriere`, `quete_accueil`, `enigme1` et `maxence`, ce qui permet peut-être de sauter des étapes de quête et d'en toucher les récompenses (à confirmer quête par quête) ;
- `moral` et `reservation_hotel`.

---

## Points faibles mineurs
- `cron_alerte_etat()` peut être appelée sans connexion et montre les erreurs de la passe de minuit.
- 81 fonctions n'ont pas de chemin de recherche fixé (`search_path`), selon le conseiller Supabase. Le risque est faible ici, mais la correction est simple.
- La vue `personnages` est en `SECURITY DEFINER`. C'est voulu (elle passe par la garde `personnages_vue_modifier`), mais toute colonne que cette garde oublie devient modifiable : c'est l'origine des failles 1, 3, 4, 5, 6 et 10.

---

## Corrections proposées (choix techniques, sans question de game design)

1. **Étendre la garde `personnages_vue_modifier`**, qui protège déjà les PA, l'argent, les caractéristiques, `pop` et `inf`, à :
   - `resources.dis` ;
   - `hp`, en passant de l'observation au blocage ;
   - `employes` ;
   - `domicile` ;
   - `effets_actifs` ;
   - `bonus_lobbyiste` ;
   - `licence_sportive` et `performance_sportive` ;
   - les champs de quête.

   Règle : **seule une fonction du serveur peut écrire ces colonnes**. Un banc annulé par colonne, comme ceux ci-dessus, servira de garde permanente dans le contrôle CI.
2. **Comptes anonymes** : une session anonyme peut visiter et essayer le jeu, mais voter, se porter candidat, créer un parti, faire un don ou commercer exigent un **compte confirmé par courriel**. On ajoute un captcha à la création de session (Supabase le propose nativement). La faille 2 rejoint ainsi la proposition « un compte par personne ».
3. **IA** :
   - `redaction.js` construit lui-même les instructions côté serveur, à partir de l'usage et de données vérifiées ; plus aucune instruction libre venue du navigateur ;
   - plafond d'appels par joueur et par jour sur toutes les routes d'IA ;
   - IA réservée aux comptes confirmés au-delà d'un petit quota d'essai.
4. **Renseignements** : brancher `joueurAuthentifie` et `exiger_acteur` comme dans les autres routes.
5. **Fonctions ouvertes aux visiteurs non connectés** : retirer le droit d'exécution à `anon` pour `rumeurs_organisations_cibles` et `cron_alerte_etat`, et passer en revue les 23 autres fonctions signalées.

## Décision de Fred (17/11/2026, 0 h 08)
**Pas de jeu anonyme : il faut un compte et s'identifier pour jouer.** Les sessions anonymes sont supprimées. La correction 2 devient : désactiver la connexion anonyme dans Supabase, exiger un compte confirmé par courriel dès l'entrée dans le jeu, ajouter un captcha à l'inscription. Avant de couper, contacter les 6 personnages rattachés à un compte anonyme pour qu'ils confirment une adresse, puis supprimer les comptes anonymes vides.

## Question posée à Fred (tranchée ci-dessus)
Les failles 2 et 7 rejoignent la proposition 5 de `PROPOSITIONS-MECANIQUES-LANCEMENT.md`. **Accepte-t-on qu'un visiteur anonyme puisse explorer le jeu, mais que voter, se présenter, créer un parti, faire un don et commercer exigent un compte confirmé par courriel ?**

Toutes les autres corrections sont techniques et peuvent être faites dès ton feu vert, dans une session rattachée au dépôt en écriture. À annoncer dans RELAIS.md pour ne pas croiser ChatGPT.
