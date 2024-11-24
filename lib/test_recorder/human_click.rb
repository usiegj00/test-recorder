if defined?(Capybara::Session)
  module Capybara
    module HumanClick
      def click(*options, bypass: false)
        # Bypass the human typing simulation
        return super(*options) if bypass

        # Retrieve the current mouse position
        current_position = page.driver.browser.mouse.position

        # Log the current mouse position
        puts "Current mouse position: #{current_position}"

        # Retrieve the target element's position
        target_position = self.native.rect

        # Log the target element's position
        puts "Target element position: #{target_position}"

        # Call the original click method
        super(*options)
      end
    end
  end

  # Extend Capybara::Session to include the new behavior
  Capybara::Node::Element.include(Capybara::HumanClick)
  # Capybara::Session.prepend(Capybara::HumanClick)
  puts "Loaded human click."
end
