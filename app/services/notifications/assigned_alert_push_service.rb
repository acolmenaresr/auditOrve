module Notifications
  class AssignedAlertPushService
    MOTIVE_LIMIT = 150

    def initialize(notification:, assignee:)
      @notification = notification
      @assignee = assignee
    end

    def call
      devices = eligible_devices

      sent = []
      failed = []

      devices.find_each do |device|
        begin
          result = firebase_service.send_to_token(
            token: device.token,
            title: notification_title,
            body: notification_body,
            data: notification_data,
            tag: notification_tag
          )

          sent << {
            device_id: device.id,
            user_id: device.user_id,
            message_name: result["name"]
          }
        rescue StandardError => e
          Rails.logger.error(
            "[FCM] Error enviando asignación a PushDevice #{device.id}: " \
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

    def eligible_devices
      return PushDevice.none if @assignee.blank?

      PushDevice
        .active
        .where(user_id: @assignee.id)
    end

    def firebase_service
      @firebase_service ||=
        Notifications::FirebasePushService.new
    end

    def notification_title
      if severity == "critica"
        "Alerta crítica asignada"
      else
        "Se te asignó una alerta"
      end
    end

    def notification_body
      parts = [
        alert_label,
        alert_motive
      ].compact

      return "Ábrela en AuditORVE para atenderla." if parts.empty?

      parts.join(" · ")
    end

    def notification_data
      {
        type: "audit_alert_assigned",
        alert_id: @notification.id,
        severity: severity,
        path: alert_path,
        tag: notification_tag
      }.tap do |payload|
        payload[:link] = alert_link if alert_link.present?
      end
    end

    def notification_tag
      "auditorve-alert-assigned-#{@notification.id}"
    end

    def alert_path
      "/alertas/#{@notification.id}"
    end

    def alert_link
      origin = ENV["AUDITORVE_PUBLIC_URL"].to_s.strip.presence
      return if origin.blank?

      "#{origin.chomp('/')}#{alert_path}"
    end

    def severity
      @notification["severidad"].to_s
    end

    def alert_label
      humanize_label(
        @notification["categoriaAlerta"].presence ||
          @notification["tipoAlerta"]
      )
    end

    def alert_motive
      motive = @notification["motivo"].to_s.squish
      return if motive.blank?

      motive.truncate(MOTIVE_LIMIT)
    end

    def humanize_label(value)
      text = value.to_s.tr("_-", " ").squish
      return if text.blank?

      text.downcase.sub(/\S/, &:upcase)
    end
  end
end
