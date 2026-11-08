# Tirages — lot dons aux PNJ — 8 novembre 2026

Branche `codex/tirages-dons-pnj-20261108`, départ main `d633524f`.
Inventaire général indépendant : branche `codex/tirages-ecran-inventaire-20261108`,
`outils/audits/TIRAGES-ECRAN-20261108.md` (75 appels, dont 20 décisifs à cette coupe).

## Correction et conservation des formules

Le don était déjà débité dans `jauges_ordre_executer('don_argent_pnj',...)`, avec
présence PNJ, refus initial, POP/INF et reçu de requête. Après réponse, l’écran
retirait encore DIS au hasard depuis une copie périmée. Le lot termine cette
**même** commande ; ni nouveau paiement, ni table ni moteur de don.

| Métier | Taux, pour DUP effective | Perte DIS succès / échec |
| --- | --- | --- |
| Commissaire | min(70,30+floor(DUP×2)) | 5 / 20 |
| Policier | min(65,25+floor(DUP×2)) | 3 / 15 |
| Inspecteur | min(70,35+floor(DUP×2)) | 5 / 15 |
| Juge | min(55,20+floor(DUP×2)) | 8 / 25 |

Jet uniforme entier 1..100, succès si jet≤taux. Refus préalable déjà au serveur :
aucun débit, −15 DIS. Banquier : +5 DIS plafonné à 100, sans jet. Autres métiers :
effets existants inchangés. Le `state.dis || 50` historique (y compris DIS=0) est
**conservé**, pas corrigé silencieusement. À réexaminer séparément si Fred souhaite
changer cette règle héritée ; aucun solde ni taux n’est modifié ici.

DUP est le port de `getMembresGroupeAvecStat` / `getStatEffective('DUP')` : moyenne,
profils de repli exacts du client, effets actifs, affaiblissement Santé et arrondi
`floor(x+0.5)`. Le banc vérifie tous les profils contre data.js. La projection
**existante** `employe_mes_employes()` valide les membres et leurs caractéristiques :
un miroir ancien falsifié ou contradictoire annule l’opération entière. Il n’est
pas utilisé pour inventer une nouvelle moyenne ou remplacer discrètement les
anciens profils par un autre barème. Les profils du socle et certains anciens
replis du client diffèrent réellement ; le prévol doit les signaler **avant**
activation. Pas de réparation automatique de fiche ou de caractéristique.

## Contrat et déploiement (non exécuté)

Migration : `migrations/20261108130723_dons_pnj_dis_serveur.sql`.
**Dépendante de l’écran**. Ordre prévu :

1. Claude ouvre la PR, vérifie CI puis intègre le client ; attendre Vercel READY.
2. Exécuter le prévol **en lecture seule** `outils/bancs/prevol-tirages-dons-pnj.sql`.
   Il ne retourne que des compteurs et une empreinte, aucun nom ou solde.
   Si les miroirs/profils divergent, **ne pas activer**, réconcilier par le socle
   avec revue appropriée ; ne pas choisir arbitrairement d’autres caractéristiques.
3. Sur une base isolée fidèle, jouer le banc annulé sous authenticated ; comparer
   les ancres de la fonction réelle. La migration refuse un corps non examiné.
4. Claude applique la migration complète en une transaction via le registre,
   vérifiée par **NOM** `dons_pnj_dis_serveur`, puis réextrait suivant WORKFLOW.
5. Vérifier sur compte isolé. Aucun don réel demandé pour ce prévol.

Le nouveau client envoie `contrat_dis:1`. Avant SQL, l’ancien serveur le refuse
**avant débit**. Après SQL, un ancien navigateur sans cette version est refusé
**avant débit**, au lieu de tirer une seconde DIS locale. Le client n’a aucun
fallback local. Même reçu : même jet/verdict, DIS et soldes relus à leur état
courant ; une réponse perdue ne crée ni nouveau prélèvement ni nouveau jet.
Les droits et les branches tierces du dispatcher sont conservés par patch ciblé.

Aucune migration appliquée. Aucun accès Supabase, API GitHub ou Vercel retenté.
Aucun fichier Sovarka, montant, texte RP ou ordre du catalogue modifié. Le seul
nouveau message nomme une réponse de contrat non confirmée. Cache JS plateau majoré.

## Vérifications

- Client dédié : 10/10 ; Math.random et getStatEffective interdits dans la fixture,
  succès/échec/refus, DIS zéro, banquier, rejeu et réponses incomplètes.
- Régressions avec le banc de jauges existant : 49/49 tests clients ciblés.
- PostgreSQL jetable : **93/93** assertions en transaction annulée sous
  `role=authenticated`, `request.path=/rpc/jauges_ordre_executer` ; corps réels de
  débit et de dispatcher, projection PNJ existante. La vue de lecture personnages
  est minimale ; ce n’est pas une reconstruction du catalogue complet.
- Deux courses authentifiées réelles sur le cluster détruit : même clé → un
  débit, un jet et un rejeu ; clés distinctes avec fonds insuffisants → un seul
  débit et refus intégral du second. Fixtures uniquement.
- Installation, rollback, installation puis rejeu vérifiés.
- Contre-épreuves : jet forcé à 1 et écriture DIS supprimée sont réellement
  détectés par le banc SQL. Aucune assertion désactivée.
- Bureau : comparaison stricte 1440 du banc de certification, 1/1.
- Contrôleur client complet et Workflow : en fin de lot.

Les migrations anciennes ne sont pas rejouées en bloc : seules les tables et
routines nécessaires sont extraites pour la base jetable. Les autres fonctions
ne sont pas certifiées par ces tests. Les comptes et les soldes réels n’ont
jamais été lus ou modifiés.
