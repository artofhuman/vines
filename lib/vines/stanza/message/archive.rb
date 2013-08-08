# coding: UTF-8

module Vines
  class Stanza
    class Message
      module Archive
        extend self

        def process(message)
          return unless message.local?
          return if message.to == message.from

          message.storage(message.to.domain)
                 .save_message(message)
        end

      end
    end
  end
end
