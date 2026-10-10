-- BANC DU CREDIT SOCIAL D'UNE TOURNEE
-- Chantier 5, chaine 5 -- verification demandee au lot du 10 octobre 2026.
--
-- Une transaction annulee, aucune donnee residuelle, verdict leve en EXCEPTION.
--
-- CE QU'IL ETABLIT, et ce sont exactement les trois demandes du lot :
--
--   1. L'ORGANISATEUR NE CHOISIT PAS SES BENEFICIAIRES. `tournee_cloturer` n'a AUCUN parametre de
--      liste : elle a deux arguments, l'identifiant de la tournee et « servie ou non ». Les
--      beneficiaires sont lus en base -- `invitations_diner` de CETTE tournee, statut `acceptee`.
--      L'epreuve 3 verifie la signature (deux arguments, pas trois) ; l'epreuve 6 verifie qu'un
--      invite ayant REFUSE n'est pas credite, et l'epreuve 1 qu'un tiers ne clot rien du tout.
--
--   2. LE BONUS NE SE DUPLIQUE PAS PAR REJEU. La cloture est un compare-and-swap sur
--      `statut = 'en_resolution'`, et les invitations sont purgees dans la meme transaction : le
--      second appel rend `pas_en_resolution` et les caracteristiques ne bougent plus (epreuves 8
--      et 9).
--
--   3. LE SERVEUR APPLIQUE LA REGLE EXISTANTE, A L'IDENTIQUE : +2 moral et +1 ENT, le moral borne
--      a 100 et l'ENT a 20 -- et le +1 ENT n'est pose QUE sous 20 (epreuves 5, 10, 11). Une
--      tournee NON servie ne credite personne (epreuve 12).
--
-- LE PIEGE RENCONTRE EN ECRIVANT CE BANC, et il est deja consigne dans WORKFLOW-SUPABASE.md :
-- `pg_get_function_identity_arguments` rend les NOMS des parametres, pas seulement leurs types.
-- La premiere version de l'epreuve 3 comparait a `'text, boolean'` et tombait alors que la
-- signature etait juste. On compare donc `pronargs`.
--
-- COMMENT IL A REELLEMENT TOURNE. Tel quel sous psql. Par le canal MCP de ce depot, qui plafonne
-- a ~12 500 caracteres de SQL, il a ete envoye DEBARRASSE DE SES LIGNES DE COMMENTAIRE.
BEGIN;
DO $banc$
DECLARE
  ko text[] := '{}'; n integer := 0; v jsonb; m integer; e numeric; c integer;
  BEN constant text := '{"sub":"bafc96b1-1628-4ae2-93d2-78d89f8ac5b5","role":"authenticated"}';
  MAY constant text := '{"sub":"3d91b1fa-a22d-41ae-82cf-fef98194b10a","role":"authenticated"}';
  TR constant text := 'zzbanc-tournee';
BEGIN
  PERFORM set_config('role','postgres',true);
  DELETE FROM public.invitations_diner WHERE tournee_id = TR;
  DELETE FROM public.tournees WHERE id = TR;
  -- May organise ; Ben a ACCEPTE ; Marsault a REFUSE ; Lee Capene est au plafond des deux bornes.
  INSERT INTO public.tournees (id, country, ville, offreur, building_id, commerce_type,
    recette_id, prix_unitaire_reference, statut, pa_debite, expires_at)
  VALUES (TR, 'republic', 'ville_a', 'May', 'zzbanc-bar', 'bar', 'biere', 10, 'en_resolution', false,
          now() + interval '1 day');
  INSERT INTO public.invitations_diner (inviteur, invite, country, city, building_id, room_id,
    statut, cout, type, tournee_id) VALUES
    ('May','Ben','republic','ville_a','zzbanc-bar','salle','acceptee',0,'tournee',TR),
    ('May','Marsault','republic','ville_a','zzbanc-bar','salle','refusee',0,'tournee',TR);
  UPDATE public.personnages_donnees SET moral = 50,
    stats = coalesce(stats,'{}'::jsonb) || '{"ENT":5}'::jsonb WHERE name = 'Ben';
  UPDATE public.personnages_donnees SET moral = 50,
    stats = coalesce(stats,'{}'::jsonb) || '{"ENT":5}'::jsonb WHERE name = 'Marsault';
  UPDATE public.personnages_donnees SET moral = 99,
    stats = coalesce(stats,'{}'::jsonb) || '{"ENT":20}'::jsonb WHERE name = 'Lee Capene';

  -- 1 et 2. UN INVITE N'EST PAS L'OFFREUR.
  PERFORM set_config('request.jwt.claims', BEN, true);
  PERFORM set_config('role','authenticated',true);
  v := public.tournee_cloturer(TR, true);
  n := n+1; IF v->>'raison' <> 'pas_mon_offre' THEN ko := ko||('1 un invite clot la tournee : '||v::text); END IF;
  PERFORM set_config('role','postgres',true);
  SELECT moral INTO m FROM public.personnages_donnees WHERE name='Ben';
  n := n+1; IF m <> 50 THEN ko := ko||('2 un credit a eu lieu malgre le refus : moral='||m); END IF;

  -- 3. LA LISTE DES BENEFICIAIRES N'EST PAS UN PARAMETRE.
  n := n+1; IF (SELECT pronargs FROM pg_proc p JOIN pg_namespace ns ON ns.oid=p.pronamespace
                 WHERE ns.nspname='public' AND p.proname='tournee_cloturer') <> 2
    THEN ko := ko||('3 tournee_cloturer n a plus exactement deux parametres'::text); END IF;

  -- 4 a 7. L'OFFREUR CLOT, ET SEULS LES INVITES QUI ONT ACCEPTE SONT CREDITES.
  PERFORM set_config('request.jwt.claims', MAY, true);
  PERFORM set_config('role','authenticated',true);
  v := public.tournee_cloturer(TR, true);
  n := n+1; IF NOT (v->>'ok'='true' AND (v->>'credites')::integer = 1)
    THEN ko := ko||('4 la cloture ne credite pas exactement un invite : '||v::text); END IF;
  PERFORM set_config('role','postgres',true);
  SELECT moral, (stats->>'ENT')::numeric INTO m, e FROM public.personnages_donnees WHERE name='Ben';
  n := n+1; IF NOT (m = 52 AND e = 6) THEN ko := ko||('5 la regle plus2 moral plus1 ENT n est pas appliquee : moral='||m||' ENT='||e); END IF;
  SELECT moral, (stats->>'ENT')::numeric INTO m, e FROM public.personnages_donnees WHERE name='Marsault';
  n := n+1; IF NOT (m = 50 AND e = 5) THEN ko := ko||('6 un invite qui a REFUSE a ete credite : moral='||m); END IF;
  SELECT count(*) INTO c FROM public.invitations_diner WHERE tournee_id = TR;
  n := n+1; IF c <> 0 THEN ko := ko||('7 les invitations ne sont pas purgees : '||c); END IF;

  -- 8 et 9. LE REJEU NE CREDITE PERSONNE DEUX FOIS.
  PERFORM set_config('role','authenticated',true);
  v := public.tournee_cloturer(TR, true);
  n := n+1; IF NOT (v->>'raison' = 'pas_en_resolution' AND v->>'statut' = 'resolue')
    THEN ko := ko||('8 le rejeu de la cloture est accepte : '||v::text); END IF;
  PERFORM set_config('role','postgres',true);
  SELECT moral, (stats->>'ENT')::numeric INTO m, e FROM public.personnages_donnees WHERE name='Ben';
  n := n+1; IF NOT (m = 52 AND e = 6) THEN ko := ko||('9 le rejeu a credite une seconde fois : moral='||m||' ENT='||e); END IF;

  -- 10 et 11. LES DEUX BORNES DE LA REGLE EXISTANTE.
  DELETE FROM public.tournees WHERE id = TR;
  INSERT INTO public.tournees (id, country, ville, offreur, building_id, commerce_type,
    recette_id, prix_unitaire_reference, statut, pa_debite, expires_at)
  VALUES (TR, 'republic', 'ville_a', 'May', 'zzbanc-bar', 'bar', 'biere', 10, 'en_resolution', false,
          now() + interval '1 day');
  INSERT INTO public.invitations_diner (inviteur, invite, country, city, building_id, room_id,
    statut, cout, type, tournee_id) VALUES
    ('May','Lee Capene','republic','ville_a','zzbanc-bar','salle','acceptee',0,'tournee',TR);
  PERFORM set_config('role','authenticated',true);
  v := public.tournee_cloturer(TR, true);
  PERFORM set_config('role','postgres',true);
  SELECT moral, (stats->>'ENT')::numeric INTO m, e FROM public.personnages_donnees WHERE name='Lee Capene';
  n := n+1; IF m <> 100 THEN ko := ko||('10 le moral depasse 100 : '||m); END IF;
  n := n+1; IF e <> 20 THEN ko := ko||('11 l ENT depasse 20 : '||e); END IF;

  -- 12. UNE TOURNEE NON SERVIE NE CREDITE RIEN.
  DELETE FROM public.tournees WHERE id = TR;
  INSERT INTO public.tournees (id, country, ville, offreur, building_id, commerce_type,
    recette_id, prix_unitaire_reference, statut, pa_debite, expires_at)
  VALUES (TR, 'republic', 'ville_a', 'May', 'zzbanc-bar', 'bar', 'biere', 10, 'en_resolution', false,
          now() + interval '1 day');
  INSERT INTO public.invitations_diner (inviteur, invite, country, city, building_id, room_id,
    statut, cout, type, tournee_id) VALUES
    ('May','Marsault','republic','ville_a','zzbanc-bar','salle','acceptee',0,'tournee',TR);
  PERFORM set_config('role','authenticated',true);
  v := public.tournee_cloturer(TR, false);
  PERFORM set_config('role','postgres',true);
  SELECT moral INTO m FROM public.personnages_donnees WHERE name='Marsault';
  n := n+1; IF NOT (v->>'ok'='true' AND (v->>'credites')::integer = 0 AND m = 50)
    THEN ko := ko||('12 une tournee NON servie a credite : '||v::text||' moral='||m); END IF;

  DELETE FROM public.invitations_diner WHERE tournee_id = TR;
  DELETE FROM public.tournees WHERE id = TR;
  IF array_length(ko,1) IS NULL THEN
    RAISE EXCEPTION 'LES % EPREUVES DU CREDIT DE TOURNEE SONT VERTES.', n;
  ELSE
    RAISE EXCEPTION E'ECHEC : % epreuve(s) sur % en defaut.\n  %', array_length(ko,1), n, array_to_string(ko, E'\n  ');
  END IF;
END $banc$;
ROLLBACK;
