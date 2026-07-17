require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "redirects unauthenticated user to login" do
    get dashboard_path

    assert_redirected_to login_path
  end
end
