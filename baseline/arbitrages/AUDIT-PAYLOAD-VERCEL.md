# Audit du payload Vercel — ce qu'un déploiement transporte vraiment

> **Mesures du 8 octobre 2026**, dépôt au commit `d3c3f05`. Aucun accès à
> Supabase pendant ce chantier (base en redimensionnement Nano → Micro) : les
> références en base citées ici viennent du relevé déjà au dépôt,
> `.scratch/references_base_de_donnees.txt`, pas d'une requête du jour.
>
> Les chiffres sont produits par `outils/payload-vercel.py`, qui simule la règle
> d'inclusion de Vercel — **fichiers suivis par git, moins `.vercelignore`**. Ce
> n'est pas `du -sh .`, qui se trompe dans les deux sens : il compte les fichiers
> non suivis et ignore les exclusions.

---

## 1. Le poids, avant et après

| | Payload | Fichiers |
|---|---|---|
| Avant | **400,2 Mo** | 773 |
| Après | **310,0 Mo** | 734 |
| Écart | **−90,2 Mo (−22,5 %)** | −39 |

Le dépôt suivi pèse, lui, environ **505 Mo** : la différence est l'outillage, les
migrations, les archives et `.scratch/` — 302 fichiers et 86,3 Mo versionnés
exprès, écartés du déploiement et non de l'histoire.

**Après réduction, `images/` fait 302,5 Mo, soit 97,6 % du payload.** Tout le
reste additionné pèse 7,5 Mo. Aucune optimisation hors des images ne peut donc
plus déplacer le chiffre de façon sensible — c'est le fait le plus important de
cet audit.

## 2. D'où venaient les 90 Mo

| Retiré | Poids | Ce qui le prouve |
|---|---|---|
| `audio/` | **89,8 Mo** | les 29 MP3 sont référencés dans `data.js` par une URL **absolue** vers `raw.githubusercontent.com` — 29 sur 29 vérifiés, et **aucune** référence relative à `audio/` dans tout le code servi. `vercel.json` porte un en-tête de cache pour `/images/`, aucun pour `/audio/` |
| `*.md` | 247 Ko | aucune page servie ne charge de `.md` ; les 4 pages HTML du payload chargent 54 ressources énumérées, dont aucune |
| `prototype-*.html` | 49 Ko | se déclarent « PROTOTYPE JETABLE » dans leur propre `<title>`, avec `robots: noindex` ; cités seulement dans un commentaire |
| 2 bancs football | 56 Ko | utilisent `require(` et `process.` : incapables de tourner dans un navigateur |

**La cause racine était une phrase.** Le prologue de `.vercelignore` listait
`audio/` parmi « ce qui part toujours, et qu'il ne faut pas exclure ». Elle était
fausse, et personne ne l'avait rouverte. C'est corrigé, daté, et la condition qui
rendrait l'exclusion invalide est écrite à côté d'elle : un `audioUrl` sans le
préfixe GitHub dans `data.js`.

## 3. Classification des assets

| Classe | Quoi | Nombre | Verdict |
|---|---|---|---|
| **A** — référence relative explicite | images chargées par un chemin écrit dans le code | 605 | gardées |
| **B** — citées en base | portraits de joueurs, escorts, camions militaires | 30 | gardées, **et intouchables en nom** |
| **C** — sans référence constatée | images dont ni grep ni base ne porte le nom | 21 | **gardées quand même** |
| **D** — servies par GitHub | les 29 MP3 | 29 | écartées du payload, **conservées dans git** : c'est là que les URL pointent |
| **E** — non chargé, gardé exprès | `plateau-alimentaire.js` (25,9 Ko), `i18n/i18next.LICENSE.txt` (1,1 Ko) | 2 | gardés — motifs au § 4 |
| **F** — exclu | documentation, prototypes, bancs, outillage, migrations, archives | — | hors payload |

**La classe C n'autorise aucune suppression.** Le dépôt construit des chemins
d'image par concaténation d'identifiant, de ville et de bâtiment : l'absence de
grep direct n'a jamais prouvé qu'un asset était inutile. Les 21 pèsent une
fraction du total et le risque est une image manquante en jeu.

**Zéro doublon binaire exact. Zéro asset présent sous deux formats du même
radical.** Les deux pistes de déduplication sont donc fermées, par mesure.

## 4. Les deux conservations délibérées

`plateau-alimentaire.js` — mesuré : aucune page ne le charge, aucune de ses 24
fonctions n'est appelée ailleurs, son nom n'est cité nulle part. **Il reste.** Un
`.js` à la racine est indiscernable des cinquante autres qui *sont* chargés :
l'exclure par son nom poserait un piège pour le jour où un `<script src>`
l'ajoutera — une 404 au lieu d'un module. 0,006 % du payload ne vaut pas ça.

`i18n/i18next.LICENSE.txt` — jamais chargé, et il reste : c'est la licence d'une
bibliothèque tierce distribuée à côté de son code minifié. L'économie serait d'un
kilo-octet, le manquement serait juridique.

## 5. Les PNG — un gain mesuré, et architecturalement bloqué

**54 PNG, 90,3 Mo. Conversion WebP mesurée : 75,9 Mo d'économie, soit 84 %.**
C'est le deuxième gain du dépôt par la taille, et il n'est **pas** accessible :

- **53 des 54 sont cités dans la base** (`.scratch/references_base_de_donnees.txt`).
  Convertir change l'extension, donc le nom, donc rompt la référence. La base
  porte des noms de fichiers d'image, et c'est cela qui bloque — pas le format ;
- **le 54ᵉ est `images/plan-palais-presidentiel-luthecia.png`**, explicitement
  interdit de modification.

> **DÉCISION NON PRISE — elle n'est pas technique.** Récupérer ces 75,9 Mo exige
> de changer la façon dont la base désigne une image : stocker un **identifiant**
> et laisser le code résoudre l'extension, au lieu de stocker un nom de fichier.
> C'est un chantier de modèle de données, pas une conversion d'images, et il
> touche un asset visible. Non entamé, consigné ici. Voir la mémoire
> `conversion_webp_outil` et `images_livraison_cache_immutable` — remplacer une
> image exige déjà aujourd'hui de changer son nom.

## 6. Les déploiements — ce qui est établi localement, et ce qui ne l'est pas

Établi par lecture du dépôt :

- **152 commits en 14 jours**, soit environ **11 déploiements par jour** si
  chaque push sur `main` en déclenche un ;
- `vercel.json` ne porte **ni `git`, ni `ignoreCommand`, ni `buildCommand`** :
  rien ne filtre les déclenchements, rien ne construit — le déploiement est une
  copie de fichiers ;
- **une seule branche** existe sur le distant (`origin/main`) : il n'y a plus de
  déploiements de prévisualisation parasites ;
- le seul workflow planifié (`ajuster-heure-cron.yml`) ne commite que **deux fois
  par an**, aux changements d'heure. Il n'est pas une source de déploiements.

Le stockage de déploiement de Vercel est **multiplicatif** — déploiements ×
taille de sortie × rétention — sans déduplication documentée. L'ordre de grandeur
est donc ~11/jour × 310 Mo × 7 jours ≈ **24 Go**, et c'est là, et non dans le
poids unitaire, que se trouve le reste du problème.

> **À VÉRIFIER DANS VERCEL — non accessible localement.** Le quota de Deployment
> Storage du plan Hobby, la rétention réellement appliquée, et la disponibilité
> de l'« Ignored Build Step » sur ce plan. Aucune de ces trois informations n'est
> dans le dépôt, et aucune ne doit être devinée.

## 7. Ce qui empêche la rechute

Trois garde-fous, et ils se complètent :

1. **`outils/payload-vercel.py --garde`** compare le payload au plafond
   **déclaré** dans `payload-vercel.json` — 330 Mo, soit 20 Mo de marge. Il
   **refuse de tourner** si ce fichier manque : un plafond déduit de la mesure du
   jour validerait toujours l'état présent. Les quatre épreuves de la garde
   passent — elle crie sur un dépassement, sur un gros fichier neuf non déclaré,
   sur un doublon binaire, et se tait sinon.
2. **`.github/workflows/garde-payload-vercel.yml`** la lance à chaque push sur
   `main`. **C'est une alarme, pas un verrou** : Actions et Vercel sont
   indépendants, et son échec n'arrête aucun déploiement.
3. **`.gitignore`**, le premier du dépôt. Aucun de ses motifs ne recouvre un
   fichier déjà suivi — vérifié par `git ls-files | git check-ignore --stdin`, et
   c'est ce qui a fait écarter `*.log`, qui aurait masqué une mesure archivée.

## 8. Ce que ce chantier n'a pas fait, exprès

Aucune image convertie. Aucun fichier audio déplacé. Aucun asset supprimé. Aucun
fichier de jeu modifié — ni `.js`, ni `.html`, ni `.css`, ni `.sql`. Aucune
migration. Aucun contact avec Supabase.

Les dix contrôles du baseline sont verts, et
`images/plan-palais-presidentiel-luthecia.png` porte toujours son empreinte
`0a9a5e279fb67149ae303f1c0a8e0da3`.
