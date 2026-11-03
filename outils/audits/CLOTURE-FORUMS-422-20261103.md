# Forums #422 — correction vérifiée localement, livraison bloquée

Branche existante `chatgpt/forums-territoires-et-adhesions-20261103` conservée.
Base réconciliée : main `4c657b53` (#410), fusion de travail `2a2ad0e4`.
Corrections : `92242533`, `0c03d2f6`. Aucune fusion ni migration de production.

## Changements

Les corrections initiales `332e64cf` et antérieures sont conservées. Le forum
national et les locaux sont filtrés par pays ; seul le local de la ville actuelle
est proposé. Les organisations du catalogue ne donnent plus un accès privé sans
adhésion ou direction. Les identifiants historiques restent compatibles avec les
publications officielles.

Les réponses de sujets, messages, compteurs et activité sont maintenant liées à
l'identité, la session, la position et l'adhésion. Les caches locaux sont renouvelés
à l'aller et au retour ; les caches privés et leurs voyants sont purgés lors d'une
perte d'accès. Une réponse vide confirmée ne conserve plus d'anciens messages. Le
délai de lecture est libéré et une ancienne requête ne déverrouille pas la suivante.

L'ouverture et les accès directs par l'interface relisent les organisations avec
le chargeur existant, en mode `lectureSeule`. Ce mode ne lance ni élections ni
ordre métier ; son fonctionnement normal reste testé et inchangé. Aucun nouveau
sondage périodique n'est ajouté.

La RLS couvre SELECT/INSERT/UPDATE/DELETE des sujets et réponses. La migration
refuse RLS inactive, politique permissive supplémentaire ou définition inconnue.
Une organisation malformée ferme son accès, sans panne globale. Les institutions,
la presse, l'international et le sport conservent leurs règles existantes.

## Compatibilité #410

La publication de #410 est SECURITY DEFINER : la RLS seule ne la contrôle pas.
La migration #422 adapte **uniquement ses autorisations** à la même fonction
canonique de lecture : chef, adhérent, territoire, accès direct au sujet. Chef
absent de la liste des membres et membres représentés par un nom simple restent
pris en charge, y compris une réponse privée depuis un autre pays.

La dépendance à `forum_publication_jauges_interne(text,uuid,jsonb)` est explicite.
Son corps examiné ou notre patch sont les seuls acceptés. Aucun ancien corps n'est
restauré. Le banc compare le bloc d'écriture/récompense au source de main : il
reste identique. **Aucune formule ou écriture POP/INF n'est modifiée.**

## Preuves

Voir `preuves-forums422-20261103/MANIFESTE.json` et les fichiers hachés.

- PostgreSQL natif 17.6 : **25/25** ; PostgreSQL16.2 : **25/25**.
- Tables, vue `personnages`, identité et politiques réelles du baseline, rôles
  authenticated/anon et JWT fictifs. Chaque scénario est annulé ; cluster détruit.
  Ce décor ne constitue pas une reconstruction du catalogue vivant.
- **17/17** cas de contexte client ; **19/19** cas territoriaux initiaux.
- Contrôleur complet après installation des dépendances de main : **187/187 bancs**.
  Une première passe sans PGlite avait quatre erreurs d'environnement ; elles ont
  été réparées par `npm ci`, sans modifier les bancs POP/INF de Claude.
- Chromium local complet : **119/119**, dont rendu réel du local et du forum privé.
  Aucune connexion à un personnage réel et aucun appel Supabase de production.
- Contre-épreuves : anciennes politiques permissives détectées ; ancien helper
  refusant le chef détecté ; ancien client réintroduisant des caches détecté.
- Les cinq jobs CI de la tête initiale `332e64cf` ont été observés terminés sans
  échec. La CI de la tête finale doit être relevée séparément, jamais déduite
  des résultats locaux ni de celle d'un ancien SHA.

## Échecs préexistants, non masqués

Contrôle global : **8/12**, aussi bien sur cette branche que sur main #410 isolé.
Baseline et Referential : miroir `ordres_couts` non régénéré/déclaration de source
périmée ; Authority : signature historique `couvre_feu_patrouille()` ; Fonctions :
ancien miroir client de succession supprimé et corps client d'indice modifié.
Aucune référence, observation ou empreinte n'a été ajustée pour masquer ces écarts.

Transversaux : **99/100** sur la branche ET main #410 isolé. Le contrôle
`test-organisations-ecritures-inventaire.mjs` attend encore
`sbGreveGeneraleSynchroniser(ggId)` dans `confirmerAppelGreveGenerale`, qui utilise
maintenant les commandes de grève serveur. Ce mécanisme de Claude n'est pas
réécrit par ce chantier. Les traces des deux exécutions sont conservées.

## Livraison restant impossible depuis cette session

Aucun outil Supabase `execute_sql`/`apply_migration` n'est exposé. Le prévol
historique de ChatGPT, annulé en transaction, n'est pas une certification de
l'état actuel. Aucun secret n'a été demandé ou extrait pour contourner ce manque.
La tentative HTTP publique Vercel est refusée par le proxy HTTPS (403). Aucun
statut READY ni fonctionnement authentifié en production n'a été observé.

La PR reste en brouillon. Ne pas la fusionner sur la seule foi de ses bancs verts.

## Ordre de reprise pour l'intégrateur disposant des accès

1. Exécuter via le canal technique le prévol en lecture seule
   `outils/bancs/PREFLIGHT-FORUMS-422-LECTURE-SEULE.sql`. Confirmer registre par NOM,
   dépendances #410, corps du helper, rôles/BYPASSRLS, politiques et déclencheurs.
   Une autre définition ou politique exige une relecture ; ne pas forcer le hash.
2. Vérifier le SHA courant, sa CI complète et les échecs transversaux hérités ;
   résoudre ceux qui bloquent la promotion, sans exemption ni suppression de test.
3. Après certification réelle, appliquer au registre la seule migration
   `20261103222000_forums_territoires_et_adhesions.sql`, sauf si elle est déjà
   enregistrée. Elle ne met à jour aucune ligne de PJ, organisation ou message.
   Prendre les définitions/politiques antérieures hors Git. Tout échec DDL doit
   annuler la transaction entière ; ne pas rouvrir les lectures publiques pour
   contourner une panne après déploiement.
4. Relever les catalogues, régénérer avec les outils existants le baseline et les
   seeds, contrôler le diff et les contrôles. Aucun SQL généré ne s'édite à la main.
5. Fusionner seulement après les garde-fous ; vérifier le SHA servi et Vercel READY.
   Recette authentifiée en consultation : aller/retour de ville, changement de
   pays, chef/adhérent/non-adhérent, accès direct sujets/réponses, voyants et comptes.
   Aucune modification de finances, caractéristiques, possessions ou identité PJ.

Aucune manipulation SQL ni commande n'est à déléguer au game designer.
