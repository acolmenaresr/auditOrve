class HomeController < ApplicationController
  def index
    destination =
      authorized_home_path

    if destination.present?
      return redirect_to destination
    end

    # Si el tipo de usuario cambió mientras existía una
    # sesión activa y ya no posee una vista implementada,
    # cerramos la sesión.
    reset_session

    redirect_to(
      login_path,
      alert: "Tu perfil aún no tiene una vista habilitada."
    )
  end
end
