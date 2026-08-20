class AuditNotificationsController < ApplicationController
  before_action :authorize_events!
  before_action :set_notification, only: %i[show update]
  before_action :authorize_alert_update!, only: :update

  def index
    @date_range = Audit::DateRange.new(
      filter: params[:period],
      custom_from: params[:from],
      custom_to: params[:to]
    )

    query = AuditNotifications::DashboardQuery.new(
      from: @date_range.from,
      to: @date_range.to,
      status: params[:estado],
      severity: params[:severidad],
      assignment: params[:asignacion],
      motive: params[:motivo],
      viewer: current_user,
      restrict_to_queue: current_permissions.event_auditor?,
      page: params[:page],
      closed_page: params[:page_finalizadas],
      page_size: params[:per_page]
    )

    @metrics = query.metrics
    @open_records = query.open_records
    @closed_records = query.closed_records
    @show_open_table = query.show_open_table?
    @show_closed_table = query.show_closed_table?
    @status = query.status
    @severity = query.severity
    @assignment = query.assignment
    @motive = query.motive
    @motive_options = query.motive_options
    @page = query.page
    @closed_page = query.closed_page
    @per_page = query.page_size
    @open_total_count = query.open_total_count
    @closed_total_count = query.closed_total_count
    @open_total_pages = query.open_total_pages
    @closed_total_pages = query.closed_total_pages
    @total_count = query.total_count
    @directory_users_by_email =
      directory_users_by_email(
        Array(@open_records) + Array(@closed_records)
      )
    @can_assign_alerts = current_permissions.can_assign_alerts?
    @assignable_alert_users =
      current_permissions.assignable_alert_users
  end

  def show
    @return_to = safe_return_path(params[:return_to])
    email = @notification["usuario"].to_s.strip.downcase
    @directory_user =
      if email.present?
        Microsoft365User.find_by(
          "LOWER(BTRIM(user_principal_name)) = ?",
          email
        )
      end
    @can_attend = current_permissions.can_manage_events?
    @can_assign_alerts = current_permissions.can_assign_alerts?
    @assignable_alert_users =
      current_permissions.assignable_alert_users
  end

  def update
    result = AuditNotifications::AttendService.new(
      notification: @notification,
      actor: current_user,
      action: params[:attend_action],
      comment: params[:comment],
      create_exception: params[:create_exception],
      exception_reason: params[:exception_reason],
      assignee_id: params[:assignee_id]
    ).call

    if result.ok
      redirect_to(
        after_update_path,
        notice: notice_for_action
      )
    else
      redirect_to(
        after_update_path,
        alert: result.error
      )
    end
  end

  private

  def set_notification
    @notification = AuditNotification.find(params[:id])
    authorize_alert_visibility!
  end

  def authorize_alert_visibility!
    return unless current_permissions.event_auditor?

    email = current_user.usuario.to_s.strip.downcase
    assigned = @notification["asignadoA"].to_s.strip.downcase
    return if assigned.blank? || assigned == email

    render_not_found!
    throw :abort
  end

  def authorize_alert_update!
    action = params[:attend_action].to_s

    if action == "asignar"
      return if current_permissions.can_assign_alerts?
    else
      return if current_permissions.can_manage_events?
    end

    render_not_found!
    throw :abort
  end

  def notice_for_action
    case params[:attend_action]
    when "asignar"
      "La alerta quedó asignada y en trabajo."
    when "comentario"
      "Se guardó el comentario de la alerta."
    else
      "La alerta fue marcada como terminada."
    end
  end

  def after_update_path
    return_to = params[:return_to].to_s.strip

    if return_to.start_with?("/") && !return_to.start_with?("//")
      return return_to
    end

    alert_path(@notification)
  end

  def safe_return_path(value)
    path = value.to_s.strip
    return alerts_path if path.blank?
    return alerts_path unless path.start_with?("/")
    return alerts_path if path.start_with?("//")

    path
  end

  def directory_users_by_email(records)
    normalized_emails = records.filter_map do |record|
      record["usuario"]
        .to_s
        .strip
        .downcase
        .presence
    end.uniq

    return {} if normalized_emails.empty?

    Microsoft365User
      .where(
        "LOWER(BTRIM(user_principal_name)) IN (?)",
        normalized_emails
      )
      .index_by do |user|
        user.user_principal_name.to_s.strip.downcase
      end
  end
end
