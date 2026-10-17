# Stabilisation des sessions, interfaces et retours serveur — 18 octobre 2026

## Verdict

**CHANTIER PARTIELLEMENT CORRIGÉ ; CLÔTURE ET DÉPLOIEMENT NON VÉRIFIÉS.** Les corrections indépendantes ci-dessous sont testées localement et intégrées à `main`. Aucun test authentifié en production, aucune migration appliquée, aucune donnée de joueur modifiée. La branche financière `codex/reconstruction-finances-atomiques` (`a3e48c0fab31a8e20b26af37bce5fc01eecff91e`) reste séparée : sa protection financière globale n'est pas livrée par ce lot.

Point de départ vérifié : `origin/main` à `e1cff10998d70d6cd6de90cb007f32b05c1863ea`. Branche de réalisation : `codex/stabilisation-session-20261018`. Les optimisations récentes, corrections commerciales et policières de main sont préservées.

## Corrections et preuves

| Commit | Correction |
|---|---|
| `97ac1d9` | Repos déjà enregistré reconnu ; reprise bornée du seul RPC de repos quotidien ; historique de session ; mot de passe Identité via GoTrue ; nettoyage des infobulles ; charte commune ; portrait en liquide. |
| `452427d` | Diagnostics de transport RPC, réponse JSON invalide distinguée ; destruction de l'infobulle quand son élément source disparaît ou qu'une modale s'ouvre. |
| `a8f0eef` | Banc de rendu portrait/inventaire, dont solde nul et 5,50 FR. |
| `b363d74` | Journal aligné sur les 18 ressources canoniques et leurs prix réels, dont laitages ; résolution effective de sa divergence mesurée. |
| `dfa6c25` | Deux migrations civiles déplacées à contenu strictement identique dans `migrations/` ; chemins CI corrigés ; test des fermetures exécuté sur les vrais helpers aux minuits Paris d'été et d'hiver. |
| `00590f1` | Une rotation normale de JWT ne fait plus ignorer les réponses valides : gardes fondées sur `session_id`, avec UID et personnage ; nouvelle connexion toujours rejetée. |

### Dormir et retours tardifs

Le contrat SQL archivé de `pa_repos_nocturne` renvoie `deja_repose`, motif absent de l'ancienne reconnaissance cliente. Le client adopte désormais le PA renvoyé, y compris zéro, sans rejouer soins ou salaire. Si la réponse manque, une seule seconde lecture/exécution est autorisée pour ce RPC protégé par son verrou quotidien. Deux réponses absentes produisent un résultat explicitement indéterminé, jamais un faux refus définitif. Aucun rejeu générique des actes financiers n'a été ajouté.

Le personnage, le pays, le compte et la connexion sont vérifiés avant d'appliquer un retour. Les protections de commerce, banque, inventaire, justice, soins, politique et terminal militaire distinguent maintenant renouvellement du JWT et nouvelle session. Le vrai bearer reste utilisé pour l'authentification HTTP : `session_id` ne donne aucun droit.

Limite : la séquence historique complète du sommeil comporte encore des effets clients et un salaire séparé. Ce lot ne les transforme pas en transaction serveur unique et ne prouve pas leur atomicité en production.

### Infobulles et interfaces

L'infobulle de rue `#rc-tooltip`, ajoutée au body, survivait à sa source ; le nettoyage existant visait seulement celle de la minimap. Nettoyage commun aux transitions, observation bornée à la durée de vie de la bulle et suppression au retrait de la source ou ouverture d'une modale. Le navigateur reproduit l'ancien défaut avant d'éprouver le correctif.

Les modales ordinaires et dialogues matières du commerce réutilisent la palette ardoise/or existante, avec champs lisibles, focus, défilement et contraintes mobiles. Les interfaces machine spécifiques restent conservées. Les règles de transaction et de police ne changent pas.

L'historique technique conserve au maximum 30 incidents en mémoire de session/personnage, sans requêtes, secrets ou réponses brutes. Il apparaît seulement après un incident. Le changement de mot de passe utilise le compte GoTrue authentifié et confirmé, avec protection contre le changement de compte pendant les attentes. Aucun mot de passe réel n'a été modifié lors des tests.

### Argent

Les deux rendus du compteur sous portrait lisent exclusivement `liquide`, comme l'inventaire ; banques et fortune restent distinctes. Aucun crédit, débit ou correctif au personnage d'Angie. Les risques des sauvegardes financières historiques restent du ressort du chantier financier séparé.

## Vérifications exécutées

| Vérification | Résultat et portée |
|---|---|
| `python3 outils/bancs/controler-client.py` | **73/73 bancs** ; exécutions locales avec doublures selon les bancs, aucun SQL distant. |
| `node --test outils/bancs/banc-stabilisation-session.cjs outils/bancs/banc-infobulles-navigateur.cjs` | **14/14** : 11 tests de session/transport/compte et 3 essais Chromium. |
| Chromium réel par CDP | Ancien défaut reproduit ; correctif éprouvé à 1280 et 390 px, transitions, source retirée, survol tardif, modale et défilement. Fixture utilisant les composants réels, pas une session authentifiée du jeu. |
| `node --test outils/bancs/test-*.mjs` | **5/5**, calendrier et fermetures. |
| `contre-epreuves-chantier5.py` | **90/90**, régressions volontairement réintroduites dans des copies ; assertions conservées. |
| Réception atomique locale | **31/31 groupes**, PostgreSQL isolé, services annexes simulés. |
| Achat local | **12/12 groupes**, PostgreSQL isolé ; ne prouve pas le déploiement distant. |
| Syntaxe API | **23 modules** analysés. |
| Garde Vercel | Conforme : charge utile sous 330 Mo, marge environ 16,9 Mo. |
| `verifier-workflow.py` | **9/9 invariants** conformes. |
| `controler-tout.py` | **10/12**, deux contrôles rouges conservés ci-dessous. |
| Catalogue Supabase vivant, parcours authentifiés, Vercel Preview/Production | **Non exécutés / inaccessibles**. |

Adaptation d'environnement pour les anciens bancs : Node remplace JavaScriptCore via un lanceur externe au dépôt ; le chemin historique macOS des sources est redirigé vers le dépôt local. Aucune assertion n'est supprimée. Les bancs Chromium passent par CDP ; le mode `--dump-dom` de ce conteneur ne terminait pas correctement.

### Contrôles rouges exacts

**Autorité** : quatre RPC utilisées par le client absentes du baseline archivé : `inventaire_reception_etat`, `inventaire_reclamer_livraison`, `inventaire_sauver_revision`, `tracts_electoraux_distribuer_collectif`. Des scripts préparés ou photographies hors registre ne constituent pas une preuve de déploiement. Nécessite inventaire vivant des signatures, droits, RLS et registre des migrations avant réconciliation.

**Référentiels** : cinq problèmes : empreinte calculée `ordres_couts` = `79ecb2f9d4bf71f5`, déclaration = `20e52d8f9bbe8e3f` ; `postes_nommes_regles` calculée = `694f117ace57b0b1`, déclaration = `6c0c7aa0d29bf852` ; trois déclarations de divergence devenues incohérentes (`ordres_couts/base`, `ordres_couts/posee`, `postes_nommes_regles/posee`). Aucun relevé vivant ni empreinte observée n'est remplacé artificiellement.

## Audit des branches et PR

Les références Git des quatre PR ont été récupérées et comparées. L'API GitHub est bloquée par le proxy HTTP 403, y compris avec l'authentification disponible : état ouvert/fermé/brouillon, contrôles distants et commentaires non vérifiables.

- **PR 40**, tête `ea7a8a3604280d93aa49063eda3f516182ba5dc7` : non intégrée à main au contrôle. Contient 20 migrations et de nouveaux contrats de détection, position et résolution policière, dont suppression d'une ancienne signature de combat. Conservation séparée : compatibilité du serveur vivant non démontrée. Fusionner sans ce contrôle risquerait de casser les interceptions.
- **PR 35** : ancien correctif partiel d'interception, conservé séparément. Pas de résurrection de ce circuit face aux correctifs plus récents de main.
- **PR 21** : préparation du calendrier ; main contient depuis les corrections civiles dédiées. Pas de fusion de préparation sans preuve de besoin.
- **PR 19** : préparation football ; les optimisations des PR 18 et 20 sont déjà présentes dans main. Conservation séparée ; pas de clôture ni qualification d'obsolescence sans examen distant complet.

Aucune de ces PR n'est annoncée comme fusionnée ou fermée par cette intervention.

## Remontées supplémentaires : état et limites

- **Nourriture** : circuit d'inventaire et tests existants exécutés, quantité/PA/fraîcheur serveur préservés. Pas de création d'aliments ni de test sur joueur réel ; état des anciens aliments en production non inspecté.
- **Désinfectant** : routes de vente médicale présentes pour les trois villes ; règles de structures permettent les fournitures attendues. Stocks, caisses et autorisations effectivement déployées impossibles à inspecter. Aucun ajout de stock fictif.
- **Commerce automatique** : interface récente conservée, dont suppression des commandes de vente redondantes. **Point ouvert précis** : le SQL d'achat archivé refuse encore `active:false` (`reference_inactive`), alors que le client ne propose plus le basculement historique. Il faut confronter la définition vivante avant une correction SQL gardée ; aucun contournement client ni faux drapeau ajouté.
- **Relations PNJ** : les étiquettes demandées étaient déjà absentes de main. Relations internes et statut de coma des personnages conservés.
- **Jodie Moitout** : circuit retrouvé dans `plateau-communication.js` ; aucune cause de panne nouvelle démontrable sans contexte de reproduction authentifié et réponse serveur. Ne pas annoncer cette anomalie réparée.
- **Tracts/collectif** : bancs clients exécutés ; existence distante de la RPC collective non démontrée (contrôle Autorité rouge).
- **Sondages excessifs** : corrections récentes déjà dans main conservées. Pas de mesure de charge réelle Supabase ou Vercel possible.

## Production et suite sûre

Aucun accès utilisable au catalogue Supabase ou à Vercel n'est exposé dans cette session ; aucun jeton Supabase/Vercel ni connexion SQL n'est configuré. Les appels HTTP externes examinés sont refusés par le proxy (403). L'URL Vercel réelle du projet n'est pas certifiée par une URL supposée. Git fetch/push fonctionne, mais ne prouve ni build réussi ni code effectivement servi.

Aucune migration n'a été appliquée. Les deux migrations civiles déplacées sont strictement inchangées ; leur présence Git ne renseigne pas leur application réelle. Les migrations financières restent non déployées.

Après disponibilité des accès techniques : lire le catalogue et les versions réellement actives, réconcilier les quatre RPC et référentiels ; valider la chaîne policière PR 40 ; corriger le contrat de vente automatique si l'écart serveur est confirmé ; observer Preview puis Production ; réaliser des parcours authentifiés isolés (repos/rechargement, commerce/matières, soins, nourriture, tracts, Jodie, interception). Aucun de ces contrôles n'est délégué au game designer et aucune réussite n'est présumée.

## Intégration Git effectivement vérifiée

Push sans forçage de `e1cff10` vers `dffed23951ada08cb6199ce90d18cc416e69c5e5` accepté sur `main`. La lecture distante `git ls-remote` confirme ce SHA sur `main` et sur la branche de sauvegarde. Le présent complément documentaire est ajouté ensuite ; il ne modifie aucun code testé. Aucun état de build GitHub Actions ou Vercel n’a pu être observé. **Code intégré et sauvegardé sur GitHub ; déploiement et essais authentifiés non vérifiés.**
