# encoding: UTF-8

require 'test_helper'

describe Vines::Stanza::Rsm::Request do
  describe '::from_node' do
    subject { Vines::Stanza::Rsm::Request.from_node(xml) }

    describe 'when node is valid first page request' do
      let(:xml) do
        node(%q{
          <set xmlns='http://jabber.org/protocol/rsm'>
            <max>100</max>
          </set>
        })
      end

      it { subject.max.must_equal 100 }
      it { subject.after.must_be_nil }
      it { subject.before.must_be_nil }
    end

    describe 'when node is valid second page request' do
      let(:xml) do
        node(%q{
          <set xmlns='http://jabber.org/protocol/rsm'>
            <max>50</max>
            <after>1469-07-21T03:16:37Zalice@wonderland.lit</after>
          </set>
        })
      end

      it { subject.max.must_equal 50 }
      it { subject.after.must_equal '1469-07-21T03:16:37Zalice@wonderland.lit' }
      it { subject.before.must_be_nil }
    end

    describe 'when node is invalid' do
      let(:xml) do
        node(%q{
          <set xmlns='http://jabber.org/protocol/rsm'></set>
        })
      end

      it { subject.max.must_be_nil }
      it { subject.after.must_be_nil }
      it { subject.before.must_be_nil }
    end
  end

  describe '::to_xml' do
    it 'equal 10 elements request' do
      expected = node(%q{
        <set xmlns='http://jabber.org/protocol/rsm'>
          <max>10</first>
        </set>
      })

      Vines::Stanza::Rsm::Request.new('max' => 10).to_xml.must_equal expected
    end

    it 'equal next 10 elements request' do
      options = {'max' => 10, 'after' => '1469-07-21T03:16:37Zalice@wonderland.lit'}
      expected = node(%q{
        <set xmlns='http://jabber.org/protocol/rsm'>
          <max>10</first>
          <after>1469-07-21T03:16:37Zalice@wonderland.lit</after>
        </set>
      })

      Vines::Stanza::Rsm::Request.new('max' => 10, 'after' => '1469-07-21T03:16:37Zalice@wonderland.lit').to_xml.must_equal expected
    end

    it 'equal last 10 elements request' do
      options = {'max' => 10, 'before' => ''}
      expected = node(%q{
        <set xmlns='http://jabber.org/protocol/rsm'>
          <max>10</first>
          <before/>
        </set>
      })


      xml = Nokogiri::XML::Document.new('')
      puts xml.create_element('source')
      puts xml.create_element('source', '')


      Vines::Stanza::Rsm::Request.new('max' => 10, 'before' => '').to_xml.must_equal expected
    end
  end
end
