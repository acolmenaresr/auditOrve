require "test_helper"

class AuditNotifications::RankingsQueryTest < ActiveSupport::TestCase
  test "returns empty rankings when there are no alerts in range" do
    result = AuditNotifications::RankingsQuery.new(
      from: Date.new(2000, 1, 1),
      to: Date.new(2000, 1, 2),
      limit: 10
    ).call

    assert_equal [], result[:top_alert_users]
    assert_equal [], result[:top_alert_types]
  end
end
