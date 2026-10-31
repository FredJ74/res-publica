# Game design — Banques (Helvetia, Banque nationale)

Décisions explicites de Fred, consignées pour tous les agents.

## Caisse d'Helvetia et refinancement BNR (#267)

- **Règle technique (Claude, 31/10/2026)** : la caisse `<pays>_banque-privee` est l'argent que
  la banque détient réellement. Un prêt laisse l'argent sur le compte du client ; seuls les
  retraits et restitutions la vident. Migration `20261031140000_helvetia_caisse_argent_detenu`.
- **Refinancement BNR en trop (31/10/2026)** : une première note disait « remboursement normal ».
  ChatGPT a ensuite fusionné et appliqué l'annulation du seul refinancement excédentaire
  (`20261031150000_helvetia_bnr_excedent_regulariser`, PR #288 : 150 000 FR « retrait_client » au
  statut `annule`, il reste 73 320 FR « pret_client »). Fred laisse le choix à Claude, qui **garde
  l'annulation** : ces 150 000 FR naissaient d'un défaut, pas d'un besoin réel de la banque.
- **Placement Helvetia (Claude, 31/10/2026, technique)** : règles inchangées (gain brut 8 %, frais
  30 % du gain, impôt 50 % du reste si déclaré). Le montant final va sur le compte Helvetia seul ;
  la caisse reçoit frais + gain net. Migration `20261031151000_placement_helvetia_gain_unique`.
