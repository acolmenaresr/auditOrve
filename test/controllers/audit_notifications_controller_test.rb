require "test_helper"

class AuditNotificationsControllerTest < ActionDispatch::IntegrationTest
  test "redirects unauthenticated user to login" do
    get alerts_path

    assert_redirected_to login_path
  end
end
