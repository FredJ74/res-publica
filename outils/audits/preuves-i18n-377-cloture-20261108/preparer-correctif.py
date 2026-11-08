"""Produit un patch de présentation, sans écrire un fichier applicatif."""
from pathlib import Path
import difflib,json
R=Path(__file__).resolve().parents[3];D=Path(__file__).parent
files=['i18n/ordres.js','i18n/room-resources.js','i18n/plateau-init.js','plateau-politique.js','plateau-navigation.js','forum.js']
before={p:(R/p).read_text()for p in files};after=dict(before)
def replace(f,a,b):
 assert after[f].count(a)==1,(f,a[:80]);after[f]=after[f].replace(a,b)
replace('plateau-politique.js', '''    const libelleMarque = '<span data-rp-order-index="' + orderIndex + '">' + libelleAffiche + '</span>';''','''    // Le descripteur appartient au noeud, pas au dernier catalogue d'une autre pièce.
    const descripteurLibelle = JSON.stringify({fn:o.fn,label:o.label,i18nKey:o.i18nKey})
      .replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
    const libelleMarque = '<span data-rp-order-index="' + orderIndex + '" data-rp-order-description="' + descripteurLibelle + '">' + libelleAffiche + '</span>';''')
replace('i18n/ordres.js', '''   const index=Number(node.getAttribute?.('data-rp-order-index'));
   if(!Number.isSafeInteger(index)||index<0||index>=renderedOrders.length)continue;
   const ordre=renderedOrders[index];
   if(!ordre)continue;''','''   const description=node.getAttribute?.('data-rp-order-description');
   let ordre;
   if(description!=null){
    try{ordre=JSON.parse(description);}catch{continue;}
    if(!ordre||typeof ordre.fn!=='string'||typeof ordre.label!=='string')continue;
   }else{
    // Compatibilité des anciens consommateurs, nouveaux boutons auto-descriptifs.
    const index=Number(node.getAttribute?.('data-rp-order-index'));
    if(!Number.isSafeInteger(index)||index<0||index>=renderedOrders.length)continue;
    ordre=renderedOrders[index];
   }
   if(!ordre)continue;''')
replace('i18n/room-resources.js', ' global.RPRoomI18n=Object.freeze({label,labelHtml});', ''' function bindLabel(node,buildingId,roomId,original){
  if(!node)return;
  node.setAttribute('data-rp-room-description',JSON.stringify([buildingId,roomId,original]));
  node.textContent=label(buildingId,roomId,original);
 }
 function spanHtml(buildingId,roomId,original){
  const description=JSON.stringify([buildingId,roomId,original]).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  return '<span data-rp-room-description="'+description+'">'+labelHtml(buildingId,roomId,original)+'</span>';
 }
 function refreshVisibleLabels(root){
  for(const node of root?.querySelectorAll?.('[data-rp-room-description]')||[]){
   let data;try{data=JSON.parse(node.getAttribute('data-rp-room-description'));}catch{continue;}
   if(!Array.isArray(data)||data.length!==3||!data.every(v=>typeof v==='string'))continue;
   node.textContent=label(data[0],data[1],data[2]);
  }
 }
 global.RPRoomI18n=Object.freeze({label,labelHtml,bindLabel,spanHtml,refreshVisibleLabels});''')
replace('i18n/plateau-init.js','    global.RPOrderI18n?.refreshVisibleLabels?.(global.document,engine,locale);','''    global.RPOrderI18n?.refreshVisibleLabels?.(global.document,engine,locale);
    global.RPRoomI18n?.refreshVisibleLabels?.(global.document);''')
replace('plateau-navigation.js', '? RPRoomI18n.labelHtml(buildingId, roomId, tabName) : tabName;', '? (RPRoomI18n.spanHtml?.(buildingId, roomId, tabName) || RPRoomI18n.labelHtml(buildingId, roomId, tabName)) : tabName;')
a='''  document.getElementById('piece-nom').textContent =
    (typeof RPRoomI18n !== 'undefined')
      ? RPRoomI18n.label(buildingId, roomId, nomPieceAffiche) : nomPieceAffiche;'''
b='''  const titrePiece = document.getElementById('piece-nom');
  if (typeof RPRoomI18n !== 'undefined' && typeof RPRoomI18n.bindLabel === 'function')
    RPRoomI18n.bindLabel(titrePiece, buildingId, roomId, nomPieceAffiche);
  else titrePiece.textContent = (typeof RPRoomI18n !== 'undefined')
    ? RPRoomI18n.label(buildingId, roomId, nomPieceAffiche) : nomPieceAffiche;'''
replace('plateau-navigation.js',a,b)
# Attributs statiques uniquement : jamais les sujets, identités ou contenus PJ.
replace('forum.js', "${rpForumNom(id,f.name)}${nonVu ?", "<span${Object.hasOwn(window.RP_I18N_RESOURCES?.fr?.translation?.forumNames||{},id) && window.RP_I18N_RESOURCES.fr.translation.forumNames[id]===f.name ? ' data-i18n=\"forumNames.'+id+'\"' : ''}>${rpForumNom(id,f.name)}</span>${nonVu ?")
a=after['forum.js'].index('function renderMailCompose(');b=after['forum.js'].index('let _mailEnvoiEnCours',a)
segment=after['forum.js'][a:b]
for key,source in [('newMessage','Nouveau message'),('recipient','Destinataire'),('subject','Sujet'),('messageLabel','Message'),('sendButton','Envoyer')]:
 expression="${rpForumPlateauLibelle('"+key+"','"+source+"')}"
 assert segment.count(expression)==1
 segment=segment.replace(expression,'<span data-i18n="plateau.'+key+'">'+expression+'</span>')
segment=segment.replace("${rpForumLibelle('back','Retour')}",'<span data-i18n="forumUI.back">'+"${rpForumLibelle('back','Retour')}"+'</span>')
segment=segment.replace('id="mail-to" type="text"','id="mail-to" data-i18n-placeholder="plateau.recipientPlaceholder" type="text"').replace('id="mail-subject" type="text"','id="mail-subject" data-i18n-placeholder="plateau.subjectPlaceholder" type="text"')
after['forum.js']=after['forum.js'][:a]+segment+after['forum.js'][b:]
patch=''.join(''.join(difflib.unified_diff(before[p].splitlines(True),after[p].splitlines(True),fromfile='a/'+p,tofile='b/'+p))for p in files)
(D/'correctif-reference.patch').write_text(patch)
# Uniquement artefact /tmp et patch, jamais source modifiée.
Path('/tmp/cert377-sources-corrigees.json').write_text(json.dumps(after))
print(json.dumps({'fichiers':len(files),'fichiers_applicatifs_modifies':False,'patch':str(D/'correctif-reference.patch')}))
