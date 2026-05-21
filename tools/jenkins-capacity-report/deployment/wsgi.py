#!/usr/bin/env python3
"""WSGI entry point for Jenkins Capacity Analyzer web application."""

import sys
import os
from pathlib import Path

# Add the application directory to the Python path
# Since this file is in deployment/, go up one level to get to the app root
app_dir = Path(__file__).parent.parent.absolute()
sys.path.insert(0, str(app_dir))

# Import the Flask application
from web_app import app as application

# Configure for subdirectory deployment
# This middleware ensures Flask generates correct URLs when deployed under /jenkins-capacity
class PrefixMiddleware(object):
    def __init__(self, app, prefix=''):
        self.app = app
        self.prefix = prefix

    def __call__(self, environ, start_response):
        if self.prefix:
            # Set SCRIPT_NAME to the prefix so Flask knows the application root
            environ['SCRIPT_NAME'] = self.prefix
            # Adjust PATH_INFO by removing the prefix
            path_info = environ.get('PATH_INFO', '')
            if path_info.startswith(self.prefix):
                environ['PATH_INFO'] = path_info[len(self.prefix):]
        return self.app(environ, start_response)

# Wrap the application with the prefix middleware
# The prefix should match the WSGIScriptAlias path in Apache config
application.wsgi_app = PrefixMiddleware(application.wsgi_app, prefix='/jenkins-capacity')

# This is required for WSGI
if __name__ == "__main__":
    application.run()

# Made with Bob
