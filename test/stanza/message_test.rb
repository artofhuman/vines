# encoding: UTF-8

require 'test_helper'

describe Vines::Stanza::Message do
  subject      { Vines::Stanza::Message.new(xml, stream) }
  let(:stream) { MiniTest::Mock.new }
  let(:alice)  { Vines::User.new(jid: 'alice@wonderland.lit/tea') }
  let(:romeo)  { Vines::User.new(jid: 'romeo@verona.lit/balcony') }
  let(:config) do
    Vines::Config.new do
      host 'wonderland.lit' do
        storage(:fs) { dir Dir.tmpdir }
      end
    end
  end

  before do
    class << stream
      attr_accessor :config, :user
    end
    stream.user = alice
    stream.config = config
  end

  describe 'when message type attribute is invalid' do
    let(:xml) { node('<message type="bogus">hello!</message>') }

    it 'raises a bad-request stanza error' do
      -> { subject.process }.must_raise Vines::StanzaErrors::BadRequest
    end
  end

  describe 'when the to address is missing' do
    let(:xml) { node('<message>hello!</message>') }

    it 'raises a bad-request stanza error' do
      -> { subject.process }.must_raise Vines::StanzaErrors::BadRequest
    end
  end

  describe 'when addressed to a non-user' do
    let(:bogus) { Vines::JID.new('bogus@wonderland.lit/cake') }
    let(:xml) { node(%Q{<message to="#{bogus}">hello!</message>}) }

    it 'ignores the stanza' do
      -> { subject.process }.must_raise Vines::StanzaErrors::BadRequest
    end
  end

  describe 'when addressed to an offline user' do
    let(:hatter) { Vines::User.new(jid: 'hatter@wonderland.lit/cake') }
    let(:xml) { node(%Q{<message to="#{hatter.jid}" from="#{alice.jid}">hello!</message>}) }
    let(:storage) { MiniTest::Mock.new }

    before do
      storage.expect :find_user, hatter, [hatter.jid]
      storage.expect :save_message, true, [Vines::Stanza::Message]
      storage.expect :save_pending_stanza, true, [hatter.jid, xml]
      storage.expect :unmark_messages, true, [alice.jid, hatter.jid]

      4.times { stream.expect :storage, storage, [alice.jid.domain] }

      stream.expect :connected_resources, [], [hatter.jid]
      stream.expect :prioritized_resources, [], [hatter.jid]
    end

    it 'store message for resend' do
      subject.process

      stream.verify
      storage.verify
    end
  end

  describe 'when address to a local user in a different domain' do
    let(:xml) { node(%Q{<message to="#{romeo.jid}" from="#{alice.jid}">hello!</message>}) }
    let(:expected) { node(%Q{<message to="#{romeo.jid}" from="#{alice.jid}">hello!</message>}) }
    let(:recipient) { MiniTest::Mock.new }
    let(:storage) { MiniTest::Mock.new }

    before do
      storage.expect :find_user, romeo, [romeo.jid]
      storage.expect :save_message, true, [Vines::Stanza::Message]
      storage.expect :unmark_messages, true, [alice.jid, romeo.jid]

      recipient.expect :user, romeo
      recipient.expect :write, nil, [expected]

      config.host 'verona.lit' do
        storage(:fs) { dir Dir.tmpdir }
      end

      stream.expect :connected_resources, [recipient], [romeo.jid]
      stream.expect :prioritized_resources, [recipient], [romeo.jid]

      2.times { stream.expect :storage, storage, [alice.jid.domain] }
    end

    it 'delivers the stanza to the user' do
      subject.process
      stream.verify
      recipient.verify
    end
  end

  describe 'when addressed to a remote user' do
    let(:xml) { node(%Q{<message to="#{romeo.jid}" from="#{alice.jid}">hello!</message>}) }
    let(:expected) { node(%Q{<message to="#{romeo.jid}" from="#{alice.jid}">hello!</message>}) }
    let(:router) { MiniTest::Mock.new }

    before do
      router.expect :route, nil, [expected]
      stream.expect :router, router
    end

    it 'routes rather than handle locally' do
      subject.process
      stream.verify
      router.verify
    end
  end
end
