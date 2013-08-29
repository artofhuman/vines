# coding: UTF-8

module Vines
  class Stanza
    class Archive < Iq

      # Empty

      private
      class ResultSetManagment
        include Nokogiri::XML

        NS = NAMESPACES[:rsm]
        SET  = %w[max count after before first last].freeze

        def self.from_node(node)
          options = SET.map do |attribute|
            value = node.xpath("ns:#{attribute}", 'ns' => NS).first

            unless value.nil?
              value = value.text
              value = value.to_i if %w[max count].include?(attribute)
            end

            [attribute, value]
          end

          new(Hash[options])
        end

        def initialize(options)
          @options = options
        end

        def to_response_xml
          doc = Document.new
          doc.create_element('set') do |set|
            set.default_namespace = NS

            %w[first last count].each do |a|
              set << doc.create_element(a, @options[a])
            end
          end
        end

        def to_request_xml
          doc = Document.new
          doc.create_element('set') do |set|
            set.default_namespace = NS

            %w[max after before].reject { |a| @options[a].nil? }.each do |a|
              set << doc.create_element(a, @options[a])
            end
          end
        end

        SET.each { |a| define_method(a) { @options[a] } }
      end

    end
  end
end
