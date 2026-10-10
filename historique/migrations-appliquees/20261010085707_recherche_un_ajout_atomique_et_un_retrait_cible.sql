-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 10 OCTOBRE 2026
--
-- Registre Supabase : version 20261010085707 (UTC), nom `recherche_un_ajout_atomique_et_un_retrait_cible`.
-- Le registre passe de 602 a 603 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 a9e53cbe844725657739ae926cfdd17f, 7652 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- CHANTIER 5, CHAINE 14 : L'AVIS DE RECHERCHE, PREMIERE MOITIE
--
-- L'inspection complete trouve DIX-HUIT sites la ou l'inventaire n'en nommait qu'un : le defaut
-- n'est pas une ecriture directe, c'est un dernier-ecrivain-gagnant sur un tableau sans cle. Ces
-- deux portes suppriment toute lecture-modification-ecriture -- ajout par `||` atomique, retrait
-- par `jsonb_agg` filtre -- et levent `rp.recherche_interne` pour elles seules.
-- =============================================================================

-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- CHANTIER 5, CHAINE 14 -- L'AVIS DE RECHERCHE (10 octobre 2026), PREMIERE MOITIE
--
-- L'INSPECTION COMPLETE, QUE LE LOT PRECEDENT AVAIT REFUSE DE FAIRE A LA HATE.
--
-- L'inventaire nommait UN site (`plateau-justice-economie.js:10996`). Le relevé exhaustif en
-- trouve DIX-HUIT, et ils forment un seul mecanisme :
--   . 13 `state.recherche.push(...)` PUREMENT LOCAUX, dans cinq fichiers, qui comptent sur un
--     `sbSavePersonnage` ulterieur pour les persister -- le blob de 48 colonnes republie
--     `recherche` EN BLOC ;
--   . 1 lecture-modification-ecriture serveur avalee (`ajouterCondamnationRechercheLocale`),
--     doublee d'un reflet local « obligatoire » que son propre commentaire presente comme une
--     precaution contre l'ecrasement -- donc comme une rustine, pas comme une correction ;
--   . 4 retraits par `filter` cote client, eux aussi persistes par le blob ;
--   . et une TROISIEME instance, cote serveur celle-la, qu'aucun inventaire ne nommait :
--     `militaire_requisitions_deserteurs` (api/cron-minuit.js) lit `recherche`, pousse une
--     entree de desertion, et reecrit le tableau ENTIER -- les deux ecritures avalees.
--
-- LE DEFAUT N'EST DONC PAS « une ecriture directe » : C'EST UN DERNIER-ECRIVAIN-GAGNANT. Deux
-- motifs inscrits dans la meme session, ou une inscription suivie d'un simple changement de
-- piece, et l'un des deux disparait. Le tableau n'a aucune cle : rien ne permet de fusionner.
--
-- CE QUE CES DEUX PORTES CHANGENT. Plus aucune lecture-modification-ecriture : l'ajout est un
-- `||` atomique sur la colonne, le retrait un `jsonb_agg` filtre, tous deux en une instruction
-- sous le verrou de ligne que PostgreSQL pose de lui-meme. Deux inscriptions concurrentes
-- aboutissent donc toutes les deux, et le verdict rend le tableau REEL -- que le client recopie
-- au lieu de pousser dans le sien.
--
-- `rp.recherche_interne` EST LE LAISSEZ-PASSER. La migration suivante pose le verrou qui refuse
-- toute ecriture cliente de cette colonne ; ces deux portes le lèvent pour elles seules, dans leur
-- transaction. Meme patron que `rp.caisse_interne`, en service depuis le 20 septembre 2026.
--
-- AUCUNE REGLE DE JEU N'EST MODIFIEE. Un joueur inscrit sur SA fiche (c'est la regle existante :
-- « chemin conserve pour SA PROPRE fiche »), le serveur inscrit sur celle qu'il nomme. Le filtre
-- de retrait est exactement `estMienne` du code client : l'acte, et le pays quand l'entree en
-- porte un -- « rien de ce qui concerne la desertion n'a le droit d'effacer un motif etranger ».

CREATE OR REPLACE FUNCTION public.recherche_inscrire(p_entree jsonb, p_cible text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $fn$
DECLARE v_moi text; v_cible text; v_id text; v_apres jsonb; v_n integer;
BEGIN
  IF p_entree IS NULL OR jsonb_typeof(p_entree) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'entree_invalide');
  END IF;

  v_moi := public.mon_personnage();
  IF v_moi IS NOT NULL THEN
    -- UN JOUEUR N'INSCRIT QUE SUR SA PROPRE FICHE. Condamner autrui est un pouvoir, et il a sa
    -- porte : justice_condamner, qui relit le poste de l'appelant.
    IF p_cible IS NOT NULL AND p_cible <> v_moi THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_ma_fiche');
    END IF;
    v_cible := v_moi;
  ELSE
    IF coalesce(btrim(coalesce(p_cible, '')), '') = '' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'cible_manquante');
    END IF;
    v_cible := p_cible;
  END IF;

  PERFORM set_config('rp.recherche_interne', 'on', true);

  -- IDEMPOTENCE PAR IDENTIFIANT, quand l'entree en porte un. C'est le cas du mandat d'arret des
  -- tracts calomnieux, dont le client verifiait deja l'absence avant de le refleter. Un crime
  -- ordinaire, lui, n'a pas d'identifiant : il peut etre commis deux fois, et doit s'inscrire
  -- deux fois.
  v_id := nullif(p_entree ->> 'id', '');
  IF v_id IS NOT NULL THEN
    SELECT count(*) INTO v_n FROM public.personnages_donnees d,
           jsonb_array_elements(CASE WHEN jsonb_typeof(d.recherche)='array'
                                     THEN d.recherche ELSE '[]'::jsonb END) e
     WHERE d.name = v_cible AND e ->> 'id' = v_id;
    IF v_n > 0 THEN
      SELECT coalesce(recherche, '[]'::jsonb) INTO v_apres
        FROM public.personnages_donnees WHERE name = v_cible;
      RETURN jsonb_build_object('ok', true, 'action', 'deja_inscrite',
                                'recherche', coalesce(v_apres, '[]'::jsonb));
    END IF;
  END IF;

  -- L'AJOUT EST ATOMIQUE : aucune relecture, donc aucune fenetre de perte.
  UPDATE public.personnages_donnees
     SET recherche = (CASE WHEN jsonb_typeof(recherche) = 'array'
                           THEN recherche ELSE '[]'::jsonb END) || jsonb_build_array(p_entree)
   WHERE name = v_cible
  RETURNING recherche INTO v_apres;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  RETURN jsonb_build_object('ok', true, 'action', 'inscrite',
                            'recherche', coalesce(v_apres, '[]'::jsonb));
END; $fn$;

CREATE OR REPLACE FUNCTION public.recherche_retirer(
  p_actes text[], p_pays text DEFAULT NULL, p_cible text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $fn$
DECLARE v_moi text; v_cible text; v_avant jsonb; v_apres jsonb;
BEGIN
  IF p_actes IS NULL OR array_length(p_actes, 1) IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'actes_manquants');
  END IF;

  v_moi := public.mon_personnage();
  IF v_moi IS NOT NULL THEN
    IF p_cible IS NOT NULL AND p_cible <> v_moi THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_ma_fiche');
    END IF;
    v_cible := v_moi;
  ELSE
    IF coalesce(btrim(coalesce(p_cible, '')), '') = '' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'cible_manquante');
    END IF;
    v_cible := p_cible;
  END IF;

  SELECT CASE WHEN jsonb_typeof(recherche)='array' THEN recherche ELSE '[]'::jsonb END
    INTO v_avant FROM public.personnages_donnees WHERE name = v_cible FOR UPDATE;
  IF v_avant IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  PERFORM set_config('rp.recherche_interne', 'on', true);

  -- LE FILTRE EST EXACTEMENT `estMienne` DU CLIENT : l'acte, et le pays quand l'entree en porte
  -- un. UN MOTIF N'EN EFFACE JAMAIS UN AUTRE -- ni celui d'un autre acte, ni celui d'un autre
  -- empire. C'est la regle posee le 13 septembre 2026, reprise ici sans un mot de plus.
  SELECT coalesce(jsonb_agg(e), '[]'::jsonb) INTO v_apres
    FROM jsonb_array_elements(v_avant) e
   WHERE NOT ( (e ->> 'acte') = ANY (p_actes)
               AND ( p_pays IS NULL
                     OR coalesce(nullif(e ->> 'country', ''), p_pays) = p_pays ) );

  UPDATE public.personnages_donnees SET recherche = v_apres WHERE name = v_cible;

  RETURN jsonb_build_object('ok', true, 'action', 'retires',
    'retires', jsonb_array_length(v_avant) - jsonb_array_length(v_apres),
    'recherche', v_apres);
END; $fn$;

REVOKE ALL ON FUNCTION public.recherche_inscrire(jsonb, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.recherche_inscrire(jsonb, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.recherche_inscrire(jsonb, text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.recherche_retirer(text[], text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.recherche_retirer(text[], text, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.recherche_retirer(text[], text, text) TO authenticated, service_role;
