#!/usr/bin/env ruby

require 'dotenv'
require 'trello'
require './burndown_results'

Dotenv.load

Trello.configure do |config|
  config.developer_public_key = ENV['TRELLO_DEV_PUB']
  config.member_token = ENV['TRELLO_MEMBER_TOKEN']
end

board_id = ENV['TRELLO_BOARD_ID']

results = BurndownResults.new({
  board_id: board_id,
})

results.print_personal_results
