importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js");

const firebaseConfig = {
    apiKey: "AIzaSyChzwhwUyXtnwpv6PovD0HrSTjfqRbEqTI",
    authDomain: "hostelmanagement-76261.firebaseapp.com",
    projectId: "hostelmanagement-76261",
    storageBucket: "hostelmanagement-76261.firebasestorage.app",
    messagingSenderId: "560412204249",
    appId: "1:560412204249:web:e10b96b4ba8dfa638a72c8"
};

try {
    firebase.initializeApp(firebaseConfig);
    const messaging = firebase.messaging();

    // Optional: add a background message handler
    messaging.onBackgroundMessage(function(payload) {
        console.log('[firebase-messaging-sw.js] Received background message ', payload);
        const notificationTitle = payload.notification.title;
        const notificationOptions = {
            body: payload.notification.body,
        };

        self.registration.showNotification(notificationTitle, notificationOptions);
    });
} catch (e) {
    console.log("Error initializing Firebase messaging service worker", e);
}
