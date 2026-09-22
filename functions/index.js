const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

// 1. Notificar al Proveedor cuando llega una NUEVA SOLICITUD
exports.notifyNewRequest = functions.firestore
    .document('matches/{matchId}')
    .onCreate(async (snap, context) => {
        const matchData = snap.data();
        const providerId = matchData.providerId;
        const clientName = matchData.clientName || 'Un cliente';

        // Buscar el fcmToken del proveedor
        const providerDoc = await admin.firestore().collection('users').doc(providerId).get();
        const fcmToken = providerDoc.data().fcmToken;

        if (!fcmToken) return null;

        return admin.messaging().send({
            token: fcmToken,
            notification: {
                title: '¡Nueva solicitud de servicio!',
                body: `${clientName} ha solicitado tu servicio. Abre la app para revisar.`,
            }
        });
    });

// 2. Notificar al Cliente cuando se ACEPTA o RECHAZA la solicitud
exports.notifyMatchStatus = functions.firestore
    .document('matches/{matchId}')
    .onUpdate(async (change, context) => {
        const before = change.before.data();
        const after = change.after.data();

        // Si el estado no cambió, no hacemos nada
        if (before.status === after.status) return null;

        // Buscar el fcmToken del cliente
        const clientId = after.clientId;
        const clientDoc = await admin.firestore().collection('users').doc(clientId).get();
        const fcmToken = clientDoc.data().fcmToken;

        if (!fcmToken) return null;

        let title = '';
        let body = '';

        if (after.status === 'accepted') {
            title = '¡Solicitud Aceptada!';
            body = 'El proveedor ha aceptado tu servicio. ¡Ve al chat para acordar los detalles!';
        } else if (after.status === 'rejected') {
            title = 'Solicitud Rechazada';
            body = 'Lo sentimos, el proveedor no puede atenderte en este momento.';
        } else {
            return null;
        }

        return admin.messaging().send({
            token: fcmToken,
            notification: { title, body }
        });
    });

// 3. Notificar cuando llega un NUEVO MENSAJE de Chat
// (Asume que guardas los mensajes dentro de la subcolección 'messages' del match)
exports.notifyNewChatMessage = functions.firestore
    .document('matches/{matchId}/messages/{messageId}')
    .onCreate(async (snap, context) => {
        const messageData = snap.data();
        const senderId = messageData.senderId;
        const text = messageData.text;
        const matchId = context.params.matchId;

        // Obtener la información del Match para saber quién es la otra persona
        const matchDoc = await admin.firestore().collection('matches').doc(matchId).get();
        const matchData = matchDoc.data();

        // Determinar quién debe recibir el mensaje
        const receiverId = matchData.clientId === senderId ? matchData.providerId : matchData.clientId;

        // Obtener el fcmToken del receptor
        const receiverDoc = await admin.firestore().collection('users').doc(receiverId).get();
        const fcmToken = receiverDoc.data().fcmToken;

        if (!fcmToken) return null;

        return admin.messaging().send({
            token: fcmToken,
            notification: {
                title: 'Nuevo mensaje',
                body: text.length > 30 ? text.substring(0, 30) + '...' : text, // Trunca el mensaje si es muy largo
            }
        });
    });