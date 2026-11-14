# #871 — tableau des organisations

PR #932, seule fonction `ouvrirTableauOrganisations`. Quinze libellés fixes / 120
traductions étrangères : titre, état vide, détails non communiqués, préfixes Chef/Siège,
siège inconnu et neuf types canoniques. Français exact, espaces et casse conservés.
Catalogue de présentation `organizationDirectory`, moteur i18next commun ; aucun
second moteur ni nouvel appel serveur. Le titre porte son marqueur sur un span :
une autre fenêtre détruit ce marqueur en remplaçant son titre normalement.

Les noms de joueurs, organisations, empires et lieux restent opaques ; aucune
traduction automatique de leurs chaînes. Les valeurs dynamiques sont échappées à
l’insertion pour empêcher de créer des marqueurs via les noms saisis. Les noms de
lieux déjà encodés en HTML gardent leur affichage (Chasse &amp; Pêche → Chasse & Pêche).
Les types sont marqués seulement si le libellé canonique français correspond au
catalogue ; un type nouveau ou modifié reste affiché tel quel. Les identifiants,
les noms des lieux et la détermination du pays d’origine ne changent pas.

Les mêmes branches masquent le chef et le siège d’une organisation secrète au
non-membre ; un membre ordinaire garde les mêmes informations qu’avant. Aucun
champ secret n’est ajouté aux marqueurs ou au HTML masqué. Les autres fonctions
(adhésion, événements, ordres, PNJ, quêtes…) de cette grosse source ne changent pas.
Aucun coût, inventaire, droit, condition, RPC, migration ou donnée joueur modifié.

Vérifications : fichier entier comparé par AST après retrait des seuls marqueurs,
échappements et adaptations de rendu. Français entier comparé à main pour 37 états.
Neuf langues / 999 bascules Chromium à 320/390/1280 ; RTL arabe, aucune dépense ni
requête, état/brouillon/focus/sélection conservés, aucun débordement. Liste longue :
même organisation visible et même nœud après bascule, pas de retour au début.
Noms contenant des marqueurs ou un texte UI conservés comme texte, type modifié
non traduit, repli français, fermeture/réouverture et fenêtre voisine vérifiés.
116 tests Node ciblés passent ; les 114 tests existants correspondants passent
aussi sur main, dont les anciens bancs d’ordres, membres, événements et rumeurs. Pas de CSS
modifié ; les adaptations mobiles communes suffisent dans ces essais.

## Mesure et comparaison

Même extracteur sur main a7ce1e0 et code ebaca20. Le périmètre statique enrichi
par les marqueurs passe de 7 584 textes/50 891 mots à 7 588/50 901 : quatre
fragments de rendu supplémentaires sont identifiés et raccordés (Chef/Siège,
siège inconnu et détails masqués), dix mots source. À périmètre commun strictement
identique : zéro raccordement supplémentaire reconnu, deux ressources / huit
mots source supplémentaires disponibles. Au total : +6 ressources/+18 mots source.
Les quinze libellés sont vérifiés en navigateur ; le tableau de bord n’en déduit
pas quinze raccordements. Aucun texte statique retiré, zéro erreur d’extraction.
Anglais : 1 025 textes/12 411 mots raccordés, 24,38 % des mots statiques identifiés,
pas de tout le jeu. La comparaison détaillée versionne aussi le corpus commun.

Bancs étrangers : mêmes 34/37 sur main et branche ; seuls les trois SSM habituels
échouent. Les inventaires de descriptions sont désormais verts sur cette base.
CI finale, fusion et production à terminer. Aucune session PJ réelle,
aucun téléphone physique ni revue native. Les opérations métier des bancs sont
simulées ; aucune donnée de joueur lue ou écrite.
