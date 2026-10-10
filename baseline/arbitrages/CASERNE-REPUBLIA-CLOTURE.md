# La Caserne de Républia — arbitrages rendus et clôture

> **10 octobre 2026.** L'audit de consolidation a été rendu, les arbitrages de
> game design ont suivi, et le bâtiment est fermé. Registre Supabase **636 → 637**.
>
> **Les 11 contrôles sont verts, les 13 invariants d'autorité tiennent**, 30 bancs
> JavaScript et 1 banc SQL passent.

## 1. La règle qui fait foi

```
Ministre de la Défense  →  Commandant  →  Capitaine  →  Lieutenant  →  Soldat
```

**Il n'existe aucun poste de Général**, et le mot ne doit plus suggérer un
échelon. C'était le cœur de l'audit : le serveur ne connaissait déjà que ces cinq
niveaux — zéro occurrence de `'general'` comme poste dans les onze domaines SQL —
mais le joueur, lui, voyait dans la Salle de Commandement un « Général Faure,
Chef d'état-major » sans aucun pouvoir, tandis que l'autorité militaire réelle
appartenait à un PNJ invisible.

| Fonction | Ce qu'elle fait, et c'est vérifié au serveur |
|---|---|
| **Ministre de la Défense** | autorité politique ; **alimente** la caserne ; mobilisation et réquisition |
| **Commandant** | chef militaire de la caserne ; crée les compagnies ; recrute les Capitaines ; **engage** la caisse et peut la **reverser** au ministère |
| **Capitaine** | commande sa compagnie ; nomme et démet les Lieutenants de **sa** compagnie |
| **Lieutenant** | commande sa section ; recrute ses soldats ; seule autorité structurelle sur un soldat |
| **Soldat** | dernier niveau de la chaîne |

## 2. Les six écarts corrigés

### 2.1 Le chef visible n'était pas le chef

Le titulaire du poste `commandant` était **« Commandant Tom Hawak »**, inscrit
dans `titulaires_pnj` depuis le 10 août 2026 et porteur de toute l'autorité — mais
il n'existait **que** comme chaîne de caractères dans `api/cron-minuit.js` : aucune
fiche dans `data.js`, aucun profil, aucune voix, invisible dans la pièce.

Faure est retiré. Tom Hawak prend sa place, avec un corps, un portrait généré par
le système existant, un profil de dialogue et une mémoire pédagogique.

**Deux états, une seule personne.** Le titre est **recalculé à l'entrée** dans la
pièce, depuis le registre serveur et jamais depuis `state.poste` :

- poste tenu par le PNJ → *« Commandant de la Caserne »* ;
- poste pris par un joueur → *« Commandant adjoint »*, **et il ne disparaît pas**.

« Commandant adjoint » **n'est pas un poste** : ni candidatable, ni nommable, ni
connu du serveur. Aucune prérogative n'y est attachée — l'autorité suit le poste
`commandant`, et lui seul. Il n'y a jamais deux Commandants dans la pièce.

> **La mécanique a été généralisée au lieu d'être recopiée.** Elle ne connaissait
> que le ministère de la Défense, avec ses deux libellés écrits en dur dans
> `plateau-navigation.js`. Les libellés appartiennent désormais au PNJ, dans
> `data.js` (`roleSiPnjTitulaire` / `roleSiPjTitulaire`), et la règle vaut pour
> tout PNJ futur porteur d'un poste. Martial Bouterin garde ses deux libellés au
> caractère près : ils ont seulement déménagé.

Le métier technique `general` de `PNJ_STATS_PAR_JOB` **n'est pas supprimé** : il
sert de famille d'avatar et peut servir de casting ailleurs. C'est l'échelon
fantôme qui disparaît, pas le mot.

### 2.2 Le ministre puisait dans la caisse de la caserne

`caisses_autorites` accordait le débit à `{commandant, min_def}`. La règle
arbitrée : **le ministre alimente, le Commandant dépense.**

Trois flux, un interdit :

| | |
|---|---|
| Ministère → Caserne | part nocturne du budget, ou virement ponctuel ; **inchangé** |
| Caserne → dépenses | décidées par le Commandant, à la caserne |
| Caserne → Ministère | **nouveau** : `caserne_reverser_au_ministere`, décidé par le Commandant |
| Ministre → caisse de la caserne | **refusé au serveur**, pas seulement dans l'écran |

Mesure préalable avant de retirer `min_def` : le **seul** débit client de cette
caisse était la recherche d'armement, déjà réservée au Commandant. Retirer
`min_def` ne fermait donc aucun chemin légitime — il fermait la console.

Le reversement n'est **pas plafonné** : un virement partiel sur une décision
volontaire serait une surprise. Solde insuffisant = refus, et **rien n'est écrit**
— le banc le vérifie en comparant les deux soldes avant et après un refus.

### 2.3 L'ordre de bataille était public

`compagnies_lecture_mon_pays` ouvrait `compagnies_militaires` en `SELECT` à **tout
joueur authentifié du pays** : matricules, PA, armes, positions, missions, réserve,
contingent, trésorerie. La policy est supprimée **et** le `SELECT` révoqué.

> **Une policy et son `GRANT` tombent ensemble.** Retirer la policy sans révoquer
> le droit laisserait la table ouverte le jour où une policy permissive
> reviendrait, et personne ne chercherait la cause dans un `GRANT` oublié.

**La porte projette, elle ne filtre pas** — et c'est la décision de conception
importante de ce lot. Fermer la table à un civil aurait aussi supprimé sa capacité
à voir qu'un détachement tient une pièce : une observation légitime du monde, et
le déclencheur des missions d'entrée.

| Qui | Ce qu'il reçoit |
|---|---|
| ministre de la Défense, Commandant | toutes les compagnies du pays, **blob entier** |
| Capitaine, Lieutenant, soldat joueur | **la leur**, blob entier |
| tout le reste | **présence seule** : qui mène, où, combien, quelle consigne |

Ni matricule, ni PA, ni arme, ni réserve, ni contingent, ni trésorerie, ni stock.

**Les trente-trois sites d'appel du navigateur n'ont pas bougé d'une ligne** : la
porte rend la même forme `(id, data)` que le `SELECT` qu'elle remplace, et c'est
`sbGetCompagnies` — l'unique point de lecture — qui a changé de chemin.

### 2.4 L'inspection des troupes n'était gardée qu'en JavaScript

`accesInspectionTroupes()` testait `state.poste?.id` : la console donnait l'écran,
les points d'influence et la lecture de l'armée.

Règle arbitrée : **la chaîne inspecte à partir du Lieutenant** — Lieutenant,
Capitaine, Commandant, ministre de la Défense. Le soldat, non. Un civil, non.
Chacun dans son périmètre : sa section, sa compagnie, l'armée.

Le verdict **et** le périmètre viennent de `militaire_inspection_perimetre`, qui
relit le poste en base. Le refus est **nommé par le serveur**, jamais devisé par
l'interface : un message qui prétendrait connaître la raison finirait par mentir.

### 2.5 La Salle de Commandement se disait réservée au ministre

`requiresPostId: 'min_def'` était une métadonnée **inerte** — aucun code ne la lit
— et elle disait le contraire de ce que fait la pièce : 9 de ses 15 ordres
appartiennent au Lieutenant ou au Commandant. Le champ est retiré avec
l'ambiguïté. **Aucun droit fonctionnel n'a changé** : ce sont les `requiresPost`
portés par chaque ordre, doublés des gardes serveur, qui restreignent réellement.

### 2.6 Un commentaire affirmait que le Commandant n'avait aucune prérogative

Celui de `POSTES_UNIQUES_A_MASQUER` : « *aucune prérogative de jeu n'est encore
codée sur ces postes* ». Faux depuis septembre. Il reste pourtant **exclu de la
liste de masquage**, et pour une raison neuve : Tom Hawak porte
`resteApresPourvoi` et **doit** rester visible quand un joueur occupe le poste.

## 3. Ce qui n'a PAS été touché, et pourquoi

**La compagnie sans Capitaine est un état normal du game design.** Une compagnie
naît, existe immédiatement, et le Commandant recrute *ensuite* son Capitaine : il
y a donc toujours une période sans. Et si une compagnie perd son Capitaine, elle
continue d'exister — sections, Lieutenants et soldats en place, aucun
démantèlement, aucune cascade. Le prochain Capitaine la reprend dans son état.

État mesuré en base, inchangé par ce lot : **une compagnie, aucun capitaine,
4 sections, la section 1 tenue par Vince Kubrick avec 24 soldats, 72 hommes en
réserve sur un contingent de 96.** Rien n'a été créé, déplacé ni réparé.

**Le combat reste hors périmètre**, conformément à l'arbitrage du 17 septembre.

## 4. Les preuves

| Banc | Épreuves | Ce qu'il établit |
|---|---|---|
| `outils/bancs/banc-caserne-autorites.sql` | **24** | en transaction annulée, avec décor et identités impersonnées : qui peut débiter, qui peut reverser, qu'un refus n'écrit rien, les six verdicts d'inspection, et la projection de l'ordre de bataille. **Contre-épreuve comprise** : le `GRANT` rendu, le civil relit tout — c'est donc bien la révocation qui ferme |
| `outils/bancs/banc-titre-pnj-de-poste.js` | **28** | le titre bascule dans les deux sens, le PNJ ne disparaît jamais, il n'y a jamais deux Commandants, une pièce sans PNJ de poste n'interroge pas le registre, et un registre muet laisse le titre plein |
| `outils/bancs/banc-referent-commandant.js` | **20** | son profil est servi par la même voie que les autres référents, son corpus couvre réellement la chaîne, et « Général Faure » n'a plus de profil |
| `outils/bancs/banc-ordre-de-bataille-client.js` | **9** | les écrans passent par la porte, jamais par la table, et la forme de sortie n'a pas bougé |
| les 30 bancs JavaScript existants | — | aucune régression : candidatures, compagnie, nominations, terminal, armurerie, soldes |

Deux contre-épreuves de code ont été jouées puis défaites : sans les libellés
déclarés, 7 des 28 épreuves du titre rougissent ; sans la garde de nature,
9 des 20 épreuves de l'archive d'urbanisme rougissent.

## 5. Ce qui reste, nommé

1. **Le contrôle visuel est dû** : l'écran de la caisse de la caserne, le portrait
   généré de Tom Hawak, et son titre dans les deux états. Aucun navigateur dans la
   session.
2. **Son dialogue n'a jamais été exercé en vrai** : le corpus est vérifié par un
   banc, la conversation non.
3. **Interblocage théorique** entre `caserne_reverser_au_ministere` et
   `caisse_ministere_mouvement`, qui verrouillent la même paire de caisses dans
   des ordres opposés. PostgreSQL l'arbitre en annulant une transaction entière —
   donc sans écriture partielle ni argent perdu. Nommé dans l'en-tête de la
   fonction plutôt que caché.
4. **Le jet de la défense d'une plainte** reste au navigateur (`bonusFormation`
   n'est persisté nulle part) : hors périmètre, déjà consigné.
