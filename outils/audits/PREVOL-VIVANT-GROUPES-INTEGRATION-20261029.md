# Prévol vivant (lecture seule) — intégration groupes

Résultat constaté dans Supabase `jxpwoosmmhohoihxpbuc` :

- `rue_position_enregistrer(p_noeud text)` existe réellement. Il verrouille la fiche PJ (`FOR UPDATE`), contrôle l'emprisonnement et l'interception, vérifie les nœuds et la sortie, puis écrit `personnages_donnees.current_street`. **Il ne déplace qu'un seul PJ**, sans prise en charge de groupe : ne pas le réemployer par itération pour un groupe, car cela casserait l'atomicité.
- `pnj_miroir_police(p_pays,p_ville,p_batiment)` existe. Sa version active lit `effectifsPolice.policiers` dans `batiments_etat` et réécrit directement `pnj_membres.ville`, `building_id`, `room_id`, `rue_noeud_id` par `ON CONFLICT DO UPDATE`. C'est une **seconde autorité de position** ; ne pas déployer les déplacements collectifs de policiers tant que cette projection n'est pas corrigée et testée en concurrence.
- `militaire_bataille_recruter`, `militaire_bataille_combattants`, `militaire_bataille_poursuivre`, `militaire_blob_projeter` existent. Aucune preuve d'un raccordement au moteur de combattants mixtes n'est fournie par ce prévol.
- `groupe_pj_lire` était absent de l'inventaire des fonctions consultées : cela confirme que les migrations groupes ne sont **pas** installées en production et ne doivent pas être activées sans prévol ACL/RLS et tests complets.

**Blocages réels de déploiement** : remplacement transactionnel des écrivains de position concurrents, raccordement des interceptions/combat mixtes à la détection existante, tests SQL combinés et essai authentifié. Tous les six workflows généraux de la PR #230 étaient verts sur `2cf0d696`, mais cela ne valide pas ces critères métier.

**Aucun SQL de mutation exécuté.**
