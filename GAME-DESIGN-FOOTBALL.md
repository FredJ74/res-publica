# Football — règles du game designer

Référence pour tout agent : ne pas redemander ce qui est tranché ici.

## Transferts de joueurs

- **Pas de prime de signature dans le moteur de transfert** (décision de Fred, 01/11/2026). Le
  transfert règle seulement le prix entre le club de départ et le club d'arrivée. Une somme versée au
  joueur pour qu'il signe est une **question entre PJ** : elle se négocie et se paie entre eux, par
  les moyens ordinaires (virement), jamais par le transfert lui-même.
- Conséquence technique : l'affichage « Prime de signature proposée » est retiré (PR #330). La migration
  `20261031220000_transfert_prime_signature_serveur`, préparée sans décision de Fred, **a été appliquée en
  production le 31/10** ; elle est neutralisée par `20261101190000_transfert_sans_prime_signature`
  (offre avec prime refusée, conclusion sans prime). Le champ `prixJoueur` n'est versé par personne.
