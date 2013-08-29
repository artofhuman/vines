# coding: UTF-8

module Vines
  class Stanza
    class Archive
      class List < Archive
        NS = NAMESPACES[:archive]
        ACCEPTABLE_SET_SIZE = (1..100).freeze

        register "/iq[@id and @type='get']/ns:list", 'ns' => NS

        def process
          return if route_iq || !allowed?

          node = self.xpath('ns:list', 'ns' => NS).first
          rsm_node = node.xpath('ns:set', 'ns' => ResultSetManagment::NS)
          raise StanzaErrors::BadRequest.new(self, 'modify') if rsm_node.empty?

          rsm = ResultSetManagment.from_node(rsm_node)
          raise StanzaErrors::NotAcceptable.new(self, 'modify') unless ACCEPTABLE_SET_SIZE.cover?(rsm.max.to_i)

          jid = JID.new(node['with'])
          collections = jid.empty? ? storage.find_collections(stream.user.jid, rsm)
                                   : storage.find_with_collections(stream.user.jid, jid, rsm)

          if collections.empty?
            send_empty_list
            return
          end

          send_list(collections)
        end

        private
        def send_empty_list
          el = to_result
          el << el.document.create_element('list') do |list|
            list.default_namespace = NS
          end

          stream.write(el)
        end

        def send_list(collections)
          me = stream.user.jid.bare.to_s

          el = to_result
          el << el.document.create_element('list') do |list|
            list.default_namespace = NS
            
            collections.each do |chat|
              list << el.document.create_element('chat', 'with' => chat_with(chat, me),
                                                         'start' => chat.created_at.utc)
            end

            list << build_rsm(collections).to_response_xml
          end

          stream.write(el)
        end

        def build_rsm(collections)
          me  = stream.user.jid.bare.to_s

          first = "#{chat_with(collections.first, me)}@#{collections.first.created_at.utc}"
          last  = "#{chat_with(collections.last, me)}@#{collections.last.created_at.utc}"
          count = collections.count

          ResultSetManagment.new('count' => count, 'first' => first, 'last' => last)
        end

        def chat_with(chat, me)
          me == chat.jid_from ? chat.jid_with : chat.jid_from
        end
      end
    end
  end
end
