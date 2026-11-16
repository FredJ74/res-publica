# Goulag de Sovarka — préparation technique (16 novembre 2026)

**Statut : spécification préparatoire, aucun RPC, accès ni nouvel ordre de goulag activé.** Décisions ci-dessous fournies par le game designer ; les points ouverts ne doivent pas être inventés lors du codage.

## Décisions confirmées
- Le goulag est situé **hors des villes**. Le modèle `WORLD.soviet.qhs` existe déjà avec le bâtiment `qhs-prison` ; il n'est pas encore un goulag jouable et ses ordres sont ceux du QHS de Républia, à **ne pas réutiliser tels quels**.
- Chacun des centres multimodaux de Sovarka offre un voyage vers le goulag. Accès direct : **ministre de la Justice, chef du gouvernement, juges**. Tous les autres PJ demandent une autorisation au ministre de la Justice ; ce ministre dispose d'un ordre de validation.
- Un détenu ne peut utiliser aucun trajet vers un centre multimodal pour s'évader.
- À l'entrée du goulag : ordre **« S'enfuir à pied »**, avec choix de destination **Starovka (7 jours)** ou **Krasnov (10 jours)**. Le joueur doit voir le coût et la durée avant confirmation. **Aucune durée minimale de peine ni de peine restante** n'est exigée : le PJ décide librement de tenter la fuite, même s'il ne lui reste que quelques heures de détention. Le serveur ne compare jamais le temps de peine restant aux 7/10 jours de marche pour autoriser ou refuser l'ordre.
- À l'arrivée : état d'épuisement ; le fugitif doit trouver refuge chez un **habitant** pendant **3 jours**, sur une logique similaire à l'hospitalisation des personnages à 0 PA.
- Popup dès l'arrivée : portrait du fugitif diffusé en ville, recherche urgente d'un refuge chez l'habitant, et risque important d'arrestation à l'hôtel ou à l'hôpital. **Formule de risque à définir**.
- Aucun mécanisme de gouvernance municipale supplémentaire à créer.

## Raccordements et protections techniques à prévoir
1. **Contrôle serveur** de l'accès au goulag par (pays, fonction nationale/locale, ville, PJ), avec autorisation nominative signée par le ministre ; ne pas faire confiance à un bouton grisé.
2. **Règle de transport spéciale** depuis les gares/centres multimodaux de Sovarka vers `soviet/qhs`, sans créer de fausse ville dans `villes` ni emprunter les règles de taxi du QHS de Républia. Départ vers le goulag refusé à toute personne non autorisée. Retour normal interdit au détenu.
3. **Demande et décision ministérielle** persistées côté serveur, anti-double décision et consultation des demandes. Autorisation non transférable ; déterminer durée/usage lors de l'arbitrage.
4. **Évasion atomique** : valider statut de détenu, destination et prix éventuel (sans seuil lié à la durée de peine) ; inscrire une fuite en cours, immobiliser le personnage pendant 7 ou 10 jours, sans navigation ordinaire ni autre évitement. À l'issue, déplacer vers la ville choisie, mettre en place le suivi judiciaire et l'épuisement, afficher la popup au prochain retour en jeu.
5. **Récupération en refuge** : état serveur persistant de 3 jours, associer l'hébergeant PJ et un logement réellement disponible ; empêcher le contournement par déconnexion, hôtel ou navigation forcée. Réutiliser les primitives PA/hospitalisation compatibles, sans confondre détenu et patient.
6. **Vie privée et fuite** : distinguer le signalement public (portrait diffusé en ville) des éléments judiciaires confidentiels. Sanctions et probabilités à arbitrer.
7. **Tests** : toutes les habilitations, deux destinations, autorisation de fuite avec moins d'un jour restant et même quelques heures, aucune comparaison à 7/10 jours de peine, refus des transports en détention, trajet multi-jours et déconnexions, double-clic, sortie de prison, refuge chez PJ, hôtel/hôpital, incompatibilités temporelles, absence de régression sur QHS/Républia. Vérifier d'abord les signatures courantes des fonctions SQL.

## Points nécessitant arbitrage
- **Tranché le 16/11 par Fred :** aucun minimum de peine totale ou restante, pour Starovka comme pour Krasnov ; une évasion même à quelques heures de la libération est un choix du PJ.
- « L'évasion a un prix » : quel prix (PA, santé, jours ajoutés à la peine en cas de capture, monnaie, autre) ? Peut-on commencer avec 0 PA ?
- Que devient la peine pendant les 7/10 jours de marche, et à l'arrivée ? La récupération chez l'habitant exige-t-elle sa présence/acceptation explicite et un ordre « héberger » ?
- Comment arbitrer la détection en hôtel/hôpital, et les arrestations/soins en cas de manque de refuge ?
- Nature et validité de l'autorisation du ministre (usage unique, permanante, expiration), modalités de retour des visiteurs.

Ces arbitrages ne sont pas des blocages pour la préparation architecturale, mais bloquent l'activation réelle de l'évasion.
