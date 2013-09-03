# coding: UTF-8

module Vines
  class Stanza
    class Rsm

      class Request < Rsm
        def self.fields
          {'max' => nil, 'after' => nil, 'before' => nil}
        end

        fields.keys.each { |f| define_method(f) { @options[f] } }

        private
        def cast_types
          @options['max'] = @options['max'].to_i unless @options['max'].nil?
        end
      end

    end
  end
end
