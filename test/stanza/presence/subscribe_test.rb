# encoding: UTF-8

require 'test_helper'

describe Vines::Stanza::Presence::Subscribe do
  subject       { Vines::Stanza::Presence::Subscribe.new(xml, stream) }
  let(:stream)  { MiniTest::Mock.new }
  let(:alice)   { Vines::JID.new('alice@wonderland.lit/tea') }
  let(:hatter)  { Vines::JID.new('hatter@wonderland.lit') }
  let(:contact) { Vines::Contact.new(jid: hatter) }

  before do
    class << stream
      attr_accessor :user, :nodes
      def write(node)
        @nodes ||= []
        @nodes << node
      end
    end
  end

  describe 'outbound subscription to a local jid, but missing contact' do
    let(:xml) { node(%q{<presence id="42" to="hatter@wonderland.lit" type="subscribe"/>}) }
    let(:alice_user) { MiniTest::Mock.new }
    let(:hatter_user) { MiniTest::Mock.new }
    let(:storage) { MiniTest::Mock.new }
    let(:alice_recipient) { MiniTest::Mock.new }
    let(:hatter_recipient) { MiniTest::Mock.new }
    let(:config) { MiniTest::Mock.new }

    before do
      class << hatter_user
        attr_accessor :jid
      end
      hatter_user.jid = hatter

      class << alice_user
        attr_accessor :jid
      end
      alice_user.jid = alice
      alice_user.expect :request_subscription, nil, [hatter]
      alice_user.expect :contact, contact, [hatter]

      storage.expect :save_user, nil, [alice_user]
      storage.expect :find_user, nil, [hatter]

      alice_recipient.expect :user, alice_user
      class << alice_recipient
        attr_accessor :nodes
        def write(node)
          @nodes ||= []
          @nodes << node
        end
      end

      hatter_recipient.expect :user, hatter_user
      class << hatter_recipient
        attr_accessor :nodes
        def write(node)
          @nodes ||= []
          @nodes << node
        end
      end

      stream.user = alice_user
      stream.expect :config, config
      stream.expect :domain, 'wonderland.lit'
      2.times { stream.expect :storage, storage, ['wonderland.lit'] }
      2.times { stream.expect :available_resources, [hatter_recipient], [hatter] }
      stream.expect :interested_resources, [alice_recipient], [alice]
      stream.expect :update_user_streams, nil, [alice_user]

      config.expect :local_jid?, true, [hatter]

      class << subject
        def route_iq; false; end
        def inbound?; false; end
        def local?;   true;  end
      end
    end

    it 'send the subscription to available recipients' do
      subject.process
      stream.verify
      storage.verify
      config.verify

      alice_user.verify
      alice_recipient.verify
      alice_recipient.nodes.size.must_equal 1

      hatter_user.verify
      hatter_recipient.verify
      hatter_recipient.nodes.size.must_equal 1

      expected = node(%q{<presence id="42" to="hatter@wonderland.lit" type="subscribe" from="alice@wonderland.lit"/>})
      hatter_recipient.nodes.first.must_equal expected
    end

    it 'sends a roster set to the interested resources with subscription none' do
      subject.process
      alice_recipient.nodes.size.must_equal 1

      query = %q{<query xmlns="jabber:iq:roster"><item jid="hatter@wonderland.lit" subscription="none"/></query>}
      expected = node(%Q{<iq to="alice@wonderland.lit/tea" type="set">#{query}</iq>})
      alice_recipient.nodes.first.remove_attribute('id') # id is random
      alice_recipient.nodes.first.must_equal expected
    end
  end
end
