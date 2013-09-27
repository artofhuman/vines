# coding: UTF-8

module Vines
  class Stanza
    class Message
      module Offline
        extend self

        def process(message)
          return unless message.local?
          return unless message.recipients.empty?

          if user = message.storage(message.to.domain).find_user(message.to)
            # TODO Implement offline messaging storage
            #raise StanzaErrors::ServiceUnavailable.new(message, 'cancel')
            message.store
          elsif !message.restored?
            message.share
          end
        end

      end
    end
  end
end
