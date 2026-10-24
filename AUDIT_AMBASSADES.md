# Audit des ambassades — 24 octobre 2026

Audit en lecture seule (aucun code modifié). Auteur : Claude, à la demande de Fred.
Question posée : le fonctionnement des ambassades est-il suffisamment abouti ?

**Verdict : non.** Le décor et le squelette existent, la sécurité de la base est
correcte, mais la boucle de jeu ne se ferme pas : la plupart des ordres produisent
des effets qui disparaissent au rechargement, et le circuit principal (Républia
ouvre une ambassade, nomme un ambassadeur, celui-ci travaille) est impossible à
parcourir aujourd'hui.

## Ce qui existe

| Élément | Où | État |
|---|---|---|
| Bâtiment Quartier des Ambassades (Luthécia) : accueil, salle de réception, 3 bureaux (Al-Khalija, Sovarka, El Estado) | `data.js` ~5966 | ✅ décor, images, PNJ hôtesse et agent de sécurité |
| Ministre AE : ouvrir une ambassade, nommer, démettre, expulser | `plateau-gouvernement.js` 347, `plateau-politique.js` 7409, 9412-9550 | ⚠️ voir constats |
| Table partagée `ambassades_ouvertes` | `supabase.js` 3685 | ✅ RLS correcte (insert par le min. AE de l'empire, lecture publique) |
| Bureau fermé tant que l'empire n'a pas ouvert son ambassade | `plateau-navigation.js` 617 | ✅ |
| Ordres du bureau réservés à l'ambassadeur en poste | `plateau-politique.js` 4202 | ✅ côté client |
| Réservation de la salle de réception (1 par jour) | `supabase.js` 4015, RLS | ✅ solide, contrôlée en base |
| Expulsion avec délai de 24 h, traitée par le cron serveur | `api/cron-minuit.js` 4056 | ✅ partiel (voir C6) |
| Offre d'emploi « Hôtesse d'accueil diplomatique » (BNE) | `data.js` 8462 | ⚠️ étiquette seule, documentée comme telle |

## Constats

### Bloquants (la boucle de jeu ne fonctionne pas)

**C1 — Le circuit de Républia est une impasse.** Quand le ministre AE de Républia
« ouvre une ambassade à Sovarka », la ligne créée est `soviet-republic` : un bureau
pour l'ambassadeur de Républia **dans le Quartier des Ambassades de Sovarka**. Or
aucune capitale étrangère n'a de Quartier des Ambassades (seule Luthécia l'a, et
ses 3 bureaux sont pour les ambassadeurs étrangers). L'ambassadeur républicain
nommé n'a donc aucun lieu où exercer. Inversement, les 3 bureaux de Luthécia ne
s'ouvrent que si un ministre AE d'El Estado, Sovarka ou Al-Khalija ouvre son
ambassade — ce qui suppose des joueurs dans ces empires, qui sont jouables à la
création mais non finalisés.

**C2 — Les gains d'Indice Diplomatique (ID) sont fictifs.** Tous les ordres
(corrompre +6/-10, réception +5, mécénat +3, ouvrir une ambassade +8, traités +12)
modifient `INDICES_NATIONAUX`, une constante **en mémoire dans le navigateur du
joueur** (`data.js` 8606), jamais enregistrée. L'effet disparaît au rechargement
et n'est vu par personne d'autre. C'est un écart connu, noté dans
`api/cron-minuit.js` 2349 (décision du 3 septembre : « on finalise Républia ») —
mais pour Républia aussi, l'ID n'est pas dans `indices_villes`.

**C3 — Les traités ne sont pas partagés.** `state.traites` vit dans l'état
personnel du joueur qui signe. L'ordre « Consulter les relations bilatérales »
de l'ambassadeur affiche donc **ses propres** traités (en pratique : aucun), pas
ceux de son pays.

### Importants (l'ordre s'exécute mais ne produit rien de réel)

**C4 — Demande d'asile politique sans suite.** Elle pose
`state.char.asilePolitique`, que **aucun code ne lit**. Pas de protection contre
l'arrestation, pas de traitement par l'ambassadeur, pas de décision. Et
l'ordre est à l'accueil commun : on ne choisit même pas l'ambassade.

**C5 — L'audience ne mène pas à l'ambassadeur.** « Demander audience » ouvre un
PNJ générique « L'Ambassadeur » (70 % de réussite), le même pour les trois
ambassades, et jamais le vrai joueur ambassadeur en poste.

**C6 — L'expulsion annonce une arrestation qui n'existe pas.** Le message dit
« 24 h pour quitter le pays, sous peine d'arrestation ». À l'échéance, le cron
retire simplement le poste ; aucune vérification de la présence physique, aucune
arrestation.

**C7 — Faux succès sur la nomination et l'ouverture.** `sbNommerAmbassadeur` et
`sbOuvrirAmbassade` sont lancés sans attendre le résultat (`.catch(() => {})`).
Nommer un ambassadeur pour une ambassade pas encore ouverte n'écrit rien (ligne
absente) mais affiche « Ambassadeur nommé », envoie la notification au joueur et
publie l'annonce. Idem si la base refuse l'ouverture.

**C8 — « Corrompre un homologue » : la faveur obtenue n'existe pas.** Seul effet :
±ID (fictif, voir C2). Aucune faveur stockée ni utilisable.

### Mineurs

- **C9** — Ouvrir une ambassade déjà ouverte redonne +8 ID à chaque fois
  (ordre répétable).
- **C10** — Aucun contrôle sur la personne nommée : n'importe quel contact du
  répertoire, quelle que soit sa nationalité, y compris quelqu'un qui détient
  déjà un poste ou qui est en prison.
- **C11** — La règle de base autorise le ministre AE du **pays hôte** à modifier
  toute la ligne d'une ambassade étrangère, y compris le nom de l'ambassadeur
  (il pourrait installer le sien). L'interface ne le permet pas, mais un joueur
  malin oui.
- **C12** — Les ordres du bureau sont contrôlés côté navigateur seulement
  (sauf la réservation de salle, contrôlée en base).
- **C13** — L'hôtesse diplomatique (BNE) n'a aucun rôle mécanique, ce qui est
  documenté comme un choix.

## Décisions de design à prendre (Fred)

1. **Le circuit cible pour la bêta.** Deux voies :
   - (a) Républia seule : un Quartier des Ambassades est aussi utile *à
     Républia*, avec des ambassadeurs **PNJ** étrangers en attendant les autres
     empires, et le joueur républicain nommé ambassadeur exerce… où ?
   - (b) Multi-empires : ajouter un Quartier des Ambassades dans chaque capitale
     étrangère et finaliser les déplacements internationaux de l'ambassadeur.
2. **L'Indice Diplomatique** : le persister (national, en base) ou retirer les
   gains affichés tant qu'il n'existe pas.
3. **L'asile politique** : que doit-il protéger (arrestation, extradition,
   exécution d'une peine) et qui l'accorde (l'ambassadeur joueur, un PNJ) ?
4. **L'expulsion** : garder la promesse d'arrestation (alors il faut la
   construire) ou reformuler le message.
5. **La faveur de corruption** : en faire une ressource utilisable, ou
   supprimer l'idée.

## Corrections possibles sans arbitrage de design

C7 (attendre et vérifier le résultat avant d'annoncer le succès), C9 (pas de
bonus si déjà ouverte), C10 (refuser détenu ou déjà en poste), C11 (restreindre
la règle de base), C12 (contrôle serveur des ordres du bureau).
