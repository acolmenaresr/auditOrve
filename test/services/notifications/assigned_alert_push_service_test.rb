require "test_helper"

class Notifications::AssignedAlertPushServiceTest < ActiveSupport::TestCase
  FakeUser = Struct.new(:id, :usuario, keyword_init: true)

  class FakeNotification
    def initialize(attrs)
      @attrs = attrs
    end

    def id
      @attrs["id"]
    end

    def [](key)
      @attrs[key]
    end
  end

  test "points the assigned push to the alert detail" do
    notification = FakeNotification.new(
      "id" => 42,
      "clave" => "ALT-42",
      "categoriaAlerta" => "posible_exfiltración",
      "tipoAlerta" => "descarga_masiva",
      "motivo" => "Descarga fuera de horario",
      "severidad" => "critica"
    )

    service = Notifications::AssignedAlertPushService.new(
      notification: notification,
      assignee: FakeUser.new(id: 7, usuario: "auditor@orve.mx")
    )

    data = service.send(:notification_data)
    body = service.send(:notification_body)

    assert_equal "audit_alert_assigned", data[:type]
    assert_equal 42, data[:alert_id]
    assert_equal "/alertas/42", data[:path]
    assert_equal "Alerta crítica asignada", service.send(:notification_title)
    assert_equal "Posible exfiltración · Descarga fuera de horario", body
    assert_not_includes body, "ALT-42"
  end

  test "falls back to alert type when category is blank" do
    notification = FakeNotification.new(
      "id" => 7,
      "tipoAlerta" => "acceso_link_anonimo",
      "motivo" => "Recurso sensible por enlace anónimo",
      "severidad" => "alta"
    )

    service = Notifications::AssignedAlertPushService.new(
      notification: notification,
      assignee: FakeUser.new(id: 1, usuario: "auditor@orve.mx")
    )

    assert_equal(
      "Acceso link anonimo · Recurso sensible por enlace anónimo",
      service.send(:notification_body)
    )
  end
end
