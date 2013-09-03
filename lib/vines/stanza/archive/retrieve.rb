# coding: UTF-8

module Vines
  class Stanza
    class Archive
      class Retrieve < Archive
        register "/iq[@id and @type='get']/ns:retrieve", 'ns' => NS

        def process
          return if route_iq || !allowed?

          node = self.xpath('ns:retrieve', 'ns' => NS).first

          rsm_node = node.xpath('ns:set', 'ns' => Vines::Stanza::Rsm::NS)
          raise StanzaErrors::BadRequest.new(self, 'modify') if rsm_node.empty?

          rsm = Vines::Stanza::Rsm::Request.from_node(rsm_node)
          raise StanzaErrors::NotAcceptable.new(self, 'modify') unless ACCEPTABLE_SET_SIZE.cover?(rsm.max)

          jid = JID.new(node['with'])
          start = Time.parse(node['start']) rescue nil
          endd  = Time.parse(node['end']) rescue nil
          raise StanzaErrors::BadRequest.new(self, 'modify') if jid.empty? || start.nil?

          messages, total = storage.find_messages(stream.user.jid, jid, rsm: rsm, start: start, end: endd)
          raise StanzaErrors::ItemNotFound.new(self, 'cancel') if messages.empty?

          send_chat(messages, total, jid)
        end

        private
        def send_chat(messages, total, with)
          me = stream.user.jid.bare.to_s
          start = messages.first.created_at

          el = to_result
          el << el.document.create_element('chat') do |chat|
            chat.default_namespace = NS
            chat['with'] = with.bare.to_s
            chat['start'] = start

            messages.each do |message|
              direction = (me == message.jid) ? 'to' : 'from'
              offset = (message.created_at - start).to_i

              chat << el.document.create_element(direction) do |m|
                m['secs'] = offset
                m << el.document.create_element('body', message.body) do |b|
                  b['mid'] = message.created_at.to_i
                end
              end
            end

            chat << build_rsm(messages, total).to_xml
          end

          stream.write(el)
        end

        def build_rsm(messages, total)
          first = messages.first.id
          last = messages.last.id

          Vines::Stanza::Rsm::Response.new('count' => total, 'first' => first, 'last' => last)
        end
      end
    end
  end
end
