# Le dialogue des PNJ de Républia — audit, correctifs, et ce qui reste à décider

**13 octobre 2026.** Point de départ `14f5e72`, registre Supabase 712 → **713**.

Déclencheur : une nouvelle joueuse a essayé de parler aux PNJ qu'elle rencontrait et a
rapporté que « presque tous apparaissent comme non connectés et/ou ne répondent pas ».

L'inventaire complet, PNJ par PNJ, est dans `INVENTAIRE-PNJ-REPUBLIA.csv` (244 lignes,
généré depuis le code et la base, jamais saisi à la main).

---

## 1. Ce que l'audit a mesuré, et ce qu'il a écarté

**Ce n'était pas DeepSeek.** `cron_journal` porte une sonde `sonde_ia` **verte chaque nuit
depuis le 1er octobre**, 13 octobre compris. Et un appel réel du chemin complet — session
anonyme créée comme celle d'une nouvelle joueuse, `POST /api/chat`, DeepSeek — rend **200 en
2,0 à 2,4 secondes**, avec des réponses en personnage :

> « Marco. Je tiens le bar de l'Hotel-Restaurant La Republica. Vous voulez boire quelque chose ? »

**Ce n'était pas la table des profils.** Sur **185 identifiants** de PNJ de Républia sondés
en production sans jeton — 400 « Profil inconnu » = absent, 401 = présent — **161 étaient
connus du serveur**.

**Et il n'existe AUCUN état « connecté / déconnecté » pour un PNJ.** Le mot n'apparaît nulle
part dans l'interface : ni dans les fichiers HTML, ni dans la carte d'une personne présente
(qui affiche « Neutre / Allié / Hostile »), ni dans la fiche d'un PNJ. Ce que la joueuse a lu
est le message d'échec du dialogue :

> « Discussion impossible momentanément. Veuillez réessayer dans quelques instants. »

qui se lit, mot pour mot, comme un problème de connexion.

## 2. Les trois causes réelles

### a) LE GUIDE DU JEU ÉTAIT MUET — et c'est la cause principale

**Jérémy** conduit la quête d'accueil. C'est le premier PNJ qu'une nouvelle joueuse
rencontre, celui qui l'accompagne de pièce en pièce, et celui qui lui dit lui-même
« Vous avez des questions ? ». Son prompt était **écrit depuis longtemps** — vouvoiement
systématique, maladresse serviable, interdiction d'inventer un lieu, renvoi vers le bouton
PLAN, et jusqu'à l'étape en cours de la visite — mais il était construit **par le navigateur**,
dans un bloc qui n'est plus envoyé nulle part depuis le 29 septembre 2026. Et son identifiant
`jeremy` **n'a jamais existé côté serveur**.

Résultat : `/api/chat` répondait 400, et **aucune question posée à Jérémy n'a jamais reçu de
réponse depuis le 29 septembre**. Pour une joueuse qui découvre le jeu, c'est le seul PNJ qui
compte vraiment — d'où « presque tous ».

**Maxence Monfils** était dans le même cas exactement : un « contexte spécial » écrit mot pour
mot dans le client, un identifiant absent du serveur.

### b) UN BLOC MORT POUVAIT FAIRE TAIRE LES 171 AUTRES

Le même bloc lisait `FORUM_TOPICS` — une table de `forum.js` — **hors de tout try/catch**.
`plateau.html` charge bien `forum.js` avant `plateau-pnj.js`, donc le défaut dormait ; mais un
changement d'ordre de chargement, ou un `forum.js` qui échoue, et une `ReferenceError` est levée
**avant l'appel réseau** : tous les PNJ muets, la joueuse bloquée sur « En train de repondre… »,
aucune requête, aucune trace.

**Ce n'est pas une hypothèse : c'est exactement ce qui s'est produit le 29 septembre 2026** —
une `TypeError` sur `traits.join` avait rendu trois PNJ de la caserne muets de cette façon.

Ce bloc coûtait en outre **un aller-retour réseau pour rien** à chaque réplique de Marcel Ancre
(`getEtatPort()` + `chargerCaisseBatiment()`), pour un texte jeté aussitôt.

### c) LA PRODUCTION A DEUX JOURS DE RETARD — hors de nos mains

`https://res-publica.vercel.app` sert le build de **`7e3bc52`, 11 octobre 17 h 21** :
`data.js?v=321` en ligne contre `v=332` au dépôt, et `PNJ_ONBOARDING_REPERTOIRE_NOMS` (12
octobre) absent du fichier servi. **Dix-sept commits ne sont pas déployés**, dont les deux
tranches du Tribunal.

Conséquence mesurable sur ce chantier : `honore_cozetoujours` — le référent juridique du
Tribunal, entré au dépôt le 12 octobre à 12 h 38 — répond 400 en production alors qu'il est
correct dans le dépôt. **Un PNJ muet sur les 26 l'est uniquement à cause du retard de
déploiement.**

Je ne peux pas diagnostiquer la cause depuis ici (aucun accès au tableau de bord Vercel). La
piste la plus probable est documentée dans `.vercelignore` du 8 octobre : *« à ce poids,
20 déploiements saturent les 10 Go inclus »*. **À vérifier dans le tableau de bord Vercel.**

## 3. Ce qui a été corrigé

| | |
|---|---|
| **Jérémy raccordé** | son texte existant transposé dans `api/_pnj-personnalites.js`, sans réécriture |
| **Maxence raccordé** | idem, avec `maxTokens: 120` — sa consigne est « 1 à 2 phrases maximum » |
| **Sixième canal** | `quete_accueil_contexte()` (registre 713) rend l'**étape** de la visite ; la **phrase** de consigne est un miroir de `QUETE_ACCUEIL_OBJECTIFS`, côté dépôt |
| **Bloc mort supprimé** | 154 lignes qui ne partaient nulle part et pouvaient tout faire taire |
| **Deux messages d'échec** | un refus **définitif** (400) ne promet plus de réessayer ; une panne **passagère** le promet encore |
| **Interface cohérente** | un refus définitif **retire la boîte de question** : on n'invite plus à écrire à un PNJ qui ne répondra jamais |

**La découverte ne coûte aucun appel supplémentaire** : la fiche d'un PNJ envoie déjà un
« bonjour » à l'ouverture, et c'est cette réplique qui révèle l'absence de profil. Le navigateur
n'a donc **pas** besoin d'un miroir des 216 identifiants serveur — un miroir qui aurait dérivé
dès la première fiche ajoutée.

## 4. Ce qui reste muet, et pourquoi on n'y touche pas

**26 PNJ**, tous déclarés nommément dans `outils/bancs/banc-dialogue-pnj-republia.js` pour
qu'un vingt-septième fasse rougir le banc :

* **8 députés PNJ** de l'hémicycle (`assemblee_sieges`). Un député PNJ n'a ni personnalité
  écrite ni savoir propre : seulement un siège et une ville. Le neuvième, **President Laroche**,
  répond — il est référent.
* **12 candidats de l'agence Grobras** (`pnj_candidats_catalogue`), qui deviennent des employés
  cliquables une fois embauchés.
* **4 directeurs** : usine pharmaceutique de Luthécia, et les trois entrepôts logistiques.
* **2 avocats commis d'office**, à Port-Sainte-Marie et à Montrouge.

Aucun des 26 n'a de personnalité écrite **nulle part** — ni dans `PNJ_PERSONALITIES`, ni dans
`PNJ_PROFILS`, ni en base. Leur en écrire une, c'est créer 26 personnages : **un arbitrage de
game design, pas une passe technique.** Le cahier des charges l'interdit explicitement, et
l'interface ne leur propose plus de conversation libre.

## 5. Le coût, mesuré

* **ouvrir une fiche de PNJ** = 1 appel DeepSeek (le « bonjour » automatique), sauf si la
  conversation du jour existe déjà (la dernière réplique est réaffichée, aucun appel) ou si une
  réponse déterministe intercepte ;
* **chaque question** = 1 appel, jamais deux ;
* une conversation normale de cinq questions = **6 appels** ;
* **aucun second appel IA** pour reformuler, résumer ou classer ;
* par appel : le prompt système (≈ 1 à 4 k caractères selon le PNJ, jusqu'à ~30 k pour un
  référent qui porte une bible de domaine), **6 derniers échanges au plus**, message borné à
  1 000 caractères ;
* **3 lectures serveur en parallèle** par réplique pour presque tous les PNJ (relation sociale,
  mémoire pédagogique, contexte public) ; une quatrième seulement pour Huguette Papier, Renée
  Toitout ou Jérémy. Elles partent **ensemble**, jamais en série.

## 6. Ce qui reste à faire, et par qui

1. **Vérifier pourquoi Vercel ne déploie plus** (tableau de bord). Rien de ce chantier n'est
   visible par les joueurs avant un déploiement — y compris Jérémy.
2. **Test humain, après déploiement** : créer un personnage neuf, suivre la quête d'accueil,
   poser trois questions à Jérémy (« on fait quoi ? », « c'est quoi cet endroit ? », « tu es
   qui ? ») et vérifier qu'il répond, qu'il redit l'étape en cours et qu'il ne nomme aucun lieu.
3. **Arbitrage GD** : faut-il une personnalité aux 8 députés, aux 12 candidats de Grobras, aux
   4 directeurs et aux 2 avocats commis d'office ? Ou restent-ils des figures fonctionnelles
   sans conversation ?
