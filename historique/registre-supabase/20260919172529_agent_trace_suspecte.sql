-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260919172529
-- Nom original      : agent_trace_suspecte
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-19 17:25:29 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 063ae48200dedcc60a7e0ba63eb6153c
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
-- LOT 2 — Trace laissee par un agent apres une collecte productive.
--
-- REGLE GD : un agent ne risque rien parce qu'il existe, attend ou stationne.
-- Le risque n'apparait QU'APRES une collecte ayant reellement produit au moins
-- une information. risque = max(5, 30 - DUP) %. RNG serveur. Une trace au
-- maximum par agent et par jour, quel que soit le nombre d'informations.
--
-- REUTILISATION : la trace est une ligne ordinaire d'actions_tracables, portee
-- par l'IDENTITE DE COUVERTURE. Le schema de cette table (auteur, cible,
-- type_action, country, city, jour, jour_expiration, decouvert) n'a AUCUNE
-- colonne pour un pays d'origine, une fonction ou une cellule : la trace est
-- donc structurellement incapable de reveler ce que le GD veut cacher.
--
-- ANTI-REJEU : l'anti-rejeu EST LA CLE (doctrine deja appliquee a
-- soldes_militaires et scandales_tentatives). L'id vaut
-- 'agent-<id_agent>-j<jour>' : une seconde collecte productive le meme jour
-- retombe sur la cle primaire et ne cree rien. Aucun index supplementaire.
--
-- LE JOUR DE JEU. actions_tracables.jour est un entier de jour de jeu, et le
-- serveur n'en connait aucun : personnages_donnees.day est un compteur PRIVE et
-- divergent par joueur. Le seul ecrivain serveur existant, corruption_presse_
-- tenter, abandonne et ecrit jour = 0 -- ce qui rend ses traces INVISIBLES au
-- client (sbGetActionsTracables filtre jour_expiration >= state.day) et les
-- classe DERNIERES dans plainte_instruire_interne (ORDER BY jour DESC).
-- On derive donc le jour du pays d'accueil : max(day) des personnages de ce
-- pays, 1 a defaut. C'est le referentiel des joueurs susceptibles de decouvrir
-- la trace, il est lu dans des donnees canoniques, et il place la trace dans le
-- meme cadre temporel qu'eux. jour_expiration = jour + 7, comme toute trace.

CREATE OR REPLACE FUNCTION public.jour_de_jeu_pays(p_pays text)
RETURNS integer
LANGUAGE sql
STABLE
SET search_path TO 'public'
AS $function$
  SELECT greatest(1, coalesce(max(d.day), 1))
    FROM public.personnages_donnees d WHERE d.country = p_pays;
$function$;

CREATE OR REPLACE FUNCTION public.agent_trace_deposer(p_agent_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  a record; v_risque integer; v_jet integer; v_jour integer; v_id text;
BEGIN
  SELECT ag.id, ag.dup, ag.nom_couverture, ag.pays_couverture, ag.ville,
         ag.building_id, ag.statut, ag.leader_courant, c.statut AS statut_cellule
    INTO a
    FROM public.agents_renseignement ag
    JOIN public.cellules_renseignement c ON c.id = ag.cellule_id
   WHERE ag.id = p_agent_id;

  IF a.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'agent_introuvable');
  END IF;
  IF a.statut_cellule <> 'active' OR a.statut <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'agent_inactif');
  END IF;
  -- Un agent en deplacement (porte par un chef) n'est pas pose : il ne collecte
  -- pas, il ne laisse donc pas de trace.
  IF a.leader_courant IS NOT NULL OR a.ville IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'agent_non_pose');
  END IF;

  v_risque := greatest(5, 30 - coalesce(a.dup, 8));
  v_jet    := floor(random() * 100)::integer + 1;          -- RNG SERVEUR
  IF v_jet > v_risque THEN
    RETURN jsonb_build_object('ok', true, 'trace', false, 'risque', v_risque);
  END IF;

  v_jour := public.jour_de_jeu_pays(a.pays_couverture);
  v_id   := 'agent-' || a.id || '-j' || v_jour;

  INSERT INTO public.actions_tracables
    (id, auteur, cible, type_action, country, city, jour, jour_expiration, decouvert)
  VALUES (v_id, a.nom_couverture, NULL, 'presence_suspecte',
          a.pays_couverture, a.ville, v_jour, v_jour + 7, false)
  ON CONFLICT (id) DO NOTHING;           -- deja trace aujourd'hui : rien de plus

  RETURN jsonb_build_object('ok', true, 'trace', true, 'risque', v_risque,
                            'reference', v_id);
END;
$function$;

REVOKE ALL ON FUNCTION public.jour_de_jeu_pays(text)      FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.agent_trace_deposer(text)   FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.jour_de_jeu_pays(text)    TO service_role;
GRANT EXECUTE ON FUNCTION public.agent_trace_deposer(text) TO service_role;
