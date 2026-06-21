# Integration Map: macos-scripts

## Reads From

* local MQ repos under the user workspace
* mq-agent and mq-hal command outputs
* repo-signal readiness outputs
* terminal menu and launcher scripts

## Writes To

* terminal UI output
* local workflow snapshots
* shell launcher state
* no durable memory unless routed through MQ tools

## Use When

* task involves `mqlaunch`
* task involves macOS terminal menus
* task touches release-check shortcuts
* task needs launcher-to-repo path boundaries

## Avoid Reading First

* unrelated app docs
* old menu screenshots
* full repo READMEs
* generated dependency logs
