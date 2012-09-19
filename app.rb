require 'sinatra'
require 'grok-pure'
require 'json'
require 'newrelic_rpm'

class Application < Sinatra::Base
  
  def grok
    if @grok.nil?
      @grok = Grok.new

      Dir.foreach('./patterns/') do |item|
        next if item == '.' or item == '..' or item == '.git'
        @grok.add_patterns_from_file("./patterns/#{item}")
      end
    end
    @grok
  end
  post '/grok' do
    input = params[:input]
    pattern = params[:pattern]

    begin
      grok.compile(params[:pattern])
    rescue 
      return "Compile ERROR"
    end

    match = grok.match(params[:input])

    if match
    #pp match.captures
      return JSON.pretty_generate(match.captures)
    end

    return "No Matches"
  end

  post '/discover' do
    grok.discover(params[:input])
  end
  
  get '/' do
    erb :'index'
  end
  
  get '/discover' do
    erb :'discover'
  end
end
