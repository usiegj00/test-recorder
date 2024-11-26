if defined?(Capybara::Session)
  module Capybara
    module HumanClick
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
