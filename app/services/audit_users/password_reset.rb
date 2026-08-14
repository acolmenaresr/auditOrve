require "json"
require "net/http"
require "uri"

module AuditUsers
  class PasswordReset
    class RequestError < StandardError; end

    BASE_URL =
      "https://auditproject-0626-audit-flows.wxwmvi.easypanel.host"

    VALIDATE_URL =
      URI("#{BASE_URL}/webhook/RPapi")

    UPDATE_URL =
      URI("#{BASE_URL}/webhook/updatePSD")

    class << self
      def validate(token:)
        post_json(
          VALIDATE_URL,
          {
            token: token
          }
        )
      end

      def update_password(
        token:,
        password_hash:,
        user_id:
      )
        post_json(
          UPDATE_URL,
          {
            token: token,
            newPassword: password_hash,
            userID: user_id
          }
        )
      end

      private

      def post_json(uri, payload)
        request = Net::HTTP::Post.new(uri)

        request["Content-Type"] = "application/json"
        request["Accept"] = "application/json"

        request.body = JSON.generate(payload)

        http = Net::HTTP.new(
          uri.host,
          uri.port
        )

        http.use_ssl =
          uri.scheme == "https"

        http.open_timeout = 5
        http.read_timeout = 15

        response = http.request(request)

        unless response.is_a?(Net::HTTPSuccess)
          raise RequestError,
                "n8n respondió HTTP #{response.code}"
        end

        JSON.parse(response.body)
      rescue JSON::ParserError => e
        raise RequestError,
              "n8n devolvió una respuesta JSON inválida: #{e.message}"
      rescue Net::OpenTimeout,
             Net::ReadTimeout,
             SocketError,
             SystemCallError => e
        raise RequestError,
              "No fue posible comunicarse con n8n: #{e.message}"
      end
    end
  end
end
