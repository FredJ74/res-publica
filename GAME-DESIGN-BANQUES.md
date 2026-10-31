# Game design — Banques (Helvetia, Banque nationale)

Décisions explicites de Fred, consignées pour tous les agents.

## Caisse d'Helvetia et refinancement BNR (#267)

- **Règle technique (Claude, 31/10/2026)** : la caisse `<pays>_banque-privee` est l'argent que
  la banque détient réellement. Un prêt laisse l'argent sur le compte du client ; seuls les
  retraits et restitutions la vident. Migration `20261031140000_helvetia_caisse_argent_detenu`.
- **Décision de Fred (31/10/2026)** : le refinancement BNR contracté en trop à cause du défaut
  (environ 150 000 FR sur 223 320 FR en cours pour la République) **n'est pas annulé** : il se
  rembourse normalement, selon les échéances existantes. Aucune régularisation à écrire.
