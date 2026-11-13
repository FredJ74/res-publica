# #871 — confirmations de suppression du forum

Deux titres fixes encore français : « Sujet supprimé » et « Message supprimé ».
Deux clés ajoutées au catalogue `forumFeedback`, 16 traductions étrangères.
Aucune ressource existante ne contenait ces deux libellés exacts. Le corps vide
reste vide. Le moteur commun et son support de titre seul (#902) sont réutilisés.

Les deux appels de suppression et leurs suites restent intégralement identiques :
preuve AST après retrait des seules annotations de présentation. Aucun texte joueur,
RPC, droit d’accès, prix, PA, progression ou inventaire changé. Aucune traduction
automatique des contenus du forum ou des courriers.

Chromium appelle la vraie fonction `executerSuppressionPost` sur deux scénarios
simulés (premier message et réponse), puis change neuf fois de langue à trois
largeurs (320/390/1280), soit 54 bascules. Aucun appel supplémentaire, ni mutation
du sujet restant, du brouillon, du focus, des PA, de l’argent, de la progression,
des incidents ou de la minuterie. Corps vide, arabe RTL et absence de débordement
vérifiés. Le banc des 31 messages existants est rejoué (837 rendus).

La preuve historique des 44 annotations de #877 reste figée ; le code courant
vérifie leur maintien par clé et multiplicité au lieu d’interdire toute extension.
Français exact et neuf langues sont vérifiés sur les 45 clés actuelles du catalogue.

Relecture native, session PJ authentifiée et téléphone physique non réalisés.
Même extracteur avant/après le lot précédent (fusion `69a1c03`, forum identique au code mesuré `3a8a954`) : corpus inchangé, 7 565 textes / 50 690 mots. +2 textes / +4 mots source raccordés par langue étrangère, +2 ressources / +4 mots. Anglais : 994 textes / 12 061 mots raccordés, 23,79 % des mots identifiés (taux arrondi). 31 tests Node finaux et deux bancs Chromium verts. Contrôles distants et vérification publique à compléter avant livraison.

Correction de la preuve après rebasage : commit de code joignable dans la branche publiée et base de fusion #902, au lieu du premier commit local remplacé. Aucun code de jeu changé.

## Livraison vérifiée

PR #904 fusionnée : `196af01ddc4bf65dd0421f5754ea34856eb4eebf`. 40 contrôles verts, seul rouge SSM (3 échecs identiques sur main eb089ff). Vercel `dpl_93CfQ1mhf1k5abxw5a5fyNRKpYWk` READY, alias vérifié ; 11 fichiers publics identiques. Deux bancs Chromium rejoués sur ces fichiers : 54 bascules supplémentaires et 837 rendus existants, verts. Complément transversal missions/musées : 35 tests Node verts.
