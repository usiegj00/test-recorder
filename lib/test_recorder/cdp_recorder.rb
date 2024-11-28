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

    def add_mouse_pointer
      javascript = <<~JAVASCRIPT
        // This injects a box into the page that moves with the mouse;
        // Useful for debugging
        function installMouseHelper() {
          // Install mouse helper only for top-level frame.
          if (window !== window.parent)
            return;
          window.addEventListener('DOMContentLoaded', () => {
            const box = document.createElement('puppeteer-mouse-pointer');
            const styleElement = document.createElement('style');
            styleElement.innerHTML = `
              puppeteer-mouse-pointer {
                pointer-events: none;
                position: absolute;
                top: 0;
                z-index: 10000;
                left: 0;
                width: 20px;
                height: 20px;
                background: rgba(0,0,0,.4);
                border: 1px solid white;
                border-radius: 10px;
                margin: -10px 0 0 -10px;
                padding: 0;
                transition: background .2s, border-radius .2s, border-color .2s;
              }
              puppeteer-mouse-pointer.button-1 {
                transition: none;
                background: rgba(0,0,0,0.9);
              }
              puppeteer-mouse-pointer.button-2 {
                transition: none;
                border-color: rgba(0,0,255,0.9);
              }
              puppeteer-mouse-pointer.button-3 {
                transition: none;
                border-radius: 4px;
              }
              puppeteer-mouse-pointer.button-4 {
                transition: none;
                border-color: rgba(255,0,0,0.9);
              }
              puppeteer-mouse-pointer.button-5 {
                transition: none;
                border-color: rgba(0,255,0,0.9);
              }
            `;
            document.head.appendChild(styleElement);
            document.body.appendChild(box);
            document.addEventListener('mousemove', event => {
              box.style.left = event.pageX + 'px';
              box.style.top = event.pageY + 'px';
              updateButtons(event.buttons);
            }, true);
            document.addEventListener('mousedown', event => {
              updateButtons(event.buttons);
              box.classList.add('button-' + event.which);
            }, true);
            document.addEventListener('mouseup', event => {
              updateButtons(event.buttons);
              box.classList.remove('button-' + event.which);
            }, true);
            function updateButtons(buttons) {
              for (let i = 0; i < 5; i++)
                box.classList.toggle('button-' + i, buttons & (1 << i));
            }
          }, false);
        };
      installMouseHelper();
      JAVASCRIPT

      # Define the function on the page
      @page.driver.browser.page.evaluate(javascript)

      # Call the function
      # @page.driver.browser.page.evaluate("installMouseHelper()")
    end

    def start(page:, enabled: nil)
      enabled = @enabled if enabled.nil?
      @started = enabled
      return unless @started

      @page = page
      return unless page.driver.browser.respond_to?(:page)
      
      # We must generate a mouse pointer since it is an OS function...
      add_mouse_pointer

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
