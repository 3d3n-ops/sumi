Scaffold a new ProactiveTrigger for Sumi.
Ask me: trigger name, what condition it evaluates, what surface it fires.
Create file in Sumi/Proactive/Triggers/.
Must: conform to ProactiveTrigger protocol, return ProactiveSurface?,
respect quiet hours and daily max, include relevance score Float.
Register in ProactiveEngine.allTriggers. Write unit test.
