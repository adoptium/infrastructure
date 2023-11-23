# Wazuh

## Overview Of This Repository

The aim of this repository is to collate, and store configuration and code snippets used to customise a default Wazuh installation for use within the Adoptium project.

## Useful Information

Currently we are using Wazuh 4.5.3

Documentation for which can be found: https://documentation.wazuh.com/4.5/user-manual/index.html

## Repository Structure

At the top level, this repository has a folder for each of the two main components on the server. These will contain any configuration changes that are applied to files hosted on the physical server. These, in turn, will include changes to the shared agent configuration (located on the Wazuh server), and then applied to all agents connected.

The agents folder will contain only configuration changes required to individual agents, platforms or groups of agents, that should not be applied via the  global shared agent configuration.
