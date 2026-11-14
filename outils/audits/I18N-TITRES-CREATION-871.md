# #871 — attente et titres des refus de création du personnage

PR #928. Six libellés fixes manquants dans `validateChar` : « Creation en cours... »,
« Vous avez deja un personnage », « Ce nom est deja porte », « Genre manquant »,
« Session expiree », « Creation impossible ». Le français original, y compris son
orthographe et sa ponctuation, reste identique. 48 traductions étrangères ajoutées
au catalogue existant `connectionUi`, toutes les ressources antérieures conservées.

Le bouton d’attente conserve sa clé initiale, reçoit temporairement la clé du texte
d’attente puis retrouve son libellé dans la langue courante après un refus. Un
bouton personnalisé sans clé retrouve son texte. Les titres reçoivent les seuls
attributs de présentation du moteur existant. Aucune seconde traduction automatique,
aucun changement du verrou de création, de navigation, de requête, de cache ou de
personnage. Les explications longues et leurs valeurs restent intactes et ne sont
pas annoncées comme traduites par ce lot.

Preuve : AST entier de creation.js identique après retrait des seules métadonnées ;
comparaison du catalogue précédent et contrôle des neuf langues. Chromium simule
neuf parcours sur 320/390/1280 : nom pris, compte déjà pourvu, genre manquant,
session expirée, motif inconnu, autre personnage du compte, transport rejeté,
succès, réussite d’un envoi concurrent. Même français, mêmes appels, cache, verrou
et navigation que main. 432 bascules pendant l’attente puis après les refus,
aucune requête/dépense nouvelle, aucun double envoi, brouillon/focus/sélection/position
conservés, RTL arabe et aucun débordement. Réponse reçue après changement de langue,
bouton personnalisé et ressource allemande absente également vérifiés.

Les opérations serveur sont simulées : aucun compte ni personnage réel créé,
aucune donnée de joueur lue ou modifiée. Pas de revue native ni téléphone physique.
41 tests Node ciblés, 12 tests de connexion (dont deux navigateur) et quatre
bancs Chromium verts. Les bancs étrangers comparés à main fb25f0e retrouvent
les mêmes 32/37 : deux inventaires de descriptions (247/246, 153/151) et trois
SSM connus, aucune régression nouvelle.

Mesure avec le même extracteur : corpus inchangé 7 587 textes/50 923 mots,
zéro raccordement statique supplémentaire reconnu ; les marqueurs de titres
choisis par table et le bouton conditionnel ne sont pas reconnus par cet
extracteur strict. Le rendu des six textes est vérifié en Chromium, sans gonfler
le taux. Une ressource supplémentaire / trois mots source sont reconnue dans
le corpus statique ; les autres titres y figurent hors dénominateur strict.
Anglais : 24,33 % des mots statiques identifiés, pas de tout le jeu.
Zéro erreur d’extraction. Mesures complètes dans le JSON associé.

CI finale, fusion et production à terminer.
