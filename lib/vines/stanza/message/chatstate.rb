# coding: utf-8

module Vines
  class Stanza
    class Message
      class Chatstate
        NS = NAMESPACES[:chatstates]

        # Public: Is this message is service message about user typing
        #
        # node - Nokogiri::XML::Document parsed message xml
        #
        # Returns boolean
        def self.typing?(node)
          node.xpath('/message/ns:composing or /message/ns:active or /message/ns:paused', ns: NS)
        end

      end
    end
  end
end
