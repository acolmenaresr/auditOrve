module Notifications
  class AuditAlertPushService
    TARGET_USER_TYPES = [ 6, 7, 10 ].freeze

    def initialize(
      total:,
      critical: 0,
      high: 0,
      medium: 0,
      low: 0,
      path: "/dashboard"
    )
      @total = total.to_i
      @critical = critical.to_i
      @high = high.to_i
      @medium = medium.to_i
      @low = low.to_i
      @path = path.presence || "/dashboard"
    end

    def call
      return empty_result if @total <= 0

      devices = eligible_devices

      sent = []
      failed = []

      devices.find_each do |device|
        begin
          result = firebase_service.send_to_token(
            token: device.token,
            title: notification_title,
            body: notification_body,
            data: notification_data
          )

          sent << {
            device_id: device.id,
            user_id: device.user_id,
            message_name: result["name"]
          }
        rescue StandardError => e
          Rails.logger.error(
            "[FCM] Error enviando a PushDevice #{device.id}: " \
            "#{e.class}: #{e.message}"
          )

          failed << {
            device_id: device.id,
            user_id: device.user_id,
            error: e.message
          }
        end
      end

      {
        ok: failed.empty?,
        eligible_devices: devices.count,
        sent: sent.length,
        failed: failed.length,
        sent_devices: sent,
        failed_devices: failed
      }
    end

    private

    # =========================================================
    # DESTINATARIOS
    # =========================================================

    def eligible_devices
      PushDevice
        .active
        .joins(:audit_user)
        .merge(
          AuditUser.where(
            active: true,
            "tipoUsuario" => TARGET_USER_TYPES
          )
        )
        .distinct
    end

    # =========================================================
    # FIREBASE
    # =========================================================

    def firebase_service
      @firebase_service ||=
        Notifications::FirebasePushService.new
    end

    # =========================================================
    # TÍTULO
    # =========================================================

    def notification_title
      if @total == 1
        "1 alerta requiere revisión"
      else
        "#{@total} alertas requieren revisión"
      end
    end

    # =========================================================
    # CUERPO
    # =========================================================

    def notification_body
      parts = []

      parts << severity_text(
        @critical,
        "crítica",
        "críticas"
      )

      parts << severity_text(
        @high,
        "alta",
        "altas"
      )

      parts << severity_text(
        @medium,
        "media",
        "medias"
      )

      parts << severity_text(
        @low,
        "baja",
        "bajas"
      )

      parts.compact!

      return "Revisa AuditORVE para más información." if parts.empty?

      parts.join(" · ")
    end

    def severity_text(
      quantity,
      singular,
      plural
    )
      return nil if quantity <= 0

      label =
        quantity == 1 ? singular : plural

      "#{quantity} #{label}"
    end

    # =========================================================
    # DATA FCM
    # =========================================================

    def notification_data
      {
        type: "audit_alert_summary",
        total: @total,
        critical: @critical,
        high: @high,
        medium: @medium,
        low: @low,
        path: @path
      }
    end

    # =========================================================
    # SIN ALERTAS
    # =========================================================

    def empty_result
      {
        ok: true,
        eligible_devices: 0,
        sent: 0,
        failed: 0,
        sent_devices: [],
        failed_devices: []
      }
    end
  end
end
