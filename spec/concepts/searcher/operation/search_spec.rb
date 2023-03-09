require 'rails_helper'

RSpec.describe Searcher::Operation::Search do
  let!(:data) { JSON.parse(File.read(Rails.root.join('public', 'data.json'))) }

  describe 'exact matches' do
    context 'with quotes query' do
      let!(:query) { 'Interpreted "Thomas Eugene"' }
      subject(:search) { described_class.wtf?(query: query, data: data) }

      it 'returns "BASIC" but not "Haskell"' do
        expect_languages_to_include(search, ['BASIC'])
        expect_languages_to_exclude(search, ['Haskell'])
      end
    end
  end

  describe 'match in different fields' do
    context 'when searching for "Scripting Microsoft"' do
      let!(:query) { 'Scripting Microsoft' }
      subject(:search) { described_class.wtf?(query: query, data: data) }

      it 'returns all scripting languages designed by "Microsoft"' do
        expect_languages_to_include(search, ['VBScript', 'JScript'])
      end
    end
  end

  describe 'negative searches' do
    context 'when searching for "john -array"' do
      let!(:query) { 'john -array' }
      subject(:search) { described_class.wtf?(query: query, data: data) }

      it 'matches "BASIC", "Haskell", "Lisp" and "S-Lang", but not "Chapel", "Fortran"' do
        expect_languages_to_include(search, ['BASIC', 'Haskell', 'Lisp', 'S-Lang'])
        expect_languages_to_exclude(search, ['Chapel', 'Fortran'])
      end
    end
  end

  describe 'match inverse order' do
    context 'when searching for "Lisp Common"' do
      let!(:query) { 'Lisp Common' }
      subject(:search) { described_class.wtf?(query: query, data: data) }

      it 'returns "Common Lisp" as a result' do
        expect_languages_to_include(search, ['Common Lisp'])
      end
    end
  end

  describe 'check relevance order' do
    context 'when searching for "Java"' do
      let!(:data) { [
        { 'Name' => 'Java', 'Designed by' => 'James Gosling' },
        { 'Name' => 'JavaScript', 'Designed by' => 'Brendan Eich' }
      ] }
      let!(:query) { 'Java' }
      subject(:search) { described_class.wtf?(query: query, data: data) }

      it 'returns results list with "Java" as first element' do
        expect_languages_to_include(search, ['Java', 'JavaScript'])

        expect(search[:results].first).to include('Name' => 'Java')
      end
    end

    context 'when searching for "C"' do
      let!(:data) { [
        { 'Name' => 'C++', 'Designed by' => 'Bjarne Stroustrup' },
        { 'Name' => 'C', 'Designed by' => 'Dennis Ritchie' },
        { 'Name' => 'C#', 'Designed by' => 'Anders Hejlsberg' }
      ] }
      let!(:query) { 'C' }
      subject(:search) { described_class.wtf?(query: query, data: data) }

      it 'returns results list with "C" as first element' do
        expect_languages_to_include(search, ['C', 'C++', 'C#'])

        expect(search[:results].first).to include('Name' => 'C')
      end
    end

    context 'when searching for "John"' do
      let!(:data) { [
        { "Name" => "S-Lang", "Designed by" => "Mark E. Johns" },
        { "Name" => "S", "Designed by" => "Rick Becker, Allan Wilks, John Chambers" },
        { 'Name' => 'Java', 'Designed by' => 'James Gosling' }
      ] }
      let!(:query) { 'John' }
      subject(:search) { described_class.wtf?(query: query, data: data) }

      it 'returns results list with "S" as first element' do
        expect_languages_to_include(search, ['S', 'S-Lang'])
        expect_languages_to_exclude(search, ['Java'])

        expect(search[:results].first).to include('Name' => 'S')
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
