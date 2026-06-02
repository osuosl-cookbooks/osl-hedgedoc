require_relative '../../spec_helper'
require_relative '../../../libraries/helpers'

RSpec.describe OSLHedgedoc::Cookbook::Helpers do
  let(:dummy_class) do
    Class.new { include OSLHedgedoc::Cookbook::Helpers }
  end

  subject { dummy_class.new }

  describe '#hedgedoc_base_dir' do
    it 'namespaces each instance under /data/hedgedoc' do
      expect(subject.hedgedoc_base_dir('pad.example.org')).to eq('/data/hedgedoc/pad.example.org')
    end
  end

  describe '#hedgedoc_instance' do
    it 'sanitizes a domain into a Compose/firewall-safe identifier' do
      expect(subject.hedgedoc_instance('Pad.Example.org')).to eq('pad-example-org')
    end

    it 'strips leading and trailing separators' do
      expect(subject.hedgedoc_instance('_pad_')).to eq('pad')
    end
  end

  describe '#hedgedoc_db_port' do
    it { expect(subject.hedgedoc_db_port('postgres')).to eq(5432) }
    it { expect(subject.hedgedoc_db_port('mysql')).to eq(3306) }
  end

  describe '#hedgedoc_db_url' do
    it 'builds a postgres connection string' do
      expect(
        subject.hedgedoc_db_url(
          dialect: 'postgres', user: 'u', password: 'p', host: 'db', port: 5432, name: 'hedgedoc'
        )
      ).to eq('postgres://u:p@db:5432/hedgedoc')
    end

    it 'builds a mysql connection string' do
      expect(
        subject.hedgedoc_db_url(
          dialect: 'mysql', user: 'u', password: 'p', host: 'db', port: 3306, name: 'hedgedoc'
        )
      ).to eq('mysql://u:p@db:3306/hedgedoc')
    end
  end
end
