// Envoie les notifications aux heures de publication. Lancé toutes les 5 minutes par GitHub Actions.
import webpush from "web-push";
const SB=process.env.SB_URL||"https://jbalwfcedhchozxpynxu.supabase.co";
const ANON="sb_publishable_oHmX_3pfr8tw9QZLDisLhA_g9kvTIS8";
const PUBLIC="BOBZCPUmiBfkUVsizrjO127lwLjkgD0EnoYGR4Gx7-cXrvPYqcWMOg0G5I-V0bh7TmDj-bengcNKNzyRYycuEx4";
const {SEND_KEY,VAPID_PRIVATE,TEST,TEST_NAME,DRY}=process.env;
if(!SEND_KEY||!VAPID_PRIVATE){console.error("Secrets manquants : SEND_KEY et VAPID_PRIVATE.");process.exit(1)}
webpush.setVapidDetails("https://jsalmon30a.github.io/salmon30-marrakech/",PUBLIC,VAPID_PRIVATE);
const URL_APP="./";
const SLOTS=[
 {id:"night",at:"2026-12-18T21:00:00+01:00",title:"Le procès de ma vingtaine",body:"{n}, ta soirée vient de s'ouvrir. Rendez-vous sur la terrasse du riad."},
 {id:"gal",at:"2026-12-19T09:00:00+01:00",title:"En mémoire de l'enterrement de la vingtaine",body:"{n}, la galerie photos est ouverte. Les souvenirs de la nuit t'attendent."},
 {id:"bingo",at:"2026-12-19T10:30:00+01:00",title:"Le bingo de Marrakech",body:"{n}, le bingo est ouvert. À toi de jouer pendant ces trois jours."},
 {id:"desert",at:"2026-12-19T13:00:00+01:00",title:"L'énigme du désert",body:"{n}, une énigme vient d'arriver. Sauras-tu deviner la surprise de ce soir ?"},
 {id:"defi",at:"2026-12-19T19:00:00+01:00",title:"Le défi photo du désert",body:"{n}, ton défi photo est prêt. La révélation arrive demain matin."},
 {id:"quad",at:"2026-12-20T08:00:00+01:00",title:"Debout, les pilotes !",body:"{n}, prépare-toi pour l'aventure. La révélation du défi photo t'attend aussi."},
 {id:"souk",at:"2026-12-20T10:00:00+01:00",title:"Balade dans le souk",body:"{n}, on se perd dans la médina ce matin. Ta balade est ouverte."},
 {id:"anec",at:"2026-12-20T16:00:00+01:00",title:"Les anecdotes du quad",body:"{n}, raconte ton moment le plus drôle. Le mur des anecdotes est ouvert."},
 {id:"majo",at:"2026-12-21T09:00:00+01:00",title:"Le secret du jardin",body:"{n}, ta mission au Jardin Majorelle commence. Ouvre l'app."},
 {id:"missions",at:"2026-12-21T20:00:00+01:00",title:"La cérémonie des missions secrètes",body:"{n}, les missions vont être dévoilées. Rendez-vous dans l'app."}
];
const MAX_LATE_MS=12*3600e3;
// Missions secrètes : envoyées 40 minutes après l'arrivée de chacun (arrivée prévue + 40 min)
const ARR={"Juliette":"2026-12-18T09:20","Quentin":"2026-12-18T09:20","Adèle":"2026-12-18T19:30","Justine":"2026-12-18T14:40","Matéo":"2026-12-18T14:40","Pierre":"2026-12-18T14:40","Kevin":"2026-12-18T14:40","Bastien":"2026-12-18T14:40","Romain":"2026-12-18T21:40","Julie":"2026-12-18T21:40"};
const MISSION_DELAY_MS=40*60e3;
const nrm=t=>(t||"").normalize("NFD").replace(/[\u0300-\u036f]/g,"").toLowerCase();
async function rpc(fn,args){const r=await fetch(SB+"/rest/v1/rpc/"+fn,{method:"POST",headers:{apikey:ANON,Authorization:"Bearer "+ANON,"Content-Type":"application/json"},body:JSON.stringify(args)});if(!r.ok)throw new Error(fn+" "+r.status);const t=await r.text();return t?JSON.parse(t):null}
const st=await rpc("push_state",{p_key:SEND_KEY});
if(!st){console.error("Clé d'envoi refusée par Supabase : vérifie le secret SEND_KEY.");process.exit(1)}
const subs=st.subs,sent=new Set(st.sent),codes=st.codes||{},now=Date.now();
const ARRN=Object.fromEntries(Object.entries(ARR).map(([g,t])=>[nrm(g),Date.parse(t+":00+01:00")+MISSION_DELAY_MS]));
const CODEN=Object.fromEntries(Object.entries(codes).map(([g,c])=>[nrm(g),c]));
console.log(subs.length+" téléphone(s) abonné(s).");
let todo=[];
if(TEST==="oui")todo=[{id:null,title:"Test des notifications",body:"{n}, si tu lis ceci, les notifications fonctionnent."}];
else todo=SLOTS.filter(s=>{const t=Date.parse(s.at);return now>=t&&now-t<=MAX_LATE_MS&&!sent.has(s.id)});
if(!todo.length)console.log("Aucune page à publier pour le moment.");
for(const s of todo){let ok=0,ko=0;
 for(const sub of subs){
  if(TEST==="oui"&&TEST_NAME&&sub.guest.toLowerCase()!==TEST_NAME.toLowerCase())continue;
  const payload=JSON.stringify({title:s.title,body:s.body.replace("{n}",sub.guest||"Coucou"),tag:s.id||"test",url:URL_APP});
  if(DRY){console.log("[DRY]",sub.guest,payload);ok++;continue}
  try{await webpush.sendNotification({endpoint:sub.endpoint,keys:{p256dh:sub.p256dh,auth:sub.auth}},payload,{TTL:6*3600,urgency:"high"});ok++}
  catch(e){ko++;console.error("Échec pour",sub.guest,e.statusCode||e.message);if(e.statusCode===404||e.statusCode===410)await rpc("push_drop",{p_key:SEND_KEY,p_endpoint:sub.endpoint}).catch(()=>{})}}
 console.log((s.id||"test")+" : "+ok+" envoyée(s), "+ko+" échec(s).");
 if(s.id&&!DRY&&(ok>0||subs.length===0))await rpc("push_mark",{p_key:SEND_KEY,p_slot:s.id});
}

// Notification personnelle de mission : le code est caché dans le lien, jamais affiché à l'écran
if(TEST!=="oui"){
 for(const g of Object.keys(ARRN)){const id="mission_"+g,t=ARRN[g];
  if(!(now>=t&&now-t<=MAX_LATE_MS)||sent.has(id)||!CODEN[g])continue;
  const mine=subs.filter(x=>nrm(x.guest)===g);let ok=0,ko=0;
  for(const sub of mine){const payload=JSON.stringify({title:"Ta mission secrète t'attend",body:sub.guest+", une enveloppe cachetée t'attend dans l'app.",tag:id,url:"./?m="+encodeURIComponent(CODEN[g])});
   if(DRY){console.log("[DRY]",sub.guest,payload);ok++;continue}
   try{await webpush.sendNotification({endpoint:sub.endpoint,keys:{p256dh:sub.p256dh,auth:sub.auth}},payload,{TTL:6*3600,urgency:"high"});ok++}
   catch(e){ko++;console.error("Échec pour",sub.guest,e.statusCode||e.message);if(e.statusCode===404||e.statusCode===410)await rpc("push_drop",{p_key:SEND_KEY,p_endpoint:sub.endpoint}).catch(()=>{})}}
  console.log(id+" : "+ok+" envoyée(s), "+ko+" échec(s).");
  if(!DRY&&ok>0)await rpc("push_mark",{p_key:SEND_KEY,p_slot:id});}
}
