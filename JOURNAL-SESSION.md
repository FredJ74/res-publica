# Journal de session — Res Publica

*Dernière mise à jour : 19 juillet 2026 (soir)*

**Usage** : au début de chaque nouvelle session avec Claude, faire `cat JOURNAL-SESSION.md` et coller le résultat dans le chat. Envoyer aussi directement en pièce jointe les fichiers cœur qu'on réutilise presque à chaque session : `data.js`, `plateau-core.js`, `plateau-personnage.js`, `plateau-pnj.js`, `plateau-multijoueur.js`, `plateau-router.js`, `plateau-actions-illegales-rumeurs.js`. Ça évite les allers-retours `sed`/`grep` répétés en début de session.

---

## 🔒 Points de restauration Git connus comme stables

- `base-saine-18juillet` — état d'avant la crise du 17-18 juillet.
- `avant-hotel-republica-suites` — juste avant le chantier suites/réservation de chambre du 19 juillet.
- `avant-diner-affaires` — juste avant le système d'invitations sociales.
- Le dépôt est à jour au soir du 19 juillet, `?v=11` dans `plateau.html`.

En cas de casse grave :
```bash
cd ~/ResPublica
git checkout <nom-du-tag> -- .
```

---

## ⚠️ Règles impératives (toujours valables)

1. **Noms de fichiers définitifs, jamais de suffixe `-vXX`.**
2. **Cache navigateur** géré par `?v=N` dans `plateau.html`. Toujours donner la commande `sed -i '' 's/?v=N/?v=N+1/g' plateau.html` complète — Fred ne code jamais, il ne fait que copier-coller des commandes déjà prêtes (terminal ou Supabase). Ne jamais lui dire d'« incrémenter » sans lui donner la commande.
3. **Avant de livrer un fichier reconstruit "de mémoire"**, toujours demander un `grep`/`wc -l` de vérification sur le fichier réel de Fred. Ne jamais reconstruire un fichier entier à partir de la mémoire de conversation.
4. **Pour un correctif**, toujours un script Python (`create_file` puis donné en copier-coller direct dans le chat via un bloc `cat > fichier.py << 'PYEOF' ... PYEOF`), jamais en téléchargement séparé. Le script doit être **testé par Claude lui-même** (bash_tool, sur une copie locale reconstituée à partir des fichiers déjà envoyés par Fred) avant d'être livré, avec vérification de l'unicité de l'ancre et de l'équilibre des accolades/crochets.
5. **`node` n'est pas installé** chez Fred — seul `grep -c` pour vérifier une modification.
6. **En cas de doute sur l'état d'un fichier**, faire confiance à Git plutôt qu'à la mémoire de conversation.
7. **Avant toute action destructive**, poser un tag Git de sécurité (`git tag nom && git push origin nom`).
8. **Chaque fichier ET chaque image livrés** doivent avoir un nom de sortie unique jamais réutilisé (suffixes `(1)` de Chrome), toujours avec la commande `mv` complète (source téléchargée → nom final dans le repo).
9. Si Claude a besoin d'un fichier qu'il n'a pas encore vu en entier, le demander **directement en pièce jointe** plutôt qu'en `sed`/`grep` répétés — c'est beaucoup plus rapide pour tout le monde.
10. Pour tester un correctif avant livraison, privilégier la reconstruction locale à partir des vrais fichiers déjà envoyés par Fred dans la conversation (copies successives), pas de fichiers de test inventés.

---

## 🗺️ Feuille de route (inchangée depuis le 18 juillet)

- **Fin juillet 2026** : terminer Luthécia.
- **1re quinzaine d'août** : Port-Sainte-Marie et Montrouge.
- **2e quinzaine d'août** : déploiement de la base commune vers les 3 autres empires.
- **Fin août / début septembre** : spécificités par empire.
- **Fin septembre 2026** : objectif bêta fermée.

---

## 🏛️ Tour des bâtiments de Luthécia — état exact

**Entièrement audités et fonctionnels** : Mairie, Assemblée Nationale, Tribunal, Université, Quartier des Ambassades, Centre d'Affaires, Centre Commercial, Centre Artisanal, Dispensaire Public, **Hôtel-Restaurant La Républica (Accueil, Restaurant, Bar — voir détail ci-dessous)**.

**Prochain bâtiment à auditer** : **Commissariat** (Fred suit l'ordre de la rue, toujours en attente depuis plusieurs sessions).

**Encore à faire** : Palais Présidentiel, Hôtel Republica *(déjà fait, à retirer de cette liste dans la prochaine version du fichier — erreur de ma part si encore présent)*, Palais du Gouvernement, Banque Nationale, Banque Privée, Clinique Privée, La Tribune, Loge Maçonnique, Armurerie, Marché, Tabernacle des Impôts, Centre Multimodal, Office Notarial, Stade, Place du Formulaire de la Liberté.

---

## 🍽️🍸 GROS CHANTIER DU 19 JUILLET — Audit complet de l'Hôtel-Restaurant La Républica

### Accueil
- **Réservation de chambre** (`reserver_chambre_hotel`) : corrigée, bonus +2 PA/+3 Moral au prochain Dormir dans la chambre (aligné sur Port-Sainte-Marie).
- **Louer une suite** (`choisir_suite`) : nouvelle Suite Présidentielle ajoutée à côté de la Suite Privée de Roxane, choix entre les deux à l'accueil (mix POP/INF/DIS pour la Présidentielle).
- **"Parler au concierge"** et **"Se renseigner"** : supprimés (redondants).
- PNJ : Nathalie Ondor (réceptionniste) et Isidore Trébien (bagagiste) remplacent Gustave/Béatrice, qui n'étaient jamais affichés à cause d'un `persons` piégé dans `buildingContext` qui écrasait la vraie pièce.

### Restaurant
- **Repas gastronomique** (`repas_gastronomique`, remplace l'ancien `se_nourrir` générique) : 120 FR, +10 Santé +1 Moral immédiats, **+1 PA différé au prochain Dormir** (nouveau mécanisme générique `state.bonusPaProchainDormir`, consommé dans `doDormir()`).
- **Dîner d'affaires** (`diner_affaires`) : entièrement refondu. Système d'**invitation entre PJ présents dans la même pièce**, avec popup Accepter/Refuser en temps quasi-réel (sondage 4s), table Supabase `invitations_diner` (colonne `type` ajoutée). 300 FR, +10 Santé/+5 INF/+1 PA différé pour chacun si accepté, aucun coût si refusé, tracé pour les rumeurs vraies dans les deux cas.
- **Ecouter les tables** : rebranché sur `ecouterRumeurs()` (uniquement des rumeurs vraies désormais, plus de génération IA de repli — voir section rumeurs).
- PNJ : Gaston Sauceblanche requalifié Sommelier, Yvette Gratinée Serveuse, aux côtés de Paulo (placeholder photo retiré).

### Bar
- **Boire un verre** (`boire_verre`) : généralisé sur le **même système d'invitation** que Dîner d'affaires (voir `CONFIG_INVITATIONS_SOCIALES` dans `plateau-pnj.js`). 50 FR, +5 Santé/+2 INF/+2 ENT si accepté.
- **Ecouter le barman** : source maintenant Marco (au lieu d'un PNJ générique aléatoire), via un champ `sourceOverride` sur l'ordre.
- **Recruter un informateur** (`recruter_informateur_pnj`) : refondu. Génère un PNJ qui rejoint le groupe (`state.employes`), PER aléatoire 12-18 (utilisée plus tard par l'ordre "localiser", moyenne de PER du groupe), toujours réussi, 150 FR/jour, max 1 informateur. Noms actuels (à retravailler, Fred trouve ça "affreux") : Momo Fouine, Lucienne Indic, Bernard Filature, Rita Tuyau, Gaspard Renseigne, Nadège Oreille.
- **"Recueillir des informations"** (ex-Roxane) : renommé et déplacé. C'est maintenant **"Fabriquer un kompromat"**, une action contextuelle sur la fiche de tout PNJ `job:'escort'` (plus un ordre de salle), cible choisie dans le répertoire (PJ uniquement).
- **Organiser une rencontre piège** : vérifié, fonctionne déjà bien (a servi de modèle pour tout le reste). 800 FR, cible dans le répertoire, jet DUP vs DUP/DIS simulées, kompromat en cas de succès, risque d'être démasqué (-15 POP -10 DIS) en cas d'échec si la cible enquête.
- **Système escort entièrement refondu et réactivé** (était désactivé depuis des semaines, "Temporairement indisponible") :
  - **Roxane Velours devient le nom de l'agence**, plus un personnage. Chaque escort a un simple prénom + rôle "Escort — Agence Roxane Velours".
  - **Deux escorts simultanées au bar** : Natacha (F) et Julien (H), pour couvrir tous les PJ.
  - Stats aléatoires à l'embauche : CHA 12-18, DUP 10-16, INT 8-14. Salaire 800 FR/jour (payé automatiquement via `payerEmployes()`/`payerEscorts()`).
  - **Remplacement automatique** après recrutement (une nouvelle escort du même genre apparaît dans la pièce) — le mécanisme existait mais n'était jamais lu nulle part, corrigé via `appliquerRemplacantesEscort()` dans `renderPersonsList()`.
  - **Banque de photos** : 3 femmes / 3 hommes intégrées et tirées au hasard indépendamment du prénom, à chaque recrutement et remplacement.
  - **Nouvel ordre "Faire l'amour"** (contextuel sur la fiche PNJ escort) : 300 FR, +15 Moral/+5 Santé/+2 ENT, récit généré par IA (flatteur avec un doute distillé à la fin sur l'authenticité — c'était la demande précise de Fred).
  - Recrutement ET "Faire l'amour" sont **tracés pour les rumeurs vraies**, avec la trace **dupliquée (donc 2x plus de chances d'être révélée) si le PJ est marié** (`sbGetMariageActif`).

### Système de rumeurs (transversal, impacte tout le jeu)
- **`ecouter_rumeurs`** (bug historique : 3 ordres "Ecouter" du jeu pointaient vers `doSeRenseigner`, une fonction de gestion de location de locaux, sans rapport) : rebranché sur la vraie fonction `ecouterRumeurs()`. **Ne révèle plus que des rumeurs vraies** (actions réellement tracées) — suppression complète du repli IA inventé. Si échec du jet ou rien à révéler : message neutre "Rien de croustillant à se mettre sous la dent."
- **`lancer_rumeur_cible`** (bug historique : route pointait vers `openRumeurModal()`, fonction jamais écrite) : entièrement implémenté. Cible choisie dans le répertoire (PJ), succès = -5 à -20 POP sur la cible (via `sbAjusterPopJoueur`) + texte de rumeur généré par IA, échec = -5 POP/-5 DIS sur le lanceur + risque de détection.
- **Répertoire de contacts** : bug corrigé où `isPJ` n'était jamais transmis du bouton "Ajouter au répertoire" jusqu'au stockage (`addContactByName` → `addContact`), ce qui empêchait tout filtrage "PJ uniquement" de fonctionner.
- **Textes IA tronqués** : `max_tokens` trop bas (60-80) sur 3 générateurs (kompromat, piège escort, rumeur ciblée), coupait le texte en plein milieu ; augmenté à 120-150 partout, avec consigne explicite "texte brut, sans markdown" (le modèle générait parfois des `#`/`**` affichés tels quels).

### Bugs annexes corrigés en cours de route
- Prompt IA de dialogue PNJ (`talkToPnj`) : ne mentionnait jamais le lieu où se trouve le PNJ (d'où des PNJ qui parlaient comme s'ils étaient à la Mairie) et la consigne sur la monnaie était trop faible (un PNJ a parlé en Euro). Corrigé : lieu explicite + interdiction stricte des devises réelles.
- Inventaire : bouton "Supprimer (destruction définitive)" appelait `supprimerItemInventaire()`, jamais écrite. Fonction ajoutée (différent de "Abandonner ici", qui laisse l'objet récupérable par d'autres joueurs).
- `requiresCadavre`/`requiresSquatteurs` sur certains ordres : flags **jamais vérifiés nulle part** dans le code (contrairement à `requiresPost`, qui fonctionne). À garder en tête, pas corrigé cette session (hors-sujet du jour).
- POP potentiellement stocké en deux endroits incohérents (`resources.pop` imbriqué vs colonne `pop` directe utilisée par `sbAjusterPopJoueur`) — **repéré mais pas vérifié/corrigé**, à surveiller si les effets POP sur d'autres joueurs semblent ne pas s'appliquer.

---

## 🖼️ Images poussées cette session (à vérifier/pousser si pas encore fait)

- `armurerie-port-sainte-marie-maison-le-gall.png`
- `hotel-republica-suite-presidentielle.png`
- Informateurs (noms définitifs pas encore choisis, Fred trouve les noms actuels "affreux") : image homme "façon Jean Cétreau", + 4 autres (femme âgée, jeune homme casquette, homme corpulent, femme facteur/La Poste) — **pas encore intégrées au code, juste reçues**.
- Escorts Agence Roxane Velours (intégrées et fonctionnelles) : `escort-f-1-robe-verte.png`, `escort-f-2-robe-or.png`, `escort-f-3-robe-marine.png`, `escort-h-1-costume-beige.png`, `escort-h-2-chemise-noire.png`, `escort-h-3-chemise-ouverte.png`.

---

## 🆕 Remontées de toute fin de session (19 juillet, pas encore traitées)

**Hôtel Republica — Suite Privée**
- La description mentionne encore "Roxane y reçoit une clientèle triée sur le volet" — référence à un nom propre qui n'a plus de sens depuis que Roxane Velours est devenue le nom de l'agence (pas un personnage). À généraliser.
- Le PNJ "Roxane Velours (PNJ)" est toujours listé dans les `persons` de cette pièce (oublié lors du renommage agence) — à supprimer.

**Hôtel Republica — Chambres classiques**
- Les ordres actuels (`dormir` générique avec bonus fixe, `se_reposer`, `reunion_privee`) sont redondants avec la mécanique précise de réservation + bonus PA différé déjà codée (`reserver_chambre_hotel` à l'accueil + `dormir_chambre` dans la chambre). Fred veut **tout supprimer sauf un seul ordre "Dormir"**, correctement branché sur la mécanique de réservation (probablement `dormir_chambre` renommé simplement "Dormir" pour le joueur, sans exposer la distinction technique des `fn`).
- `reunion_privee` : jugé inutile, à supprimer.
- Idée à valider : ajouter **"Faire appel au service d'étage"** pour un déjeuner/repas pris en chambre.

**Question de conception ouverte — chambres partagées sans dupliquer les pièces**
Fred veut éviter de multiplier les chambres dans `data.js` (une par location) tout en gardant une impression de confidentialité entre PJ qui la louent à des moments différents, **sans que ça devienne une planque intouchable**. Piste proposée par Claude, à discuter/affiner ensemble avant implémentation :
- Garder une seule pièce physique "Chambre" dans `data.js`.
- Ne **jamais** filtrer `state.currentBuilding`/`state.currentRoom` (la vraie position reste toujours exacte et interrogeable par la police/les enquêtes — c'est la garantie contre la planque intouchable).
- Filtrer uniquement **l'affichage** (`renderPersonsList`) : un PJ ne voit que les autres PJ rattachés à sa propre réservation (ex. via le même système d'invitation que Dîner d'affaires/Boire un verre), pas les autres PJ qui louent la même chambre à un autre moment.

**Université**
- Fred a repéré des bugs, **pas encore détaillés**. À préciser en tout début de la prochaine session.

---

## 🏗️ Chantiers ouverts / en attente

- **Tableau récapitulatif des ordres** : idée validée par Fred pour la fin du codage de Luthécia — lister tous les `fn`, leurs usages multiples, coûts et effets, généré directement à partir de `data.js` plutôt que découvert au fil de l'eau (plusieurs bugs cette session venaient de `fn` génériques partagés entre bâtiments avec des comportements différents attendus).
- **Ordre "Localiser quelqu'un/un objet"** : pas encore créé. Utilisera la moyenne de PER du groupe (joueur + informateur(s) recrutés) dans son calcul de réussite.
- **Noms des informateurs et informatrices** : à revoir avec Fred, jugés pas assez réussis (contrairement à "Jean Cétreau").
- **Autres empires** : le même bug de `persons` piégé dans `buildingContext` qui a cassé l'accueil de l'Hôtel Republica pourrait exister pour les hôtels des 3 autres empires (Ciudad Roja, Sovarka, Al-Khalija, etc.) — non vérifié, à surveiller quand ces empires seront travaillés.
- **Système de duplication de PNJ** : toujours désactivé temporairement dans `plateau-multijoueur.js` (mentionné les sessions précédentes, indépendant du système d'employés/escorts qui lui a été réactivé cette session).
- Kompromats au texte tronqué déjà générés avant le correctif (ex. celui sur Sophie Leroux) : Fred les nettoie lui-même via le bouton Supprimer maintenant fonctionnel.

---

## 💡 Idées en réserve (pas de code, juste notées)

- Monétisation premium : cosmétique/confort uniquement, jamais d'avantage compétitif payant.
- Discord, traduction, mobile : pas des priorités de lancement.
