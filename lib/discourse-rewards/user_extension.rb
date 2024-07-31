# frozen_string_literal: true

module DiscourseRewards::UserExtension
  def self.prepended(base)
    base.has_many :user_points, class_name: 'DiscourseRewards::UserPoint'
    base.has_many :user_rewards, class_name: 'DiscourseRewards::UserReward'
    base.has_many :rewards, class_name: 'DiscourseRewards::Reward'
  end

  # Points fetching in user Extension
  def total_earned_points
    DiscourseRewards::UserPoint.user_total_points(self)
  end
end
