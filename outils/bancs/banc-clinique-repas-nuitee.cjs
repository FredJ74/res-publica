const {test}=require('node:test');
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'../..');
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const sql=read('migrations/20261113012000_clinique_nuitee_repas.sql');
const client=read('plateau-personnage.js');
const reservation=read('migrations/20261112133000_clinique_reservation_sans_expiration.sql');
test('La réservation de chambre ne transforme pas les clients en patients',()=>{
 assert.match(reservation,/reservationClinique.*true/);
 assert.match(sql,/v_j IS NULL AND p\.country IN \('republic','soviet'\)/);
 assert.match(sql,/p\.hospitalisation IS NULL OR p\.hospitalisation='null'::jsonb/);
 assert.ok(!sql.includes("SET hospitalisation ="));
});
test('Repas strictement réservé au détenteur de la chambre attribuée par le serveur',()=>{
 for(const token of ["personnage=moi","country=p.country","room_id=p.current_room","consommee_le IS NULL",
     "annulee_le IS NULL","l.data->>'locataire'=moi","l.data->>'reservationClinique'='true'","FOR UPDATE",
     "p.current_room ~ '^chambre_([1-9]|10)$'"])
   assert.ok(sql.includes(token),token);
});
test('Paiement exact, une fois par jour, +4 PA au prochain sommeil sans crédit immédiat',()=>{
 assert.match(sql,/ALTER TABLE public\.clinique_nuitees ADD COLUMN IF NOT EXISTS repas_le date/);
 assert.match(sql,/IF v_nuit\.repas_le=aujourdhui::date/);
 assert.match(sql,/v_pa<>1 OR v_cost<>30/);
 assert.match(sql,/payer_ordre_interne\(moi,'repas_clinique',v_pa,v_cost\)/);
 assert.match(sql,/UPDATE public\.clinique_nuitees SET repas_le=aujourdhui::date WHERE id=v_nuit\.id/);
 assert.match(sql,/bonus_pa_differe=coalesce\(bonus_pa_differe,0\)\+4/);
 assert.match(sql,/'bonus_lendemain',4/);
 assert.doesNotMatch(sql,/UPDATE public\.personnages_donnees SET\s+pa=pa\+4/);
});
test('Hospitalisés et hôpital public : logique préservée',()=>{
 assert.match(sql,/IF v_j IS NULL THEN RETURN jsonb_build_object\('ok',false,'raison','non_hospitalise'\)/);
 assert.match(sql,/p\.hospitalisation->>'repasLe' = aujourdhui/);
 assert.match(sql,/p\.current_building = 'clinique-privee' THEN v_fn := 'repas_clinique'; v_bonus := 4/);
 assert.match(sql,/LIKE 'dispensaire-public%' THEN v_fn := 'repas_hopital'; v_bonus := 2/);
 assert.match(sql,/hospitalisation = hospitalisation \|\| jsonb_build_object\('repasLe'/);
});
test('Client : même porte RPC et bonnes annonces selon nuitée ou hospitalisation',()=>{
 assert.match(client,/sbRpcVerdict\('hospitalisation_repas_prendre', \{\}\)/);
 assert.match(client,/r\.mode === 'nuitee'/);
 assert.match(client,/state\.country === 'soviet' \? 'PSK' : 'FR'/);
 assert.match(client,/prochain sommeil autorisé/);
 assert.match(client,/Repas de la clinique privée/);
});
