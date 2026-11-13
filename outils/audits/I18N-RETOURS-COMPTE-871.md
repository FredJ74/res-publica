# #871 — retours de création du compte

Les traductions des erreurs de création de compte et du bouton existaient déjà.
Ce lot réutilise **huit clés `auth` / 64 traductions étrangères**, sans catalogue
nouveau ni copie de texte. L’état d’attente reste lisible et les erreurs suivent
la langue du joueur. Le bouton retrouve sa clé d’origine après la réponse, dans
la langue courante ; une éventuelle absence de clé reste respectée.

La fonction d’affichage reçoit une clé optionnelle de présentation. Sans clé, le
texte reste intégralement opaque. La réouverture retire le marqueur précédent :
aucune erreur ne ressurgit au changement de langue. Le moteur existant suffit.

## Preuves

AST entier de `creation.js` identique après retrait des seules métadonnées de
présentation. Les six appels de message gardent exactement leur premier argument.
Conditions, raisons de refus, email/mot de passe transmis, requêtes, session,
verrou et navigation restent identiques. Français exact, onze parcours comparés
avant/après main, y compris exceptions et retour normal. Aucun compte réel créé.

Chromium : **351 bascules**, onze parcours terminés et deux attentes simulées,
neuf langues, 320/390/1280, allemand/russe/arabe RTL, repli français. La langue ne
répète aucune requête et ne change ni verrou, bouton désactivé, progression,
saisie, focus, sélection, session ou cache. Le double clic pendant l’attente reste
bloqué. Après résolution, le bouton retrouve son libellé dans la langue courante.
Réouverture sans résurrection d’alerte, texte libre avec caractères HTML conservé.

Les bancs recherche et confirmation sont rejoués (324 bascules et 108/972).
Vérifications de connexion existantes, mesure au même extracteur, CI et production
à compléter avant livraison. Relecture native, PJ réel et téléphone physique non
réalisés. Aucune modification Supabase, migration, RPC ou réglage Auth.
