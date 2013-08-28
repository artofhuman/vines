# encoding: UTF-8

require 'test_helper'

describe Vines::Stanza::Archive::List do
  subject      { Vines::Stanza::Archive::List.new(xml, stream) }
  let(:stream) { MiniTest::Mock.new }
  let(:storage) { MiniTest::Mock.new }
  let(:alice)  { Vines::User.new(jid: 'alice@wonderland.lit/home') }
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

  describe 'when rsm option not setted' do
    let(:xml) { create(hatter.jid) }

    it 'raises an not-acceptable stanza error' do
      -> { subject.process }.must_raise Vines::StanzaErrors::NotAcceptable
      stream.verify
    end
  end

  describe 'when request all archived collections' do
    describe 'when archive is empty' do
      let(:xml) { create(nil, max: 100) }
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
    end
  end

  describe 'when request concrete archived collection' do
    describe 'when archive is empty' do
      let(:xml) { create(hatter.jid, max: 100) }
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

        storage.expect :find_collection, [], [alice.jid, hatter.jid, Vines::Stanza::Archive::ResultSetManagment]
      end

      it 'response with empty list result' do
        subject.process
        storage.verify
        stream.verify
      end
    end

    describe 'when archive has collections' do
    end
  end

  private
  def create(with, rsm = {})
    r_max, r_after, r_before = rsm.values_at(:max, :after, :before)

    m = r_max.nil? ? '' : "<max>#{r_max}</max>"
    a = r_after.nil? ? '' : "<after>#{r_after}</after>"
    b = r_before.nil? ? '' : "<before>#{r_before}</before>"
    rms_body = %Q{
      <set xmlns='http://jabber.org/protocol/rsm'>
        #{m}#{a}#{b}
      </set>}

    w = with.nil? ? '' : " with='#{with}'"
    body = %Q{
      <list xmlns='urn:xmpp:archive'#{w}>
        #{rms_body}
      </list>}

    iq(type: 'get', id: 42, body: body)
  end
end
