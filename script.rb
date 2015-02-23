#!/usr/bin/env ruby

require 'trello'
require 'yaml'

board_id = ENV['TRELLO_BOARD_ID']

Trello.configure do |config|
  config.developer_public_key = ENV['TRELLO_DEV_PUB']
  config.member_token = ENV['TRELLO_MEMBER_TOKEN']
end

class BurndownResults

  attr_reader :board

  RE_ESTIMATE_FROM_NAME = /^\s*\(\s*([\d\.]*)\s*\)/

  def initialize(options = {})
    @board = Trello::Board.find(options[:board_id])
    self
  end

  def print_personal_results
    personal_results.each do |result|
      puts "#{result[:member_name]}:"
      puts "  Cards: #{result[:cards_percentage]}% (#{result[:cards_done]} / #{result[:cards_total]}), #{result[:cards_undone]} left"
      puts "  Estim: #{result[:estimate_percentage]}% (#{result[:estimate_done]} / #{result[:estimate_total]}), #{result[:estimate_undone]} left"
    end
  end

  private

  def personal_results
    @board.members
      .map { |member|
        cards_with_estimates
          .select{|card| card[:member_id] == member.id}
          .reduce({
            member_id: member.id,
            member_name: member.full_name,
            cards_total: 0,
            cards_done: 0,
            cards_undone: 0,
            estimate_total: 0,
            estimate_done: 0,
            estimate_undone: 0,
          }) {|memo, card|
            if card[:list_id] == done_list.id
              memo[:cards_done] += 1
              memo[:estimate_done] += card[:estimate]
            else
              memo[:cards_undone] += 1
              memo[:estimate_undone] += card[:estimate]
            end
            memo[:cards_total] += 1
            memo[:estimate_total] += card[:estimate]
            memo
          }
          .tap{|result|
            result[:cards_percentage] = (1.0 * result[:cards_done] / (result[:cards_total] + 0.0001) * 100).round
            result[:estimate_percentage] = (1.0 * result[:estimate_done] / (result[:estimate_total] + 0.0001) * 100).round
          }
      }
      .reject{|result| result[:cards_total] == 0 }
      .sort_by{|result| 1 * result[:estimate_undone]}
  end

  def cards_with_estimates
    @cards_with_estimates ||=
      @board.cards
        .map{ |card|
          match = card.name.match(RE_ESTIMATE_FROM_NAME)
          estimate = match.present? && match[1].present? && match[1].to_f || 0
          {
            card: card,
            card_name: card.name,
            estimate: estimate,
            member_id: card.member_ids.first,
            list_id: card.list_id,
          }
        }
        .reject{ |obj|
          obj[:estimate] == 0
        }
  end

  def done_list
    @done_list ||=
      @board.lists
        .find{|list| list.attributes[:name] == 'Done'}
  end

  def undone_lists
    @undone_lists ||=
      @board.lists
        .reject{|list| list.id == done_list.id}
  end

end

@results = BurndownResults.new({
  board_id: board_id,
})
@results.print_personal_results
