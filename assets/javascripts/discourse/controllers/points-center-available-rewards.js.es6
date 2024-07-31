import Controller from "@ember/controller";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import Reward from "../models/reward";
import I18n from "I18n";
import { ajax } from "discourse/lib/ajax";

export default Controller.extend({
  dialog: service(),
  routing: service("-routing"),
  page: 0,
  loading: false,

  init() {
    this._super(...arguments);

    this.messageBus.subscribe(`/u/${this.currentUser.id}/rewards`, (data) => {
      this.replaceReward(data);
    });
  },

  replaceReward(data) {
    if (!this.model) {
      return;
    }

    let index = this.model.rewards.indexOf(
      this.model.rewards.find(
        (searchReward) => searchReward.id === data.reward_id
      )
    );

    if (data.create) {
      if (index < 0) {
        this.model.rewards.unshiftObject(Reward.createFromJson(data));
      }

      return;
    }

    if (data.destroy) {
      if (index >= 0) {
        this.model.rewards.removeObject(this.model.rewards[index]);
      }

      return;
    }

    this.model.rewards.removeObject(this.model.rewards[index]);
    this.model.rewards.splice(index, 0, Reward.createFromJson(data));

    this.set("model.rewards", this.model.rewards);
  },

  findRewards() {
    if (this.page * 30 >= this.model.count) {
      return;
    }

    if (this.loading || !this.model) {
      return;
    }

    this.set("loading", true);
    this.set("page", this.page + 1);

    ajax("/rewards.json", {
      type: "GET",
      data: { page: this.page },
    })
      .then((result) => {
        this.model.rewards.pushObjects(Reward.createFromJson(result).rewards);
      })
      .finally(() => this.set("loading", false));
  },

  @action
  loadMore() {
    this.findRewards();
  },

  @action
  grant(reward) {
    if (!reward || !reward.id) {
      return;
    }

    this.dialog.yesNoConfirm({
      title: I18n.t("admin.rewards.grant_confirm"),
      body: I18n.t("no_value"),
      yes: I18n.t("yes_value"),
      no: I18n.t("no_value"),
      didConfirm: () => {
        return Reward.grant(reward)
          .then(() => {
            location.reload();
          })
          .catch(() => {
            this.dialog.alert(I18n.t("generic_error"));
          });
      }
    });
  },

  @action
  fetchNewAvailableRewardData(){
    ajax('/rewards.json').then((json)=>{
      const newModel = Reward.createFromJson(json);
      this.set('model',newModel);
    })
  },
});
