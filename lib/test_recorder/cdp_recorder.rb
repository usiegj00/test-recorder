require "open3"
require "fileutils"
require "tempfile"

module TestRecorder
  class CdpRecorder
    def initialize(enabled:)
      @enabled = enabled
      @started = nil
      @page = nil
      @frames = StringIO.new
      setup
    end

    def setup
      @frames_dir = ::Rails.root.join("tmp", "frames")
      FileUtils.mkdir_p(@frames_dir)
      # Clean up any old frames (anything .png in the directory)
      FileUtils.rm_rf(Dir["#{@frames_dir}/*.png"])
    end

    def start(page:, enabled: nil)
      enabled = @enabled if enabled.nil?
      @started = enabled
      return unless @started

      return unless page.driver.browser.respond_to?(:page)
      
      @page = page
      @page.driver.browser.page.start_screencast(format: "png", every_nth_frame: 1) do |data, _metadata, _session_id|
        @frames.write("#{data}|#{_metadata}|#{_session_id}\n")
      end
    end

    def stop_and_discard
      return unless @page.driver.browser.respond_to?(:page)
      if @started
        @page.driver.browser.page.stop_screencast
        @frames.truncate(0)
        @frames.close
      end
    end

    def stop_and_save(filename)
      return "" unless @started
      return unless @page.driver.browser.respond_to?(:page)

      @page.driver.browser.page.stop_screencast

      @frames.string.split("\n").each do |frame|
        next if frame.empty?
        data, metadata, session_id = frame.split("|")
        timestamp = metadata.split("timestamp\"=>")[1].split("}")[0]
        # Parse the timestamp (a float) and then format it back as a float, but with 0 padding so it can be lexically sorted
        timestamp = format("%0.08f", timestamp.to_f)

        frame_path = @frames_dir.join("#{filename}_#{timestamp}.png")
        File.open(frame_path, "wb") do |f|
          f.set_encoding("ASCII-8BIT")
          f.write(Base64.decode64(data))
        end
      end
      @frames_dir
    end
  end
end
