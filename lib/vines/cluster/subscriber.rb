# encoding: UTF-8

module Vines
  class Cluster
    # Subscribes to the redis nodes:all broadcast channel to listen for
    # heartbeats from other cluster members. Also subscribes to a channel
    # exclusively for this particular node, listening for stanzas routed to us
    # from other nodes.
    class Subscriber
      include Vines::Log

      ALL, SHARE, FROM, HEARTBEAT, OFFLINE, ONLINE, STANZA, TIME, TO, TYPE, USER =
        %w[cluster:nodes:all cluster:nodes:share
           from heartbeat offline online stanza time to type user].map {|s| s.freeze }

      def initialize(cluster)
        @cluster = cluster
        @channel = "cluster:nodes:#{@cluster.id}"
        @messages = EM::Queue.new
        process_messages
      end

      # Create a new redis connection and subscribe to the nodes:all broadcast
      # channel as well as the channel for this cluster node. Redis connections
      # in subscribe mode cannot be used for other key/value operations.
      def subscribe
        conn = @cluster.connect
        conn.subscribe(ALL)
        conn.subscribe(SHARE)
        conn.subscribe(@channel)
        conn.on(:message) do |channel, message|
          @messages.push([channel, message])
        end
      end

      private

      # Recursively process incoming messages from the queue, guaranteeing they
      # are processed in the order they are received.
      def process_messages
        @messages.pop do |channel, message|
          Fiber.new do
            on_message(channel, message)
            process_messages
          end.resume
        end
      end

      # Process messages as they arrive on the pubsub channels to which we're
      # subscribed.
      def on_message(channel, message)
        doc = JSON.parse(message)
        case channel
        when ALL      then to_all(doc)
        when SHARE    then analyze_share(doc)
        when @channel then to_node(doc)
        end
      rescue => e
        log.error("Cluster subscription message failed: #{e}")
      end

      # Analyze arrived shared message
      # If it's arrive from the same node, then skip it
      # If recipient exist on this node, then process it
      def analyze_share(message)
        return if message['from'] == @cluster.id

        node = Nokogiri::XML(message[STANZA]).root rescue nil
        return unless node

        to = Vines::JID.new(node[TO])
        return unless @cluster.storage(to.domain).user_exists?(to)

        to_node(message)
      end

      # Process a message sent to the nodes:all broadcast channel. In the case
      # of node heartbeats, we update the last time we heard from this node so
      # we can cleanup its session if it goes offline.
      def to_all(message)
        case message[TYPE]
        when ONLINE, HEARTBEAT
          @cluster.poke(message[FROM], message[TIME])
        when OFFLINE
          @cluster.delete_sessions(message[FROM])
        end
      end

      # Process a message published to this node's channel. Messages sent to
      # this channel are stanzas that need to be routed to connections attached
      # to this node.
      def to_node(message)
        case message[TYPE]
        when STANZA then process_stanza(message)
        when USER   then update_user(message)
        end
      end

      # Process arrived message store it for future use or send to resources
      def process_stanza(message)
        node = Nokogiri::XML(message[STANZA]).root rescue nil
        return unless node
        log.debug { "Received cluster stanza: %s -> %s\n%s\n" % [message[FROM], @cluster.id, node] }

        recources = @cluster.connected_resources(node[TO])
        if recources.empty?
          store_stanza(node)
        else
          route_stanza(recources, node)
        end
      end

      # Store stanza for future use
      def store_stanza(node)
        stream = Vines::Cluster::StreamProxy.new(@cluster, {'jid' => node[Vines::Stanza::FROM]})
        stanza = Vines::Stanza.from_node(node, stream)

        if stanza.nil?
          log.warn("Unknown cluster stanza:\n#{node}")
        elsif stanza.store?
          stanza.store
        end
      end

      # Send the stanza, from a remote cluster node, to locally connected
      # streams for the destination user.
      def route_stanza(recources, node)
        recources.each do |session|
          stanza = Vines::Stanza.from_node(node, session.stream)

          if stanza.nil?
            if node[TO]
              stream.write(node)
            else
              log.warn("Cluster stanza missing address:\n#{node}")
            end
          else
            stanza.restored!
            stanza.process
          end
        end
      end

      # Update the roster information, that's cached in locally connected
      # streams, for this user.
      def update_user(message)
        jid = JID.new(message['jid']).bare
        if user = @cluster.storage(jid.domain).find_user(jid)
          @cluster.connected_resources(jid).each do |stream|
            stream.user.update_from(user)
          end
        end
      end
    end
  end
end
