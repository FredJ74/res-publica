# Tranche du 13 octobre 2026 — Tribunal, greffe, Université : ce qui reste à décider

**Ni le Tribunal ni l'Université ne sont déclarés clos ici** : le cahier des charges de la tranche
l'interdit explicitement, et cette page existe pour que la décision reste entière.

Registre Supabase **705 → 712**, sept migrations, toutes archivées byte-exact. Ce qui a été
livré est décrit dans `baseline/CONTROLE-GLOBAL.json`, section
`_chantier_greffe_et_universite`. Ce document ne liste que **les décisions non prises**.

---

## 1. Extrait officiel de domiciliation — ARBITRAGE VALIDÉ LE 13 OCTOBRE 2026

**Décision de game design :** toutes les organisations, sans exception de catégorie, reçoivent à leur constitution **un extrait officiel unique de domiciliation**. L'original est remis dans l'inventaire du fondateur. Le document atteste la constitution et la domiciliation, sans conférer de fonction dirigeante à son détenteur.

**Duplicata :** seul le **président ou le trésorier** de l'organisation peut demander un double, **au greffe du tribunal de la ville de domiciliation**, pour **75 FR et 1 PA**. Le duplicata reproduit un original existant, il ne constitue pas une nouvelle organisation et ne modifie pas sa domiciliation.

**Écart avec l'existant :** la porte actuelle `syndicat_etudiant_domicilier` émet déjà un extrait original, mais la règle n'est pas générale. La porte `organisation_extrait_duplicata` autorise actuellement le président **ou le secrétaire** : remplacer le secrétaire par le **trésorier**. Les organisations créées par l'ancien chemin client n'ont pas forcément de dirigeants normalisés ni d'extrait original. Il faut auditer les voies de constitution et prévoir un traitement cohérent des organisations préexistantes sans fabriquer silencieusement de faux originaux.

**Statut technique :** arbitrage enregistré ; implémentation transversale et vérifications restent à faire. Ne pas déclarer le chantier clos.

## 2. Greffiers nommés dans les trois tribunaux — ARBITRAGE VALIDÉ

**Décision :** chaque tribunal de Républia doit avoir son **propre greffier PNJ nommé** : Luthécia (Greffier Petit, existant), Port-Sainte-Marie (**Greffier Leroux**) et Montrouge (**Greffier Richard**). Le greffier n'est **jamais un poste accessible aux PJ** ; conserver la contrainte `postes_attribues_jamais_greffier`.

**État actuel :** `greffes_tribunaux` possède trois lignes, mais les deux greffes locaux ont `greffier_pnj = NULL` et utilisent la signature générique du greffe. Les noms ont été choisis par le game designer et inscrits dans `greffes_tribunaux` en production ; aucune nouvelle image n'a été générée. La présence physique de ces personnages dans les salles reste à contrôler.

**Statut technique :** casting validé et signatures des greffes mises à jour dans Supabase ; intégration visuelle des PNJ non vérifiée.

## 3. Énigme du Musée — passage au greffe du Tribunal (CONFIRMÉ)

L'énigme du Musée de Luthécia (portraits disparus, parcelle B-127, succession Pierre Thibault, coffre bancaire, clé du débarras, Gérard Poinçon) **est conservée intégralement** : sept indices, conditions, progression et révélation inchangés.

Le passage judiciaire se fait déjà par l'ordre **« Demander à parler au juge » au greffe**, relié à `doDemanderJugeInstruction` dans `plateau-enigme-portrait.js`. Il vérifie les archives et les témoignages puis, si le dossier est complet, le juge Honoré Cozetoujours autorise l'ouverture du coffre. **Aucun nouveau bouton ni déplacement de l'action**.

L'identité de Fontaine a été remplacée par Honoré Cozetoujours ; les trois répliques sont encore les formulations originales. Leur réécriture stylistique reste facultative et n'est pas arbitrée. Ne pas les modifier sans nouvelle décision explicite.

## 4. Un bouton trompeur par homonymie, hors des deux périmètres

Le **Quartier des Troupes de la Caserne** déclare l'ordre `fn:'recruter_etud'` sous le libellé
**« Recruter pour un groupe »**, description « Constituer une milice ou un groupe armé ».

C'est **le même identifiant** que « Recruter des militants » de l'Université. Depuis que la porte
serveur des militants exige une adhésion syndicale, **cliquer ce bouton à la Caserne exécute le
recrutement de militants et refuse avec « Adhésion requise »**.

**Ni corrigé ni touché** : la Caserne n'est ni le Tribunal ni l'Université, et le cahier des
charges dit de ne pas ouvrir d'autre chantier. La décision attendue est simple à formuler et
n'est pas la nôtre : soit l'ordre de la Caserne est **supprimé** (il n'a jamais eu de mécanique
propre), soit il reçoit **son propre identifiant** et sa propre porte.

## 5. La seconde carrière : le bouton est visible, la mécanique n'existe pas

« Suivre une formation » **existe et se voit** dans l'amphithéâtre, **désactivé pour de vrai** par
trois verrous indépendants : le drapeau générique `bientot` (clic inerte, un toast et rien
d'autre), **aucune route** dans `plateau-router.js`, et **absence du miroir des coûts** — ce qui
ferait refuser `ordre_inconnu` même à un appel forcé. Son infobulle dit mot pour mot ce que
l'arbitrage demande.

**Ce qui manque n'est pas du code, c'est un catalogue.** `universite_cursus` compte **zéro
ligne** : le socle des cursus existe depuis le 12 octobre, et il est **vide exprès**. Tant
qu'aucun cursus n'est écrit, `universite_inscrire` ne peut que répondre `cursus_inconnu`. Les
cursus, leurs durées, leurs jalons et les carrières qu'ils délivrent sont un arbitrage de game
design, et **la tranche n'en a inventé aucun**.

## 6. Les arbitrages explicitement non rouverts

Trois points sont **déjà arbitrés** et ont été laissés intacts, pour mémoire :

* **`justification_rejetee` garde son dé.** Le Commissaire PJ ne remplace pas le jet par son
  appréciation. L'infraction reste **sans catégorie**, et une contrainte de base interdit qu'elle
  hérite d'un barème.
* **« Donner une conférence » est conservée mot pour mot** — même coût, même taux, même
  description, même type : un banc le mesure caractère par caractère.
* **La catégorie `delit` reste la catégorie**, et aucun barème n'a bougé. Le détail factuel des
  sept `delit` et des six `delit_grave` est dans
  `baseline/arbitrages/AUDIT-CORRUPTION-ET-FONDS-PUBLICS.md`.

## 7. Renvois

* Corruption, détournement de fonds publics, emplois fictifs :
  `AUDIT-CORRUPTION-ET-FONDS-PUBLICS.md` — **deux infractions sur trois n'existent pas**.
* Types de journal non judiciaires : `AUDIT-TYPES-DE-JOURNAL-NON-JUDICIAIRES.md` — **onze types
  restent écrits par le navigateur**, dette chiffrée et nommée.
* Divergence à trois valeurs du miroir `ordres_couts` : inchangée, lot 4D
  (`outils/baseline/referentiels.json`).
