# coding: UTF-8

module Vines
  class Stanza
    class Message
      module Broadcast
        extend self

        def process(message)
          if message.local?
            message.broadcast(message.recipients) unless message.recipients.empty?
          else
            message[FROM] = message.stream.user.jid.to_s
            message.route
          end
        end

      end
    end
  end
end
