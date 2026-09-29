import { WebSocketServer, WebSocket } from 'ws';
import { randomUUID, timingSafeEqual, createHash } from 'node:crypto';
import { pathToFileURL } from 'node:url';

// Development-only LAN signaling. Video/data do not pass through this server.
export function startServer({ host = '127.0.0.1', port = 8080 } = {}) {
  const rooms = new Map();
  const server = new WebSocketServer({ host, port, maxPayload: 64 * 1024 });
  const send = (socket, value) => {
    if (socket.readyState === WebSocket.OPEN) socket.send(JSON.stringify(value));
  };
  server.on('connection', socket => {
    let membership;
    let count = 0;
    let windowStart = Date.now();
    const timer = setTimeout(() => { if (!membership) socket.close(1008, 'Join required'); }, 10000);
    socket.on('message', bytes => {
      try {
        if (Date.now() - windowStart > 1000) { count = 0; windowStart = Date.now(); }
        if (++count > 100) throw Error('Too many messages');
        const message = JSON.parse(bytes.toString());
        if (message.type === 'join') {
          if (membership || !/^[A-Za-z0-9-]{4,32}$/.test(message.room ?? '') ||
              !['camera', 'monitor'].includes(message.role) ||
              typeof message.token !== 'string' || message.token.length < 12 || message.token.length > 128) {
            throw Error('Invalid room, role or token (12+ characters)');
          }
          const digest = createHash('sha256').update(message.token).digest();
          let room = rooms.get(message.room);
          if (!room) { room = { digest, peers: new Map(), epoch: randomUUID() }; rooms.set(message.room, room); }
          if (!timingSafeEqual(room.digest, digest) || room.peers.has(message.role)) throw Error('Room unavailable');
          room.peers.set(message.role, socket);
          membership = { name: message.room, role: message.role, room };
          clearTimeout(timer);
          send(socket, { type: 'joined' });
          if (room.peers.size === 2) {
            room.epoch = randomUUID();
            for (const peer of room.peers.values()) send(peer, { type: 'ready', epoch: room.epoch });
          }
          return;
        }
        if (!membership) throw Error('Join first');
        const { room, role } = membership;
        if (!['offer', 'answer', 'candidate'].includes(message.type) || message.epoch !== room.epoch) return;
        if (message.type === 'offer' && role !== 'camera') throw Error('Camera offers only');
        if (message.type === 'answer' && role !== 'monitor') throw Error('Monitor answers only');
        send(room.peers.get(role === 'camera' ? 'monitor' : 'camera') ?? { readyState: -1 }, message);
      } catch (error) {
        send(socket, { type: 'error', message: error.message });
        socket.close(1008, 'Rejected');
      }
    });
    socket.on('close', () => {
      clearTimeout(timer);
      if (!membership) return;
      const { name, role, room } = membership;
      room.peers.delete(role);
      for (const peer of room.peers.values()) send(peer, { type: 'peer-left' });
      if (!room.peers.size) rooms.delete(name);
    });
    socket.on('error', () => {});
  });
  return server;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const host = process.env.STAGEPOINT_HOST ?? '127.0.0.1';
  const port = Number(process.env.STAGEPOINT_PORT ?? 8080);
  startServer({ host, port }).on('listening', () => {
    console.log(`StagePoint signaling ${host}:${port}; trusted LAN development only.`);
    console.log('Use WSS behind a trusted TLS proxy outside a private test LAN.');
  });
}
