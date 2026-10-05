-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260915193552
-- Nom original      : commissariat_arrestation_urgence
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-15 19:35:52 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 1ac58ec1cf7410fce2b88276e3f5b823
--
-- ARCHIVE DOCUMENTAIRE exportee de supabase_migrations.schema_migrations.
-- Ce fichier NE FAIT PAS partie d'une chaine de reconstruction et NE DOIT
-- PAS etre rejoue, ni execute automatiquement, ni servir a installer une
-- base neuve. Voir historique/registre-supabase/README.md.
--
-- Le SQL ci-dessous est conserve INTEGRALEMENT, SANS AUCUNE MODIFICATION :
-- ni correction, ni mise en forme, ni separation des parties DDL et DML,
-- ni ajout d'idempotence. On archive ce qui s'est reellement passe.
-- ============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- COMMISSARIAT — LOT 1 : ARRESTATION D'URGENCE (refonte du 15 septembre 2026).
--
-- CE QUI EXISTAIT. L'ordre 'arreter' exigeait l'etat d'urgence (table etats_urgence : 0 ligne,
-- donc injouable), excluait le commissaire, coutait 500 FR pour rien, annoncait « +3 INF » que le
-- routeur n'appliquait jamais, et surtout ecrivait est_emprisonne sur la ligne de la CIBLE depuis
-- le navigateur : le trigger personnages_vue_modifier levait personnage_non_possede (42501), et
-- le .catch() avalait l'echec. Le jeu affichait « Arrestation executee » sans arrestation.
--
-- CE QUE CE LOT POSE. Une primitive serveur. Aucune RPC du depot ne savait mettre QUELQU'UN
-- D'AUTRE en detention -- justice_prolonger_peine allonge une peine existante, presidence_gracier
-- en leve une. C'est ce trou qui cassait aussi la chasse a l'homme et l'enquete, qui appellent
-- enregistrerDetention sur un tiers contre la policy detentions_ecriture_soi.
--
-- La primitive ecrit EXACTEMENT ce qu'ecrit enregistrerDetention cote client : meme ligne
-- detentions (motifs, autorite, issue_judiciaire...), meme objet est_emprisonne avec ses deux
-- ancres indispensables -- 'jours' et 'debutTs' pour le filet nocturne, 'jourFin' exprime dans le
-- day de LA CIBLE pour la liberation cliente, 'detentionId' pour clore le registre.

-- ---------------------------------------------------------------------------
-- Poste de l'appelant, AVEC sa ville. exiger_poste() existe deja mais ne rend que le nom et
-- ignore poste->>'city' -- or le commissaire a une competence de ville (scope:'ville'), la ou
-- president/min_int/min_just ont une competence de pays (scope:'pays').
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.acteur_poste_courant()
RETURNS TABLE (nom text, poste_id text, poste_city text, pays text)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT p.name, p.poste->>'id', p.poste->>'city', p.country
    FROM public.personnages_donnees p
   WHERE p.user_id = auth.uid()
   LIMIT 1;
$$;
REVOKE ALL ON FUNCTION public.acteur_poste_courant() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.acteur_poste_courant() TO authenticated, service_role;

-- ---------------------------------------------------------------------------
-- PRIMITIVE INTERNE : place un tiers en detention. Non exposee aux clients -- elle ne porte
-- AUCUNE regle d'autorisation, c'est a chaque RPC appelante de les poser avant.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.detention_ouvrir_interne(
  p_nom text, p_raison text, p_jours integer, p_city text, p_country text,
  p_motifs jsonb, p_autorite text, p_issue text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_id         text := 'det-' || (extract(epoch from clock_timestamp())*1000)::bigint || '-' ||
                       substr(md5(random()::text), 1, 6);
  v_jour_cible integer;
  v_deja       jsonb;
BEGIN
  SELECT coalesce(d.day, 1), d.est_emprisonne INTO v_jour_cible, v_deja
    FROM public.personnages_donnees d WHERE d.name = p_nom FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_introuvable');
  END IF;
  IF v_deja IS NOT NULL AND jsonb_typeof(v_deja) = 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_deja_detenue');
  END IF;

  INSERT INTO public.detentions (id, country, city, nom, raison, jour_debut, jour_fin, qhs,
                                 motifs, autorite, issue_judiciaire, ville_condamnation)
  VALUES (v_id, p_country, p_city, p_nom, p_raison, v_jour_cible, v_jour_cible + p_jours, false,
          p_motifs, p_autorite, p_issue, p_city);

  -- est_emprisonne : ecriture DIRECTE sur la table de base, jamais via la vue personnages --
  -- son trigger INSTEAD OF refuserait la ligne d'un tiers. Meme forme exacte qu'enregistrerDetention.
  UPDATE public.personnages_donnees
     SET est_emprisonne = jsonb_build_object(
           'jours', p_jours,
           'jourFin', v_jour_cible + p_jours,
           'raison', p_raison,
           'detentionId', v_id,
           'qhs', false,
           'city', p_city,
           'country', p_country,
           'debutTs', (extract(epoch from clock_timestamp())*1000)::bigint)
   WHERE name = p_nom;

  RETURN jsonb_build_object('ok', true, 'detention_id', v_id,
                            'jour_debut', v_jour_cible, 'jour_fin', v_jour_cible + p_jours);
END;
$$;
REVOKE ALL ON FUNCTION public.detention_ouvrir_interne(text,text,integer,text,text,jsonb,text,text)
  FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- INDICES DE VILLE cote serveur. Le client a modifierIndiceVille, le cron en a sa propre copie,
-- mais aucune RPC n'existait : les effets d'une arrestation doivent etre poses dans la MEME
-- transaction que la detention, sinon un faux succes client pourrait les declencher seul.
-- Cles reelles : 'isn' = securite, 'social' = IS (voir INDICE_VILLE_DEFAUT, plateau-divers.js).
-- Hors republic, indices_villes n'a pas de ligne : on ne fabrique rien (meme regle que le client).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.indice_ville_ajuster_interne(
  p_pays text, p_ville text, p_cle text, p_delta integer)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_id text := p_pays || '_' || p_ville; v_data jsonb; v_val integer;
BEGIN
  IF p_pays IS DISTINCT FROM 'republic' THEN RETURN; END IF;
  SELECT data INTO v_data FROM public.indices_villes WHERE id = v_id FOR UPDATE;
  IF NOT FOUND THEN RETURN; END IF;
  v_val := coalesce((v_data ->> p_cle)::integer, 50) + p_delta;
  v_val := greatest(0, least(100, v_val));
  UPDATE public.indices_villes
     SET data = coalesce(v_data, '{}'::jsonb) || jsonb_build_object(p_cle, v_val),
         updated_at = now()
   WHERE id = v_id;
END;
$$;
REVOKE ALL ON FUNCTION public.indice_ville_ajuster_interne(text,text,text,integer)
  FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- RPC EXPOSEE : arrestation d'urgence.
--   Autorites : president, min_int, min_just (competence pays) et commissaire (competence ville).
--   Le juge est EXCLU (arbitrage du 15 septembre 2026).
--   Aucun etat d'urgence requis. 1 jour de detention. Securite +1, IS -1 dans la ville.
--   Juridiction : meme empire, regle deja ecrite pour la chasse a l'homme (26 aout 2026) ; et
--   pour un commissaire, la ville de son poste, puisque son mandat est municipal.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.arrestation_urgence(p_cible text, p_motif text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_nom text; v_poste text; v_poste_city text; v_pays text;
  v_cible_pays text; v_cible_ville text;
  v_ville text; v_res jsonb; v_motifs jsonb;
BEGIN
  SELECT a.nom, a.poste_id, a.poste_city, a.pays
    INTO v_nom, v_poste, v_poste_city, v_pays
    FROM public.acteur_poste_courant() a;

  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF v_poste IS NULL OR v_poste NOT IN ('president', 'min_int', 'min_just', 'commissaire') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
  END IF;
  IF p_cible IS NULL OR btrim(p_cible) = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_absente');
  END IF;
  IF p_cible = v_nom THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_est_l_acteur');
  END IF;
  IF p_motif IS NULL OR btrim(p_motif) = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'motif_absent');
  END IF;

  SELECT d.country, d.current_city INTO v_cible_pays, v_cible_ville
    FROM public.personnages_donnees d WHERE d.name = p_cible;
  IF v_cible_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_introuvable');
  END IF;

  -- Competence territoriale : meme empire, toujours.
  IF v_cible_pays IS DISTINCT FROM v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction');
  END IF;
  -- Un commissaire n'a autorite que dans SA ville.
  IF v_poste = 'commissaire' THEN
    IF v_poste_city IS NULL OR v_cible_ville IS DISTINCT FROM v_poste_city THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction_ville');
    END IF;
    v_ville := v_poste_city;
  ELSE
    v_ville := coalesce(v_cible_ville, 'capitale');
  END IF;

  v_motifs := jsonb_build_array(jsonb_build_object(
    'type', 'Arrestation d''urgence : ' || p_motif,
    'jour_fait', (SELECT coalesce(d.day, 1) FROM public.personnages_donnees d WHERE d.name = p_cible),
    'city', v_ville,
    'jours', 1,
    'source', 'arrestation_urgence',
    'date_evenement', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));

  v_res := public.detention_ouvrir_interne(
    p_cible, 'Arrestation d''urgence (' || p_motif || ')', 1, v_ville, v_pays,
    v_motifs, v_nom || ' (' || v_poste || ')', 'arrestation_urgence');

  IF (v_res ->> 'ok') IS DISTINCT FROM 'true' THEN
    RETURN v_res;
  END IF;

  -- Effets de ville : posés UNIQUEMENT ici, donc jamais sur un faux succes client.
  PERFORM public.indice_ville_ajuster_interne(v_pays, v_ville, 'isn', 1);
  PERFORM public.indice_ville_ajuster_interne(v_pays, v_ville, 'social', -1);

  RETURN v_res || jsonb_build_object('cible', p_cible, 'ville', v_ville,
                                     'autorite', v_nom, 'poste', v_poste,
                                     'securite', 1, 'social', -1);
END;
$$;
REVOKE ALL ON FUNCTION public.arrestation_urgence(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.arrestation_urgence(text, text) TO authenticated, service_role;

-- L'ordre ne coute plus 500 FR : 3 PA, 0 FR. Le miroir serveur fait foi pour payer_ordre.
UPDATE public.ordres_couts SET cost = 0 WHERE fn = 'arreter';
-- L'ordre de cambriolage disparait du commissariat : son cout n'a plus lieu d'etre declare.
DELETE FROM public.ordres_couts WHERE fn = 'cambrioler_caisse_commissariat';