import Controller from "@ember/controller";
import UserReward from "../models/user-reward";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";

export default Controller.extend({
  dialog: service(),
  page: 0,
  loading: false,

  findRewards() {
    if (this.page * 30 >= this.model.count) {
      return;
    }

    if (this.loading || !this.model) {
      return;
    }

    this.set("loading", true);
    this.set("page", this.page + 1);

    ajax("/user-rewards.json", {
      type: "GET",
      data: { page: this.page },
    })
      .then((result) => {
        // Sort the loaded rewards
        const sortedRewards = UserReward.createFromJson(result).userRewards.sortBy('created_at').reverse();
        this.model.userRewards.pushObjects(sortedRewards);
      })
      .finally(() => this.set("loading", false));
  },

  @action
  loadMore() {
    this.findRewards();
  },

  @action
  grant(user_reward) {
    if (!user_reward || !user_reward.id) {
      return;
    }

    this.dialog.yesNoConfirm({
      title: I18n.t("admin.rewards.grant_confirm"),
      body: I18n.t("no_value"),
      yes: I18n.t("yes_value"),
      no: I18n.t("no_value"),
      didConfirm: () => {
        return UserReward.grant(user_reward)
        .then(() => {
          this.model.userRewards.removeObject(user_reward);
          this.send("closeModal");
        })
        .catch(() => {
          dialog.alert(I18n.t("generic_error"));
        });
        
      }
    });
  },

  @action
  cancelReward(user_reward, reason) {
    if (!user_reward || !user_reward.id) {
      return;
    }

        this.dialog.confirm({
      title: I18n.t("admin.rewards.cancel_grant_confirm"),
      body: I18n.t("no_value"),
      yes: I18n.t("yes_value"),
      no: I18n.t("no_value"),

      didConfirm: () => {
        return UserReward.cancelReward(user_reward, reason)
        .then(() => {
          this.model.userRewards.removeObject(user_reward);
          this.send("closeModal");
        })
        .catch(() => {
          dialog.alert(I18n.t("generic_error"));
        });
        
      }
    });
  },
});
