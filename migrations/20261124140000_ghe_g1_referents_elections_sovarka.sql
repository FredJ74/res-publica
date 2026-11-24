-- APPLIQUÉE en production le 24/11/2026 (contrôlée en lecture) — l'agent principal l'applique à la fusion (mission « Purge », 24/11/2026).
-- Point G.1 (Fred, 24/11/2026) : dans les trois villes de Sovarka, les secrétaires de mairie et les officiers des salles
-- des partis deviennent des référents élections (ils expliquent comment se présenter ; fiches DeepSeek :
-- api/_pnj-personnalites.js, SAVOIR_CANDIDATURE_SOVARKA). La liste fermée pnj_referents est celle que lit le PNJ guide
-- (point A.10) : chacun y figure, avec un domaine qui dit « élections ».
--   Novomirsk : Valentina Petchatkina (secrétaire municipale, profil sovarka_valentina_petchatkina) et le Capitaine Igor
--               Balatov (salle des partis, profil capitaine_igor_balatov) — ajoutés ;
--   Krasnov   : Galina Dokladova (secrétaire de mairie) et le lieutenant Fiodor Doznaïev (salle des partis) — ajoutés ;
--   Starovka  : Sayana Tsydypova et le lieutenant Tsyden Zhalsaraev, déjà référents (18/11) — leur domaine mentionne
--               désormais les élections (mise à jour gardée par l'ancien libellé).
-- Rejouable ; aucune donnée de joueur touchée ; rien du goulag.
BEGIN;
INSERT INTO public.pnj_referents (referent_id, domaine, pays)
SELECT x.id, x.domaine, 'soviet' FROM (VALUES
  ('sovarka_valentina_petchatkina', 'élections (comment se présenter) et démarches municipales — mairie de Novomirsk'),
  ('capitaine_igor_balatov', 'élections (comment se présenter) et partis de Sovarka — salle des partis de Novomirsk'),
  ('galina_dokladova', 'élections (comment se présenter) et démarches municipales — mairie de Krasnov'),
  ('lieutenant_fiodor_doznaiev', 'élections (comment se présenter) et partis de Sovarka — salle des partis de Krasnov')) AS x(id, domaine)
 WHERE NOT EXISTS (SELECT 1 FROM public.pnj_referents r WHERE r.referent_id = x.id);

UPDATE public.pnj_referents SET domaine = 'élections (comment se présenter) et démarches municipales — mairie de Starovka'
 WHERE referent_id = 'sayana_tsydypova' AND domaine = 'démarches municipales — mairie de Starovka';
UPDATE public.pnj_referents SET domaine = 'élections (comment se présenter) et partis de Sovarka — salle des partis de Starovka'
 WHERE referent_id = 'lieutenant_tsyden_zhalsaraev' AND domaine = 'partis de Sovarka — salle des partis de Starovka';

DO $$ BEGIN
  IF (SELECT count(*) FROM public.pnj_referents WHERE pays = 'soviet' AND domaine LIKE 'élections (comment se présenter)%'
        AND referent_id IN ('sovarka_valentina_petchatkina', 'capitaine_igor_balatov', 'galina_dokladova',
                            'lieutenant_fiodor_doznaiev', 'sayana_tsydypova', 'lieutenant_tsyden_zhalsaraev')) <> 6 THEN
    RAISE EXCEPTION 'ghe_g1_referents_elections_sovarka : contrôle structurel en échec';
  END IF;
END $$;
COMMIT;
