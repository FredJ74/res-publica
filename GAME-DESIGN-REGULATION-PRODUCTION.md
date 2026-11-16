# Régulation de la production — décisions de Fred (16/11/2026, nuit)

Contexte : au champ de pétrole de Starovka, « Récolter » est limité à 2 fois par jour (règle du gabarit
`zone-production`, commune à toutes les villes). Fred veut pousser les joueurs à se déplacer.

## Décisions

1. **Plus de plafond fixe** de récoltes par jour dans les zones de production ; le coût en PA reste le frein.
2. **La limitation devient un pouvoir municipal**, dans **toutes les villes de tous les empires** (socle) :
   c'est une forme de régulation de la production.
3. **Ordre « Régulation de la production »** (adjoint au maire), avec la **liste des productions de la
   ville à réguler**.
4. **L'ordre revient à l'adjoint au maire seul** : chacun son pré carré ; le maire nomme l'adjoint et
   peut le remplacer en cas de désaccord.
5. **Deux limites possibles, cumulables**, réglées par ressource : un maximum de récoltes **par joueur
   et par jour**, et/ou un **plafond total de la ville par jour** (premiers arrivés, premiers servis).
6. **Pas de durée fixe** : une régulation est un acte volontaire, elle reste en vigueur jusqu'à ce que
   l'adjoint la change ou la lève (acte volontaire lui aussi).
7. **Pas d'ordre de sommation** : le ministre de l'Économie peut exiger une régulation, mais cela se
   traite en RP (forums), pas par un bouton ; Fred ne veut pas un bouton par interaction possible.
   Il n'a pas les commandes.
8. **Récolte à 1 PA** (au lieu de 2), quantité récoltée relevée pour que produire vaille la peine
   (PA minimum en Républia : 50 FR). Exemple validé par Fred : **poisson en Républia = 10 par PA**.
   Quantités fixes par PA validées par Fred (16/11) : poisson 10 (PSM), charbon 6 et métal 3 (Montrouge),
   pétrole 4 (Starovka), bois 6 (Krasnov ; forêt profonde doublée : 12).
9. **Prix des matières en Sovarka = moitié des prix de Républia** (règle de Fred, rappelée le 16/11 ;
   pas encore codée : un seul tableau de prix `ressources_economie`, mêmes chiffres en FR et PSK).
   S'applique à **toutes les matières premières** de Sovarka (entrepôts, usines, trading).
   Pétrole de Starovka à 4 PSK, donc **4 unités par PA** (16 PSK pour un PA à 15 PSK).

## À vérifier avant de coder (Claude)

- Sans plafond, la récolte ne doit pas devenir une planche à billets : relever ce qui freine déjà (prix
  de rachat, caisse et stock maximum des entrepôts) et proposer un réglage si nécessaire.

## Questions encore ouvertes

- Moyens de coercition des ministres sur les élus locaux (sujet plus large, à traiter plus tard).

## Idée notée au passage

- **Créer une ferme en Républia** (Fred, 16/11/2026) : chantier à part, à décider plus tard.

## Codé le 16/11/2026 (feu vert de Fred, nuit)

- Migration `20261116020000_regulation_production_recolte` (appliquée) : `recolte_effectuer` (1 PA, quantité
  fixe par `recolte_quantite_par_pa`, plus de limite de 2/jour), forêt profonde (1 PA, 12 bois), tables
  `production_regulations` / `production_recoltes_jour`, RPC `regulation_production_lire` / `_fixer`
  (adjoint attesté, dans la mairie de sa ville, 1 PA ; deux champs vides = levée ; 0 = interdiction).
- Prix : `coef_prix_matieres` (Sovarka 0,5) et `ressources_economie_pays(pays)` raccordés aux entrepôts,
  usines (rachat et vente directe), trading (cours, achats, fournisseurs étrangers), commandes des
  directeurs, commerces et fonds, chantiers, passes et exportations de Sovarka. Importations de Sovarka :
  payées au prix du pays d'origine (pas de taux de change).
- Écran : `plateau-regulation-production.js`, catalogue `i18n/regulation-production-resources.js`.

## Décisions de Fred du 16/11/2026 (matin)

- **Lieu de pêche de PSM = le Port de Plaisance** (bâtiment déjà existant) : les PJ pêchent depuis le port
  de plaisance (10 poissons par PA, sans plafond fixe, régulable par l'adjoint). Le poisson débarqué
  automatiquement chaque jour arrive, lui, par le **Port Industriel** (RP ; approvisionnement de nuit inchangé).
- **Commandant du Port de Sovarka** (port industriel de Starovka), comme en Républia. Il **fléchit les
  importations reçues vers les entrepôts** et **les exportations vers les ports industriels des autres
  pays**. Un **réglage par défaut** existe, que le commandant peut modifier.
- **Nouvel indicateur envisagé : la balance commerciale** du pays. Son responsable pourrait caler des
  **quotas d'importation et d'exportation** pour la rééquilibrer si le pays perd trop d'argent.
  **Décidé : la balance commerciale et les quotas reviennent au Commandant du Port** (pas au ministre de
  l'Économie), pour que chaque joueur nommé à un poste se sente utile.
  **Socle commun, tous les empires** (« un basique de gestion ») : le Commandant du Port de Républia
  reçoit les mêmes leviers.
- **Un produit, un prix intérieur** : un entrepôt n'a qu'un stock et un prix par ressource ; pas de double
  prix entre produit local et produit importé (option « exception pour les importés » écartée par Fred :
  la production de Sovarka sera insuffisante, l'importation comble le manque).
- **La caisse du port industriel paie la différence** entre le prix d'achat à l'étranger et le prix de
  cession aux entrepôts. Elle doit **rester positive pour continuer à importer** : c'est le rôle de la
  balance commerciale, ne pas créer de déficit.
- Si elle se creuse, le Commandant du Port peut :
  1. **demander une dotation récurrente au ministre de l'Économie**, qui détient le Trésor ;
  2. en cas de refus, **revoir les prix de ce qu'il expédie** vers les entrepôts du pays et/ou vers les
     ports industriels étrangers (le commandant fixe donc ces prix de cession) ;
  3. jouer sur les quotas d'importation et d'exportation.
- **Les droits de douane servent aussi à équilibrer** : **droits de douane ET amendes pour fausse
  déclaration sont versés à la caisse du port industriel** (les amendes ne vont plus au Trésor).
- **Le taux des droits de douane (10 % aujourd'hui) est fixé par le Commandant du Port.** Il est sous les
  ordres du ministre de l'Économie, qui peut lui imposer de l'ajuster : **RP seulement, pas de code**.
  Fourchette réglementaire proposée par Claude : 0 à 30 % (non contestée par Fred).
- **Dotation du ministre de l'Économie à la caisse du port : les deux formes**, ponctuelle et récurrente
  (le socle sait déjà faire les deux : virements simples et automatiques de la Banque Nationale,
  virement journalier du ministre de la Défense vers la caserne, `caserne_virement_journalier_fixer`).
  Le Commandant du Port de Sovarka est nommé par le ministre de l'Économie (« sous ses ordres ») ;
  en Républia par le ministre des Finances, comme aujourd'hui.
- **Balance commerciale publique**, visible de tous ; reprise dans le **journal du jour** avec les prix des
  matières premières.
- **Vente à perte assumée** (Fred) : un produit acheté 8 FR en Républia par le port de Sovarka peut être
  cédé aux entrepôts de Sovarka au prix intérieur (4 PSK) ; la perte reste dans la caisse du port et c'est
  la balance commerciale qui l'équilibre (douanes, amendes, marges à l'exportation, dotations, quotas).

- **Commandants du Port d'El Estado et d'Al-Khalija** (Fred, 16/11, midi) : codés pour que le commerce
  international parte aussi de ces pays. Empires non jouables : commandant PNJ au réglage par défaut, port
  avec une vraie caisse, l'État couvre le déficit tant que l'empire n'est pas ouvert (lecture de Claude).
- **Importations de Républia payantes**, comme partout (Fred, 16/11) ; **caisse de départ de 20 000** pour
  chaque port. « On va commencer à donner du corps et une réalité au modèle économique. »

## Codé le 16/11/2026 (feu vert de Fred, midi)

Migration `20261116113000_ports_commerce_international` (appliquée ; registre
`ports_commerce_international_20261116113000`), écran `plateau-port-commerce.js`, catalogue
`i18n/port-commerce-resources.js`, tâche de nuit `commerce_international` (`api/cron-minuit.js`).

- **Tables** : `ports_commerce` (un port par pays : caisse, entrepôts, réglages du commandant, dotation
  quotidienne), `ports_stock`, `commerce_contrats` (volumes d'avant ce lot, repris tels quels, à relire par
  Fred), `ports_productions` (Scierie Guy Tarembois, 150 bois), `ports_journal`, `ports_balance_jours`.
- **Prix par défaut** (choix de Claude) : exportation au **cours international** (prix de base de la table
  des ressources, celui de Républia ; Sovarka vendait déjà ses exportations à ce prix) ; cession aux
  entrepôts au **prix intérieur** du pays. Le port achète aux entrepôts au prix intérieur ce qu'il exporte.
  Bornes des prix fixés : 10 % à 500 % de la référence.
- **Passe de nuit** (`commerce_international_passe`) : dotations quotidiennes du ministre (plafonnées à la
  caisse du ministère) ; production intérieure ; contrats (lois, quotas, stock des entrepôts, caisse du port
  qui achète ; vente à perte possible) ; cession du stock des ports aux entrepôts selon le fléchage (place
  et caisse de chaque entrepôt ; le reste attend au port) ; balance du jour.
- **Pétrole et produits exotiques** n'arrivent plus en Républia que par les contrats (Al-Khalija 133 pétroles,
  Sovarka 200, El Estado 125 produits exotiques) ; la part que le tirage des entrepôts réservait à la
  raffinerie de Montrouge est conservée. Le bois de Sovarka (150) devient un contrat prélevé sur les
  entrepôts de Sovarka.
- **Commandant du Port** : `port_commandant_regler`, dans son bureau, 0 PA (comme l'ancien ordre) ;
  `fixer_repartition_port` passe par la même porte. Retour d'un PNJ : réglages par défaut.
- **Ministre de l'Économie** : « Dotation au port » dans « Gestion industrielle et portuaire » ; virement
  ponctuel (1 PA) ou dotation quotidienne.
- **Douane** : taux du port dans `fret_dedouaner` et dans l'amende d'inspection (`fret_inspecter_interne`) ;
  droits, amendes et produit des caisses saisies pour amende à la caisse du port.
- **Pêche** : ordre « Pêcher » au Port de Plaisance de PSM ; le serveur refuse le poisson ailleurs à PSM.
- **Journal du jour** : bloc « Balance commerciale » en dernière page, après les indices de prix.
- Premier essai annulé (nuit simulée) : Républia −2 652 FR, Sovarka +4 182 PSK, El Estado +547,
  Al-Khalija −2 077 ; les entrepôts de Républia, pleins, ne prennent encore rien au port.

## Points relevés pour Fred

- ~~Lieu de pêche de PSM~~ : réglé (Port de Plaisance). ~~Importations de Sovarka à perte~~ : réglé (caisse
  du port, balance commerciale).
- **Volumes des contrats** repris de l'existant, à relire par Fred (table `commerce_contrats`, corrigeable
  sans code). Le déficit quotidien de Républia (environ 2 650 FR) épuisera la caisse de départ en une
  semaine sans dotation, prix ou quotas : c'est le jeu voulu, à surveiller.
