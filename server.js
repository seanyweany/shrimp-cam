const express = require('express');
const app = express();
const http = require('http').Server(app);
const io = require('socket.io')(http);

app.use(express.static('.'));

io.on('connection', (socket) => {
  console.log('a user connected');

  socket.on('disconnect', () => {
    console.log('user disconnected');
  });

  socket.on('signal', (data) => {
    socket.broadcast.emit('signal', data);
  });
});

http.listen(3000, () => {
  console.log('listening on *:3000');
});
