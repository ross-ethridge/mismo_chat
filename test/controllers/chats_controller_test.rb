require "test_helper"

class ChatsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get chats_url
    assert_response :success
  end

  test "should create chat" do
    post chats_url
    assert_response :redirect
  end
end
