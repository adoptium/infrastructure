# OS End-of-Life Audit

## Motivation

Adoptium maintains a fleet of build and test machines running various operating systems distributions. Keeping track of which operating system versions have reached End-of-Life (EOL) is important for security and supportability. Machines still running EOL operating systems may no longer receive security patches and should be prioritised for upgrade or decommission.

`check_os_eol.py` automates this audit by querying the live Jenkins inventory for all active build/test nodes, parsing the OS version encoded in each node name, and checking each version against the [endoflife.date](https://endoflife.date) public API.

---

## Usage

### Requirements

Install the Python dependencies listed in [`requirements.txt`](requirements.txt):

```bash
pip install -r requirements.txt
```

| Package | Purpose |
|---|---|
| `python-dotenv` | Load Jenkins credentials from a `.env` file |
| `python-jenkins` | Connect to and query the Jenkins API |
| `requests` | Call the endoflife.date REST API |

---

### Configuration

Create a `.env` file in the `EOL_audit/` directory (next to the script) with the following variables:

```dotenv
url=https://your-jenkins-instance.example.com:80
username=your-jenkins-username
password=your-jenkins-api-token
```

> The `.env` file is read automatically at startup. The `password` field should be a Jenkins API token, not your account password.

---

### Usage

```bash
python3 check_os_eol.py
```

No command-line arguments are required. The script reads all configuration from the `.env` file.

---

## How It Works

1. **Connect to Jenkins** — Reads credentials from `.env` and opens a connection to the Jenkins server, validating it with a `get_whoami()` call.
2. **Retrieve nodes** — Fetches all Jenkins nodes and filters to those whose names contain `test`, `build`, `dockerhost`, or `macos`.
3. **Extract OS information** — Parses each node name with regular expressions to identify the OS family and version. The following platforms are recognised:

   | OS | Example node name | Example etected version |
   |---|---|---|
   | Ubuntu | `ubuntu2204-build` | `22.04` |
   | RHEL / UBI | `rhel9-test`, `ubi8-build` | `9`, `8` |
   | CentOS | `centos7-test` | `7` |
   | CentOS Stream | `centosstream10-build` | `10` |
   | Fedora | `fedora40-test` | `40` |
   | Alpine | `alpine321-build` | `3.21` |
   | SLES | `sles15-test` | resolved from node labels, e.g. `15.5` |
   | AIX | `aix72-build` | resolved from node labels, e.g. `7.2.5` |

   At the moment windows and dynamic nodes are skipped

4. **Check EOL status** — For each detected OS/version pair, queries `https://endoflife.date/api/v1/products/{os}/releases/{version}`. UBI versions are mapped to their equivalent RHEL release for this lookup.
5. **Print results** — Outputs the full result set as a JSON array to stdout.

---

## Output

Below is a small snippet of the expected output:

```json
[
  {
    "name": "test-rise-ubuntu2404-riscv64-5",
    "os": "ubuntu",
    "version": "24.04",
    "isEOL": false,
    "eolFrom": "2029-05-31"
  },
  {
    "name": "test-podman-ubi9-x64-1",
    "os": "rhel",
    "version": "9",
    "isEOL": false,
    "eolFrom": "2032-05-31"
  },
  {
    "name": "test-marist-sles15-s390x-2",
    "os": "sles",
    "version": "15.2",
    "isEOL": true,
    "eolFrom": "2021-12-31"
  },
]
```

*Documentation generated with the assistance of IBM Bob*
