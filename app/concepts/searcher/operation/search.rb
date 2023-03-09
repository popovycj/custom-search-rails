module Searcher::Operation
  class Search < Trailblazer::Operation
    step :parse_query
    step :define_terms
    step :search
    step :order_by_relevance

    def parse_query(ctx, query: '', **)
      ctx[:terms] = query.downcase
                         .scan(/"[^"]+"|'[^']+'|\S+/)
                         .map { |s| s.gsub(/["']/, '') }
    end

    def define_terms(ctx, terms:, **)
      ctx[:negative_terms], ctx[:positive_terms] = terms.partition do |term|
        term.start_with?('-')
      end.map(&:compact)
    end

    def search(ctx, data:, positive_terms:, negative_terms:, **)
      return ctx[:results] = data if positive_terms.empty? && negative_terms.empty?

      ctx[:results] = data.select do |language|
        SubSearch.call(language:, positive_terms:, negative_terms:).success?
      end
    end

    def order_by_relevance(ctx, results:, positive_terms:, **)
      ctx[:results] = results.sort_by do |language|
        count_exact_matching(language, positive_terms)
      end.reverse
    end

    private

    def count_exact_matching(language, positive_terms)
      positive_terms.map do |term|
        language.values.any? do |value|
          value.downcase.match?(/(^|[\s,])#{term}([\s,]|$)/i)
        end
      end.count(true)
    end
  end

  class SubSearch < Trailblazer::Operation
    step :right_language?

    def right_language?(ctx, language:, positive_terms:, negative_terms:, **)
      conclusion = true

      conclusion &&= check_language(language, positive_terms) unless positive_terms.empty?
      conclusion &&= !check_language(language, negative_terms) unless negative_terms.empty?

      conclusion
    end

    private

    def check_language(language, terms)
      terms.all? do |term|
        language.values.any? do |value|
          value.downcase.include?(term.sub(/\A-/, ''))
        end
      end
    end
  end
end
