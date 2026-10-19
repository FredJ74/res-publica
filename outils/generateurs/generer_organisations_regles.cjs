// Charge la source reelle dans Node ; aucun parseur approximatif des constantes.
const fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const racine=path.resolve(__dirname,'../..');
function regles(){const t=vm.runInNewContext(fs.readFileSync(path.join(racine,'data.js'),'utf8')+';TYPES_ORGANISATIONS',{}, {timeout:5000});
 return Object.fromEntries(Object.entries(t).map(([k,v])=>[k,{grades:v.grades,maxAdhesion:v.maxAdhesion}]));}
function bloc(){return '-- DEBUT REGLES GENEREES\nCREATE OR REPLACE FUNCTION public.organisation_regles_membres() RETURNS jsonb\nLANGUAGE sql IMMUTABLE SET search_path=public,pg_temp AS $regles$\n SELECT '+"'"+JSON.stringify(regles()).replaceAll("'","''")+"'::jsonb;\n$regles$;\nREVOKE ALL ON FUNCTION public.organisation_regles_membres() FROM PUBLIC,anon,authenticated;\n-- FIN REGLES GENEREES";}
module.exports={regles,bloc};
if(require.main===module){if(process.argv.includes('--check')){
 const s=fs.readFileSync(path.join(racine,'migrations/20261019130213_organisations_adhesions_grades.sql'),'utf8');
 if(!s.includes(bloc())){console.error('Regles membres SQL divergentes de data.js');process.exitCode=1;}else console.log('Neuf types : regles SQL identiques a data.js');
}else process.stdout.write(bloc()+'\n');}
