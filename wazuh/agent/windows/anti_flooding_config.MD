# Wazuh Agent flooding

## Requirement

Adoptium's public windows hosts receive significantly more intrusion attempts than any other platform. As such, Wazuh will issue anti-flooding alerts & warnings for this platform. The best solution is to increase the number of logging requests permitted on windows hosts.

## How

To achieve this on windows, we could amend the client buffer section of the agent configuration. We could also put this change in the centralised configuration, but given we've only seen flooding issues on windows, allowing more logs for all agents across all platforms could cause disk space issues and a loss of visibility during periods of focused hacker activity.

Assuming a default installation, the file agent.conf can be found in "C:\Program Files (x86)\ossec-agent\ossec.conf" , and the client buffer section should be altered to match the below.

```
<client_buffer>
  <disabled>no</disabled>
  <queue_size>100000</queue_size>
  <events_per_second>1000</events_per_second>
</client_buffer>
```

## References

Wazuh Agent Anti-Flooding Reference : https://documentation.wazuh.com/current/user-manual/agents/antiflooding.html
