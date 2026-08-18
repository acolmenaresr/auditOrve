import { Controller } from "@hotwired/stimulus"

import {
  initializeApp,
  getApps,
  getApp
} from "firebase/app"

import {
  getMessaging,
  getToken,
  isSupported,
  onMessage
} from "firebase/messaging"

export default class extends Controller {
  async register() {
    try {
      console.log("[FCM] Iniciando registro")

      // ======================================================
      // 1. SOPORTE DEL NAVEGADOR
      // ======================================================

      if (!(await isSupported())) {
        throw new Error(
          "Firebase Messaging no está soportado por este navegador"
        )
      }

      if (!("Notification" in window)) {
        throw new Error(
          "Este navegador no soporta notificaciones"
        )
      }

      if (!("serviceWorker" in navigator)) {
        throw new Error(
          "Este navegador no soporta Service Workers"
        )
      }

      // ======================================================
      // 2. PERMISO DE NOTIFICACIONES
      // ======================================================

      let permission = Notification.permission

      if (permission !== "granted") {
        permission = await Notification.requestPermission()
      }

      console.log(
        "[FCM] Permiso:",
        permission
      )

      if (permission !== "granted") {
        throw new Error(
          "Permiso de notificaciones no concedido"
        )
      }

      // ======================================================
      // 3. SERVICE WORKER
      // ======================================================

      const registration =
        await navigator.serviceWorker.register(
          "/firebase-messaging-sw.js"
        )

      await navigator.serviceWorker.ready

      console.log(
        "[FCM] Service Worker activo:",
        registration.scope
      )

      // ======================================================
      // 4. FIREBASE WEB
      // ======================================================

      const firebaseConfig = {
        apiKey:
          "AIzaSyABKFbXYo_2KFLW1F2jGD-CwCpA2kOWG88",

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
      }

      const app =
        getApps().length > 0
          ? getApp()
          : initializeApp(firebaseConfig)

      const messaging =
        getMessaging(app)

      // ======================================================
      // 5. MENSAJES FCM EN PRIMER PLANO
      // ======================================================

      this.configureForegroundMessages(
        messaging,
        registration
      )

      // ======================================================
      // 6. VAPID PUBLIC KEY
      // ======================================================

      const vapidKey =
        document
          .querySelector(
            'meta[name="firebase-vapid-key"]'
          )
          ?.getAttribute("content")
          ?.trim()

      if (!vapidKey) {
        throw new Error(
          "No se encontró FIREBASE_VAPID_PUBLIC_KEY"
        )
      }

      // ======================================================
      // 7. TOKEN FCM DEL NAVEGADOR
      // ======================================================

      const token =
        await getToken(
          messaging,
          {
            vapidKey: vapidKey,

            serviceWorkerRegistration:
              registration
          }
        )

      if (!token) {
        throw new Error(
          "Firebase no devolvió un registration token"
        )
      }

      console.log(
        "[FCM] Token obtenido correctamente"
      )

      // ======================================================
      // 8. REGISTRAR DISPOSITIVO EN RAILS
      // ======================================================

      const result =
        await this.registerTokenInRails(token)

      console.log(
        "[FCM] Dispositivo registrado en Rails:",
        result.device
      )

      alert(
        "Notificaciones activadas correctamente"
      )
    } catch (error) {
      console.error(
        "[FCM] Error:",
        error
      )

      alert(
        `Error activando notificaciones: ${error.message}`
      )
    }
  }

  // ==========================================================
  // REGISTRAR TOKEN FCM EN RAILS
  // ==========================================================

  async registerTokenInRails(token) {
    const csrfToken =
      document
        .querySelector(
          'meta[name="csrf-token"]'
        )
        ?.getAttribute("content")

    if (!csrfToken) {
      throw new Error(
        "No se encontró CSRF token"
      )
    }

    const response =
      await fetch(
        "/push_devices",
        {
          method: "POST",

          credentials: "same-origin",

          headers: {
            "Content-Type":
              "application/json",

            "Accept":
              "application/json",

            "X-CSRF-Token":
              csrfToken
          },

          body: JSON.stringify({
            token: token,
            platform: "web"
          })
        }
      )

    let data = {}

    try {
      data =
        await response.json()
    } catch (_error) {
      throw new Error(
        `Respuesta inválida de Rails (${response.status})`
      )
    }

    if (!response.ok) {
      throw new Error(
        data.error ||
        `No fue posible registrar el dispositivo (${response.status})`
      )
    }

    return data
  }

  // ==========================================================
  // MENSAJES FCM CUANDO AUDITORVE ESTÁ ABIERTO
  // ==========================================================

  configureForegroundMessages(
    messaging,
    registration
  ) {
    // Evita registrar múltiples listeners si el usuario
    // pulsa varias veces "Activar notificaciones".
    if (
      window.auditOrveFcmForegroundConfigured
    ) {
      return
    }

    window.auditOrveFcmForegroundConfigured =
      true

    onMessage(
      messaging,
      async (payload) => {
        console.log(
          "[FCM] Mensaje recibido en primer plano:",
          payload
        )

        try {
          // ==================================================
          // TÍTULO
          // ==================================================

          const title =
            payload.notification?.title ||
            "AuditORVE"

          // ==================================================
          // CUERPO
          // ==================================================

          const body =
            payload.notification?.body ||
            "Tienes una nueva notificación."

          // ==================================================
          // DATA ADICIONAL
          // ==================================================

          const data =
            payload.data || {}

          // ==================================================
          // MOSTRAR NOTIFICACIÓN NATIVA
          // ==================================================

          await registration.showNotification(
            title,
            {
              body: body,

              icon:
                "/auditorve-favicon-v3.png",

              badge:
                "/auditorve-favicon-v3.png",

              // Todas las notificaciones resumen utilizan
              // el mismo tag.
              tag:
                "auditorve-alert-summary",

              // Si ya existe una notificación con el mismo tag,
              // vuelve a avisar al usuario.
              renotify:
                true,

              // Solicita mantener visible la notificación
              // hasta interacción del usuario cuando el
              // navegador/SO lo permita.
              requireInteraction:
                true,

              // Incluye path, severidades, total, etc.
              // El Service Worker usa data.path al hacer clic.
              data:
                data
            }
          )

          console.log(
            "[FCM] Notificación mostrada"
          )
        } catch (error) {
          console.error(
            "[FCM] Error mostrando notificación:",
            error
          )
        }
      }
    )
  }
}