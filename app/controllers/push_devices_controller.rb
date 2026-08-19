class PushDevicesController < ApplicationController
  def create
    token = params[:token].to_s.strip
    platform = params[:platform].to_s.strip.presence || "web"

    if token.blank?
      return render json: {
        ok: false,
        error: "FCM token requerido"
      }, status: :unprocessable_entity
    end

    device = PushDevice.find_or_initialize_by(
      token: token
    )

    device.assign_attributes(
      user_id: current_user.id,
      platform: platform,
      active: true,
      last_registered_at: Time.current
    )

    device.save!

    render json: {
      ok: true,
      device: {
        id: device.id,
        platform: device.platform,
        active: device.active
      }
    }
  rescue ActiveRecord::RecordInvalid => e
    render json: {
      ok: false,
      error: e.record.errors.full_messages.join(", ")
    }, status: :unprocessable_entity
  end

  def status
    token = params[:token].to_s.strip

    if token.blank?
      return render json: {
        ok: false,
        registered: false,
        error: "FCM token requerido"
      }, status: :unprocessable_entity
    end

    device = PushDevice.find_by(token: token)

    registered =
      device.present? &&
      device.active? &&
      device.user_id == current_user.id

    render json: {
      ok: true,
      registered: registered
    }
  end
end
