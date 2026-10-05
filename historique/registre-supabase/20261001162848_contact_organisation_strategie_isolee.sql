-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20261001162848
-- Nom original      : contact_organisation_strategie_isolee
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-10-01 16:28:48 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : bdad8ed0b1a1192153a493fc0d616b87
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
-- LA STRATEGIE DE SELECTION, ISOLEE (1er octobre 2026)
-- Repondre « laquelle ? » et « que se passe-t-il ensuite ? » sont deux questions
-- distinctes, et seule la premiere est susceptible de changer. Le jour ou la
-- selection regardera l'activite recente, la reputation ou la proximite, c'est ce
-- corps et lui seul qui changera.
--
-- LA STRATEGIE D'AUJOURD'HUI : la plus nombreuse, aucun autre critere. Non par
-- equite entre organisations -- c'est assume -- mais pour maximiser la probabilite
-- qu'un nouveau joueur obtienne vite une reponse HUMAINE.
--
-- `p_joueur` est un POINT D'EXTENSION que la strategie actuelle ignore
-- volontairement : une strategie de proximite aurait besoin de son empire, une de
-- reputation de son passe. Sans ce parametre, changer de strategie forcerait a
-- changer aussi l'appelant.
create or replace function public.contact_organisation_choisir(
  p_joueur text, p_type_organisation text, p_exclues jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE v_r jsonb;
BEGIN
  -- `organisations.data` est un blob JSON ecrit par le client : on le lit, on n'y
  -- ecrit rien, et on ne suppose la presence d'aucune cle.
  --
  -- Une organisation SANS CHEF est ecartee ici et non par l'appelant : il n'y a
  -- personne a qui ecrire, donc ce n'est pas un choix valide.
  --
  -- A nombre de membres egal, l'identifiant tranche. Pas un critere de jeu : la
  -- seule facon de rendre le resultat reproductible.
  SELECT jsonb_build_object(
           'id',      o.id,
           'nom',     coalesce(d->>'nom', 'une organisation'),
           'chef',    d->>'chef',
           'membres', jsonb_array_length(coalesce(d->'membres', '[]'::jsonb)))
    INTO v_r
    FROM public.organisations o
    CROSS JOIN LATERAL (SELECT public.jsonb_ou_null(o.data) AS d) j
   WHERE d IS NOT NULL
     AND d->>'type' = p_type_organisation
     AND coalesce(d->>'chef', '') <> ''
     AND NOT (coalesce(p_exclues, '[]'::jsonb) ? o.id)
   ORDER BY jsonb_array_length(coalesce(d->'membres', '[]'::jsonb)) DESC, o.id ASC
   LIMIT 1;
  RETURN v_r;
END;
$fn$;

comment on function public.contact_organisation_choisir(text, text, jsonb) is
  'STRATEGIE DE SELECTION, isolee pour pouvoir changer seule : quelle organisation du type demande solliciter, en excluant celles deja contactees. Aujourd''hui la plus nombreuse -- non par equite, mais pour maximiser la chance d''une reponse humaine rapide. `p_joueur` est un point d''extension (proximite, reputation) que la strategie actuelle ignore volontairement. N''ecrit rien. Rend NULL s''il n''y a personne a solliciter, ce qui est un etat valide.';

-- Interdite au client comme au joueur : la strategie du jeu n'est pas une
-- information publique. L'appelant est SECURITY DEFINER, il l'atteint sans cela.
revoke all on function public.contact_organisation_choisir(text, text, jsonb) from public, anon, authenticated;
grant execute on function public.contact_organisation_choisir(text, text, jsonb) to service_role;

-- ELLE NE CHOISIT PLUS L'ORGANISATION, elle la DEMANDE. Cette fonction porte ce
-- qui ne changera pas -- le delai, le courrier, l'escalade, la trace -- et ignore
-- entierement selon quel critere l'organisation a ete retenue.
create or replace function public.contact_organisation_demander(
  p_passeur text, p_type_organisation text)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE
  v_moi     text;
  v_passeur record;
  v_e       record;
  v_orga    jsonb;
  v_nom     text;
  v_corps   text;
  v_id      text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT * INTO v_passeur FROM public.contacts_organisations_passeurs p
   WHERE p.passeur = p_passeur AND p.type_organisation = p_type_organisation;
  IF v_passeur IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'passeur_inconnu'); END IF;

  -- Verrou sur la ligne d'etat : deux clics simultanes ne doivent pas solliciter
  -- deux organisations d'un coup, ni deux fois la meme.
  SELECT * INTO v_e FROM public.contacts_organisations c
   WHERE c.joueur = v_moi AND c.passeur = p_passeur
     AND c.type_organisation = p_type_organisation
     FOR UPDATE;

  IF v_e IS NOT NULL AND now() < v_e.derniere_demande + interval '3 days' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'delai_non_ecoule',
             'jours_restants', greatest(1, ceil(extract(epoch from
               (v_e.derniere_demande + interval '3 days') - now()) / 86400.0)::integer)); END IF;

  v_orga := public.contact_organisation_choisir(
              v_moi, p_type_organisation,
              coalesce(v_e.organisations_contactees, '[]'::jsonb));

  IF v_orga IS NULL THEN
    -- Le delai de trois jours N'EST PAS consomme : aucun message n'est parti.
    RETURN jsonb_build_object('ok', false, 'raison',
             CASE WHEN v_e IS NULL OR jsonb_array_length(v_e.organisations_contactees) = 0
                  THEN 'aucune_organisation' ELSE 'toutes_contactees' END); END IF;

  -- Le bouton ne voyage pas dans le HTML : marqueur textuel inerte, meme format
  -- que marqueurActionMail() cote navigateur.
  v_nom   := regexp_replace(v_moi, '[|\[\]]', '', 'g');
  v_corps := 'J''ai rencontré quelqu''un qui cherche un service. Contacte '
          || v_nom || ' de ma part.' || chr(10) || chr(10)
          || '[[act:ecrire_a|' || v_nom || ']]';

  v_id := 'co-' || (extract(epoch from clock_timestamp()) * 1000)::bigint
               || '-' || substr(md5(random()::text), 1, 6);
  INSERT INTO public.mails (id, from_player, to_player, subject, body, time, read)
  VALUES (v_id, v_passeur.expediteur, (v_orga->>'chef'), 'Quelqu''un à contacter', v_corps,
          to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI'), false);

  INSERT INTO public.contacts_organisations
         (joueur, passeur, type_organisation, derniere_demande, organisations_contactees)
  VALUES (v_moi, p_passeur, p_type_organisation, now(), jsonb_build_array(v_orga->>'id'))
  ON CONFLICT (joueur, passeur, type_organisation) DO UPDATE
     SET derniere_demande = now(),
         organisations_contactees =
           public.contacts_organisations.organisations_contactees || jsonb_build_array(v_orga->>'id');

  -- Ne nomme PAS l'organisation : le passeur ne transmet aucun detail, dans les
  -- deux sens.
  RETURN jsonb_build_object('ok', true, 'rang',
           coalesce(jsonb_array_length(v_e.organisations_contactees), 0) + 1);
END;
$fn$;

comment on function public.contact_organisation_demander(text, text) is
  'Un passeur envoie un message a l''organisation retenue par contact_organisation_choisir(), jamais encore sollicitee pour ce joueur. Aucun filtrage : tout joueur peut demander. N''A AUCUN PARAMETRE pour le projet du joueur, et c''est la garantie que rien n''en est conserve. Ne choisit pas l''organisation et ne la nomme pas dans sa reponse.';

revoke all on function public.contact_organisation_demander(text, text)  from public, anon;
grant execute on function public.contact_organisation_demander(text, text) to authenticated, service_role;

DO $garde$
DECLARE n integer;
BEGIN
  SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
   WHERE ns.nspname = 'public' AND p.proname = 'contact_organisation_demander'
     AND p.prosrc ILIKE '%public.organisations%';
  IF n <> 0 THEN RAISE EXCEPTION 'la mise en relation choisit encore elle-meme'; END IF;
  SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
   WHERE ns.nspname = 'public' AND p.proname = 'contact_organisation_choisir'
     AND (has_function_privilege('anon', p.oid, 'execute')
       OR has_function_privilege('authenticated', p.oid, 'execute'));
  IF n <> 0 THEN RAISE EXCEPTION 'la strategie de selection est exposee au client'; END IF;
END $garde$;