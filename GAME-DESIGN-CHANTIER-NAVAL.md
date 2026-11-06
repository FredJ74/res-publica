# Chantier naval de Port-Sainte-Marie — contrat de raccordement

## Décisions établies du game designer (4 novembre 2026)
- Deux modèles de bateaux : **3 passagers et 300 unités de fret**, prix total de fabrication **90 000 FR** ; **5 passagers et 500 unités de fret**, prix total **150 000 FR**.
- Matières à fournir par bateau, sans substitution : **1 200 bois + 1 200 métal + 600 dérivés pétrochimiques** pour le petit modèle ; **1 800 bois + 1 800 métal + 600 dérivés pétrochimiques** pour le grand.
- La ressource **dérivés pétrochimiques** reste unique ; les vernis, résines, goudrons, peintures et polyester sont des usages industriels narratifs de cette ressource.
- Les matériaux arrivent progressivement ; l'ouvrage avance par étapes (ne pas valider une fabrication instantanée faute de durée établie).
- Fabrication dans le chantier naval existant à Port-Sainte-Marie, référence **Pierrick Le Roux**.
- Le bateau achevé est un **bien physique localisé dans un port** ; il ne va jamais dans l'inventaire de 100 objets du PJ.
- Le bateau appartient à un seul PJ. **Seul le propriétaire pilote et embarque son groupe**, jusqu'à la capacité de passagers.
- La **cale de fret séparée de l'inventaire**, capacité 300/500 selon modèle, est vidée à destination selon la règle de navigation validée.
- Le déplacement maritime est **port à port et instantané**, avec PA et douanes aux destinations internationales (à raccorder sur le moteur transports sans inventer un état en mer).
- Le chantier pourra servir d'intermédiaire à la vente d'occasion (révision complète justifiant la commission) ; réparation envisagée, mais aucune mécanique d'usure n'est validée.
- La raréfaction voulue du bois, des métaux et des dérivés soutient la concurrence avec l'immobilier et l'activité des traders.

## Contrats de données souhaitables
- `naval_modeles`: modèle, capacité passagers, capacité fret, recette fixe, prix total.
- `naval_commandes`: acheteur prouvé par l'identité Supabase, modèle, avances, matériaux effectivement réservés, progression, événements datés et état.
- `naval_bateaux`: identifiant stable, propriétaire, modèle, localisation portuaire, cargaison, statut (en port, non en mer), identité de construction.
- Idempotence par UUID de requête, transaction et verrous serveur pour débiter, réserver, livrer, vendre ou transférer.
- Les prix au joueur et consommations doivent être affichés **avant** validation ; aucun client ne doit pouvoir fixer le prix, la quantité, le propriétaire ou une position maritime.
- Les marchandises en entrepôt public **ne sont jamais prélevées gratuitement** : acheter/réserver doit conserver le prix réellement affiché, la caisse et le registre de transactions.
- S'assurer que les entrepôts n'ont **pas** actuellement les 1 200/1 800 unités simultanément : la progression est structurellement indispensable.

## Règle de construction approuvée (4 novembre 2026, dernière décision)
- **7 jours effectifs** pour le bateau 3 places ; **10 jours effectifs** pour le 5 places.
- **35 % du prix total en acompte lors de la commande**, puis les **65 % restants en journées de travail réellement exécutées**. Le total ne dépasse jamais 90 000 / 150 000 FR.
- Chaque paiement alimente une **caisse séquestre serveur propre à la commande**. Elle règle les fournisseurs selon les stocks effectivement sortis, puis verse le reliquat au constructeur à la réception. Ainsi les fonds ne disparaissent pas pendant le chantier et les transferts sont auditables.
- Chaque jour, le chantier consomme une tranche exacte des 1 200/1 800 bois, 1 200/1 800 métal et 600 dérivés pétrochimiques. La répartition emploie `ceil(total * jour / jours_total) - ceil(total * (jour - 1) / jours_total)` pour ne perdre aucune unité.
- **Si une seule des matières nécessaires du jour manque, le chantier est bloqué** : ni progression, ni prélèvement du solde, ni sortie de stock. Les jours perdus ne sont pas rattrapés automatiquement.
- Un entrepôt de Port-Sainte-Marie livre les matières chaque jour **au tarif affiché à cet instant** ; le règlement est versé à sa caisse et inscrit à son journal. Ce coût est inclus dans les 90 000 / 150 000 FR du contrat, **jamais refacturé au client**. Les traders peuvent augmenter les stocks de l'entrepôt par les voies commerciales existantes.
- Si les cours des matières absorbent l'enveloppe contractuelle disponible, le chantier est bloqué financièrement ; aucune ponction ni fabrication à crédit cachée.
- Les fonds restants une fois les matières achetées sont versés au chantier naval à la réception ; pas de double paiement.
- **La création du bateau est unique, transactionnelle et idempotente**, liée à une commande authentifiée. Propriétaire et immatriculation conservés au port de Port-Sainte-Marie (bâtiment `port-sainte-marie`).
- Une livraison ne crée **aucun** objet dans les 100 places d'inventaire du PJ.
- La navigation privée du navire livré reste désactivée jusqu'à raccordement explicite du moteur de déplacement et des douanes. Elle ne doit pas être simulée par l'achat d'un billet public.

## Encore séparé de cette livraison
- Navigation privée, coût PA, groupes, transferts port à port et douanes ; les billets de transport publics existent et restent inchangés.
- Réparation, révision et vente d'occasion ; les paramètres tarifaires ne sont pas validés.
- Réservation d'un anneau individualisé et limite du nombre de bateaux par propriétaire : non arbitrées.

## Livraison
Ne fusionner qu'une fois les bancs PostgreSQL transactionnels et la CI verts, la migration validée et la cohérence Supabase établie. Seule la construction et la livraison physique sont dans ce lot, pas le déplacement privé.
