require "test_helper"

class AuditNotifications::DashboardQueryTest < ActiveSupport::TestCase
  test "accepts activas and finalizadas status filters" do
    query = AuditNotifications::DashboardQuery.new(
      from: Date.current,
      to: Date.current + 1,
      status: "activas"
    )

    assert_equal "activas", query.status

    query = AuditNotifications::DashboardQuery.new(
      from: Date.current,
      to: Date.current + 1,
      status: "finalizadas"
    )

    assert_equal "finalizadas", query.status
  end

  test "orders open alerts with assigned before unassigned" do
    sql = AuditNotifications::DashboardQuery::OPEN_ORDER_SQL

    assert_includes sql, "asignadoA"
    assert_not_includes sql, "resuelta"
  end

  test "shows open and closed tables together by default" do
    query = AuditNotifications::DashboardQuery.new(
      from: Date.current,
      to: Date.current + 1
    )

    assert query.show_open_table?
    assert query.show_closed_table?
  end

  test "finalizadas filter hides the open table" do
    query = AuditNotifications::DashboardQuery.new(
      from: Date.current,
      to: Date.current + 1,
      status: "finalizadas"
    )

    assert_not query.show_open_table?
    assert query.show_closed_table?
  end

  test "open and closed status sets are complementary" do
    open_statuses = AuditNotifications::DashboardQuery::OPEN_STATUSES
    closed_statuses = AuditNotifications::DashboardQuery::CLOSED_STATUSES

    assert_equal %w[pendiente asignada en_revision], open_statuses
    assert_equal %w[resuelta descartada], closed_statuses
    assert_empty(open_statuses & closed_statuses)
  end
end
