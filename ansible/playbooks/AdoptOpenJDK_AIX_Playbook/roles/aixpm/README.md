Role Name
=========

The 'module' aixpm implements the geninstall (general install) command for AIX.

The initial release will be limited to the 'installp' packaging

Requirements
------------

No requirements are expected - other than core Ansible, and Ansible version 2.4 and later.
(Developed using Ansible-2.10 and aixtools.python.py36-3.6.12.0).

Role Variables
--------------

A description of the settable variables for this role should go here, including any variables that are in defaults/main.yml, vars/main.yml, and any variables that can/should be set via parameters to the role. Any variables that are read from other roles and/or the global scope (ie. hostvars, group vars, etc.) should be mentioned here as well.

Required elements:

package.name: {string}
package.src: {string}
package.src_type: {fs, nfs, http, https, lpp_source}
package.type: {installp, rpm, ia, ifix}
package.version: {string}
package.notwhen: ""


Dependencies
------------

No dependencies are expected for installp.

While the role will support, eventually, rpm packaging - it not expected that it will ever call Ansible yum module.

Example Playbook
----------------

Including an example of how to use your role (for instance, with variables passed in as parameters) is always nice for users too:

    - hosts: servers
      roles:
         - aixpm:
            package.name: "aixtools.gnu.bash"
            package.src:  "/usr/sys/inst.images"
            package.src_type: fs
            package.type: installp
            package.version: "5.0.18.0"
	    # optional
            package.notwhen: "/usr/bin/bash"
         - aixpm:
            # This will download http://download.aixtools.net/tools/aixtools.gnu.bash-5.0.18.0.I
            # and install it using installp
            package.name: "aixtools.gnu.bash"
            package.src:  "download.aixtools.net/tools"
            package.src_type: httpd
            package.type: installp
            package.version: "5.0.18.0"
	    # optional
            package.notwhen: "/usr/bin/bash"
            package.chksum: "MD5:E6106A3CF9A82B4E8785003F587ECA13"


License
-------

Apache 2.0

Author Information
------------------

Issues with this role can be opened on github: @aixtools/aixpm.
Also, old-school forums at http://forums.rootvg.net/aixtools.

Somedays - old-school is faster than new-tricks :)
