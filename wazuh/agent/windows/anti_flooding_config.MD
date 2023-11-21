# Wazuh Agent flooding

## Requirement

The Adoptium public infrastructure windows hosts, receive significantly more intrusion attempts than any other platform, and as such, Wazuh will issue anti-flooding alerts & warnings. The best solution to this, is to improve the volume of logging requests permitted on windows hosts.

## How

To achieve this, a simple configuration change can be made specifically on the windows hosts by amending the client buffer section of the agent configuration on each windows machine. This change could be made in the centralised configuration, but given we have only encountered flooding issues on windows, globally increasing the amount of logging available for all agents across all platforms, could potentially cause disk space issues, and a loss of visibility of an period where an increased number of attacks on a specific machine or platform are occurring.

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
