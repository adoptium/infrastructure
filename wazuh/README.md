# Wazuh

## Overview Of This Repository

The aim of this repository is to collate, and store configuration and code snippets used to customise a default Wazuh installation for use within the Adoptium project.

## Useful Information

Currently we are using Wazuh 4.5.3

Documentation for which can be found: https://documentation.wazuh.com/4.5/user-manual/index.html

## Repository Structure

At the top level, this repository contains two folders that relate directly to the Wazuh application. These consist of the Wazuh central server, and the agent components that are installed on each machine. These individual folders contain any relevant configuration changes that are applied to files hosted on the physical server, or the agents as appropriate.

The server folder will contain configuration changes, that are applied to the server itself, or to the global shared configuration shared by all agents.

The agent folder will contain only configuration changes required to individual agents, platforms or groups of agents, that should not be applied via the global shared agent configuration.
