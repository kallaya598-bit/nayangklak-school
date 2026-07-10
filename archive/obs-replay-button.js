const fs = require('fs');
const path = require('path');

const OBS_URL = 'ws://127.0.0.1:4455';
const REPLAY_DIR = 'G:\\OBS-Replay';
const LIVE_SCENE = 'Scene';
const REPLAY_SCENE = 'Replay 7s Slow';
const TRANSITION_SCENE = 'Replay Transition';
const RETURN_TRANSITION_SCENE = 'Live Transition';
const REPLAY_INPUT = 'Replay 7s Slow Media';
const REPLAY_SECONDS = 7;
const SPEED_PERCENT = 60;
const RETURN_EXTRA_MS = 0;
const TRANSITION_MS = 1200;
const FADE_MS = 220;

let ws;
let nextId = 1;
const pending = new Map();

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function request(requestType, requestData = {}) {
  const requestId = String(nextId++);
  ws.send(JSON.stringify({ op: 6, d: { requestType, requestId, requestData } }));
  return new Promise((resolve, reject) => {
    pending.set(requestId, { resolve, reject, requestType });
  });
}

function getLatestReplay(sinceMs) {
  if (!fs.existsSync(REPLAY_DIR)) return null;
  return fs.readdirSync(REPLAY_DIR)
    .filter((name) => /\.(mp4|mkv|mov)$/i.test(name))
    .map((name) => {
      const full = path.join(REPLAY_DIR, name);
      const stat = fs.statSync(full);
      return { full, mtimeMs: stat.mtimeMs, size: stat.size };
    })
    .filter((file) => file.mtimeMs >= sinceMs - 1000 && file.size > 0)
    .sort((a, b) => b.mtimeMs - a.mtimeMs)[0] || null;
}

async function waitForReplay(sinceMs) {
  for (let i = 0; i < 60; i++) {
    const file = getLatestReplay(sinceMs);
    if (file) {
      await sleep(500);
      return file.full.replace(/\\/g, '/');
    }
    await sleep(250);
  }
  throw new Error('ไม่พบไฟล์รีเพลใหม่ใน G:\\OBS-Replay');
}

function connect() {
  return new Promise((resolve, reject) => {
    ws = new WebSocket(OBS_URL);
    ws.onerror = () => reject(new Error('เชื่อมต่อ OBS WebSocket ไม่ได้'));
    ws.onmessage = (event) => {
      const message = JSON.parse(event.data);

      if (message.op === 0) {
        ws.send(JSON.stringify({ op: 1, d: { rpcVersion: 1, eventSubscriptions: 0 } }));
      }

      if (message.op === 2) {
        resolve();
      }

      if (message.op === 7) {
        const item = pending.get(message.d.requestId);
        if (!item) return;
        pending.delete(message.d.requestId);
        if (message.d.requestStatus.result) {
          item.resolve(message.d.responseData || {});
        } else {
          item.reject(new Error(`${item.requestType}: ${message.d.requestStatus.comment || 'OBS request failed'}`));
        }
      }
    };
  });
}

async function main() {
  await connect();

  const status = await request('GetReplayBufferStatus');
  if (!status.outputActive) {
    await request('StartReplayBuffer');
    await sleep(1000);
  }

  const sinceMs = Date.now();
  await request('SaveReplayBuffer');
  const replayFile = await waitForReplay(sinceMs);

  await request('SetInputSettings', {
    inputName: REPLAY_INPUT,
    inputSettings: {
      is_local_file: true,
      local_file: replayFile,
      looping: false,
      restart_on_activate: true,
      close_when_inactive: true,
      clear_on_media_end: true,
      speed_percent: SPEED_PERCENT
    },
    overlay: true
  });

  await request('SetCurrentSceneTransition', { transitionName: 'Fade' }).catch(() => {});
  await request('SetCurrentSceneTransitionDuration', { transitionDuration: FADE_MS }).catch(() => {});
  await request('SetCurrentProgramScene', { sceneName: TRANSITION_SCENE });
  await sleep(TRANSITION_MS);
  await request('SetCurrentSceneTransition', { transitionName: 'Fade' }).catch(() => {});
  await request('SetCurrentSceneTransitionDuration', { transitionDuration: FADE_MS }).catch(() => {});
  await request('SetCurrentProgramScene', { sceneName: REPLAY_SCENE });

  const playbackMs = Math.ceil((REPLAY_SECONDS * 1000 * 100) / SPEED_PERCENT) + RETURN_EXTRA_MS;
  await sleep(playbackMs);
  await request('SetCurrentSceneTransition', { transitionName: 'Fade' }).catch(() => {});
  await request('SetCurrentSceneTransitionDuration', { transitionDuration: FADE_MS }).catch(() => {});
  await request('SetCurrentProgramScene', { sceneName: RETURN_TRANSITION_SCENE });
  await sleep(TRANSITION_MS);
  await request('SetCurrentSceneTransition', { transitionName: 'Fade' }).catch(() => {});
  await request('SetCurrentSceneTransitionDuration', { transitionDuration: FADE_MS }).catch(() => {});
  await request('SetCurrentProgramScene', { sceneName: LIVE_SCENE });
  ws.close();

  console.log(`เล่นรีเพลแล้ว: ${replayFile}`);
}

main().catch((error) => {
  console.error(error.message);
  if (ws) ws.close();
  process.exit(1);
});
