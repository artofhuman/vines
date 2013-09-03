# coding: UTF-8

module Vines
  class Stanza
    class Rsm

      class Response < Rsm
        def self.fields
          {'count' => nil, 'first' => nil, 'last' => nil}
        end

        def to_xml
          doc = Document.new
          doc.create_element('set') do |set|
            set.default_namespace = NS

            @options.each do |f, v|
              set << doc.create_element(f, v)
            end
          end
        end

        fields.keys.each { |f| define_method(f) { @options[f] } }

        private
        def cast_types
          @options['count'] = @options['count'].to_i unless @options['count'].nil?
        end
      end

    end
  end
end
