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

      def simulate_mouse_movement(x, y)
        javascript = <<~JS
          const event = new MouseEvent('mousemove', {
            bubbles: true,
            cancelable: true,
            clientX: #{x},
            clientY: #{y}
          });
          document.dispatchEvent(event);
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
            acc[:x] = q[:x] if acc[:x].nil? || q[:x] < acc[:x]
            acc[:y] = q[:y] if acc[:y].nil? || q[:y] < acc[:y]
            acc[:w] = q[:x] if acc[:w].nil? || q[:x] > acc[:w]
            acc[:h] = q[:y] if acc[:h].nil? || q[:y] > acc[:h]
            acc
          end

          # puts "Clicking in the rectangle: #{coords}"
          @@click_log.puts({coords: coords, timestamp: Time.now.to_f}.to_json)
          
          # Move the mouse to the center of the element
          # self.session.driver.browser.mouse.move_to(coords[:x] + coords[:w] / 2, coords[:y] + coords[:h] / 2)
          simulate_mouse_movement(coords[:x] + coords[:w] / 2, coords[:y] + coords[:h] / 2)

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
