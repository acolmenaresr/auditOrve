module Api
  module Internal
    class PushNotificationsController < ApplicationController
      skip_before_action :require_authentication

      skip_forgery_protection

      before_action :authenticate_internal_request!

      def create
        total = params[:total].to_i

        if total <= 0
          return render json: {
            ok: true,
            skipped: true,
            reason: "No hay alertas para notificar"
          }
        end

        result =
          Notifications::AuditAlertPushService.new(
            total: total,
            critical: params[:critical].to_i,
            high: params[:high].to_i,
            medium: params[:medium].to_i,
            low: params[:low].to_i,
            path: notification_path
          ).call

        render json: {
          ok: result[:ok],
          eligible_devices: result[:eligible_devices],
          sent: result[:sent],
          failed: result[:failed]
        }
      end

      private

      def authenticate_internal_request!
        expected_token =
          ENV["AUDITORVE_N8N_PUSH_TOKEN"].to_s

        provided_token =
          request.authorization
            .to_s
            .delete_prefix("Bearer ")
            .strip

        valid =
          expected_token.present? &&
          provided_token.present? &&
          ActiveSupport::SecurityUtils.secure_compare(
            provided_token,
            expected_token
          )

        return if valid

        render json: {
          ok: false,
          error: "Unauthorized"
        }, status: :unauthorized
      end

      def notification_path
        path = params[:path].to_s.strip

        return "/alertas" if path.blank?

        path.start_with?("/") ? path : "/alertas"
      end
    end
  end
end
