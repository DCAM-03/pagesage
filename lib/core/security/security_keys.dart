const aiApiKeyStorageKey = 'ai.openai-compatible.apiKey';

String aiProfileApiKeyStorageKey(String profileId) =>
    'ai.profile.$profileId.apiKey';
