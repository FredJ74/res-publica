-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 9 OCTOBRE 2026
--
-- Registre Supabase : version 20261009152210 (UTC ; 17h22 a Paris), nom
-- `compromis_expire_une_transaction_deux_familles`. Le registre passe de 574 a 575 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 7136607c36e23e661e8f633cc544fdf2, 14 739 caracteres,
-- 1 instruction au registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- Elle ferme les trois scenarios que l'audit avait nommes sur les compromis expires -- double credit
-- de pret, argent sans dette, double remboursement d'acompte : `Math.random() < 0.5` decidait du pret
-- en JavaScript, puis quatre ecritures independantes et avalees appliquaient la decision, et
-- l'identifiant d'historique portait un `Date.now()` que la cle primaire ne refusait jamais. Une
-- seule fonction sert les deux familles (terrains et entreprises), les identifiants deviennent
-- deterministes a la journee, et la brique nocturne n'est deliberement PAS forcee ici.
--
-- ELLE VA PAR PAIRE AVEC LE DEPOT : `api/cron-minuit.js` (`resoudreCompromisExpires` et
-- `resoudreCompromisEntreprisesExpires`, reduites a un balayage et un appel).
-- =============================================================================

-- Chantier 6 -- UN COMPROMIS QUI EXPIRE EST UNE TRANSACTION, ET LE TIRAGE DU PRET EST DEDANS.
--
-- resoudreCompromisExpires (terrains, api/cron-minuit.js:804) et
-- resoudreCompromisEntreprisesExpires (entreprises, :945) etaient deux fonctions quasi
-- identiques, et toutes deux faisaient la meme chose de travers : `Math.random() < 0.5` decidait
-- du pret en JavaScript, puis QUATRE ecritures independantes, avalees, appliquaient la decision
-- -- credit de l'emprunteur, ligne `prets`, blob du bien, ligne `compromis_historique`.
--
-- LES TROIS SCENARIOS QUE L'AUDIT AVAIT NOMMES, ET QUI SONT MAINTENANT FERMES :
--   1. DOUBLE CREDIT DE PRET -- le tirage etait rejoue, et pouvait accorder deux fois. La garde
--      « pret deja accorde » existait bien cote JS, mais apres les ecritures : une coupure entre
--      le credit et l'ecriture du blob laissait `attente_validation` en base, donc rejouable ;
--   2. ARGENT SANS DETTE -- seul l'`INSERT prets` echouait, et l'emprunteur gardait le montant ;
--   3. DOUBLE REMBOURSEMENT D'ACOMPTE, avec une SECONDE ligne d'historique que la cle primaire
--      ne refusait pas : son identifiant portait un `Date.now()`.
--
-- UNE SEULE FONCTION POUR LES DEUX FAMILLES. Les deux chemins JavaScript ne differaient que par
-- quatre details : la table, l'encodage du blob (`terrains_etat.data` est du TEXTE portant du
-- JSON, `entreprises.data` est du jsonb natif), la clause « permis du maire » qui n'existe que
-- pour un terrain, et la source du pays. p_type porte cette difference ; le reste est commun,
-- et c'etait deux fois le meme code.
--
-- LE PATRON EST resoudre_compromis_helvetia_expire, deja deployee : SELECT ... FOR UPDATE,
-- decision, credit, INSERT, mutation du blob, tout dans un seul BEGIN. On ne force PAS la brique
-- actes_nocturnes ici : elle sert a empecher le REJEU D'UNE TACHE DE NUIT, alors que le rejeu
-- d'un compromis est deja impossible par transition d'etat -- le drapeau `compromis` disparait du
-- blob dans la meme transaction que ses consequences. Ajouter une revendication par jour
-- empecherait en plus de resoudre deux compromis du MEME bien a deux jours differents.
--
-- ET LES DEUX IDENTIFIANTS DEVIENNENT DETERMINISTES : `compromis-<bien>-<jour>` pour l'historique,
-- `pret-<type>-<bien>-<jour>` pour le pret, avec ON CONFLICT DO NOTHING. Une horloge produisait
-- un identifiant neuf a chaque rejeu ; une date n'en produit qu'un par jour.
--
-- AUCUNE REGLE N'EST MODIFIEE : meme seuil de risque (10 % du montant), meme tirage a 50 %, meme
-- auto-validation du permis sans reponse du maire, meme regle d'acompte (rembourse sur refus
-- explicite, perdu sinon), memes libelles de detail, et le bien Helvetia continue d'etre refuse
-- ici pour rester sur sa propre RPC.
--
-- Bancs en transaction annulee : 12 epreuves vertes -- 7 sur le terrain (dont le double credit et
-- le double remboursement), 2 sur la resolution du pays d'une entreprise, 3 sur l'entreprise.
CREATE OR REPLACE FUNCTION public.compromis_expire_resoudre(p_type text, p_cible text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $fn$
DECLARE
  v_type text := lower(btrim(coalesce(p_type,''))); v_data jsonb;
  v_pays text; v_bat text; v_prefixe text; v_expire bigint;
  v_ms bigint := (extract(epoch from now())*1000)::bigint;
  v_pret jsonb; v_refus boolean := false; v_gele boolean := false; v_existe boolean;
  v_detail text[] := ARRAY[]::text[]; v_montant numeric; v_arg numeric;
  v_acompte numeric; v_par text; v_perm text;
  v_jour text := to_char((now() AT TIME ZONE 'Europe/Paris')::date, 'YYYY-MM-DD');
BEGIN
  -- FAIL-CLOSED : un type ou une cible absents LEVENT. Rendre un verdict voudrait dire
  -- « rien a resoudre », et le cron reposerait un drapeau qu'il n'a pas gagne.
  IF v_type NOT IN ('terrain','entreprise') THEN
    RAISE EXCEPTION 'compromis_expire_resoudre : type inconnu « % »', p_type; END IF;
  IF btrim(coalesce(p_cible,'')) = '' THEN
    RAISE EXCEPTION 'compromis_expire_resoudre : la cible est obligatoire'; END IF;

  -- LE VERROU SUR LE BIEN est ce qui serialise deux passes simultanees.
  IF v_type = 'terrain' THEN
    SELECT t.data::jsonb, t.country, t.building_id INTO v_data, v_pays, v_bat
      FROM public.terrains_etat t WHERE t.id = p_cible FOR UPDATE;
    v_prefixe := 'compromis-';
  ELSE
    -- Le pays d'une entreprise : son blob d'abord, sinon le DEUXIEME segment de l'identifiant
    -- (« <type>-<pays>-<ville> »). C'est exactement ce que lisait `split('-').slice(1)[0]`.
    SELECT e.data,
           nullif(coalesce(e.data->>'country', split_part(coalesce(e.data->>'id', e.id),'-',2)),''), e.id
      INTO v_data, v_pays, v_bat FROM public.entreprises e WHERE e.id = p_cible FOR UPDATE;
    v_prefixe := 'compromis-entreprise-';
  END IF;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'action','non_applicable'); END IF;
  -- Un bien Helvetia garde sa propre RPC : on ne reimplemente pas sa decision ici.
  IF v_type = 'terrain' AND (v_data->>'proprietaire') = 'Helvetia' THEN
    RETURN jsonb_build_object('ok', false, 'action','helvetia'); END IF;
  IF coalesce((v_data->>'compromis')::boolean, false) IS NOT TRUE
     OR (v_data->>'compromisExpireAt') IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'action','non_applicable'); END IF;
  v_expire := (v_data->>'compromisExpireAt')::bigint;
  IF v_expire > v_ms THEN RETURN jsonb_build_object('ok', false, 'action','pas_encore_expire'); END IF;

  -- UN PRET DEJA ACCORDE GELE LE COMPROMIS (correctif du 10 aout 2026) : sans cette garde, la
  -- meme ligne se ferait perdre son acompte a chaque passage du cron, chaque nuit.
  v_pret := v_data->'pretDemande';
  IF jsonb_typeof(v_pret) = 'object' AND v_pret->>'statut' = 'accorde' THEN
    RETURN jsonb_build_object('ok', true, 'action','pret_accorde_compromis_gele'); END IF;

  -- PERMIS DU MAIRE : terrain seulement. Pas de reponse = positif, maintenant.
  IF v_type = 'terrain' THEN
    v_perm := v_data #>> '{permis,statut}';
    IF v_perm = 'attente_validation' THEN
      v_data := jsonb_set(jsonb_set(v_data, '{permis,statut}', '"valide"'),
                          '{permis,autoValide}', 'true');
      v_data := jsonb_set(v_data, '{constructionAutorisee}', 'true', true);
      v_detail := array_append(v_detail, 'permis validé (sans réponse du maire)');
    ELSIF v_perm = 'valide' THEN
      v_data := jsonb_set(v_data, '{constructionAutorisee}', 'true', true);
      v_detail := array_append(v_detail, 'permis validé par le maire');
    ELSIF v_perm = 'refuse' THEN
      v_refus := true; v_detail := array_append(v_detail, 'permis refusé par le maire');
    END IF;
  END IF;

  -- LE TIRAGE DU PRET EST ICI, pas chez l'appelant : un rejeu ne peut plus le rejouer.
  IF jsonb_typeof(v_pret) = 'object' AND v_pret->>'statut' = 'attente_validation' THEN
    v_montant := coalesce((v_pret->>'montant')::numeric, 0);
    SELECT true, coalesce(arg,0) INTO v_existe, v_arg FROM public.personnages
     WHERE name = v_pret->>'demandeur' FOR UPDATE;
    v_arg := coalesce(v_arg, 0);
    IF v_arg >= v_montant * 0.10 OR random() < 0.5 THEN
      v_data := jsonb_set(v_data, '{pretDemande,statut}', '"accorde"');
      IF coalesce(v_existe, false) THEN
        UPDATE public.personnages SET arg = coalesce(arg,0) + v_montant
         WHERE name = v_pret->>'demandeur';
        INSERT INTO public.prets (id, emprunteur, country, building_id, type_banque,
            montant_initial, montant_restant, duree_jours, mensualite, jours_impayes, statut)
        VALUES ('pret-' || v_type || '-' || p_cible || '-' || v_jour, v_pret->>'demandeur',
            v_pays, v_bat, 'nationale', v_montant, (v_pret->>'montantTotal')::numeric,
            (v_pret->>'duree')::integer, (v_pret->>'mensualite')::numeric, 0, 'en_cours')
        ON CONFLICT (id) DO NOTHING;
      END IF;
      v_detail := array_append(v_detail, 'prêt accordé (+' || v_montant::text || ' FR virés)');
      v_gele := true;
    ELSE
      v_data := jsonb_set(v_data, '{pretDemande,statut}', '"refuse"');
      v_refus := true; v_detail := array_append(v_detail, 'prêt refusé par la banque');
    END IF;
  END IF;

  -- Pret accorde a l'instant, aucune autre clause refusee : le compromis reste actif, ni
  -- rembourse ni perdu -- le joueur finalisera plus tard avec l'argent prete.
  IF v_gele AND NOT v_refus THEN
    IF v_type = 'terrain' THEN
      UPDATE public.terrains_etat SET data = v_data::text, updated_at = now() WHERE id = p_cible;
    ELSE
      UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_cible;
    END IF;
    RETURN jsonb_build_object('ok', true, 'action','pret_en_attente_finalisation',
                              'detail', array_to_string(v_detail,' · '));
  END IF;

  v_acompte := coalesce((v_data->>'acompte')::numeric, 0);
  v_par := v_data->>'compromisPar';
  IF v_refus AND v_par IS NOT NULL AND v_acompte > 0 THEN
    UPDATE public.personnages SET arg = coalesce(arg,0) + v_acompte WHERE name = v_par;
    v_detail := array_append(v_detail, 'acompte remboursé (' || v_acompte::text || ' FR)');
  ELSE
    v_detail := array_append(v_detail, 'acompte perdu (' || v_acompte::text || ' FR)');
  END IF;

  INSERT INTO public.compromis_historique (id, country, building_id, demandeur, resultat, detail)
  VALUES (v_prefixe || p_cible || '-' || v_jour, v_pays, v_bat, coalesce(v_par,'inconnu'),
          CASE WHEN v_refus THEN 'rembourse' ELSE 'perdu' END,
          coalesce(nullif(array_to_string(v_detail,' · '),''),
                   CASE WHEN v_type='entreprise'
                        THEN 'compromis de rachat d''entreprise expiré sans finalisation'
                        ELSE '' END))
  ON CONFLICT (id) DO NOTHING;

  -- `pretDemande` est efface aussi (10 aout 2026) : un {statut:'refuse'} laisse accroche aurait
  -- bloque a tort le pretOk d'un futur compromis n'ayant rien demande.
  v_data := v_data - 'compromis' - 'compromisPar' - 'acompte' - 'compromisAt'
                   - 'compromisExpireAt' - 'pretDemande';
  IF v_type = 'terrain' THEN
    UPDATE public.terrains_etat SET data = v_data::text, updated_at = now() WHERE id = p_cible;
  ELSE
    UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_cible;
  END IF;

  RETURN jsonb_build_object('ok', true,
    'action', CASE WHEN v_refus THEN 'rembourse' ELSE 'perdu' END,
    'acompte', v_acompte, 'detail', array_to_string(v_detail,' · '));
END; $fn$;

COMMENT ON FUNCTION public.compromis_expire_resoudre(text,text) IS
'Resout en UNE transaction un compromis arrive a echeance, pour les deux familles : p_type
« terrain » (terrains_etat, blob texte, clause permis du maire) ou « entreprise » (entreprises,
blob jsonb). Le TIRAGE du pret est ici, pas chez l''appelant. Identifiants deterministes
(compromis-<bien>-<jour>, pret-<type>-<bien>-<jour>) : un rejeu ne cree ni second pret ni seconde
ligne d''historique. Un bien Helvetia est refuse et reste sur resoudre_compromis_helvetia_expire.
Verdicts : non_applicable, helvetia, pas_encore_expire, pret_accorde_compromis_gele,
pret_en_attente_finalisation, rembourse, perdu. Non appelable depuis le reseau.';

DO $$
DECLARE v_def text; v_n int;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def FROM pg_proc p
    JOIN pg_namespace n ON n.oid=p.pronamespace AND n.nspname='public'
   WHERE p.proname='compromis_expire_resoudre';
  IF v_def IS NULL THEN RAISE EXCEPTION 'P1 ECHOUEE -- la porte n''existe pas'; END IF;

  -- P1 : LE TIRAGE EST DANS LA PORTE, et le bien est verrouille avant.
  IF position('random() < 0.5' in v_def) = 0 THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- aucun tirage dans la porte'; END IF;
  SELECT count(*) INTO v_n FROM regexp_matches(v_def, 'FOR UPDATE', 'g');
  IF v_n < 3 THEN RAISE EXCEPTION 'P1 ECHOUEE -- % verrou(s) au lieu de 3 au moins', v_n; END IF;

  -- P2 : LES DEUX IDENTIFIANTS SONT DATES, et proteges par ON CONFLICT.
  IF position('''pret-'' || v_type || ''-'' || p_cible || ''-'' || v_jour' in v_def) = 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- l''identifiant du pret n''est pas date'; END IF;
  IF position('v_prefixe || p_cible || ''-'' || v_jour' in v_def) = 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- l''identifiant de l''historique n''est pas date'; END IF;
  SELECT count(*) INTO v_n FROM regexp_matches(v_def, 'ON CONFLICT \(id\) DO NOTHING', 'g');
  IF v_n <> 2 THEN RAISE EXCEPTION 'P2 ECHOUEE -- % garde(s) de rejeu au lieu de 2', v_n; END IF;

  -- P3 : LES DEUX FAMILLES SONT DANS LA MEME FONCTION, chacune avec son encodage de blob.
  IF position('UPDATE public.terrains_etat SET data = v_data::text' in v_def) = 0
     OR position('UPDATE public.entreprises SET data = v_data,' in v_def) = 0 THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- un encodage de blob manque'; END IF;
  IF position('''helvetia''' in v_def) = 0 THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- le bien Helvetia n''est plus refuse'; END IF;

  -- P4 : la brique nocturne n'est PAS forcee ici, et c'est deliberé.
  IF position('acte_nocturne_revendiquer' in v_def) > 0 THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- une revendication par jour empecherait deux compromis du meme bien';
  END IF;

  -- P5 : les droits. Acte de minuit : injoignable depuis le reseau.
  IF has_function_privilege('authenticated','public.compromis_expire_resoudre(text,text)','EXECUTE')
     OR has_function_privilege('anon','public.compromis_expire_resoudre(text,text)','EXECUTE') THEN
    RAISE EXCEPTION 'P5 ECHOUEE -- un navigateur peut resoudre un compromis'; END IF;
  IF NOT has_function_privilege('service_role','public.compromis_expire_resoudre(text,text)','EXECUTE') THEN
    RAISE EXCEPTION 'P5 ECHOUEE -- le cron ne peut pas appeler la porte'; END IF;

  -- P6 : AUCUNE DONNEE TOUCHEE, et aucun residu de banc.
  SELECT count(*) INTO v_n FROM public.terrains_etat WHERE id LIKE 'zzbanc%' OR id LIKE 'zzb-%' OR id LIKE 'zzp-%';
  IF v_n <> 0 THEN RAISE EXCEPTION 'P6 ECHOUEE -- % terrain(s) de banc', v_n; END IF;
  SELECT count(*) INTO v_n FROM public.entreprises WHERE id LIKE 'zzbanc%' OR id LIKE 'zzb-%' OR id LIKE 'zzp-%';
  IF v_n <> 0 THEN RAISE EXCEPTION 'P6 ECHOUEE -- % entreprise(s) de banc', v_n; END IF;
  SELECT count(*) INTO v_n FROM public.compromis_historique WHERE id LIKE '%zz%';
  IF v_n <> 0 THEN RAISE EXCEPTION 'P6 ECHOUEE -- % ligne(s) d''historique de banc', v_n; END IF;
  SELECT count(*) INTO v_n FROM public.prets WHERE id LIKE '%zz%';
  IF v_n <> 0 THEN RAISE EXCEPTION 'P6 ECHOUEE -- % pret(s) de banc', v_n; END IF;
  IF (SELECT arg FROM public.personnages_donnees WHERE name='Ben') <> 1850 THEN
    RAISE EXCEPTION 'P6 ECHOUEE -- l''argent du personnage du banc a bouge'; END IF;

  RAISE NOTICE 'SIX PREUVES STRUCTURELLES VERTES.';
END $$;