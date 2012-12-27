require 'sinatra'
require 'grok-pure'
require 'json'
require 'find'

class Application < Sinatra::Base
  
  def grok
    if @grok.nil?
      @grok = Grok.new

      Dir.foreach('./public/patterns/') do |item|
        next if item == '.' or item == '..' or item == '.git'
        @grok.add_patterns_from_file(("./public/patterns/#{item}"))
      end
    end
    @grok
  end

  def get_files path
    dir_array = Array.new
      Find.find(path) do |f|
        if !File.directory?(f)
            #dir_array << f if !File.directory?.basename(f) # add only non-directories  
          dir_array << File.basename(f, ".*")
        end
      end
      return dir_array
  end 

  set :public_folder, File.dirname(__FILE__) + '/public'
  post '/grok' do
    input = params[:input]
    pattern = params[:pattern]
    named_captures_only = (params[:named_captures_only] == "true")
    singles = (params[:singles] == "true")
    keep_empty_captures = (params[:keep_empty_captures] == "true")

    begin
      grok.compile(params[:pattern])
    rescue 
      return "Compile ERROR"
    end

    match = grok.match(params[:input])
    return "No Matches" if !match

    fields = {}
    match.captures.each do |key, value|
      type_coerce = nil
      is_named = false
      if key.include?(":")
         name, key, type_coerce = key.split(":")
         is_named = true
      end

      case type_coerce
        when "int"
          value = value.to_i rescue nil
        when "float"
          value = value.to_f rescue nil
      end

      if named_captures_only && !is_named
        next
      end

      if fields[key].is_a?(String)
        fields[key] = [fields[key]]
      end

      if keep_empty_captures && fields[key].nil?
        fields[key] = []
      end

      # If value is not nil, or responds to empty and is not empty, add the
      # value to the event.
      if !value.nil? && (!value.empty? rescue true)
        # Store fields as an array unless otherwise instructed with the
        # 'singles' config option
        if !fields.include?(key) and singles
          fields[key] = value
        else
          fields[key] ||= []
          fields[key] << value
        end
      end
    end

    if fields
    #pp match.captures
      return JSON.pretty_generate(fields)
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

  get '/patterns' do
    @arr = get_files("./public/patterns/")
    erb :'patterns'
  end
  get '/patterns/*' do
    send_file(params[:spat])
  end
end
