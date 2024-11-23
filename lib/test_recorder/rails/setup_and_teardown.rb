module TestRecorder
  module Rails
    module SetupAndTeardown
      def before_setup
        @cdp_recorder = TestRecorder::CdpRecorder.new(enabled: true)
        @cdp_recorder.start(page: page, enabled: true)

        super
      end

      def before_teardown
        video_path = @cdp_recorder.stop_and_save("spec_#{self.name}")
        puts "[Video]: #{video_path}" if File.exist?(video_path)
      ensure
        super
      end
    end
  end
end
