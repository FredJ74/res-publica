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
115 tests Node ciblés et l’ancien banc des rumeurs secrètes passent. Pas de CSS
modifié ; les adaptations mobiles communes suffisent dans ces essais.

Comparaison main, mesures, CI et production à terminer. Aucune session PJ réelle,
aucun téléphone physique ni revue native. Les opérations métier des bancs sont
simulées ; aucune donnée de joueur lue ou écrite.
