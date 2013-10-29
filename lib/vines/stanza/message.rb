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

        validate_from_and_to
        raise StanzaErrors::BadRequest.new(@node, 'modify') if @to.nil? || @from.nil?

        prioritized = local? ? stream.prioritized_resources(@to) : []
        @recipients = local? ? stream.connected_resources(@to) : []
        @recipients.select! { |r| prioritized.include?(r) } unless prioritized.empty?

        [Broadcast, Archive, Offline, Unmark].each { |p| p.process(self) }
      end

      def broadcast(recipients)
        @node[FROM] = stream.user.jid.to_s unless restored?

        recipients.each do |recipient|
          @node[TO] = recipient.user.jid.to_s
          recipient.write(@node)
        end
      end

      def archive!
        validate_from_and_to
        return if @to.nil? || @from.nil?

        Archive.process!(self)
      end

      # This stanza can be saved for future use
      def store?
        true
      end

      def outbound?
        !inbound?
      end

      def inbound?
        stream.user.jid == @to
      end

      def validate_from_and_to
        validate_to if @to.nil?
        validate_from if @from.nil?

        @from ||= stream.user.jid if outbound?
      end
    end
  end
end
