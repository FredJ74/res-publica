# #871 — descriptions partagées des fonctions publiques et de police

Lot sur `main` d6d2f08, après les chantiers Sovarka #886 à #892.

Trente descriptions réellement communes sont sorties du catalogue national Républia
et ajoutées au catalogue commun, sans changer aucune des neuf colonnes :
**240 traductions étrangères réutilisées, aucune nouvelle**. Les 394 lignes originales
restent toutes présentes, sans doublon : 253 communes + 141 nationales. Les 205
communes initiales et les 18 lignes du lot #885 sont conservées exactement.

Le périmètre couvre notamment nominations/révocations, organisation des budgets,
affaires judiciaires, police municipale, demandes de naturalisation, manifestations,
calendrier électoral et information publique. Aucune règle n’est modifiée.

Quatre descriptions militaires sont restées nationales après le récent cloisonnement
par empire : mobilisation/réquisition/démobilisation, trêve diplomatique, commandement
de caserne/budget et renfort de garde. Elles ne sont pas partagées par ce lot.
Les dossiers d’escorts de Novomirsk et la ligne du catalogue propre Sovarka sont
également exclus. Aucun fichier métier, bâtiment, PNJ, RPC ou catalogue Sovarka changé.

Les bancs s’appuient sur la fusion réelle des ordres : 250 descriptions communes
actuellement affichées, dont deux restent hors catalogue commun après ce lot.
Le nombre de lignes d’un catalogue n’est pas un taux de traduction du jeu.

Preuves : JSON `-sources.json` avec les 30 lignes initiales, garde d’égalité de
l’union des catalogues, chiffres et unités conservés, traductions Républia identiques,
repli français, isolement des descriptions nationales. Un test qui dépendait de
l’index d’une ligne recherche maintenant son texte français exact ; aucun résultat
attendu n’est changé.

Banc Chromium commun paramétré pour ces 30 lignes : **2 430 descriptions rendues**,
dont **1 620 dialogues tactiles**, neuf langues, trois pays dont un uniquement en
fixture, formats 320/390/1280, arabe RTL, langue modifiée avec dialogue ouvert,
fermetures répétées, ordre bloqué et clic normal. Progression, brouillon, PA, argent,
objets de données et appels métier restent inchangés pendant la consultation.

Relecture native, compte authentifié et téléphone physique non vérifiés. Les champs
libres des joueurs ne sont jamais traduits. Mesures, CI et production : relais et PR.

Résultats locaux : 62 contrôles Node et le banc Chromium verts. Chaque ligne
reclassée est aussi vérifiée dans les deux listes d’ordres effectivement affichées.
