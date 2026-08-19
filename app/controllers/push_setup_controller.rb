class PushSetupController < ApplicationController
  def show
    unless push_alerts_required_for?(current_user)
      session.delete(:push_setup_pending)
      return redirect_to authorized_home_path || root_path
    end

    unless session[:push_setup_pending]
      redirect_to authorized_home_path || root_path
    end
  end

  def complete
    session.delete(:push_setup_pending)

    destination =
      authorized_home_path.presence || root_path

    respond_to do |format|
      format.json do
        render json: {
          ok: true,
          redirect: destination
        }
      end

      format.html do
        redirect_to destination
      end
    end
  end
end
