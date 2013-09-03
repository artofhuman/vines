# coding: UTF-8

module Vines
  class Stanza
    class Rsm
      include Nokogiri::XML
      include Comparable

      NS = NAMESPACES[:rsm]

      def self.from_node(node)
        text_or_nil = ->(n) { n.nil? ? nil : n.text }

        options = fields.keys.map do |f|
          [f, text_or_nil[node.xpath("ns:#{f}", 'ns' => NS).first]]
        end

        new(fields.merge!(Hash[options]))
      end

      def initialize(options)
        @options = self.class.fields.merge!(options)
        cast_types
      end

      def <=>(other)
        to_hash <=> other.to_hash
      end

      def to_xml
        doc = Document.new
        doc.create_element('set') do |set|
          set.default_namespace = NS

          @options.each do |f, v|
            set << doc.create_element(f, v) unless v.nil?
          end
        end
      end

      def to_hash
        @options
      end
    end
  end
end
