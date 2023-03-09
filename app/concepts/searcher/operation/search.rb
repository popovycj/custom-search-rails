module Searcher::Operation
  class Search < Trailblazer::Operation
    step :parse_query
    step :search

    def parse_query(ctx, params:, **)
      ctx[:terms] = params[:query].downcase
                                  .scan(/"[^"]+"|'[^']+'|\S+/)
                                  .map { |s| s.gsub(/["']/, '') }
    end

    def search(ctx, data:, terms:, **)
      return ctx[:results] = data if terms.empty?

      ctx[:results] = data.select do |language|
        SubSearch.call(language:, terms:).success?
      end
    end
  end

  class SubSearch < Trailblazer::Operation
    step :define_terms
    step :right_language?

    def define_terms(ctx, terms:, **)
      ctx[:negative_terms], ctx[:positive_terms] = terms.partition do |term|
        term.start_with?('-')
      end.map(&:compact)
    end

    def right_language?(ctx, language:, positive_terms:, negative_terms:, **)
      check_language(language, positive_terms) && !check_language(language, negative_terms)
    end

    private

    def check_language(language, terms)
      return false if terms.empty?

      terms.all? do |term|
        language.values.any? do |value|
          value.downcase.include?(term.sub(/\A-/, ''))
        end
      end
    end
  end
end
