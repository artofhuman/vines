# coding: UTF-8

module Vines
  class Stanza
    class Message
      module Archive
        extend self

        # EM-safe message archiving
        def process(message)
          return unless message.local?
          return if message.to == message.from

          message.storage(message.to.domain).save_message(message)
        end

        # EM-blocking message archiving
        def process!(message)
          return unless message.local?
          return if message.to == message.from

          message.storage(message.to.domain).save_message!(message)
        end

      end # module Archive
    end
  end
end
