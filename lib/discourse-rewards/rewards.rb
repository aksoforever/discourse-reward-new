# frozen_string_literal: true

class DiscourseRewards::Rewards
  def initialize(user, reward = nil, user_reward = nil)
    @user = user
    @reward = reward
    @user_reward = user_reward
  end

  def add_reward(opts)
    @reward = DiscourseRewards::Reward.create(
      created_by_id: @user.id,
      points: opts[:points],
      quantity: opts[:quantity].to_i,
      title: opts[:title],
      description: opts[:description],
      upload_id: opts[:upload_id],
      upload_url: opts[:upload_url]
    )

    DiscourseRewards::RewardNotification.new(@reward, @user, DiscourseRewards::RewardNotification.types[:new]).create

    publish_reward!(create: true)

    link_image_to_post(opts[:upload_id])

    @reward
  end

  def create_campaign(opts)
    @campaign = DiscourseRewards::Campaign.create(
      created_by_id: @user.id,
      name: opts[:name],
      description: opts[:description],
      start_date: Date.parse(opts[:start_date]),
      end_date: Date.parse(opts[:end_date]),
      include_parameters: opts[:include_parameters],
    )

    @campaign
  end

  def update_campaign(campaign, opts)
    campaign.update!(
      created_by_id: campaign.created_by_id,
      name: opts[:name],
      description: opts[:description],
      start_date: Date.parse(opts[:start_date]),
      end_date: Date.parse(opts[:end_date]),
      include_parameters: opts[:include_parameters],
    ) if campaign

    campaign
  end

  def update_reward(opts)
    @reward.update!(opts) if @reward

    publish_reward!(update: true)

    link_image_to_post(opts[:upload_id]) if opts[:upload_id]

    @reward
  end

  def destroy_reward
    @reward.destroy

    publish_reward!(destroy: true)

    @reward
  end

  def grant_user_reward
    @user_reward = DiscourseRewards::UserReward.create(
      user_id: @user.id,
      reward_id: @reward.id,
      status: 'applied',
      points: @reward.points
    )

    @reward.update!(quantity: @reward.quantity - 1)

    DiscourseRewards::RewardNotification.new(@reward, @user, DiscourseRewards::RewardNotification.types[:redeemed]).create

    publish_reward!(quantity: true)
    publish_points!

    @reward
  end

  def approve_user_reward
    @user_reward.update!(status: 'granted')

    PostCreator.new(
      @user,
      title: 'Reward Grant',
      raw: "@#{@user_reward.user.username}, \n Hi #{@user_reward.user.name}, 您已成功兑换礼品： #{@reward.title} . \n 请联系管理员领取: \n 合肥：李晶晶 Elina Li 8073（座机号） \n 武汉&常州：蒋雪利 Shirley Jiang 8294（座机号） \n 桂林：杨璐瑜 Joey Yang  15021（座机号） \n 佛山&深圳：朱冬然 Abby Zhu 16008（座机号） \n 上海及其他地区：刘芳 Liuliu Liu  6757（座机号）",
      category: SiteSetting.discourse_rewards_grant_topic_category,
      skip_validations: true
    ).create!

    publish_user_reward!

    @user_reward
  end

  def refuse_user_reward(opts)
    @user_reward.update!(cancel_reason: opts[:cancel_reason])
    @user_reward.destroy!
    publish_user_reward!
    publish_points!

    if @reward
      PostCreator.new(
        @user,
        title: 'Unable to grant the reward',
        raw: "We are sorry to announce that #{@user_reward.reward.title} Award has not been granted to you because #{@user_reward.cancel_reason}. Please try to redeem another award @#{@user_reward.user.username}",
        category: SiteSetting.discourse_rewards_grant_topic_category,
        skip_validations: true
      ).create!

      @reward.update!(quantity: @reward.quantity + 1)
      publish_reward!(quantity: true)
    else
      PostCreator.new(
        @user,
        title: 'The reward is no longer available',
        raw: "We are sorry to announce that your redeemed Award is no longer availabe due to some technical reasons. Please try to redeem another award @#{@user_reward.user.username}",
        category: SiteSetting.discourse_rewards_grant_topic_category,
        skip_validations: true
      ).create!
    end

    @user_reward
  end

  private

  def link_image_to_post(upload_id)
    UploadReference.create(upload_id: upload_id, target_type: "Post", target_id: Post.first.id) unless UploadReference.find_by(upload_id: upload_id)
    PostUpload.create(post_id: Post.first.id, upload_id: upload_id) unless PostUpload.find_by(upload_id: upload_id)
  end

  def publish_reward!(status = {})
    message = {
      reward_id: @reward.id,
      reward: @reward.attributes
    }.merge!(status)

    MessageBus.publish("/u/rewards", message)
    publish_points!
  end

  def publish_points!

    # 清除缓存以便下次获取更新的值
    Rails.cache.delete("user_#{@user.id}_total_points")
    Rails.cache.delete("user_#{@user.id}_available_points")

    user_message = {
      available_points: @user.available_points
    }

    MessageBus.publish("/u/#{@user.id}/rewards", user_message)
  end

  def publish_user_reward!
    message = {
      user_reward_id: @user_reward.id,
      user_reward: @user_reward.attributes
    }

    MessageBus.publish("/u/user-rewards", message)
    publish_points!
  end
end
