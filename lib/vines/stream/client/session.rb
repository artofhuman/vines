# encoding: UTF-8

module Vines
  class Stream
    class Client
      # A Session tracks the state of a client stream over its lifetime from
      # negotiation to processing stanzas to shutdown. By disconnecting the
      # stream's state from the stream, we can allow multiple TCP connections
      # to access one logical session (e.g. HTTP streams).
      class Session
        include Comparable

        attr_accessor :domain, :user
        attr_reader   :id, :last_broadcast_presence, :state

        def initialize(stream)
          @stream = stream
          @id = Kit.uuid
          @config = stream.config
          @state = Client::Start.new(stream)
          @available = false
          @domain = nil
          @last_broadcast_presence = nil
          @requested_roster = false
          @unbound = false
          @user = nil
          @prioritized = false
        end

        def <=>(session)
          session.is_a?(Session) ? self.id <=> session.id : nil
        end

        alias :eql? :==

        def hash
          @id.hash
        end

        def advance(state)
          @state = state
        end

        # Returns true if this client has properly authenticated with
        # the server.
        def authenticated?
          !@user.nil?
        end

        # Notify the session that the client has sent an initial presence
        # broadcast and is now considered to be an "available" resource.
        # Available resources are sent presence subscription stanzas.
        def available!
          @available = true
          save_to_cluster
        end

        # An available resource has sent initial presence and can
        # receive presence subscription requests.
        def available?
          @available && connected?
        end

        def prioritized?
          @prioritized && connected?
        end

        # Complete resource binding with the given resource name, provided by the
        # client or generated by the server. Once resource binding is completed,
        # the stream is considered to be "connected" and ready for traffic.
        def bind!(resource)
          @user.jid.resource = resource
          router << self
          save_to_cluster
        end

        # A connected resource has authenticated and bound a resource
        # identifier.
        def connected?
          !@unbound && authenticated? && !@user.jid.bare?
        end

        # An interested resource has requested its roster and can
        # receive roster pushes.
        def interested?
          @requested_roster && connected?
        end

        def last_broadcast_presence=(node)
          @last_broadcast_presence = node
          @prioritized = presence_priority(node) > 0

          save_to_cluster
        end

        def ready?
          @state.class == Client::Ready
        end

        # Notify the session that the client has requested its roster and is now
        # considered to be an "interested" resource. Interested resources are sent
        # roster pushes when changes are made to their contacts.
        def requested_roster!
          @requested_roster = true
          save_to_cluster
        end

        def stream_type
          :client
        end

        def write(data)
          @stream.write(data)
        end

        # Called by the stream when it's disconnected from the client. The stream
        # passes itself to this method in case multiple streams are accessing this
        # session (e.g. BOSH/HTTP).
        def unbind!(stream)
          router.delete(self)
          delete_from_cluster
          unsubscribe_pubsub
          @unbound = true
          @available = false
          broadcast_unavailable
        end

        # Returns streams for available resources to which this user
        # has successfully subscribed.
        def available_subscribed_to_resources
          subscribed = @user.subscribed_to_contacts.map {|c| c.jid }
          router.available_resources(subscribed, @user.jid)
        end

        # Returns streams for available resources that are subscribed
        # to this user's presence updates.
        def available_subscribers
          subscribed = @user.subscribed_from_contacts.map {|c| c.jid }
          router.available_resources(subscribed, @user.jid)
        end

        # Returns contacts hosted at remote servers to which this user has
        # successfully subscribed.
        def remote_subscribed_to_contacts
          @user.subscribed_to_contacts.reject do |c|
            @config.local_jid?(c.jid)
          end
        end

        # Returns contacts hosted at remote servers that are subscribed
        # to this user's presence updates.
        def remote_subscribers(to=nil)
          jid = (to.nil? || to.empty?) ? nil : JID.new(to).bare
          @user.subscribed_from_contacts.reject do |c|
            @config.local_jid?(c.jid) || (jid && c.jid.bare != jid)
          end
        end

        private

        def broadcast_unavailable
          return unless authenticated?
          Fiber.new do
            broadcast(unavailable, available_subscribers)
            broadcast(unavailable, router.available_resources(@user.jid, @user.jid))
            remote_subscribers.each do |contact|
              node = unavailable
              node['to'] = contact.jid.bare.to_s
              router.route(node) rescue nil # ignore RemoteServerNotFound
            end
          end.resume
        end

        def unavailable
          doc = Nokogiri::XML::Document.new
          doc.create_element('presence',
            'from' => @user.jid.to_s,
            'type' => 'unavailable')
        end

        def broadcast(stanza, recipients)
          recipients.each do |recipient|
            stanza['to'] = recipient.user.jid.to_s
            recipient.write(stanza)
          end
        end

        def router
          @config.router
        end

        def save_to_cluster
          if @config.cluster?
            @config.cluster.save_session(@user.jid, to_hash)
          end
        end

        def delete_from_cluster
          if connected? && @config.cluster?
            @config.cluster.delete_session(@user.jid)
          end
        end

        def unsubscribe_pubsub
          if connected?
            @config.vhost(@user.jid.domain).unsubscribe_pubsub(@user.jid)
          end
        end

        def presence_priority(node)
          node.at_css(Stanza::Presence::PRIORITY).text.to_i rescue 0
        end

        def to_hash
          {
            available: @available,
            interested: @requested_roster,
            prioritized: @prioritized,
            presence: @last_broadcast_presence.to_s
          }
        end
      end
    end
  end
end
