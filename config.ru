require 'rubygems'
require 'bundler'

Bundler.require

require 'sinatra'
path = File.expand_path("../", __FILE__)
require "#{path}/app"

run Application
