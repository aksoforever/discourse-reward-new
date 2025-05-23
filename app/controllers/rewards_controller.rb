# frozen_string_literal: true

module DiscourseRewards
  class RewardsController < ::ApplicationController
    requires_login
    before_action :ensure_admin, only: [:create, :update, :destroy, :grant_user_reward, :create_campaign, :update_campaign]

    PAGE_SIZE = 30

    def create
      params.require([:quantity, :title])

      raise Discourse::InvalidParameters.new(:quantity) if params[:quantity].to_i < 0
      raise Discourse::InvalidParameters.new(:title) unless params.has_key?(:title)

      reward = DiscourseRewards::Rewards.new(current_user).add_reward(params)

      render_serialized(reward, RewardSerializer)
    end

    def create_campaign
      params.require([:start_date, :end_date, :name])

      raise Discourse::InvalidParameters.new(:start_date) if Date.parse(params[:start_date]) > Date.parse(params[:end_date])

      DiscourseRewards::Campaign.destroy_all

      campaign = DiscourseRewards::Rewards.new(current_user).create_campaign(params)

      render_serialized(campaign, CampaignSerializer)
    end

    def update_campaign
      params.require([:start_date, :end_date, :name, :id])

      raise Discourse::InvalidParameters.new(:start_date) if Date.parse(params[:start_date]) > Date.parse(params[:end_date])

      campaign = DiscourseRewards::Campaign.find(params[:id])

      campaign = DiscourseRewards::Rewards.new(current_user).update_campaign(campaign, params)

      render_serialized(campaign, CampaignSerializer)
    end

    def index
      page = params[:page].to_i || 1

      rewards = DiscourseRewards::Reward.order(created_at: :desc).offset(page * PAGE_SIZE).limit(PAGE_SIZE)

      reward_list = DiscourseRewards::RewardList.new(rewards: rewards, count: DiscourseRewards::Reward.all.count)

      render_serialized(reward_list, RewardListSerializer)
    end

    def show
      params.require(:id)

      reward = DiscourseRewards::Reward.find(params[:id])

      render_serialized(reward, RewardSerializer)
    end

    def update
      params.require(:id)

      reward = DiscourseRewards::Reward.find(params[:id])

      reward = DiscourseRewards::Rewards.new(current_user, reward).update_reward(params.permit(:points, :quantity, :title, :description, :upload_id, :upload_url))

      render_serialized(reward, RewardSerializer)
    end

    def destroy
      params.require(:id)

      reward = DiscourseRewards::Reward.find(params[:id]).destroy

      reward = DiscourseRewards::Rewards.new(current_user, reward).destroy_reward

      render_serialized(reward, RewardSerializer)
    end

    def grant
      params.require(:id)

      reward = DiscourseRewards::Reward.find(params[:id])

      raise Discourse::InvalidAccess if current_user.user_points.sum(:reward_points) < reward.points
      raise Discourse::InvalidAccess if reward.quantity <= 0

      reward = DiscourseRewards::Rewards.new(current_user, reward).grant_user_reward

      render_serialized(reward, RewardSerializer)
    end

    def user_rewards
      page = params[:page].to_i || 1
    
      user_rewards = DiscourseRewards::UserReward.where(status: 'applied')
                      .order(created_at: :desc) # Order by created_at in descending order
                      .offset(page * PAGE_SIZE)
                      .limit(PAGE_SIZE)
    
      user_reward_list = DiscourseRewards::UserRewardList.new(
        user_rewards: user_rewards,
        count: DiscourseRewards::UserReward.where(status: 'applied').count
      )
    
      render_serialized(user_reward_list, UserRewardListSerializer)
    end

    def grant_user_reward
      params.require(:id)

      user_reward = DiscourseRewards::UserReward.find(params[:id])

      raise Discourse::InvalidParameters.new(:id) if !user_reward

      user_reward = DiscourseRewards::Rewards.new(current_user, user_reward.reward, user_reward).approve_user_reward



      render_serialized(user_reward, UserRewardSerializer)
    end

    def cancel_user_reward
      params.require(:id)
      params.require(:cancel_reason)

      user_reward = DiscourseRewards::UserReward.find(params[:id])

      user_reward = DiscourseRewards::Rewards.new(current_user, user_reward.reward, user_reward).refuse_user_reward(params)

      render_serialized(user_reward, UserRewardSerializer)
    end

    def destroy_campaign
      params.require(:id)

      campaign = DiscourseRewards::Campaign.find(params[:id]).destroy

      render_serialized(campaign, CampaignSerializer)
    end

    def get_current_campaign
      campaign = DiscourseRewards::Campaign.first
      if campaign && campaign.end_date < Date.today
        render_serialized(nil, CampaignSerializer)
      else
        render_serialized(DiscourseRewards::Campaign.first, CampaignSerializer)
      end
    end

    def leaderboard
      page = params[:page].to_i || 1

      campaign = DiscourseRewards::Campaign.first

      if campaign && campaign.end_date > Date.today
        campaign_valid = true
      end

      if campaign_valid && (!params[:filter] || params[:filter] == "campaign")
        users = User.joins(:user_points).group(:id).select("users.*, COALESCE(SUM(discourse_rewards_user_points.reward_points), 0) AS total_available_points").order(total_available_points: :desc, username: :asc).where("discourse_rewards_user_points.created_at BETWEEN ? AND ?", campaign.start_date, campaign.end_date)
      else
        query = <<~SQL
          SELECT earned.*, total_spent_points, (total_earned_points - total_spent_points) AS total_available_points FROM (
            SELECT users.*, COALESCE(SUM(discourse_rewards_user_points.reward_points), 0) total_earned_points FROM "users"
            LEFT OUTER JOIN "discourse_rewards_user_points" ON "discourse_rewards_user_points"."user_id" = "users"."id"
            WHERE (users.id NOT IN(select user_id from anonymous_users) AND
              silenced_till IS NULL AND
              suspended_till IS NULL AND
              active=true AND
              users.id > 0)
            GROUP BY "users"."id"
          ) earned INNER JOIN (
            SELECT users.*, COALESCE(SUM(discourse_rewards_user_rewards.points), 0) total_spent_points FROM "users"
            LEFT OUTER JOIN "discourse_rewards_user_rewards" ON "discourse_rewards_user_rewards"."user_id" = "users"."id"
            WHERE (users.id NOT IN(select user_id from anonymous_users)
              AND silenced_till IS NULL
              AND suspended_till IS NULL
              AND active=true
              AND users.id > 0)
            GROUP BY "users"."id"
          ) spent ON earned.id = spent.id
          ORDER BY total_available_points desc, earned.username_lower
        SQL

        users = ActiveRecord::Base.connection.execute(query).to_a
      end

      count = users.length

      current_user_index = users.pluck("id").index(current_user.id) || 0

      users = users.drop(page * PAGE_SIZE).first(PAGE_SIZE)

      users = users.map { |user| User.new(user.with_indifferent_access.except!(:total_earned_points, :total_spent_points, :total_available_points)) } if !campaign_valid || params[:filter] == "all-time"

      render_json_dump({ campaign: campaign_valid ? true : false, count: count, current_user_rank: current_user_index + 1, users: serialize_data(users, BasicUserSerializer) })
    end

    def transactions
      transactions = ActiveRecord::Base.connection.execute("SELECT user_id, null user_reward_id, user_points_category_id,  id point_id, reward_points, created_at FROM discourse_rewards_user_points WHERE user_id=#{current_user.id} UNION SELECT user_id, id, null, null, points, created_at FROM discourse_rewards_user_rewards WHERE user_id=#{current_user.id} ORDER BY created_at DESC").to_a

      transactions = transactions.map { |transaction| DiscourseRewards::Transaction.new(transaction.with_indifferent_access) }

      render_json_dump({ count: transactions.length, transactions: serialize_data(transactions, TransactionSerializer) })
    end

    def display
    end
  end
end
