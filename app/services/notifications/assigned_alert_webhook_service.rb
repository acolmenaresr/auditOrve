require "net/http"
require "json"

module Notifications
  class AssignedAlertWebhookService
    DEFAULT_URL =
      "https://auditproject-0626-audit-flows.wxwmvi.easypanel.host/webhook/asignatedAlert"

    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 15

    def initialize(notification:, assignee:, actor:)
      @notification = notification
      @assignee = assignee
      @actor = actor
    end

    def call
      response = http_client.request(request)

      unless response.is_a?(Net::HTTPSuccess)
        Rails.logger.error(
          "[AssignedAlertWebhook] HTTP #{response.code}: #{response.body}"
        )

        return { ok: false, status: response.code.to_i }
      end

      { ok: true, status: response.code.to_i }
    rescue StandardError => error
      Rails.logger.error(
        "[AssignedAlertWebhook] #{error.class}: #{error.message}"
      )

      { ok: false, error: error.message }
    end

    private

    def endpoint
      ENV.fetch(
        "AUDITORVE_ASSIGNED_ALERT_WEBHOOK_URL",
        DEFAULT_URL
      )
    end

    def uri
      @uri ||= URI(endpoint)
    end

    def http_client
      client = Net::HTTP.new(uri.host, uri.port)

      client.use_ssl = uri.scheme == "https"
      client.open_timeout = OPEN_TIMEOUT
      client.read_timeout = READ_TIMEOUT

      client
    end

    def request
      Net::HTTP::Post.new(uri).tap do |http_request|
        http_request["Content-Type"] = "application/json"
        http_request["Accept"] = "application/json"
        http_request.body = payload.to_json
      end
    end

    def payload
      {
        id: @notification.id,
        clave: @notification["clave"],
        tipoAlerta: @notification["tipoAlerta"],
        motivo: @notification["motivo"],
        severidad: @notification["severidad"],
        estado: @notification["estado"],
        categoriaAlerta: @notification["categoriaAlerta"],
        usuario: @notification["usuario"],
        accion: @notification["accion"],
        operacion365: @notification["operacion365"],
        archivo: @notification["archivo"],
        ip: @notification["ip"],
        fecha: occurred_at_iso,
        asignadoA: @assignee&.usuario.to_s,
        asignadoANombre: person_name(@assignee),
        asignadoPor: @actor&.usuario.to_s,
        asignadoPorNombre: person_name(@actor),
        rutaAlerta: alert_path,
        urlAlerta: alert_url
      }
    end

    def occurred_at_iso
      value =
        if @notification.respond_to?(:occurred_at)
          @notification.occurred_at
        else
          @notification["dateZ"].presence ||
            @notification["createdAt"]
        end

      return if value.blank?

      time = value.respond_to?(:iso8601) ? value : Time.zone.parse(value.to_s)
      time&.iso8601
    rescue ArgumentError, TypeError
      value.to_s
    end

    def person_name(user)
      return if user.blank?

      user.full_name.presence || user.usuario.to_s
    end

    def alert_path
      "/alertas/#{@notification.id}"
    end

    def alert_url
      origin = ENV["AUDITORVE_PUBLIC_URL"].to_s.strip.presence
      return if origin.blank?

      "#{origin.chomp('/')}#{alert_path}"
    end
  end
end
