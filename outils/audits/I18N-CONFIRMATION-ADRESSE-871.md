# #871 — confirmation d’adresse sur l’accueil

Quatre textes fixes de `rpRetourConfirmation` (lien expiré et adresse confirmée,
chacun avec titre et explication), ajoutés au catalogue `connectionUi` existant.
**32 nouvelles traductions étrangères**, français exactement repris des chaînes
assemblées d’origine. Les neuf anciens messages de connexion restent identiques.

Quatre attributs `data-i18n` et deux appels à `appliquerTraductionsRP` sur le rendu
nouvellement affiché : aucune nouvelle infrastructure ni réexécution du parcours.
La bascule utilise le moteur existant sans relire le fragment URL, rouvrir le
formulaire ou agir sur la session. Le corps des messages est entièrement fixe.

## Preuves

AST entier de `creation.js` identique après retrait des seuls attributs et appels
de présentation. Les conditions d’erreur/succès, l’effacement du fragment, la
protection du panneau déjà ouvert et les parcours de connexion restent identiques.
Aucun RPC, session, donnée personnage, PA, prix ou mécanisme de jeu modifié.
Aucune fonction Supabase, migration, permission ou réglage Auth modifié.

Chromium réel : **108 arrivées et 972 bascules**, neuf langues initiales et neuf
langues de destination, 320/390/1280, arabe RTL, allemand/russe, repli français.
Lien expiré, succès avec panneau fermé ou ouvert, fragment étranger conservé.
Aucune authentification, aucun appel métier, aucune nouvelle lecture du fragment,
aucune perte d’adresse, mot de passe, focus, sélection, brouillon, session ou état.
Le hook de rafraîchissement courant est exécuté ; les conditions d’accès restent
celles d’origine. Tests des traductions initiales et bascules en cours de parcours.

Banc existant `banc-i18n-connexion-ui.cjs` : 12 tests verts, anciennes erreurs,
appels/cache/redirection identiques, formulaire pendant requête et rendu bureau.
Vérification par simulation uniquement, aucun compte réel créé ou connecté.
Relecture native et téléphone physique non réalisés. Même extracteur avant/après main `196af01` : corpus 7 565 textes / 50 690 mots inchangé ; +4 textes / +64 mots source raccordés par langue étrangère, autant de ressources. Anglais : 998 textes et 12 125 mots raccordés (23,92 % des mots identifiés). 31 tests Node finaux verts. CI et production à compléter avant livraison.

La garde de périmètre compare base et commit de code du lot, pas le merge temporaire GitHub (qui inclut les migrations étrangères ajoutées entre-temps sur main, telle #905). La preuve AST porte toujours sur le programme entier du lot.
