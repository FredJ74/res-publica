# Drogues en Républia (décisions de Fred, 2 novembre 2026)

Le jeu ne fait pas la promotion de la consommation de drogue : c'est du RP, adossé au narco-état
d'El Estado. **Aucune drogue réelle n'est nommée** ; les PNJ n'emploient jamais de nom réel.

## Statut légal
- **Consommer est légal.** **L'achat et le transport sont illégaux** : trace `achat_drogue`
  (7 jours) chez le dealer, objet `legal:false` saisi en douane.
- Chaque consommation laisse une trace (7 jours) que les rumeurs et enquêtes peuvent exploiter :
  `consommation_drogue` (Brume), `consommation_estadine`. La justice ne les qualifie pas.

## Produits

| | Brume (drogue douce) | Estadine (drogue dure) |
|---|---|---|
| Prix à El Estado (à l'ouverture de l'empire) | 3 FR le pochon | 6 FR le pochon |
| Prix en Républia | 50 FR | 120 FR |
| Réapprovisionnement par dealer | +3 par jour | +1 par jour |
| Stock maximal par dealer | 30 | 10 |

Dealers : Céd' Labone (Luthécia), Ronan Lafourgue (PSM), Jojo Laferraille (Montrouge), aux
travées des centres artisanaux. Même offre partout.

## Effets

**Brume** (même effet quel que soit l'âge du pochon) : moral +10, ENT +2 jusqu'à minuit (non
cumulable), PA −1, santé −5.

**Estadine** : un coup de boost immédiat qu'on paie cher ensuite.
- Montée : PA +3, moral +15, CHA +2 pendant 6 h (non cumulable).
- Descente, 6 h après chaque dose : moral −25, santé −10, −3 PA à la recharge suivante.
- Usure cognitive : INT −0,1 par dose ; chaque dose s'efface au bout de 15 jours (réversible).

Choix techniques : la santé ne descend jamais sous 1 du fait d'une drogue (pas d'hospitalisation) ;
les bonus et malus de caractéristiques vivent dans `effets_actifs` et ne sont lus pour l'instant que
par l'écran (les jets décidés par le serveur lisent encore les caractéristiques de base).
