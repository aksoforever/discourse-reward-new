import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";

export default DiscourseRoute.extend({
  queryParams: {
    filter: {
      refreshModel: true,
    },
  },

  model(params) {
    return ajax("/rewards-leaderboard.json", {
      data: { filter: params.filter },
    }).then((data) => {
      return data;
    });
  },

  setupController(controller, model) {
    controller.setProperties({
      model,
    });
  },
});
