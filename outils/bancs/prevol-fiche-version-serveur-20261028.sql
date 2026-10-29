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

-- Extension du 29/10 : preuve catalogue sans écriture.
-- updated_at possède DEFAULT now(), mais cela NE met PAS à jour les lignes à chaque UPDATE.
-- Aucun trigger explicitement dédié à la version/updated_at n'a été repéré
-- dans l'inspection ciblée des déclencheurs ; inspecter le corps des autres
-- triggers avant de conclure à une absence absolue de mise à jour.
select a.attname, pg_get_expr(d.adbin,d.adrelid) as default_expr
from pg_attribute a left join pg_attrdef d on d.adrelid=a.attrelid and d.adnum=a.attnum
where a.attrelid='public.personnages_donnees'::regclass
  and a.attname in ('updated_at','inventory_revision');

select p.proname, pg_get_function_identity_arguments(p.oid) as arguments
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and p.prokind='f'
  and pg_get_functiondef(p.oid) ilike '%update%personnages_donnees%'
order by p.proname;

-- La fermeture de #225 exige un jeton de version monotone pour TOUS les
-- chemins d'écriture canonique ou une séparation stricte des champs.
-- Ne pas mettre en production une comparaison CAS updated_at isolée.

-- Inspection exhaustive des 16 triggers non internes au 29/10 :
-- aucun des seize corps de fonction déclencheur ne contient 'updated_at'.
-- Confirmation : le DEFAULT now() n'est pas une version de mutation fiable.
select t.tgname, p.proname,
       position('updated_at' in lower(pg_get_functiondef(p.oid))) as touches_updated_at
from pg_trigger t join pg_proc p on p.oid=t.tgfoid
where t.tgrelid='public.personnages_donnees'::regclass and not t.tgisinternal
order by t.tgname;

-- Avant livraison : établir un protocole de version atomique applicable à
-- toute écriture serveur (y compris les UPDATE via SECURITY DEFINER), puis
-- éprouver un conflit entre deux sessions authentifiées sur la même fiche.
