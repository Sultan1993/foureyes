# Changelog

## [1.3.0](https://github.com/Sultan1993/foureyes/compare/v1.2.0...v1.3.0) (2026-09-24)


### Features

* **critic:** move Codex to gpt-6-sol ([dd6d851](https://github.com/Sultan1993/foureyes/commit/dd6d851a12299d7fdefa36538582692dc7f97e03))
* **critic:** remove the fast service tier ([91b3c52](https://github.com/Sultan1993/foureyes/commit/91b3c522927e81d794cc1612faa877d24e4e3255))
* **critic:** rename the critic Astra → Sol ([5dd2528](https://github.com/Sultan1993/foureyes/commit/5dd2528d0c66e5773fe83994a7658a7ea6e5abe5))
* **critic:** run Astra at medium effort by default ([2960037](https://github.com/Sultan1993/foureyes/commit/2960037c4aee377822f43fa1c36d72b15fdd3e5b))

## [1.2.0](https://github.com/Sultan1993/foureyes/compare/v1.1.1...v1.2.0) (2026-09-23)


### Features

* **agents:** implementers, reviewer and code critic work from the spec ([809c87a](https://github.com/Sultan1993/foureyes/commit/809c87aec16bdf82b6d8161a32e3497c26ca7df0))
* **agents:** implementers, reviewer and code critic work from the spec: Astra fixes ([ab37155](https://github.com/Sultan1993/foureyes/commit/ab371550d38237b9fa611db15baca52268d3ed47))
* **brainstorm:** one document seam; delete the plan draft, critique and parts protocol ([a0cbeae](https://github.com/Sultan1993/foureyes/commit/a0cbeaef713106e9e0db1590487b2217b8db0f7a))
* **brainstorm:** one document seam: review fixes ([102fda1](https://github.com/Sultan1993/foureyes/commit/102fda177200673fe306ed4951ba64bbe2c2ff3b))
* **build:** execute the spec; forward contracts, stop on has-steps ([c8dbe5f](https://github.com/Sultan1993/foureyes/commit/c8dbe5f4e1bd45779ee2c166a1da26b711c53667))
* **critic:** spec critic absorbs task checks; delete the plan critic ([9a564f0](https://github.com/Sultan1993/foureyes/commit/9a564f0cef2f185d619adb599170df73e339bd96))
* **drafter:** the spec owns its tasks; no Steps, no plan assignment ([3dc4f9e](https://github.com/Sultan1993/foureyes/commit/3dc4f9ef2243c80aa3a8f545931f614736e0e9ff))
* **plan-viz:** has-steps check; drop the splicer and the Steps card ([0b1aa0d](https://github.com/Sultan1993/foureyes/commit/0b1aa0d3a6447794386a2335fdcd8e7c0e8192ba))
* **plan-viz:** has-steps check; drop the splicer and the Steps card: review fixes ([01676c9](https://github.com/Sultan1993/foureyes/commit/01676c988c91a1e23f46abaf49d86099db1bfc9e))
* **stats:** scan specs and legacy plans; drop the plan critic from the ledger and skills ([aaec918](https://github.com/Sultan1993/foureyes/commit/aaec918e851b1d4b8d81cba3bc97a730e1a901a4))

## [1.1.1](https://github.com/Sultan1993/foureyes/compare/v1.1.0...v1.1.1) (2026-09-21)


### Bug Fixes

* **critic:** run Astra at the normal service tier by default; effort stays high ([38a1ffb](https://github.com/Sultan1993/foureyes/commit/38a1ffb70464b02e1ab1a8a7bede7fb69849c20d))

## [1.1.0](https://github.com/Sultan1993/foureyes/compare/v1.0.3...v1.1.0) (2026-09-06)


### Features

* **critic:** move Codex to gpt-6-astra and rename the critic Sol → Astra ([3da3148](https://github.com/Sultan1993/foureyes/commit/3da314839377930096e12ea376bb74ca673d2dae))

## [1.0.3](https://github.com/Sultan1993/foureyes/compare/v1.0.2...v1.0.3) (2026-09-05)


### Bug Fixes

* **skills:** retry transient agent failures three times before degrading, never ask ([a279c30](https://github.com/Sultan1993/foureyes/commit/a279c30d4987ea01f36c72e8ab7d3820d3dad7a8))

## [1.0.2](https://github.com/Sultan1993/foureyes/compare/v1.0.1...v1.0.2) (2026-08-23)


### Bug Fixes

* **brainstorm:** decide the mode before the report so --continue never stalls ([b3cf13f](https://github.com/Sultan1993/foureyes/commit/b3cf13f2063d9625d6bda8cc3c21c0ee0bb586e4))

## [1.0.1](https://github.com/Sultan1993/foureyes/compare/v1.0.0...v1.0.1) (2026-08-16)


### Bug Fixes

* **implementer:** bound the change inside a file, not just across files ([2a30fe2](https://github.com/Sultan1993/foureyes/commit/2a30fe2d46d870803fe341bb4cb61bbc36e2cbe3))

## Changelog

All notable changes to foureyes are documented here. This file is maintained by
release-please from conventional commits.
