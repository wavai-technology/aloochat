import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import * as types from '../mutation-types';
import AgentAPI from '../../api/agents';

export const state = {
  records: [],
  aloostudioDeployments: [],
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isUpdating: false,
    isDeleting: false,
    isFetchingAloostudio: false,
  },
};

export const getters = {
  getAgents($state) {
    return $state.records;
  },
  getAloostudioDeployments($state) {
    return $state.aloostudioDeployments;
  },
  getVerifiedAgents($state) {
    return $state.records.filter(record => record.confirmed);
  },
  getUIFlags($state) {
    return $state.uiFlags;
  },
  getAgentById: $state => id => {
    return $state.records.find(record => record.id === Number(id)) || {};
  },
  getAgentStatus($state) {
    let status = {
      online: $state.records.filter(
        agent => agent.availability_status === 'online'
      ).length,
      busy: $state.records.filter(agent => agent.availability_status === 'busy')
        .length,
      offline: $state.records.filter(
        agent => agent.availability_status === 'offline'
      ).length,
    };
    return status;
  },
};

export const actions = {
  get: async ({ commit }) => {
    commit(types.default.SET_AGENT_FETCHING_STATUS, true);
    try {
      const response = await AgentAPI.get();
      commit(types.default.SET_AGENTS, response.data);
      commit(types.default.SET_AGENT_FETCHING_STATUS, false);
      return response.data;
    } catch (error) {
      commit(types.default.SET_AGENT_FETCHING_STATUS, false);
      throw error;
    }
  },
  create: async ({ commit }, agentInfo) => {
    commit(types.default.SET_AGENT_CREATING_STATUS, true);
    try {
      const response = await AgentAPI.create(agentInfo);
      commit(types.default.ADD_AGENT, response.data);
      commit(types.default.SET_AGENT_CREATING_STATUS, false);
    } catch (error) {
      commit(types.default.SET_AGENT_CREATING_STATUS, false);
      throw error;
    }
  },
  createBleepAgent: async ({ commit }, agentData) => {
    commit(types.default.SET_AGENT_CREATING_STATUS, true);
    try {
      const response = await AgentAPI.createAIAgent(agentData);
      commit(types.default.ADD_AGENT, response.data);
      commit(types.default.SET_AGENT_CREATING_STATUS, false);
    } catch (error) {
      commit(types.default.SET_AGENT_CREATING_STATUS, false);
      throw error;
    }
  },
  update: async ({ commit }, { id, ...agentParams }) => {
    commit(types.default.SET_AGENT_UPDATING_STATUS, true);
    try {
      const response = await AgentAPI.update(id, agentParams);
      commit(types.default.EDIT_AGENT, response.data);
      commit(types.default.SET_AGENT_UPDATING_STATUS, false);
    } catch (error) {
      commit(types.default.SET_AGENT_UPDATING_STATUS, false);
      throw new Error(error);
    }
  },
  updateSingleAgentPresence: ({ commit }, { id, availabilityStatus }) => {
    commit(types.default.UPDATE_SINGLE_AGENT_PRESENCE, {
      id,
      availabilityStatus,
    });
  },
  updatePresence: async ({ commit }, data) => {
    commit(types.default.UPDATE_AGENTS_PRESENCE, data);
  },
  delete: async ({ commit }, agentId) => {
    commit(types.default.SET_AGENT_DELETING_STATUS, true);
    try {
      await AgentAPI.delete(agentId);
      commit(types.default.DELETE_AGENT, agentId);
      commit(types.default.SET_AGENT_DELETING_STATUS, false);
    } catch (error) {
      commit(types.default.SET_AGENT_DELETING_STATUS, false);
      throw new Error(error);
    }
  },
  async fetchAloostudioDeployments({ commit }) {
    commit('SET_FETCHING_ALOOSTUDIO', true);
    try {
      const response = await AgentAPI.fetchAloostudioDeployments();
      commit('SET_ALOOSTUDIO_DEPLOYMENTS', response.data.deployments || []);
      commit('SET_FETCHING_ALOOSTUDIO', false);
      return response.data.deployments || [];
    } catch (error) {
      commit('SET_FETCHING_ALOOSTUDIO', false);
      throw error;
    }
  },
};

export const mutations = {
  [types.default.SET_AGENT_FETCHING_STATUS]($state, status) {
    $state.uiFlags.isFetching = status;
  },
  [types.default.SET_AGENT_CREATING_STATUS]($state, status) {
    $state.uiFlags.isCreating = status;
  },
  [types.default.SET_AGENT_UPDATING_STATUS]($state, status) {
    $state.uiFlags.isUpdating = status;
  },
  [types.default.SET_AGENT_DELETING_STATUS]($state, status) {
    $state.uiFlags.isDeleting = status;
  },

  [types.default.SET_AGENTS]: MutationHelpers.set,
  [types.default.ADD_AGENT]: MutationHelpers.create,
  [types.default.EDIT_AGENT]: MutationHelpers.update,
  [types.default.DELETE_AGENT]: MutationHelpers.destroy,
  [types.default.UPDATE_AGENTS_PRESENCE]: MutationHelpers.updatePresence,
  [types.default.UPDATE_SINGLE_AGENT_PRESENCE]: (
    $state,
    { id, availabilityStatus }
  ) =>
    MutationHelpers.updateSingleRecordPresence($state.records, {
      id,
      availabilityStatus,
    }),
  SET_ALOOSTUDIO_DEPLOYMENTS($state, deployments) {
    $state.aloostudioDeployments = deployments;
  },
  SET_FETCHING_ALOOSTUDIO($state, status) {
    $state.uiFlags.isFetchingAloostudio = status;
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
