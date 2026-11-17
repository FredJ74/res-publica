# Krasnov — 19 photos de profil (17 novembre 2026)

## Résultat vérifié sur la PR #1103

**Le fichier `Krasnov_19_portraits_WebP.zip` a été retrouvé sur `main`, puis validé par son empreinte SHA256 :**
`984355c8d8981254eee3af259a28f88113d429a3c407ea59d7aa738d25d3e9c3`.

Le workflow ciblé `Krasnov : 19 portraits WebP et raccordement` a exécuté avec succès, dans cet ordre :
- récupération de l'archive depuis la branche principale ;
- vérification stricte des 19 noms dans le ZIP et du SHA256 ;
- extraction et validation de **19 images WebP carrées 512 × 512** ;
- raccordement des 19 PNJ par **nom exact et pièce**, dans `WORLD.soviet.ville_b` seulement ;
- vérification syntaxique de `data.js` et chargement du jeu via les bancs `test-krasnov-accueil-sans-vide-20261115.mjs` et `test-starovka-rue-petrole-ferme-20261106.mjs` ;
- suppression de la source ZIP et des deux anciennes planches PNG, seulement après succès ;
- publication du résultat dans la branche de la PR.

Le correctif préserve les portraits existants d'Ignat, Nina, Kouzma, Praskovia, les PNJ du stade et tous les autres PNJ qui disposaient déjà de photo.

Deux PNJ non récupérables par recadrage d'un décor ont été couverts : `Receptionniste (PNJ)` de l'hôtel des mineurs et `Caporal Ilia Sorokine (PNJ)`.

### Limites

Une CI ciblée réussie ne remplace pas une recette en jeu authentifiée sur téléphone. L'état des autres workflows généraux de la PR et le déploiement Vercel doivent être confirmés séparément.
