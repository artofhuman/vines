# coding: utf-8

require 'test_helper'

describe Vines::Stanza::Presence do
  subject      { Vines::Stanza::Presence.new(xml, stream) }
  let(:stream) { MiniTest::Mock.new }
  let(:config) do
    Vines::Config.new do
      host 'wonderland.lit' do
        storage(:fs) { dir Dir.tmpdir }
      end
    end
  end

  before do
    class << stream
      attr_accessor :user, :nodes, :config
      def write(node)
        @nodes ||= []
        @nodes << node
      end

      def background
        yield
      end
    end
  end

  describe '#send_pending_stanzas' do
    let(:alice)   { Vines::JID.new('alice@wonderland.lit/tea') }
    let(:user)    { MiniTest::Mock.new }
    let(:storage) { MiniTest::Mock.new }
    let(:stanza)  { MiniTest::Mock.new }
    let(:pending_stanzas) do
      [
        PendingStanza.new(15, '<presence id="42" to="alice@wonderland.lit" />'),
        PendingStanza.new(17, '<message to="alice@wonderland.lit" from="romeo@wonderland.lit">hello!</message>'),
      ]
    end

    let(:xml) do
      node(%q{
        <presence xmlns="jabber:client">
          <priority>1</priority>
          <show>away</show>
        </presence>
      })
    end

    before do
      class << user
        attr_accessor :jid
      end
      user.jid = alice
      stream.user = user
      stream.config = config

      storage.expect :find_pending_stanzas!, pending_stanzas, [alice]
      storage.expect :find_pending_stanzas!, [], [alice]
      storage.expect :delete_pending_stanzas!, true, [[15, 17]]

      2.times { stanza.expect :archive!, true }

      stream.expect :prioritized?, true
      3.times { stream.expect :domain, 'wonderland.lit' }
      3.times { stream.expect :storage, storage, ['wonderland.lit'] }
    end

    it 'sends pending stanzas' do
      Vines::Stanza.stub(:from_node, stanza) do
        subject.send :send_pending_stanzas
      end

      stream.verify
      storage.verify
      stanza.verify
      user.verify

      stream.nodes.size.must_equal 2
      stream.nodes[0].must_equal node(%q{<presence id="42" to="alice@wonderland.lit" label="offline"/>})
      stream.nodes[1].must_equal node(%q{<message to="alice@wonderland.lit" from="romeo@wonderland.lit" label="offline">hello!</message>})
    end

    PendingStanza = Struct.new(:id, :xml)
  end
end
