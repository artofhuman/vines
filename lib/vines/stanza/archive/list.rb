# coding: UTF-8

module Vines
  class Stanza
    class Archive
      class List < Archive
        NS = NAMESPACES[:archive]

        register "/iq[@id and @type='get']/ns:list/rsm:set", 'ns' => NS,
                                                             'rsm' => ResultSetManagment::NS

        def process
          return if route_iq || !allowed?

          list = self.xpath('ns:list', 'ns' => NS).first
          rsm = ResultSetManagment.new(list.xpath('ns:set', 'ns' => ResultSetManagment::NS))
          raise StanzaErrors::NotAcceptable.new(self, 'modify') if rsm.max < 1

          jid = JID.new(list['with'])

          collections = jid.empty? ? storage.find_collections(stream.user.jid, rsm)
                                   : storage.find_collection(stream.user.jid, jid, rsm)

          if collections.empty?
            send_empty_list
            return
          end

          send_list(collections)
        end

        private
        def send_list(collections)
          el = to_result
          el << el.document.create_element('list') do |list|
            list.default_namespace = NS

            me = stream.user.jid.bare.to_s
            collections.each do |chat|
              with = me == chat.jid_from ? chat.jid_with : chat.jid_from

              list << el.document.create_element('chat', 'with' => with, 'start' => chat.created_at)
            end
          end

          stream.write(el)
        end

        def send_empty_list
          el = to_result
          el << el.document.create_element('list') do |list|
            list.default_namespace = NS
          end

          stream.write(el)
        end

      end
    end
  end
end
