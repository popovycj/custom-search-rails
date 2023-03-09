require 'rails_helper'

RSpec.describe Searcher::Operation::Search do
  let!(:data) { JSON.parse(File.read(Rails.root.join('public', 'data.json'))) }

  describe 'exact matches' do
    context 'with quotes query' do
      let!(:params) { { query: 'Interpreted "Thomas Eugene"' } }
      subject(:search) { described_class.wtf?(params: params, data: data) }

      it 'returns "BASIC" but not "Haskell"' do
        expect_languages_to_include(search, ['BASIC'])
        expect_languages_to_exclude(search, ['Haskell'])
      end
    end
  end

  describe 'match in different fields' do
    context 'when searching for "Scripting Microsoft"' do
      let!(:params) { { query: 'Scripting Microsoft' } }
      subject(:search) { described_class.wtf?(params: params, data: data) }

      it 'returns all scripting languages designed by "Microsoft"' do
        expect_languages_to_include(search, ['VBScript', 'JScript'])
      end
    end
  end

  describe 'negative searches' do
    context 'when searching for "john -array"' do
      let!(:params) { { query: 'john -array' } }
      subject(:search) { described_class.wtf?(params: params, data: data) }

      it 'matches "BASIC", "Haskell", "Lisp" and "S-Lang", but not "Chapel", "Fortran"' do
        expect_languages_to_include(search, ['BASIC', 'Haskell', 'Lisp', 'S-Lang'])
        expect_languages_to_exclude(search, ['Chapel', 'Fortran'])
      end
    end
  end

  describe 'match inverse order' do
    context 'when searching for "Lisp Common"' do
      let!(:params) { { query: 'Lisp Common' } }
      subject(:search) { described_class.wtf?(params: params, data: data) }

      it 'returns "Common Lisp" as a result' do
        expect_languages_to_include(search, ['Common Lisp'])
      end
    end
  end

  private

  def expect_languages_to_include(search, languages)
    languages.each do |language|
      expect(search[:results].any? { |result| result['Name'].include? language }).to be_truthy
    end
  end

  def expect_languages_to_exclude(search, languages)
    languages.each do |language|
      expect(search[:results].any? { |result| result['Name'].include? language }).to be_falsey
    end
  end
end
