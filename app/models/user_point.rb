# frozen_string_literal: true

module DiscourseRewards
  class UserPoint < ActiveRecord::Base
    self.table_name = 'discourse_rewards_user_points'

    belongs_to :user
    belongs_to :user_badge
    belongs_to :user_points_category

    # def self.user_total_points(user)
    #   UserPoint.where(user_id: user.id).sum(:reward_points)
    # end

    # user_total_points添加到缓存机制
    after_commit :expire_cache

    def self.user_total_points(user)
      Rails.cache.fetch("user_#{user.id}_total_points", expires_in: 12.hour) do
        UserPoint.where(user_id: user.id).sum(:reward_points)
      end
    end

    private

    def expire_cache
      Rails.cache.delete("user_#{self.user_id}_total_points")
    end


  end
end
