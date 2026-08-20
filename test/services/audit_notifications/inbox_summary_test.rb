require "test_helper"

class AuditNotifications::InboxSummaryTest < ActiveSupport::TestCase
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

    def to_param
      id.to_s
    end
  end

  test "builds a critical assigned alert with readable category and motive" do
    summary = AuditNotifications::InboxSummary.new(viewer: nil)
    item = summary.send(
      :assigned_item,
      FakeNotification.new(
        "id" => 42,
        "severidad" => "critica",
        "clave" => "ANON_LINK/ID:caf1da",
        "categoriaAlerta" => "posible_exfiltración",
        "motivo" => "Un recurso sucitado fue accedido mediante un enlace anónimo o Anyone."
      )
    )

    assert_equal "critica", item.kind
    assert_equal "Alerta Crítica Asignada", item.title
    assert_equal "Posible exfiltración", item.category
    assert_equal(
      "Un recurso sucitado fue accedido mediante un enlace anónimo o Anyone.",
      item.hint
    )
    assert_equal "/alertas/42", item.path
    assert_not item.grouped
  end

  test "truncates long motives to 150 characters" do
    summary = AuditNotifications::InboxSummary.new(viewer: nil)
    item = summary.send(
      :assigned_item,
      FakeNotification.new(
        "id" => 8,
        "severidad" => "alta",
        "motivo" => "A" * 200
      )
    )

    assert_equal 150, item.hint.length
    assert_equal "alta", item.kind
  end

  test "groups unassigned alerts toward the main alerts panel" do
    summary = AuditNotifications::InboxSummary.new(viewer: nil)
    item = summary.send(:grouped_new_item, 147)

    assert_equal "new", item.kind
    assert_equal "147 Alertas Nuevas", item.title
    assert_equal "Click para revisar", item.hint
    assert item.grouped
    assert_includes item.path, "/alertas"
    assert_includes item.path, "asignacion=sin_asignar"
    assert_includes item.path, "estado=pendiente"
  end
end
