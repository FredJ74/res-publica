# Game design — L'armée

Règles décidées par Fred (game designer). Les agents s'y réfèrent avant toute modification du
socle militaire ; toute nouvelle décision s'ajoute ici avec sa date.

## Mission des soldats (décision de Fred, 03/11/2026)

1. **On ne choisit pas la mission des soldats** : elle est automatique. Aucun ordre ne permet à
   un lieutenant (ni à personne) de leur assigner une consigne.
2. **En temps de paix, des soldats postés sont des renforts policiers.** Ils agissent comme la
   police : dissuasion des actes illégaux (malus commun min(40, 10 + hommes armés présents)),
   détection des PJ recherchés, confrontation et interpellation selon le fonctionnement policier.
   Ils n'interviennent que dans l'État dont ils relèvent ; ceux qui escortent un PJ ne comptent
   pas contre lui.
3. **Ils n'attaquent personne**, sauf si le pays est déclaré en guerre contre un autre : ils
   attaquent alors les soldats, policiers ou douaniers du pays adverse.

Fred n'a jamais demandé l'ordre « Attribuer une mission » ni ses cinq missions (bloquer l'accès,
sécuriser, assassiner toute personne entrant, arrêter toute personne entrant, surveiller) : codés
sans décision, ils ont été retirés le 03/11/2026 (migration `20261103163000_soldats_renforts_policiers`).
