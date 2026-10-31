"""Trois commandes réelles sous authenticated sur catalogue entier, JWT fictifs."""
import json
def recette(q):
 q.execute('SAVEPOINT recette_organisations95')
 uid='00000219-3000-4000-8000-000000000001';autre='00000219-3000-4000-8000-000000000002'
 for nom,u in [('__hg219_orgchef',uid),('__hg219_orginvite',autre)]:
  q.execute("SELECT set_config('request.jwt.claim.sub',%s,true),set_config('request.jwt.claims',%s,true)",(u,json.dumps({'sub':u,'role':'authenticated'})))
  q.execute("INSERT INTO auth.users(id,email,is_anonymous,email_confirmed_at) VALUES(%s,%s,false,now())",(u,nom+'@example.invalid'))
  q.execute("INSERT INTO personnages_donnees(name,user_id,country,current_city,current_building,current_room,pa,liquide,arg,hp) VALUES(%s,%s,'republic','capitale','mairie','accueil',100,1000,1000,100)",(nom,u))
 org={'id':'__hg219_organisation','chef':'__hg219_orgchef','nom':'Organisation fictive','type':'criminelle','visible':False,'country_origine':'republic','membres':[{'nom':'__hg219_orgchef','gradeIdx':3}],'caisse':700}
 q.execute('INSERT INTO organisations(id,country_origine,data) VALUES(%s,%s,%s)',(org['id'],'republic',json.dumps(org)))
 def rpc(fn,action,params,cle,acteur=uid):
  q.execute("SELECT set_config('request.jwt.claim.sub',%s,true),set_config('request.jwt.claims',%s,true),set_config('request.path',%s,true),set_config('role','authenticated',true)",(acteur,json.dumps({'sub':acteur,'role':'authenticated'}),'/rpc/'+fn))
  q.execute('SELECT public.'+fn+'(%s,%s,%s,%s::jsonb)',(cle,org['id'],action,json.dumps(params)));v=q.fetchone()[0];q.execute('RESET ROLE');assert v['ok'],v;return v
 resultats=[]
 try:
  rpc('organisation_commande_administrative','informations',{'nom':'Nom confirmé'},'orgcmd-catalogue-nom-001');resultats.append({'cas':'organisation_administrative_catalogue','ok':True})
  rpc('organisation_commande_evenement','inviter',{'nom':'__hg219_orginvite'},'orgcmd-catalogue-inviter-001');v=rpc('organisation_commande_evenement','inviter',{'nom':'__hg219_orginvite'},'orgcmd-catalogue-inviter-001');assert v['rejeu'];resultats.append({'cas':'organisation_evenement_rejeu_catalogue','ok':True})
  rpc('organisation_commande_membres','accepter_invitation',{},'orgcmd-catalogue-accepter-001',autre)
  q.execute('SELECT data::jsonb FROM organisations WHERE id=%s',(org['id'],));d=q.fetchone()[0];assert d['caisse']==700 and any(x['nom']=='__hg219_orginvite' for x in d['membres']);resultats.append({'cas':'organisation_membres_et_caisse_preservee_catalogue','ok':True})
 finally:q.execute('ROLLBACK TO SAVEPOINT recette_organisations95')
 return resultats
