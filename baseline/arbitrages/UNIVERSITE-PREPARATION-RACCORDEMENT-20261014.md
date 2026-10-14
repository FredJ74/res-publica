# Université — état de préparation technique au 14 octobre 2026

## Base Supabase (projet jxpwoosmmhohoihxpbuc)

Quatre cursus inscrits : `univ_medecin` (doctor), `univ_affaires` (business), `univ_justice` (magistrat), `univ_armee` (officer). Chaque cursus a **24 jalons : 17 cours + 7 missions de stage**. Formation gratuite (0 FR), cours à 6 PA.

RPC nouvelles : `universite_prochaine_etape()` (lecture) et `universite_valider_etape(p_jalon,p_action)` (validation avec contrôle du lieu, de l'ordre des étapes, de la date et débit atomique des PA). L'ancienne `universite_jalon_accomplir` n'est plus exécutable par les joueurs.

**IMPORTANT : INSCRIPTIONS ET VALIDATIONS VOLONTAIREMENT FERMÉES** pour `authenticated` jusqu'à finalisation. Révoquées : `universite_inscrire(text,text)` et `universite_valider_etape(text,text)`. Ne les rouvrir qu'après tests bout-en-bout et validation des missions contextuelles. Le catalogue en base ne signifie pas que le jeu est prêt.

## GitHub

Fichiers créés : `plateau-universite.js`, `universite-calendrier.js`, `universite-missions-autres.js` et bancs `outils/bancs/banc-universite-calendrier.js`, `outils/bancs/banc-universite-missions-autres.js`. Le catalogue médical préexistant est `universite-missions-medecin.js`.

**Raccordement HTML non effectué** : l'outil GitHub refuse les écritures des fichiers volumineux `plateau.html`, `data.js` et `plateau-router.js`. Il faudra :

1. Charger `plateau-universite.js` avant `plateau-router.js` dans `plateau.html`, ainsi que les catalogues et le calendrier si utilisés.
2. Router `suivre_formation` vers `ouvrirUniversiteFormation()` avant le débit générique dans `plateau-router.js`.
3. Retirer `bientot` de l'ordre dans `data.js` **uniquement lorsque les tests sont satisfaisants**.
4. Tester les formes JSON réelles de `universite_mon_etat`, `universite_prochaine_etape`, `universite_inscrire`, `universite_valider_etape` et `universite_diplomer`.
5. Revoir les interactions pédagogiques : `plateau-universite.js` propose actuellement des réponses déterministes, pas encore une véritable conversation DeepSeek. Les missions de stage ne doivent pas se valider par un simple clic sans rencontre effective d'un maître de stage et d'un PNJ concerné.
6. Réconcilier `universite-missions-autres.js` (première ébauche avec lieux abstraits) et les lieux **réels** retenus en base : affaires centre-affaires Luthécia / port industriel PSM ; justice tribunal Luthécia / tribunal local PSM ; armée caserne spéciale / port industriel PSM (logistique). Vérifier que les pièces sont accessibles à un étudiant civil.
7. Revoir les trajets et le calendrier : deux cours à Luthécia chaque semaine, stage PSM jeudi ; vérifier faisabilité des allers-retours et règles de présence. Tester les reports, le fuseau Paris, les frontières de semaine et les PA. `universite_prochaine_etape` programme la première séance au lundi suivant l'inscription ; vérifier la conformité aux arbitrages.
8. Après tests sur personnage de test et confirmation des 4 parcours, rétablir les grants `EXECUTE` des deux RPC aux utilisateurs authentifiés, puis commit/push/déploiement.

## Attention

Les modifications en base ont été effectuées avant le branchement du client. Ne pas confondre **catalogue préparé** et **fonctionnalité livrée**. Ne pas toucher aux dialogues existants des pensionnaires de l'EHPAD, liés à la quête du musée.
