-- Réutilisation du registre judiciaire : gardes publiques conservées, helpers privés.
BEGIN;
DO $g$ BEGIN IF EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='justice_peine_effective_interne' AND (p.oid IS DISTINCT FROM to_regprocedure('public.justice_peine_effective_interne(jsonb,integer)') OR md5(p.prosrc)<>'0707486977794eb793ba39676dde0f1c')) THEN RAISE EXCEPTION 'definition_non_examinee: justice_peine_effective_interne';END IF;END;$g$;
DO $g$ BEGIN IF EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='justice_condamnation_poser_interne' AND (p.oid IS DISTINCT FROM to_regprocedure('public.justice_condamnation_poser_interne(text,jsonb,text,text,text)') OR md5(p.prosrc)<>'3eb7196cad84084c528eae5f8ae8f0df')) THEN RAISE EXCEPTION 'definition_non_examinee: justice_condamnation_poser_interne';END IF;END;$g$;
DO $g$ DECLARE h text;BEGIN SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.justice_condamner(text,jsonb)');IF h IS NULL OR h NOT IN('b12a960c7c51ca6a5e53b8cdeb61266c','88014c8521a5408f512a7055ad95f81c') THEN RAISE EXCEPTION 'definition_non_examinee: justice_condamner';END IF;END;$g$;
DO $g$ DECLARE h text;BEGIN SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.justice_recherches(text)');IF h IS NULL OR h NOT IN('cf59bce0728d889c21a8be912a8d9340','db9466386fa9c0bee93aa4e6bb912a27') THEN RAISE EXCEPTION 'definition_non_examinee: justice_recherches';END IF;END;$g$;
DO $g$ DECLARE h text;BEGIN SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.justice_executer_condamnation(text,text)');IF h IS NULL OR h NOT IN('cb4eeecfc22f4a0ec8aa27f19a78e1f6','1362571c3e469fdd7161ce3dec8f99c3') THEN RAISE EXCEPTION 'definition_non_examinee: justice_executer_condamnation';END IF;END;$g$;
CREATE OR REPLACE FUNCTION public.justice_peine_effective_interne(d jsonb,repli integer) RETURNS integer
LANGUAGE plpgsql IMMUTABLE SET search_path=public,pg_temp AS $f$
DECLARE reliquat numeric;jours integer;
BEGIN
 IF d->>'reliquat_jours' IS NOT NULL THEN
  reliquat:=(d->>'reliquat_jours')::numeric;
  IF reliquat<0 OR reliquat<>trunc(reliquat) OR reliquat::text IN('NaN','Infinity','-Infinity') THEN RAISE EXCEPTION 'reliquat_invalide' USING ERRCODE='22023';END IF;
  jours:=reliquat::integer+coalesce((SELECT (x.value->>'jours')::integer FROM jsonb_array_elements(coalesce(d->'motifs','[]')) WITH ORDINALITY x(value,numero) WHERE x.value->>'source'='evasion' ORDER BY x.numero LIMIT 1),0);
 ELSE SELECT coalesce(sum((m->>'jours')::integer),0) INTO jours FROM jsonb_array_elements(coalesce(d->'motifs','[]')) m;END IF;
 RETURN CASE WHEN jours<=0 THEN repli ELSE jours END;
END;$f$;
REVOKE ALL ON FUNCTION public.justice_peine_effective_interne(jsonb,integer) FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.justice_condamnation_poser_interne(p_cible text,p_entree jsonb,v_pays text,v_ville text,v_juge text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE v_jours integer;v_id text;
BEGIN
  v_jours:=public.justice_peine_effective_interne(p_entree,0);

  v_id := coalesce(nullif(p_entree->>'id', ''),
                   'rech-' || (extract(epoch from clock_timestamp())*1000)::bigint || '-'
                     || substr(md5(random()::text), 1, 6));

  INSERT INTO public.jugements (id, country, city, accuse, motif, peine, juge, jour, executee, data)
  VALUES (v_id, v_pays, v_ville, p_cible,
          coalesce(p_entree #>> '{motifs,0,type}', 'Condamnation'),
          v_jours::text || ' jours', v_juge,
          coalesce((p_entree->>'jour_affaire')::int, 0), false,
          p_entree || jsonb_build_object('id', v_id))
  ON CONFLICT (id) DO NOTHING;

  IF NOT EXISTS(SELECT 1 FROM public.jugements WHERE id=v_id AND accuse=p_cible AND country IS NOT DISTINCT FROM v_pays AND city IS NOT DISTINCT FROM v_ville AND data=p_entree||jsonb_build_object('id',v_id)) THEN RAISE EXCEPTION 'condamnation_non_confirmee';END IF;
  RETURN jsonb_build_object('ok', true, 'id', v_id, 'accuse', p_cible, 'jours', v_jours);
END;$f$;
REVOKE ALL ON FUNCTION public.justice_condamnation_poser_interne(text,jsonb,text,text,text) FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.justice_condamner(p_cible text, p_entree jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_juge text; v_id text; v_pays text; v_ville text; v_jours integer;
        v_aff text; v_brut text; v_a jsonb; v_aff_ville text; v_statut text; v_jl record;
BEGIN
  v_juge := public.exiger_poste('juge');
  IF v_juge IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF p_entree IS NULL OR jsonb_typeof(p_entree) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'entree_invalide');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = p_cible) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_introuvable');
  END IF;

  -- ===========================================================================================
  -- UNE CONDAMNATION JUDICIAIRE NOMME SON AFFAIRE, ET SON AFFAIRE A EU SON PROCES (13 oct. 2026)
  -- ===========================================================================================
  -- Cette porte est celle par laquelle la SANCTION tombe : `appliquerSentence` l'appelle AVANT
  -- `justice_rendre_sentence`, qui ne fait qu'archiver. Elle n'exigeait que le poste de juge.
  -- Un juge pouvait donc inscrire au registre une peine de n'importe quelle duree, sur
  -- n'importe quelle personne, hors de toute affaire, hors de tout barreme et hors de toute
  -- audience -- et `jugements` non executee EST l'avis de recherche.
  --
  -- CE QUI EST EXIGE MAINTENANT, et uniquement pour le genre qui est un jugement : l'entree de
  -- `type` 'condamnation' doit NOMMER son affaire, l'affaire doit exister, etre au statut ou un
  -- jugement complet se rend, avoir son audience OUVERTE, et l'appelant doit etre le juge DE SA
  -- VILLE -- la regle d'autorite des trois autres portes, qui manquait ici.
  --
  -- CE QUI RESTE OUVERT, EXPRES : le mandat du DESERTEUR (`type` 'militaire'), qui ne juge rien
  -- et n'attache aucune peine, et tout autre genre futur. Le verrou nomme son genre ; il ne
  -- decide pas a la place du game design ce que les autres deviennent.
  IF coalesce(p_entree ->> 'type', '') = 'condamnation' THEN
    v_aff := nullif(btrim(coalesce(p_entree ->> 'affaire_id', '')), '');
    IF v_aff IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'condamnation_sans_affaire');
    END IF;
    SELECT p.data, p.city INTO v_brut, v_aff_ville
      FROM public.plaintes_en_cours p WHERE p.id = v_aff;
    IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente', 'affaire', v_aff);
    END IF;
    v_a := v_brut::jsonb;
    SELECT * INTO v_jl FROM public.juge_de_la_ville(v_aff_ville);
    IF v_jl.nom IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_juge_de_cette_ville',
                                'ville', v_aff_ville);
    END IF;
    -- LA CIBLE EST CELLE DE L'AFFAIRE, pas une personne choisie a cote du dossier.
    IF coalesce(v_a ->> 'cible', '') IS DISTINCT FROM p_cible THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'cible_etrangere_a_l_affaire',
                                'affaire', v_aff);
    END IF;
    v_statut := coalesce(v_a ->> 'status', '');
    -- `saisie` : premiere instance. `appel` : le second examen, qui est aussi un jugement complet.
    IF v_statut NOT IN ('saisie', 'appel') THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'affaire_non_saisie', 'statut', v_statut);
    END IF;
    IF NOT public.affaire_audience_ouverte(v_a) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'audience_non_ouverte', 'affaire', v_aff);
    END IF;
  END IF;

  SELECT coalesce(p_entree->>'country', country), coalesce(p_entree->>'ville_condamnation', current_city)
    INTO v_pays, v_ville FROM public.personnages_donnees WHERE name = v_juge;
  RETURN public.justice_condamnation_poser_interne(p_cible,p_entree,v_pays,v_ville,v_juge);
END; $function$;
CREATE OR REPLACE FUNCTION public.justice_recherches(p_nom text)
 RETURNS TABLE(id text, country text, ville_condamnation text, motif text, jours integer, data jsonb)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_autorise boolean := false;
BEGIN
  IF public.est_appel_serveur() THEN
    v_autorise := true;
  ELSE
    v_moi := public.mon_personnage();
    IF v_moi IS NOT NULL THEN
      -- Soi-meme : un joueur peut savoir qu'il est recherche.
      IF v_moi = p_nom THEN
        v_autorise := true;
      ELSE
        -- Autorite judiciaire, dans son propre pays.
        SELECT true INTO v_autorise
          FROM public.acteur_poste_courant() a
          JOIN public.personnages_donnees c ON c.name = p_nom
         WHERE a.poste_id IN ('commissaire','juge','min_just','min_int','president')
           AND a.pays = c.country
         LIMIT 1;
      END IF;
    END IF;
  END IF;

  IF NOT coalesce(v_autorise, false) THEN RETURN; END IF;

  -- `motif_allegue` EST RETIRE DE CE QUI SORT (13 octobre 2026). C'est le texte libre du
  -- plaignant, recopie sur la condamnation depuis le dossier : il n'a rien a faire sur un avis de
  -- recherche, que l'autorite lit pour savoir QUI chercher, pour QUELLE qualification, OU et
  -- pour COMBIEN de jours. Le retrait est inconditionnel -- meme pour la personne recherchee
  -- elle-meme, qui lit le texte du plaignant sur SON dossier par sa propre porte, pas ici.
  RETURN QUERY
    SELECT j.id, j.country, j.city, j.motif,
           public.justice_peine_effective_interne(j.data,0),
           (j.data - 'motif_allegue')
      FROM public.jugements j
     WHERE j.accuse = p_nom AND j.executee = false
     ORDER BY j.created_at;
END;
$function$;
CREATE OR REPLACE FUNCTION public.justice_executer_condamnation(p_jugement_id text, p_ville text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_acteur text; v_j record; v_jours integer; v_motif text; v_res jsonb; v_det record;v_reliquat numeric;
BEGIN
  v_acteur := public.exiger_poste('commissaire');
  IF v_acteur IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  -- Verrou : deux executions simultanees de la meme condamnation ne peuvent pas coexister.
  SELECT * INTO v_j FROM public.jugements WHERE id = p_jugement_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'condamnation_introuvable');
  END IF;
  IF v_j.executee THEN
    RETURN jsonb_build_object('ok', true, 'deja_executee', true, 'accuse', v_j.accuse);
  END IF;

  -- Deja detenu : la peine s'ajoute a la detention en cours plutot que d'en ouvrir une seconde.
  SELECT * INTO v_det FROM public.detention_active(v_j.accuse);
  IF v_det.id IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_deja_detenue');
  END IF;

  BEGIN v_jours:=public.justice_peine_effective_interne(v_j.data,3);EXCEPTION WHEN SQLSTATE '22023' THEN RETURN jsonb_build_object('ok',false,'raison','reliquat_invalide');END;
  v_motif := coalesce(v_j.motif, 'Avis de recherche');

  v_res := public.detention_ouvrir_interne(
             v_j.accuse, v_motif, v_jours, coalesce(p_ville, v_j.city), v_j.country,
             coalesce(v_j.data->'motifs', '[]'::jsonb), v_acteur,
             coalesce(v_j.data->>'issue_judiciaire', 'condamnation_executee'),
             jsonb_build_object('ville_condamnation',v_j.city,'jour_affaire',v_j.data->'jour_affaire',
               'detention_precedente_id',v_j.data->'detention_precedente_id','reliquat_jours',v_j.data->'reliquat_jours'));
  IF NOT coalesce((v_res->>'ok')::boolean, false) THEN
    RETURN v_res;
  END IF;

  UPDATE public.jugements SET executee = true WHERE id = p_jugement_id;
  IF nullif(v_res->>'detention_id','') IS NULL
     OR NOT EXISTS(SELECT 1 FROM public.jugements WHERE id=p_jugement_id AND executee IS TRUE)
     OR NOT EXISTS(SELECT 1 FROM public.detentions d WHERE d.id=v_res->>'detention_id' AND d.nom=v_j.accuse AND d.city=coalesce(p_ville,v_j.city) AND d.country IS NOT DISTINCT FROM v_j.country AND d.mode_fin IS NULL AND d.jour_fin_effective IS NULL AND d.date_fin_effective IS NULL)
     OR (EXISTS(SELECT 1 FROM public.personnages_donnees p WHERE p.name=v_j.accuse) AND NOT EXISTS(SELECT 1 FROM public.personnages_donnees p WHERE p.name=v_j.accuse AND p.est_emprisonne->>'detentionId'=v_res->>'detention_id')) THEN
    RAISE EXCEPTION 'execution_condamnation_non_confirmee';
  END IF;


  RETURN jsonb_build_object('ok', true, 'accuse', v_j.accuse, 'jours', v_jours,
                            'detention_id', v_res->>'detention_id', 'motif', v_motif);
END; $function$;
COMMIT;
