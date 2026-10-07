-- =============================================================================
-- CORRECTIF — directions_etablissements n'accorde plus rien aux roles clients
-- 7 octobre 2026
-- =============================================================================
--
-- CE QUE JE N'AVAIS PAS FERME. La migration
-- 20261007040000_direction_etablissements_salaire_serveur.sql cree la table
-- directions_etablissements et declare, en commentaire, qu'elle suit « le meme regime que
-- caisses_autorites » -- c'est-a-dire : RLS active, aucune policy, aucun droit client. Elle ne
-- portait pourtant qu'une seule ligne de revocation :
--
--     REVOKE ALL ON TABLE public.directions_etablissements FROM PUBLIC;
--
-- C'EST LE PIEGE SYMETRIQUE DE CELUI DEJA RENCONTRE TROIS FOIS SUR LES FONCTIONS. `FROM PUBLIC`
-- ne retire QUE le privilege accorde a PUBLIC. Or Supabase accorde `SELECT` a `anon` et a
-- `authenticated` NOMMEMENT sur toute table neuve du schema public, via ALTER DEFAULT
-- PRIVILEGES -- et une revocation sur PUBLIC ne touche pas un privilege nomme. La table est donc
-- nee avec `anon=r/postgres | authenticated=r/postgres`, ce que la reextraction du baseline a
-- rendu visible :
--
--     GRANT SELECT ON TABLE public.directions_etablissements TO anon;
--     GRANT SELECT ON TABLE public.directions_etablissements TO authenticated;
--
-- CE QUE CELA EXPOSAIT, EXACTEMENT : rien. La RLS est active et la table n'a AUCUNE policy, donc
-- une lecture par `anon` ou `authenticated` rend zero ligne. Le privilege etait inerte. Mesure du
-- 7 octobre 2026 : aucune policy sur cette table, et ses deux soeurs (caisses_autorites,
-- salaires_civils_declares) n'accordent rien aux roles clients.
--
-- POURQUOI LE CORRIGER QUAND MEME. Parce que le depot declarait une chose et la base en disait
-- une autre, et parce qu'une policy ajoutee plus tard aurait reveille ce privilege sans que
-- personne ne se demande s'il avait lieu d'etre. Un garde-fou qui ne tient que par l'absence
-- d'une autre ligne n'est pas un garde-fou.
--
-- Le fichier de la migration d'origine a ete corrige pour qu'une rejouee soit juste, et le meme
-- piege a ete ferme par avance dans 20261008000000_villes_referentiel_et_caisses_fail_closed.sql,
-- qui cree deux tables et n'est pas encore appliquee.
--
-- IDEMPOTENTE. Une revocation deja effectuee ne fait rien.
-- =============================================================================

BEGIN;

REVOKE ALL ON TABLE public.directions_etablissements FROM anon;
REVOKE ALL ON TABLE public.directions_etablissements FROM authenticated;

COMMIT;
