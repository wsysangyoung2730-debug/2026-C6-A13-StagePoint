import test from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { WebSocket } from 'ws';
import { startServer } from './server.mjs';

async function fixture(t) {
  const server = startServer({ port: 0 });
  await once(server, 'listening');
  const clients = [];
  t.after(async () => { clients.forEach(c => c.terminate()); await new Promise(resolve => server.close(resolve)); });
  return async () => {
    const socket = new WebSocket(`ws://127.0.0.1:${server.address().port}`);
    clients.push(socket);
    const queue = [], waiters = [];
    socket.on('message', raw => {
      const message = JSON.parse(raw);
      if (waiters.length) waiters.shift()(message); else queue.push(message);
    });
    await once(socket, 'open');
    socket.next = () => queue.length ? Promise.resolve(queue.shift()) : new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(Error('message timeout')), 2000);
      waiters.push(message => { clearTimeout(timer); resolve(message); });
    });
    socket.json = value => socket.send(JSON.stringify(value));
    socket.join = (role, token = 'test-password-1234') => socket.json({ type: 'join', role, token, room: 'test-room' });
    return socket;
  };
}
test('pairs opposite roles, relays signaling, reports peer loss and creates new epoch', async t => {
  const client = await fixture(t), camera = await client(), monitor = await client();
  camera.join('camera'); assert.equal((await camera.next()).type, 'joined');
  monitor.join('monitor'); assert.equal((await monitor.next()).type, 'joined');
  const ready = await camera.next(); assert.equal(ready.type, 'ready');
  assert.equal((await monitor.next()).epoch, ready.epoch);
  camera.json({ type: 'offer', epoch: ready.epoch, sdp: 'example' });
  assert.equal((await monitor.next()).sdp, 'example');
  monitor.close(); assert.equal((await camera.next()).type, 'peer-left');
  const replacement = await client(); replacement.join('monitor'); await replacement.next();
  assert.notEqual((await camera.next()).epoch, ready.epoch);
});
test('rejects wrong token and duplicate role without disturbing existing peer', async t => {
  const client = await fixture(t), camera = await client();
  camera.join('camera'); await camera.next();
  const wrong = await client(); wrong.join('monitor', 'wrong-password-123');
  assert.equal((await wrong.next()).type, 'error');
  const duplicate = await client(); duplicate.join('camera');
  assert.equal((await duplicate.next()).type, 'error');
});
test('rejects unauthenticated signaling and short tokens', async t => {
  const client = await fixture(t), a = await client(), b = await client();
  a.json({ type: 'offer', sdp: 'not allowed' });
  assert.equal((await a.next()).type, 'error');
  b.join('camera', 'short'); assert.equal((await b.next()).type, 'error');
});
