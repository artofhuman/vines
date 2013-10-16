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

      def initialize(node, stream)
        super

        @to = validate_to
        @from = validate_from
      end

      def process
        unless self[TYPE].nil? || VALID_TYPES.include?(self[TYPE])
          raise StanzaErrors::BadRequest.new(self, 'modify')
        end

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

    end
  end
end
