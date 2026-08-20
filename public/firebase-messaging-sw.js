// ============================================================
// CLICK EN NOTIFICACIÓN
// Debe declararse antes de cargar Firebase Messaging.
// ============================================================

function resolveNotificationPath(data) {
  const payload = data || {}

  if (payload.path) {
    return payload.path
  }

  if (payload.alert_id) {
    return `/alertas/${payload.alert_id}`
  }

  if (payload.link) {
    try {
      return new URL(
        payload.link,
        self.location.origin
      ).pathname
    } catch (_error) {
      // ignore invalid absolute links
    }
  }

  return "/alertas"
}

self.addEventListener(
  "notificationclick",
  (event) => {
    event.notification.close()

    const data =
      event.notification.data || {}

    const path =
      resolveNotificationPath(data)

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
