# coding: UTF-8

module Vines
  class Stanza
    class Message
      module Unmark
        extend self

        # EM-safe message archiving
        def process(message)
          return unless message.local?
          return if message.inbound?

          message.storage(message.to.domain)
                 .unmark_messages(message.from, message.to)
        end

      end # module Unmark
    end
  end
end
