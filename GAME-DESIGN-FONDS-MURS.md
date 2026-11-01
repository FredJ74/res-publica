# Fonds et murs des commerces — règles du game designer (#66)

Décisions de Fred du 21 octobre 2026 (issue #66, `outils/audits/ISSUE-66-ARBITRAGES.md` de la
PR #71) et du 1er novembre 2026 (surfaces). Référence pour tout agent : ne pas redemander ce qui
est tranché ici.

## Deux titres indépendants

- Un commerce a deux titres distincts : le **fonds de commerce** (l'entreprise, son exploitation)
  et les **murs** (le bâtiment).
- Acheter le fonds ne transfère jamais les murs ; acheter les murs ne transfère jamais le fonds.
- Un PJ peut acheter le fonds seul, les murs seuls, ou les deux. L'achat conjoint est **un seul
  acte** : jamais de demi-achat (tout ou rien).
- À l'origine, les **murs des commerces PNJ appartiennent à la commune** de leur ville ; les fonds
  PNJ sont distincts.

## Prix

- **Murs vendus par la commune** : surface × prix au m² du pays. Républia : **150 FR/m²**, sans
  coefficient de ville, de quartier, de standing ou de type de commerce. La seule variable entre
  pays est le prix au m².
- **Fonds PNJ** : prix du catalogue existant (armureries 130 000 FR, imprimeries 180 000 FR,
  commerces alimentaires selon `entreprises_prix_rachat`).
- **Dès qu'un PJ possède un fonds ou des murs, il fixe librement son prix de vente**, sans plafond
  ni plancher. Le notaire distingue « prix de référence » et « prix demandé par le propriétaire ».
- Règle économique : construire soi-même ne doit pas coûter plus cher que d'acheter les murs d'un
  bâtiment existant comparable (cessions non-PJ seulement).

## Surfaces validées

| Commerce | Ville | Surface | Murs (150 FR/m²) |
|---|---|---|---|
| La Republica (hôtel-restaurant-bar, bâtiment unique) | Luthécia | 1 200 m² (21/10) | 180 000 FR |
| Hôtel Mineur | Montrouge | 800 m² (01/11) | 120 000 FR |
| Hôtel du Port | PSM | 800 m² (01/11) | 120 000 FR |
| Café de la Gare, Brasserie des Voyageurs, Café-Tabac des Cheminots | Montrouge | 550 m² (01/11) | 82 500 FR |
| Bar des Pêcheurs, Capitaine Sauvage | PSM | 550 m² (01/11) | 82 500 FR |
| Armureries (Luthécia, Montrouge, Maison Le Gall à PSM) | — | 550 m² (01/11) | 82 500 FR |
| Imprimeries (La Tribune à Luthécia et Montrouge, imprimerie-librairie de PSM) | — | 700 m² (01/11) | 105 000 FR |

Un commerce sans surface validée ne peut pas voir ses murs vendus : ne jamais inventer de surface.

## Vente de murs occupés : priorité de l'exploitant

- Le propriétaire des murs les met en vente **chez le notaire**, sans l'accord de l'exploitant.
- Si un autre PJ exploite le fonds, il reçoit **automatiquement un courrier** : il a **3 jours
  réels** de priorité pour acheter au prix annoncé. Pendant ce délai, aucun tiers ne peut acheter.
- **Refus explicite** de l'exploitant : publication immédiate à tous. **Sans réponse** : publication
  automatique au bout de 3 jours, même sans joueur connecté. Il perd alors sa priorité pour cette
  mise en vente et achète comme n'importe qui.
- La vente des murs conserve l'exploitation (bail éventuel et ses conditions).

## Choix techniques retenus (agent)

- Titre des murs : table `murs_titres` (identifiant = celui de l'entreprise exploitante) ; titre du
  fonds : `entreprises.data.proprietaire`, inchangé. Barème par pays : `immobilier_baremes`.
- Un seul moteur serveur (`immobilier_acheter`) pour murs, fonds mis en vente par un PJ et achat
  conjoint, idempotent par requête. Le rachat d'un fonds PNJ **seul** reste le parcours existant
  (compromis de 7 jours, prêt possible, acte au notaire).
- Fin de priorité décidée par l'heure du serveur à chaque lecture et à chaque achat : aucun cron.
- Argent : murs communaux versés à la caisse de la mairie ; prix d'un PJ vendeur versé en liquide ;
  fonds PNJ comme le rachat existant.
- Acte : 1 PA (ordre `officialiser_transaction`). Mise en vente, retrait et renoncement : gratuits.

## Loyer entre murs et fonds (décision de Fred, 01/11/2026, 20 h 57)

- Chaque commerce a un **loyer quotidien**, payé par l'exploitant du fonds au propriétaire des murs
  (commune ou PJ), sur le modèle des baux existants (locaux des centres, lots des immeubles).
- **Pas de loyer quand le fonds est tenu par un PNJ** : les PNJ ne fixent pas leurs prix (marge
  contrainte à ×2), il n'y a pas assez de clients pour les faire tourner, et un PNJ ne gagne pas
  d'argent : il serait vite exproprié. Le loyer est fixé mais pas appliqué.
- Montant de départ (murs communaux) : **1 FR/m²/jour** (option A, choix de Fred du 01/11 à 21 h 05) :
  550 FR/j pour les cafés et armureries, 700 FR/j pour les imprimeries, 800 FR/j pour les hôtels,
  1 200 FR/j pour La Républia. À recalibrer en jeu si besoin.
- Le bail survit à la vente des murs : le nouveau propriétaire touche le loyer.
- **Payeur** (Fred, 01/11, 23 h 30) : la **caisse du commerce d'abord**, le complément sur les avoirs
  de l'exploitant (liquide puis comptes ; caisse de l'organisation si le fonds lui appartient).
- Pas de loyer non plus quand le même titulaire tient murs et fonds.
- **Impayé** : règle des baux (arbitrage du 8 septembre 2026) — avertissement la première nuit, puis
  dette inscrite et conservée, un seul avis à l'exploitant et au propriétaire PJ des murs ; jamais
  d'expulsion automatique. Un nouvel exploitant n'hérite pas de la dette du précédent (archivée).
- Choix techniques : `immobilier_baremes.loyer_m2_jour`, état par titre dans `murs_loyers`,
  prélèvement `murs_loyer_prelever` / passe `murs_loyers_nuit` (cron de minuit, identité serveur),
  loyer et ardoise (visible des deux parties) rendus par `immobilier_catalogue`.

## Non arbitré (ne pas inventer)

- Changement de prix pendant la priorité : interdit techniquement (retirer puis remettre en vente,
  ce qui rouvre une priorité et renvoie le courrier).
- Règles de revente dans les autres empires.
