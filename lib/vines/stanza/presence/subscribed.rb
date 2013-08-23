# encoding: UTF-8

module Vines
  class Stanza
    class Presence
      class Subscribed < Presence
        register "/presence[@type='subscribed']"

        def process
          if restored?
            self['from'] = validate_from.bare.to_s
          else
            stamp_from
          end

          inbound? ? process_inbound : process_outbound
        end

        def process_outbound
          to = stamp_to
          from = restored? ? validate_from : to

          if restored?
            local? ? process_inbound : route
            return
          end

          stream.user.add_subscription_from(from)
          storage.save_user(stream.user)
          stream.update_user_streams(stream.user)

          local? ? process_inbound : route
          send_roster_push(from)
          send_known_presence(from)
        end

        def process_inbound
          to = stamp_to
          from = validate_from

          user = storage(to.domain).find_user(to)
          contact = user.contact(from) if user

          if contact && contact.can_subscribe?
            contact.subscribe_to
            storage(to.domain).save_user(user)
            stream.update_user_streams(user)
            broadcast_subscription_change(contact)
          else
            broadcast_to_available_resources([@node], to)
          end
        end

        private

        # After approving a contact's subscription to this user's presence,
        # broadcast this user's most recent presence stanzas to the contact.
        def send_known_presence(to)
          stanzas = stream.available_resources(stream.user.jid).map do |stream|
            stream.last_broadcast_presence.clone.tap do |node|
              node['from'] = stream.user.jid.to_s
              node['id'] = Kit.uuid
            end
          end
          broadcast_to_available_resources(stanzas, to)
        end
      end
    end
  end
end
