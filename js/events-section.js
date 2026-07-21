/* Shared "upcoming <category>" listing, used by opus-academy.html and
   relational-forest-therapy-academy--guide-training.html (and any future page).
   Keep this the single source of truth — do not copy-paste it per page.

   Each page declares one (or more) container(s) plus this script, e.g.:

     <div class="ev-list"
          data-category="Opus Training"
          data-path="opus-academy"
          data-empty="Upcoming events will be announced here.">
       <p class="events-empty">Upcoming events will be announced here.</p>
     </div>
     <script src="js/events-section.js"></script>

   It fetches data/trainings.json, shows records whose `category` equals
   data-category, drops past ones, sorts soonest-first, and renders each as a
   clickable card opening apply.html?event=<id>&path=<data-path>. On a failed
   fetch or no upcoming records it shows the data-empty quiet line.
   Styling lives in each page's stylesheet (.ev-list/.ev-card/... classes). */
(function(){
  var boxes=[].slice.call(document.querySelectorAll('.ev-list[data-category]'));
  if(!boxes.length) return;
  var MON=['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  function esc(s){return String(s==null?'':s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');}
  function fmt(d){if(!d)return '';var p=String(d).split('-');if(p.length!==3)return d;return MON[parseInt(p[1],10)-1]+' '+parseInt(p[2],10)+', '+p[0];}
  function money(v){if(v==null||v==='')return '';var n=Number(v);return isNaN(n)?'':'$'+n.toLocaleString('en-US');}
  var today=new Date().toISOString().slice(0,10);
  function startKey(e){return e.startDate||e.firstCall||e.date||e.enrollmentDeadline||'9999-12-31';}
  function lastKey(e){return [e.startDate,e.firstCall,e.date,e.enrollmentDeadline].filter(Boolean).sort().pop()||'0000-01-01';}
  // hide cohorts that are no longer joinable (full / waitlist / registration closed)
  function isOpen(e){return !/waitlist|full|closed|sold\s*out/i.test(e.status||'');}
  function quiet(box){box.innerHTML='<p class="events-empty">'+esc(box.getAttribute('data-empty')||'Upcoming events will be announced here.')+'</p>';}
  function card(e,path){
    var meta=[];
    if(e.startDate)meta.push('<b>Begins</b> '+esc(fmt(e.startDate)));
    else if(e.firstCall)meta.push('<b>First call</b> '+esc(fmt(e.firstCall)));
    if(e.enrollmentDeadline)meta.push('<b>Enroll by</b> '+esc(fmt(e.enrollmentDeadline)));
    if(e.schedule)meta.push(esc(e.schedule));
    if(e.language)meta.push(esc(e.language));
    var price=money(e.price), dep=money(e.deposit);
    var href='apply.html?event='+encodeURIComponent(e.id)+(path?'&path='+encodeURIComponent(path):'');
    return '<a class="ev-card" href="'+href+'">'+
      '<div class="ev-title">'+esc(e.title)+(e.cohort?' <span class="ev-cohort">Cohort '+esc(e.cohort)+'</span>':'')+'</div>'+
      (meta.length?'<div class="ev-meta">'+meta.join(' &middot; ')+'</div>':'')+
      (price?'<div class="ev-meta"><b>Tuition</b> '+price+(dep?' &middot; <b>Deposit</b> '+dep:'')+'</div>':'')+
      '<span class="ev-go">Begin your application &rarr;</span></a>';
  }
  var dataPromise=fetch('data/trainings.json').then(function(r){if(!r.ok)throw 0;return r.json();});
  boxes.forEach(function(box){
    var cat=box.getAttribute('data-category'), path=box.getAttribute('data-path')||'';
    dataPromise.then(function(data){
      var evs=(data.trainings||[]).concat(data.events||[])
        .filter(function(e){return e.category===cat;})
        .filter(function(e){return lastKey(e)>=today;})
        .filter(isOpen)
        .sort(function(a,b){var x=startKey(a),y=startKey(b);return x<y?-1:(x>y?1:0);});
      if(!evs.length){quiet(box);return;}
      box.innerHTML=evs.map(function(e){return card(e,path);}).join('');
    }).catch(function(){quiet(box);});
  });
})();
