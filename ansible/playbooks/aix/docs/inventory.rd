
# AdoptOpenJDK - Ansible AIX Playbook Inventory.MD

As I have not (yet) found how to document Inventory in-line - I'll add comments here
asif this was the inventory file - with comments

There are two default groups: `all` and `ungrouped`. Group labels are created by
bracketing the groupname: [groupname]

Note: while all the examples here are names, IP addresses and IP addr ranges are also valid

```
# ungrouped hosts 
osu-nim

# Four (4) named groups - hosts may be in multiple groups
[defaults]
ojdk06.bak

[test]
ojdk06.bak
osu-test

[aix-7104]
ojdk06.bak

[aix-7105]
ojdk05.bak
```
