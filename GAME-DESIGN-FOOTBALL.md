# Football — règles du game designer

Référence pour tout agent : ne pas redemander ce qui est tranché ici.

## Transferts de joueurs

- **Pas de prime de signature dans le moteur de transfert** (décision de Fred, 01/11/2026). Le
  transfert règle seulement le prix entre le club de départ et le club d'arrivée. Une somme versée au
  joueur pour qu'il signe est une **question entre PJ** : elle se négocie et se paie entre eux, par
  les moyens ordinaires (virement), jamais par le transfert lui-même.
- Conséquence technique : la migration préparée `20261031220000_transfert_prime_signature_serveur`
  (jamais appliquée) est retirée, ainsi que l'affichage « Prime de signature proposée ». Le champ
  `prixJoueur` d'une offre n'est versé par personne.
