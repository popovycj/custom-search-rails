module Searcher::Operation
  class Search < Trailblazer::Operation
    step :parse_query
    step :define_terms
    step :search
    step :order_by_relevance

    def parse_query(ctx, query: '', **)
      ctx[:terms] = query.to_s.downcase
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
        SubSearch.wtf?(language:, positive_terms:, negative_terms:).success?
      end
    end

    def order_by_relevance(ctx, results:, positive_terms:, **)
      return ctx[:results] if positive_terms.empty?

      ctx[:results] = results.sort_by do |language|
        language.values.reverse.map.with_index do |value, index|
          50**index * (count_exact_matching(value, positive_terms) * 10 + count_partial_matching(value, positive_terms))
        end.sum
      end.reverse
    end

    private

    def count_exact_matching(field, positive_terms)
      regex = Regexp.new(/(^|[\s,])(#{positive_terms.join('|')})([\s,]|$)/i)
      field.downcase.split.count { |value| value.match?(regex) }
    end

    def count_partial_matching(field, positive_terms)
      regex = Regexp.new(/(^|[\s,-])(#{positive_terms.join('|')})/i)
      field.downcase.split.count { |value| value.match?(regex) }
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
