# Session nocturne du 19 octobre 2026 — état de livraison et reprise

**CHANTIER GLOBAL NON TERMINÉ.** Plusieurs corrections sont codées et éprouvées localement. Aucune vérification de production ni migration Supabase n'est revendiquée. Les fonctionnalités organisationnelles et la bascule financière intégrale ne sont pas implémentées par ce lot.

## Point de départ et accès

Main récupéré à `4ba350d`, avec tous les commits cités dans la mission. Aucun changement local initial. Les développements déjà présents (trois rubriques, dix articles, recettes, garde de production publique, portraits, diagnostic financier, D-Bus/60 secondes) ont été conservés.

Les demandes HTTPS à `res-publica.vercel.app/plateau.html`, `api.vercel.com`, `api.github.com` et au REST Supabase ont été refusées par le proxy (403). Aucun token Vercel, accès SQL ni connecteur Supabase disponible ; Git fetch/push fonctionne. Le périmètre Vercel `fred-s-projects25` est rapporté par le propriétaire, pas identifié dans une réponse API exploitable ici. Ne pas confondre un refus du proxy avec une preuve d'erreur d'autorisation du projet lui-même.

## État des douze chantiers

| Chantier | Réalisé et limites |
|---|---|
| 1. Déploiement | Audit de la configuration et du filtre d'ignorance. Aucun workflow ne lance de déploiement CLI concurrent. Le filtre conserve le build de code/configuration ; les corrections de cette session ne sont pas seulement documentaires. **Connexion Git/Vercel, dernier build et ressources réellement servies inaccessibles. Aucun déploiement confirmé.** |
| 2. Messagerie | Rubriques déjà présentes, exclusivité et ouverture sur reçus testées. Corrections des réponses hors ordre et d'ancien personnage/connexion. Les interviews et aperçus Jodie sont protégés comme les brouillons contre un rendu asynchrone destructeur. Lecture, réponses, organisations et badges conservés. Tests de fonctions réelles/HTML produit, pas comptes authentifiés de production. |
| 3. Position | Avertissement normal de présence en bâtiment supprimé à sa source. Retour sans écriture conservé ; erreurs réelles de lecture et déplacements autoritaires préservés. Tests accueil, bureau et rue. |
| 4. Électronique | Dix articles vérifiés avec les SQL du catalogue dans une base jetable. Défauts du moteur existant reproduits puis corrigés dans une nouvelle migration gardée : consommation de composants répartis entre références, coûts réels et absence de matière fictive négative. Succès, refus, rollback, doubles demandes et concurrence testés. **Correction SQL non appliquée ; commerce réel de Jean Jaaj non inspecté.** |
| 5. Propriété organisations | Chemins typés `orga:` retrouvés dans l'achat et `mouvement_titulaire`. Cela ne prouve ni représentation autorisée, ni inventaire collectif/installations/transferts atomiques. **Fonctionnalité complète non implémentée.** Aucun bouton d'achat organisationnel non sécurisé n'a été ajouté. |
| 6. Ordinateur partagé | Règle retenue : un ordinateur, capacités cumulées des périphériques installés, sans consommation du matériel. **Socle serveur d'équipements installés et d'autorité collective à construire ; aucune fonction annoncée active.** |
| 7. Combinaisons | Moteurs existants de renseignement, commerce international, documents et fabrication à réutiliser. **Raccordement aux équipements non réalisé**, dépend du socle précédent. Aucun mini-jeu ou bonus fictif ajouté. |
| 8. Finances | Diagnostic SQL existant conservé. Autorité financière globale non basculée ; sauvegardes historiques et `mouvement_titulaire` restent à traiter avec tous leurs appelants. Branche de sauvegarde financière retrouvée à `a3e48c0fab31a8e20b26af37bce5fc01eecff91e`, non fusionnée aveuglément. **Aucun avoir d'Angie ni échéance de placement lu ou modifié ; aucun crédit/débit compensatoire.** |
| 9. Réception | Migration `20261016131932_reception_objets_atomique.sql` conservée. Bancs PostgreSQL locaux relancés. **Aucune RPC rétablie en production sans accès au catalogue ; disparition de l'alerte ne signifie pas réparation.** |
| 10. Jodie/journal | Faux succès sur verrou 409 supprimé. Succès conditionné à l'article effectivement enregistré, restitution serveur lors d'un rejeu. Vérification GoTrue et propriété du personnage ajoutées à l'API, bearer transmis/rafraîchi par le client. Migration préparée pour publier dans le forum lors de la sauvegarde de l'article, dans la même transaction ; le Journal continue de lire la source interviews, sans seconde file. Portrait courrier testé avec son trigger existant vers la file Journal. **Pas de publication réelle ni de réponses inventées pour Angie.** Horaire de minuit corrigé dans le dépôt. |
| 11. Bancs | Changements D-Bus et délai réel 60 s déjà présents conservés. Suite complète et banc Chromium exécutés localement ; résultats ci-dessous. **Résultat Actions distant non observable.** Aucun test désactivé. |
| 12. Enseigne | Décor transparent sans second cartouche conservé. L'algorithme actuel utilise encore des proportions du cadre (`15%`, `14,5%`, `70%`, `8,5%`) ; il ne constitue pas une zone garantie de l'image IA. **Image actuelle de Jean Jaaj et dimensions du cartouche non accessibles : aucun nouveau déplacement approximatif du texte.** Une zone normalisée attachée au décor et un rendu tenant compte de contain restent à réaliser et valider sur les vrais visuels. |

Les points 5–8 et 12 ne sont pas présentés comme simplement « déployables » : une implémentation supplémentaire reste nécessaire. L'indisponibilité des accès empêche aussi d'établir les contrats vivants et d'achever les essais sensibles, mais ne transforme pas du travail absent en fonctionnalité achevée.

## Corrections et commits

- `78f74b2` : messagerie, réponses tardives, protection de l'entretien Jodie, suppression de l'alerte de position normale et versions HTML.
- `0ba3ee3` : migrations correctives préparées et tests PostgreSQL de l'assemblage et des publications ; classement des SQL selon le workflow, CI existante réutilisée.
- `2b02d89` : API interview authentifiée/propriété contrôlée, persistance confirmée, absence de faux succès 409, reprise du texte enregistré.
- `766724b` : heure minuit Paris réconciliée quotidiennement ; anciennes propositions SQL rangées dans l'archive non déployable.

Les sept fichiers auparavant sous `supabase/migrations/` sont déplacés **octet pour octet** sous `migrations/`. Leur statut d'application réel n'est pas changé ni prétendu connu. Les deux anciennes propositions policières (sans enveloppe d'annulation, classées comme bancs à tort) sont déplacées octet pour octet vers `historique/sql-hors-registre/propositions/` ; aucune réimportation de leur logique.

## SQL préparés : ordre, sécurité, retour arrière

### Assemblage : `migrations/20261018231225_assemblage_composants_stocks_reels.sql`

La garde compare le hash exact du corps de la fonction de référence, ou du correctif déjà installé ; toute autre définition refuse la migration. La garde n'est pas un substitut à l'inspection du catalogue vivant. Même transaction : composants, matières, stock fabriqué, caisse, salaire, PA et reçu. Les modifications intermédiaires du JSON restent locales à la fonction avant validation et persistance. Les prix, rendements et PA métier ne changent pas.

**Dépendance impérative :** le moteur issu de `20261018234500_assemblage_electronique.sql` doit déjà être présent, puis le catalogue des dix articles doit être vérifié. Les fichiers hérités portent des horodatages futurs par rapport à leur rédaction constatée : **ne pas trier/appliquer aveuglément toute la liste**. Appliquer le correctif seulement après ces préconditions ; la garde refusera un état antérieur ou divergent. Aucune migration existante n'a été réécrite pour masquer ce problème.

Retour arrière : conserver la définition vivante avant déploiement. La migration ne réécrit pas de stock historique, ne multiplie pas les valeurs par 100 et n'arrondit pas les anciens soldes. Un retour fonctionnel doit bloquer l'assemblage concerné plutôt que réactiver le défaut connu. Ne jamais « annuler » des consommations réelles en appliquant des deltas inventés. Tester la migration sous transaction annulée puis appliquer suivant WORKFLOW-SUPABASE.md, relever les catalogues et vérifier les invariants.

### Interview : `migrations/20261018231849_jodie_interview_forum_atomique.sql`

Requiert `interviews_jodie` en RLS et sans policy d'écriture cliente. La fonction trigger n'est pas exécutable par PUBLIC/anon/authenticated. Elle n'effectue aucun rattrapage de joueur existant. Le texte journalistique enregistré est la source ; il est échappé pour le forum, pas généré de nouveau. Clés déterministes de topic/post, donc pas de doublon au rejeu. Une erreur forum fait échouer la sauvegarde de l'article, et l'API n'annonce plus un succès inexistant. Le Journal lit déjà `interviews_jodie` : pas de file supplémentaire pour ce parcours. Le trigger existant des portraits courrier est testé séparément.

Retour arrière : désactiver seulement le nouveau trigger après inspection de l'incident, conserver les articles et posts existants ; pas de suppression des contenus des joueurs. Le comportement d'erreur honnête de l'API doit rester actif. Tester au préalable les triggers/droits réellement présents, puis les deux parcours sur comptes autorisés.

## Minuit Paris

Le dépôt déclarait `0 23 * * *` le 19 octobre, alors que Paris est encore UTC+2 : cette déclaration correspond à 1 h locale. Le dépôt déclare désormais `0 22 * * *`. Le workflow quotidien déjà existant calcule l'offset Europe/Paris à chaque passage ; il corrige aussi une configuration périmée hors du seul jour de changement d'heure. Aucun commit si la configuration est déjà correcte ; pas d'invocation Vercel supplémentaire ni rattrapage de journée. L'autre cron est conservé. Les réglages réellement actifs chez Vercel restent à observer.

## Vérifications

- Messagerie/position : **9/9 tests** sur fonctions réelles et rendus.
- API/client Jodie : **10/10 tests**, dont utilisateur absent, autre propriétaire, panne, succès autorisé, persistence refusée et rejeu confirmé. Services externes simulés.
- PostgreSQL assemblage : **20/20 groupes**, dont dix recettes, catalogue réel, coût fractionnaire 5,50 FR, refus inchangés, rollback, concurrence et idempotence. Deux défauts historiques reproduits avant correction.
- PostgreSQL Jodie : **6/6 groupes**, vrais triggers sur tables jetables, deux circuits, texte, HTML, idempotence et rollback.
- Suite client complète et Chromium : résultat final consigné ci-dessous.
- Contre-épreuves : **90/90** ; calendrier : **5/5** ; syntaxe API : **23 modules** ; payload sous 330 Mo.
- Global : **10/12**, Authority et Referential rouges. Authority : 13 RPC absentes du baseline archivé. Referential : deux mesures périmées. Aucun baseline SQL généré ni empreinte observée n'est modifié.

Ces tests ne sont ni une authentification Supabase réelle, ni une visite de production, ni une preuve de disponibilité du commerce. Le PostgreSQL local utilise les fonctions/triggers SQL réels avec tables et services annexes de test.

## Déblocage Vercel et reprise précise

L'opération humaine éventuellement nécessaire concerne seulement **l'accès au projet** : un administrateur du compte Vercel doit autoriser l'identité technique dans l'équipe qui détient Res Publica et lui donner accès au projet/intégration GitHub. Le scope rapporté est `fred-s-projects25`. Il faut ensuite que l'agent puisse lire Settings → Git (dépôt `FredJ74/res-publica`, branche de production `main`) et Deployments. Ne pas partager les secrets dans le chat, ne pas changer de forfait, ne pas déléguer SQL ou déploiements manuels au game designer. Le proxy doit aussi permettre les API concernées ; l'autorisation de compte seule ne corrige pas un refus réseau.

Une fois cet accès disponible : observer le dernier déploiement et ses erreurs ; rétablir l'intégration autorisée si nécessaire ; déployer une seule fois le dernier SHA stable ; comparer SHA/ressources HTML, forum et scripts réellement servis ; exécuter les parcours authentifiés isolés.

Reprise serveur : lire le registre et les fonctions actuelles avant toute application ; conserver les avoirs et l'échéance d'Angie ; terminer les circuits atomiques avant d'ouvrir les achats/équipements collectifs. Les prochaines implémentations doivent établir le représentant habilité avec l'autorité existante, conserver le propriétaire `orga:` à travers paiement/livraison/inventaire, puis ajouter installation/transfert/journal sous un même verrou transactionnel. Les capacités d'un ordinateur et de ses périphériques doivent être une projection du matériel installé, pas des bonus locaux ou des copies consommables d'ordinateur. Raccorder ensuite les moteurs existants (renseignement, fret, documents et fabrication) ; aucun moteur parallèle ni mini-jeu.

Aucune migration appliquée par cette session. Aucun solde, placement, courrier d'Angie, stock ou équipement de joueur réel modifié.

Validation finale : **79/79 bancs client** ; Chromium séparé **9/9** (dont les trois scénarios d'infobulles conservés) ; calendrier **5/5** ; contre-épreuves **90/90** ; PostgreSQL assemblage **20/20**, publications **6/6**. Deux YAML modifiés analysés. Payload **315,2 Mo / 330 Mo**, marge **14,8 Mo**. Contrôle global **10/12**, deux échecs non masqués.
