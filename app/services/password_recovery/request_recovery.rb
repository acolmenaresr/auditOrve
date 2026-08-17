require "net/http"
require "json"

module PasswordRecovery
  class RequestRecovery
    ENDPOINT_URL =
      "https://auditproject-0626-audit-flows.wxwmvi.easypanel.host/webhook/ResetPWD".freeze

    GENERIC_MESSAGE =
      "Si el correo está registrado recibirás instrucciones para recuperar tu contraseña.".freeze

    ERROR_MESSAGE =
      "No fue posible procesar la solicitud. Intenta nuevamente.".freeze

    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 15


    def initialize(
      email:,
      ip:,
      user_agent:
    )
      @email = email
      @ip = ip
      @user_agent = user_agent
    end


    # =========================================================
    # EJECUTAR SOLICITUD
    # =========================================================

    def call
      uri =
        URI.parse(
          ENDPOINT_URL
        )

      request =
        build_request(
          uri
        )

      response =
        perform_request(
          uri,
          request
        )

      unless response.is_a?(
        Net::HTTPSuccess
      )
        Rails.logger.error(
          "[PasswordRecovery] ResetPWD respondió HTTP #{response.code}"
        )

        return failure_result
      end

      success_result

    rescue StandardError => error
      Rails.logger.error(
        "[PasswordRecovery] Error solicitando ResetPWD: " \
        "#{error.class}: #{error.message}"
      )

      failure_result
    end


    private


    # =========================================================
    # REQUEST
    #
    # Conserva el mismo contrato utilizado actualmente:
    #
    # {
    #   "correoReset": "usuario@correo.com"
    # }
    # =========================================================

    def build_request(uri)
      request =
        Net::HTTP::Post.new(
          uri.request_uri
        )

      request["Content-Type"] =
        "application/json"

      request["Accept"] =
        "application/json"

      set_forwarded_headers(
        request
      )

      request.body =
        {
          correoReset: @email
        }.to_json

      request
    end


    # =========================================================
    # IP Y USER AGENT
    #
    # n8n utiliza estos headers para registrar:
    #
    # - requested_ip
    # - user_agent
    #
    # Rails actúa como intermediario, por lo que reenviamos
    # los datos originales de la solicitud del navegador.
    # =========================================================

    def set_forwarded_headers(request)
      if @ip.present?
        request["X-Forwarded-For"] =
          @ip

        request["X-Real-IP"] =
          @ip
      end

      request["User-Agent"] =
        @user_agent.presence ||
        "AuditORVE-Rails"
    end


    # =========================================================
    # HTTP
    # =========================================================

    def perform_request(
      uri,
      request
    )
      http =
        Net::HTTP.new(
          uri.host,
          uri.port
        )

      http.use_ssl =
        uri.scheme == "https"

      http.open_timeout =
        OPEN_TIMEOUT

      http.read_timeout =
        READ_TIMEOUT

      http.request(
        request
      )
    end


    # =========================================================
    # RESPUESTAS
    #
    # La respuesta exitosa siempre es genérica para no revelar
    # si una cuenta existe o no en AuditORVE.
    # =========================================================

    def success_result
      {
        ok: true,
        message: GENERIC_MESSAGE
      }
    end


    def failure_result
      {
        ok: false,
        message: ERROR_MESSAGE
      }
    end
  end
end
