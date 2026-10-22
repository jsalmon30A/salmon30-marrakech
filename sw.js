const C="j30-v2",F=["./","index.html","manifest.webmanifest","icon-192.png","icon-512.png"];
self.addEventListener("install",e=>{self.skipWaiting();e.waitUntil(caches.open(C).then(c=>c.addAll(F)))});
self.addEventListener("activate",e=>e.waitUntil(caches.keys().then(k=>Promise.all(k.filter(x=>x!==C).map(x=>caches.delete(x)))).then(()=>self.clients.claim())));
self.addEventListener("fetch",e=>{if(e.request.method!=="GET")return;e.respondWith(fetch(e.request).then(r=>{const c=r.clone();caches.open(C).then(x=>x.put(e.request,c));return r}).catch(()=>caches.match(e.request)))});
self.addEventListener("push",e=>{let d={};try{d=e.data?e.data.json():{}}catch(_){d={body:e.data?e.data.text():""}}
 e.waitUntil(self.registration.showNotification(d.title||"Juliette 30 ans",{body:d.body||"",icon:"icon-192.png",badge:"icon-192.png",tag:d.tag||"j30",data:{url:d.url||"./"}}))});
self.addEventListener("notificationclick",e=>{e.notification.close();const u=new URL((e.notification.data&&e.notification.data.url)||"./",self.registration.scope).href;
 e.waitUntil(self.clients.matchAll({type:"window",includeUncontrolled:true}).then(l=>{for(const c of l){if("focus" in c)return c.focus().then(()=>("navigate" in c)?c.navigate(u):c)}return self.clients.openWindow(u)}))});
