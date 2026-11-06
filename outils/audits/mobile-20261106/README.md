# Preuves de l'audit mobile du 6 novembre 2026

Ces captures et mesures proviennent de Chromium **local**, source `304633e0`.
Aucun compte, aucune authentification, aucune donnée personnelle et aucune transaction.
Les valeurs statiques visibles sous le portrait ne sont pas un solde de joueur.

`reproduire-affichage.cjs` est un instrument d'audit, pas un nouveau banc métier ni
une version mobile du jeu. Il sert les fichiers locaux sur 127.0.0.1, retire les scripts
HTML, charge uniquement les scripts de création nécessaires et bloque tout réseau
extérieur. Les rendus des pièces, PNJ et forum sont des fixtures explicitement nommées.
Les 120 mesures décrivent 20 états sur six formats ; elles ne valident pas les ordres.
La réduction de hauteur à 350 px ne simule pas un vrai clavier système.

`reproduire-canvas.cjs` utilise le contrôleur **réel** du forum, un objet fictif et les
events tactiles CDP puis souris. Le résultat démontre le défaut de glissement au doigt
sur ce Chromium ; aucun message n'est publié. Aucun serveur n'est contacté.

Pour l'agent technique disposant de Node, du Chromium système et des dépendances
Playwright existantes (`outils/e2e/package-lock.json`) :

```
node outils/audits/mobile-20261106/reproduire-affichage.cjs
node outils/audits/mobile-20261106/reproduire-canvas.cjs
```

Les outils réécrivent leurs preuves dans ce dossier ; ne pas exécuter sur un compte
connecté ni substituer l'URL publique à l'origine locale. Les temporisations de capture
attendent les animations, elles ne constituent pas un chronométrage de performance.
Les polices et icônes distantes sont bloquées, d'où les substitutions visibles.

`mesures.json` contient dimensions, dépassements et contrôles sous 44 px ; les listes
sont tronquées volontairement et peuvent inclure des éléments derrière une modale.
`canvas-tactile.json` contient la contre-épreuve ; `environnement.json` précise les
outils. `SHA256.json` permet de vérifier les captures, sources de mesure et résultats.

Limites : pas de Safari iOS réel, ni Android physique, ni recette authentifiée,
ni mesure de trafic réseau de production. Consulter le rapport parent pour les
risques, parcours inspectés, estimation et plan de développement.

## Conditionnement de publication

Pour ne pas construire une Preview à cause des PNG/JSON/scripts, ils sont regroupés
dans l’archive vérifiée de [PREUVES.md](PREUVES.md#archive-vérifiée).
Les chemins de reproduction et noms de fichiers ci-dessus s’appliquent après extraction
par l’agent technique dans ce même répertoire. Aucun changement Vercel n’est requis.
