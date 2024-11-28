if defined?(Capybara::Session)
  module Capybara
    module HumanClick
      def setup
        @frames_dir = ::Rails.root.join("tmp", "frames")
        FileUtils.mkdir_p(@frames_dir)
        # Clean up any old frames (anything .png in the directory)
        FileUtils.rm_rf(Dir["#{@frames_dir}/*.png"])
        @@click_log ||= File.open("tmp/clicks.log", "w")
        timestamp = format("%0.08f", timestamp.to_f)
        frame_path = @frames_dir.join("#{filename}_#{timestamp}.png")
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
        self.session.driver.browser.page.evaluate(javascript)

        # Call the function
        # @page.driver.browser.page.evaluate("installMouseHelper()")
      end

      def add_pointer(x:, y:)
        # Make the pointer centered on x,y
        javascript = <<~JS
        (function() {
          const box = document.createElement('div');
          box.style.position = 'fixed';
          box.style.top = '#{y}px';
          box.style.left = '#{x}px';
          box.style.width = '20px';
          box.style.height = '20px';
          box.style.background = 'rgba(0,0,0,.4)';
          box.style.border = '1px solid white';
          box.style.borderRadius = '10px';
          box.style.margin = '-10px 0 0 -10px';
          box.style.padding = '0';
          box.style.zIndex = '9999';
          box.style.transition = 'background .2s, border-radius .2s, border-color .2s';
          document.body.appendChild(box);
        })();
        JS
        self.session.driver.browser.page.evaluate(javascript)
      end

      def add_red_box(rect:)
        javascript = <<~JS
          (function() {
            const box = document.createElement('div');
            box.id = 'test-red-box';
            box.style.position = 'fixed';
            box.style.top = '#{rect[:y]}px';
            box.style.left = '#{rect[:x]}px';
            box.style.width = '#{rect[:w]}px';
            box.style.height = '#{rect[:h]}px';
            box.style.backgroundColor = 'rgba(255,0,0,.4)';
            box.style.zIndex = '9000';
            box.style.pointerEvents = 'none';
            document.body.appendChild(box);
          })();
        JS

        self.session.driver.browser.page.evaluate(javascript)
      end


      def click(*options, bypass: false)
        # Bypass the human typing simulation
        return super(*options) if bypass

        if self.is_a?(Capybara::Node::Element) && self.native.is_a?(Capybara::Cuprite::Node) && self.native.node.is_a?(Ferrum::Node)
          @@click_log ||= File.open("tmp/clicks.log", "w")

          # self.native.node.instance_eval { bounding_rect_coordinates }
          # [363.0234375, 136.5]
          # self.native.node.instance_eval { wait_for_stop_moving.map { |q| to_points(q) }.first }
          # [{:x=>21.5234375, :y=>127}, {:x=>504.125, :y=>127}, {:x=>504.125, :y=>145.5}, {:x=>221.5234375, :y=>145.5}]
          # self.session.driver.browser.mouse.instance_variable_get("@x")
          coords = self.native.node.instance_eval { wait_for_stop_moving.map { |q| to_points(q) }.first }
          # Make into x,y,w,h
          coords = coords.reduce({}) do |acc, q|
            acc[:x1] = q[:x] if acc[:x1].nil? || q[:x] < acc[:x1]
            acc[:y1] = q[:y] if acc[:y1].nil? || q[:y] < acc[:y1]
            acc[:x2] = q[:x] if acc[:x2].nil? || q[:x] > acc[:x2]
            acc[:y2] = q[:y] if acc[:y2].nil? || q[:y] > acc[:y2]
            acc
          end
          # Now we have x1,y1,x2,y2, convert to x,y,w,h
          coords = { x: coords[:x1], y: coords[:y1], w: coords[:x2] - coords[:x1], h: coords[:y2] - coords[:y1] }

          # puts "Clicking in the rectangle: #{coords}"
          @@click_log.puts({coords: coords, timestamp: Time.now.to_f}.to_json)
          
          # Move the mouse to the center of the element
          # self.session.driver.browser.mouse.move_to(coords[:x] + coords[:w] / 2, coords[:y] + coords[:h] / 2)
          # add_mouse_pointer
          add_red_box(rect: coords) 
          add_pointer(x: coords[:x] + coords[:w] / 2, y: coords[:y] + coords[:h] / 2)
          # simulate_mouse_movement(coords[:x] + coords[:w] / 2, coords[:y] + coords[:h] / 2)
          self.session.driver.browser.mouse.move(x: coords[:x] + coords[:w] / 2, y: coords[:y] + coords[:h] / 2)
          # Click the element
          # self.session.driver.browser.mouse.down.up

        else
          puts "Only supported for Cuprite/Ferrum drivers."
        end
        super(*options)
      end
    end
  end

  # Extend Capybara::Session to include the new behavior
  Capybara::Node::Element.prepend(Capybara::HumanClick)

  # Capybara::Session.prepend(Capybara::HumanClick)
  puts "Loaded human click."
end
