# Krasnov — audit des portraits de PNJ (17 novembre 2026)

**Source de vérité :** `data.js` et `api/_pnj-scenes-generes.js` sur `main` ; registre `outils/images/portraits-pnj-starovka-krasnov-20261116.json` ; contrôle d'existence des 19 fichiers ci-dessous par lecture GitHub.

**Inventaire : 39 PNJ distincts ; 19 portraits déjà affectés et fichiers présents ; 20 PNJ sans photo affectée.** Ce chiffre ne signifie pas que 20 visages doivent être générés : recherche du portrait antérieur d'Ignat et possibilité de recadrage (réceptionniste, caporal) à approfondir. Les silhouettes anonymes ne sont pas des portraits attribuables.

## Déjà pourvus — ne pas régénérer

| PNJ | Lieu | Fichier WebP vérifié |
|---|---|---|
| Galina Dokladova | mairie / accueil | `images/Sovarka/Krasnov/Krasnov_portrait_mairie_galina-dokladova.webp` |
| Zinaïda Izbirkova | mairie / salle des élections | `images/Sovarka/Krasnov/Krasnov_portrait_mairie_zinaida-izbirkova.webp` |
| Infirmière | dispensaire / attente | `images/Sovarka/Krasnov/Krasnov_portrait_dispensaire-public-v_infirmiere.webp` |
| Brigadier Local | commissariat / accueil | `images/Sovarka/Krasnov/Krasnov_portrait_commissariat-local_brigadier-local.webp` |
| Hôtesse du centre d'affaires de Krasnov | centre d'affaires / hall | `images/Sovarka/Krasnov/Krasnov_centre_affaires_hotesse_20261115.webp` |
| Vsevolod Fedotov | stade / vestiaires | `images/Sovarka/Krasnov/Krasnov_stade_entraineur_portrait.webp` |
| Semione Klimov | stade / terrain | `images/Sovarka/Krasnov/Krasnov_stade_commentateur_portrait.webp` |
| Avdotia Doubova | stade / buvette | `images/Sovarka/Krasnov/Krasnov_portrait_stade_avdotia-doubova.webp` |
| Iossif Borissov | stade / bookmaker | `images/Sovarka/Krasnov/Krasnov_portrait_stade_iossif-borissov.webp` |
| Oxana Zvezdina | stade / boutique | `images/Sovarka/Krasnov/Krasnov_portrait_stade_oxana-zvezdina.webp` |
| Leonid Zapravkine | station-service / boutique | `images/Sovarka/Krasnov/Krasnov_portrait_station-service-krasnov_leonid-zapravkine.webp` |
| Nina Gorbounova | marché / étals | `images/Sovarka/Krasnov/Krasnov_portrait_marche_nina-gorbounova.webp` |
| Alevtina Gramotova | université / amphithéâtre | `images/Sovarka/Krasnov/Krasnov_portrait_universite_alevtina-gramotova.webp` |
| Kouzma Lapchine | maison du prêtre | `images/Sovarka/Krasnov/Kouzma.webp` |
| Hôtesse du musée de Krasnov | musée / hall | `images/Sovarka/Krasnov/Krasnov_musee_accueil_hotesse.webp` |
| Guide du musée de Krasnov | musée / hall | `images/Sovarka/Krasnov/Krasnov_musee_accueil_guide.webp` |
| Grigori Zaitsev | café-tabac / salle | `images/Sovarka/Krasnov/Krasnov_portrait_cafe-tabac-cheminots-montrouge_grigori-zaitsev.webp` |
| Colonel Gleb Voronov | centre d'écoute / salle | `images/Sovarka/Krasnov/Krasnov_portrait_station-radar-krasnov_colonel-gleb-voronov.webp` |
| Praskovia Pakhomova | maison bleue | `images/Sovarka/Krasnov/Praskovia.webp` |

## Sans photo affectée — contrôle avant création

| PNJ | Lieu | Action correcte |
|---|---|---|
| Réceptionniste | hôtel / hall | RECARDAGE POSSIBLE : femme derrière le comptoir ; décor actuellement hérité de Montrouge, contrôler cohérence avant adoption |
| Le Maire | mairie / bureau du maire | À CRÉER si poste PNJ, ne pas attribuer à un PJ élu |
| Lieutenant Fiodor Doznaïev | mairie / salle des partis | À CRÉER : salle vide |
| Egor Tikhonov | commissariat / bureau du commissaire | À CRÉER : bureau vide |
| Anatoli Gromov | tribunal / salle d'audience | À CRÉER : photographie du tribunal non identifiée comme portrait |
| Directeur Platon Iermakov | usine / direction | À CRÉER sous réserve du modèle de ville |
| Varvara Kozlova | centre commercial / hall | À CRÉER : silhouettes du hall non attribuables à ce PNJ |
| Efim Iakovlev | centre commercial / hall | À CRÉER : silhouettes du hall non attribuables à ce PNJ |
| Stas Mironov | centre artisanal / accueil | À CRÉER : atelier vide |
| Valentina Makhorkina | tabac-presse / boutique | À CRÉER : comptoir vide |
| Stiopa « le Tambour » Ossipov | stade / club des supporters | À CRÉER : local vide |
| Fiodor Kolkhozov | entrepôt / bureau | À CRÉER : bureau vide |
| Caporal Ilia Sorokine | station radar / salle d'écoute | RECARDAGE POSSIBLE : opérateur casque vu de dos, visage peu exploitable ; recadrage à expertiser avant création |
| Stepan Kouznetsov | maison de Stepan | À CRÉER : décor vide |
| Antonina Merkoulova | maison d'Antonina | À CRÉER : décor sans occupant identifié |
| Matveï Rybakov | maison rouge | À CRÉER : décor vide |
| Ignat Lykov | maison d'Ignat | À VÉRIFIER : aucune photo affectée dans data.js ; portrait éventuellement livré sous un autre nom à retrouver avant de générer |
| Galina Belova | ferme / cour | À CRÉER si aucun visage identifiable dans la cour |
| Anatoli Pokhmelkine | distillerie / direction | À CRÉER : bureau vide |
| Vassili Gradousov | distillerie / atelier | À CRÉER : atelier vide |

## Consignes de production

- Ne jamais inventer de nom : les deux anciennes planches avec « Pavel », « Irina », « Sergueï Volkov », etc., sont **REJETÉES**.
- Respecter les visages existants de Nina, Kouzma, Praskovia, des PNJ du stade et de tous les 19 personnages ci-dessus.
- Vérifier la présence du personnage **dans sa scène actuelle** avant de demander un nouveau portrait.
- Différencier réellement les traits : âges, coupes, barbes, silhouettes, costumes, attitudes et environnements. Ne pas uniformiser les visages par l'origine géographique.
- Krasnov = **automne** ; aucune faucille et marteau.
- Garder une table d'attribution basée sur les noms exacts avant toute découpe ou intégration.
- Le bookmaker **Iossif Borissov** a déjà sa photo : aucun remplacement.

**Ce document est un audit, pas une livraison d'images ni une autorisation de substituer les portraits existants.**
