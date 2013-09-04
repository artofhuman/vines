# encoding: UTF-8

require 'test_helper'

describe Vines::Stanza::Archive::Retrieve do
  subject       { Vines::Stanza::Archive::Retrieve.new(xml, stream) }
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
      let(:xml) { retrieve(hatter.jid, '2013-02-12T09:44:12Z') }

      it 'raises an not-acceptable stanza error' do
        -> { subject.process }.must_raise Vines::StanzaErrors::NotAcceptable
        stream.verify
      end
    end

    describe 'when rsm not sended at all' do
      let(:xml) { retrieve(hatter.jid, '2013-02-12T09:44:12Z', without: [:rsm]) }

      it 'raises an bad-request stanza error' do
        -> { subject.process }.must_raise Vines::StanzaErrors::BadRequest
        stream.verify
      end
    end
  end

  describe 'when with or start attributes not setted properly' do
    describe 'when with not setted' do
      let(:xml) { retrieve(nil, '2013-02-12T09:44:12Z', max: 100) }

      it 'raises an bad-request stanza error' do
        -> { subject.process }.must_raise Vines::StanzaErrors::BadRequest
        stream.verify
      end
    end

    describe 'when start not setted' do
      let(:xml) { retrieve(hatter.jid, nil, max: 100) }

      it 'raises an bad-request stanza error' do
        -> { subject.process }.must_raise Vines::StanzaErrors::BadRequest
        stream.verify
      end
    end

    describe 'when start and with not setted' do
      let(:xml) { retrieve(nil, nil, max: 100) }

      it 'raises an bad-request stanza error' do
        -> { subject.process }.must_raise Vines::StanzaErrors::BadRequest
        stream.verify
      end
    end
  end

  describe 'when request not existed collection page' do
    let(:xml) { retrieve(hatter.jid, '2013-02-12T09:44:12Z', max: 100) }

    before do
      stream.expect :storage, storage, [stream.domain]

      rsm = Vines::Stanza::Rsm::Request.new('max' => 100)

      storage.expect :find_messages, [[], 0], [alice.jid, hatter.jid, {start: Time.parse('2013-02-12 09:44:12 UTC'), end: nil, rsm: rsm}]
    end

    it 'response with chat messages' do
      -> { subject.process }.must_raise Vines::StanzaErrors::ItemNotFound
      storage.verify
      stream.verify
    end
  end

  describe 'when request existing collection page' do
    let(:xml) { retrieve(hatter.jid, '2013-02-12T09:44:12Z', max: 100) }
    let(:result) do
      node(%q{
        <iq from="wonderland.lit" id="42" to="alice@wonderland.lit/home" type="result">
          <chat xmlns="urn:xmpp:archive" with="hatter@wonderland.lit" start="2013-02-12T09:44:12Z">
            <from secs="0"><body mid="1360662252">Hello</body></from>
            <to secs="8"><body mid="1360662260">Hi</body></to>
            <from secs="10"><body mid="1360662262">How a u?</body></from>
            <to secs="60"><body mid="1360662312">Fine</body></to>

            <set xmlns="http://jabber.org/protocol/rsm">
              <count>233</count>
              <first>11</first>
              <last>14</last>
            </set>
          </chat>
        </iq>
      })
    end

    before do
      stream.expect :write, nil, [result]
      stream.expect :storage, storage, [stream.domain]

      m1 = message(id: 11, jid: 'hatter@wonderland.lit', body: 'Hello', created_at: '2013-02-12 09:44:12 UTC')
      m2 = message(id: 12, jid: 'alice@wonderland.lit', body: 'Hi', created_at: '2013-02-12 09:44:20 UTC')
      m3 = message(id: 13, jid: 'hatter@wonderland.lit', body: 'How a u?', created_at: '2013-02-12 09:44:22 UTC')
      m4 = message(id: 14, jid: 'alice@wonderland.lit', body: 'Fine', created_at: '2013-02-12 09:45:12 UTC')

      rsm = Vines::Stanza::Rsm::Request.new('max' => 100)

      storage.expect :find_messages, [[m1, m2, m3, m4], 233], [alice.jid, hatter.jid, {start: Time.parse('2013-02-12 09:44:12 UTC'), end: nil, rsm: rsm}]
    end

    it 'response with chat messages' do
      subject.process
      storage.verify
      stream.verify
    end
  end

  describe 'when request existing collection page anded at time' do
    let(:xml) { retrieve(hatter.jid, '2013-02-12T09:44:12Z', end: '2013-02-12T09:44:20Z', max: 100) }
    let(:result) do
      node(%q{
        <iq from="wonderland.lit" id="42" to="alice@wonderland.lit/home" type="result">
          <chat xmlns="urn:xmpp:archive" with="hatter@wonderland.lit" start="2013-02-12T09:44:12Z">
            <from secs="0"><body mid="1360662252">Hello</body></from>
            <from secs="8"><body mid="1360662260">A u here?</body></from>

            <set xmlns="http://jabber.org/protocol/rsm">
              <count>15</count>
              <first>11</first>
              <last>12</last>
            </set>
          </chat>
        </iq>
      })
    end

    before do
      stream.expect :write, nil, [result]
      stream.expect :storage, storage, [stream.domain]

      m1 = message(id: 11, jid: 'hatter@wonderland.lit', body: 'Hello', created_at: '2013-02-12 09:44:12 UTC')
      m2 = message(id: 12, jid: 'hatter@wonderland.lit', body: 'A u here?', created_at: '2013-02-12 09:44:20 UTC')

      rsm = Vines::Stanza::Rsm::Request.new('max' => 100)

      storage.expect :find_messages, [[m1, m2], 15], [alice.jid, hatter.jid, {start: Time.parse('2013-02-12 09:44:12 UTC'), end: Time.parse('2013-02-12 09:44:20 UTC'), rsm: rsm}]
    end

    it 'response with chat messages' do
      subject.process
      storage.verify
      stream.verify
    end
  end

  private
  MockMessage = Struct.new(:id, :jid, :body, :created_at)
  def message(options)
    id, jid, body, created_at = options.values_at(:id, :jid, :body, :created_at)

    MockMessage.new(id, jid, body, Time.parse(created_at))
  end

  def retrieve(with, start, options = {})
    without = options.fetch(:without, [])

    rms_body = without.include?(:rsm) ? '' : %Q{
      <set xmlns='http://jabber.org/protocol/rsm'>
        #{[:max, :after, :before].map { |v| options[v].nil? ? '' : "<#{v}>#{options[v]}</#{v}>" } * "\n"}
      </set>}

    params = [
      start.nil? ? nil : "start='#{start}'",
      with.nil? ? nil : "with='#{with}'",
      options[:end].nil? ? nil : "end='#{options[:end]}'"
    ].compact * ' '
    body = %Q{
      <retrieve xmlns='urn:xmpp:archive'#{params.nil? ? '' : " #{params}"}>
        #{rms_body}
      </retrieve>}

    iq(type: 'get', id: 42, body: body)
  end
end
