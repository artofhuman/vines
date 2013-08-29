# encoding: UTF-8

require 'test_helper'
require 'time'

describe Vines::Stanza::Archive::List do
  subject       { Vines::Stanza::Archive::List.new(xml, stream) }
  let(:stream)  { MiniTest::Mock.new }
  let(:storage) { MiniTest::Mock.new }
  let(:alice)   { Vines::User.new(jid: 'alice@wonderland.lit/home') }
  let(:hatter)  { Vines::User.new(jid: 'hatter@wonderland.lit/balcony') }
  let(:config) do
    Vines::Config.new do
      host 'wonderland.lit' do
        storage(:fs) { dir Dir.tmpdir }
      end
    end
  end

  before do
    class << stream
      attr_accessor :config, :user, :domain
    end
    stream.config = config
    stream.user = alice
    stream.domain = 'wonderland.lit'
  end

  describe 'when rsm not setted properly' do
    describe 'when rsm option max is missed' do
      let(:xml) { list(hatter.jid) }

      it 'raises an not-acceptable stanza error' do
        -> { subject.process }.must_raise Vines::StanzaErrors::NotAcceptable
        stream.verify
      end
    end

    describe 'when rsm not sended at all' do
      let(:xml) { list(hatter.jid, without_rsm: true) }

      it 'raises an bad-request stanza error' do
        -> { subject.process }.must_raise Vines::StanzaErrors::BadRequest
        stream.verify
      end
    end
  end

  describe 'when request all archived collections' do
    describe 'when archive is empty' do
      let(:xml) { list(nil, max: 100) }
      let(:result) do
        node(%q{
          <iq from="wonderland.lit" id="42" to="alice@wonderland.lit/home" type="result">
            <list xmlns="urn:xmpp:archive"/>
          </iq>
        })
      end

      before do
        stream.expect :write, nil, [result]
        stream.expect :storage, storage, [stream.domain]

        storage.expect :find_collections, [], [alice.jid, Vines::Stanza::Archive::ResultSetManagment]
      end

      it 'response with empty list result' do
        subject.process
        storage.verify
        stream.verify
      end
    end

    describe 'when archive has collections' do
      let(:xml) { list(nil, max: 100) }
      let(:result) do
        node(%q{
          <iq from="wonderland.lit" id="42" to="alice@wonderland.lit/home" type="result">
            <list xmlns="urn:xmpp:archive">
              <chat with="hatter@wonderland.lit" start="2013-02-12 09:44:12 UTC"/>
              <chat with="juliet@wonderland.lit" start="2013-05-01 12:15:32 UTC"/>
              <chat with="romeo@wonderland.lit" start="2013-08-27 11:54:06 UTC"/>
              <set xmlns="http://jabber.org/protocol/rsm">
                <first>hatter@wonderland.lit@2013-02-12 09:44:12 UTC</first>
                <last>romeo@wonderland.lit@2013-08-27 11:54:06 UTC</last>
                <count>3</count>
              </set>
            </list>
          </iq>
        })
      end

      before do
        stream.expect :write, nil, [result]
        stream.expect :storage, storage, [stream.domain]

        h = chat(jid_with: 'alice@wonderland.lit', jid_from: 'hatter@wonderland.lit', created_at: '2013-02-12 09:44:12 UTC')
        j = chat(jid_with: 'juliet@wonderland.lit', jid_from: 'alice@wonderland.lit', created_at: '2013-05-01 12:15:32 UTC')
        r = chat(jid_with: 'alice@wonderland.lit', jid_from: 'romeo@wonderland.lit', created_at: '2013-08-27 11:54:06 UTC')

        storage.expect :find_collections, [h, j, r], [alice.jid, Vines::Stanza::Archive::ResultSetManagment]
      end

      it 'response with list including 3 chat conversations' do
        subject.process
        storage.verify
        stream.verify
      end
    end
  end

  describe 'when request concrete archived collection' do
    describe 'when archive is empty' do
      let(:xml) { list(hatter.jid, max: 100) }
      let(:result) do
        node(%q{
          <iq from="wonderland.lit" id="42" to="alice@wonderland.lit/home" type="result">
            <list xmlns="urn:xmpp:archive"/>
          </iq>
        })
      end

      before do
        stream.expect :write, nil, [result]
        stream.expect :storage, storage, [stream.domain]

        storage.expect :find_with_collections, [], [alice.jid, hatter.jid, Vines::Stanza::Archive::ResultSetManagment]
      end

      it 'response with empty list result' do
        subject.process
        storage.verify
        stream.verify
      end
    end

    describe 'when archive has collections' do
      let(:xml) { list(hatter.jid, max: 100) }
      let(:result) do
        node(%q{
          <iq from="wonderland.lit" id="42" to="alice@wonderland.lit/home" type="result">
            <list xmlns="urn:xmpp:archive">
              <chat with="hatter@wonderland.lit" start="2013-02-12 09:44:12 UTC"/>

              <set xmlns="http://jabber.org/protocol/rsm">
                <first>hatter@wonderland.lit@2013-02-12 09:44:12 UTC</first>
                <last>hatter@wonderland.lit@2013-02-12 09:44:12 UTC</last>
                <count>1</count>
              </set>
            </list>
          </iq>
        })
      end

      before do
        stream.expect :write, nil, [result]
        stream.expect :storage, storage, [stream.domain]

        h = chat(jid_with: 'alice@wonderland.lit', jid_from: 'hatter@wonderland.lit', created_at: '2013-02-12 09:44:12 UTC')

        storage.expect :find_with_collections, [h], [alice.jid, hatter.jid, Vines::Stanza::Archive::ResultSetManagment]
      end

      it 'response with list including 1 chat conversation' do
        subject.process
        storage.verify
        stream.verify
      end
    end
  end

  private
  MockChat = Struct.new(:jid_with, :jid_from, :created_at)
  def chat(options)
    with, from, created_at = options.values_at(:jid_with, :jid_from, :created_at)

    MockChat.new(with, from, Time.parse(created_at))
  end

  def list(with, options = {})
    without_rsm = options.fetch(:without_rsm, false)

    rms_body = without_rsm ? '' : %Q{
      <set xmlns='http://jabber.org/protocol/rsm'>
        #{[:max, :after, :before].map { |v| options[v].nil? ? '' : "<#{v}>#{options[v]}</#{v}>" } * "\n"}
      </set>}

    body = %Q{
      <list xmlns='urn:xmpp:archive'#{with.nil? ? '' : " with='#{with}'"}>
        #{rms_body}
      </list>}

    iq(type: 'get', id: 42, body: body)
  end
end
