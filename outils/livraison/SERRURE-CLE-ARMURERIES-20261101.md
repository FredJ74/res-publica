# Serrure à clé — armureries / quincailleries (01/11/2026)

## Décision validée

- Produit : `serrure_cle`, **article de quincaillerie** et **non une arme**.
- Fabrication : **2 unités de métal + 1 PA => 2 serrures** (un lot indivisible).
- Prix de vente dans un commerce PNJ : **60 FR / serrure** dans Républia.
- Commercialisation : armureries et armureries-quincailleries de Républia, dont Montrouge ; pas de marché noir, pas de registre de vente d'armes.
- Objet physique destiné à l'inventaire, avec capacité future d'installation sur armoire à souvenirs, appartement ou local loué.
- **La pose et le contrôle d'accès ne sont pas dans cette livraison.** Pas d'effet fictif de fermeture ; aucune mécanique de crochetage pour l'instant.

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

Spécification verrouillée et constat d'architecture seulement ; fabrication, achat et visibilité **non encore implémentés**. Aucune donnée en production modifiée.
