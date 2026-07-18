# Journal de session — Res Publica

*Dernière mise à jour : 18 juillet 2026 (matin)*

**Usage** : au début de chaque nouvelle session avec Claude, faire `cat JOURNAL-SESSION.md` et coller le résultat dans le chat. Claude doit mettre ce fichier à jour à la fin de chaque session (ou sur demande).

---

## 🔒 Point de restauration Git connu comme stable

Tag : **`base-saine-18juillet`**

En cas de casse grave et de doute, revenir à cet état avec :
```bash
cd ~/ResPublica
git checkout base-saine-18juillet -- .
git commit -m "Retour a la base saine du 18 juillet"
git push
```

---

## ⚠️ Règles impératives (apprises à la dure le 17-18 juillet)

1. **Les fichiers JS/CSS/HTML principaux ont des noms définitifs, plus jamais de suffixe `-vXX`** :
   `plateau.html`, `style.css`, `rue-centrale.css`, `plateau-core.js`, `plateau-navigation.js`,
   `plateau-rue-centrale.js`, `plateau-personnage.js`, `plateau-pnj.js`, `plateau-multijoueur.js`,
   `plateau-communication.js`, `plateau-politique.js`, `plateau-justice-economie.js`,
   `plateau-actions-illegales-rumeurs.js`, `plateau-organisations-quetes.js`, `plateau-divers.js`,
   `plateau-router.js`, `data.js`, `avatars.js`, `world-map.js`, `supabase.js`, `forum.js`.
   Livraison = toujours `cp fichier.js plateau-xxx.js` (écrase le même nom), jamais un nouveau nom.

2. **Cache navigateur** : géré par un numéro de version unique dans `plateau.html`
   (`?v=1`, `?v=2`...). Pour livrer une mise à jour qui doit forcer le rechargement,
   augmenter ce chiffre dans TOUTES les balises `<script>`/`<link>` locales d'un coup.

3. **Avant de livrer un fichier reconstruit "de mémoire"**, TOUJOURS demander à Fred un
   `grep`/`wc -l` de vérification sur SON fichier actuel. Ne jamais faire confiance à une
   copie locale de Claude sans vérification préalable.

4. **Pour un petit correctif sur un gros fichier**, préférer une commande `sed`/script Python
   précis à exécuter directement par Fred, plutôt que renvoyer le fichier entier.

5. **Vérifier le contenu réel** (présence de fonctions/variables clés via `grep -c`), pas
   seulement la syntaxe. `node` n'est pas installé sur la machine de Fred — utiliser `grep`
   pour tout contrôle, pas `node --check`.

6. **En cas de doute sur l'état d'un fichier**, faire confiance à Git
   (`git log -S "texte" -- fichier`, `git checkout <hash> -- fichier`) plutôt qu'à la
   mémoire de conversation de Claude.

7. **Avant toute action destructive** (suppression de fichiers, nettoyage), poser un tag
   Git de sécurité d'abord (`git tag nom-du-tag && git push origin nom-du-tag`).

8. **Vérification rapide de propreté du dépôt**, à lancer de temps en temps :
   ```bash
   git ls-files | grep -E '\-v[0-9]+\.(js|css|html)$'
   ```
   Doit renvoyer une liste vide.

---

## 🗺️ Feuille de route (donnée par Fred le 18 juillet)

- **Fin juillet 2026** : terminer complètement Luthécia (tour de tous les bâtiments,
  audit des ordres morts/cassés).
- **1re quinzaine d'août** : finaliser les deux autres villes de Républia
  (probablement Port Sainte-Marie + une autre), en dupliquant la mécanique de Luthécia.
- **2e quinzaine d'août** : commencer le déploiement de la "base commune" vers les
  3 autres empires (El Estado, Sovarka, Al-Khalija).
- **Fin août / début septembre** : finaliser les spécificités propres à chaque empire.
- **Fin septembre 2026** : objectif d'avoir quelque chose d'abouti pour une bêta fermée.

---

## 🏛️ État d'avancement — Tour des bâtiments de Luthécia

Terminés et vérifiés fonctionnels : Mairie, Assemblée Nationale, Tribunal, Université
(amphi + salle de réunion, avec formation/conférence/militants), Quartier des Ambassades,
Centre d'Affaires (hall + Gretta Délieu), Centre Commercial (hall), Centre Artisanal
(Travées, image reçue mais pas encore intégrée).

**Chantiers ouverts / en attente** :
- Intégrer l'image de Jean Bonde (espion, rue devant l'ambassade) — reçue, pas encore poussée.
- Renommer "Henrico Stot" → "Enrico Stot" + intégrer son image de sécurité — reçue, pas encore poussée.
- Système de groupe/emploi de PNJ à concevoir : un PJ peut recruter un PNJ (militaire,
  policier, ou "employé" générique), le PNJ s'agglomère au groupe du PJ, peut être laissé
  quelque part et récupéré. Puissance de groupe = somme des caractéristiques.
  Hiérarchie militaire (compagnie → capitaine → sections → lieutenants) à concevoir à part,
  en même temps que le commissariat pour la police.
- Système de duplication de PNJ (escort/recrutement générique/débauchage) désactivé
  temporairement dans `plateau-multijoueur.js`, en attente d'un vrai redesign.
- Tableau Excel des PNJ de Luthécia en cours d'enrichissement par Fred
  (`PNJ_Luthecia_v2.xlsx` / `.numbers`), avec colonnes stats/trait IA/employabilité.
  Attention aux doublons (ex: Jodie Moitout apparaît à 2 endroits).
- Réflexion en cours (non tranchée) : refonte de l'architecture des fichiers en 4 familles
  (décor fixe / cartographie-déplacement / contenu des lieux / systèmes de jeu). Fred doit
  encore trancher s'il veut une migration progressive ou une session dédiée.
- Système de messagerie persistante (conversations privées + salons nommés, notification
  persistante) construit et fonctionnel — le bouton "Parler" sur un vrai joueur ouvre le chat.

---

## 💡 Idées en réserve (pas de code, juste notées)

- Monétisation premium : cosmétique/confort uniquement (portraits présidentiels, Banque
  Privée Helvetia, taxe successorale, sécurité contre l'usure des bâtiments privés...).
  Jamais d'avantage compétitif payant (pas de protection contre le sabotage d'un rival).
- Discord : à construire une fois le jeu plus avancé, pas maintenant.
- Traduction/internationalisation : faisable techniquement plus tard (contenu déjà
  séparé de la logique dans `data.js`), mais pas une priorité — Torn n'a jamais traduit
  son interface en 22 ans et a quand même atteint 100 000 joueurs/jour.
- Mobile : pas un frein au lancement, à traiter bien plus tard (Torn n'a eu d'app mobile
  qu'en 2018, 14 ans après son lancement).
