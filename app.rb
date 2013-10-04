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

  helpers do
    def js_array(name, array)   

    end
  end

  def add_custom_patterns_from_string(text)
    text.each_line do |line|
      # Skip comments
      next if line =~ /^\s*#/ 
      # File format is: NAME ' '+ PATTERN '\n'
      name, pattern = line.gsub(/^\s*/, "").split(/\s+/, 2)
      #p name => pattern
      # If the line is malformed, skip it.
      next if pattern.nil?
      # Trim newline and add the pattern.
      grok.add_pattern(name, pattern.chomp)
      end
  end

  set :public_folder, File.dirname(__FILE__) + '/public'
  post '/grok' do
    custom_patterns = params[:custom_patterns]    
    input = params[:input]
    pattern = params[:pattern]
    named_captures_only = (params[:named_captures_only] == "true")
    singles = (params[:singles] == "true")
    keep_empty_captures = (params[:keep_empty_captures] == "true")
    
    if !custom_patterns.empty?
      add_custom_patterns_from_string(custom_patterns)
    end 
    
    begin
      grok.compile(params[:pattern])          
    rescue 
      return "Compile ERROR"
    end

    matches = grok.match(params[:input])
    return "No Matches" if !matches

    fields = {}
    matches.captures.each do |key, value|
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
    custom_patterns = params[:custom_patterns]    
    if !custom_patterns.empty?
      add_custom_patterns_from_string(custom_patterns)
    end 
    
    discovered = grok.discover(params[:input])
    print "#{discovered}"
    discovered
  end
  
  get '/' do
    @tags = []
    grok.patterns.each do |x,y|
        @tags << "%{#{x}"        
    end
    haml :'index'
  end
  
  get '/discover' do
    haml :'discover'
  end

  get '/patterns' do
    @arr = get_files("./public/patterns/")
    haml :'patterns'
  end
  get '/patterns/*' do
    send_file(params[:spat]) unless params[:spat].nil?
  end
end
