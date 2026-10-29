# TestFlight delivery

This pipeline prepares signed macOS and iOS builds (including Watch and widget/
Live Activity targets) and uploads them to App Store Connect for TestFlight.
It does not publish an App Store release, submit review, or distribute to
external testers automatically. No Apple password is stored in GitHub.

## Entry points

- Ordinary pushes and PRs use [CI](../.github/workflows/ci.yml); they do not upload.
- Push `testflight/v<version>-<build>` to run both platforms. For the current
  candidate the tag is `testflight/v1.4.0-14`.
- Run **TestFlight** manually from `main` or the matching TestFlight tag. Choose
  `ios`, `macos`, or `both`; selecting one platform allows recovery when the
  other platform already uploaded successfully.
- Tags must resolve to commits in `origin/main`. Every target configuration must
  have the same marketing version and build, matching the tag. Release settings
  are not incremented or rewritten at upload time.
- TestFlight tags identify upload attempts, not published releases. Reserve
  `v1.4.0` for the accepted, tested release source as described in [Release](RELEASE.md).
  Never move published tags or overwrite builds already accepted by Apple.

GitHub concurrency serializes delivery runs and does not cancel a running upload.
GitHub may replace an older pending run with a newer pending run in the same
concurrency group; check queued runs rather than using tags as a bulk upload queue.
The platform matrix is sequential and does not cancel the other platform on failure.

## One-time account setup

1. Configure the GitHub Environment **testflight** before the first delivery.
   Require maintainer approval and allow
   only the `main` branch and `testflight/v*` tags. Protect `main` and the tag
   namespace against unreviewed changes. Workflow checks complement these
   server-side rules; a modified workflow cannot be trusted to protect itself.
   The current single-maintainer environment allows `shigorefu` to approve their
   own run, as explicitly authorized; an independent reviewer is preferable when
   another maintainer is available.
2. Create an App Store Connect team API key with the least role needed for this
   upload workflow (normally App Manager for uploading and waiting for processing).
   Store its ID, issuer ID and base64-encoded `.p8` content as environment secrets.
   Do not paste the key into an issue, PR, repository file or agent chat.
3. Prepare an encrypted **private** Fastlane match Git repository using the
   maintainer's existing signing identities. Do not run `match nuke` or revoke
   working certificates. Bootstrap/renew profiles outside CI, then use read-only
   credentials in CI. The app's public repository must never store signing assets.
4. Prepare App Store distribution profiles for these bundle IDs:

   | Platform | Bundle IDs |
   | --- | --- |
   | iOS | `com.shigorefu.thruflow`, `com.shigorefu.thruflow.liveactivity`, `com.shigorefu.thruflow.watchapp` |
   | macOS | `com.shigorefu.thruflow`, `com.shigorefu.thruflow.liveactivity` |

   iOS and macOS profiles remain separate even where bundle IDs match. Include
   the Mac App Store installer certificate/private key for producing the `.pkg`.
   Profiles must include the existing App Groups, CloudKit, push and associated
   domain capabilities required by their targets.
5. Add the environment settings below. The implementation deliberately fails
   closed until setup and the release-specific CloudKit gate are complete.

### Environment secrets

| Name | Value |
| --- | --- |
| `ASC_KEY_ID` | App Store Connect API key ID |
| `ASC_ISSUER_ID` | Team API key issuer ID |
| `ASC_KEY_CONTENT_BASE64` | Base64 of the entire `.p8` file |
| `MATCH_PASSWORD` | Encryption passphrase for match storage |
| `MATCH_GIT_PRIVATE_KEY` | Read-only SSH deploy key for the private signing repository (current setup) |
| `MATCH_GIT_BASIC_AUTHORIZATION` | Alternative for HTTPS storage: base64 of `username:token` with read-only access; leave unset for SSH |

Configure exactly one repository authentication method, matching its URL. SSH
host keys come from GitHub's authenticated HTTPS metadata endpoint; strict host
verification stays enabled.

Base64 is encoding, not encryption. These values are secrets. Use a narrowly
scoped read-only token rather than the public repository's `GITHUB_TOKEN`, which
cannot read a different private repository by default. Rotate and revoke these
credentials through the owning Apple/GitHub account, not by committing them.

### Environment variables

| Name | Value |
| --- | --- |
| `TESTFLIGHT_ENABLED` | `true` after setup |
| `APPLE_TEAM_ID` | Distribution team ID; current project uses `BR727PS795` |
| `MATCH_GIT_URL` | GitHub SSH or HTTPS URL of the private match repository, without embedded credentials |
| `MATCH_GIT_BRANCH` | Signing repository branch (typically `main`) |
| `MAC_INSTALLER_CERT_NAME` | Exact common name of the Mac App Store installer certificate |
| `CLOUDKIT_VERIFIED_SHA` | Full source commit SHA for which live Production inspection was completed |

The CloudKit variable is a maintainer attestation, not an automatic schema test.
Record the inspected environment, fields/indexes, date and evidence in
[CLOUDKIT.md](CLOUDKIT.md), then set the variable to the final candidate commit.
Do not set it merely to make the workflow green. Recheck for a new candidate SHA.
Live Production was inspected for build 14 on 2026-10-29; see the dated evidence
in CloudKit. Set the variable only for the final reviewed source commit. Signed
physical-device checks remain separate from this schema attestation.

## Per-candidate procedure

1. Merge reviewed code and version/build metadata to `main` and verify CI.
2. Check App Store Connect for previously uploaded build numbers. Increase the
   project build in a new reviewed commit if necessary; never silently retry with
   an automatically generated number. Both platforms use the same project build.
3. Complete live CloudKit Production inspection and signing/profile review.
4. Set `CLOUDKIT_VERIFIED_SHA` to the candidate commit, then push the matching
   TestFlight tag or manually run **TestFlight** from `main`.
5. Approve the protected environment deployment after checking its SHA and gate.
6. Check App Store Connect processing and TestFlight availability. The workflow
   waits for processing; a timeout or network failure can occur after Apple has
   already accepted the binary. Inspect the account before retrying.
7. Test the exact processed build on physical Mac, iPhone/iPad and Watch. Follow
   [Release](RELEASE.md) for migration, sync, widgets and Live Activity checks.
   Upload success is not device verification or approval for App Store publication.

Signing uses a temporary Keychain and a temporary project copy on a disposable
GitHub-hosted macOS runner. CI reads existing match identities; it does not create
or renew them. Secrets are supplied only to the signing/upload step. Build products
and signing material are not automatically published as public workflow artifacts.

## Local tooling checks

Use Ruby 3.3 and the Bundler version recorded in `Gemfile.lock`:

```sh
bundle install
bundle exec fastlane lanes
ruby fastlane/tests/testflight_support_test.rb
python3 -m unittest discover -s scripts/tests -p 'test_*.py'
```

The upload lanes intentionally require GitHub Actions; the commands above only
load lanes and run offline tests. Fastlane and its transitive dependencies are
locked. Delivery uses `BUNDLE_FROZEN=true`; update dependencies in a reviewed PR.
The runner uses the same explicit Xcode 26.6 path as the regular CI. Fastlane's
supported `app-store` export method is used; Xcode may describe that method as
`app-store-connect` in its own interface.

## Verification boundaries

The automation can be checked without Apple credentials using Python regression
tests, Ruby syntax/helper tests and workflow validation. Signed archive/export,
App Store Connect authentication and TestFlight delivery require configured
credentials and a real approved run. Never describe offline checks as a successful
upload. Repository environment creation, secret provisioning and Apple account
changes are separate setup actions.

## Official references

- [Fastlane GitHub Actions integration](https://docs.fastlane.tools/best-practices/continuous-integration/github/)
- [Fastlane match](https://docs.fastlane.tools/actions/match/)
- [App Store Connect API authentication](https://docs.fastlane.tools/app-store-connect-api/)
- [TestFlight upload](https://docs.fastlane.tools/actions/pilot/)
- [GitHub deployment environments](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments)

## Account setup progress — 2026-10-29

The maintainer authorized a protected `testflight` environment on
`shigorefu/thruflow`, limited to the `main` branch and `testflight/v*` tags,
with `shigorefu` as required reviewer and self-review enabled for the sole
maintainer. The team is `BR727PS795`. An App Manager team API key was created
and its three values stored as environment secrets without printing the private
key. Apple team API keys apply to all apps in the team; this scope was explicitly
approved. The maintainer accepted Apple's updated Program License Agreement.

The private `shigorefu/thruflow-signing` repository holds encrypted match assets.
Its dedicated deploy key is read-only; the private deploy key and match
passphrase are environment secrets. Local bootstrap uses the maintainer's
authenticated GitHub access for writing; CI never receives that broader access.
Bootstrap completed for iOS and macOS: Apple Distribution and Mac App Store
Installer identities plus five App Store profiles were created without revoking
existing certificates. Profile team, application groups, push and CloudKit
container permissions were inspected; exported binaries must still pass the
workflow entitlement checks. Delivery was enabled after PRs #29 and #30 passed
CI and were merged. The approved source is
`6493617dba8b6a244952dc78374d6396b97bca60`.

The first tagged attempt (`testflight/v1.4.0-14`, commit `9ce310a`) stopped before
signing because the unauthenticated GitHub metadata request hit a rate limit.
PR #30 authenticated that request using the workflow token. The original tag
was preserved; the retry used manual dispatch from reviewed main.

[Delivery run #40820767787](https://github.com/shigorefu/thruflow/actions/runs/40820767787)
completed the iOS archive, export checks, upload and Apple processing for
1.4.0 (14). Apple returned `VALID`; the version was separately submitted to App
Review with maintainer authorization. macOS delivery is still in progress.
The workflow itself does not submit App Review. Do not rerun an already accepted
platform with the same build number.
