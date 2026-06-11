Analyze all BGTask handlers in Sumi/Proactive/ for the 25-second iOS budget.
Trace all async calls in each handler, estimate cumulative latency,
flag anything that risks timeout, suggest optimizations.
Also verify: expiration handler calls task.setTaskCompleted(success: false).
