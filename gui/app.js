// Simple DMA visualizer app.js
const playBtn = document.getElementById('playBtn');
const pauseBtn = document.getElementById('pauseBtn');
const speedInput = document.getElementById('speed');
const eventsDiv = document.getElementById('events');

let timeline = [];
let tIndex = 0;
let playing = false;
let timer = null;
let speed = 1.0;

const svg = document.getElementById('arch');

function log(msg) { const el = document.createElement('div'); el.textContent = msg; eventsDiv.prepend(el); }

function flash(id, dur=600) {
  const node = document.getElementById(id);
  if (!node) return;
  node.classList.add('flash');
  setTimeout(()=> node.classList.remove('flash'), dur);
}

function pulseLine(pathId, dur=800) {
  const p = document.getElementById(pathId);
  if (!p) return;
  p.classList.add('pulse-line');
  setTimeout(() => p.classList.remove('pulse-line'), dur);
}

function movePacketAlong(pathId, label, dur=800, isSram=false) {
  const path = document.getElementById(pathId);
  if (!path) return;
  const len = path.getTotalLength();
  const circle = document.createElementNS('http://www.w3.org/2000/svg','circle');
  circle.setAttribute('r', 8);
  circle.setAttribute('class', isSram ? 'packet-sram' : 'packet');
  svg.appendChild(circle);
  let start = null;
  function step(ts) {
    if (!start) start = ts;
    const t = (ts-start)/dur;
    if (t>1) {
      svg.removeChild(circle);
      return;
    }
    const pt = path.getPointAtLength(len * t);
    circle.setAttribute('cx', pt.x);
    circle.setAttribute('cy', pt.y);
    requestAnimationFrame(step);
  }
  requestAnimationFrame(step);
}

function handleEvent(ev) {
  log(`> ${ev.type} ${ev.payload || ''}`);
  
  if (ev.type === 'SOC_WRITE_CSR') {
    pulseLine('p_soc_csr', 400);
    movePacketAlong('p_soc_csr', '', 400);
    setTimeout(() => flash('csr', 600), 400);
  } 
  else if (ev.type === 'CSR_NOTIFY_RING') {
    pulseLine('p_csr_ring', 500);
    movePacketAlong('p_csr_ring', '', 500);
    setTimeout(() => flash('ring', 600), 500);
  }
  else if (ev.type === 'RING_NOTIFY_DESC') {
    pulseLine('p_ring_desc', 600);
    movePacketAlong('p_ring_desc', '', 600);
    setTimeout(() => flash('desc', 600), 600);
  }
  else if (ev.type === 'DESC_FETCH_AXI') {
    pulseLine('p_desc_axi', 600);
    movePacketAlong('p_desc_axi', '', 600);
    setTimeout(() => flash('axi', 400), 600);
    setTimeout(() => {
      pulseLine('p_axi_sysmem', 400);
      movePacketAlong('p_axi_sysmem', '', 400);
      setTimeout(() => flash('sysmem', 400), 400);
    }, 600);
  }
  else if (ev.type === 'DESC_RETURN_AXI') {
    pulseLine('p_sysmem_axi', 400);
    movePacketAlong('p_sysmem_axi', '', 400);
    setTimeout(() => flash('axi', 400), 400);
  }
  else if (ev.type === 'DESC_NOTIFY_DM') {
    pulseLine('p_desc_dm', 400);
    movePacketAlong('p_desc_dm', '', 400);
    setTimeout(() => flash('dataMover', 600), 400);
  }
  else if (ev.type === 'DM_READ_SYSMEM') {
    pulseLine('p_dm_axi', 400);
    movePacketAlong('p_dm_axi', '', 400);
    setTimeout(() => flash('axi', 400), 400);
    setTimeout(() => pulseLine('p_axi_sysmem', 400), 600);
    setTimeout(() => movePacketAlong('p_axi_sysmem', '', 400), 600);
    setTimeout(() => flash('sysmem', 500), 1000);
  }
  else if (ev.type === 'DM_WRITE_SRAM') {
    pulseLine('p_sysmem_axi', 400);
    movePacketAlong('p_sysmem_axi', '', 400);
    setTimeout(() => pulseLine('p_dm_sram_ctrl', 400), 400);
    setTimeout(() => movePacketAlong('p_dm_sram_ctrl', '', 400), 400);
    setTimeout(() => flash('sram_ctrl', 400), 800);
    setTimeout(() => {
      pulseLine('p_sramctrl_sram', 400);
      movePacketAlong('p_sramctrl_sram', '', 400, true);
      flash('sram', 600);
    }, 1200);
  }
}

// Built-in DMA Demo workflow matching the hackathon request
timeline = [
  { type: 'SOC_WRITE_CSR', payload: 'Configuring Ring Base' },
  { type: 'CSR_NOTIFY_RING', payload: 'Doorbell Set' },
  { type: 'RING_NOTIFY_DESC', payload: 'Req next index' },
  { type: 'DESC_FETCH_AXI', payload: 'Fetch Descriptor' },
  { type: 'DESC_RETURN_AXI', payload: 'Descriptor Acquired' },
  { type: 'DESC_NOTIFY_DM', payload: 'Dispatch Job to Mover' },
  { type: 'DM_READ_SYSMEM', payload: 'Mover: Stream from Mem' },
  { type: 'DM_WRITE_SRAM', payload: 'Mover: Push to SRAM' }
];

function stepTimeline() {
  if (tIndex >= timeline.length) { 
    pause(); 
    tIndex = 0; // loop back
    return; 
  }
  const ev = timeline[tIndex++];
  handleEvent(ev);
}

function play() {
  if (playing) return;
  playing = true;
  timer = setInterval(stepTimeline, 2000 / speed);
  stepTimeline(); // do first immediately
}

function pause() { playing=false; clearInterval(timer); }

playBtn.onclick = play;
pauseBtn.onclick = pause;
speedInput.oninput = (e)=> { speed = parseFloat(e.target.value); if (playing) { pause(); play(); } };

log('GUI Ready. Press Play Demo!');
