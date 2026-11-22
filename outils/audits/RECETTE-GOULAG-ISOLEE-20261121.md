# Proposition : recette du goulag sans ouvrir la production

## Solution proposée

Une **instance Supabase locale dans Docker**, sur le workspace de recette, et une copie locale du client du jeu. Aucun projet Supabase cloud supplémentaire, aucune nouvelle ressource payante à créer. Aucun joueur ni compte réel à copier.

Prévol réalisé : daemon Docker **29.9.2** disponible, **3 CPU et environ 10 Go de mémoire** annoncés. Aucun conteneur de recette n'a été démarré. L'espace disque utilisable, les images épinglées, les extensions et la locale restent à valider avant lancement. L'outil Supabase CLI doit être installé dans un profil d'outillage inscriptible ; une tentative de lecture de son aide 3.2.0 échoue sur le répertoire utilisateur en lecture seule, sans changement de production. Une exécution dans un conteneur d'outillage isolé évite de toucher au profil de l'utilisateur.

| Élément | Cible de recette proposée |
| --- | --- |
| Base | PostgreSQL 17.6 local, structure issue des exports canoniques |
| Authentification | Auth locale, clefs et jetons propres à cette instance |
| API | PostgREST local, schéma et droits effectivement vérifiés |
| Interface | Copie du client, servie uniquement sur localhost |
| Adresses prévues | client `http://127.0.0.1:8081`, API `http://127.0.0.1:54321` |
| Services | Stack minimale base/Auth/API ; aucun service IA ou e-mail externe |
| Coût Supabase additionnel | Aucun projet cloud ; aucune souscription supplémentaire |

Ces adresses sont une proposition, **pas des services déjà disponibles**. Fred utilisera le navigateur partagé de la machine de recette ; ces URL ne désignent pas la production ni le localhost de son téléphone.

## Cloisonnement à mettre en place par l'agent

1. Reconstruire la structure depuis les captures officielles, sans données PJ ; vérifier les dépendances, rôles, extensions, droits et locale sur cette copie. La dette du classement global du baseline est documentée dans l'audit d'installation : une copie reconstruite n'est pas annoncée certifiée avant les contrôles.
2. Alimenter uniquement les références nécessaires (lieux, objets, tarifs) et des données fictives. Ne copier ni `auth.users`, ni inventaires, ni courriers, ni secrets, ni historiques réels.
3. Dans une copie de fichiers hors dépôt, remplacer les constantes de connexion actuellement fixes de `supabase.js` par l'URL et la clef **locales**. Vérifier toutes les destinations réseau ; aucune modification de la configuration du site public.
4. Utiliser un navigateur de recette qui **bloque les requêtes vers le projet de production**, les fonctions Vercel publiques, les services IA et tout autre domaine non autorisé. Le test doit échouer si une URL ou une clef de production subsiste. Les bibliothèques publiques nécessaires seront servies localement.
5. Après vérification explicite de la cible locale, lever le verrou et ouvrir le goulag **dans cette copie uniquement**. Le CHECK et `active=false` de production restent inchangés. Aucun mode secret ou exception par PJ n'est ajouté à la production.
6. Neutraliser les tâches nocturnes réelles sur la copie ; l'agent exécutera les étapes de contrôle de minuit et les simulations multi-jours dans ce seul décor. Journaliser les commandes de recette et leur résultat.

Les étapes 1 à 6 restent à réaliser. Le premier feu vert n'est pas transformé en autorisation d'ouvrir la production ; aucun accès réservé à un compte test n'y est fabriqué.

## Comptes fictifs proposés

| Compte | Usage |
| --- | --- |
| Juge Recette | Juge compétent de Sovarka ; décisions judiciaires |
| Ministre Recette | Ministre de la Justice ; autorisations de visite seulement |
| Détenu Recette | Personnage à condamner ; inventaire témoin avec clés et objets ordinaires |
| Visiteur Recette | Demande de visite, transports et retour |
| Témoin Recette | Personnage non habilité, contre-épreuves de refus |

Comptes Auth créés et confirmés **localement**, adresses fictives sous `.invalid`, aucun envoi d'e-mail. Mots de passe aléatoires transmis uniquement dans l'espace privé de recette, jamais dans Git. Des profils de navigateur séparés permettent de passer d'un rôle à l'autre sans confondre leurs sessions.

## Parcours proposé à Fred

1. **Condamnation** : avec Juge Recette, ouvrir une affaire fictive et prononcer l'envoi ; avec Ministre Recette ou Témoin Recette, vérifier le refus de condamner.
2. **Laissez-passer et transfert** : demander puis accorder l'autorisation de visite ; voyager depuis chacun des centres multimodaux ; vérifier le refus du transport de retour pour un détenu. Tester révocation et réutilisation du droit du visiteur.
3. **Arrivée et inventaire** : vérifier le vrai lieu, le dépôt des objets et la conservation des clés. À la libération, vérifier la restitution unique ; en cas d'évasion, la perte du dépôt.
4. **Ordres sur place** : liste, registre, dortoir, cachot et mirador ; interrogatoire et sanction à 1 PA ; corruption et tentative d'évasion. Vérifier les refus avant tout paiement.
5. **Parcours longs** : l'agent préparera des états fictifs et les passages de jours pour les itinéraires Starovka/Krasnov, l'arrivée à 1 PA, le bois 5 puis 3 et les trois jours de récupération. Aucune accélération d'horloge de production.
6. **Affichage et état** : neuf langues, arabe RTL, 320/390/1280 px, changement de langue, saisie conservée et double clic. Un téléphone physique restera une vérification distincte.

## Critères avant présentation à Fred

- Authentification et RPC réellement locales, pas seulement simulées.
- Aucun accès réseau à la production dans les traces.
- Comptes fictifs et droits vérifiés ; données réinitialisables.
- Recettes PostgreSQL moteur/ordres/raccords/contrats et tests navigateur passants sur cette instance.
- URL du navigateur partagé, identifiants privés et scénario de test prêts.

**État à cette livraison : proposition préparée ; environnement interactif non créé, aucun PJ connecté testé, aucune facture Supabase nouvelle, activation de production toujours interdite.**
