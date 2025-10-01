const socket = io();

const configuration = { iceServers: [{ urls: 'stun:stun.l.google.com:19302' }] };
const pc = new RTCPeerConnection(configuration);

pc.onicecandidate = (e) => {
  if (e.candidate) {
    socket.emit('signal', { candidate: e.candidate });
  }
};

pc.ontrack = (e) => {
  const remoteVideo = document.getElementById('remote-video');
  remoteVideo.srcObject = e.streams[0];
};

// navigator.mediaDevices.getUserMedia({ video: true, audio: true })
//   .then((stream) => {
//     const localVideo = document.getElementById('local-video');
//     localVideo.srcObject = stream;

//     stream.getTracks().forEach((track) => pc.addTrack(track, stream));

//     pc.createOffer()
//       .then((offer) => {
//         return pc.setLocalDescription(offer);
//       })
//       .then(() => {
//         socket.emit('signal', { sdp: pc.localDescription });
//       });

//     socket.on('signal', async (data) => {
//       if (data.sdp) {
//         await pc.setRemoteDescription(new RTCSessionDescription(data.sdp));
//         const answer = await pc.createAnswer();
//         await pc.setLocalDescription(answer);
//         socket.emit('signal', { sdp: pc.localDescription });
//       } else if (data.candidate) {
//         pc.addIceCandidate(new RTCIceCandidate(data.candidate));
//       }
//     });
//   })
//   .catch((error) => {
//     console.error(error);
//   });

navigator.mediaDevices.getUserMedia({ video: true, audio: false }) // Request only video (remove 'audio')
  .then((stream) => {
    const localVideo = document.getElementById('local-video');
    localVideo.srcObject = stream;

    stream.getTracks().forEach((track) => pc.addTrack(track, stream));

    // ...
  })
  .catch((error) => {
    console.error(error);
  });