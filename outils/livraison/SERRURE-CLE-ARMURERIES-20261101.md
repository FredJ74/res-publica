# Serrure à clé — armureries / quincailleries (01/11/2026)

## Décision validée

- Produit : `serrure_cle`, **article de quincaillerie** et **non une arme**.
- Fabrication : **2 unités de métal + 1 PA => 2 serrures** (un lot indivisible).
- Prix de vente dans un commerce PNJ : **60 FR / serrure** dans Républia.
- Commercialisation : armureries et armureries-quincailleries de Républia, dont Montrouge ; pas de marché noir, pas de registre de vente d'armes.
- Objet physique destiné à l'inventaire, avec capacité future d'installation sur armoire à souvenirs, appartement, local loué ou suite d'hôtel louée dans la durée.
- **La pose et le contrôle d'accès ne sont pas dans cette livraison.** Pas d'effet fictif de fermeture ; aucune mécanique de crochetage pour l'instant.

## Règles d'installation confirmées (01/11/2026)

- La vente porte sur **un bloc serrure accompagné d'une clé** ; les deux sont associés à une serrure donnée.
- Le PJ clique sur le bloc dans son inventaire : une pop-up dédiée avec **illustration du bloc** présente l'ordre **Installer**.
- La sélection des cibles est calculée sur la **position effective côté serveur** : uniquement les objets et espaces physiquement accessibles là où se trouve le PJ ; jamais d'installation à distance.
- Cibles actuellement éligibles : **armoire à souvenirs**, **appartement** et **local** dont le PJ détient la jouissance, **suite d'hôtel louée dans la durée** si le droit d'usage est confirmé. La propriété ou le bail / droit d'usage doit être vérifié côté serveur avant installation.
- Les **chambres d'hôtel ordinaires** sont **exclues**, même si le PJ occupe temporairement la chambre.
- **Autre** n'est qu'une réserve d'extension de game design (éventuellement un coffre-fort un jour) : **aucune cible « autre » actuellement**, et aucune option vide ou action fictive à afficher dans le sélecteur.
- Si aucune cible éligible n'est accessible, l'installation est indisponible et le bloc reste dans l'inventaire.
- Ne jamais consommer ni poser une serrure avant confirmation transactionnelle serveur ; les interactions redoublées ne doivent pas dupliquer l'installation.
- Le crochetage et les cibles supplémentaires ne sont pas définis pour cette livraison. La duplication des clés est désormais spécifiée ci-dessous.

## Fin du bail, cession et irréversibilité d'usage (décision du 01/11)

- Quand le locataire quitte un appartement ou un local, son droit d'usage de la serrure installée prend fin. Les clés et doubles existants ne peuvent plus lui donner accès à l'ancien emplacement.
- La serrure ainsi désactivée ne peut jamais être réutilisée, réinstallée ni réactivée, y compris après vente du local, changement de propriétaire ou arrivée d'un autre locataire. Toute nouvelle fermeture nécessite une nouvelle serrure.
- Le changement de propriétaire ne doit jamais hériter automatiquement d'un droit d'ouverture sur une serrure désactivée. Le serveur porte un identifiant d'installation et un état irréversible, et vérifie la validité du droit d'occupation lors de chaque tentative d'accès.
- Les clés et doubles de l'ancienne installation ne doivent jamais être rattachés à une nouvelle installation par un changement de propriétaire ou d'occupant.

## Clés vierges et duplication (décision du 01/11)

- Fabrication en armurerie/quincaillerie : **1 unité de métal + 1 PA = 5 clés vierges** (lot de cinq).
- Vente PNJ des clés vierges : **prix cible d'environ 10 FR/unité**, à confirmer comme tarif définitif avant codage tarifaire.
- La clé vierge est un objet d'inventaire non lié à une serrure. L'achat précède toute duplication.
- Depuis l'inventaire, cliquer sur une clé vierge ouvre une **pop-up de duplication dédiée**. Le PJ y choisit la clé/serrure à reproduire parmi celles pour lesquelles il dispose d'une clé valide ; aucune serrure arbitraire ne doit être proposée.
- Une duplication réussie transforme transactionnellement **une clé vierge** en **un double de clé** lié à l'identifiant unique de la serrure. Pas de clonage d'objets ni de double débit en cas de rejeu/double clic.
- Un double ne confère aucun droit supérieur à la clé source. Toute clé d'une serrure désactivée demeure inutilisable pour l'accès, malgré sa présence éventuelle en inventaire.
- Le nombre maximal de doubles, la transmissibilité de clés et un coût éventuel de duplication au-delà de la clé vierge ne sont pas encore spécifiés ; ne pas inventer de restriction ou de frais.

## Contraintes techniques constatées

La vitrine actuelle `ouvrirModalAcheterArme` parcourt `ARMES_CATALOGUE`. Le circuit `arme_acheter` dépose des armes via RPC et enregistre les ventes, et `commerce_produire` applique les recettes du système d'armurerie. **Ne pas ajouter `serrure_cle` dans `ARMES_CATALOGUE`** : cela l'exposerait au marché noir et aux restrictions des armes et dénaturerait son type.

Le socle doit inclure :
1. Référence d'objet non-arme, durable et reconnue par l'inventaire serveur.
2. Recette serveur et production atomique 2 métal/1 PA/2 produits, avec contrôle des droits de l'employé, du stock et du salaire selon le circuit économique existant.
3. Vente serveur transactionnelle à 60 FR/unité pour PNJ, sans débiter deux fois après rejeu, transfert de l'objet dans l'inventaire et crédit de la caisse du commerce.
4. Présentation distincte dans la même liste des produits des armureries ; rupture de stock visible ; ni marché noir ni registre d'armes.
5. Tests d'achat, manque de fonds, inventaire plein, rupture de stock, double clic, production insuffisante et contrôle d'autorité.

**Ne pas livrer une vitrine proposant un bouton qui ne serait pas branché à la RPC serveur.**

## Statut

Règles de fabrication, vente, installation et duplication documentées ; fabrication, achat et visibilité **non encore implémentés**. Aucune donnée en production modifiée.
