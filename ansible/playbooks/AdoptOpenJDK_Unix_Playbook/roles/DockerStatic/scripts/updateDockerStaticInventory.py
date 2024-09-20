import sys
import json
import jenkins

def getIP(nodeConfig):
    find1 = nodeConfig.find("<host>") + 6
    find2 = nodeConfig.find("</host>")
    if find1 > 5 and find2 > -1:
        ip = nodeConfig[find1:find2]
        return ip
    else:
        return "No ip"
    
def getNodePort(nodeConfig):
    find1 = nodeConfig.find("<port>") + 6
    find2 = nodeConfig.find("</port>")
    if find1 > 5 and find2 > -1:
        port = nodeConfig[find1:find2]
        return port
    else:
        return "No port"

def getLabel(nodeConfig):
    find1 = nodeConfig.find("<label>") + 7
    find2 = nodeConfig.find("</label>")
    if find1 > 5 and find2 > -1:
        labels = nodeConfig[find1:find2]
        return labels
    else:
        return "No labels"
    
def createServer(username, password):
    url = "https://ci.adoptium.net:443"
    server = jenkins.Jenkins(url, username=username,
                        password=password)
    return server

def help():
    print("Help:\n"
          "     This script is used to retrieve dockerhost and static docker container information from the Adoptium Jenkins server hosted at https://ci.adoptium.net\n"
            "     Usage: python3 updateDockerStaticInventory.py $username $jenkinsAPItoken\n"
            "     The results are dumped into DockerInventory.json in the same directory from which the script was executed\n")

def main():
# Credentials passed via commandline
    try:
        username, password = sys.argv[1:3]
        server = createServer(username, password)
        dockerhosts = []
        nodes = server.get_nodes()
    except ValueError:
        print("\nERROR:This script takes one username and one api token\n")
        help()
        sys.exit(1)

# Get a list of dockerhost machines
    for node in nodes:
        if node["name"].find("dockerhost") > -1:
            dockerhost = node["name"]
            ip = getIP(server.get_node_config(dockerhost))
            dockerhosts.append({"name":dockerhost, "ip":ip})

    dockerhostsFull = []

# Get static docker containers, group with dockerhosts
    for dockerhost in dockerhosts:
        print(dockerhost)
        containers = []
        for node in nodes:
            try:
                nodeConfig = server.get_node_config(node["name"])
                nodePort = getNodePort(nodeConfig)
                nodeLabel = getLabel(nodeConfig)
                if nodeLabel.find(dockerhost["name"]) > -1:
                    nodeObject = {"nodeName": node["name"], "port": nodePort}
                    containers.append(nodeObject)
            except jenkins.NotFoundException:
                continue

        dockerhostsFull.append({"name": dockerhost["name"], "ip": dockerhost["ip"], "containers": containers, "containersCount": len(containers)})

    print(json.dumps(dockerhostsFull, indent=4))

# Write output to file
    with open('../DockerInventory.json', 'w') as f:
        json.dump(dockerhostsFull, f, indent=4)

if __name__ == "__main__":
    main()
