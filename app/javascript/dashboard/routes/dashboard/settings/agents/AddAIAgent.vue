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
const aiAgents = ref([]);
const humanAgents = ref([]);
const isLoadingAIAgents = ref(false);

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

// Fetch deployed AI agents from backend
const fetchAloostudioAgents = async () => {
  isLoadingAIAgents.value = true;
  try {
    const deployments = await store.dispatch(
      'agents/fetchAloostudioDeployments'
    );

    aiAgents.value = deployments.map(d => ({
      id: d.agent_id || d.id,
      name: d.agent?.title || 'AI Agent',
      description: d.agent?.welcome_message || '',
      capabilities: d.agent?.category_names || [],
      language: d.agent?.languages || [],
      response_time: d.agent?.response_time || '',
      raw: d,
    }));
  } catch (error) {
    useAlert(t('AGENT_MGMT.ADD.API.BLEEP_FETCH_ERROR'));
  } finally {
    isLoadingAIAgents.value = false;
  }
};

const fetchHumanAgents = async () => {
  try {
    const response = await store.dispatch('agents/get');
    humanAgents.value = response.filter(agent => !agent.is_ai);
  } catch (error) {
    useAlert(t('AGENT_MGMT.ADD.API.HUMAN_AGENTS_FETCH_ERROR'));
  }
};

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
  fetchAloostudioAgents();
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
