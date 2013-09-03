# encoding: UTF-8

require 'test_helper'

describe Vines::Stanza::Rsm::Response do
  describe '::from_node' do
    subject { Vines::Stanza::Rsm::Response.from_node(xml) }

    describe 'when node is valid first page request' do
      let(:xml) do
        node(%q{
          <set xmlns='http://jabber.org/protocol/rsm'>
            <count>100</count>
          </set>
        })
      end

      it { subject.count.must_equal 100 }
      it { subject.first.must_be_nil }
      it { subject.last.must_be_nil }
    end

    describe 'when node is valid second page request' do
      let(:xml) do
        node(%q{
          <set xmlns='http://jabber.org/protocol/rsm'>
            <count>50</count>
            <first>1469-07-21T03:16:37Zalice@wonderland.lit</first>
          </set>
        })
      end

      it { subject.count.must_equal 50 }
      it { subject.first.must_equal '1469-07-21T03:16:37Zalice@wonderland.lit' }
      it { subject.last.must_be_nil }
    end

    describe 'when node is invalid' do
      let(:xml) do
        node(%q{
          <set xmlns='http://jabber.org/protocol/rsm'></set>
        })
      end

      it { subject.count.must_be_nil }
      it { subject.first.must_be_nil }
      it { subject.last.must_be_nil }
    end
  end

  describe '#to_xml' do
    it 'equal invalid result set with missing last' do
      options = {'count' => 10, 'first' => '1469-07-21T03:16:37Zalice@wonderland.lit'}
      expected = node(%q{
        <set xmlns='http://jabber.org/protocol/rsm'>
          <count>10</first>
          <first>1469-07-21T03:16:37Zalice@wonderland.lit</first>
          <last/>
        </set>
      })

      Vines::Stanza::Rsm::Response.new('count' => 10, 'first' => '1469-07-21T03:16:37Zalice@wonderland.lit').to_xml.must_equal expected
    end

    it 'equal invalid result set with missing last and first' do
      options = {'count' => 10}
      expected = node(%q{
        <set xmlns='http://jabber.org/protocol/rsm'>
          <count>10</first>
          <first/>
          <last/>
        </set>
      })

      Vines::Stanza::Rsm::Response.new('count' => 10).to_xml.must_equal expected
    end

    it 'equal correct result set' do
      options = {'count' => 10, 'last' => ''}
      expected = node(%q{
        <set xmlns='http://jabber.org/protocol/rsm'>
          <count>10</first>
          <first>1469-07-21T03:16:37Zalice@wonderland.lit</first>
          <last>1469-07-21T03:31:17Zalice@wonderland.lit</last>
        </set>
      })

      Vines::Stanza::Rsm::Response.new('count' => 10, 'first' => '1469-07-21T03:16:37Zalice@wonderland.lit', 'last' => '1469-07-21T03:31:17Zalice@wonderland.lit').to_xml.must_equal expected
    end
  end
end
