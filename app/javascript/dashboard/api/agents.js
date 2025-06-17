/* global axios */

import ApiClient from './ApiClient';

class Agents extends ApiClient {
  constructor() {
    super('agents', { accountScoped: true });
  }

  bulkInvite({ emails }) {
    return axios.post(`${this.url}/bulk_create`, {
      emails,
    });
  }

  createAIAgent(agentData) {
    return this.postCollectionAction({
      action: 'create_ai_agent',
      data: { agent: agentData },
    });
  }

  // Fetch deployed AI agents from backend
  // eslint-disable-next-line class-methods-use-this
  fetchAloostudioDeployments() {
    // We are reusing the agents API client, so we need to replace 'agents' with 'aloostudio_agents' in the URL
    const url = this.url.replace('agents', 'aloostudio_agents');
    return axios.get(url);
  }
}

export default new Agents();
