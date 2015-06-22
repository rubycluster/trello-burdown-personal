require 'trello'

class BurndownResults

  attr_reader :board

  RE_POINTS_FROM_NAME = /^\s*\(\s*([\d\.]*)\s*\)/

  def initialize(options = {})
    @board = Trello::Board.find(options[:board_id])
    self
  end

  def print_personal_results
    personal_results.each do |result|
      puts "#{result[:member_name]}:"
      %w{cards points}.each do |target|
        strings = %w{percentage done total undone}
          .map do |type|
            result[:"#{target}_#{type}"]
          end
          .unshift(target.capitalize)
        puts "  %s : %d%% (%d / %d), %d left" % strings
      end
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
            points_total: 0,
            points_done: 0,
            points_undone: 0,
          }) {|memo, card|
            done = card[:list_id] == done_list.id ? :done : :undone
            [done, :total].each do |type|
              memo[:"cards_#{type}"] += 1
              memo[:"points_#{type}"] += card[:estimate]
            end
            memo
          }
          .tap{|result|
            %w{cards points}.each do |target|
              result[:"#{target}_percentage"] =
                (1.0 * result[:"#{target}_done"] / (result[:"#{target}_total"] + 0.0001) * 100).round
            end
          }
      }
      .reject{|result| result[:cards_total] == 0 }
      .reject{|result| result[:points_total] == 0 }
      .sort_by{|result| 1 * result[:points_undone]}
  end

  def cards_with_estimates
    @cards_with_estimates ||=
      @board.cards
        .map{ |card|
          match = card.name.match(RE_POINTS_FROM_NAME)
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
