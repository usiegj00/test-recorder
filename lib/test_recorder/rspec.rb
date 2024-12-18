require "test_recorder/cdp_recorder"
require "test_recorder/rspec/example_wrapper"

module TestRecorder
  module RSpec
    CHARS_TO_TRANSLATE = ['/', '.', ':', ',', "'", '"', " "].freeze

    class << self
      attr_accessor :cdp_recorder

      def after_example(example)
        video_path = cdp_recorder.stop_and_save(method_name(example)).to_s
        if File.exist?(video_path)
          example.metadata[:extra_failure_lines] = [example.metadata[:extra_failure_lines], "[Video]: #{video_path}"].flatten
        end
      end

      def method_name(example)
        example.description.underscore.tr(CHARS_TO_TRANSLATE.join, "_")[0...200]
      end

      def passed?(example)
        return false if example.exception
        return true unless defined?(::RSpec::Expectations::FailureAggregator)

        failure_notifier = ::RSpec::Support.failure_notifier
        return true unless failure_notifier.is_a?(::RSpec::Expectations::FailureAggregator)

        failure_notifier.failures.empty? && failure_notifier.other_errors.empty?
      end
    end
  end
end

RSpec::Core::Example.prepend(TestRecorder::RSpec::ExampleWrapper)

RSpec.configure do |config|
  puts "RSpec.configure -> Add CDP Recorder"
  TestRecorder::RSpec.cdp_recorder = TestRecorder::CdpRecorder.new(enabled: true)

  config.after(type: :system) do |example|
    TestRecorder::RSpec.after_example(example)
  end
  
  config.after(type: :feature) do |example|
    TestRecorder::RSpec.after_example(example)
  end
end
