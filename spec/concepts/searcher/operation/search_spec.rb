require 'rails_helper'

RSpec.describe Searcher::Operation::Search do
  describe 'test assignment cases' do
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

    describe 'match inverse terms order' do
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
  end

  describe 'general cases' do
    let!(:data) do
      [
        { name: 'Ruby', description: 'A dynamic, open source programming language' },
        { name: 'Python', description: 'A high-level, interpreted programming language' },
        { name: 'Java', description: 'A class-based, object-oriented programming language' }
      ]
    end
    let!(:ctx) { { data: data } }

    describe '#parse_query' do
      it 'downcases the query string and splits it into terms' do
        ctx[:query] = 'Ruby On Rails'

        result = described_class.(ctx)

        expect(result[:terms]).to eq(['ruby', 'on', 'rails'])
      end
    end

    describe '#define_terms' do
      it 'separates positive and negative terms' do
        ctx[:query] = 'ruby -java'

        result = described_class.(ctx)

        expect(result[:positive_terms]).to eq(['ruby'])
        expect(result[:negative_terms]).to eq(['-java'])
      end
    end

    describe '#search' do
      it 'returns all data if no query are provided' do
        result = described_class.(ctx)

        expect(result[:results]).to eq(data)
      end

      it 'returns matching data when positive terms are provided' do
        ctx[:query] = 'ruby'

        result = described_class.(ctx)

        expect(result[:results]).to eq([{ name: 'Ruby', description: 'A dynamic, open source programming language' }])
      end

      it 'does not return data with negative terms' do
        ctx[:query] = '-java'

        result = described_class.(ctx)

        expect(result[:results]).to eq([{ name: 'Ruby', description: 'A dynamic, open source programming language' }, { name: 'Python', description: 'A high-level, interpreted programming language' }])
      end

      it 'returns matching data when both positive and negative terms are provided' do
        ctx[:query] = 'ruby -java'

        result = described_class.(ctx)

        expect(result[:results]).to eq([{ name: 'Ruby', description: 'A dynamic, open source programming language' }])
      end
    end

    describe '#order_by_relevance' do
      it 'returns unsorted results if no positive terms are provided' do
        ctx[:query] = ''

        result = described_class.(ctx)

        expect(result[:results]).to eq(data)
      end
    end
  end
end

RSpec.describe Searcher::Operation::SubSearch do
  subject(:operation) { described_class }

  describe '#right_language?' do
    let(:language) do
      {
        name: 'Ruby',
        category: 'Programming language',
        date_created: '1995'
      }
    end

    context 'when both positive_terms and negative_terms are empty' do
      it 'returns true' do
        result = operation.call(language: language, positive_terms: [], negative_terms: [])

        expect(result.success?).to be_truthy
      end
    end

    context 'when positive_terms are present' do
      let(:positive_terms) { ['ruby', 'programming'] }

      context 'when language includes all positive terms' do
        it 'returns true' do
          result = operation.call(language: language, positive_terms: positive_terms, negative_terms: [])

          expect(result.success?).to be_truthy
        end
      end

      context 'when language does not include all positive terms' do
        let(:positive_terms) { ['ruby', 'programming', 'java'] }

        it 'returns false' do
          result = operation.call(language: language, positive_terms: positive_terms, negative_terms: [])

          expect(result.success?).to be_falsey
        end
      end

      context 'when language includes some positive terms and some negative terms' do
        let(:positive_terms) { ['ruby', 'programming'] }
        let(:negative_terms) { ['java'] }

        it 'returns true' do
          result = operation.call(language: language, positive_terms: positive_terms, negative_terms: negative_terms)

          expect(result.success?).to be_truthy
        end
      end
    end

    context 'when negative_terms are present' do
      let(:negative_terms) { ['java', 'php'] }

      context 'when language includes none of the negative terms' do
        it 'returns true' do
          result = operation.call(language: language, positive_terms: [], negative_terms: negative_terms)

          expect(result.success?).to be_truthy
        end
      end

      context 'when language includes some of the negative terms' do
        let(:negative_terms) { ['ruby'] }

        it 'returns false' do
          result = operation.call(language: language, positive_terms: [], negative_terms: negative_terms)

          expect(result.success?).to be_falsey
        end
      end
    end
  end
end
