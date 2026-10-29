# Groupes universels — décisions explicites de Fred, 28 octobre 2026

## Autorité ≠ commandement ≠ appartenance
- **Reprise d'un membre détaché :** seulement par la personne disposant déjà de l'autorité sur ce membre. Un commissaire ne récupère que les policiers de son commissariat, jamais ceux d'une autre ville.
- Le propriétaire d'un PNJ employé peut le reprendre ; diriger temporairement un PNJ prêté **ne transfère pas** l'autorité sur lui.
- Aucun PJ ne peut imposer à un autre PJ de rejoindre son groupe.
- Le chef de groupe décide du déplacement et de l'engagement collectif, sans gagner les droits administratifs sur les membres prêtés.

## Composition et déplacement
- Les PJ se regroupent **volontairement** : un PJ sélectionne la fiche d'un autre PJ dans « personnes présentes » et utilise « Rejoindre » (présence effective du bouton à vérifier).
- Un PJ ne peut rejoindre **un PNJ**, qui ne possède pas de mobilité propre.
- Le chef de groupe PJ se déplace avec les membres de son groupe ; les PNJ isolés restent là où ils ont été laissés.
- Les PNJ employés/agents sous l'autorité d'un PJ peuvent être **affectés à un autre groupe**, déjà dirigé par un PJ ou constitué de PNJ, sans transfert d'autorité.
- Un détachement de PNJ sans PJ peut exister, mais ne lui prêter aucun déplacement autonome non prévu.

## Combat et recherche
- Si le chef de groupe engage un combat contre PJ ou PNJ, **tout le groupe** y participe.
- Si un PJ recherché se trouve dans un groupe, la police combat le groupe pour tenter de récupérer le PJ recherché : pas d'interpellation comme s'il était seul.
- Les mécanismes de détection, combat, interception et incarcération restent ceux du socle commun ; aucune création de moteur par type de PNJ.

## Exemple opposable
Un lieutenant affecte quatre de ses soldats à un groupe de trois policiers dirigé par un commissaire. Le commissaire se déplace avec les sept PNJ. Il peut déposer puis récupérer un policier **de son commissariat**. S'il dépose l'un des quatre soldats, il ne peut **pas** le reprendre ; seul un acteur disposant de l'autorité correspondante le peut.

## Vérifications de raccordement
- Vérifier que « Rejoindre » existe réellement sur la fiche PJ et ne crée pas seulement un état navigateur.
- Conserver séparément l'autorité, les liens de suivi et l'identité du commandement ; ne pas utiliser un « groupe de bataille » comme substitut universel.
- Tester les frontières d'autorité entre commissariats, la délégation lieutenant → commissaire, la séparation et reprise, la présence effective, les combats collectifs et le PJ recherché protégé par son groupe.

**Statut : spécification de game design enregistrée ; aucune fonction n'est prétendue modifiée ou testée par ce document.**

## Exception unique : rappel par radio (précision explicite de Fred, 28/10/2026)

**Des PNJ peuvent effectuer seuls un déplacement uniquement lorsqu'un responsable habilité les rappelle par radio.** Exemples validés :

- Un lieutenant détache un groupe de soldats PNJ, dont au moins un possède une radio. Le lieutenant possède lui-même une radio et peut rappeler le groupe pour qu'il le rejoigne à son emplacement actuel.
- Un employeur PJ peut équiper ses agents de sécurité PNJ d'une radio et, avec sa propre radio, les appeler pour qu'ils viennent le rejoindre.

Cette possibilité est **universelle et non réservée à l'armée** : elle s'applique aux groupes PNJ d'autres métiers, avec les mêmes conditions. Un seul membre du groupe rappelé doit être doté d'une radio ; le PJ donneur d'ordre aussi. Le déplacement est commandé à distance par radio, pas décidé spontanément par les PNJ. Les règles d'autorité continuent à s'appliquer : la radio ne donne aucun droit de commander ou de reprendre des agents d'autrui.

Ne pas multiplier les moteurs de déplacement autonome par métier. Raccorder la règle à la gestion existante de radio, d'inventaire/équipement, de suivi, de groupe, d'autorité et de déplacement. Vérifier la réalisation effective du déplacement côté serveur avant de retirer tout ancien parcours.

**Important :** le texte antérieur « aucun déplacement autonome PNJ » admet expressément cette unique exception. Le document n'établit pas les coûts, délais, obstacles ou limites de portée radio, qui ne doivent pas être inventés.

## Portée géographique de la radio — précision de Fred (28/10/2026)

**La liaison radio est strictement limitée à une même ville.** Un ordre de rappel par radio d'un groupe PNJ ne peut être exécuté que si le PJ appelant et le groupe appelé se trouvent dans **la même ville**. Deux villes différentes : **aucune liaison, aucun déplacement autonome**. Cette condition est à contrôler par le serveur avant tout mouvement. La présence de radios des deux côtés et l'autorité du PJ restent nécessaires, mais ne suffisent pas à contourner la limite géographique. Aucun rayon supplémentaire ni exception inter-villes n'est défini.

## Transports payants collectifs — arbitrage explicite de Fred, 28/10/2026

Le leader prend en charge le coût du transport de **tous** les membres PJ et PNJ,
lui compris. Payeur unique : le leader. Prix total = tarif existant × nombre total
de voyageurs. Chaque PJ et chaque PNJ compte pour un voyageur payant. Le coût en
PA reste celui de l'ordre de transport existant ; aucun nouveau barème n'est créé.

Si les fonds du leader ne couvrent pas tout le groupe, tout le transport est
refusé, sans débit ni déplacement partiel. Paiement et déplacement forment une
transaction unique. Les conditions habituelles d'accès et de voyage s'appliquent
à chacun ; rejoindre un groupe ne fournit pas de dispense. Réutiliser le moteur
de paiement et de déplacement, sans deuxième billetterie ni nouveau tarif.

Exemple validé : tarif 100 FR, leader + deux PJ + quatre PNJ = sept voyageurs,
soit **700 FR payés par le leader**. Cette décision remplace l'attente d'arbitrage
consignée au point de sauvegarde `8c2904dc` ; aucun transport PNJ gratuit n'est retenu.

## Convocations douanières des accompagnants — Fred, 28/10/2026

Un PNJ accompagnant n'est pas convoqué : seuls les PJ le sont. Un PNJ n'a pas
de mobilité autonome ordinaire. La responsabilité judiciaire n'est pas transférée
à un PJ du seul fait qu'il paie le transport ou commande le groupe. Les contrôles
des objets et les confiscations existantes restent applicables ; cette décision
ne crée pas de dispense de contrôle pour les possessions PNJ.
