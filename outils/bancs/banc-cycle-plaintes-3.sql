-- BANC DU CYCLE DE VIE D'UNE AFFAIRE -- 3/3 : LA PREROGATIVE DU MINISTRE DE LA JUSTICE
-- Chantier 5 (10 octobre 2026), REECRIT DANS LA NUIT DU 12 OCTOBRE 2026 par la tranche du parquet.
--
-- Une transaction annulee, aucune donnee residuelle, verdict leve en EXCEPTION. Voir le fichier 1
-- pour la raison du decoupage en trois (limite de transport du canal SQL).
--
-- POURQUOI CE FICHIER A CHANGE DE SUJET. Il eprouvait `plainte_classer_ministere`, le classement
-- sans suite ministeriel. CETTE FONCTION N'EXISTE PLUS : elle a ete SUPPRIMEE par la migration
-- 20261012092828, et l'ordre `annuler_poursuites` qui l'appelait a quitte `ordres_couts` par la
-- 20261012094344. La raison n'est pas une simplification, c'est la regle d'arret du chantier :
-- l'opportunite des poursuites ne peut pas appartenir a DEUX autorites. Elle appartient au
-- Procureur de la Republique -- qui prononce le non-lieu, engage les poursuites, saisit le juge
-- et peut abandonner -- et le Ministre de la Justice garde la seule prerogative qui soit la
-- sienne : NOMMER ET REVOQUER CE PROCUREUR. Un ministre qui classait lui-meme les dossiers
-- n'avait pas besoin de parquet.
--
-- UN BANC DONT LE SUJET A DISPARU DOIT CHANGER DE SUJET, PAS MOURIR. Le nouveau prouve la
-- substitution complete : l'ancienne porte n'est plus au catalogue, son cout n'est plus declare,
-- le ministre n'a plus AUCUN chemin vers le dossier -- ni par `plainte_traiter`, ni par le
-- parquet, ni par l'ecriture directe -- et la prerogative qui le remplace FONCTIONNE : il nomme,
-- et il revoque.
--
-- LA CONTRE-EPREUVE DE L'ANCIEN CHEMIN EST CONSERVEE MOT POUR MOT, et elle garde toute sa valeur.
-- Avant le registre 634, l'UPDATE client qui posait `status: 'annulee'` touchait 0 ligne EN
-- SILENCE : la policy n'avait que deux branches -- autorite judiciaire de la ville, ou affaire qui
-- me concerne -- et le ministre n'etait ni l'une ni l'autre. Les 250 FR quittaient la caisse et la
-- plainte restait ouverte, a chaque fois. Depuis que INSERT et UPDATE sont revoques a
-- `authenticated` sur `plaintes_en_cours`, le meme UPDATE LEVE `42501 permission denied`. On
-- attrape ce refus-la et lui seul -- jamais `others`, qui ferait passer l'epreuve sur une faute de
-- frappe ou une table absente -- et c'est l'ABSENCE d'exception qui est l'echec.
--
-- COMMENT IL A REELLEMENT TOURNE. Tel quel sous psql. Par le canal MCP de ce depot, qui plafonne
-- a ~12 500 caracteres de SQL, il a ete envoye DEBARRASSE DE SES LIGNES DE COMMENTAIRE -- le code
-- execute est donc exactement celui de ce fichier, aux commentaires pres :
--     python3 -c "print('\n'.join(l for l in open('<ce fichier>').read().split('\n') if l.strip() and not l.strip().startswith('--')))"
BEGIN;
DO $banc$
DECLARE
  ko text[] := '{}'; n integer := 0;
  v jsonb; d jsonb; c integer; v_par text; v_dest text;
  -- Vrai quand l'ecriture cliente directe a bien ete refusee par le PRIVILEGE (registre 634).
  v_refuse boolean;
  BEN constant text := '{"sub":"bafc96b1-1628-4ae2-93d2-78d89f8ac5b5","role":"authenticated"}';
  AFF constant text := 'aff-may';
  NOMME constant text := 'Lee Capene';
BEGIN
  PERFORM set_config('role', 'postgres', true);
  DELETE FROM public.plaintes_en_cours;
  INSERT INTO public.plaintes_en_cours (id, country, city, data) VALUES
    (AFF, 'republic', 'ville_a',
     '{"id":"aff-may","country":"republic","city":"ville_a","cible":"May","motif":"Vol","jour":1,"status":"au_parquet"}');

  -- ------------------------------------------------- 1. L'ANCIENNE PORTE N'EST PLUS LA
  SELECT count(*) INTO c FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
   WHERE ns.nspname = 'public' AND p.proname = 'plainte_classer_ministere';
  n := n + 1; IF c <> 0
    THEN ko := ko || ('1 plainte_classer_ministere existe encore : ' || c || ' signature(s)'); END IF;

  SELECT count(*) INTO c FROM public.ordres_couts o WHERE o.fn = 'annuler_poursuites';
  n := n + 1; IF c <> 0
    THEN ko := ko || '2 l ordre annuler_poursuites est encore declare au miroir des couts'; END IF;

  -- ------------------------------------------------- 2. QUI NOMME LE PROCUREUR
  UPDATE public.personnages_donnees SET poste = NULL WHERE name = 'Ben';
  PERFORM set_config('request.jwt.claims', BEN, true);
  PERFORM set_config('role', 'authenticated', true);
  v := public.poste_nommer('procureur', NULL, NOMME);
  n := n + 1; IF v ->> 'raison' <> 'autorite_insuffisante'
    THEN ko := ko || ('3 un simple joueur nomme le Procureur : ' || v::text); END IF;

  -- Un commissaire n'est pas davantage ministre : l'autorite est le PORTEFEUILLE, pas la robe.
  PERFORM set_config('role', 'postgres', true);
  UPDATE public.personnages_donnees SET poste = '{"id":"commissaire","city":"ville_a"}'::jsonb WHERE name = 'Ben';
  PERFORM set_config('role', 'authenticated', true);
  v := public.poste_nommer('procureur', NULL, NOMME);
  n := n + 1; IF v ->> 'raison' <> 'autorite_insuffisante'
    THEN ko := ko || ('4 le commissaire nomme le Procureur : ' || v::text); END IF;

  -- LE COMMISSAIRE QUI TENTE ENCORE DE CLASSER EST REFUSE EXPLICITEMENT, et c'est voulu : un
  -- refus nomme se voit, un refus avale ne se voit pas.
  v := public.plainte_traiter(AFF, 'classer');
  n := n + 1; IF v ->> 'raison' <> 'classement_reserve_au_parquet'
    THEN ko := ko || ('5 le commissaire classe encore sans suite : ' || v::text); END IF;

  -- ------------------------------------------------- 3. LE MINISTRE EN EXERCICE
  PERFORM set_config('role', 'postgres', true);
  UPDATE public.personnages_donnees SET poste = '{"id":"min_just"}'::jsonb WHERE name = 'Ben';
  PERFORM set_config('role', 'authenticated', true);

  -- L'AUTORITE EST DECLAREE EN BASE, PAS DANS LE CODE : une LIGNE de postes_nommes_regles.
  SELECT a.autorite, a.scope INTO v_par, v_dest FROM public.poste_autorite_de('procureur', NULL) a;
  n := n + 1; IF v_par <> 'min_just' OR v_dest <> 'pays'
    THEN ko := ko || ('6 l autorite declaree du parquet : ' || coalesce(v_par,'(nul)')
                      || ' / ' || coalesce(v_dest,'(nul)')); END IF;

  v := public.poste_nommer('procureur', NULL, NOMME);
  n := n + 1; IF v ->> 'decision' <> 'proposition_envoyee'
    THEN ko := ko || ('7 le ministre ne peut pas nommer le Procureur : ' || v::text); END IF;
  PERFORM set_config('role', 'postgres', true);
  SELECT count(*) INTO c FROM public.nominations_en_attente
   WHERE poste_id = 'procureur' AND destinataire = NOMME AND par = 'Ben' AND traitee IS FALSE;
  n := n + 1; IF c <> 1
    THEN ko := ko || ('8 la proposition n est pas EN BASE au nom du ministre : ' || c || ' ligne(s)'); END IF;

  -- ------------------------------------------------- 4. ET AUCUN CHEMIN VERS LE DOSSIER
  PERFORM set_config('role', 'authenticated', true);
  v := public.plainte_traiter(AFF, 'classer');
  n := n + 1; IF v ->> 'raison' <> 'autorite_insuffisante'
    THEN ko := ko || ('9 le ministre atteint le dossier par plainte_traiter : ' || v::text); END IF;
  v := public.parquet_non_lieu(AFF, 'Je prefere en rester la');
  n := n + 1; IF v ->> 'raison' <> 'pas_procureur'
    THEN ko := ko || ('10 le ministre prononce un non-lieu : ' || v::text); END IF;
  PERFORM set_config('role', 'postgres', true);
  SELECT data::jsonb INTO d FROM public.plaintes_en_cours WHERE id = AFF;
  n := n + 1; IF d ->> 'status' <> 'au_parquet'
    THEN ko := ko || ('11 le dossier a bouge malgre les refus : ' || d::text); END IF;

  -- ------------------------------------------------- 5. CONTRE-EPREUVE DE L'ANCIEN CHEMIN
  PERFORM set_config('request.jwt.claims', BEN, true);
  PERFORM set_config('role', 'authenticated', true);
  v_refuse := false;
  BEGIN
    UPDATE public.plaintes_en_cours
       SET data = (data::jsonb || '{"status":"annulee"}'::jsonb)::text
     WHERE id = AFF;
  EXCEPTION WHEN insufficient_privilege THEN v_refuse := true;
  END;
  n := n + 1; IF NOT v_refuse THEN
    ko := ko || ('12 L ECRITURE CLIENTE DIRECTE EST ENCORE POSSIBLE : l ecriture ministerielle n a '
      || 'pas ete refusee par le privilege -- les 250 FR partaient pour rien');
  END IF;
  PERFORM set_config('role', 'postgres', true);
  SELECT data::jsonb INTO d FROM public.plaintes_en_cours WHERE id = AFF;
  n := n + 1; IF d ->> 'status' <> 'au_parquet' THEN
    ko := ko || ('13 la plainte a change de statut par l ancien chemin : ' || d::text);
  END IF;

  -- ------------------------------------------------- 6. CE QUI RESTE AU MINISTRE : REVOQUER
  PERFORM set_config('role', 'authenticated', true);
  v := public.poste_revoquer('procureur', NULL);
  n := n + 1; IF v ->> 'decision' <> 'pnj_revoque'
    THEN ko := ko || ('14 le ministre ne peut pas revoquer le Procureur : ' || v::text); END IF;
  PERFORM set_config('role', 'postgres', true);
  SELECT count(*) INTO c FROM public.titulaires_pnj
   WHERE country = 'republic' AND poste_id = 'procureur';
  n := n + 1; IF c <> 0
    THEN ko := ko || ('15 le titulaire PNJ du parquet survit a sa revocation : ' || c || ' ligne(s)'); END IF;

  IF array_length(ko, 1) IS NULL THEN
    RAISE EXCEPTION 'LES % EPREUVES DE LA PREROGATIVE MINISTERIELLE SONT VERTES.', n;
  ELSE
    RAISE EXCEPTION E'ECHEC : % epreuve(s) sur % en defaut.\n  %',
      array_length(ko, 1), n, array_to_string(ko, E'\n  ');
  END IF;
END $banc$;
ROLLBACK;
