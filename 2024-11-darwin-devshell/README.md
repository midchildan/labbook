```console
❯ nix develop --impure -c /usr/bin/git rev-parse HEAD
warning: Git tree '/Users/midchildan/Documents/src/repos/github.com/midchildan/playground' is dirty
Running tasks     devenv:enterShell

Succeeded         devenv:enterShell 9ms
1 Succeeded                         9.27ms

DEVELOPER_DIR=/nix/store/4s8z8il6zyq77ixy4b8kfzwsnz90vsrm-apple-sdk-11.3
SDKROOT=/nix/store/4s8z8il6zyq77ixy4b8kfzwsnz90vsrm-apple-sdk-11.3/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk
warning: unhandled Target key DefaultVariant
warning: unhandled Target key SupportedTargets
warning: unhandled Target key VersionMap
warning: unhandled Target key Variants
warning: unhandled Target key DebuggerOptions
warning: unhandled Product key iOSSupportVersion
warning: unhandled Target key DefaultVariant
warning: unhandled Target key SupportedTargets
warning: unhandled Target key VersionMap
warning: unhandled Target key Variants
warning: unhandled Target key DebuggerOptions
warning: unhandled Product key iOSSupportVersion
warning: unhandled Target key DefaultVariant
warning: unhandled Target key SupportedTargets
warning: unhandled Target key VersionMap
warning: unhandled Target key Variants
warning: unhandled Target key DebuggerOptions
warning: unhandled Product key iOSSupportVersion
error: tool 'git' not found
❯ nix develop --impure .#still-broken -c /usr/bin/git rev-parse HEAD
warning: Git tree '/Users/midchildan/Documents/src/repos/github.com/midchildan/playground' is dirty
DEVELOPER_DIR=/nix/store/4s8z8il6zyq77ixy4b8kfzwsnz90vsrm-apple-sdk-11.3
SDKROOT=/nix/store/4s8z8il6zyq77ixy4b8kfzwsnz90vsrm-apple-sdk-11.3/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk
Running tasks     devenv:enterShell
Succeeded         devenv:enterShell 10ms
1 Succeeded                         10.32ms

warning: unhandled Target key DefaultVariant
warning: unhandled Target key SupportedTargets
warning: unhandled Target key VersionMap
warning: unhandled Target key Variants
warning: unhandled Target key DebuggerOptions
warning: unhandled Product key iOSSupportVersion
warning: unhandled Target key DefaultVariant
warning: unhandled Target key SupportedTargets
warning: unhandled Target key VersionMap
warning: unhandled Target key Variants
warning: unhandled Target key DebuggerOptions
warning: unhandled Product key iOSSupportVersion
warning: unhandled Target key DefaultVariant
warning: unhandled Target key SupportedTargets
warning: unhandled Target key VersionMap
warning: unhandled Target key Variants
warning: unhandled Target key DebuggerOptions
warning: unhandled Product key iOSSupportVersion
error: tool 'git' not found
playground/2024-11-darwin-devshell on  main [∅!+≡1]
❯ nix develop --impure .#fixed -c /usr/bin/git rev-parse HEAD
warning: Git tree '/Users/midchildan/Documents/src/repos/github.com/midchildan/playground' is dirty
DEVELOPER_DIR=
SDKROOT=
Running tasks     devenv:enterShell
Succeeded         devenv:enterShell 7ms
1 Succeeded                         7.20ms

44e184c4bf71fe5d469c09e84e8691e8b0f88172
❯ nix develop --impure .#pre-commit -c true
warning: Git tree '/Users/midchildan/Documents/src/repos/github.com/midchildan/playground' is dirty
Running tasks     devenv:enterShell

Succeeded         playground:clean-previous 4ms
Failed            devenv:git-hooks:install  262ms
Dependency failed devenv:enterShell
1 Succeeded, 1 Failed, 1 Dependency Failed  267.21ms

--- devenv:git-hooks:install failed with error: Task exited with status: exit status: 1
--- devenv:git-hooks:install stdout:
0000.21: /Users/midchildan/Documents/src/repos/github.com/midchildan/playground/.pre-commit-config.yaml
0000.02: An error has occurred: FatalError: git failed. Is it installed, and are you in a Git repository directory?
0000.01: Check the log at /Users/midchildan/.cache/pre-commit/pre-commit.log
--- devenv:git-hooks:install stderr:
0000.24: git-hooks.nix: updating /Users/midchildan/Documents/src/repos/github.com/midchildan/playground/2024-11-darwin-devshell repo
---

❯ nix develop --impure .#pre-commit-fixed -c true
warning: Git tree '/Users/midchildan/Documents/src/repos/github.com/midchildan/playground' is dirty
Running tasks     devenv:enterShell
Succeeded         playground:clean-previous 4ms
Succeeded         devenv:git-hooks:install  1176ms
Succeeded         devenv:enterShell         6ms
3 Succeeded                                 1.19s

```
