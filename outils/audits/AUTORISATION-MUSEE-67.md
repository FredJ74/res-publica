# Issue #67 — bouton contextuel du coffre du musée

La quête porte l'autorisation dans `state.char.enigme1.autorisationCoffre` et la consommation dans `coffreOuvert`. Aucun second objet/marqueur créé. Le rendu commun des ordres masque `presenter_autorisation_coffre` sans autorisation inutilisée ; le handler vérifie la même condition avant le débit existant. La clé, les dialogues, le coût et le parcours existants sont conservés.

5/5 tests locaux : sans état, sans autorisation, autorisation valide, déjà utilisée, attribution de la clé et consommation du marqueur par la fonction réelle. La lecture après F5 utilise le même état persistant de personnage. Aucune nouvelle RPC ni migration ; il ne s'agit pas d'une refonte transactionnelle du moteur de quête historique, dont les effets et la sauvegarde restent existants.

Non fusionné, non déployé : prévol distant et validation en jeu indisponibles dans cette session. Cette correction UI est indépendante de la construction et des nouvelles migrations immobilières.
