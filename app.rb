# encoding: utf-8
require 'sinatra'
require 'json'
require 'redis'
require 'dotenv'
require 'httparty'

module Acadia
  class Server < Sinatra::Application
    configure do
      # Load .env vars
      Dotenv.load
      # Disable output buffering
      $stdout.sync = true
      
      # Set up redis
      case settings.environment
      when :development
        uri = URI.parse(ENV['LOCAL_REDIS_URL'])
      when :production
        uri = URI.parse(ENV['REDISCLOUD_URL'])
      end
      $redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
    end

    get '/' do
      latest_result = $redis.get('latest_result')
      if latest_result.nil?
        status 404
        body ''
      else
        status 200
        body latest_result
      end
    end
  end

  class WPT
    def initialize
      Dotenv.load
      @url = ENV['TEST_URL']
      @key = ENV['WPT_API_KEY']

      if ENV['REDISCLOUD_URL'].nil?
        uri = URI.parse(ENV['LOCAL_REDIS_URL'])
      else
        uri = URI.parse(ENV['REDISCLOUD_URL'])
      end
      $redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
    end

    def run_test
      url = "http://www.webpagetest.org/runtest.php?url=#{@url}&k=#{@key}&f=json"
      request = HTTParty.get(url)
      response = JSON.parse(request.body)
      if response['statusCode'] == 200
        puts "WPT test requested: #{response['data']['userUrl']}"
        $redis.set('latest_test', response['data']['jsonUrl'])
      end
    end

    def get_test
      latest_test = $redis.get('latest_test')
      unless latest_test.nil?
        request = HTTParty.get(latest_test)
        response = JSON.parse(request.body)
        if response['statusCode'] == 200 && response['statusText'].downcase == 'test complete'
          result = {
            :speed_index => response['data']['runs']['1']['firstView']['SpeedIndex'],
            :url => response['data']['url'],
            :result_url => response['data']['summary']
          }
          $redis.pipelined do
            $redis.set('latest_result', result.to_json)
            $redis.del('latest_test')
          end
          puts "Test results stored: #{response['data']['summary']}"
        else
          puts "Test results not available: #{response['statusText']}"
        end
      else
        puts 'There are no pending tests.'
      end
    end

  end
end