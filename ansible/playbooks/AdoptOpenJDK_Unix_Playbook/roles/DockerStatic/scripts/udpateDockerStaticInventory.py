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
        return "Port"

def getLabel(nodeConfig):
    find1 = nodeConfig.find("<label>") + 7
    find2 = nodeConfig.find("</label>")
    if find1 > 5 and find2 > -1:
        labels = nodeConfig[find1:find2]
        return labels
    else:
        return "No labels"
    
def createServer(username, password):
    server = jenkins.Jenkins('http://ci.adoptium.net:80', username=username,
                         password=password)
    return server

def main():

# Credentials passed via commandline
    username, password = sys.argv[1:3]
    server = createServer(username, password)
    dockerhosts = []
    nodes = server.get_nodes()

# Get a list of dockerhost machines
    for node in nodes:
        if node["name"].find("dockerhost") > -1:
            dockerhost = node["name"]
            ip = getIP(server.get_node_config(dockerhost))
            dockerhosts.append({"name":dockerhost, "ip":ip})

    dockerhostsFull = []

# Get static docker containers, group with dockerhosts
    for dockerhost in dockerhosts[0:1]:
        print(dockerhost)
        containers = []
        for node in nodes:
            try:
                nodeConfig = server.get_node_config(node["name"])
                nodeIP = getIP(nodeConfig)
                nodePort = getNodePort(nodeConfig)
                if nodeIP == dockerhost["ip"] and node["name"] != dockerhost["name"]:
                    nodeObject = {"nodeName": node["name"], "port": nodePort}
                    containers.append(nodeObject)
            except jenkins.NotFoundException:
                continue
        dockerhostsFull.append({"name": dockerhost["name"], "ip": dockerhost["ip"], "containers": containers, "containersCount": len(containers)})

    print(json.dumps(dockerhostsFull, indent=4))

# Write output to file
    with open('../dockerhost.json', 'w') as f:
        json.dump(dockerhostsFull, f, indent=4)

if __name__ == "__main__":
    main()