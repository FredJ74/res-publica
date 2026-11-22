# Santé et forêt — décisions de Fred (22/11/2026, après-midi)

Texte de la mission, consigné tel quel. Le serveur décide de tout ; aucun gain ni aucune perte ne se calcule dans le
navigateur. Toutes les valeurs chiffrées vont dans une table de paramètres réglable par un MJ depuis l'administration.

## PARTIE 1 — SANTÉ (colonne hp, affichée « Santé »)

1. Robustesse. Toute perte de PA infligée par un adversaire en combat (faune, police, PJ contre PJ, bataille) est multipliée par un facteur qui dépend de la Santé de la victime au moment du coup : 1,3 à Santé 0, 1,0 à Santé 50, 0,8 à Santé 100, linéaire entre ces points. Arrondi à l'entier le plus proche ; un coup qui touche retire toujours au moins 1 PA.

2. La Santé à 0 ne bloque plus rien. Retire tous les contrôles « hp <= 0 » qui empêchent d'agir : navigation_disponibilite_interne, groupe_combattants_interne, police_combat_personnage_interne, combat_rapport_lignes_interne (état « coma »), sovarka_reunion_evenement, et tout autre que tu trouves (liste-les dans le rapport). Le coma n'a plus qu'une définition : PA à 0, qui déclenche l'hospitalisation existante (hospitalisation_pa_epuises_declencheur, inchangé).

3. Blessures. Chaque PA perdu en combat, après multiplication, retire aussi 1 point de Santé (plancher 0).

4. Maladies. Une maladie retire de la Santé au moment où elle est contractée : intoxication −10, grippe −10, coup de chaleur −5, gueule de bois −3, MST −10. Ajoute ce champ dans maladies_parametres.

5. MST, nouvelle maladie du catalogue. Symptôme visible par les autres, sans le nom de la maladie : « démangeaisons très gênantes ». Effet : −2 CHA. Elle ne guérit jamais seule : elle dure jusqu'à la prise d'un antibiotique (nouveau médicament), qui guérit au prochain Dormir comme les autres médicaments. Non contagieuse. Risque : à chaque « faire l'amour » avec une escort, compte le nombre d'escorts DIFFÉRENTES vues sur les 10 derniers jours glissants, celle-ci comprise ; si ce nombre n vaut 2 ou plus, risque = 15 % × (n − 1). Revoir la même escort n'augmente pas le risque. Le tirage a lieu à l'acte ; la maladie et la perte de Santé sont révélées au réveil suivant, dans le journal d'événements (jamais par courrier), avec ce texte exact : « Ces 10 derniers jours, vous avez eu des relations avec X partenaires. L'un d'eux ou l'une d'elles vous a transmis une MST. −10 points de Santé. »

6. Escort. escort_intimite ne donne plus aucune Santé ; le Moral reste inchangé.

7. Alcool. Par personnage et par jour (heure de Paris), avec le même compteur de verres que la gueule de bois : 1er verre alcoolisé +1 Santé, 2e 0, 3e et chacun des suivants −2. Vaut pour toutes les boissons alcoolisées, où qu'elles soient bues (bar, restaurant, minibar, verre offert, tournée, « boire un verre » avec un PNJ). Les boissons sans alcool ne donnent pas de Santé. Supprime le +5 de tournee_cloturer_boire et le +5 de boire_verre.

8. Sommeil, calculé par le SERVEUR au Dormir (supprime le +12 et le +10 de régénération calculés aujourd'hui par le navigateur dans plateau-personnage.js) : +5 dans une chambre chez soi ou à l'hôtel, +3 dans un bâtiment hors chambre, +2 dehors (rue, vues en plein air), +5 à l'hôpital public ou au dispensaire, +7 à la clinique privée (clinique_nuitee_consommer passe de +10 à +7).

9. Repas. Barème Santé / PA différés, Moral inchangé : menus gastronomiques +5 / +3 ; plats du jour +4 / +2 ; sandwich et tartine de salo +3 / +1 ; petits-déjeuners +2 / +1 ; snacks (pirojki, cacahuètes, amuse-bouche, zakouski) +1 / 0 ; boissons 0. Produits alimentaires créés par un joueur : palier 5 à 9,99 → +3 / +1, palier 10 à 14,99 → +4 / +2. Produits du marché de Krasnov qu'on mange (pain noir, goulash, fruits et légumes) : range chacun dans la catégorie la plus proche et indique ton choix dans le rapport. Les ordres « Repas gastronomique », « Se nourrir » et « Service d'étage », ainsi que le dîner d'affaires avec un PNJ, appliquent l'effet du plat réellement servi, plus aucune valeur codée en dur ; à défaut de plat identifié : Se nourrir = sandwich, Service d'étage = plat du jour, Dîner d'affaires = menu.

10. Soins : soin public au dispensaire +8 Santé et +1 PA (toujours une fois par jour) ; soin à la clinique privée +15 et +2 PA ; soins accélérés (urgence) +25 ; soins sans trace +15.

11. Moral. Il module tous les GAINS de Santé (repas, sommeil, soins, médecin, alcool) : Moral 75 et plus ×1,5 ; de 25 à 74 ×1 ; moins de 25 ×0,5 ; arrondi à l'entier. Les pertes ne dépendent jamais du Moral.

12. Médecin de terrain. Réservé aux personnages de carrière « doctor » (Médecin / Universitaire), sur un autre personnage présent au même endroit, partout (bâtiments, rues, forêt) :
   - « Diagnostiquer » (1 PA pour le médecin) : le médecin voit la Santé exacte du patient, ses maladies en cours par leur nom et le médicament qui soigne chacune ; le patient reçoit le même diagnostic dans son journal. Personne d'autre ne voit le nom des maladies.
   - « Soigner » (2 PA pour le médecin, consomme une trousse de premiers secours de son inventaire) : +12 Santé pour le patient, modulé par le Moral du patient.
   - Tarif libre fixé par le médecin à chaque acte ; le patient voit le prix dans une fenêtre et accepte ou refuse ; aucun prélèvement sans son accord.

13. Médicaments. Une seule usine pharmaceutique par pays, un seul ordre « Produire des médicaments », où le producteur choisit le médicament à fabriquer, avec les mêmes matières et la même règle de prix pour tous : antinauséeux, aspirine, antigrippal, sels de réhydratation, antibiotique. Commence par inventorier dans le rapport comment ces médicaments sont produits et vendus aujourd'hui (maladies_parametres, stock_journalier, ressource générique « Médicaments », pharmacies, comptoir de l'usine), puis branche-les sur cet ordre en gardant les points de vente existants. Pour l'antidote et le traitement anti-poison actuel : inventaire seulement, ne change rien, propose dans le rapport.

14. Jauges visibles. Dans le panneau « Mon personnage », deux jauges Santé et Moral à côté des PA. Au survol ou au toucher, une infobulle claire, par exemple pour la Santé : « Santé 40 : vous perdez un peu plus de PA sous les coups. Mangez, dormez dans un lit ou consultez un médecin. » Texte jamais plus petit que le texte courant.

15. Suppressions : la régénération (regen_jour) et les caractéristiques affaiblies (stats_affaiblies) n'ont plus aucun effet. Partout dans le journal et les messages, « PV » devient « Santé ».

16. Aucune Santé actuelle de personnage n'est modifiée par la migration.

## PARTIE 2 — FORÊT ET VUES EN PLEIN AIR

17. Dans toutes les vues en plein air (PIECES_PLEIN_AIR et fiches pleinAir) : retire « Inspecter la pièce » et « Désinstaller du matériel ». En forêt, il ne reste que « Couper du bois », « Retour au campement » et « Se cacher ».

18. Nouveaux titres et textes des vues de la forêt de Krasnov (data.js, objet vues) :
   - vue 1 : « La piste des débardeurs » — « Des souches fraîches, des grumes empilées au bord d'une piste défoncée. Les bûcherons ne sont pas loin. »
   - vue 2 : « La coupe abandonnée » — « Des souches partout, une odeur de résine. Quelque chose a gratté l'écorce d'un bouleau, bien haut. »
   - vue 3 : « Les grands fûts » — « La forêt se referme. Les fougères montent aux genoux, et des empreintes larges comme une assiette marquent l'humus. »
   - vue 4 : « Le sentier d'Olga » — « Un sentier à peine tracé sous les feuilles mortes. Au loin, une odeur de feu de bois et de soupe aux choux. »

19. Meute : chaque loup garde sa fuite individuelle, mais quand deux loups sont tombés, le dernier s'enfuit toujours. Le butin de chaque loup tué est toujours remis au chef, même si un loup s'enfuit. Corrige le défaut signalé : un loup en fuite affiche l'état « En fuite » dans la dernière ligne du rapport.

## PARTIE 3 — AUTRES DÉCISIONS

20. Fontaines : les six points d'eau (Luthécia hôtel de ville, Montrouge place du Rail, Port-Sainte-Marie place d'Armes, Novomirsk place du Peuple, Starovka mairie, Krasnov place de l'Ours) donnent une eau potable, sans aucun risque de maladie. Emplacements validés.

21. Logement : surface minimale de 2 000 m² confirmée.

22. « Montrer un objet » : nouvelle action entre deux personnages présents au même endroit (membres d'un groupe compris) : l'autre voit le nom, l'image et la description de l'objet dans une fenêtre ; rien ne change de main ; une ligne dans le journal des deux. « Échanger » n'est pas créé.

## PARTIE 4 — VÉRIFICATIONS

23. Terrains de Sovarka : terrains_referentiel en déclare 7 (Novomirsk, Starovka, Krasnov), mais terrains_etat n'a aucune ligne pour soviet. Vérifie si un joueur peut aujourd'hui acheter et construire sur un terrain de Sovarka. Si c'est bloqué, corrige-le par le même mécanisme qu'en République ; sinon, explique pourquoi l'absence de ligne est normale.

24. Le sas des dons : la migration inventaire_direct_capacite refuse déjà un don qui dépasse la capacité du destinataire, sas compris. Explique ce que tu entendais par « si le sas des dons doit avoir une limite » ; ne change rien.

## PARTIE 5 — QUESTIONS À EXPOSER, SANS RIEN CODER

25. Pour chacune des quatre questions ouvertes — le nom « Metel » à Starovka, les prix du marché de Krasnov, la façon de comprendre le rôle du commissaire, obj_informateur — écrire dans le rapport : le contexte en deux ou trois phrases simples, ce qui est codé aujourd'hui, les options possibles et une recommandation.

## POUR FINIR

26. Mise en ligne, puis RELAIS.md et AGENTS.md à jour, avec les nouvelles clés de traduction listées pour Codex.

27. Tests de bout en bout sur la vraie base, dans une transaction annulée, avec une vérification après coup qu'il ne reste rien : un combat contre la meute à Santé 100 puis à Santé 10 (PA et Santé perdus, fuite du dernier loup, état « En fuite », butin) ; un verre, deux, puis trois verres dans la journée ; Dormir dans une chambre, dans un bâtiment et dehors ; un menu avec un Moral de 80 puis de 20 ; diagnostic et soin par un médecin avec trousse et accord sur le prix ; MST tirée au troisième partenaire et révélée au réveil ; « Montrer » un objet.

28. Rapport final unique, point par point dans l'ordre de cette mission : fait / partiel / non fait, avec la raison pour chaque point non terminé.

## Règles de travail de la mission

- Migrations écrites à partir des définitions de PRODUCTION (pg_get_functiondef), éprouvées sur PGlite, annoncées à Fred
  juste avant leur lancement (validation à l'écran). Une validation expirée : ne rien relancer, une ligne « migration X en
  attente », arrêt.
- Rien du goulag (sovarka_goulag_*, configuration active=false conservée).

## Suites — décisions de Fred (22/11/2026, soir), réponses au rapport « Santé et forêt »

1. Fruits et légumes du marché de Krasnov : catégorie en-cas (+1 Santé, 0 PA), comme tu l'as fait. Le mot « snack » ne doit jamais être lu par un joueur : la catégorie s'affiche « En-cas » en Républia et « Zakouski » en Sovarka.
2. Plats créés par un joueur : nouveau palier 15 et plus = +5 Santé / +3 PA (comme un menu).
3. Repas du président : +5 Santé / +3 PA. Repas de l'hôpital public : +4 Santé / +2 PA, gratuit, toujours réservé aux patients hospitalisés (contrôle existant conservé). Repas de la clinique : +5 Santé, ses +4 PA, 30 FR.
4. Défaite contre la meute : le chef reçoit bien le butin des loups tués avant la déroute. Inchangé.
5. Médecin payé en liquide. Règle générale du jeu : tous les paiements se font en liquide ; la banque est un dépôt volontaire du joueur.
6. « Montrer un objet » reste à 0 PA.
7. Robustesse (et 1 Santé par PA perdu) appliquée aussi à « se laisser faire » face à une bête, à la répression et à la rébellion. Pas à la neutralisation criminelle ni au poison.
8. Médicaments :
   a. La ressource générique « Médicaments » devient la matière première des trousses de premiers secours (recette dans la règle commune).
   b. La dotation de 20 boîtes par jour et par médicament devient une production des PNJ de l'usine qui consomme de la matière première comme celle des joueurs : sans matière première, pas de boîtes. Les boîtes des joueurs restent vendues en premier.
   c. L'argent des ventes va à la caisse de l'usine. Ajoute aux usines d'État le mécanisme des entrepôts municipaux : fonds de roulement de 5 000 (dans la monnaie du pays, réglable par le MJ), excédent reversé chaque nuit à la caisse du ministère de tutelle, et un bouton de virement volontaire pour le directeur.
   d. Ajoute l'antidote, sixième médicament : produit à l'usine avec de la matière première, vendu en pharmacie, nettement plus cher que les autres par une recette plus riche dans la règle commune, il annule l'empoisonnement au réveil suivant. Le centre antipoison de l'hôpital consomme des antidotes de son propre stock, achetés comme les autres ; sans stock, il ne soigne plus jusqu'au réapprovisionnement.
9. Dons de tracts soumis au même plafond que les autres dons. Rien n'échappe à la règle commune. Le sas reste sans limite pour le reste.
10. L'antenne de Starovka signe « La Voix de Sovarka » ; « Metel » reste le nom de la boutique.
11. Prix : le kolkhoze vend la confiture 10 PSK. Règle de rachat de TOUS les marchés : 30 % sous le prix de vente, arrondi à l'unité, au moins 1 d'écart ; aligne tous les produits de tous les marchés et liste les prix changés dans le rapport. Caisse du marché de Krasnov : 1 000 PSK. Chemise de bûcheron : le prix que donne la règle commune.
12. Commissaire et informateurs : inchangé.
13. Objectif obj_informateur remplacé par « Acheter 5 informations à des informateurs différents ».
14. Inchangés : « (en fuite) » en minuscules, gilet qui laisse au moins 1 PA, patient reconduit en cellule compté « bâtiment ».
