# coding: UTF-8

module Vines
  class Stanza
    class Message
      module Unmark
        extend self

        # EM-safe message archiving
        def process(message)
          return unless message.local?
          return unless message.local_jid?(message.from)
          return if message.inbound?

          message.storage(message.from.domain)
                 .unmark_messages(message.from, message.to)
        end

      end # module Unmark
    end
  end
end
