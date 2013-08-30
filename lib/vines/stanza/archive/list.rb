# coding: UTF-8

module Vines
  class Stanza
    class Archive
      class List < Archive
        register "/iq[@id and @type='get']/ns:list", 'ns' => NS

        def process
          return if route_iq || !allowed?

          node = self.xpath('ns:list', 'ns' => NS).first
          rsm_node = node.xpath('ns:set', 'ns' => ResultSetManagment::NS)
          raise StanzaErrors::BadRequest.new(self, 'modify') if rsm_node.empty?

          rsm = ResultSetManagment.from_node(rsm_node)
          raise StanzaErrors::NotAcceptable.new(self, 'modify') unless ACCEPTABLE_SET_SIZE.cover?(rsm.max.to_i)

          jid = JID.new(node['with'])
          # TODO node['start']
          # TODO node['end']

          options = {rsm: rsm}
          options[:with] = jid unless jid.empty?

          collections, total = storage.find_collections(stream.user.jid, options)

          if collections.empty?
            send_empty_list
            return
          end

          send_list(collections, total)
        end

        private
        def send_empty_list
          el = to_result
          el << el.document.create_element('list') do |list|
            list.default_namespace = NS
          end

          stream.write(el)
        end

        def send_list(collections, total)
          me = stream.user.jid.bare.to_s

          el = to_result
          el << el.document.create_element('list') do |list|
            list.default_namespace = NS
            
            collections.each do |chat|
              list << el.document.create_element('chat', 'with' => chat_with(chat, me),
                                                         'start' => chat.created_at.utc)
            end

            list << build_rsm(collections, total).to_response_xml
          end

          stream.write(el)
        end

        def build_rsm(collections, total)
          first = collections.first.id
          last  = collections.last.id

          ResultSetManagment.new('count' => total, 'first' => first, 'last' => last)
        end

        def chat_with(chat, me)
          me == chat.jid_from ? chat.jid_with : chat.jid_from
        end
      end
    end
  end
end
