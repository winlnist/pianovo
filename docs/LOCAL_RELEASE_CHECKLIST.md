# Local-first release checklist

## Scope and status

Prepare a useful local Pianovo release before live Supabase integration. This is release preparation, not a TestFlight upload or a claim of App Store readiness. Navigation exposes Today, Practice, Library and History; Progress, Ask My Teacher and Settings remain planned and hidden. Existing cloud contracts are preserved but unused; there is no account requirement or automatic upload.

The existing twelve-week programme supports assigned generated MIDI sight-reading. Authored learner-plan exercises remain written guidance and do not launch MIDI Practice. Completion is learner-reported, not an automatic mastery assessment. Standalone Practice statistics and the assigned-session summary remain temporary; saved history contains context/times, not numeric accuracy or tempo measurements. Reference PDFs are not bundled or openable.

The navigation preparation passed the complete automated test action (314 tests across 35 suites), a Debug app build and `git diff --check`. A real app launch on the iPad Pro 11-inch (M5), iOS Simulator 27.0, visually confirmed the four-destination sidebar and Today presentation in portrait. This does not complete the broader physical-device, iPhone, rotation or repeated-navigation checks below. Existing compiler warnings remain unchanged.

The Getting started addition also passed all 314 tests across 35 suites and an app build, with no new compiler warnings. Its automatic presentation and readable opening content were visually confirmed in the running iPad simulator on 14 October 2026. The user subsequently reported the guide working on their physical iPad on 14 October 2026. This records overall guide validation, not completion of every iPhone, larger-text, rotation or release check below; no simulator capture is added to the repository.

## Device validation before TestFlight

Record device/OS, build or commit, date and result for each check. Previously reported successes remain useful evidence but do not prove untested paths or later builds. Use disposable local content; do not delete an existing personal installation merely to test a fresh launch.

- [ ] Navigation shows only Today, Practice, Library and History on iPhone and iPad; repeated selection works in portrait and landscape.
- [ ] Fresh installation on a test device shows honest unstarted/empty states and works without accounts or network access.
- [ ] Getting started appears before its first dismissal, closes by button or swipe, stays dismissed after reopening, and can be reopened from the toolbar. Check long text/larger text on iPhone and iPad.
- [ ] Guide shortcuts open Practice/Today/Library without starting a programme, changing saved selection/position or writing session records. Switching the visible destination to Today is not switching the selected learner programme.
- [ ] Upgrade an existing test installation; confirm exercises, templates, plans, saved position, completion and private notes remain intact.
- [ ] Create/edit/archive/restore an exercise and exercise template; create independent exercises from a template and confirm later template edits do not rewrite them.
- [ ] Create/edit/copy a programme template, preserve pinned exercise revisions, and use it to create two independent learner plans.
- [ ] Select either learner plan or the original programme; verify separate saved positions after closing and reopening.
- [ ] Verify completion/undo, the unfinished-work warning, Next/Previous Day, recovery/week boundaries and the final-day state without automatic mastery or wrapping.
- [ ] Edit a learner plan; unchanged assignments keep status, replacement work starts uncompleted, and old history remains interpretable.
- [ ] Test Treble/Bass Practice with the Yamaha P-45, including USB disconnect/reconnect, correct/incorrect input, rotation and range/reset controls.
- [ ] Test the original assigned sight-reading flow: start, MIDI input, End & Save, summary and return to Today. Saving does not complete work or move programme position.
- [ ] Test background/interruption save/discard and explain that force-quit may lose unsaved sessions.
- [ ] Save a private session/day note and confirm its text/context after reopening. Verify History labels session evidence separately from learner reports and does not invent statistics.
- [ ] Check larger text, VoiceOver labels, readable notation/controls, keyboard avoidance, long authored text and accessible error/retry states.

## Distribution preparation

- [ ] Choose the first release audience, supported devices/OS versions, and free/paid scope; AI, marketplace and subscriptions are not assumed.
- [ ] Arrange Apple Developer membership, signing, App Store Connect ownership and a distinct build/version number for distribution.
- [ ] Prepare an app icon, accurate description and genuine screenshots of working features.
- [ ] Publish support/contact and privacy-policy pages; audit actual data collection, dependencies and any required privacy manifests/API reasons.
- [ ] Verify redistribution licences/attribution for bundled libraries, fonts and content. Do not add reference PDFs/audio without confirmed rights.
- [ ] Complete release-build testing and remaining device checks; provide review notes explaining USB MIDI hardware and how reviewers can access the experience.
- [ ] Upload an authorised TestFlight build, collect external feedback and resolve release-blocking issues before App Store submission.

Consult Apple's current [submission requirements](https://developer.apple.com/news/upcoming-requirements/) and [review guidelines](https://developer.apple.com/app-store/review/guidelines/) at distribution time. A future account release needs additional authentication, explicit linking/consent, account separation, sync, deletion and hosted-service checks; see [Hosted Accounts and Sync](HOSTED_ACCOUNTS_AND_SYNC.md).
