# Prévol du verrou final des ajouts d'inventaire (31/10/2026)

**Statut : correctif proposé, non appliqué.** Le code client courant appelle `sbInventaireSauverRevision` depuis `sbEnfilerEcriturePersonnage` lors de la sauvegarde automatique (fichier `supabase.js`). Il envoie l'inventaire complet avec sa révision.

## Preuves (production, lectures seules)
- `inventaire_sauver_revision(text,bigint,jsonb)` : `SECURITY DEFINER`, `EXECUTE` accordé à `authenticated`, MD5 `57e01e4f842ef10ea8dd01dc99b3de9a`.
- `inventaire_deposer_interne` : `EXECUTE` refusé à `authenticated`.
- La sauvegarde versionnée appelle `inventaire_ajouts_interdits` mais journalise ses résultats puis écrit quand même `inventory=p_inventory`.
- Le journal `inventaire_ecarts_observes` a zéro entrée au moment de la consultation ; ce n'est pas une preuve de sécurité.
- Les six fermetures intermédiaires de l'inventaire ont été appliquées sous des versions réhorodatées.

## Correction proposée
Le SQL adjacent remplace **uniquement** le bloc d'observation d'ajouts par un refus atomique avec `raison='ajout_inventaire_interdit'`. Le reste de la fonction demeure inchangé : vérification d'identité, verrou, comparaison de version, retour de l'inventaire canonique. Le prévol exige l'empreinte de production exacte et un ancrage unique. Aucun SQL n'a été appliqué.

## Validation indispensable avant application
1. Rejouer avec fixtures fictives l'ensemble des bancs inventaire, dépôts autorisés, vols, fret, objets trouvés, récompenses, consommation, achats, échanges et réponses réseau perdues.
2. Tester la modification légitime d'une quantité, un retrait, une sauvegarde identique, une vieille révision, un ajout forgé, et deux sessions concurrentes. Vérifier qu'aucun objet ou PA n'est perdu.
3. Vérifier que les mécanismes métiers qui ajoutent des objets travaillent toujours **directement au serveur**, sans passage par la sauvegarde du navigateur.
4. Mettre à jour le code client pour distinguer `ajout_inventaire_interdit` d'un conflit de version générique, et pour recharger l'état serveur si un tel refus survient.
5. Reprévoler la définition et la présence des autres migrations de la PR #219, puis coordonner l'ordre de livraison.
6. Ne pas livrer cette correction avant les tests combinés de la PR #219 et une revue du responsable de l'intégration.
