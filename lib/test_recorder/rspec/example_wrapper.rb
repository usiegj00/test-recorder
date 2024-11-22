module TestRecorder
  module RSpec
    module ExampleWrapper
      def run_before_example
        super
        if @example_group_instance.respond_to?(:page)
          TestRecorder::RSpec.cdp_recorder.start(
            page: @example_group_instance.page,
            enabled: self.metadata[:test_recorder]
          )
        else
          puts "Test type does not respond to page. Skipping test screen recording."
        end
      end
    end
  end
end
