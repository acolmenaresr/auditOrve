require "test_helper"

class Api::Internal::PushNotificationsControllerTest < ActionDispatch::IntegrationTest
  test "redirects dashboard path to the alerts panel" do
    controller = Api::Internal::PushNotificationsController.new
    controller.params = ActionController::Parameters.new(path: "/dashboard")

    assert_equal "/alertas", controller.send(:notification_path)
  end

  test "keeps a blank path on the alerts panel" do
    controller = Api::Internal::PushNotificationsController.new
    controller.params = ActionController::Parameters.new(path: "")

    assert_equal "/alertas", controller.send(:notification_path)
  end
end
