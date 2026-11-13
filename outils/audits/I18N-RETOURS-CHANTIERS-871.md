# #871 — retours fixes des commandes de chantier

Base : `8f92528`, après livraison des lots partagés #885 et #893.

Dix corps de notification et huit titres sont internationalisés dans les neuf
langues existantes : **18 clés, 144 traductions étrangères nouvelles**.
Les messages concernent une commande précédente à reprendre, l’impossibilité de
conserver une reprise sûre, la relecture de l’état ou des finances, la réception du
bâtiment, les salaires et les prix. Variables et unités `FR` restent celles de la
source. Aucun texte libre d’un joueur n’est traduit.

L’architecture livrée est réutilisée : `RPI18nPlateau.markToast`,
`RPToastI18n.registerTitle`, ressources i18next. Aucune nouvelle API ou moteur.
`showToast` conserve tous ses arguments canoniques ; les incidents restent français.
Le titre et le message affichés se rafraîchissent sans réexécuter la commande.

## Conservation du fonctionnement

Après retrait des dix marqueurs de présentation, l’AST entier de
`plateau-construction-commandes.js` est identique à la référence. Un unique `if`
sans accolades est enveloppé pour garder le marqueur sous la garde d’origine.
Aucun coût, tarif, PA, prix, droit, retour serveur, requête, verrou, intention de
reprise ou identifiant de commande n’est modifié. Aucune migration ou fonction
Supabase changée. Les salaires minimum et montants viennent des mêmes variables.

La preuve de cette migration est conservée par commit pour ne pas figer les futurs
chantiers de jeu. Le banc courant vérifie également que les dix marqueurs et les
français de référence restent présents.

## Vérifications

- Dix messages et huit titres : français exact de la référence, neuf langues
  complètes, variables et unités conservées.
- Service commun des titres, anciennes traductions et repli français testés.
- Chromium 320/390/1280, neuf langues et RTL : **270 rendus** et **270 bascules**
  sur dix chemins réels (reprise en attente, stockage refusé, état/finances à relire,
  réception, salaire refusé/enregistré, prix invalides/non confirmés/à relire).
- Le stockage réel d’une origine fictive conserve les intentions et identifiants.
  À la bascule : appels, verrous, finances, progression, inventaire, brouillons,
  focus, sélection, incidents et minuterie de notification inchangés.
- Les chemins de confirmation utilisent des réponses simulées. Aucun compte joueur,
  paiement, bâtiment réel, commande réelle ou réseau métier utilisé.
- Ressource allemande absente : français exact. Notification libre suivante : aucun
  texte précédent ne revient et son contenu n’est jamais traduit.

## Hors lot et limites

Les réponses serveur variables (y compris la notification conditionnelle
« Commande non confirmée »), les autres fenêtres du dossier et les contenus RP ne
sont pas déclarés traduits par ce lot. Les règles de reprise existantes ne sont ni
corrigées ni réinterprétées. Compte authentifié, téléphone physique et relecture
linguistique native non vérifiés. Mesures, CI et production : relais et PR.
