'use strict';
const page = document.body.dataset.page;
const el = id => document.getElementById(id);
const escape = value => String(value ?? 'Unavailable').replace(/[&<>"']/g, ch => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[ch]));
const date = (value, unix=false, unknown=false) => {
  if (!value) return 'Time unavailable';
  if (unknown && !/[Zz]|[+-]\d\d:\d\d$/.test(value)) return `${value} (GLPI source timezone)`;
  const d = new Date(unix ? Number(value)*1000 : value);
  return Number.isNaN(d.getTime()) ? String(value) : d.toLocaleString('en-GB', {timeZone:'UTC',day:'2-digit',month:'short',hour:'2-digit',minute:'2-digit',second:'2-digit'})+' UTC';
};
const badge = status => `<span class="badge ${['Healthy','Degraded','Unavailable'].includes(status)?status:''}">${escape(status)}</span>`;
const table = (headers, rows) => `<div class="table-wrap"><table><thead><tr>${headers.map(h=>`<th>${escape(h)}</th>`).join('')}</tr></thead><tbody>${rows.map(row=>`<tr>${row.map(c=>`<td>${c}</td>`).join('')}</tr>`).join('')}</tbody></table></div>`;
const empty = message => `<div class="empty">${escape(message)}</div>`;
const metric = (name, value, foot) => `<article class="metric"><div class="metric-label">${escape(name)}</div><div class="metric-value ${value==null?'unavailable':''}">${escape(value)}</div><div class="metric-foot">${escape(foot)}</div></article>`;
const count = collection => collection ? (collection.total ?? collection.returned) : null;
const countScope = collection => collection?.count_label ?? 'Source read unavailable';
const readableState = value => ({RECOVERED_PENDING_OPERATOR_VALIDATION:'Awaiting operator validation',PROBLEM_OPEN:'Problem open',DRY_RUN_PROBLEM:'Dry-run Problem',OPERATOR_RECONCILIATION_REQUIRED:'Operator reconciliation required',TICKET_CREATE_PENDING:'Ticket creation unconfirmed',FOLLOWUP_CREATE_PENDING:'Follow-up unconfirmed'}[value]??value);
const identifier = value => {
  const full = String(value ?? 'Unavailable');
  if (!/^urn:uuid:|^[0-9a-f]{8}-[0-9a-f-]{27}$/i.test(full) || full.length < 32) return escape(full);
  return `<span class="technical-id" tabindex="0" title="${escape(full)}" aria-label="${escape(full)}">${escape(full.slice(0,17))}&#8230;${escape(full.slice(-12))}</span>`;
};
const row = (number,title,detail,value) => `<div class="correlation-row"><span class="step-number">${number}</span><div class="step-content"><strong>${escape(title)}</strong><small>${identifier(detail)}</small></div><div class="step-value">${escape(value)}</div></div>`;
document.querySelectorAll(`[data-nav="${page}"]`).forEach(link => {link.classList.add('active');link.setAttribute('aria-current','page');});
const titles={overview:'Operations overview',infrastructure:'Infrastructure inventory',incidents:'Integration incidents',events:'Event correlation',runbooks:'Operational Runbooks'};
el('page-title').textContent=titles[page];
el('detail-heading').textContent=titles[page];
el('overview-content').hidden=page!=='overview';
el('detail-content').hidden=page==='overview'||page==='runbooks';
if(page==='runbooks'){
  el('status-strip').hidden=true;
  el('refresh').hidden=true;
  el('updated').textContent='Read-only catalog · Operator-local execution';
}

function render(d){
  const z=d.zabbix,g=d.glpi,i=d.integration,infra=d.synthetic_infrastructure,m=d.episode_metrics;
  if(el('ai-ticket')){
    const selected=el('ai-ticket').value;
    const tickets=(d.incidents??[]).filter(t=>t.episode?.mode==='live');
    el('ai-ticket').innerHTML=tickets.map(t=>`<option value="${escape(t.id)}">#${escape(t.id)} · Event ${escape(t.episode.event_id)}</option>`).join('');
    if(tickets.some(t=>String(t.id)===selected))el('ai-ticket').value=selected;
    else if(tickets.some(t=>t.id===d.latest_episode?.glpi_ticket_id))el('ai-ticket').value=String(d.latest_episode.glpi_ticket_id);
    el('ai-analyze').disabled=!tickets.length||aiBusy;
  }
  el('status-strip').innerHTML=[['Zabbix',z,'Observability API'],['GLPI',g,'ITSM / CMDB API'],['GIOP Integration',i,i.mode?`Mode: ${i.mode}`:'Correlation API'],['Synthetic Infrastructure',infra,'Pilot trigger status']].map(([name,source,description])=>`<div class="source-status ${escape(source.status)}"><span class="status-dot"></span><div><strong>${escape(name)}</strong><small>${escape(description)}</small></div>${badge(source.status)}</div>`).join('');
  el('updated').textContent='Last updated: '+date(d.updated_at);
  if(page==='overview'){
    el('metrics').innerHTML=[metric('Zabbix · monitored hosts',z.monitored_hosts,'API-visible enabled hosts'),metric('Zabbix · active Problems',z.active_problems,'Current API-visible Problems'),metric('GLPI · Computers',count(g.computers),countScope(g.computers)),metric('Integration · awaiting validation',m?.awaiting_validation,'LIVE · within latest 100 persisted episodes')].join('');
    const e=d.latest_episode;
    if(!e) el('correlation').innerHTML=empty(i.status==='Unavailable'?'Integration episodes unavailable.':'No persisted episodes in the returned window.');
    else {
      const ticket=d.incidents?.find(t=>String(t.id)===String(e.glpi_ticket_id));
      el('correlation').innerHTML=`<div class="episode-banner"><div><strong>Persistent event-to-incident correlation</strong><small>${escape(e.mode)} mode · Synthetic LAB episode</small></div>${badge(readableState(e.status))}</div>`+
        row('01','Zabbix Problem',date(e.problem_time),`Event ${e.event_id}`)+
        row('02','Synthetic monitored host',e.mapping?.host_name??`Pilot trigger ${e.trigger_id}`,`Host ${e.host_id}`)+
        row('03','Mapped configuration item',e.ci_uid,e.mapping?`Computer ${e.mapping.computer_id} · Entity ${e.mapping.entity_id}`:'Mapping unavailable')+
        row('04','GLPI Incident',ticket?.name??'Ticket reference from persisted integration state',e.glpi_ticket_id?`Ticket #${e.glpi_ticket_id}`:'No confirmed Ticket ID')+
        row('05','Recovery / Follow-up',e.recovery_time?date(e.recovery_time):'Recovery not recorded',e.recovery_event_id?`Event ${e.recovery_event_id} · Follow-up ${e.followup_id??'unconfirmed'}`:'Awaiting Recovery')+
        row('06','Operator validation','Automatic closure is disabled',e.status==='RECOVERED_PENDING_OPERATOR_VALIDATION'?'Validation required':'See episode state');
    }
    const timeline=[...d.timeline].sort((a,b)=>{
      const time=x=>x.timezone_unknown?0:(x.unix?Number(x.timestamp)*1000:Date.parse(x.timestamp)||0);
      return time(b)-time(a);
    }).slice(0,12);
    el('timeline').innerHTML=timeline.length?timeline.map(t=>`<div class="timeline-item"><span class="timeline-dot"></span><div><strong>${escape(t.event)}</strong><span class="source">${escape(t.source)}</span><p>${escape(t.reference)} · ${escape(t.host)}${t.ticket?' · Ticket #'+escape(t.ticket):''}</p><p>${escape(readableState(t.status))}</p></div><time>${escape(date(t.timestamp,t.unix,t.timezone_unknown))}</time></div>`).join(''):empty('No timeline records available from current sources.');
    el('pilot-state').innerHTML=`<div class="service-name">GUA-LAB-SRV-WEB-001 · Synthetic pilot</div><div class="service-state">${escape(infra.status)}</div>${badge(z.pilot?String(z.pilot.value)==='0'?'OK':'PROBLEM':'Unavailable')}<div class="pilot-state-note">${escape(z.pilot?.description??'Pilot trigger read unavailable')}</div><div class="pilot-state-note">${m?`${m.open} open · ${m.awaiting_validation} LIVE awaiting validation · ${m.dry_run} dry-run · ${m.returned} episodes returned`:'Episode counts unavailable'}</div><div class="pilot-state-note">Network equipment: ${g.network?count(g.network)+' · '+countScope(g.network):'Unavailable'}</div>`;
  } else if(page==='infrastructure'){
    let html='<h3 class="section-heading">Zabbix · Monitored hosts</h3><p class="table-note">API-visible enabled hosts · Listing capped at 100. Agent availability is distinct from service health.</p>';
    html+=z.hosts?table(['Host','Source','State','Location','Environment'],z.hosts.map(h=>[escape(h.name||h.host)+`<br><small>ID ${escape(h.hostid)}</small>`,'Zabbix',`Monitoring enabled<br><small>Active agent availability: ${escape(h.active_available)}</small>`,'Not supplied', '<span class="lab-pill">SYNTHETIC LAB</span>'])):empty('Zabbix inventory unavailable.');
    for(const [key,title] of [['computers','Computers'],['network','Network equipment']]){
      const c=g[key];html+=`<h3 class="section-heading">GLPI · ${title}</h3><p class="table-note">${c?escape(count(c)+' · '+countScope(c)):'Source read unavailable'} · Entity 0 · Up to ${c?.limit ?? 100} rows</p>`;
      html+=c?table(['Asset','Source','Asset status','Location','Environment'],c.items.map(a=>[escape(a.name)+`<br><small>ID ${escape(a.id)}</small>`,'GLPI',escape(a.status??'Not supplied'),escape(a.location??'Not supplied'),'<span class="lab-pill">SYNTHETIC LAB</span>'])):empty('GLPI asset collection unavailable.');
    } el('detail-body').innerHTML=html;
  } else if(page==='incidents'){
    const rows=d.incidents;
    el('detail-body').innerHTML='<p class="table-note">GIOP-marked or episode-linked tickets within the latest 100 API-visible tickets. No global open-Incident total is claimed. GLPI status/priority are API labels or raw IDs.</p>'+ (rows==null?empty('GLPI Tickets unavailable.'):rows.length?table(['Ticket / title','Status / priority','Source event','Mapped CI','Created','Recovery state'],rows.map(t=>[ `<strong>#${escape(t.id)}</strong> ${escape(t.name)}`,`${escape(t.status)} / ${escape(t.priority)}`,escape(t.episode?.event_id??'Not in episode window'),identifier(t.episode?.ci_uid??'Not available'),escape(date(t.date_creation,false,true)),escape(t.episode?.status??'Not in episode window')])):empty('No GIOP-marked Incidents in the returned Ticket window.'));
  } else {
    const episodes=i.episodes;
    el('detail-body').innerHTML=`<p class="table-note">${escape(i.scope??'Integration read unavailable')} · Duplicate suppression counters are not exposed by the source API.</p>`+(episodes==null?empty('Integration episodes unavailable.'):episodes.length?table(['Problem / Recovery','Host / trigger','GLPI Ticket','State / mode','Problem time','Recovery time'],episodes.map(e=>[`${escape(e.event_id)} / ${escape(e.recovery_event_id??'Pending')}`,`${escape(e.host_id)} / ${escape(e.trigger_id)}`,escape(e.glpi_ticket_id??'Unconfirmed'),`${escape(e.status)}<br><small>${escape(e.mode)}</small>`,escape(date(e.problem_time)),escape(e.recovery_time?date(e.recovery_time):'Not recorded')])):empty('No persisted episodes returned.'));
  }
}
let aiBusy=false;
if(el('ai-analyze')){
  el('ai-ticket').addEventListener('change',()=>{el('ai-result').innerHTML='<p class="ai-placeholder">Incident selection changed. Request an analysis for this incident; previous recommendations are not carried over.</p>';});
  el('ai-analyze').addEventListener('click',async()=>{
    if(aiBusy||!el('ai-ticket').value)return;
    aiBusy=true;el('ai-analyze').disabled=true;el('ai-ticket').disabled=true;
    const ticketId=Number(el('ai-ticket').value);
    el('ai-result').innerHTML='<p class="ai-placeholder">Reviewing bounded evidence… No infrastructure action is possible.</p>';
    try{
      const response=await fetch('/api/ai/analyze',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({ticket_id:ticketId})});
      if(!response.ok)throw Error('Analysis unavailable');
      showAnalysis(await response.json());
    }catch{showAnalysis({status:'AI_UNAVAILABLE'});}
    finally{aiBusy=false;el('ai-analyze').disabled=false;el('ai-ticket').disabled=false;}
  });
}
function showAnalysis(result){
  const messages={AI_UNAVAILABLE:['Unavailable','AI assistance is unavailable. Monitoring, Incident correlation and operator runbooks remain available.'],AI_ANALYSIS_INVALID:['AI analysis invalid','The provider output did not meet the advisory contract. No result has been fabricated.'],INSUFFICIENT_EVIDENCE:['Insufficient evidence','Approved correlated incident evidence is insufficient. Review diagnostics and source visibility.'],AI_CONTEXT_INVALID:['Context invalid','The supplied context could not be accepted. Review bounded diagnostics.']};
  if(result.status!=='SUCCESS'){
    const [title,detail]=messages[result.status]??messages.AI_UNAVAILABLE;
    el('ai-result').innerHTML=`<div class="ai-unavailable"><strong>${escape(title)}</strong><p>${escape(detail)}</p></div>`;return;
  }
  const a=result.analysis, percent=value=>Math.round(value*100)+'%', names={'RB-OPS-001':'Service Health Check','RB-OPS-002':'Collect Incident Diagnostics','RB-OPS-003':'Controlled LAB Recovery'};
  el('ai-result').innerHTML=`${result.fixture?'<div class="ai-fixture">FIXTURE PROVIDER · Deterministic validation output — not a language model</div>':''}
    <div class="ai-incident"><div><span class="eyebrow">INCIDENT #${escape(result.incident_id)}</span><strong>${escape(readableState(result.episode_state))}</strong></div><div><span class="ai-confidence">${escape(percent(a.overall_confidence))}</span><small>Inference confidence · not a calibrated probability</small></div></div>
    <p class="ai-summary">${escape(a.summary)}</p>
    <p class="ai-provenance">Affected service: ${escape(a.affected_service)} · Logical CI: Computer ${escape(result.ci.computer_id)} · ${identifier(result.ci.ci_uid)}</p>
    <div class="ai-grid"><div><h3 class="ai-label">OBSERVED</h3><ul class="ai-observed">${result.observed.map(f=>`<li><span aria-hidden="true">✓</span><div>${escape(f.statement)}<small>${escape(f.source)} · ${escape(f.window)}${f.observed_at?' · '+escape(date(f.observed_at)):''}</small></div></li>`).join('')}</ul></div>
    <div><h3 class="ai-label inferred">INFERRED · PROBABLE CAUSES</h3>${a.probable_causes.map(c=>`<div class="ai-cause"><strong>${escape(c.cause)}</strong><p>Confidence: ${escape(percent(c.confidence))}</p><small>Evidence: ${escape(c.evidence.join(', '))}</small></div>`).join('')}
    <h3 class="ai-label unknown">UNKNOWN · MISSING INFORMATION</h3><ul>${a.missing_information.map(value=>`<li>${escape(value)}</li>`).join('')}</ul></div></div>
    <div class="ai-grid ai-next"><div><h3 class="ai-label">RECOMMENDED CHECKS</h3><ol>${a.recommended_checks.map(value=>`<li>${escape(value)}</li>`).join('')}</ol></div>
    <div class="ai-runbook"><h3 class="ai-label">SUGGESTED RUNBOOK</h3><strong>${escape(a.recommended_runbook.id)} · ${escape(names[a.recommended_runbook.id])}</strong><p>${escape(a.recommended_runbook.reason)}</p><span class="ai-risk">Risk: ${escape(a.recommended_runbook.risk)} · synthetic target only</span></div></div>
    <div class="ai-approval"><strong>Operator approval required</strong><p>${escape(a.operator_notes)}</p><a href="/runbooks">Review operational runbook governance →</a></div>
    <p class="ai-provenance">Provider: ${escape(result.provider)} · ${escape(result.model)} · ${result.cached?'Cached context analysis':'Explicitly requested analysis'}${result.diagnostics_execution?' · Diagnostics '+escape(result.diagnostics_execution):' · Historical workload diagnostics unavailable'}</p>`;
}
let busy=false;
async function refresh(){
  if(busy)return;busy=true;el('refresh').disabled=true;
  try{const response=await fetch('/api/overview',{cache:'no-store'});if(!response.ok)throw Error('Read unavailable');render(await response.json());el('fetch-warning').hidden=true;}
  catch{el('fetch-warning').hidden=false;}finally{busy=false;el('refresh').disabled=false;}
}
el('refresh').addEventListener('click',refresh);
if(page!=='runbooks'){refresh();setInterval(refresh,20000);}
function clock(){el('clock').textContent=new Date().toLocaleTimeString('en-GB',{timeZone:'UTC'})+' UTC';}clock();setInterval(clock,1000);
