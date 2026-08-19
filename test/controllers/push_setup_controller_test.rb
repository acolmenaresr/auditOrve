require "test_helper"

class PushSetupControllerTest < ActionDispatch::IntegrationTest
  test "redirects unauthenticated user to login" do
    get push_setup_path

    assert_redirected_to login_path
  end
end
