require "test_recorder/cdp_recorder"
require "test_recorder/human_fill_in"
require "test_recorder/rails/setup_and_teardown"

ActiveSupport.on_load(:action_dispatch_system_test_case) do
  include TestRecorder::Rails::SetupAndTeardown
end
