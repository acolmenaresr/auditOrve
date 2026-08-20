require "test_helper"

class AuditNotifications::RankingsQueryTest < ActiveSupport::TestCase
  test "falls back to default limit when value is invalid" do
    query = AuditNotifications::RankingsQuery.new(
      from: Date.current,
      to: Date.current + 1,
      limit: 7
    )

    assert_equal 10, query.instance_variable_get(:@limit)
  end

  test "accepts allowed limits" do
    query = AuditNotifications::RankingsQuery.new(
      from: Date.current,
      to: Date.current + 1,
      limit: 20
    )

    assert_equal 20, query.instance_variable_get(:@limit)
  end

  test "call returns ranking keys without hitting the database" do
    query = AuditNotifications::RankingsQuery.new(
      from: Date.current,
      to: Date.current + 1,
      limit: 10
    )
    query.define_singleton_method(:top_alert_users) { [] }
    query.define_singleton_method(:top_alert_types) { [] }

    result = query.call

    assert_equal %i[top_alert_users top_alert_types], result.keys
    assert_equal [], result[:top_alert_users]
    assert_equal [], result[:top_alert_types]
  end
end
