import jenkins
import sys
import json
import requests

# Get string of node names from input
# Look up 

def createServer(username, password):
    url = "http://ci.adoptium.net:80"
    server = jenkins.Jenkins(url, username=username,
                        password=password)
    return server

def returnPort(inventory, nodeName):
    # Search dockerInventory.json for port numbers, return port number
    for dockerhost in inventory:
        for node in dockerhost["containers"]:
            if node["nodeName"] == nodeName:
                port = node["port"]
                return port

def deleteJenkinsNode(nodeName, USERNAME, TOKEN):
    # Post request to doDelete jenkins url
    headers = {"Content-Type": "application/xml"}
    auth = (USERNAME, TOKEN)
    deleteURL = f'https://ci.adoptium.net/computer/{nodeName}/doDelete'
    r = requests.post(url=deleteURL, auth=auth, headers=headers)

    if r.status_code == 200:
        print(f'\n{nodeName} deleted\n')
    else:
        print(f'\nSomething went wrong. Check to see if {nodeName} is deleted\n')

def main():
    USERNAME,TOKEN = sys.argv[1:3]
    nodeList = sys.argv[3:]

    server = createServer(USERNAME, TOKEN)

    with open('ansible/DockerInventory.json') as file:
        inventory = json.load(file)

    deletedNodesPorts = []
    isNotIdleNodes = []
    # Delete in Jenkins first
    for node in nodeList:
        testNode = server.get_node_info(node)
        if testNode['idle']:
            deleteJenkinsNode(node, USERNAME, TOKEN)
            deletedNodesPorts.append(returnPort(inventory, node))
        else:
            isNotIdleNodes.append(node)

    if len(isNotIdleNodes) > 0:
        print(f'\nList of nodes that were not deleted: {isNotIdleNodes}\n')

    print(f'\nports: {deletedNodesPorts}\n')

if __name__ == "__main__":
    main()
