class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  before_action :require_authentication
  helper_method :current_user, :authenticated?

  SESSION_DURATION = 8.hours

  private

  def current_user
    return @current_user if defined?(@current_user)

    @current_user =
      if session_valid?
        AuditUser.find_by(id: session[:audit_user_id])
      end
  end

  def authenticated?
    current_user.present?
  end

  def require_authentication
    return if authenticated?

    reset_session
    redirect_to login_path, alert: "Inicia sesión para continuar."
  end

  def session_valid?
    user_id = session[:audit_user_id]
    authenticated_at = session[:authenticated_at]

    return false if user_id.blank? || authenticated_at.blank?

    Time.at(authenticated_at.to_i) >= SESSION_DURATION.ago
  end
end
