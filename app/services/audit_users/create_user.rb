require "net/http"
require "json"

module AuditUsers
  class CreateUser
    DEFAULT_URL =
      "https://auditproject-0626-audit-flows.wxwmvi.easypanel.host/webhook/createUser"

    Result = Data.define(
      :success?,
      :message,
      :data
    )

    def initialize(firstname:, lastname:, usuario:, tipo_usuario_id:)
      @firstname = firstname.to_s.strip
      @lastname = lastname.to_s.strip
      @usuario = usuario.to_s.strip.downcase
      @tipo_usuario_id = tipo_usuario_id.to_i
    end

    def call
      response = http_client.request(request)
      data = parse_response(response.body)

      if response.is_a?(Net::HTTPSuccess) && data["ok"] != false
        Result.new(
          success?: true,
          message: data["message"].presence ||
            "Usuario creado correctamente.",
          data: data
        )
      else
        Result.new(
          success?: false,
          message: data["message"].presence ||
            "No se pudo crear el usuario.",
          data: data
        )
      end
    rescue JSON::ParserError
      Result.new(
        success?: false,
        message: "La respuesta del servicio de creación de usuarios no es válida.",
        data: {}
      )
    rescue StandardError => error
      Rails.logger.error(
        "[AuditUsers::CreateUser] #{error.class}: #{error.message}"
      )

      Result.new(
        success?: false,
        message: "No fue posible comunicarse con el servicio de creación de usuarios.",
        data: {}
      )
    end

    private

    attr_reader :firstname,
                :lastname,
                :usuario,
                :tipo_usuario_id

    def endpoint
      ENV.fetch(
        "AUDITORVE_CREATE_USER_URL",
        DEFAULT_URL
      )
    end

    def uri
      @uri ||= URI(endpoint)
    end

    def http_client
      client = Net::HTTP.new(uri.host, uri.port)

      client.use_ssl = uri.scheme == "https"
      client.open_timeout = 5
      client.read_timeout = 15

      client
    end

    def request
      Net::HTTP::Post.new(uri).tap do |request|
        request["Content-Type"] = "application/json"
        request.body = payload.to_json
      end
    end

    def payload
      {
        nombreUsuario: firstname,
        apellidoUsuario: lastname,
        usuario: usuario,
        tipoUsuario: tipo_usuario_id
      }
    end

    def parse_response(body)
      parsed = JSON.parse(body.presence || "{}")

      normalize_response(parsed)
    end

    def normalize_response(value)
      value = value.first if value.is_a?(Array)
      return {} unless value.is_a?(Hash)

      nested =
        value["json"] ||
        value["body"] ||
        value["result"]

      return value unless nested

      if nested.is_a?(String)
        JSON.parse(nested)
      elsif nested.is_a?(Hash)
        nested
      else
        value
      end
    end
  end
end