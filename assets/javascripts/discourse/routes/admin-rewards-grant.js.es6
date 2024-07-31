import UserReward from "../models/user-reward";
import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";

export default DiscourseRoute.extend({
  model() {
    return ajax("/user-rewards.json").then((json) => {
      const userRewards = UserReward.createFromJson(json).userRewards;
      userRewards.forEach((reward) => {
        reward.created_at = new Date(reward.created_at);
      });
      userRewards.sort((a, b) => b.created_at - a.created_at);
      return { userRewards };
    });
  },

  setupController(controller, model) {
    controller.setProperties({
      model,
    });
  },
});
