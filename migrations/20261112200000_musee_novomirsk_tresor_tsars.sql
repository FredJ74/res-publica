-- Musée municipal de Novomirsk et énigme du trésor des Tsars (Fred, 12/11/2026 au soir ; Claude).
-- Salles : Salle des Origines et Salle des Personnalités discrètes remplacent les neuf salles du panthéon
-- (Krasnov, qui réutilise le bâtiment, n'est pas concerné : ses pièces ne sont pas dans ces règles).
-- Énigme gratuite, une par joueur, étapes dans l'ordre imposé :
--   guide (Salle des Origines) -> karpova (poissonnière) -> sudakov (EHPAD) -> livre (fouille du musée
--   présidentiel, à coup sûr, un exemplaire par joueur) -> livre_donne (à Tatiana, Mère Volga) -> terminee
--   (récit de Tatiana, deux « Trésor des tsars » : +1 PA et +10 de moral, à manger avant 4 jours ;
--   au-delà, la crème a tourné : -1 PA, comme un aliment périmé).
-- Un PNJ à qui l'on parle trop tôt ne révèle rien (tresor_tsars_parler renvoie scene = null).
-- Idempotente.

UPDATE public.navigation_lieux_regles
   SET pieces = '["hall", "salle_origines", "salle_personnalites_discretes"]'::jsonb
 WHERE pays = 'soviet' AND ville = 'capitale' AND batiment = 'musee-novomirsk';

CREATE TABLE IF NOT EXISTS public.enigme_tresor_tsars (
  acteur text PRIMARY KEY,
  etape text NOT NULL CHECK (etape IN ('guide', 'karpova', 'sudakov', 'livre', 'livre_donne', 'terminee')),
  maj timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.enigme_tresor_tsars ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.enigme_tresor_tsars FROM PUBLIC, anon, authenticated;

INSERT INTO public.objets_modeles(id, objet) VALUES
 ('tresor_tsars:livre', '{"id":"livre-tresor-tsars","name":"Le fabuleux trésor des Tsars","icon":"ti-book","type":"livre_enigme","tresorTsars":"livre","legal":true,"desc":"Un vieux livre gondolé par l''eau, à moitié effacé. Sur une page : « le trésor est composé… », puis le dessin d''une chose ronde posée sur une chose ronde, dont le bas a disparu. Plus bas, un texte illisible se termine par « …chez la mère Volga »."}'::jsonb),
 ('tresor_tsars:gateau', '{"name":"Trésor des tsars","icon":"ti-cake","type":"gateau_tsars","tresorTsars":"gateau","stackable":true,"stackKey":"tresor-tsars","qty":2,"legal":true,"desc":"Pâte à choux, crème chiboust, amandes effilées et chantilly, coiffée d''une noisette collée au sucre. À manger avant 4 jours : la crème tourne vite."}'::jsonb)
ON CONFLICT (id) DO UPDATE SET objet = EXCLUDED.objet;

CREATE OR REPLACE FUNCTION public.tresor_tsars_rang_interne(p text)
RETURNS integer LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE p WHEN 'guide' THEN 1 WHEN 'karpova' THEN 2 WHEN 'sudakov' THEN 3 WHEN 'livre' THEN 4
                WHEN 'livre_donne' THEN 5 WHEN 'terminee' THEN 6 ELSE 0 END;
$$;

CREATE OR REPLACE FUNCTION public.tresor_tsars_lieu_interne(p_acteur text, p_batiment text, p_piece text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT EXISTS (SELECT 1 FROM public.personnages_donnees
                  WHERE name = p_acteur AND country = 'soviet' AND current_city = 'capitale'
                    AND current_building = p_batiment AND current_room = p_piece);
$$;

CREATE OR REPLACE FUNCTION public.tresor_tsars_livre_index_interne(p_inv jsonb)
RETURNS integer LANGUAGE sql IMMUTABLE AS $$
  SELECT coalesce((SELECT (o.ord - 1)::integer
                     FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_inv) = 'array' THEN p_inv ELSE '[]'::jsonb END)
                          WITH ORDINALITY o(v, ord)
                    WHERE o.v ->> 'tresorTsars' = 'livre' ORDER BY o.ord LIMIT 1), -1);
$$;

CREATE OR REPLACE FUNCTION public.tresor_tsars_inventaire_interne(p_acteur text)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision)
    FROM public.personnages_donnees WHERE name = p_acteur;
$$;

-- Étape 1 : le guide de la Salle des Origines termine sa visite par l'indice de la poissonnière.
CREATE OR REPLACE FUNCTION public.tresor_tsars_guide()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); e text;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF NOT public.tresor_tsars_lieu_interne(a, 'musee-novomirsk', 'salle_origines') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  INSERT INTO public.enigme_tresor_tsars(acteur, etape) VALUES (a, 'guide') ON CONFLICT (acteur) DO NOTHING;
  SELECT etape INTO e FROM public.enigme_tresor_tsars WHERE acteur = a;
  RETURN jsonb_build_object('ok', true, 'etape', e);
END $$;

-- Étapes 2 et 3, et demande du livre par Tatiana : appelée par /api/chat sous le jeton du joueur quand il
-- parle à l'un des trois PNJ. Le serveur juge le lieu, l'ordre des étapes et la possession du livre ;
-- p_mot_cle dit seulement si le message contenait un mot clé (Tatiana réagit au livre, mot clé ou non).
CREATE OR REPLACE FUNCTION public.tresor_tsars_parler(p_pnj text, p_mot_cle boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); e text; r integer; inv jsonb;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT etape INTO e FROM public.enigme_tresor_tsars WHERE acteur = a FOR UPDATE;
  r := public.tresor_tsars_rang_interne(e);
  IF p_pnj = 'galina_karpova' THEN
    IF NOT coalesce(p_mot_cle, false) OR r < 1 OR NOT public.tresor_tsars_lieu_interne(a, 'poissonniere-novomirsk', 'etal_poissonniere') THEN
      RETURN jsonb_build_object('ok', true, 'scene', NULL); END IF;
    IF e = 'guide' THEN UPDATE public.enigme_tresor_tsars SET etape = 'karpova', maj = now() WHERE acteur = a; END IF;
    RETURN jsonb_build_object('ok', true, 'scene', 'karpova');
  ELSIF p_pnj = 'evgueni_sudakov' THEN
    IF NOT coalesce(p_mot_cle, false) OR r < 2 OR NOT public.tresor_tsars_lieu_interne(a, 'dispensaire-public', 'ehpad_tilleuls') THEN
      RETURN jsonb_build_object('ok', true, 'scene', NULL); END IF;
    IF e = 'karpova' THEN UPDATE public.enigme_tresor_tsars SET etape = 'sudakov', maj = now() WHERE acteur = a; END IF;
    RETURN jsonb_build_object('ok', true, 'scene', 'sudakov');
  ELSIF p_pnj = 'tatiana_bortchova' THEN
    SELECT inventory INTO inv FROM public.personnages_donnees WHERE name = a;
    IF e = 'livre' AND public.tresor_tsars_livre_index_interne(inv) >= 0
       AND public.tresor_tsars_lieu_interne(a, 'capitaine-sauvage', 'salle_principale') THEN
      RETURN jsonb_build_object('ok', true, 'scene', 'tatiana_livre'); END IF;
    RETURN jsonb_build_object('ok', true, 'scene', NULL);
  END IF;
  RETURN jsonb_build_object('ok', true, 'scene', NULL);
END $$;

-- Étape 4 : la fouille du musée présidentiel de Novomirsk trouve le livre à coup sûr (un exemplaire par joueur).
CREATE OR REPLACE FUNCTION public.tresor_tsars_fouille_interne(p_acteur text, p_batiment text, p_piece text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE e text; o jsonb; v jsonb;
BEGIN
  IF (p_batiment, p_piece) IS DISTINCT FROM ('palais-presidentiel', 'musee_presidentiel')
     OR NOT public.tresor_tsars_lieu_interne(p_acteur, p_batiment, p_piece) THEN RETURN '{}'::jsonb; END IF;
  SELECT etape INTO e FROM public.enigme_tresor_tsars WHERE acteur = p_acteur FOR UPDATE;
  IF e IS NULL OR e NOT IN ('sudakov', 'livre') THEN RETURN '{}'::jsonb; END IF;
  IF public.tresor_tsars_livre_index_interne((SELECT inventory FROM public.personnages_donnees WHERE name = p_acteur)) >= 0 THEN
    RETURN '{}'::jsonb; END IF;
  SELECT objet INTO STRICT o FROM public.objets_modeles WHERE id = 'tresor_tsars:livre';
  v := public.inventaire_deposer_interne(p_acteur, o, true);
  IF (v ->> 'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'tresor_tsars: depot du livre refuse'; END IF;
  UPDATE public.enigme_tresor_tsars SET etape = 'livre', maj = now() WHERE acteur = p_acteur;
  RETURN jsonb_build_object('livre_tresor', true) || public.tresor_tsars_inventaire_interne(p_acteur);
END $$;

DO $$
DECLARE f text; ancien text; nouveau text;
BEGIN
  SELECT pg_get_functiondef('public.fouiller_lieux()'::regprocedure) INTO f;
  IF position('tresor_tsars_fouille_interne' IN f) > 0 THEN RETURN; END IF;
  ancien := $q$RETURN jsonb_build_object('ok', true, 'couinator', v_couin, 'taux', v_taux, 'trouvees', v_trouvees,$q$;
  nouveau := $q$RETURN public.tresor_tsars_fouille_interne(a, l.batiment, l.piece) || jsonb_build_object('ok', true, 'couinator', v_couin, 'taux', v_taux, 'trouvees', v_trouvees,$q$;
  IF (length(f) - length(replace(f, ancien, ''))) / length(ancien) <> 1 THEN RAISE EXCEPTION 'fouiller_lieux: fragment introuvable'; END IF;
  EXECUTE replace(f, ancien, nouveau);
END $$;

-- Le joueur donne le livre à Tatiana : il quitte son inventaire.
CREATE OR REPLACE FUNCTION public.tresor_tsars_donner_livre(p_requete uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb := '{}'::jsonb; v jsonb; e text; inv jsonb; i integer;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'tresor_tsars_donner_livre', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  IF NOT public.tresor_tsars_lieu_interne(a, 'capitaine-sauvage', 'salle_principale') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  SELECT etape INTO e FROM public.enigme_tresor_tsars WHERE acteur = a FOR UPDATE;
  IF e IS DISTINCT FROM 'livre' THEN RETURN jsonb_build_object('ok', false, 'raison', 'etape_invalide'); END IF;
  SELECT inventory INTO inv FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  i := public.tresor_tsars_livre_index_interne(inv);
  IF i < 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_livre'); END IF;
  UPDATE public.personnages_donnees SET inventory = inv - i, updated_at = now() WHERE name = a;
  UPDATE public.enigme_tresor_tsars SET etape = 'livre_donne', maj = now() WHERE acteur = a;
  v := jsonb_build_object('ok', true, 'etape', 'livre_donne') || public.tresor_tsars_inventaire_interne(a);
  RETURN public.achat_requete_clore_interne(a, p_requete, 'tresor_tsars_donner_livre', prm, v);
END $$;

-- Le joueur a répondu (peu importe quoi) : Tatiana raconte et offre deux « Trésor des tsars ».
CREATE OR REPLACE FUNCTION public.tresor_tsars_recit(p_requete uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb := '{}'::jsonb; v jsonb; e text; o jsonb;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'tresor_tsars_recit', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  IF NOT public.tresor_tsars_lieu_interne(a, 'capitaine-sauvage', 'salle_principale') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  SELECT etape INTO e FROM public.enigme_tresor_tsars WHERE acteur = a FOR UPDATE;
  IF e IS DISTINCT FROM 'livre_donne' THEN RETURN jsonb_build_object('ok', false, 'raison', 'etape_invalide'); END IF;
  SELECT objet INTO STRICT o FROM public.objets_modeles WHERE id = 'tresor_tsars:gateau';
  o := o || jsonb_build_object('recuA', floor(extract(epoch FROM clock_timestamp()) * 1000));
  v := public.inventaire_deposer_interne(a, o, true);
  IF (v ->> 'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'tresor_tsars: depot des gateaux refuse'; END IF;
  UPDATE public.enigme_tresor_tsars SET etape = 'terminee', maj = now() WHERE acteur = a;
  v := jsonb_build_object('ok', true, 'etape', 'terminee', 'gateaux', 2) || public.tresor_tsars_inventaire_interne(a);
  RETURN public.achat_requete_clore_interne(a, p_requete, 'tresor_tsars_recit', prm, v);
END $$;

-- Manger un « Trésor des tsars » : +1 PA et +10 de moral s'il a moins de 4 jours ; sinon -1 PA.
CREATE OR REPLACE FUNCTION public.tresor_tsars_manger(p_requete uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb := '{}'::jsonb; v jsonb; inv jsonb; l jsonb; recu numeric;
        frais boolean; v_pa integer; v_moral integer;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'tresor_tsars_manger', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  SELECT coalesce(inventory, '[]'::jsonb) INTO inv FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  l := public.sovarka_inventaire_ligne_interne(inv, ARRAY['tresor-tsars']);
  IF (l ->> 'i')::integer < 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_gateau'); END IF;
  recu := CASE WHEN coalesce(inv -> (l ->> 'i')::integer ->> 'recuA', '') ~ '^[0-9]+(\.[0-9]+)?$'
               THEN (inv -> (l ->> 'i')::integer ->> 'recuA')::numeric END;
  frais := recu IS NOT NULL AND extract(epoch FROM clock_timestamp()) * 1000 - recu <= 4 * 86400000;
  PERFORM public.sovarka_inventaire_retirer_interne(a, l, 1);
  IF frais THEN
    UPDATE public.personnages_donnees SET pa = least(30, coalesce(pa, 0) + 1), moral = least(100, coalesce(moral, 0) + 10), updated_at = now()
     WHERE name = a RETURNING pa, moral INTO v_pa, v_moral;
  ELSE
    UPDATE public.personnages_donnees SET pa = greatest(0, coalesce(pa, 0) - 1), updated_at = now()
     WHERE name = a RETURNING pa, moral INTO v_pa, v_moral;
  END IF;
  v := jsonb_build_object('ok', true, 'frais', frais, 'pa', v_pa, 'moral', v_moral) || public.tresor_tsars_inventaire_interne(a);
  RETURN public.achat_requete_clore_interne(a, p_requete, 'tresor_tsars_manger', prm, v);
END $$;

REVOKE ALL ON FUNCTION public.tresor_tsars_rang_interne(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.tresor_tsars_lieu_interne(text, text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.tresor_tsars_livre_index_interne(jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.tresor_tsars_inventaire_interne(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.tresor_tsars_fouille_interne(text, text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.tresor_tsars_guide() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.tresor_tsars_parler(text, boolean) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.tresor_tsars_donner_livre(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.tresor_tsars_recit(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.tresor_tsars_manger(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.tresor_tsars_guide() TO authenticated;
GRANT EXECUTE ON FUNCTION public.tresor_tsars_parler(text, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.tresor_tsars_donner_livre(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.tresor_tsars_recit(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.tresor_tsars_manger(uuid) TO authenticated;

DO $$
BEGIN
  IF (SELECT pieces FROM public.navigation_lieux_regles WHERE pays = 'soviet' AND ville = 'capitale' AND batiment = 'musee-novomirsk')
       IS DISTINCT FROM '["hall", "salle_origines", "salle_personnalites_discretes"]'::jsonb
     OR position('tresor_tsars_fouille_interne' IN pg_get_functiondef('public.fouiller_lieux()'::regprocedure)) = 0
     OR (SELECT count(*) FROM public.objets_modeles WHERE id IN ('tresor_tsars:livre', 'tresor_tsars:gateau')) <> 2 THEN
    RAISE EXCEPTION 'tresor_tsars_incomplet';
  END IF;
END $$;
