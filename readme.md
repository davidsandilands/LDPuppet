# LDPuppet - Fresh Catalog Script

This repository contains a Ruby script, `ld_fresh_catalog.rb`, designed to integrate Puppet with LaunchDarkly for feature flag-based catalog management.

## Overview

While adding feature flags directly into Puppet code would add an undesirable level of complecity, controlling the deployment of code in an environment would seem a practicle approach. The script determines whether to run Puppet with a fresh catalog or a cached catalog based on a LaunchDarkly feature flag. It extracts trusted facts from the Puppet node's certificate to allow for targeted deployment and sends custom events to LaunchDarkly for tracking to allow for the potential of guardced rollouts.

Note this script is not intended to be production ready and is intended as a simple test of the idea.

## benefits

- Reduce needless catalog generation and reduce Puppet infrastructure hardware requirements
- Target code deployments beyond just whole environment deployment and isolate critical applications
- Abort rollouts on errors or unexpected changes

## Features

- Extracts trusted facts from Puppet node certificates.
- Uses LaunchDarkly feature flags to decide between fresh or cached catalog runs.
- Sends custom events to LaunchDarkly for tracking Puppet runs.
- Supports running multiple agents from a single VM by passing a `certname` argument.

## Requirements

- Puppet or OpenVox installed and available at `/opt/puppetlabs/puppet/bin/puppet`
- LaunchDarkly Ruby SDK `/opt/puppetlabs/puppet/bin/gem install launchdarkly-server-sdk`
- LaunchDarkly SDK Key
- LaunchDarkly Flag created called `fresh-catalog`
- LaunchDarkly Context `puppetnode` enabled for experimentation

## Installation

1. Place the `ld_fresh_catalog.rb` as an executable script each node to be controlled
2. Configure a mechanism to run the script such as cron or a for loop on certnames if testing on a single server.
3. Configure the targeting for the `fresh-catalog` flag as required

Collecting workspace informationHere is a `README.md` template for your folder:

## Usage

Run the script with the following command:

```bash
ld_fresh_catalog.rb [certname]
```

- `certname` (optional): Specify the certificate name to use. If not provided, the script will use the default certname from Puppet's configuration.

### Example

```bash
ld_fresh_catalog.rb my-node-certname
```

## Environment Variables

- `LD_SDK_KEY`: Your LaunchDarkly SDK key. If not set, the script will use the placeholder `your-sdk-key-here`.

## How It Works

1. Extracts trusted facts from the Puppet node's certificate.
2. Builds a LaunchDarkly context using the extracted facts and Facter data.
3. Queries the LaunchDarkly feature flag `fresh-catalog` to determine whether to run a fresh or cached catalog.
4. Executes the appropriate Puppet command based on the flag's value.
5. Sends a custom event to LaunchDarkly to track the result of the Puppet run.

## Custom Events

The script sends the following custom events to LaunchDarkly:

- `puppet_no_change`: No changes were made during the Puppet run.
- `puppet_change`: Changes were applied during the Puppet run.
- `puppet_error`: An error occurred during the Puppet run.
- `puppet_cached`: The cached catalog was used.

## Acknowledgments

- [LaunchDarkly Ruby SDK](https://github.com/launchdarkly/ruby-server-sdk)
- [Puppet and Facter documentation](https://help.puppet.com/)
- [Puppet 8 for DevOps Engingeers](https://www.packtpub.com/en-gb/product/puppet-8-for-devops-engineers-9781803235455)
