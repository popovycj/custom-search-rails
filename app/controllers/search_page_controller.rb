class SearchPageController < ApplicationController
  def index
    data = Rails.cache.fetch('data') do
      JSON.parse(File.read(Rails.root.join('public', 'data.json')))
    end

    @results = Searcher::Operation::Search.wtf?(query: params[:query], data:)[:results]

    respond_to do |format|
      format.html
      format.json { render json: @results }
    end
  end
end
