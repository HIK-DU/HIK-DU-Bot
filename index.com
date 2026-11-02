<!DOCTYPE html>
<html lang="ru">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>HIT-DU Bot</title>
<script src="https://js.puter.com/v2/"></script>
<style>
:root{--bg:#f6f7fb;--card:#fff;--text:#14161f;--muted:#6b7080;--accent:#5b5bf0;--on-accent:#fff;--border:#e3e5ee;--code:#eef0f7;
box-sizing:border-box;padding-top:env(safe-area-inset-top,0px);padding-bottom:env(safe-area-inset-bottom,0px)}
@media (prefers-color-scheme:dark){:root:not([data-theme="light"]){--bg:#0f1117;--card:#1a1d27;--text:#eceef5;--muted:#9096a8;--accent:#7b7bff;--on-accent:#fff;--border:#2a2e3b;--code:#11131a}}
:root[data-theme="dark"]{--bg:#0f1117;--card:#1a1d27;--text:#eceef5;--muted:#9096a8;--accent:#7b7bff;--on-accent:#fff;--border:#2a2e3b;--code:#11131a}
html{scroll-padding-top:env(safe-area-inset-top,0px)}
html,body{height:100%;margin:0}
body{background:var(--bg);color:var(--text);font:16px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;display:flex;flex-direction:column}
header{padding:12px 16px;border-bottom:1px solid var(--border);display:flex;align-items:center;gap:10px;background:var(--card)}
header .logo{width:34px;height:34px;border-radius:10px;background:var(--accent);color:var(--on-accent);display:grid;place-items:center;font-size:18px}
header b{font-size:17px}header small{display:block;color:var(--muted);font-size:12px;line-height:1.2}
#chat{flex:1;overflow-y:auto;padding:16px;display:flex;flex-direction:column;gap:12px}
.hero{margin:auto;text-align:center;max-width:420px}
.hero .big{font-size:44px}.hero h1{margin:6px 0;font-size:22px}.hero p{margin:0 0 16px;color:var(--muted)}
.chips{display:flex;flex-direction:column;gap:8px}
.chip{background:var(--card);color:var(--text);border:1px solid var(--border);border-radius:14px;padding:11px 14px;font:inherit;text-align:left;cursor:pointer}
.msg{max-width:88%;padding:10px 14px;border-radius:18px;word-wrap:break-word;overflow-wrap:anywhere}
.msg.user{align-self:flex-end;background:var(--accent);color:var(--on-accent);border-bottom-right-radius:6px}
.msg.bot{align-self:flex-start;background:var(--card);border:1px solid var(--border);border-bottom-left-radius:6px}
.msg .t{white-space:pre-wrap}.msg .t+.t,.msg .t+pre,.msg pre+.t{margin-top:8px}
.msg img{display:block;width:100%;max-width:360px;height:auto;border-radius:12px;margin:8px 0;background:#fff}
.msg pre{margin:8px 0;background:var(--code);border-radius:10px;padding:10px 12px;overflow-x:auto;font:13px/1.45 ui-monospace,Menlo,Consolas,monospace}
.status{color:var(--muted);font-style:italic}
form{display:flex;gap:8px;align-items:flex-end;padding:10px 12px;border-top:1px solid var(--border);background:var(--card)}
textarea{flex:1;resize:none;max-height:140px;border:1px solid var(--border);background:var(--bg);color:var(--text);border-radius:18px;padding:10px 14px;font:inherit;outline:none}
button.send{width:44px;height:44px;border:0;border-radius:50%;background:var(--accent);color:var(--on-accent);font-size:20px;cursor:pointer;flex:none}
button.send:disabled{opacity:.5}
</style>
</head>
<body>
<header><div class="logo">🤖</div><div><b>HIT-DU Bot</b><small>отвечает, пишет, рисует</small></div></header>
<div id="chat">
  <div class="hero" id="hero">
    <div class="big">🤖</div>
    <h1>Привет! Я HIT-DU Bot</h1>
    <p>Отвечаю на вопросы, пишу тексты и код, рисую картинки.</p>
    <div class="chips">
      <button class="chip">🎨 Нарисуй кота-космонавта</button>
      <button class="chip">📖 Придумай короткую сказку на ночь</button>
      <button class="chip">💡 Объясни простыми словами, как работает интернет</button>
    </div>
  </div>
</div>
<form id="f"><textarea id="in" rows="1" placeholder="Напиши, что нужно…"></textarea><button class="send" id="btn" type="submit" aria-label="Отправить">➤</button></form>

<script>
// Бесплатно: ИИ от OpenAI (текст и картинки) работает через Puter.js, API-ключ не нужен.
// Если модель не отвечает, замени названия ниже (список моделей: docs.puter.com).
const MODEL = "openai/gpt-5.5";
const FALLBACK = "gpt-5.4-nano";

const SYSTEM = "Ты — HIT-DU Bot, очень умный и дружелюбный помощник. Отвечай на языке пользователя, понятно и по делу. " +
  "Ты умеешь отвечать на вопросы, писать тексты, стихи, сказки и код, переводить, объяснять и считать. " +
  "Ты умеешь рисовать, никогда не говори, что не умеешь. Если просят нарисовать, ответь одной короткой фразой и добавь рисунок. " +
  "Способ 1 (по умолчанию): полный SVG-код в блоке ```svg ... ``` (viewBox=\"0 0 400 400\", яркие цвета, фон, много деталей, " +
  "без скриптов и внешних ссылок). Способ 2: если просят реалистичное фото или очень красивую детальную картинку, " +
  "напиши блок ```image с подробным описанием сцены на английском``` вместо SVG. Не используй markdown-заголовки.";

const chat = document.getElementById('chat'), input = document.getElementById('in'), btn = document.getElementById('btn');
let history = [], busy = false;

function scrollDown(){ chat.scrollTop = chat.scrollHeight; }

function addText(el, s){
  if(!s.trim()) return;
  const d = document.createElement('div'); d.className = 't';
  s.trim().split(/(\*\*[^*]+\*\*)/).forEach(p => {
    if(/^\*\*[^*]+\*\*$/.test(p)){ const b = document.createElement('strong'); b.textContent = p.slice(2,-2); d.appendChild(b); }
    else d.appendChild(document.createTextNode(p));
  });
  el.appendChild(d);
}
function addStatus(el, s){ const d = document.createElement('div'); d.className = 'status'; d.textContent = s; el.appendChild(d); return d; }

async function drawPhoto(slot, prompt){
  try{
    const img = await puter.ai.txt2img(prompt, {model: "gpt-image-1.5"});
    slot.replaceWith(img); scrollDown();
  }catch(e){ slot.textContent = 'Не удалось нарисовать картинку, попробуй ещё раз.'; }
}

function addBlock(el, lang, code, final){
  if(/^image$/i.test(lang)){
    const slot = addStatus(el, '🎨 Рисую картинку…');
    if(final) drawPhoto(slot, code.trim());
  } else if(/^svg$/i.test(lang) || /^\s*<svg/i.test(code)){
    let svg = code.trim();
    if(!/xmlns=/.test(svg)) svg = svg.replace('<svg', '<svg xmlns="http://www.w3.org/2000/svg"');
    const img = document.createElement('img'); img.alt = 'Рисунок';
    img.src = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(svg);
    el.appendChild(img);
  } else {
    const pre = document.createElement('pre'), c = document.createElement('code');
    c.textContent = code.replace(/\n$/, ''); pre.appendChild(c); el.appendChild(pre);
  }
}

function render(el, text, final){
  el.textContent = '';
  const re = /```(\w*)\n?([\s\S]*?)```/g; let last = 0, m;
  while((m = re.exec(text))){ addText(el, text.slice(last, m.index)); addBlock(el, m[1], m[2], final); last = re.lastIndex; }
  const rest = text.slice(last), open = rest.indexOf('```');
  if(open >= 0){
    addText(el, rest.slice(0, open));
    const tail = rest.slice(open + 3);
    if(/^(svg|image)/i.test(tail)) addStatus(el, '🎨 Рисую…'); else addBlock(el, '', tail.replace(/^\w*\n?/, ''), false);
  } else addText(el, rest);
  if(!el.childNodes.length) addStatus(el, 'Думаю…');
  scrollDown();
}

function addMsg(kind, text){
  const d = document.createElement('div'); d.className = 'msg ' + kind;
  if(kind === 'user') d.textContent = text;
  chat.appendChild(d); scrollDown(); return d;
}

async function ask(msgs, onText, model){
  const resp = await puter.ai.chat(msgs, {model, stream: true});
  let text = '';
  if(resp && resp[Symbol.asyncIterator]){
    for await (const part of resp){ if(part && part.text){ text += part.text; onText(text); } }
  } else {
    text = (resp && resp.message && resp.message.content && (resp.message.content[0]?.text || resp.message.content)) || String(resp);
    onText(text);
  }
  return text;
}

const errText = e => (e && ((e.error && e.error.message) || e.message)) || (typeof e === 'string' ? e : '');

async function send(text){
  text = text.trim();
  if(!text || busy) return;
  busy = true; btn.disabled = true;
  const hero = document.getElementById('hero'); if(hero) hero.remove();
  addMsg('user', text);
  history.push({role: 'user', content: text});
  const bubble = addMsg('bot'); render(bubble, '', false);
  try{
    if(typeof puter === 'undefined') throw {message: 'Нет связи с Puter. Проверь интернет.'};
    let h = history.slice(-20); if(h[0].role !== 'user') h = h.slice(1);
    const msgs = h.map((m, i) => i === 0 ? {role: m.role, content: SYSTEM + '\n\n' + m.content} : m);
    const cb = t => render(bubble, t, false);
    let answer;
    try{ answer = await ask(msgs, cb, MODEL); }
    catch(e){ if(/model/i.test(errText(e))) answer = await ask(msgs, cb, FALLBACK); else throw e; }
    render(bubble, answer, true);
    history.push({role: 'assistant', content: answer.replace(/```(svg|image)[\s\S]*?```/g, '[рисунок]')});
  } catch(e){
    history.pop();
    const t = errText(e);
    bubble.textContent = '';
    addStatus(bubble, t ? 'Ошибка: ' + t : 'Что-то пошло не так. Если появлялось окно входа в Puter, войди в него и повтори.');
  }
  busy = false; btn.disabled = false; input.focus();
}

document.getElementById('f').addEventListener('submit', e => { e.preventDefault(); const t = input.value; input.value = ''; input.style.height = 'auto'; send(t); });
input.addEventListener('input', () => { input.style.height = 'auto'; input.style.height = Math.min(input.scrollHeight, 140) + 'px'; });
input.addEventListener('keydown', e => {
  if(e.key === 'Enter' && !e.shiftKey && matchMedia('(pointer:fine)').matches){ e.preventDefault(); document.getElementById('f').requestSubmit(); }
});
document.querySelectorAll('.chip').forEach(c => c.addEventListener('click', () => send(c.textContent.replace(/^\S+\s/, ''))));
</script>
</body>
</html>
