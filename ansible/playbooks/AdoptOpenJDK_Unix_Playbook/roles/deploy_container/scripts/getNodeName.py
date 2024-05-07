import jenkins
import sys
import json

# Get string of node names from input
# Look up 

def createServer(username, password):
    url = "http://ci.adoptium.net:80"
    server = jenkins.Jenkins(url, username=username,
                        password=password)
    return server

def main():
    USERNAME,TOKEN = sys.argv[1:3]
    # USERNAME = 
    # TOKEN = 
    server = createServer(USERNAME, TOKEN)

    # testNode = server.get_node_info('build-marist-rhel8-s390x-1')
    # print(testNode)

    server.delete_node('test-docker-alpine314-armv8-3-test')

if __name__ == "__main__":
    main()
