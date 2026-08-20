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
  static targets = [ "status", "button" ]

  static values = {
    enforce: { type: Boolean, default: false }
  }

  async connect() {
    if (!this.enforceValue) {
      return
    }

    await this.verifyExistingDevice()
  }

  async register() {
    try {
      this.setStatus("Activando alertas en este dispositivo...")
      this.setButtonBusy(true)

      const token = await this.obtainToken({
        requestPermission: true
      })

      const result = await this.registerTokenInRails(token)

      console.log(
        "[FCM] Dispositivo registrado en Rails:",
        result.device
      )

      if (this.enforceValue) {
        this.setStatus("Dispositivo registrado. Continuando...")
        await this.completeSetup()
        return
      }

      alert("Notificaciones activadas correctamente")
    } catch (error) {
      console.error("[FCM] Error:", error)

      this.setStatus(error.message)
      this.setButtonBusy(false)

      if (!this.enforceValue) {
        alert(
          `Error activando notificaciones: ${error.message}`
        )
      }
    }
  }

  async verifyExistingDevice() {
    try {
      if (!(await isSupported()) || !("Notification" in window)) {
        this.setStatus(
          "Este navegador no soporta alertas push. Usa Chrome o Edge."
        )
        return
      }

      if (Notification.permission !== "granted") {
        return
      }

      this.setStatus("Verificando este dispositivo...")

      const token = await this.obtainToken({
        requestPermission: false
      })

      const status = await this.checkTokenInRails(token)

      if (status.registered) {
        this.setStatus("Este dispositivo ya está registrado. Continuando...")
        await this.completeSetup()
      }
    } catch (error) {
      console.error("[FCM] Verificación:", error)
    }
  }

  // ==========================================================
  // REGISTRAR TOKEN FCM EN RAILS
  // ==========================================================

  async obtainToken({ requestPermission }) {
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

    let permission = Notification.permission

    if (permission !== "granted" && requestPermission) {
      permission = await Notification.requestPermission()
    }

    if (permission !== "granted") {
      throw new Error(
        "Permiso de notificaciones no concedido"
      )
    }

    const registration =
      await navigator.serviceWorker.register(
        "/firebase-messaging-sw.js"
      )

    await navigator.serviceWorker.ready

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

    const messaging = getMessaging(app)

    this.configureForegroundMessages(
      messaging,
      registration
    )

    const vapidKey =
      document
        .querySelector('meta[name="firebase-vapid-key"]')
        ?.getAttribute("content")
        ?.trim()

    if (!vapidKey) {
      throw new Error(
        "No se encontró FIREBASE_VAPID_PUBLIC_KEY"
      )
    }

    const token = await getToken(messaging, {
      vapidKey: vapidKey,
      serviceWorkerRegistration: registration
    })

    if (!token) {
      throw new Error(
        "Firebase no devolvió un registration token"
      )
    }

    return token
  }

  async checkTokenInRails(token) {
    return this.railsFetch(
      "/push_devices/status",
      { token: token }
    )
  }

  async completeSetup() {
    const data = await this.railsFetch(
      "/alertas-push",
      {}
    )

    window.location.assign(
      data.redirect || "/"
    )
  }

  setStatus(message) {
    if (!this.hasStatusTarget) {
      return
    }

    this.statusTarget.textContent = message
  }

  setButtonBusy(busy) {
    if (!this.hasButtonTarget) {
      return
    }

    this.buttonTarget.disabled = busy
  }

  csrfToken() {
    const token =
      document
        .querySelector('meta[name="csrf-token"]')
        ?.getAttribute("content")

    if (!token) {
      throw new Error("No se encontró CSRF token")
    }

    return token
  }

  async railsFetch(path, body) {
    const response = await fetch(path, {
      method: "POST",
      credentials: "same-origin",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": this.csrfToken()
      },
      body: JSON.stringify(body)
    })

    let data = {}

    try {
      data = await response.json()
    } catch (_error) {
      throw new Error(
        `Respuesta inválida de Rails (${response.status})`
      )
    }

    if (!response.ok) {
      throw new Error(
        data.error ||
        `No fue posible completar la operación (${response.status})`
      )
    }

    return data
  }

  async registerTokenInRails(token) {
    return this.railsFetch(
      "/push_devices",
      {
        token: token,
        platform: "web"
      }
    )
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
                data.tag ||
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