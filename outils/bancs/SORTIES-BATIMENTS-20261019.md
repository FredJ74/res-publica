# Sorties des bâtiments — 19 octobre 2026

## Diagnostic et périmètre

Reprise de main d58cfcdafb4e4e396d1db2be9da13f5fa1211683 ; fetch avant modification et avant livraison. Aucun changement de données, RPC, migration ou règle métier. Aucun traitement particulier ajouté à l'office notarial.

Défauts vérifiés dans le code précédent : `sbRpc` aplatissait transport, authentification et refus ; trois tentatives répétaient même les refus ; une confirmation perdue était acceptée sur le seul verdict « pas dans un bâtiment », sans lecture de la rue ; aucune protection contre les réponses d'un ancien personnage ; après confirmation, une seconde lecture de rue pouvait échouer pendant le rendu. La provenance du carrefour était également perdue dès qu'un bâtiment déterminait le nœud extérieur.

**Le déclencheur exact de l'incident vécu en production n'est pas établi.** Ni journaux de la session concernée, ni accès authentifié Supabase/Vercel ne sont disponibles ici. Le tunnel HTTPS de cet environnement refuse les connexions testées (403 CONNECT, avant réponse applicative). Cela ne démontre aucune panne du jeu ou du fournisseur. Les droits et la sortie notaire signalés par le propriétaire ne sont pas remis en cause.

## Correction commune

- `plateau-navigation.js` : verdicts structurés existants, messages distincts session/HTTP/réseau/refus/sortie absente/réponse illisible/confirmation incertaine. Diagnostic technique limité à étape, catégorie, statut et code filtré ; aucun corps serveur, jeton ou identité journalisé.
- Une lecture de sortie puis une seule commande ; après réponse perdue, lecture de `rue_position_lire`, acceptée uniquement si personnage et contexte inchangés, pays/ville concordants, bâtiment null et rue connue. Un refus métier explicite n'est jamais transformé en réussite.
- Verrou d'intention et garde personnage, compte, session, ville, bâtiment et pièce. Prison et interception restent contrôlées ; les handlers de sorties spéciales sont préservés.
- `supabase.js` : option de garde avant envoi, après renouvellement d'authentification, pour éviter d'envoyer une intention périmée sous une nouvelle session. Les autres appels conservent leur contrat.
- Rendu par le moteur de rue existant avec position déjà confirmée ; pas de deuxième ordre ni de lecture supplémentaire indispensable au rendu. La mémoire ne fournit que l'orientation, jamais l'autorité de déplacement. Les quatre variantes du carrefour PSM sont conservées.
- Pas de sauvegarde générale du personnage pour persister un déplacement déjà enregistré côté serveur ; cache local conservé. Les autres empires gardent leur sauvegarde historique.
- `plateau.html` : versions des deux scripts actualisées.

## Vérifications

`banc-sorties-batiments.cjs` : **38/38 tests locaux**. Office notarial, trois villes, terrain Montrouge, sorties de pièce/handler, succès, session perdue, HTTP 403/500, réseau, corps illisible, refus métier, sortie non référencée, double clic, reprise déjà dehors, lecture encore en bâtiment, réponse tardive/personnage/compte/session/ville/pièce, prison/interception, renouvellement auth avant envoi, orientations PSM.

Les RPC de ces tests sont simulées : aucun test de joueur réel. Les bancs de rue et Chromium existants couvrent en complément les deux terrains à bâtir Luthécia/PSM et les quatre images/zones/directions contextuelles PSM.

Contre-épreuves : **90/90**. Syntaxe API, syntaxe des deux scripts, diff et garde payload Vercel : conformes. Contrôles globaux : **10/12**, sans ajustement de baseline. Authority : 20 RPC non retrouvées dans le baseline archivé ; cela ne constitue pas une preuve d'absence en production. Referential : deux empreintes en écart (`ordres_couts`, `postes_nommes_regles`). Ces écarts préexistaient ; aucune falsification ni régénération manuelle.

Une première exécution du contrôleur client a donné 86/87 : le pont local JavaScriptCore forçait à tort le vérificateur syntaxique portable vers sa branche macOS. Le banc concerné échouait sur un module valide avec import et export sur la même ligne. L'environnement de test local a été corrigé pour laisser ce vérificateur utiliser Node natif, sans changer le code ni les assertions du dépôt. Relance complète : **87/87 bancs réussis**. Après les trois derniers cas de garde, relance ciblée du nouveau banc et des bancs navigation, interception et Chromium ; aucun test désactivé.

## Production et suivi

Push sur main autorisé par la mission ; déclenchement automatique attendu, succès Vercel non observable dans cette session. À contrôler avec un accès technique autorisé : statut du déploiement puis sortie authentifiée de l'office notarial et d'un bâtiment ordinaire, navigation entre pièces, retour sur les terrains et orientations PSM. Aucune réussite en jeu n'est revendiquée. Si l'incident persiste, les catégories conservées permettront de distinguer authentification, HTTP, refus et incertitude au lieu d'accuser le réseau sans preuve.
