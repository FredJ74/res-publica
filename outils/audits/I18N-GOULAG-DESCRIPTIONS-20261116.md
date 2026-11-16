# Goulag : descriptions des cinq pièces — 16 novembre 2026

Base `ee93360`. L'échec du banc global Sovarka est reproduit sur main : exactement cinq descriptions françaises affichées manquent au catalogue. Les textes existent déjà dans `data.js`, livrés avec les cinq vues ; aucune rédaction française supplémentaire ni changement de décor/règle n'est nécessaire. Ils sont conservés octet pour octet et leurs 40 traductions étrangères sont ajoutées à la matrice existante de neuf langues.

Pièces : `soviet/qhs/qhs-prison/entree_qhs`, `cellules_qhs`, `cachot_disciplinaire`, `bureau_chef`, `mirador`. Les deux premiers textes viennent des surcharges, les trois suivants des pièces supplémentaires. Le raccordement d'affichage existant les sélectionne avant les suffixes dynamiques ; le rafraîchissement passif existant conserve la source française. Aucun nouvel appel serveur, moteur ou attribut n'est ajouté.

Trois tests ciblés verts : anciennes lignes conservées, cinq ajouts / neuf colonnes, français identique aux pièces réelles, repli français et isolement Républia ; périmètre figé au commit de code, aucune donnée/API/migration/navigation/style modifiée. Chromium exécute le fragment réel de rendu de `enterRoom` avec les vrais contextes et listes de pièces, puis le vrai rafraîchissement : 270 bascules sur cinq pièces de Sovarka et cinq du QHS de Républia, neuf langues, 320/390/1280 px, arabe RTL, progression/PA/argent/inventaire/position/saisie/focus/défilement conservés sans requête métier. Il ne s'agit pas d'une navigation authentifiée.

Le banc global `test-i18n-sovarka-descriptions-20261112.mjs` passe maintenant ses cinq tests sans aucune modification de ses exigences. Brotli et manifeste régénérés, 86 catalogues conformes. PR #1020 de survie de la toundra et chantier d'image du port #1029 exclus. Les PR #1018/#1021 ne sont pas refaites.

CI générale, fusion et production à vérifier. Non vérifiés : PJ connecté, téléphone physique et relecture linguistique native. Suite obligatoire : audit des noms/catégories/libellés et fenêtres commerciales, puis lot distinct hors des chantiers actifs.
