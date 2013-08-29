# encoding: UTF-8

require 'test_helper'

describe Vines::Stanza::Archive::ResultSetManagment do
  describe '#from_node' do
    subject { Vines::Stanza::Archive::ResultSetManagment.from_node(xml) }

    describe 'when node is valid first page request' do
      let(:xml) do
        node(%q{
          <set xmlns='http://jabber.org/protocol/rsm'>
            <max>100</max>
          </set>
        })
      end

      it { subject.max.must_equal 100 }
      it { subject.count.must_be_nil }
      it { subject.after.must_be_nil }
      it { subject.before.must_be_nil }
      it { subject.first.must_be_nil }
      it { subject.last.must_be_nil }
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
      it { subject.count.must_be_nil }
      it { subject.before.must_be_nil }
      it { subject.first.must_be_nil }
      it { subject.last.must_be_nil }
    end

    describe 'when node is invalid' do
      let(:xml) do
        node(%q{
          <set xmlns='http://jabber.org/protocol/rsm'></set>
        })
      end

      it { subject.max.must_be_nil }
      it { subject.after.must_be_nil }
      it { subject.count.must_be_nil }
      it { subject.before.must_be_nil }
      it { subject.first.must_be_nil }
      it { subject.last.must_be_nil }
    end
  end

  describe '#to_response_xml' do
    it 'equal first page response' do
      options = {'count' => 42, 'first' => 'alice@wonderland.lit', 'last' => 'hatter@wonderland.lit'}
      expected = node(%q{
        <set xmlns='http://jabber.org/protocol/rsm'>
          <first>alice@wonderland.lit</first>
          <last>hatter@wonderland.lit</last>
          <count>42</count>
        </set>
      })

      Vines::Stanza::Archive::ResultSetManagment.new(options).to_response_xml.must_equal expected
    end

    it 'equal invalid RSM response' do
      options = {'count' => 42}
      expected = node(%q{
        <set xmlns='http://jabber.org/protocol/rsm'>
          <first/>
          <last/>
          <count>42</count>
        </set>
      })

      Vines::Stanza::Archive::ResultSetManagment.new(options).to_response_xml.must_equal expected
    end
  end

  describe '#to_request_xml' do
    it 'equal 10 elements request' do
      options = {'max' => 10}
      expected = node(%q{
        <set xmlns='http://jabber.org/protocol/rsm'>
          <max>10</first>
        </set>
      })

      Vines::Stanza::Archive::ResultSetManagment.new(options).to_request_xml.must_equal expected
    end

    it 'equal next 10 elements request' do
      options = {'max' => 10, 'after' => '1469-07-21T03:16:37Zalice@wonderland.lit'}
      expected = node(%q{
        <set xmlns='http://jabber.org/protocol/rsm'>
          <max>10</first>
          <after>1469-07-21T03:16:37Zalice@wonderland.lit</after>
        </set>
      })

      Vines::Stanza::Archive::ResultSetManagment.new(options).to_request_xml.must_equal expected
    end

    it 'equal last 10 elements request' do
      options = {'max' => 10, 'before' => ''}
      expected = node(%q{
        <set xmlns='http://jabber.org/protocol/rsm'>
          <max>10</first>
          <before/>
        </set>
      })

      Vines::Stanza::Archive::ResultSetManagment.new(options).to_request_xml.must_equal expected
    end
  end
end
