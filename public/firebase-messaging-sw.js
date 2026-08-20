// ============================================================
// CLICK EN NOTIFICACIÓN
// Debe declararse antes de cargar Firebase Messaging.
// ============================================================

self.addEventListener(
  "notificationclick",
  (event) => {
    event.notification.close()

    const data =
      event.notification.data || {}

    const path =
      data.path || "/alertas"

    const destination =
      new URL(
        path,
        self.location.origin
      ).href

    event.waitUntil(
      clients
        .matchAll({
          type: "window",
          includeUncontrolled: true
        })
        .then((windowClients) => {
          for (const client of windowClients) {
            if (
              client.url.startsWith(
                self.location.origin
              )
            ) {
              if ("navigate" in client) {
                client.navigate(destination)
              }

              return client.focus()
            }
          }

          return clients.openWindow(
            destination
          )
        })
    )
  }
)


// ============================================================
// FIREBASE
// ============================================================

importScripts(
  "https://www.gstatic.com/firebasejs/12.16.0/firebase-app-compat.js"
)

importScripts(
  "https://www.gstatic.com/firebasejs/12.16.0/firebase-messaging-compat.js"
)

firebase.initializeApp({
  apiKey: "AIzaSyABKFbXYo_2KFLW1F2jGD-CwCpA2kOWG88",
  authDomain:
    "auditorve-notifications.firebaseapp.com",
  projectId:
    "auditorve-notifications",
  storageBucket:
    "auditorve-notifications.firebasestorage.app",
  messagingSenderId:
    "963513125883",
  appId:
    "1:963513125883:web:6c8c5744c26d4a06cfd95e"
})

firebase.messaging()