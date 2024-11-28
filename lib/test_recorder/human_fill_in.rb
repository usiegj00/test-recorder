if defined?(Capybara::Session)
  module Capybara
    module HumanFillIn
      def fill_in(locator, with:, wpm: 40, error_rate: 0.06, bypass: false, **options)
        # Bypass the human typing simulation
        return super(locator, with: with, **options) if bypass
        return super(locator, with: with, **options) if wpm <= 0 || wpm > 1000
        return super(locator, with: with, **options) if !respond_to?(:find_field)
        # Locate the input field
        field = find_field(locator, **options)
        return super(locator, with: with, **options) if field.nil? || !field.respond_to?(:click) || !field.respond_to?(:set) || !field.respond_to?(:send_keys)
        field.click # Ensure the field is focused
        sleep rand(0.2..0.5) # Simulate initial focus delay

        # Clear existing content
        field.set('')

        # Calculate average delay between keystrokes
        chars_per_minute = wpm * 5 # Average word length is assumed to be 5 chars
        base_delay = 60.0 / chars_per_minute

        # Define punctuation marks and paragraph delimiters
        punctuation_marks = ['.', ',', '!', '?', ';', ':']
        paragraph_delimiters = ["\n", "\r\n"]

        # Type the new content one character at a time
        with.each_char do |char|
          # Simulate error based on error_rate
          if rand < error_rate
            # Introduce a random incorrect character
            incorrect_char = ('a'..'z').to_a.sample
            field.send_keys(incorrect_char)
            sleep base_delay * (0.2 + rand * 0.4)
            # Backspace to correct the error
            field.send_keys(:backspace)
            sleep base_delay * (0.2 + rand * 0.4)
          end

          # Send the correct character
          field.send_keys(char)
          sleep base_delay * (0.2 + rand * 0.4)

          # Introduce pauses after punctuation
          if punctuation_marks.include?(char)
            sleep rand(0.3..0.7) # Pause between 300ms to 700ms
          end

          # Introduce longer pauses between paragraphs
          if paragraph_delimiters.include?(char)
            sleep rand(1.0..2.0) # Pause between 1 to 2 seconds
          end
        end
      rescue NotImplementedError
        # Some drivers define send_keys but don't implement it
        return super(locator, with: with, **options)
      end
    end
  end

  # Extend Capybara::Session to include the new behavior
  Capybara::Session.prepend(Capybara::HumanFillIn)
  puts "Loaded human fill in."
end
