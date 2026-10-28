-- Prévol lecture seule : aucune mise à jour de données réelles.
-- La comparaison updated_at ne protège pas les modifications qui omettent la date.
select t.tgname, pg_get_triggerdef(t.oid) as definition
from pg_trigger t
where t.tgrelid='public.personnages_donnees'::regclass and not t.tgisinternal
order by t.tgname;

-- Lister les fonctions qui modifient cette table et doivent faire avancer la version.
select n.nspname, p.proname, pg_get_function_arguments(p.oid) as arguments
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and pg_get_functiondef(p.oid) ilike '%update personnages_donnees%'
order by p.proname;

-- Vérifier si la vue personnages possède une porte d'écriture INSTEAD OF.
select t.tgname, pg_get_triggerdef(t.oid) as definition
from pg_trigger t where t.tgrelid='public.personnages'::regclass and not t.tgisinternal;
