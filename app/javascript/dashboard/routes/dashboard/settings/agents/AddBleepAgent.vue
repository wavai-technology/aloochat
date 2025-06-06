<script setup>
import { ref, onMounted } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useVuelidate } from '@vuelidate/core';
import { required } from '@vuelidate/validators';
import Button from 'dashboard/components-next/button/Button.vue';

const emit = defineEmits(['close']);
const store = useStore();
const { t } = useI18n();

// Form data
const selectedAIAgent = ref(null);
const selectedRegion = ref('');
const selectedHumanAgent = ref(null);
const selectedChannel = ref('');

// Data lists
const aiAgents = ref([
  {
    id: 'bleep-cs-1',
    name: 'Customer Support AI',
    description:
      'General customer service AI agent trained on support documentation',
    capabilities: [
      'ticket_classification',
      'general_support',
      'product_inquiries',
    ],
    language: ['en'],
    response_time: '< 1s',
  },
  {
    id: 'bleep-tech-2',
    name: 'Technical Support AI',
    description:
      'Specialized in technical troubleshooting and developer support',
    capabilities: ['code_debugging', 'api_support', 'technical_documentation'],
    language: ['en', 'es'],
    response_time: '< 2s',
  },
  {
    id: 'bleep-sales-3',
    name: 'Sales Assistant AI',
    description: 'Trained for product recommendations and sales inquiries',
    capabilities: ['product_recommendations', 'pricing_inquiries', 'upselling'],
    language: ['en', 'fr', 'de'],
    response_time: '< 1s',
  },
]);
const humanAgents = ref([]);

// Validation rules
const rules = {
  selectedAIAgent: { required },
  selectedRegion: { required },
  selectedHumanAgent: { required },
  selectedChannel: { required },
};

const v$ = useVuelidate(rules, {
  selectedAIAgent,
  selectedRegion,
  selectedHumanAgent,
  selectedChannel,
});

// Fetch AI agents from Bleep platform
// const fetchBleepAgents = async () => {
//   try {
//     // TODO: Replace with actual API call to Bleep platform
//     const response = await fetch('YOUR_BLEEP_API_ENDPOINT/agents');
//     aiAgents.value = await response.json();
//   } catch (error) {
//     useAlert(t('AGENT_MGMT.ADD.API.BLEEP_FETCH_ERROR'));
//   }
// };

// Fetch human agents
const fetchHumanAgents = async () => {
  try {
    const response = await store.dispatch('agents/get');
    humanAgents.value = response.filter(agent => !agent.is_ai);
  } catch (error) {
    useAlert(t('AGENT_MGMT.ADD.API.HUMAN_AGENTS_FETCH_ERROR'));
  }
};

// Add Bleep Agent
const addBleepAgent = async () => {
  v$.value.$touch();
  if (v$.value.$invalid) return;

  try {
    const payload = {
      name: selectedAIAgent.value.name,
      is_ai: true,
      ai_agent_id: selectedAIAgent.value.id,
      human_agent_id: selectedHumanAgent.value.id,
    };

    await store.dispatch('agents/createBleepAgent', payload);
    useAlert(t('AGENT_MGMT.ADD.API.BLEEP_SUCCESS_MESSAGE'));
    emit('close');
  } catch (error) {
    useAlert(t('AGENT_MGMT.ADD.API.BLEEP_ERROR_MESSAGE'));
  }
};

onMounted(() => {
  //   fetchBleepAgents();
  fetchHumanAgents();
});
</script>

<template>
  <form
    class="flex flex-col items-start w-full"
    @submit.prevent="addBleepAgent"
  >
    <!-- AI Agent Selection -->
    <div class="w-full">
      <label :class="{ error: v$.selectedAIAgent.$error }">
        {{ $t('AGENT_MGMT.BLEEP_AGENT.FORM.AI_AGENT.LABEL') }}
        <select v-model="selectedAIAgent" @change="v$.selectedAIAgent.$touch">
          <option value="">
            {{ $t('AGENT_MGMT.BLEEP_AGENT.FORM.AI_AGENT.PLACEHOLDER') }}
          </option>
          <option v-for="agent in aiAgents" :key="agent.id" :value="agent">
            {{ agent.name }}
          </option>
        </select>
        <span v-if="v$.selectedAIAgent.$error" class="message">
          {{ $t('AGENT_MGMT.BLEEP_AGENT.FORM.AI_AGENT.ERROR') }}
        </span>
      </label>
    </div>
    <!-- Human Agent Selection -->
    <div class="w-full">
      <label :class="{ error: v$.selectedHumanAgent.$error }">
        {{ $t('AGENT_MGMT.BLEEP_AGENT.FORM.HUMAN_AGENT.LABEL') }}
        <select
          v-model="selectedHumanAgent"
          @change="v$.selectedHumanAgent.$touch"
        >
          <option value="">
            {{ $t('AGENT_MGMT.BLEEP_AGENT.FORM.HUMAN_AGENT.PLACEHOLDER') }}
          </option>
          <option v-for="agent in humanAgents" :key="agent.id" :value="agent">
            {{ agent.name }}
          </option>
        </select>
        <span v-if="v$.selectedHumanAgent.$error" class="message">
          {{ $t('AGENT_MGMT.BLEEP_AGENT.FORM.HUMAN_AGENT.ERROR') }}
        </span>
        <span class="help-text">
          {{ $t('AGENT_MGMT.BLEEP_AGENT.FORM.HUMAN_AGENT.HELP_TEXT') }}
        </span>
      </label>
    </div>

    <!-- Action Buttons -->
    <div class="flex flex-row justify-end w-full gap-2 px-0 py-2">
      <Button
        faded
        slate
        type="reset"
        :label="$t('AGENT_MGMT.ADD.CANCEL_BUTTON_TEXT')"
        @click.prevent="emit('close')"
      />
      <Button
        type="submit"
        :label="$t('AGENT_MGMT.ADD.FORM.SUBMIT')"
        :disabled="v$.$invalid"
      />
    </div>
  </form>
</template>

<style scoped>
.w-full {
  margin-bottom: 1rem;
}

label {
  display: block;
  margin-bottom: 0.5rem;
}

select {
  width: 100%;
  padding: 0.5rem;
  border: 1px solid #e2e8f0;
  border-radius: 0.375rem;
}

.error select {
  border-color: #ef4444;
}

.message {
  color: #ef4444;
  font-size: 0.875rem;
  margin-top: 0.25rem;
  display: block;
}

.help-text {
  color: #6b7280;
  font-size: 0.875rem;
  margin-top: 0.25rem;
  display: block;
}
</style>
