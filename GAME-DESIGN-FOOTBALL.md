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

Écran (01/11/2026, demande de Fred) : l'offre « Proposer un transfert » comporte le champ « Prime de
signature au joueur », facultatif ; la prime est annoncée au président du club de départ et au joueur.

## Accessoires de club (décision de Fred, 28/11/2026)

Remplace les règles du 27/11/2026 (accessoire personnalisé à +10, deux objets revêtus au plus).

- **Accessoire standard** (buvette des stades, boutique des stades de Sovarka) : écharpe, casquette ou maillot du club local,
  aux prix inchangés, payés en monnaie du jeu. Il se **revêt** (ordre « Revêtir » de l'inventaire) et donne **+5 popularité**
  tant qu'il est porté.
- **Accessoire personnalisé** : **exactement le même bonus, +5** ; la personnalisation ne change que l'apparence (image créée
  par IA à partir de la demande du joueur).
- **Ville du club** : le bonus ne vaut que lorsque le porteur se trouve dans la ville du club (le pays compte : la capitale de
  Sovarka n'est pas celle de Républia). Il disparaît quand il en sort, revient quand il y rentre. On ne perd jamais que la
  popularité réellement gagnée (plafond de 100 : un joueur à 98 gagne 2 et n'en reperd que 2).
- **Un objet de chaque type au plus** : une écharpe, une casquette, un maillot de club, standard et personnalisé confondus,
  tous clubs confondus (une commande personnalisée en cours compte). Le serveur refuse l'achat d'un doublon.
- **Trois objets revêtus à la fois au plus**, quels qu'ils soient (masque, gilet, tenue, chemise, accessoires…), et toujours
  un seul par catégorie.
- **Personnalisation** : incluse dans l'abonnement, elle consomme le **renouvellement d'image hebdomadaire** de l'abonné (un par
  semaine, non cumulable). Les non-abonnés l'achètent à l'unité, comme avant (prix fixé dans la page MJ, paiement « bientôt
  disponible » tant que le prestataire n'est pas choisi). Si l'image ne peut pas être créée, la commande est annulée et le
  renouvellement de la semaine rendu.

Code : migration `20261128110000_accessoires_club_revetables.sql` (déclencheur `zzz_accessoires_club_popularite`, qui suit
l'inventaire et la position ; `club_accessoire_acheter`, `crim_revetir`, `accessoire_personnalise_offre` / `_commander` /
`_annuler` / `_livrer_service`) ; écran `plateau-accessoire-personnalise.js` ; banc `outils/bancs/banc-accessoires-club-20261128.cjs`.

### Réponses de Fred du 28/11/2026 (soir) — remplacent « un objet de chaque type » et la personnalisation ci-dessus

- **L'achat n'est plus limité** : plusieurs écharpes, casquettes ou maillots (même club ou non) peuvent s'acheter,
  se recevoir en don, se voler ou se trouver. **Seul le port est limité** : trois objets revêtus au plus, quels qu'ils
  soient, et **au plus un accessoire de chaque type revêtu** (écharpe, casquette, maillot), tous clubs confondus.
  Revêtir une deuxième écharpe retire d'office la première (même règle que les autres objets revêtus).
- **Accessoire personnalisé** : gratuit pendant la bêta, comme tout le premium. Ensuite : le renouvellement d'image
  hebdomadaire de l'abonné, puis, s'il l'a déjà utilisé (ou pour un non-abonné), l'achat à l'unité par l'écran de
  paiement commun (crédit créé par le seul webhook signé, consommé par la commande). **Le renouvellement est consommé
  dès que l'image est créée**, même si l'objet n'est jamais validé ; il n'est rendu que si la commande est annulée
  avant toute image.
- **Fonction d'image déployée** (feu vert de Fred) : fonction Edge `accessoire-personnalise` (génération OpenAI, secret
  `OPENAI_API_KEY`), éprouvée de bout en bout en production le 28/11/2026 avec un personnage de test supprimé ensuite.
- Code : migration `20261128210000_accessoires_premium_acquis` (marques `accessoire_achat_libre_v1`,
  `accessoire_perso_sources_v1`) ; banc `outils/bancs/banc-accessoires-premium-acquis-20261128-soir.cjs`.
