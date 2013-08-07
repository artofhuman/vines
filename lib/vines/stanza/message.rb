# encoding: UTF-8

module Vines
  class Stanza
    class Message < Stanza
      register "/message"

      attr_reader :to, :from, :recipients

      TYPE, FROM  = %w[type from].map {|s| s.freeze }
      VALID_TYPES = %w[chat error groupchat headline normal].freeze

      VALID_TYPES.each do |type|
        define_method "#{type}?" do
          self[TYPE] == type
        end
      end

      def process
        unless self[TYPE].nil? || VALID_TYPES.include?(self[TYPE])
          raise StanzaErrors::BadRequest.new(self, 'modify')
        end

        @to = validate_to
        @from = validate_from
        @recipients = local? ? stream.connected_resources(@to) : []

        [Archive, Offline, Broadcast].each { |p| p.process(self) }
      end
    end
  end
end
