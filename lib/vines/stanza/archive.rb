# coding: UTF-8

module Vines
  class Stanza
    class Archive < Iq

      # Empty

      private
      class ResultSetManagment
        include Nokogiri::XML

        NS = NAMESPACES[:rsm]

        attr_reader :max, :after, :before
        # :first, :last, :count

        def initialize(set)
          @max    = node_to_i(set.xpath('ns:max', 'ns' => NS).first)
          @before = node_to_s(set.xpath('ns:before', 'ns' => NS).first)
          @after  = node_to_s(set.xpath('ns:after', 'ns' => NS).first)
        end

        private
        def node_to_i(node)
          node_to_s(node).to_i
        end

        def node_to_s(node)
          node.respond_to?(:text) ? node.text : ''
        end
      end

    end
  end
end
