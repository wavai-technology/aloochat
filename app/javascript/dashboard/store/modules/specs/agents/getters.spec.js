import { getters } from '../../agents';

describe('#getters', () => {
  it('getAgents', () => {
    const state = {
      records: [
        {
          id: 1,
          name: 'Agent 1',
          email: 'agent1@aloochat.ai',
          confirmed: true,
        },
        {
          id: 2,
          name: 'Agent 2',
          email: 'agent2@aloochat.ai',
          confirmed: false,
        },
      ],
    };
    expect(getters.getAgents(state)).toEqual([
      {
        id: 1,
        name: 'Agent 1',
        email: 'agent1@aloochat.ai',
        confirmed: true,
      },
      {
        id: 2,
        name: 'Agent 2',
        email: 'agent2@aloochat.ai',
        confirmed: false,
      },
    ]);
  });

  it('getVerifiedAgents', () => {
    const state = {
      records: [
        {
          id: 1,
          name: 'Agent 1',
          email: 'agent1@aloochat.ai',
          confirmed: true,
        },
        {
          id: 2,
          name: 'Agent 2',
          email: 'agent2@aloochat.ai',
          confirmed: false,
        },
      ],
    };
    expect(getters.getVerifiedAgents(state)).toEqual([
      {
        id: 1,
        name: 'Agent 1',
        email: 'agent1@aloochat.ai',
        confirmed: true,
      },
    ]);
  });

  it('getUIFlags', () => {
    const state = {
      uiFlags: {
        isFetching: true,
        isCreating: false,
        isUpdating: false,
        isDeleting: false,
      },
    };
    expect(getters.getUIFlags(state)).toEqual({
      isFetching: true,
      isCreating: false,
      isUpdating: false,
      isDeleting: false,
    });
  });

  it('getAgentStatus', () => {
    const state = {
      records: [
        {
          id: 1,
          name: 'Agent 1',
          email: 'agent1@aloochat.ai',
          confirmed: true,
          availability_status: 'online',
        },
        {
          id: 2,
          name: 'Agent 2',
          email: 'agent2@aloochat.ai',
          confirmed: false,
          availability_status: 'offline',
        },
      ],
    };
    expect(getters.getAgentStatus(state)).toEqual({
      online: 1,
      busy: 0,
      offline: 1,
    });
  });

  it('getAgentStatus', () => {
    const state = {
      records: [
        {
          id: 1,
          name: 'Agent 1',
          email: 'agent1@aloochat.ai',
          confirmed: true,
          availability_status: 'online',
        },
        {
          id: 2,
          name: 'Agent 2',
          email: 'agent2@aloochat.ai',
          confirmed: false,
          availability_status: 'offline',
        },
      ],
    };
    expect(getters.getAgentStatus(state)).toEqual({
      online: 1,
      busy: 0,
      offline: 1,
    });
  });
});
