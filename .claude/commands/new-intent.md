Scaffold a new App Intent for Sumi.
Ask me: intent name, what it returns (spoken string), what data it needs.
Create file in Sumi/AppIntents/.
Must: conform to AppIntent, return spoken string, write to MemoryStore,
route through LLMRouter. No markdown in spoken response.
Register in SumiShortcutsProvider. Run build to verify.
