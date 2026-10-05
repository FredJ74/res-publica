-- Lot 4 (cartes postales) -- a executer manuellement AVANT le prochain deploiement.
-- Aucune de ces deux instructions n'est destructive ; les deux sont sures a re-executer.

-- 1) Persistance reelle des deux plafonds quotidiens Moral "carte postale" (lecteur/expediteur)
--    sur le personnage. Sans cette colonne, ces plafonds ne vivaient que dans state.* en memoire
--    -- jamais retournes par sbSavePersonnage (qui n'ecrit qu'une liste explicite de colonnes,
--    voir supabase.js) -- donc perdus a chaque refresh/reconnexion/changement de machine, et le
--    plafond quotidien entierement contournable. Meme motif qu'une colonne deja existante,
--    salutations_du_jour : {"lecteur": "JJ/MM/AAAA"|null, "expediteur": "JJ/MM/AAAA"|null}.
ALTER TABLE personnages ADD COLUMN IF NOT EXISTS carte_postale_moral_jour jsonb;

-- 2) Garantit que impacts_indices_attente.id peut servir de cle d'idempotence pour
--    sbDeposerImpactIndice (desormais Prefer: resolution=ignore-duplicates, supabase.js) : un
--    retry client apres un accuse de reception reseau perdu (le premier depot a en realite reussi
--    cote serveur) doit renvoyer un succes HTTP propre (ligne deja presente, rien a faire) au lieu
--    d'une erreur de contrainte -- necessaire pour que lireCartePostale() (plateau-personnage.js)
--    puisse determiner de facon fiable si le credit expediteur a bien ete mis en file, sans jamais
--    pouvoir bloquer une carte definitivement. Sans effet si id est deja contraint unique (tres
--    probable : id=eq.<valeur> est deja utilise partout comme cle de mise a jour) -- le bloc
--    EXCEPTION rend cette migration sure dans tous les cas.
DO $$
BEGIN
  ALTER TABLE impacts_indices_attente ADD CONSTRAINT impacts_indices_attente_id_unique UNIQUE (id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
