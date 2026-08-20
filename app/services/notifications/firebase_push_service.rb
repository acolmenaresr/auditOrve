require "base64"
require "json"
require "stringio"
require "googleauth"
require "net/http"
require "uri"

module Notifications
  class FirebasePushService
    FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging"

    def initialize
      @project_id = firebase_config(
        :project_id,
        "FIREBASE_PROJECT_ID"
      )
      @service_account_base64 = firebase_config(
        :service_account_base64,
        "FIREBASE_SERVICE_ACCOUNT_BASE64"
      )

      if @project_id.blank?
        raise KeyError, "Falta FIREBASE_PROJECT_ID (ENV o credentials.firebase.project_id)"
      end

      if @service_account_base64.blank?
        raise KeyError, "Falta FIREBASE_SERVICE_ACCOUNT_BASE64 (ENV o credentials.firebase.service_account_base64)"
      end
    end

    def send_to_token(
      token:,
      title:,
      body:,
      data: {},
      tag: "auditorve-alert-summary"
    )
      raise ArgumentError, "FCM token requerido" if token.blank?
      raise ArgumentError, "Título requerido" if title.blank?
      raise ArgumentError, "Body requerido" if body.blank?

      uri = URI(
        "https://fcm.googleapis.com/v1/projects/#{@project_id}/messages:send"
      )

      request = Net::HTTP::Post.new(uri)

      request["Authorization"] =
        "Bearer #{access_token}"

      request["Content-Type"] =
        "application/json"

      string_data = stringify_data(
        data.merge(tag: tag)
      )

      webpush = {
        notification: {
          title: title,
          body: body,

          icon: "/auditorve-favicon-v3.png",
          badge: "/auditorve-favicon-v3.png",

          tag: tag,

          renotify: true,
          requireInteraction: true,

          data: string_data
        }
      }

      if string_data["link"].present?
        webpush[:fcm_options] = {
          link: string_data["link"]
        }
      end

      request.body = {
        message: {
          token: token,

          notification: {
            title: title,
            body: body
          },

          data: string_data,

          webpush: webpush
        }
      }.to_json

      response = Net::HTTP.start(
        uri.hostname,
        uri.port,
        use_ssl: true
      ) do |http|
        http.request(request)
      end

      unless response.is_a?(Net::HTTPSuccess)
        raise(
          "FCM error #{response.code}: #{response.body}"
        )
      end

      JSON.parse(response.body)
    end

    def access_token
      credentials
        .fetch_access_token!
        .fetch("access_token")
    end

    private

    def service_account_json
      Base64.strict_decode64(
        @service_account_base64
      )
    end

    def credentials
      @credentials ||= begin
        json = service_account_json
        parsed = JSON.parse(json)

        unless parsed["type"] == "service_account"
          raise "Credencial Firebase inválida"
        end

        Google::Auth::ServiceAccountCredentials.make_creds(
          json_key_io: StringIO.new(json),
          scope: FCM_SCOPE
        )
      end
    end

    def stringify_data(data)
      data.transform_values do |value|
        value.nil? ? "" : value.to_s
      end
    end

    def firebase_config(credential_key, env_key)
      ENV[env_key].to_s.strip.presence ||
        Rails.application.credentials.dig(:firebase, credential_key).to_s.strip.presence
    end
  end
end
