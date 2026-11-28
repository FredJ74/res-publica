# Paiement du premium par Stripe, en fonctionnement mixte (28/11/2026)

Décision de Fred du 28/11/2026 (étape 4 de la mission de l'après-midi), qui remplace le revendeur du 25/11 (Paddle) :

- **France et Union européenne** : Stripe classique. **L'éditeur est le vendeur.** Fred est en franchise de TVA : écran et
  factures portent « TVA non applicable, article 293 B du CGI ».
- **Reste du monde** : **Stripe Managed Payments**. Stripe est le vendeur officiel (marque Link : « Vendu via Link ») ; il
  calcule, collecte et déclare les taxes, envoie reçus et factures, traite assistance, litiges et fraude.
- **Réglage serveur** pour étendre Managed Payments à l'UE plus tard, sans recoder : `premium_parametres.paiement_mp_pour_ue = 1`
  (page MJ, bloc « Paiement (Stripe) »).
- Pays que Stripe ne sert pas : **aucun achat, le jeu reste entièrement gratuit**.

Code : `api/_paiement.js` (serveur, greffé sur `api/chat.js`), `api/_paiement-courriels.js` (e-mails, 9 langues),
`plateau-paiement.js` (écran, 9 langues), `admin-premium.js` (réglages MJ), migration `20261128120000_paiement_stripe.sql`
(**appliquée le 28/11/2026** après essai annulé « TESTS_OK », relue). Bancs : `banc-paiement-stripe-20261128.mjs` (20),
`banc-paiement-stripe-pglite-20261128.cjs` (8), `banc-paiement-ecran-20261128.cjs` (5), `banc-paiement-premium-20261125.mjs` (5).

## Ce qui se passe quand un joueur achète

1. Le joueur ouvre la fenêtre premium et clique « Acheter — prix ». Le prix vient de la base (`premium_produits`, réglage MJ,
   jamais sous 2 €) ; l'écran n'en écrit aucun.
2. **Écran de confirmation** (`plateau-paiement.js`) : le serveur dit qui vend (selon le pays) ; l'écran affiche
   « Vendeur : <nom de l'éditeur>. TVA non applicable, article 293 B du CGI. » ou « Vendeur : Stripe (Link), vendeur officiel ».
   Case **CGV** (lien vers les CGV) ; pour un achat à l'unité ou une option, case **non pré-cochée** « Je demande la livraison
   immédiate et je renonce à mon droit de rétractation ». Le bouton « Payer » reste bloqué tant que les cases exigées ne sont
   pas cochées. Abonnement : renouvellement automatique, résiliation et remboursement de 14 jours rappelés.
3. Le serveur : pays de l'acheteur (géolocalisation de Vercel, en-tête `x-vercel-ip-country`, posé par la plateforme — jamais
   envoyé par le navigateur) → `premium_paiement_contexte_service` décide le mode (« editeur » ou « stripe ») ou refuse ;
   `premium_achat_preparer` (jeton du joueur) crée l'achat « en_attente » au prix de la base ; `premium_achat_consentir_service`
   enregistre les cases cochées (sinon l'achat est annulé avant tout paiement) ; création de la session Stripe Checkout
   (REST, clé d'idempotence `achat-<id>`) ; `premium_achat_lier_service` note la référence.
4. Le joueur paie sur la page hébergée par Stripe, puis revient au jeu (« Paiement reçu : activé dès que Stripe le confirme »).
5. **Seul le webhook signé confirme** : `POST /api/paiement/webhook`, en-tête `Stripe-Signature` (`t=…,v1=…`), HMAC-SHA256
   de « t.corps brut » avec le secret du point de terminaison, tolérance 300 s. `checkout.session.completed` (ou
   `async_payment_succeeded`) → `premium_achat_confirmer_service` (montant hors taxes ajoutées et devise revérifiés : euros,
   même quand le client paie dans sa monnaie ; idempotent) → `premium_achat_paiement_noter_service` (référence du paiement,
   fiche d'abonnement, doublon) → e-mail de confirmation (une seule fois).

Pourquoi le pays de Vercel : il est connu avant la page de paiement (on doit dire qui vend **avant** de payer) et le
navigateur ne peut pas le choisir. Limite connue : un réseau privé virtuel change le pays apparent ; Checkout recueille aussi
l'adresse de facturation (obligatoire en mode éditeur), visible dans Stripe en cas de doute.

## Abonnements (Stripe Billing)

- Mensuel (`abonnement_mensuel`) et **annuel** (`abonnement_annuel`, nouveau, prix non fixé) ; renouvelés automatiquement.
  Le prix d'un abonnement est celui du jour de la souscription (un changement de prix MJ vaut pour les nouveaux abonnés).
- **« Résilier mon abonnement »** : fiche du personnage → onglet Identité → bloc « Abonnement » : 1er clic « Résilier mon
  abonnement », 2e clic « Confirmer la résiliation ». Stripe reçoit `cancel_at_period_end=true` ; l'abonnement reste actif
  jusqu'à la fin de la période payée. Hors UE, le joueur peut aussi résilier depuis son compte Link.
- **Ce qui a été activé pendant l'abonnement reste acquis** : la première activation d'une option attachée à un lieu (bureau
  à 6, personnalisation du local, commerce premium) inscrit un droit durable (`premium_droits.source = 'abonnement'`).
  Élargi le 28/11/2026 au soir à tout ce qui a été utilisé (voir « Décisions de Fred du 28/11/2026 (soir) »).
- **Remboursement de 14 jours** : bouton « Demander le remboursement (jusqu'au …) » tant que les 14 jours suivant le premier
  paiement ne sont pas écoulés **et** qu'aucun avantage n'a été utilisé (option activée, renouvellement d'image inclus, droit
  acquis). Le serveur rembourse le dernier paiement chez Stripe puis arrête l'abonnement.
- **Rappel annuel** : le traitement de nuit (`api/cron-minuit.js` → `envoyerRappelsAnnuels`) envoie un e-mail **au moins
  30 jours** avant le renouvellement d'un annuel (réglage `rappel_annuel_jours`, 35 par défaut, jamais moins de 30), une fois
  par échéance. Stripe envoie en plus ses propres rappels s'ils sont activés (voir plus bas).
- Événements suivis : `customer.subscription.created/updated` (renouvellement, résiliation programmée), `.deleted` (fin).

## Remboursements et débits en double

- Achat à l'unité ou option remboursé dans Stripe (Fred, ou l'assistance Link hors UE) : `charge.refunded` retire le droit.
- Échéance d'abonnement remboursée (débit en erreur) : l'argent revient, l'abonnement continue ; pour l'arrêter, l'annuler
  dans Stripe (l'événement `.deleted` le termine dans le jeu).
- **Doublon automatique** : option payée deux fois pour la même cible, ou second abonnement alors qu'un autre court → le
  serveur rembourse aussitôt le second paiement et prévient le joueur par e-mail.

## E-mails

`api/_paiement-courriels.js`, 9 langues : confirmation d'achat (produit, montant, vendeur, mention 293 B en mode éditeur,
renonciation au droit de rétractation, conditions de l'abonnement), rappel annuel, doublon remboursé. Envoi par l'API de
**Resend** si `RESEND_API_KEY` et `COURRIEL_EXPEDITEUR` existent ; sinon rien n'est envoyé (les e-mails de Stripe restent).

## Managed Payments : ce que dit la documentation (docs.stripe.com, lue le 28/11/2026)

- Activation dans le tableau de bord (Paramètres → Managed Payments), après **examen d'éligibilité** par Stripe. France :
  pays de vendeur pris en charge. Version d'API `2025-03-31.basil` au moins (figée par l'en-tête `Stripe-Version`).
- Paramètre de Checkout : `managed_payments[enabled]=true`. Chaque produit doit porter un **code fiscal éligible** ; « Jeux
  vidéo » fait partie des catégories prises en charge. Codes choisis par défaut (réglables par `STRIPE_TAX_CODE_ABONNEMENT`
  et `STRIPE_TAX_CODE_UNITE`) : `txcd_10201004` (jeu vidéo en ligne, abonnement) et `txcd_10000000` (services fournis par
  voie électronique) pour l'unité et les options.
- Paramètres interdits avec Managed Payments (non envoyés) : `automatic_tax`, `tax_id_collection`, `payment_method_types`,
  `invoice_creation`, adresse de livraison, `customer_update`, libellés de relevé, etc. Tarification adaptative (devise
  locale) toujours active : le montant de la session reste en euros.
- Pays d'acheteurs **non servis** : Chine, Cuba, Iran, Kosovo, Corée du Nord, Russie, Syrie, île de l'Ascension,
  Tristan da Cunha → liste par défaut de `paiement_pays_exclus` (réglable). **Biélorussie** ajoutée par décision de Fred
  (28/11/2026 soir, migration `20261128220000`), comme la Russie.
- Stripe peut rembourser lui-même jusqu'à 60 jours après l'achat (assistance Link) et applique les délais de rétractation
  régionaux ; ses e-mails de renouvellement « d'anniversaire » partent 15 jours avant par défaut (au moins 7).

## À faire par Fred (aucune clé ne doit jamais être écrite dans le dépôt ni dans un message)

Côté **Stripe** (mode test d'abord) :
1. Compte Stripe au nom de l'entreprise de Fred ; adresse e-mail d'assistance à jour (Paramètres → Informations sur l'entreprise).
2. **Webhook** (Workbench → Webhooks → Ajouter une destination) : `https://res-publica.vercel.app/api/paiement/webhook`,
   événements `checkout.session.completed`, `checkout.session.async_payment_succeeded`, `customer.subscription.created`,
   `customer.subscription.updated`, `customer.subscription.deleted`, `charge.refunded` ; noter le secret de signature (`whsec_…`).
3. Clé secrète (ou clé restreinte : Checkout Sessions, Subscriptions, Invoices en lecture, Refunds en écriture).
4. Paramètres → Factures : **pied de page par défaut « TVA non applicable, article 293 B du CGI »** (pour les factures
   d'abonnement en mode éditeur ; celles des achats à l'unité le portent déjà).
5. Paramètres → E-mails clients : activer les reçus de paiement réussi et les factures ; Billing → Abonnements et e-mails :
   activer « Renouvellements à venir » (rappel Stripe en plus du nôtre).
6. **Managed Payments** : demander l'activation (Paramètres → Managed Payments). Une fois accordée, page MJ → « Managed
   Payments activé » → Activer (sinon les acheteurs hors UE ne peuvent pas acheter).
7. Paramètres → Checkout : liens des CGV et de la politique de confidentialité.

Côté **Vercel** (Settings → Environment Variables) :
- `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, puis `PAIEMENT_FOURNISSEUR=stripe`. Tant que ces clés n'existent pas :
  `PAIEMENT_FOURNISSEUR=aucun` (ou absente) : paiement fermé. Une clé réelle (`sk_live_…`) n'est acceptée qu'en production.
- Facultatif : `RESEND_API_KEY` et `COURRIEL_EXPEDITEUR` (e-mails du jeu), `PAIEMENT_URL_SITE`, `STRIPE_TAX_CODE_*`.

Côté **jeu** (page MJ → Premium) : nom de l'éditeur affiché comme vendeur, adresse des CGV (sans elles, aucun achat réel),
prix (dont l'abonnement annuel), puis fin de la gratuité de la bêta.

## Décisions de Fred du 28/11/2026 (soir)

- Prix affichés **toutes taxes comprises partout** (`tax_behavior: 'inclusive'`, déjà le cas).
- Codes fiscaux `txcd_10201004` (abonnement) et `txcd_10000000` (unité, options) **confirmés**.
- Monaco et les DOM traités comme la France (liste `paiement_pays_ue`) ; les territoires hors UE (Saint-Pierre-et-Miquelon,
  Saint-Barthélemy, Nouvelle-Calédonie, Polynésie, Wallis-et-Futuna, TAAF) passent par Managed Payments (déjà le cas).
- Biélorussie exclue comme la Russie.
- Un remboursement d'erreur fait depuis Stripe ne coupe pas l'abonnement (déjà le cas : seul le remboursement des
  14 jours le termine).
- Nom légal du vendeur : réglage serveur `vendeur_editeur_nom`, **vide** tant que Fred ne l'a pas fourni (sans lui, pas
  d'achat en mode éditeur).
- CGV : acceptées par la case existante avant chaque paiement, sans acceptation séparée.
- **Fin d'abonnement : tout ce qui a été utilisé pendant l'abonnement reste acquis** — options attachées à un lieu,
  accessoires personnalisés créés (objets d'inventaire), mini-jeux reçus (règle à appliquer quand ils seront codés),
  commerce premium dès son premier usage (premier dépassement d'un plafond gratuit : droit durable posé par
  `premium_commerce_usage_noter_interne`, marque `commerce_premium_acquis_v1`, migration `20261128210000`). Seuls
  s'arrêtent le renouvellement d'image hebdomadaire, l'absence de publicité et les nouvelles exclusivités.
- Accessoire personnalisé : gratuit pendant la bêta ; un abonné qui a déjà utilisé son renouvellement de la semaine
  l'achète à l'unité (produit `accessoire_personnalise`) ; voir `GAME-DESIGN-FOOTBALL.md`.
