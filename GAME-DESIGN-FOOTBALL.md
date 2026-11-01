# Football — règles du game designer

Référence pour tout agent : ne pas redemander ce qui est tranché ici.

## Transferts de joueurs (décision de Fred, 01/11/2026)

Une offre de transfert du club qui recrute porte deux montants, tous deux payés par la caisse de ce
club, dans la même transaction, à l'acceptation du joueur :

- le **prix du transfert** (`prixClub`) va au **club de départ** : c'est son dédommagement pour la
  perte du joueur ;
- la **prime de signature** (`prixJoueur`), fixée par le président du club qui recrute, facultative,
  va au **joueur muté**.

C'est un ordre ancien, conservé tel quel (Fred, 01/11 : « laisser la prime de signature », réponse
« garder comme aujourd'hui »). Côté serveur : migration `20261031220000`, appliquée le 31/10.
