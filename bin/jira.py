from collections.abc import Sequence
from typing import Any, Optional, TYPE_CHECKING

if TYPE_CHECKING:
    from datetime import date as date_
    from requests import Response as RequestsResponse_

class InvalidIssueKeyFormatError(Exception):
    """
    Raised when we're unable to parse an issue key string (ex: PROJ-123)
    """

    pass


class RestError(Exception):
    """
    Raised when a REST request returns a non-2xx HTTP status code.
    """

    pass


class RestNotFoundError(RestError):
    """
    Raised when a REST request returns a 404 HTTP status code.
    """

    pass


class ReleaseNotFoundError(Exception):
    """
    Raised when trying to load a release, but it doesn't exist.
    """

    pass


class Server:
    """
    Jira Server, for running REST commands against
    """

    def __init__(self, base_url: str, username: str, password: str):
        from urllib.parse import urljoin

        self.username = username
        self.password = password
        self.base_url = urljoin(base=base_url, url='/rest/api/2/')

    def has_valid_credentials(self) -> bool:
        """
        Verifies the username/password is valid
        """
        try:
            self.rest_get(uri="myself")
            return True
        except RestError:
            return False

    def rest_get(self, uri: str, params: Optional[dict[str, str]] = None) -> Optional[dict[Any, Any]]:
        """
        Run a GET request to the Jira server and return the result.
        :param uri:
        :param params: Parameters for the get request
        :raises RestError: if the HTTP status is not 200.
        :raises RestNotFoundError: if the HTTP status is 404
        """
        from urllib.parse import urljoin
        import requests

        url = urljoin(self.base_url, uri)
        resp = requests.get(url=url, params=params, auth=(self.username, self.password))

        return self._parse_response(resp)

    def rest_put(self, uri: str, params: Any) -> Optional[dict[Any, Any]]:
        """
        Run a PUT request to the Jira server and return the result.
        :param uri:
        :param params:
        :raises RestError: if the HTTP status is not 200 or 204.
        :raises RestNotFoundError: if the HTTP status is 404
        """
        from urllib.parse import urljoin
        import requests

        url = urljoin(self.base_url, uri)
        resp = requests.put(url=url, json=params, auth=(self.username, self.password))

        return self._parse_response(resp)

    def rest_post(self, uri: str, params: Any) -> Optional[dict[Any, Any]]:
        """
        Run a POST request to the Jira server and return the result.

        :param uri:
        :param params:
        :raises RestError: if the HTTP status is not 200 or 204.
        :raises RestNotFoundError: if the HTTP status is 404
        """
        from urllib.parse import urljoin
        import requests

        url = urljoin(self.base_url, uri)
        resp = requests.post(url=url, json=params, auth=(self.username, self.password))

        return self._parse_response(resp)

    @classmethod
    def _parse_response(cls, response: 'RequestsResponse_') -> Any:
        """
        Parses Jira REST response and returns parsed JSON content or raises the appropriate exception.

        :raises RestError: if the HTTP status is not 200 or 204.
        :raises RestNotFoundError: if the HTTP status is 404
        """
        if response.status_code in (200, 201, 204):
            return response.json() if response.content else None
        elif response.status_code == 404:
            raise RestNotFoundError
        raise RestError


class Issue:
    """
    Jira issue
    """

    def __init__(self, server: Server, issue_data: dict[Any, Any]):
        self.server = server
        self.issue_data = issue_data
        self.key: str = issue_data['key']
        self.summary = issue_data['fields']['summary']
        self.components: set[str] = {comp['name'] for comp in issue_data['fields']['components']}

        # Figure out the assignee.
        ass = self.issue_data['fields']['assignee']
        if ass:
            self.assignee = ass['name']
        else:
            self.assignee = None

        # Status (ex: 'In Progress')
        self.status = issue_data['fields']['status']['name']
        self.headline = issue_data['fields']['summary']

    @classmethod
    def load(cls, server: Server, issue_key: 'IssueKey') -> 'Issue':
        """
        Load an issue from its IssueKey.

        :raises RestNotFoundError: if the JIRA issue does not exist.
        """
        issue_data = server.rest_get(uri=f'issue/{issue_key}')
        assert isinstance(issue_data, dict)
        return Issue(server=server, issue_data=issue_data)

    @classmethod
    def lookup_by_status(cls, server: Server, status: str) -> Sequence['Issue']:
        """
        Gets issues in Jira if they have the status given
        :param server:
        :param status: Status of the issues desired to return
        """
        jira_resp = server.rest_get(uri="search", params={'jql': f'status="{status}" and project="MARS"'})
        assert isinstance(jira_resp, dict)

        issues = []
        for issue_str in jira_resp['issues']:
            issues.append(Issue.load(server=server, issue_key=IssueKey.from_str(issue_str['key'])))
        return issues

    def assign(self, assignee: str):
        """
        Assign the Jira issue to a different user
        """
        self.server.rest_put(uri=f"issue/{self.key}/assignee", params={'name': assignee})
        self.assignee = assignee

    def transition_to_status(self, status: str):
        """
        Transition the Jira issue to a different status
        """
        # get the list of transitions
        trans_resp = self.server.rest_get(f'issue/{self.key}/transitions')
        assert isinstance(trans_resp, dict)

        trans_id = None
        for transition in trans_resp['transitions']:
            if transition['name'] == status:
                trans_id = transition['id']
                break

        self.server.rest_post(uri=f'issue/{self.key}/transitions', params={'transition': {'id': trans_id}})
        self.status = status

    def add_fix_version(self, version: str) -> None:
        """
        Add the version name specified to the issue's "Fixed Versions" field.
        :param version:
        """
        # Keep black from collapsing this all onto a single line
        # fmt: off
        self.server.rest_put(uri=f"issue/{self.key}", params={
            "update": {
                "fixVersions": [
                    {
                        "set": [
                            {"name": version}
                        ]
                    }
                ]
            }
        })
        # fmt: on


class IssueKey:
    """
    Jira issue key (i.e. FOO-123)
    """

    def __init__(self, issue_key_str: str):
        self.issue_key_str = issue_key_str

    @classmethod
    def from_str(cls, issue_key_str: str) -> 'IssueKey':
        """
        Convert an issue key string (ex: "FOO-123") into an IssueKey object.
        """
        import re

        if not re.match(r'([A-Z]+)-(\d+)$', issue_key_str):
            raise InvalidIssueKeyFormatError(f"Unable to parse Jira issue key {issue_key_str!r}, expected something like 'PROJ-123'.")

        return IssueKey(issue_key_str=issue_key_str)

    def __str__(self) -> str:
        return self.issue_key_str

    def __eq__(self, other: Any) -> bool:
        if type(other) is not type(self):
            return NotImplemented

        return self.issue_key_str == other.issue_key_str


class Release:
    """
    Jira version
    """

    def __init__(self, server: Server, id_: int, version: str, release_date: Optional['date_'], description: Optional[str] = None):
        """
        NOTE: release_date will be None for releases that have not yet been released.
        """
        self.server = server
        self.id = id_
        self.version = version
        self.release_date = release_date
        self.description = description

    @classmethod
    def create(cls, server: Server, version: str, description: Optional[str] = None) -> 'Release':
        """
        Creates a release in Jira
        """
        r = server.rest_post(uri='version', params={"description": description, "project": "MARS", "name": version, "released": False})
        assert isinstance(r, dict)

        return Release(server=server, id_=int(r['id']), version=version, description=description, release_date=None)

    @classmethod
    def lookup_by_version(cls, server: Server, version: str) -> Optional['Release']:
        """
        Load this release from jira
        :raises ReleaseNotFoundError: if the release is not found
        """
        for release in cls.get_all_releases(server=server):
            if release.version == version:
                return release

        raise ReleaseNotFoundError(f"Version {version} doesn't exist")

    @classmethod
    def get_all_releases(cls, server: Server) -> Sequence['Release']:
        """
        Returns all releases.
        """
        from datetime import datetime

        resp = server.rest_get(uri="project/MARS/versions")
        assert isinstance(resp, list)

        releases = []
        for r in resp:
            release_date = datetime.strptime(r['releaseDate'], "%Y-%m-%d").date() if r['released'] else None
            releases.append(Release(server=server, id_=int(r['id']), version=r['name'], release_date=release_date))

        return releases

    def release(self, release_date: Optional['date_'] = None) -> None:
        """
        Release this release on Jira
        :param release_date: Date of release in the format YYYY-MM-DD default is today's date
        """
        from datetime import date

        if release_date is None:
            release_date = date.today()

        self.server.rest_put(uri=f'version/{self.id}', params={"released": True, "releaseDate": release_date.strftime('%Y-%m-%d')})
        self.release_date = release_date

