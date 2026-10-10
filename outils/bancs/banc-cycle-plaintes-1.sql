-- BANC DU CYCLE DE VIE D'UNE AFFAIRE -- 1/3 : LA TRANSMISSION AU TRIBUNAL
-- Chantier 5, les trois `sbSavePlainte` avales (10 octobre 2026).
--
-- COMMENT LE LANCER. Tout tient dans UNE transaction annulee : rien de ce que ce banc ecrit ne
-- survit, et il ne laisse aucune donnee residuelle. Le verdict est leve en EXCEPTION -- c'est
-- l'exception qui annonce le compte ET qui annule la transaction, sans quoi un banc vert
-- commiterait ses propres effets de bord.
--
-- CE QU'IL ETABLIT. `affaire_transmettre` remplace l'INSERT client de
-- `transmettreAffaireAuTribunal`, dont l'identifiant etait `'affaire-' || Date.now()` : la
-- juridiction, l'identifiant derive, le rejeu, les refus nommes et le voyage des quatre
-- metadonnees du fait demasque.
--
-- LA CONTRE-EPREUVE de cette porte -- l'ancien chemin refait a l'identique, qui cree bien deux
-- affaires pour le meme acte -- est dans le fichier 2, avec la defense. Le banc est decoupe en
-- TROIS fichiers pour une raison purement technique : la limite de transport du canal SQL
-- (~12 500 caracteres), constatee six fois sur ce chantier.
--
-- COMMENT IL A REELLEMENT TOURNE. Tel quel sous psql. Par le canal MCP de ce depot, qui plafonne
-- a ~12 500 caracteres de SQL, il a ete envoye DEBARRASSE DE SES LIGNES DE COMMENTAIRE -- le code
-- execute est donc exactement celui de ce fichier, aux commentaires pres :
--     python3 -c "print('\n'.join(l for l in open('<ce fichier>').read().split('\n') if l.strip() and not l.strip().startswith('--')))"
BEGIN;
DO $banc$
DECLARE
  ko text[] := '{}'; n integer := 0;
  v jsonb; v1 jsonb; v2 jsonb; c integer; d jsonb;
  BEN constant text := '{"sub":"bafc96b1-1628-4ae2-93d2-78d89f8ac5b5","role":"authenticated"}';
  v_poste constant jsonb := '{"id":"commissaire","city":"ville_a"}'::jsonb;
  FAIT constant jsonb := '{"victime":"May","jourFait":7,"refType":"action_tracee","refId":"act-77"}'::jsonb;
BEGIN
  PERFORM set_config('role', 'postgres', true);

  -- ---------------------------------------------------------------- 1. SANS AUTORITE, RIEN
  PERFORM set_config('request.jwt.claims', BEN, true);
  PERFORM set_config('role', 'authenticated', true);
  v := public.affaire_transmettre('May', 'Vol aggrave', 'ville_a', NULL);
  n := n + 1; IF NOT (v ->> 'ok' = 'false' AND v ->> 'raison' = 'autorite_refusee')
    THEN ko := ko || ('1 un simple joueur transmet au tribunal : ' || v::text); END IF;
  PERFORM set_config('role', 'postgres', true);
  SELECT count(*) INTO c FROM public.plaintes_en_cours;
  n := n + 1; IF c <> 0 THEN ko := ko || ('2 une affaire a ete creee sans autorite : ' || c); END IF;

  -- ---------------------------------------------------------------- 2. LE COMMISSAIRE DE LA VILLE
  UPDATE public.personnages_donnees SET poste = v_poste WHERE name = 'Ben';
  PERFORM set_config('role', 'authenticated', true);
  v1 := public.affaire_transmettre('May', 'Vol aggrave', 'ville_a', NULL);
  n := n + 1; IF NOT (v1 ->> 'ok' = 'true' AND v1 ->> 'deja_transmise' = 'false')
    THEN ko := ko || ('3 le commissaire de la ville ne peut pas transmettre : ' || v1::text); END IF;
  PERFORM set_config('role', 'postgres', true);
  SELECT count(*) INTO c FROM public.plaintes_en_cours;
  n := n + 1; IF c <> 1 THEN ko := ko || ('4 une transmission, ' || c || ' ligne(s)'); END IF;
  SELECT data::jsonb INTO d FROM public.plaintes_en_cours;
  n := n + 1; IF d ->> 'status' <> 'deposee'
    THEN ko := ko || ('5 l affaire ne nait pas deposee : ' || coalesce(d ->> 'status', 'NULL')); END IF;
  n := n + 1; IF d ->> 'transmise_par' <> 'Ben'
    THEN ko := ko || '6 le transmetteur n est pas nomme par le serveur'; END IF;
  -- LE PAYS ET LE JOUR NE SONT PAS DICTES : le client ne les envoie meme plus.
  n := n + 1; IF NOT (d ->> 'country' = 'republic' AND (d ->> 'jour')::integer = 1)
    THEN ko := ko || ('7 pays/jour ne viennent pas de la fiche : ' || d::text); END IF;

  -- ---------------------------------------------------------------- 3. LE REJEU NE DUPLIQUE RIEN
  PERFORM set_config('role', 'authenticated', true);
  v2 := public.affaire_transmettre('May', 'Vol aggrave', 'ville_a', NULL);
  n := n + 1; IF NOT (v2 ->> 'ok' = 'true' AND v2 ->> 'deja_transmise' = 'true')
    THEN ko := ko || ('8 le rejeu n est pas reconnu : ' || v2::text); END IF;
  n := n + 1; IF v2 ->> 'id' <> v1 ->> 'id'
    THEN ko := ko || '9 le rejeu produit un autre identifiant'; END IF;
  PERFORM set_config('role', 'postgres', true);
  SELECT count(*) INTO c FROM public.plaintes_en_cours;
  n := n + 1; IF c <> 1 THEN ko := ko || ('10 apres rejeu, ' || c || ' ligne(s) au lieu de 1'); END IF;

  -- ---------------------------------------------------------------- 4. LES REFUS NOMMES
  PERFORM set_config('role', 'authenticated', true);
  v := public.affaire_transmettre('   ', 'Vol', 'ville_a', NULL);
  n := n + 1; IF v ->> 'raison' <> 'cible_absente' THEN ko := ko || '11 cible vide acceptee'; END IF;
  v := public.affaire_transmettre('May', '  ', 'ville_a', NULL);
  n := n + 1; IF v ->> 'raison' <> 'motif_absent' THEN ko := ko || '12 motif vide accepte'; END IF;
  -- LA JURIDICTION EST CELLE DU POSTE : le commissaire de ville_a ne transmet pas a la capitale.
  v := public.affaire_transmettre('May', 'Vol aggrave', 'capitale', NULL);
  n := n + 1; IF v ->> 'raison' <> 'autorite_refusee'
    THEN ko := ko || ('13 transmission hors juridiction acceptee : ' || v::text); END IF;

  -- ---------------------------------------------------------------- 5. LE FAIT DEMASQUE VOYAGE
  v := public.affaire_transmettre('May', 'Assassinat', 'ville_a', FAIT);
  n := n + 1; IF NOT (v ->> 'ok' = 'true'
      AND (v -> 'affaire' ->> 'victime') = 'May'
      AND (v -> 'affaire' ->> 'jourFait') = '7'
      AND (v -> 'affaire' ->> 'refType') = 'action_tracee'
      AND (v -> 'affaire' ->> 'refId') = 'act-77')
    THEN ko := ko || ('14 les quatre metadonnees du fait ne voyagent pas : ' || v::text); END IF;

  -- DEUX ACTES TRACES DISTINCTS SONT DEUX AFFAIRES : la reference entre dans la cle.
  v := public.affaire_transmettre('May', 'Assassinat', 'ville_a',
         jsonb_set(FAIT, '{refId}', '"act-78"'));
  n := n + 1; IF v ->> 'deja_transmise' <> 'false'
    THEN ko := ko || '15 un second acte trace est confondu avec le premier'; END IF;
  -- ET DEUX MOTIFS DISTINCTS AUSSI.
  v := public.affaire_transmettre('May', 'Recel', 'ville_a', NULL);
  n := n + 1; IF v ->> 'deja_transmise' <> 'false'
    THEN ko := ko || '16 un autre motif est confondu avec le premier'; END IF;
  PERFORM set_config('role', 'postgres', true);
  SELECT count(*) INTO c FROM public.plaintes_en_cours;
  n := n + 1; IF c <> 4 THEN ko := ko || ('17 quatre actes distincts, ' || c || ' affaire(s)'); END IF;

  -- ---------------------------------------------------------------- 6. AUCUN SERVEUR NE TRANSMET
  PERFORM set_config('request.jwt.claims', '', true);
  PERFORM set_config('role', 'authenticated', true);
  v := public.affaire_transmettre('May', 'Vol', 'ville_a', NULL);
  n := n + 1; IF v ->> 'raison' <> 'acteur_non_authentifie'
    THEN ko := ko || ('18 un appel sans identite transmet : ' || v::text); END IF;

  IF array_length(ko, 1) IS NULL THEN
    RAISE EXCEPTION 'LES % EPREUVES DE LA TRANSMISSION SONT VERTES.', n;
  ELSE
    RAISE EXCEPTION E'ECHEC : % epreuve(s) sur % en defaut.\n  %',
      array_length(ko, 1), n, array_to_string(ko, E'\n  ');
  END IF;
END $banc$;
ROLLBACK;
