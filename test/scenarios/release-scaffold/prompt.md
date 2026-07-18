/ios-release-pipeline scaffold

This is a non-interactive test run — no user is available to answer questions.
Where the skill says to ask or confirm, use these pre-supplied answers instead:

- Simulator: pick "iPhone 16" if available, otherwise the newest available iPhone simulator.
- Scheme: DemoApp, app target: DemoApp, xcodeproj: DemoApp.xcodeproj, unit-test target: DemoAppTests, bundle ID: com.example.DemoApp.
- Team ID: use TESTTEAM12 (a fake value — this is a test fixture, that's fine).
- Certs repo: do NOT create one. Decline the `gh repo create` step entirely and leave the certs repo unconfigured.
- Do not run `bundle install`, do not run `fastlane setup_certs`, do not push anything anywhere.

If DemoApp.xcodeproj is missing, run `xcodegen generate` first.
Scaffold the files and stop.
