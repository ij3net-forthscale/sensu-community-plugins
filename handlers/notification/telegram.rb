#!/usr/bin/env ruby
#About telegram bot configuration read here https://github.com/eljojo/telegram_bot

require 'sensu-handler'
require 'telegram_bot'
require 'timeout'

class Telegram < Sensu::Handler
  def short_name
    @event['check']['name'] + ' on ' + @event['client']['name']
  end

  def action_to_string
    @event['action'].eql?('resolve') ? "RECOVERY" : "PROBLEM"
  end

  def status_to_string
    @event['check']['status'].eql?(0) && @event['check']['name'].eql?('keepalive') ? "UP" : @event['check']['status'].eql?(2) && @event['check']['name'].eql?('keepalive'
) ? "DOWN" : @event['check']['status'].eql?(0) ? "OK" : @event['check']['status'].eql?(1) ? "WARNING" : @event['check']['status'].eql?(2) ? "CRITICAL" : "UNKNOWN"
  end

  def handle
    telegram_token = settings['telegram']['telegram_token']

    body = <<-BODY.gsub(/^\s+/, '')
            *#{Time.at(@event['check']['issued'])} #{action_to_string} service: #{short_name}*
            Host: #{@event['client']['name']} address: #{@event['client']['address']}
            State: #{@event['check']['status']} / #{status_to_string} Occurrences:  #{@event['occurrences']}
            Check Name:  #{@event['check']['name']} Additional Info: #{@event['check']['output']}
          BODY

    begin
      timeout 10 do

        bot = TelegramBot.new(token: telegram_token)
        messages = bot.get_updates(timeout: 3000, offset: 1)
        messages.each do |message|
          message.reply do |reply|
            reply.text = body
            reply.send_with(bot)
          end
          break
        end

        puts 'telegram -- sent alert'
      end
    rescue Timeout::Error
      puts 'telegram -- timed out while attempting'
    end
  end
end
