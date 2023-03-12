module Searcher::Operation
  class Search < Trailblazer::Operation
    step :parse_query
    step :define_terms
    step :search
    step :order_by_relevance

    # It parses the query and returns an array of terms
    # For example, "ruby -java" will return ["ruby", "-java"]
    # "Python -'dynamic language'" will return ["Python", "-dynamic language"] (same with double quotes)
    def parse_query(ctx, query: '', **)
      ctx[:terms] = query.to_s.downcase
                         .scan(/-"[^"]+"|-'[^']+'|\S+/)
                         .map { |s| s.gsub(/["']/, '') }
    end

    # It separates terms into positive and negative ones
    # For example, ["ruby", "-java"] will return [["-java"], ["ruby"]]
    def define_terms(ctx, terms:, **)
      ctx[:negative_terms], ctx[:positive_terms] = terms.partition do |term|
        term.start_with?('-')
      end.map(&:compact)
    end

    # It searches for matching data
    # It returns all data if no terms are provided
    # It returns matching data when positive terms are provided
    def search(ctx, data:, positive_terms:, negative_terms:, **)
      return ctx[:results] = data if positive_terms.empty? && negative_terms.empty?

      ctx[:results] = data.select do |language|
        SubSearch.wtf?(language:, positive_terms:, negative_terms:).success?
      end
    end

    # It sorts the results by relevance
    # It returns unsorted results if no positive terms are provided
    # Exact matching terms are 10x more relevant than partial matching ones
    # "Name" key has 50^2 mutiplier
    # "Description" key has 50^1 multiplier
    # "Designed by" key has 50^0 multiplier
    def order_by_relevance(ctx, results:, positive_terms:, **)
      return ctx[:results] if positive_terms.empty?

      ctx[:results] = results.sort_by do |language|
        language.values.reverse.map.with_index do |value, index|
          50**index * (count_exact_matching(value, positive_terms) * 10 + count_partial_matching(value, positive_terms))
        end.sum
      end.reverse
    end

    private

    # Exact matching means that the term is surrounded by spaces or commas or start/end of the string
    def count_exact_matching(field, positive_terms)
      regex = Regexp.new(/(^|[\s,])(#{positive_terms.join('|')})([\s,]|$)/i)
      field.downcase.split.count { |value| value.match?(regex) }
    end

    # Partial matching means that the term starts with spaces or commas or minus or at the beginning of the string
    def count_partial_matching(field, positive_terms)
      regex = Regexp.new(/(^|[\s,-])(#{positive_terms.join('|')})/i)
      field.downcase.split.count { |value| value.match?(regex) }
    end
  end

  # It checks if the language matches the terms
  class SubSearch < Trailblazer::Operation
    step :right_language?

    # It returns true if no terms are provided
    # It returns true if positive terms are provided and the language matches them
    # It returns false if negative terms are provided and the language matches them
    def right_language?(ctx, language:, positive_terms:, negative_terms:, **)
      conclusion = true

      unless positive_terms.empty?
        positive_inclusion = positive_terms.all? { |term| check_term_inclusion(language, term) }
        conclusion &&= positive_inclusion
      end

      unless negative_terms.empty?
        negative_inclusion = negative_terms.any? { |term| check_term_inclusion(language, term) }
        conclusion &&= !negative_inclusion
      end

      conclusion
    end

    private

    # It checks if the language matches particular term
    def check_term_inclusion(language, term)
      language.values.any? do |value|
        value.downcase.include?(term.sub(/\A-/, ''))
      end
    end
  end
end
