Check all files for privacy rule violations:
- Any API keys, tokens, or credentials outside Keychain
- Any network calls not going through Cloudflare Worker proxy
- Any user data written to UserDefaults (should use SwiftData)
- Any memory writes missing entity extraction
Report violations with file + line. Fix each one.
